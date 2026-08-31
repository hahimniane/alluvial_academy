"use client";

import Link from "next/link";
import { onAuthStateChanged, type User } from "firebase/auth";
import { httpsCallable } from "firebase/functions";
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit,
  query,
  serverTimestamp,
  Timestamp,
  updateDoc,
  where,
} from "firebase/firestore";
import { useEffect, useMemo, useState } from "react";
import {
  Calendar,
  ChevronLeft,
  ChevronRight,
  Download,
  Edit3,
  FileText,
  FolderOpen,
  Lock,
  Menu,
  Printer,
  ReceiptText,
  Search,
  Trash2,
  X,
} from "lucide-react";
import { AdminDashboardShell } from "@/components/AdminDashboardShell";
import { auth, db, functions } from "@/lib/firebase";
import { isCurrentUserAdmin } from "@/lib/userRoles";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type InvoiceTab = "create" | "all";
type InvoiceStatus = "pending" | "paid" | "overdue" | "cancelled";
type StatusFilter = "all" | InvoiceStatus;

type BillableUser = {
  id: string;
  firstName: string;
  lastName: string;
  email: string;
  userType: "parent" | "student";
  childrenIds: string[];
  isAdultStudent: boolean;
};

type BillableChild = {
  id: string;
  firstName: string;
  lastName: string;
};

type InvoiceItem = {
  description: string;
  quantity: number;
  unitPrice: number;
  total: number;
};

type InvoiceRecord = {
  id: string;
  invoiceNumber: string;
  parentId: string;
  studentId: string;
  status: InvoiceStatus;
  totalAmount: number;
  paidAmount: number;
  currency: string;
  issuedDate: Date | null;
  dueDate: Date | null;
  accessCutoffDate: Date | null;
  period: string;
  items: InvoiceItem[];
  createdAt: Date | null;
};

type AmountDraft = {
  description: string;
  amount: string;
};

const statusFilters: { id: StatusFilter; label: string }[] = [
  { id: "all", label: "All" },
  { id: "pending", label: "Pending" },
  { id: "paid", label: "Paid" },
  { id: "overdue", label: "Overdue" },
  { id: "cancelled", label: "Cancelled" },
];

