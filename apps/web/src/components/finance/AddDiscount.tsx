"use client";

import { deleteField, doc, getDoc, getDocs, collection, limit, query, serverTimestamp, Timestamp, updateDoc, where } from "firebase/firestore";
import { useEffect, useMemo, useState } from "react";
import { DiscountDialog } from "@/components/discounts/DiscountDialog";
import { auth, db } from "@/lib/firebase";
import { draftToDiscount, readDiscount, type DiscountDraft, type StudentDiscount } from "@/lib/studentDiscount";
import { matchFamilies } from "@/lib/finance/invoicePicker";

type StudentRow = { id: string; name: string; email: string; phone: string; code: string; parentId: string; discount: StudentDiscount | null };

const str = (v: unknown) => (typeof v === "string" ? v.trim() : v == null ? "" : String(v).trim());
const nameOf = (d: Record<string, unknown>) => `${str(d.first_name ?? d.firstName)} ${str(d.last_name ?? d.lastName)}`.trim();
const firstOf = (v: unknown) => (Array.isArray(v) ? str(v.find((x) => typeof x === "string" && x.trim())) : "");

/**
 * Finance → Discounts: give any student (or their whole family) a discount,
 * not only new applicants. Writes the same users[].discount record the
 * Applicants screen writes, so invoices and the monthly run pick it up.
 */
export function AddDiscount({ onSaved }: { onSaved: (message: string) => void }) {
  const [open, setOpen] = useState(false);
  const [students, setStudents] = useState<StudentRow[] | null>(null);
  const [search, setSearch] = useState("");
  const [picked, setPicked] = useState<StudentRow | null>(null);
  const [familyDiscount, setFamilyDiscount] = useState<StudentDiscount | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!open || students) return;
    let alive = true;
    getDocs(query(collection(db, "users"), where("user_type", "==", "student"), limit(1500)))
      .then((snap) => {
        if (!alive) return;
        const rows = snap.docs
          .map((d) => {
            const data = d.data() as Record<string, unknown>;
            return {
              id: d.id,
              name: nameOf(data) || d.id,
              email: str(data["e-mail"] ?? data.email),
              phone: `${str(data.country_code)}${str(data.phone_number ?? data.phoneNumber)}`.replace(/\D/g, ""),
              code: str(data.student_code ?? data.studentCode),
              parentId: firstOf(data.guardian_ids) || firstOf(data.guardianIds),
              discount: readDiscount(data.discount),
              active: data.is_active !== false,
            };
          })
          .filter((r) => r.active)
          .map(({ active: _active, ...r }) => r)
          .sort((a, b) => a.name.localeCompare(b.name));
        setStudents(rows);
      })
      .catch(() => alive && setError("Students could not load. Try again."));
    return () => {
      alive = false;
    };
  }, [open, students]);

  const matches = useMemo(() => (students ? matchFamilies(students, search) : []), [students, search]);

  const pick = async (row: StudentRow) => {
    setError("");
    setFamilyDiscount(null);
    if (row.parentId) {
      try {
        const snap = await getDoc(doc(db, "users", row.parentId));
        setFamilyDiscount(snap.exists() ? readDiscount((snap.data() as Record<string, unknown>).discount) : null);
      } catch {
        setFamilyDiscount(null);
      }
    }
    setPicked(row);
  };

  const close = () => {
    setPicked(null);
    setSearch("");
    setOpen(false);
  };

  const save = async (draft: DiscountDraft) => {
    if (!picked) return;
    const admin = auth.currentUser;
    if (!admin) {
      setError("Sign in again before changing a discount.");
      return;
    }
    const forFamily = draft.scope === "family";
    if (forFamily && !picked.parentId) {
      setError("Link a parent first. A family discount is held on the parent's account.");
      return;
    }
    const discount = draftToDiscount(draft);
    await updateDoc(doc(db, "users", forFamily ? picked.parentId : picked.id), {
      discount: {
        mode: discount.mode,
        scope: discount.scope ?? "student",
        value: discount.value,
        duration: discount.duration,
        ...(discount.months ? { months: discount.months } : {}),
        startDate: Timestamp.fromDate(discount.startDate),
        reason: discount.reason,
        ...(discount.note ? { note: discount.note } : {}),
        createdBy: admin.uid,
        createdByName: admin.email ?? "Admin",
        createdAt: serverTimestamp(),
      },
    });
    setStudents(null);
    close();
    onSaved(`Discount saved for ${forFamily ? `${picked.name}'s family` : picked.name}.`);
  };

  const remove = async () => {
    if (!picked) return;
    await updateDoc(doc(db, "users", picked.id), { discount: deleteField() });
    if (picked.parentId && familyDiscount) await updateDoc(doc(db, "users", picked.parentId), { discount: deleteField() });
    setStudents(null);
    close();
    onSaved(`Discount removed for ${picked.name}.`);
  };

  if (picked) {
    return (
      <DiscountDialog
        studentName={picked.name}
        existing={picked.discount}
        familyExisting={familyDiscount}
        canApplyToFamily={Boolean(picked.parentId)}
        defaultStartDate={new Date()}
        onSave={save}
        onRemove={remove}
        onClose={close}
      />
    );
  }

  if (!open) {
    return (
      <button type="button" className="h-9 rounded-lg bg-[#0369D9] px-3 text-sm font-bold text-white" onClick={() => setOpen(true)}>
        Add a discount
      </button>
    );
  }

  return (
    <div className="flex w-full flex-col gap-2 rounded-xl border border-slate-200 bg-white p-3">
      <div className="flex items-center gap-2">
        <label className="flex flex-1 flex-col gap-1 text-sm font-semibold text-slate-700">
          Student
          <input
            className="h-10 rounded-lg border border-slate-300 bg-white px-2.5 text-sm text-slate-900"
            type="text"
            autoFocus
            value={search}
            placeholder={students ? "Name, email, phone or Student ID" : "Loading students…"}
            disabled={!students}
            onChange={(e) => setSearch(e.target.value)}
          />
        </label>
        <button type="button" className="mt-6 h-10 rounded-lg border border-slate-300 bg-white px-3 text-sm font-semibold" onClick={close}>
          Cancel
        </button>
      </div>
      {error ? <p className="m-0 text-sm font-semibold text-red-800">{error}</p> : null}
      {matches.length > 0 ? (
        <ul className="m-0 flex list-none flex-col overflow-hidden rounded-lg border border-slate-200 p-0">
          {matches.map((s) => (
            <li key={s.id} className="border-b border-slate-200 last:border-b-0">
              <button type="button" className="flex min-h-11 w-full flex-col items-start px-3 py-1.5 text-left text-sm hover:bg-slate-50" onClick={() => void pick(s)}>
                <span className="font-semibold">{s.name}</span>
                <span className="text-xs text-slate-600">
                  {[s.code, s.email].filter(Boolean).join(" · ")}
                  {s.discount ? " · has a discount" : ""}
                </span>
              </button>
            </li>
          ))}
        </ul>
      ) : search.trim() && students ? (
        <p className="m-0 text-xs text-slate-600">No student matches “{search.trim()}”.</p>
      ) : null}
    </div>
  );
}