export function InvoicesAdmin() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [user, setUser] = useState<User | null>(null);
  const [activeTab, setActiveTab] = useState<InvoiceTab>("create");
  const [billableUsers, setBillableUsers] = useState<BillableUser[]>([]);
  const [selectedUser, setSelectedUser] = useState<BillableUser | null>(null);
  const [children, setChildren] = useState<BillableChild[]>([]);
  const [amountDrafts, setAmountDrafts] = useState<Record<string, AmountDraft>>({});
  const [invoices, setInvoices] = useState<InvoiceRecord[]>([]);
  const [parentNames, setParentNames] = useState<Record<string, string>>({});
  const [userSearch, setUserSearch] = useState("");
  const [showUserResults, setShowUserResults] = useState(false);
  const [invoiceSearch, setInvoiceSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("all");
  const [billingMonth, setBillingMonth] = useState(startOfMonth(new Date()));
  const [dueDate, setDueDate] = useState(formatDateInput(addDays(new Date(), 7)));
  const [accessCutoffDate, setAccessCutoffDate] = useState(formatDateInput(addDays(new Date(), 8)));
  const [loading, setLoading] = useState(true);
  const [loadingChildren, setLoadingChildren] = useState(false);
  const [creating, setCreating] = useState(false);
  const [message, setMessage] = useState("");
  const [editing, setEditing] = useState<InvoiceRecord | null>(null);
  const [confirmDelete, setConfirmDelete] = useState<InvoiceRecord | null>(null);

  useEffect(() => {
    let mounted = true;
    return onAuthStateChanged(auth, async (nextUser) => {
      if (!mounted) return;
      setUser(nextUser);
      setMessage("");
      if (!nextUser) {
        setAccess("signedOut");
        setLoading(false);
        return;
      }

      setAccess("checking");
      setLoading(true);
      try {
        const allowed = await isCurrentUserAdmin(nextUser);
        if (!mounted) return;
        if (!allowed) {
          setAccess("denied");
          setLoading(false);
          return;
        }
        setAccess("allowed");
        const [users, invoiceRows] = await Promise.all([loadBillableUsers(), loadInvoices()]);
        if (!mounted) return;
        setBillableUsers(users);
        setInvoices(invoiceRows);
        setParentNames(await loadUserNames(invoiceRows.map((invoice) => invoice.parentId)));
      } catch (error) {
        if (mounted) setMessage(error instanceof Error ? error.message : "Could not load invoices.");
      } finally {
        if (mounted) setLoading(false);
      }
    });
  }, []);

  const filteredUsers = useMemo(() => {
    const term = userSearch.trim().toLowerCase();
    if (!term) return billableUsers;
    return billableUsers.filter((entry) => [fullName(entry), entry.email].some((value) => value.toLowerCase().includes(term)));
  }, [billableUsers, userSearch]);

  const filteredInvoices = useMemo(() => {
    const term = invoiceSearch.trim().toLowerCase();
    return invoices.filter((invoice) => {
      const effectiveStatus = isInvoiceOverdue(invoice) ? "overdue" : invoice.status;
      if (statusFilter !== "all" && effectiveStatus !== statusFilter) return false;
      if (!term) return true;
      return [
        invoice.invoiceNumber,
        invoice.id,
        parentNames[invoice.parentId] ?? invoice.parentId,
        invoice.period,
        invoice.status,
      ].some((value) => value.toLowerCase().includes(term));
    });
  }, [invoiceSearch, invoices, parentNames, statusFilter]);

  async function selectUser(nextUser: BillableUser) {
    setSelectedUser(nextUser);
    setUserSearch("");
    setShowUserResults(false);
    setMessage("");
    setLoadingChildren(true);
    try {
      const nextChildren = await loadChildrenFor(nextUser);
      setChildren(nextChildren);
      setAmountDrafts(Object.fromEntries(nextChildren.map((child) => [child.id, { description: "Tuition", amount: "" }])));
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Could not load linked students.");
      setChildren([]);
      setAmountDrafts({});
    } finally {
      setLoadingChildren(false);
    }
  }

  function clearSelection() {
    setSelectedUser(null);
    setChildren([]);
    setAmountDrafts({});
    setMessage("");
  }

  function changeMonth(offset: number) {
    setBillingMonth((current) => new Date(current.getFullYear(), current.getMonth() + offset, 1));
  }

  function updateAmount(childId: string, patch: Partial<AmountDraft>) {
    setAmountDrafts((current) => ({
      ...current,
      [childId]: { ...(current[childId] ?? { description: "Tuition", amount: "" }), ...patch },
    }));
  }

  async function createInvoice() {
    if (!selectedUser) return;
    const items = children
      .map((child) => {
        const draft = amountDrafts[child.id] ?? { description: "Tuition", amount: "" };
        const amount = Number(draft.amount);
        if (!draft.amount.trim() || !Number.isFinite(amount) || amount <= 0) return null;
        return {
          child,
          item: {
            description: `${draft.description.trim() || "Tuition"} - ${fullName(child)}`,
            quantity: 1,
            unit_price: amount,
            total: amount,
          },
        };
      })
      .filter((entry): entry is { child: BillableChild; item: { description: string; quantity: number; unit_price: number; total: number } } => entry !== null);

    if (items.length === 0) {
      setMessage("Enter an amount for at least one student");
      return;
    }

    setCreating(true);
    setMessage("");
    try {
      const firstChildId = items[0].child.id;
      const callable = httpsCallable(functions, "createInvoice");
      const result = await callable({
        parentId: selectedUser.userType === "parent" ? selectedUser.id : firstChildId,
        studentId: firstChildId,
        currency: "USD",
        items: items.map((entry) => entry.item),
        period: formatPeriod(billingMonth),
        dueDate: new Date(`${dueDate}T12:00:00`).toISOString(),
        accessCutoffDate: new Date(`${accessCutoffDate}T12:00:00`).toISOString(),
      });
      const data = (result.data ?? {}) as { invoiceNumber?: string };
      setMessage(`Invoice ${data.invoiceNumber ?? ""} created successfully`.trim());
      setAmountDrafts(Object.fromEntries(children.map((child) => [child.id, { description: amountDrafts[child.id]?.description || "Tuition", amount: "" }])));
      const invoiceRows = await loadInvoices();
      setInvoices(invoiceRows);
      setParentNames(await loadUserNames(invoiceRows.map((invoice) => invoice.parentId)));
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Could not create invoice.");
    } finally {
      setCreating(false);
    }
  }

  async function updateInvoice(invoice: InvoiceRecord, patch: Partial<InvoiceRecord>) {
    await updateDoc(doc(db, "invoices", invoice.id), {
      status: patch.status ?? invoice.status,
      total_amount: patch.totalAmount ?? invoice.totalAmount,
      paid_amount: patch.paidAmount ?? invoice.paidAmount,
      period: patch.period || "",
      due_date: patch.dueDate ? Timestamp.fromDate(patch.dueDate) : Timestamp.fromDate(invoice.dueDate ?? new Date()),
      access_cutoff_date: patch.accessCutoffDate
        ? Timestamp.fromDate(patch.accessCutoffDate)
        : Timestamp.fromDate(invoice.accessCutoffDate ?? addDays(invoice.dueDate ?? new Date(), 1)),
      updated_at: serverTimestamp(),
    });
    const invoiceRows = await loadInvoices();
    setInvoices(invoiceRows);
    setEditing(null);
    setMessage(`Invoice ${invoice.invoiceNumber || invoice.id} updated`);
  }

  async function deleteInvoiceRecord(invoice: InvoiceRecord) {
    await deleteDoc(doc(db, "invoices", invoice.id));
    setInvoices((current) => current.filter((item) => item.id !== invoice.id));
    setConfirmDelete(null);
    setMessage(`Delete Invoice: ${invoice.invoiceNumber || invoice.id}`);
  }

  if (access !== "allowed") {
    return <InvoicesAccessPrompt access={access} />;
  }

  return (
    <AdminDashboardShell activeLabel="Invoices" breadcrumb="Finance / Invoices">
      <main className="min-h-[calc(100vh-56px)] bg-[#F8FAFC] text-[#0F172A]">
        <header className="lg:hidden">
          <div className="grid min-h-14 grid-cols-[48px_1fr_48px] items-center bg-white px-3">
            <button type="button" aria-label="Menu" className="grid h-11 w-11 place-items-center rounded-xl">
              <Menu size={20} />
            </button>
            <div className="min-w-0 text-center">
              <div className="truncate text-sm font-black">Alluwal Education Hub</div>
            </div>
            <span className="grid h-8 w-8 place-items-center rounded-full bg-[#009688] text-[11px] font-black text-white">
              {initialsFor(user)}
            </span>
          </div>
        </header>

        <section className="border-b border-[#E2E8F0] bg-white">
          <div className="mx-auto grid max-w-[900px] grid-cols-2">
            <InvoiceTabButton active={activeTab === "create"} icon={ReceiptText} label="Create Invoice" onClick={() => setActiveTab("create")} />
            <InvoiceTabButton active={activeTab === "all"} icon={FolderOpen} label="All Invoices" onClick={() => setActiveTab("all")} />
          </div>
        </section>

        {message ? <div className="mx-auto mt-4 max-w-[900px] px-6"><p className="rounded-xl border border-[#BFDBFE] bg-[#EFF6FF] px-4 py-3 text-sm font-semibold text-[#1D4ED8]">{message}</p></div> : null}

        {loading ? (
          <div className="grid min-h-[480px] place-items-center">
            <div className="h-9 w-9 animate-spin rounded-full border-4 border-[#DBEAFE] border-t-[#0386FF]" />
          </div>
        ) : activeTab === "create" ? (
          <CreateInvoicePanel
            accessCutoffDate={accessCutoffDate}
            amountDrafts={amountDrafts}
            billingMonth={billingMonth}
            children={children}
            creating={creating}
            dueDate={dueDate}
            filteredUsers={filteredUsers}
            loadingChildren={loadingChildren}
            selectedUser={selectedUser}
            showUserResults={showUserResults}
            userSearch={userSearch}
            onAccessCutoffDateChange={setAccessCutoffDate}
            onChangeMonth={changeMonth}
            onClearSelection={clearSelection}
            onCreate={createInvoice}
            onDueDateChange={(value) => {
              setDueDate(value);
              if (new Date(`${accessCutoffDate}T12:00:00`) < new Date(`${value}T12:00:00`)) setAccessCutoffDate(formatDateInput(addDays(new Date(`${value}T12:00:00`), 1)));
            }}
            onSelectUser={selectUser}
            onShowResultsChange={setShowUserResults}
            onUpdateAmount={updateAmount}
            onUserSearchChange={setUserSearch}
          />
        ) : (
          <AllInvoicesPanel
            filteredInvoices={filteredInvoices}
            invoiceSearch={invoiceSearch}
            parentNames={parentNames}
            statusFilter={statusFilter}
            onDelete={setConfirmDelete}
            onEdit={setEditing}
            onInvoiceSearchChange={setInvoiceSearch}
            onPdfAction={(label) => setMessage(`${label} stays in Flutter until PDF generation is migrated.`)}
            onStatusFilterChange={setStatusFilter}
          />
        )}

        {editing ? <EditInvoiceDialog invoice={editing} onClose={() => setEditing(null)} onSave={updateInvoice} /> : null}
        {confirmDelete ? <DeleteInvoiceDialog invoice={confirmDelete} onCancel={() => setConfirmDelete(null)} onDelete={() => deleteInvoiceRecord(confirmDelete)} /> : null}
      </main>
    </AdminDashboardShell>
  );
}

function CreateInvoicePanel({
  accessCutoffDate,
  amountDrafts,
  billingMonth,
  children,
  creating,
  dueDate,
  filteredUsers,
  loadingChildren,
  selectedUser,
  showUserResults,
  userSearch,
  onAccessCutoffDateChange,
  onChangeMonth,
  onClearSelection,
  onCreate,
  onDueDateChange,
  onSelectUser,
  onShowResultsChange,
  onUpdateAmount,
  onUserSearchChange,
}: {
  accessCutoffDate: string;
  amountDrafts: Record<string, AmountDraft>;
  billingMonth: Date;
  children: BillableChild[];
  creating: boolean;
  dueDate: string;
  filteredUsers: BillableUser[];
  loadingChildren: boolean;
  selectedUser: BillableUser | null;
  showUserResults: boolean;
  userSearch: string;
  onAccessCutoffDateChange: (value: string) => void;
  onChangeMonth: (offset: number) => void;
  onClearSelection: () => void;
  onCreate: () => void;
  onDueDateChange: (value: string) => void;
  onSelectUser: (user: BillableUser) => void;
  onShowResultsChange: (show: boolean) => void;
  onUpdateAmount: (childId: string, patch: Partial<AmountDraft>) => void;
  onUserSearchChange: (value: string) => void;
}) {
  return (
    <section className="mx-auto max-w-[640px] px-6 py-7">
      <div className="flex items-center gap-4">
        <span className="grid h-11 w-11 place-items-center rounded-[14px] bg-gradient-to-br from-[#0386FF] to-[#0EA5E9] text-white">
          <ReceiptText size={22} />
        </span>
        <div>
          <h1 className="text-[22px] font-black text-[#0F172A]">Create Invoice</h1>
          <p className="mt-1 text-[13px] font-medium text-[#64748B]">Bill a parent or adult student</p>
        </div>
      </div>
      <div className="mt-7 border-t border-[#E2E8F0]" />

      <div className="mt-7">
        {selectedUser ? (
          <SelectedUserCard user={selectedUser} onClear={onClearSelection} />
        ) : (
          <div>
            <label className="text-sm font-bold text-[#334155]" htmlFor="invoice-user-search">Select a parent or student</label>
            <div className="relative mt-3">
              <Search className="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-[#94A3B8]" size={20} />
              <input
                id="invoice-user-search"
                aria-label="Search by name or email"
                value={userSearch}
                onChange={(event) => {
                  onUserSearchChange(event.target.value);
                  onShowResultsChange(true);
                }}
                onFocus={() => onShowResultsChange(true)}
                placeholder="Search by name or email..."
                className="h-12 w-full rounded-[14px] border border-[#E2E8F0] bg-white pl-12 pr-4 text-sm font-medium text-[#0F172A] shadow-[0_2px_8px_rgba(0,0,0,0.04)] outline-none placeholder:text-[#94A3B8] focus:border-[#0386FF]"
              />
            </div>
            {showUserResults ? <UserResults users={filteredUsers} onSelect={onSelectUser} /> : null}
          </div>
        )}
      </div>

      {selectedUser ? (
        <>
          <DateControl title="Billing month" value={formatMonth(billingMonth)} onPrevious={() => onChangeMonth(-1)} onNext={() => onChangeMonth(1)} />
          <LabeledDateInput label="Payment due date" value={dueDate} onChange={onDueDateChange} />
          <LabeledDateInput label="Access cutoff date" helper="Students lose access if invoice unpaid by this date." tone="warning" value={accessCutoffDate} onChange={onAccessCutoffDateChange} min={dueDate} />
          <section className="mt-5">
            <h2 className="text-sm font-bold text-[#334155]">Enter amount per student</h2>
            {loadingChildren ? (
              <div className="grid min-h-[120px] place-items-center">
                <div className="h-7 w-7 animate-spin rounded-full border-4 border-[#DBEAFE] border-t-[#0386FF]" />
              </div>
            ) : children.length === 0 ? (
              <div className="mt-3 rounded-[14px] border border-[#E2E8F0] bg-white p-5 text-sm font-semibold text-[#64748B]">No children linked to this parent.</div>
            ) : (
              <div className="mt-3 grid gap-3">
                {children.map((child) => (
                  <AmountCard key={child.id} child={child} draft={amountDrafts[child.id] ?? { description: "Tuition", amount: "" }} onChange={(patch) => onUpdateAmount(child.id, patch)} />
                ))}
              </div>
            )}
          </section>
          <button type="button" onClick={onCreate} disabled={creating || loadingChildren || children.length === 0} className="mt-5 flex min-h-12 w-full items-center justify-center rounded-xl bg-[#0386FF] px-5 text-sm font-black text-white shadow-sm disabled:cursor-not-allowed disabled:bg-[#CBD5E1]">
            {creating ? "Creating..." : "Create Invoice"}
          </button>
        </>
      ) : null}
    </section>
  );
}

function AllInvoicesPanel({
  filteredInvoices,
  invoiceSearch,
  parentNames,
  statusFilter,
  onDelete,
  onEdit,
  onInvoiceSearchChange,
  onPdfAction,
  onStatusFilterChange,
}: {
  filteredInvoices: InvoiceRecord[];
  invoiceSearch: string;
  parentNames: Record<string, string>;
  statusFilter: StatusFilter;
  onDelete: (invoice: InvoiceRecord) => void;
  onEdit: (invoice: InvoiceRecord) => void;
  onInvoiceSearchChange: (value: string) => void;
  onPdfAction: (label: string) => void;
  onStatusFilterChange: (filter: StatusFilter) => void;
}) {
  return (
    <section className="mx-auto max-w-[900px] px-6 py-7">
      <div className="flex items-center gap-4">
        <span className="grid h-11 w-11 place-items-center rounded-[14px] bg-gradient-to-br from-[#10B981] to-[#059669] text-white">
          <ReceiptText size={22} />
        </span>
        <div>
          <h1 className="text-[22px] font-black text-[#0F172A]">Invoices</h1>
          <p className="mt-1 text-[13px] font-medium text-[#64748B]">Create, review, and manage parent invoices.</p>
        </div>
      </div>
      <label className="relative mt-6 block">
        <span className="sr-only">Search Invoice Number</span>
        <Search className="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-[#94A3B8]" size={20} />
        <input
          value={invoiceSearch}
          onChange={(event) => onInvoiceSearchChange(event.target.value)}
          aria-label="Search Invoice Number"
          placeholder="Search Invoice Number"
          className="h-12 w-full rounded-[14px] border border-[#E2E8F0] bg-white pl-12 pr-10 text-sm font-medium text-[#0F172A] shadow-[0_2px_8px_rgba(0,0,0,0.04)] outline-none placeholder:text-[#94A3B8] focus:border-[#0386FF]"
        />
      </label>
      <div className="mt-3 flex gap-2 overflow-x-auto">
        {statusFilters.map((filter) => (
          <button key={filter.id} type="button" onClick={() => onStatusFilterChange(filter.id)} className={`min-h-9 rounded-full border px-4 text-xs font-black ${statusFilter === filter.id ? "border-[#0386FF] bg-[#0386FF] text-white" : "border-[#E2E8F0] bg-white text-[#334155]"}`}>
            {filter.label}
          </button>
        ))}
      </div>
      <div className="mt-4 border-t border-[#E2E8F0]" />

      {filteredInvoices.length === 0 ? (
        <div className="grid min-h-[380px] place-items-center text-center">
          <div>
            <ReceiptText size={48} className="mx-auto text-[#CBD5E1]" />
            <p className="mt-3 text-sm font-bold text-[#94A3B8]">No Invoices Found</p>
          </div>
        </div>
      ) : (
        <div className="mt-4 grid gap-3 pb-10">
          {filteredInvoices.map((invoice) => (
            <InvoiceCard key={invoice.id} invoice={invoice} parentName={(parentNames[invoice.parentId] ?? invoice.parentId) || "..."} onDelete={() => onDelete(invoice)} onEdit={() => onEdit(invoice)} onPdfAction={onPdfAction} />
          ))}
        </div>
      )}
    </section>
  );
}

function InvoiceCard({
  invoice,
  parentName,
  onDelete,
  onEdit,
  onPdfAction,
}: {
  invoice: InvoiceRecord;
  parentName: string;
  onDelete: () => void;
  onEdit: () => void;
  onPdfAction: (label: string) => void;
}) {
  const effectiveStatus = isInvoiceOverdue(invoice) ? "overdue" : invoice.status;
  const statusColor = statusColorFor(effectiveStatus);
  return (
    <article className="rounded-[14px] border border-[#E2E8F0] bg-white p-4 shadow-[0_2px_6px_rgba(0,0,0,0.03)]">
      <div className="flex items-start gap-3">
        <span className="grid h-[38px] w-[38px] place-items-center rounded-[10px]" style={{ backgroundColor: `${statusColor}1A`, color: statusColor }}>
          <ReceiptText size={18} />
        </span>
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <h2 className="text-sm font-black text-[#0F172A]">{invoice.invoiceNumber || "Invoices"}</h2>
            <span className="rounded-full px-2.5 py-1 text-[11px] font-black uppercase tracking-normal" style={{ backgroundColor: `${statusColor}1A`, color: statusColor }}>
              {effectiveStatus.toUpperCase()}
            </span>
          </div>
          <p className="mt-1 text-xs font-medium text-[#64748B]">{parentName}</p>
        </div>
        <ChevronRight size={22} className="mt-2 text-[#CBD5E1]" />
      </div>
      <div className="mt-3 flex flex-wrap gap-2">
        <InfoTag icon={Calendar} label={invoice.issuedDate ? formatShortDate(invoice.issuedDate) : "-"} />
        <InfoTag icon={ReceiptText} label={formatMoney(invoice.totalAmount, invoice.currency)} bold />
        {invoice.period ? <InfoTag icon={Calendar} label={`Billing: ${displayBillingPeriod(invoice.period)}`} color="#0369A1" /> : null}
        {remainingBalance(invoice) > 0 ? <InfoTag icon={ReceiptText} label={`Balance due: ${formatMoney(remainingBalance(invoice), invoice.currency)}`} color="#DC2626" /> : null}
      </div>
      <div className="mt-4 flex gap-2 overflow-x-auto">
        <ActionButton icon={Download} label="Download PDF" onClick={() => onPdfAction("Download PDF")} />
        <ActionButton icon={Printer} label="Print PDF" onClick={() => onPdfAction("Print PDF")} />
        <ActionButton icon={Edit3} label="Edit Invoice" onClick={onEdit} />
        <ActionButton icon={Trash2} label="Delete Invoice" tone="danger" onClick={onDelete} />
      </div>
    </article>
  );
}

function EditInvoiceDialog({ invoice, onClose, onSave }: { invoice: InvoiceRecord; onClose: () => void; onSave: (invoice: InvoiceRecord, patch: Partial<InvoiceRecord>) => Promise<void> }) {
  const [status, setStatus] = useState<InvoiceStatus>(invoice.status);
  const [total, setTotal] = useState(invoice.totalAmount.toFixed(2));
  const [paid, setPaid] = useState(invoice.paidAmount.toFixed(2));
  const [period, setPeriod] = useState(invoice.period);
  const [dueDate, setDueDate] = useState(formatDateInput(invoice.dueDate ?? new Date()));
  const [accessCutoffDate, setAccessCutoffDate] = useState(formatDateInput(invoice.accessCutoffDate ?? addDays(invoice.dueDate ?? new Date(), 1)));
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  async function save() {
    const nextTotal = Number(total);
    const nextPaid = Number(paid);
    if (!Number.isFinite(nextTotal) || !Number.isFinite(nextPaid) || nextTotal < 0 || nextPaid < 0) {
      setError("Enter valid billing numbers.");
      return;
    }
    setSaving(true);
    setError("");
    try {
      await onSave(invoice, {
        status,
        totalAmount: nextTotal,
        paidAmount: nextPaid,
        period,
        dueDate: new Date(`${dueDate}T12:00:00`),
        accessCutoffDate: new Date(`${accessCutoffDate}T12:00:00`),
      });
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : "Could not save invoice.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/35 px-4">
      <div className="max-h-[90vh] w-full max-w-[440px] overflow-y-auto rounded-[18px] bg-white p-6 shadow-2xl">
        <div className="flex items-center gap-3">
          <span className="grid h-9 w-9 place-items-center rounded-[10px] bg-[#EFF6FF] text-[#0386FF]">
            <Edit3 size={20} />
          </span>
          <h2 className="min-w-0 flex-1 text-lg font-black text-[#0F172A]">Edit Invoice {invoice.invoiceNumber}</h2>
          <button type="button" aria-label="Close edit invoice" onClick={onClose} className="grid h-9 w-9 place-items-center rounded-lg text-[#64748B]">
            <X size={20} />
          </button>
        </div>
        <div className="mt-5 grid gap-4">
          <label className="grid gap-1.5 text-xs font-bold text-[#64748B]">
            Status
            <select value={status} onChange={(event) => setStatus(event.target.value as InvoiceStatus)} className="h-11 rounded-[10px] border border-[#E2E8F0] bg-[#F8FAFC] px-3 text-sm font-semibold text-[#0F172A]">
              {(["pending", "paid", "overdue", "cancelled"] as InvoiceStatus[]).map((option) => <option key={option} value={option}>{option.toUpperCase()}</option>)}
            </select>
          </label>
          <DialogField label={`Total (${invoice.currency})`} value={total} onChange={setTotal} />
          <DialogField label={`Paid (${invoice.currency})`} value={paid} onChange={setPaid} />
          <DialogField label="Billing period" value={period} onChange={setPeriod} placeholder="Enter a billing period such as Sep 1 - Sep 30." />
          <LabeledDateInput compact label="Due Date" value={dueDate} onChange={setDueDate} />
          <LabeledDateInput compact label="Access cutoff date" helper="Students lose access if invoice unpaid by this date." tone="warning" value={accessCutoffDate} onChange={setAccessCutoffDate} min={dueDate} />
        </div>
        {error ? <p className="mt-3 text-xs font-bold text-[#DC2626]">{error}</p> : null}
        <div className="mt-5 grid grid-cols-2 gap-3">
          <button type="button" onClick={onClose} className="min-h-11 rounded-xl border border-[#E2E8F0] text-sm font-black text-[#334155]">Cancel</button>
          <button type="button" onClick={save} disabled={saving} className="min-h-11 rounded-xl bg-[#0386FF] text-sm font-black text-white disabled:bg-[#CBD5E1]">{saving ? "Saving..." : "Save"}</button>
        </div>
      </div>
    </div>
  );
}

function DeleteInvoiceDialog({ invoice, onCancel, onDelete }: { invoice: InvoiceRecord; onCancel: () => void; onDelete: () => void }) {
  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/35 px-4">
      <div className="w-full max-w-[420px] rounded-2xl bg-white p-6 shadow-2xl">
        <h2 className="text-lg font-black text-[#0F172A]">Delete invoice?</h2>
        <p className="mt-3 text-sm font-medium leading-6 text-[#64748B]">Are you sure you want to delete invoice {invoice.invoiceNumber || invoice.id}?</p>
        <div className="mt-5 grid grid-cols-2 gap-3">
          <button type="button" onClick={onCancel} className="min-h-11 rounded-xl border border-[#E2E8F0] text-sm font-black text-[#334155]">Cancel</button>
          <button type="button" onClick={onDelete} className="min-h-11 rounded-xl bg-[#DC2626] text-sm font-black text-white">Delete Invoice</button>
        </div>
      </div>
    </div>
  );
}

function UserResults({ users, onSelect }: { users: BillableUser[]; onSelect: (user: BillableUser) => void }) {
  if (users.length === 0) {
    return <div className="mt-2 rounded-[14px] border border-[#E2E8F0] bg-white p-5 text-center text-sm font-semibold text-[#94A3B8]">No parents or adult students found</div>;
  }
  return (
    <div className="mt-2 max-h-[300px] overflow-y-auto rounded-[14px] border border-[#E2E8F0] bg-white shadow-[0_4px_12px_rgba(0,0,0,0.06)]">
      {users.map((entry) => {
        const parent = entry.userType === "parent";
        return (
          <button key={entry.id} type="button" onClick={() => onSelect(entry)} className="grid w-full grid-cols-[40px_minmax(0,1fr)_20px] items-center gap-3 border-b border-[#F1F5F9] px-4 py-3 text-left last:border-b-0">
            <span className={`grid h-10 w-10 place-items-center rounded-xl text-sm font-black text-white ${parent ? "bg-gradient-to-br from-[#10B981] to-[#059669]" : "bg-gradient-to-br from-[#3B82F6] to-[#2563EB]"}`}>{initialFor(entry)}</span>
            <span className="min-w-0">
            <span className="block truncate text-sm font-black text-[#0F172A]">{fullName(entry) || entry.email || entry.id}</span>
              <span className="mt-0.5 block truncate text-xs font-medium text-[#64748B]">{parent ? `${entry.childrenIds.length} ${entry.childrenIds.length === 1 ? "child" : "children"}` : "Adult Student"}</span>
            </span>
            <ChevronRight size={20} className="text-[#CBD5E1]" />
          </button>
        );
      })}
    </div>
  );
}

function SelectedUserCard({ user, onClear }: { user: BillableUser; onClear: () => void }) {
  const parent = user.userType === "parent";
  return (
    <div className={`flex items-center gap-3 rounded-2xl bg-gradient-to-br p-4 text-white shadow-lg ${parent ? "from-[#0F172A] to-[#1E293B]" : "from-[#1E3A5F] to-[#1E293B]"}`}>
      <span className="grid h-11 w-11 place-items-center rounded-xl bg-white/15 text-lg font-black">{initialFor(user)}</span>
      <span className="min-w-0 flex-1">
        <span className="block truncate text-base font-black">{fullName(user) || user.email || user.id}</span>
        <span className="mt-0.5 block truncate text-xs font-medium text-white/70">{parent ? "Parent" : "Adult Student"}{user.email ? `  •  ${user.email}` : ""}</span>
      </span>
      <button type="button" aria-label="Clear selected user" onClick={onClear} className="grid h-8 w-8 place-items-center rounded-lg bg-white/10 text-white/80">
        <X size={18} />
      </button>
    </div>
  );
}

function AmountCard({ child, draft, onChange }: { child: BillableChild; draft: AmountDraft; onChange: (patch: Partial<AmountDraft>) => void }) {
  return (
    <article className="rounded-[14px] border border-[#E2E8F0] bg-white p-4 shadow-[0_2px_6px_rgba(0,0,0,0.03)]">
      <div className="flex items-center gap-3">
        <span className="grid h-9 w-9 place-items-center rounded-[10px] bg-gradient-to-br from-[#8B5CF6] to-[#7C3AED] text-sm font-black text-white">{initialFor(child)}</span>
        <h3 className="min-w-0 flex-1 truncate text-sm font-black text-[#0F172A]">{fullName(child) || child.id}</h3>
      </div>
      <label className="mt-4 grid gap-1.5 text-xs font-bold text-[#64748B]">
        Description
        <input value={draft.description} onChange={(event) => onChange({ description: event.target.value })} className="h-11 rounded-[10px] border border-[#E2E8F0] bg-[#F8FAFC] px-3 text-sm font-medium text-[#0F172A] outline-none focus:border-[#0386FF]" />
      </label>
      <label className="mt-3 grid gap-1.5 text-xs font-bold text-[#64748B]">
        Amount (USD)
        <span className="relative">
          <span className="absolute left-3 top-1/2 -translate-y-1/2 text-base font-black text-[#0F172A]">$</span>
          <input value={draft.amount} onChange={(event) => onChange({ amount: event.target.value.replace(/[^\d.]/g, "") })} inputMode="decimal" className="h-12 w-full rounded-[10px] border border-[#E2E8F0] bg-[#F8FAFC] pl-8 pr-3 text-base font-black text-[#0F172A] outline-none focus:border-[#0386FF]" />
        </span>
      </label>
    </article>
  );
}

function InvoiceTabButton({ active, icon: Icon, label, onClick }: { active: boolean; icon: typeof ReceiptText; label: string; onClick: () => void }) {
  return (
    <button type="button" onClick={onClick} className={`flex min-h-[74px] flex-col items-center justify-center gap-1 border-b-[2.5px] text-sm font-bold ${active ? "border-[#0386FF] text-[#0386FF]" : "border-transparent text-[#334155]"}`}>
      <Icon size={20} />
      <span>{label}</span>
    </button>
  );
}

function DateControl({ title, value, onPrevious, onNext }: { title: string; value: string; onPrevious: () => void; onNext: () => void }) {
  return (
    <section className="mt-5">
      <h2 className="text-sm font-bold text-[#334155]">{title}</h2>
      <div className="mt-3 grid min-h-12 grid-cols-[44px_1fr_44px] items-center rounded-[14px] border border-[#E2E8F0] bg-white shadow-[0_2px_6px_rgba(0,0,0,0.03)]">
        <button type="button" aria-label="Previous month" onClick={onPrevious} className="grid h-11 place-items-center text-[#64748B]"><ChevronLeft size={22} /></button>
        <span className="text-center text-sm font-black text-[#0F172A]">{value}</span>
        <button type="button" aria-label="Next month" onClick={onNext} className="grid h-11 place-items-center text-[#64748B]"><ChevronRight size={22} /></button>
      </div>
    </section>
  );
}

function LabeledDateInput({ compact = false, helper, label, min, tone = "normal", value, onChange }: { compact?: boolean; helper?: string; label: string; min?: string; tone?: "normal" | "warning"; value: string; onChange: (value: string) => void }) {
  return (
    <label className={`${compact ? "mt-0" : "mt-5"} grid gap-2 text-sm font-bold text-[#334155]`}>
      <span>{label}</span>
      {helper ? <span className="-mt-1 text-[11px] font-medium text-[#94A3B8]">{helper}</span> : null}
      <span className={`grid grid-cols-[40px_1fr] items-center rounded-[14px] border ${tone === "warning" ? "border-[#FDE68A] bg-[#FFFBEB]" : "border-[#E2E8F0] bg-white"} px-3 shadow-[0_2px_6px_rgba(0,0,0,0.03)]`}>
        <Calendar size={20} className={tone === "warning" ? "text-[#F59E0B]" : "text-[#059669]"} />
        <input type="date" min={min} value={value} onChange={(event) => onChange(event.target.value)} className={`h-12 bg-transparent text-sm font-black text-[#0F172A] outline-none ${compact ? "h-11" : ""}`} />
      </span>
    </label>
  );
}

function DialogField({ label, placeholder, value, onChange }: { label: string; placeholder?: string; value: string; onChange: (value: string) => void }) {
  return (
    <label className="grid gap-1.5 text-xs font-bold text-[#64748B]">
      {label}
      <input value={value} onChange={(event) => onChange(event.target.value)} placeholder={placeholder} className="h-11 rounded-[10px] border border-[#E2E8F0] bg-[#F8FAFC] px-3 text-sm font-semibold text-[#0F172A] outline-none focus:border-[#0386FF]" />
    </label>
  );
}

function InfoTag({ bold = false, color = "#64748B", icon: Icon, label }: { bold?: boolean; color?: string; icon: typeof Calendar; label: string }) {
  return (
    <span className="inline-flex min-h-8 items-center gap-1.5 rounded-lg border border-[#E2E8F0] bg-[#F8FAFC] px-2.5 text-xs font-semibold" style={{ color }}>
      <Icon size={14} />
      <span className={bold ? "font-black" : ""}>{label}</span>
    </span>
  );
}

function ActionButton({ icon: Icon, label, onClick, tone = "normal" }: { icon: typeof Download; label: string; onClick: () => void; tone?: "normal" | "danger" }) {
  const color = tone === "danger" ? "#DC2626" : "#334155";
  return (
    <button type="button" onClick={onClick} className="inline-flex min-h-10 shrink-0 items-center gap-1.5 rounded-[10px] border border-[#E2E8F0] bg-white px-3 text-[11px] font-bold" style={{ color }}>
      <Icon size={16} />
      {label}
    </button>
  );
}

function InvoicesAccessPrompt({ access }: { access: AccessState }) {
  if (access === "checking") {
    return (
      <main className="grid min-h-screen place-items-center bg-[#F8FAFC]">
        <div className="h-9 w-9 animate-spin rounded-full border-4 border-[#DBEAFE] border-t-[#0386FF]" />
      </main>
    );
  }
  return (
    <main className="grid min-h-screen place-items-center bg-[#F8FAFC] px-6 text-center">
      <div className="max-w-md rounded-2xl border border-[#E2E8F0] bg-white p-8 shadow-sm">
        <Lock size={36} className="mx-auto text-[#0386FF]" />
        <h1 className="mt-4 text-2xl font-black text-[#0F172A]">{access === "signedOut" ? "Admin sign-in required" : "Admin access required"}</h1>
        <p className="mt-2 text-sm leading-6 text-[#64748B]">Sign in with an administrator account to manage invoices.</p>
        <Link href="/login/" className="mt-6 inline-flex min-h-11 items-center justify-center rounded-xl bg-[#0386FF] px-5 text-sm font-black text-white">
          Go to login
        </Link>
      </div>
    </main>
  );
}

async function loadBillableUsers() {
  const [parentsSnap, adultStudentsSnap] = await Promise.all([
    getDocs(query(collection(db, "users"), where("user_type", "==", "parent"), limit(500))),
    getDocs(query(collection(db, "users"), where("user_type", "==", "student"), where("is_adult_student", "==", true), limit(500))),
  ]);
  const users = [...parentsSnap.docs, ...adultStudentsSnap.docs].map((entry) => normalizeBillableUser(entry.id, entry.data()));
  return users.sort((a, b) => fullName(a).localeCompare(fullName(b)));
}

async function loadChildrenFor(user: BillableUser) {
  if (user.userType !== "parent") return [{ id: user.id, firstName: user.firstName, lastName: user.lastName }];
  const children = await Promise.all(user.childrenIds.map(async (childId) => {
    const childDoc = await getDoc(doc(db, "users", childId));
    if (!childDoc.exists()) return null;
    const data = childDoc.data();
    return {
      id: childDoc.id,
      firstName: stringValue(data.first_name ?? data.firstName),
      lastName: stringValue(data.last_name ?? data.lastName),
    };
  }));
  return children.filter((child): child is BillableChild => child !== null);
}

async function loadInvoices() {
  const snapshot = await getDocs(query(collection(db, "invoices"), limit(200)));
  return snapshot.docs.map((entry) => normalizeInvoice(entry.id, entry.data())).sort((a, b) => (b.createdAt?.getTime() ?? 0) - (a.createdAt?.getTime() ?? 0));
}

async function loadUserNames(ids: string[]) {
  const uniqueIds = Array.from(new Set(ids.filter(Boolean)));
  const entries = await Promise.all(uniqueIds.map(async (id) => {
    const userDoc = await getDoc(doc(db, "users", id));
    if (!userDoc.exists()) return [id, id] as const;
    const data = userDoc.data();
    const name = [stringValue(data.first_name ?? data.firstName), stringValue(data.last_name ?? data.lastName)].filter(Boolean).join(" ");
    return [id, name || id] as const;
  }));
  return Object.fromEntries(entries);
}

function normalizeBillableUser(id: string, data: Record<string, unknown>): BillableUser {
  const userType = stringValue(data.user_type ?? data.userType) === "student" ? "student" : "parent";
  return {
    id,
    firstName: stringValue(data.first_name ?? data.firstName),
    lastName: stringValue(data.last_name ?? data.lastName),
    email: stringValue(data["e-mail"] ?? data.email),
    userType,
    childrenIds: arrayOfStrings(data.children_ids ?? data.childrenIds),
    isAdultStudent: data.is_adult_student === true || data.isAdultStudent === true,
  };
}

function normalizeInvoice(id: string, data: Record<string, unknown>): InvoiceRecord {
  const items = Array.isArray(data.items) ? data.items.map((item) => normalizeInvoiceItem(recordValue(item))) : [];
  return {
    id,
    invoiceNumber: stringValue(data.invoice_number ?? data.invoiceNumber),
    parentId: stringValue(data.parent_id ?? data.parentId),
    studentId: stringValue(data.student_id ?? data.studentId),
    status: normalizeStatus(data.status),
    totalAmount: numberValue(data.total_amount ?? data.totalAmount),
    paidAmount: numberValue(data.paid_amount ?? data.paidAmount),
    currency: stringValue(data.currency) || "USD",
    issuedDate: dateValue(data.issued_date ?? data.issuedDate),
    dueDate: dateValue(data.due_date ?? data.dueDate),
    accessCutoffDate: dateValue(data.access_cutoff_date ?? data.accessCutoffDate),
    period: stringValue(data.period ?? data.billing_period ?? data.billingPeriod),
    items,
    createdAt: dateValue(data.created_at ?? data.createdAt),
  };
}

function normalizeInvoiceItem(data: Record<string, unknown>): InvoiceItem {
  return {
    description: stringValue(data.description),
    quantity: numberValue(data.quantity) || 1,
    unitPrice: numberValue(data.unit_price ?? data.unitPrice),
    total: numberValue(data.total),
  };
}

function normalizeStatus(value: unknown): InvoiceStatus {
  const raw = stringValue(value).toLowerCase();
  if (raw === "paid" || raw === "overdue" || raw === "cancelled") return raw;
  return "pending";
}

function recordValue(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : {};
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value : value == null ? "" : String(value);
}

function arrayOfStrings(value: unknown) {
  return Array.isArray(value) ? value.map(stringValue).filter(Boolean) : [];
}

function numberValue(value: unknown) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return 0;
}

function dateValue(value: unknown): Date | null {
  if (!value) return null;
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === "string") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  if (typeof value === "object" && "toDate" in value && typeof (value as { toDate?: unknown }).toDate === "function") {
    return (value as { toDate: () => Date }).toDate();
  }
  return null;
}

function fullName(user: { firstName: string; lastName: string }) {
  return [user.firstName, user.lastName].filter(Boolean).join(" ").trim();
}

function initialFor(user: { firstName: string; lastName: string; email?: string; id?: string }) {
  return (fullName(user)[0] || user.email?.[0] || user.id?.[0] || "?").toUpperCase();
}

function initialsFor(user: User | null) {
  const name = user?.displayName || user?.email || "Admin";
  return name.split(/\s+/).filter(Boolean).slice(0, 2).map((part) => part[0]?.toUpperCase()).join("") || "AD";
}

function startOfMonth(date: Date) {
  return new Date(date.getFullYear(), date.getMonth(), 1);
}

function addDays(date: Date, days: number) {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
}

function formatDateInput(date: Date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function formatPeriod(date: Date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}`;
}

function formatMonth(date: Date) {
  return new Intl.DateTimeFormat("en-US", { month: "long", year: "numeric" }).format(date);
}

function formatShortDate(date: Date) {
  return new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric", year: "numeric" }).format(date);
}

function formatMoney(value: number, currency: string) {
  return new Intl.NumberFormat("en-US", { style: "currency", currency: currency || "USD" }).format(value);
}

function displayBillingPeriod(period: string) {
  const parts = period.split("-");
  const year = Number(parts[0]);
  const month = Number(parts[1]);
  if (Number.isFinite(year) && Number.isFinite(month) && month >= 1 && month <= 12) return formatMonth(new Date(year, month - 1, 1));
  return period;
}

function isInvoiceOverdue(invoice: InvoiceRecord) {
  if (!invoice.dueDate || invoice.status === "cancelled" || invoice.status === "paid") return false;
  return remainingBalance(invoice) > 0 && Date.now() > invoice.dueDate.getTime();
}

function remainingBalance(invoice: InvoiceRecord) {
  return Math.max(0, invoice.totalAmount - invoice.paidAmount);
}

function statusColorFor(status: InvoiceStatus) {
  if (status === "paid") return "#16A34A";
  if (status === "cancelled") return "#6B7280";
  if (status === "overdue") return "#DC2626";
  return "#F59E0B";
}
