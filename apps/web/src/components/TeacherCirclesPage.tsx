"use client";

import { onAuthStateChanged, type User } from "firebase/auth";
import {
  addDoc,
  collection,
  doc,
  getDoc,
  getDocs,
  limit,
  onSnapshot,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
  writeBatch,
  increment,
} from "firebase/firestore";
import {
  deleteObject,
  getDownloadURL,
  ref,
  uploadBytes,
} from "firebase/storage";
import {
  AlertTriangle,
  CheckCircle2,
  CircleDollarSign,
  Clock3,
  Crown,
  Menu,
  Plus,
  RefreshCw,
  Send,
  Upload,
  UserPlus,
  Users,
  X,
} from "lucide-react";
import { useCallback, useEffect, useMemo, useState } from "react";
import {
  TeacherAccessPrompt,
  TeacherShell,
  openTeacherMobileMenu,
} from "@/components/TeacherDashboardHome";
import { auth, db, storage } from "@/lib/firebase";
import { getCurrentUserRecord, isCurrentUserTeacher } from "@/lib/userRoles";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type Data = Record<string, unknown>;
type Item = Data & { id: string };

export function TeacherCirclesPage() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [enabled, setEnabled] = useState(false);
  const [user, setUser] = useState<User | null>(null);
  const [summary, setSummary] = useState({
    displayName: "Teacher",
    firstName: "Teacher",
    initials: "TE",
  });
  const [memberships, setMemberships] = useState<Item[]>([]);
  const [invites, setInvites] = useState<Item[]>([]);
  const [openCircles, setOpenCircles] = useState<Item[]>([]);
  const [circles, setCircles] = useState<Item[]>([]);
  const [selected, setSelected] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [createOpen, setCreateOpen] = useState(false);
  useEffect(
    () =>
      onAuthStateChanged(auth, async (nextUser) => {
        setUser(nextUser);
        if (!nextUser) {
          setAccess("signedOut");
          return;
        }
        if (!(await isCurrentUserTeacher(nextUser))) {
          setAccess("denied");
          return;
        }
        const record = await getCurrentUserRecord(nextUser);
        const displayName = nameFor(record, nextUser);
        setSummary({
          displayName,
          firstName: displayName.split(/\s+/)[0] || "Teacher",
          initials: initials(displayName),
        });
        setEnabled(record?.tontine_enabled === true);
        setAccess("allowed");
      }),
    [],
  );
  const load = useCallback(async () => {
    if (!user || !enabled) {
      setLoading(false);
      return;
    }
    setLoading(true);
    setError("");
    try {
      const [memberSnap, inviteSnap, openSnap] = await Promise.all([
        getDocs(
          query(
            collection(db, "circle_members"),
            where("user_id", "==", user.uid),
          ),
        ),
        getDocs(
          query(
            collection(db, "circle_invites"),
            where("existing_user_id", "==", user.uid),
            where("status", "==", "pending"),
          ),
        ),
        getDocs(
          query(
            collection(db, "circles"),
            where("type", "==", "teacher"),
            where("enrollment_mode", "==", "open"),
            where("status", "==", "forming"),
          ),
        ),
      ]);
      const memberItems = memberSnap.docs.map(item);
      setMemberships(memberItems);
      setInvites(inviteSnap.docs.map(item));
      setOpenCircles(openSnap.docs.map(item));
      const ids = [
        ...new Set(
          memberItems
            .filter((m) =>
              ["active", "suspended", "completed"].includes(text(m.status)),
            )
            .map((m) => text(m.circle_id))
            .filter(Boolean),
        ),
      ];
      const circleDocs = await Promise.all(
        ids.map((id) => getDoc(doc(db, "circles", id))),
      );
      setCircles(
        circleDocs
          .filter((snap) => snap.exists())
          .map((snap) => ({ id: snap.id, ...snap.data() })),
      );
    } catch (cause) {
      setError(actionError(cause, "Could not load savings circles."));
    } finally {
      setLoading(false);
    }
  }, [user, enabled]);
  useEffect(() => {
    void load();
  }, [load]);
  if (access !== "allowed") return <TeacherAccessPrompt access={access} />;
  return (
    <TeacherShell
      activeLabel="Circles"
      breadcrumb="Savings / Circles"
      summary={summary}
    >
      <div className="min-h-full bg-[#F8FAFC]">
        <MobileHeader />
        {!enabled ? (
          <div className="mx-auto max-w-xl p-6">
            <ErrorCard message="Savings Circles have not been enabled for your account. Please contact an administrator." />
          </div>
        ) : selected ? (
          <CircleDetail
            circleId={selected}
            user={user!}
            onBack={() => setSelected("")}
          />
        ) : (
          <div className="mx-auto max-w-6xl p-4 sm:p-6 lg:p-8">
            <section className="rounded-3xl bg-gradient-to-br from-[#0F766E] to-[#10B981] p-6 text-white shadow-lg sm:p-8">
              <div className="flex flex-wrap items-start justify-between gap-4">
                <div>
                  <h1 className="text-3xl font-black">Savings Circles</h1>
                  <p className="mt-2 max-w-2xl text-emerald-50">
                    Save together, contribute on schedule, and follow every
                    payout transparently.
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => setCreateOpen(true)}
                  className="inline-flex min-h-11 items-center gap-2 rounded-xl bg-white px-4 font-extrabold text-[#0F766E]"
                >
                  <Plus size={19} />
                  Create Circle
                </button>
              </div>
            </section>
            {error ? <Alert message={error} /> : null}
            {notice ? (
              <p
                role="status"
                className="mt-5 rounded-xl bg-emerald-50 p-4 font-semibold text-emerald-800"
              >
                {notice}
              </p>
            ) : null}
            {loading ? (
              <div className="grid min-h-64 place-items-center">
                <RefreshCw className="animate-spin text-[#0F766E]" />
              </div>
            ) : (
              <>
                <InviteSection
                  invites={invites}
                  onAccept={async (invite) => {
                    try {
                      await acceptInvite(invite, user!);
                      setNotice("Invitation accepted successfully.");
                      await load();
                      setSelected(text(invite.circle_id));
                    } catch (cause) {
                      setError(
                        actionError(cause, "Could not accept the invitation."),
                      );
                    }
                  }}
                />
                <OpenSection
                  circles={openCircles.filter(
                    (circle) =>
                      !memberships.some((m) => text(m.circle_id) === circle.id),
                  )}
                  onJoin={async (circle) => {
                    try {
                      await joinOpenCircle(circle, user!, summary.displayName);
                      setNotice("You joined the circle successfully.");
                      await load();
                      setSelected(circle.id);
                    } catch (cause) {
                      setError(
                        actionError(cause, "Could not join this circle."),
                      );
                    }
                  }}
                />
                <section className="mt-6">
                  <h2 className="text-xl font-extrabold text-[#111827]">
                    My Circles
                  </h2>
                  {circles.length ? (
                    <div className="mt-3 grid gap-4 md:grid-cols-2">
                      {circles.map((circle) => (
                        <CircleCard
                          key={circle.id}
                          circle={circle}
                          created={text(circle.created_by) === user?.uid}
                          onOpen={() => setSelected(circle.id)}
                        />
                      ))}
                    </div>
                  ) : (
                    <Empty onCreate={() => setCreateOpen(true)} />
                  )}
                </section>
              </>
            )}
            {createOpen ? (
              <CreateCircle
                user={user!}
                displayName={summary.displayName}
                onClose={() => setCreateOpen(false)}
                onCreated={async (id) => {
                  setCreateOpen(false);
                  setNotice("Circle created successfully.");
                  await load();
                  setSelected(id);
                }}
              />
            ) : null}
          </div>
        )}
      </div>
    </TeacherShell>
  );
}

function CircleDetail({
  circleId,
  user,
  onBack,
}: {
  circleId: string;
  user: User;
  onBack: () => void;
}) {
  const [circle, setCircle] = useState<Item | null>(null);
  const [members, setMembers] = useState<Item[]>([]);
  const [cycle, setCycle] = useState<Item | null>(null);
  const [contributions, setContributions] = useState<Item[]>([]);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [payOpen, setPayOpen] = useState(false);
  const [inviteOpen, setInviteOpen] = useState(false);
  const load = useCallback(async () => {
    try {
      const circleSnap = await getDoc(doc(db, "circles", circleId));
      if (!circleSnap.exists()) {
        setCircle(null);
        return;
      }
      setCircle({ id: circleSnap.id, ...circleSnap.data() });
      const memberSnap = await getDocs(
        query(
          collection(db, "circle_members"),
          where("circle_id", "==", circleId),
        ),
      );
      const memberItems = memberSnap.docs
        .map(item)
        .sort((a, b) => number(a.payout_position) - number(b.payout_position));
      setMembers(memberItems);
      const cycleSnap = await getDocs(
        query(
          collection(db, "circle_cycles"),
          where("circle_id", "==", circleId),
          orderBy("cycle_number", "desc"),
          limit(1),
        ),
      );
      const current = cycleSnap.docs[0] ? item(cycleSnap.docs[0]) : null;
      setCycle(current);
      if (current) {
        const contributionSnap = await getDocs(
          query(
            collection(db, "circle_contributions"),
            where("cycle_id", "==", current.id),
          ),
        );
        setContributions(contributionSnap.docs.map(item));
      } else setContributions([]);
    } catch (cause) {
      setError(actionError(cause, "Could not load circle details."));
    }
  }, [circleId]);
  useEffect(() => {
    void load();
  }, [load]);
  if (!circle)
    return (
      <div className="p-6">
        <button onClick={onBack} className="font-bold text-[#0F766E]">
          ← Back to circles
        </button>
        {error ? (
          <Alert message={error} />
        ) : (
          <div className="grid min-h-64 place-items-center">
            <RefreshCw className="animate-spin" />
          </div>
        )}
      </div>
    );
  const mine = members.find((m) => text(m.user_id) === user.uid);
  const isHead =
    mine?.is_tontine_head === true || text(circle.created_by) === user.uid;
  const myContribution = contributions.find(
    (c) => text(c.user_id) === user.uid,
  );
  const active = members.filter((m) => text(m.status) === "active");
  const confirmed = contributions.filter((c) => text(c.status) === "confirmed");
  const totalPot =
    number(circle.contribution_amount) * number(circle.total_members);
  return (
    <div className="mx-auto max-w-6xl p-4 sm:p-6 lg:p-8">
      <button
        type="button"
        onClick={onBack}
        className="mb-4 font-bold text-[#0F766E]"
      >
        ← Back to circles
      </button>
      <section className="rounded-3xl bg-gradient-to-br from-[#0F766E] to-[#10B981] p-6 text-white">
        <div className="flex flex-wrap justify-between gap-4">
          <div>
            <p className="text-sm font-bold text-emerald-100">
              {text(circle.status).toUpperCase()}
            </p>
            <h1 className="mt-1 text-3xl font-black">{text(circle.title)}</h1>
            <p className="mt-2">
              {money(circle)} · {frequency(circle)}
            </p>
          </div>
          <div className="text-right">
            <p className="text-sm text-emerald-100">Total pot</p>
            <p className="text-3xl font-black">
              {currency(text(circle.currency), totalPot)}
            </p>
          </div>
        </div>
      </section>
      {error ? <Alert message={error} /> : null}
      {notice ? (
        <p
          role="status"
          className="mt-4 rounded-xl bg-emerald-50 p-4 font-semibold text-emerald-800"
        >
          {notice}
        </p>
      ) : null}
      <div className="mt-5 grid gap-5 lg:grid-cols-[1fr_340px]">
        <div className="space-y-5">
          <section className="rounded-2xl border border-[#E2E8F0] bg-white p-5">
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-extrabold">Current Cycle</h2>
              {cycle ? <Status value={text(cycle.status)} /> : null}
            </div>
            {cycle ? (
              <div className="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-4">
                <Metric
                  label="Cycle"
                  value={`#${number(cycle.cycle_number)}`}
                />
                <Metric label="Due" value={dateLabel(cycle.due_date)} />
                <Metric
                  label="Collected"
                  value={currency(
                    text(circle.currency),
                    number(cycle.total_collected),
                  )}
                />
                <Metric
                  label="Confirmed"
                  value={`${confirmed.length}/${active.length}`}
                />
              </div>
            ) : (
              <p className="mt-3 text-[#64748B]">
                The first cycle begins when the circle is activated.
              </p>
            )}
          </section>
          <section className="rounded-2xl border border-[#E2E8F0] bg-white p-5">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <h2 className="text-lg font-extrabold">
                Payout Order & Payments
              </h2>
              {isHead ? (
                <button
                  type="button"
                  onClick={() => setInviteOpen(true)}
                  className="inline-flex min-h-10 items-center gap-2 rounded-xl border border-[#0F766E] px-3 text-sm font-bold text-[#0F766E]"
                >
                  <UserPlus size={17} />
                  Invite Member
                </button>
              ) : null}
            </div>
            <div className="mt-3 divide-y divide-[#E2E8F0]">
              {members.map((member) => {
                const contribution = contributions.find(
                  (c) => text(c.user_id) === text(member.user_id),
                );
                return (
                  <div key={member.id} className="flex items-center gap-3 py-3">
                    <span className="grid h-10 w-10 place-items-center rounded-full bg-emerald-100 font-black text-emerald-700">
                      {number(member.payout_position)}
                    </span>
                    <div className="min-w-0 flex-1">
                      <p className="truncate font-bold">
                        {text(member.display_name) || "Member"}
                        {member.is_tontine_head === true ? " · Head" : ""}
                      </p>
                      <p className="text-xs text-[#64748B]">
                        {text(member.status)}
                      </p>
                    </div>
                    <Status value={text(contribution?.status) || "pending"} />
                    {isHead && text(contribution?.status) === "submitted" ? (
                      <div className="flex gap-1">
                        <button
                          aria-label={`Confirm ${text(member.display_name)}`}
                          onClick={async () => {
                            await updateDoc(
                              doc(db, "circle_contributions", contribution!.id),
                              {
                                status: "confirmed",
                                confirmed_at: serverTimestamp(),
                                confirmed_by: user.uid,
                              },
                            );
                            setNotice("Payment confirmed.");
                            await load();
                          }}
                          className="grid h-9 w-9 place-items-center rounded-lg text-emerald-600"
                        >
                          <CheckCircle2 size={18} />
                        </button>
                        <button
                          aria-label={`Reject ${text(member.display_name)}`}
                          onClick={async () => {
                            const reason = window.prompt(
                              "Reason for rejection",
                            );
                            if (!reason?.trim()) return;
                            await updateDoc(
                              doc(db, "circle_contributions", contribution!.id),
                              {
                                status: "rejected",
                                rejection_reason: reason.trim(),
                              },
                            );
                            setNotice("Payment rejected.");
                            await load();
                          }}
                          className="grid h-9 w-9 place-items-center rounded-lg text-red-600"
                        >
                          <X size={18} />
                        </button>
                      </div>
                    ) : null}
                  </div>
                );
              })}
            </div>
          </section>
        </div>
        <aside className="space-y-4">
          <section className="rounded-2xl border border-[#E2E8F0] bg-white p-5">
            <h2 className="font-extrabold">Actions</h2>
            {cycle &&
            !isHead &&
            text(myContribution?.status) !== "confirmed" ? (
              <button
                type="button"
                onClick={() => setPayOpen(true)}
                className="mt-4 flex min-h-11 w-full items-center justify-center gap-2 rounded-xl bg-[#0F766E] font-bold text-white"
              >
                <Upload size={18} />
                Submit Payment
              </button>
            ) : null}
            {isHead && text(circle.status) === "forming" ? (
              <button
                type="button"
                disabled={active.length !== number(circle.total_members)}
                onClick={async () => {
                  try {
                    await updateDoc(doc(db, "circles", circleId), {
                      status: "active",
                    });
                    setNotice("Circle activated successfully.");
                    await load();
                  } catch (cause) {
                    setError(
                      actionError(cause, "Could not activate the circle."),
                    );
                  }
                }}
                className="mt-3 min-h-11 w-full rounded-xl bg-[#0F766E] font-bold text-white disabled:opacity-40"
              >
                Activate Circle
              </button>
            ) : null}
            {isHead &&
            cycle &&
            confirmed.length === active.length &&
            text(cycle.status) !== "completed" ? (
              <button
                type="button"
                onClick={async () => {
                  await updateDoc(doc(db, "circle_cycles", cycle.id), {
                    status: "completed",
                    payout_sent_at: serverTimestamp(),
                  });
                  setNotice("Payout marked as sent.");
                  await load();
                }}
                className="mt-3 min-h-11 w-full rounded-xl border border-[#0F766E] font-bold text-[#0F766E]"
              >
                Mark Payout Sent
              </button>
            ) : null}
            <p className="mt-4 whitespace-pre-wrap text-sm text-[#64748B]">
              {text(circle.payment_instructions) ||
                "No payment instructions provided."}
            </p>
          </section>
        </aside>
      </div>
      {payOpen && cycle ? (
        <PaymentDialog
          circle={circle}
          cycle={cycle}
          user={user}
          member={mine}
          existing={myContribution}
          onClose={() => setPayOpen(false)}
          onSaved={async () => {
            setPayOpen(false);
            setNotice("Payment submitted for review.");
            await load();
          }}
        />
      ) : null}
      {inviteOpen ? (
        <InviteDialog
          circle={circle}
          members={members}
          user={user}
          onClose={() => setInviteOpen(false)}
          onSaved={async () => {
            setInviteOpen(false);
            setNotice("Member invitation created.");
            await load();
          }}
        />
      ) : null}
    </div>
  );
}

function InviteSection({
  invites,
  onAccept,
}: {
  invites: Item[];
  onAccept: (invite: Item) => void;
}) {
  if (!invites.length) return null;
  return (
    <section className="mt-6 rounded-2xl border border-amber-200 bg-amber-50 p-5">
      <h2 className="font-extrabold text-amber-950">Pending Invitations</h2>
      <div className="mt-3 space-y-3">
        {invites.map((invite) => (
          <div
            key={invite.id}
            className="flex flex-wrap items-center gap-3 rounded-xl bg-white p-4"
          >
            <div className="min-w-0 flex-1">
              <p className="font-bold">
                {text(invite.circle_name) || "Savings Circle"}
              </p>
              <p className="text-sm text-[#64748B]">
                You have been invited to join.
              </p>
            </div>
            <button
              onClick={() => onAccept(invite)}
              className="min-h-10 rounded-xl bg-amber-600 px-4 font-bold text-white"
            >
              Review & Join
            </button>
          </div>
        ))}
      </div>
    </section>
  );
}
function OpenSection({
  circles,
  onJoin,
}: {
  circles: Item[];
  onJoin: (circle: Item) => void;
}) {
  if (!circles.length) return null;
  return (
    <section className="mt-6">
      <h2 className="text-xl font-extrabold">Available Teacher Circles</h2>
      <div className="mt-3 grid gap-4 md:grid-cols-2">
        {circles.map((circle) => (
          <div
            key={circle.id}
            className="rounded-2xl border border-[#E2E8F0] bg-white p-5"
          >
            <h3 className="font-extrabold">{text(circle.title)}</h3>
            <p className="mt-1 text-sm text-[#64748B]">
              {money(circle)} · {frequency(circle)}
            </p>
            <button
              onClick={() => onJoin(circle)}
              className="mt-4 min-h-10 w-full rounded-xl bg-[#0F766E] font-bold text-white"
            >
              Join Circle
            </button>
          </div>
        ))}
      </div>
    </section>
  );
}
function CircleCard({
  circle,
  created,
  onOpen,
}: {
  circle: Item;
  created: boolean;
  onOpen: () => void;
}) {
  return (
    <button
      onClick={onOpen}
      className="rounded-2xl border border-[#E2E8F0] bg-white p-5 text-left shadow-sm hover:border-emerald-400"
    >
      <div className="flex items-start justify-between">
        <span className="grid h-11 w-11 place-items-center rounded-xl bg-emerald-100 text-emerald-700">
          {created ? <Crown size={21} /> : <Users size={21} />}
        </span>
        <Status value={text(circle.status)} />
      </div>
      <h3 className="mt-4 text-lg font-extrabold">{text(circle.title)}</h3>
      <p className="mt-1 text-sm text-[#64748B]">
        {money(circle)} · {frequency(circle)}
      </p>
      <p className="mt-3 text-xs font-bold uppercase text-[#94A3B8]">
        {created ? "Created by you" : "Joined circle"}
      </p>
    </button>
  );
}
function CreateCircle({
  user,
  displayName,
  onClose,
  onCreated,
}: {
  user: User;
  displayName: string;
  onClose: () => void;
  onCreated: (id: string) => void;
}) {
  const [title, setTitle] = useState("");
  const [amount, setAmount] = useState("");
  const [currencyCode, setCurrency] = useState("USD");
  const [frequencyValue, setFrequency] = useState("monthly");
  const [start, setStart] = useState("");
  const [instructions, setInstructions] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  async function save() {
    if (!title.trim() || number(amount) <= 0 || !start) {
      setError("Title, contribution amount, and start date are required.");
      return;
    }
    setBusy(true);
    try {
      const circleRef = doc(collection(db, "circles"));
      const memberRef = doc(collection(db, "circle_members"));
      const batch = writeBatch(db);
      batch.set(circleRef, {
        title: title.trim(),
        type: "teacher",
        status: "forming",
        contribution_amount: number(amount),
        currency: currencyCode,
        frequency: frequencyValue,
        total_members: 1,
        current_cycle_index: 0,
        created_by: user.uid,
        created_at: serverTimestamp(),
        start_date: Timestamp.fromDate(new Date(`${start}T12:00:00`)),
        rules: { grace_period_days: 3, missed_payment_action: "move_to_back" },
        payment_instructions: instructions.trim(),
        enrollment_mode: "manual",
      });
      batch.set(memberRef, {
        circle_id: circleRef.id,
        user_id: user.uid,
        display_name: displayName,
        photo_url: null,
        contact_info: user.email || "",
        is_tontine_head: true,
        payout_position: 1,
        status: "active",
        joined_at: serverTimestamp(),
        total_contributed: 0,
        total_received: 0,
        has_received_payout: false,
      });
      await batch.commit();
      onCreated(circleRef.id);
    } catch (cause) {
      setError(actionError(cause, "Could not create the circle."));
      setBusy(false);
    }
  }
  return (
    <Modal label="Create savings circle" onClose={onClose}>
      <h2 className="text-xl font-extrabold">Create Circle</h2>
      <div className="mt-5 space-y-4">
        <Field label="Circle name" value={title} onChange={setTitle} />
        <Field
          label="Contribution amount"
          value={amount}
          onChange={setAmount}
          type="number"
        />
        <label className="block text-sm font-bold">
          Currency
          <select
            value={currencyCode}
            onChange={(e) => setCurrency(e.target.value)}
            className="mt-2 h-11 w-full rounded-xl border px-3"
          >
            <option>USD</option>
            <option>CAD</option>
            <option>EUR</option>
            <option>GBP</option>
          </select>
        </label>
        <label className="block text-sm font-bold">
          Frequency
          <select
            value={frequencyValue}
            onChange={(e) => setFrequency(e.target.value)}
            className="mt-2 h-11 w-full rounded-xl border px-3"
          >
            <option value="weekly">Weekly</option>
            <option value="biweekly">Biweekly</option>
            <option value="monthly">Monthly</option>
            <option value="quarterly">Quarterly</option>
          </select>
        </label>
        <Field
          label="Start date"
          value={start}
          onChange={setStart}
          type="date"
        />
        <label className="block text-sm font-bold">
          Payment instructions
          <textarea
            value={instructions}
            onChange={(e) => setInstructions(e.target.value)}
            rows={3}
            className="mt-2 w-full rounded-xl border p-3"
          />
        </label>
      </div>
      {error ? (
        <p role="alert" className="mt-4 text-sm font-semibold text-red-700">
          {error}
        </p>
      ) : null}
      <button
        disabled={busy}
        onClick={() => void save()}
        className="mt-5 min-h-11 w-full rounded-xl bg-[#0F766E] font-bold text-white disabled:opacity-50"
      >
        {busy ? "Creating…" : "Create Circle"}
      </button>
    </Modal>
  );
}
function InviteDialog({
  circle,
  members,
  user,
  onClose,
  onSaved,
}: {
  circle: Item;
  members: Item[];
  user: User;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [email, setEmail] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  async function invite() {
    setBusy(true);
    setError("");
    try {
      let snap = await getDocs(
        query(
          collection(db, "users"),
          where("e-mail", "==", email.trim().toLowerCase()),
          limit(1),
        ),
      );
      if (snap.empty)
        snap = await getDocs(
          query(
            collection(db, "users"),
            where("email", "==", email.trim().toLowerCase()),
            limit(1),
          ),
        );
      if (snap.empty)
        throw new Error("No existing user was found with that email.");
      const target = snap.docs[0];
      if (members.some((m) => text(m.user_id) === target.id))
        throw new Error("This user is already in the circle.");
      const data = target.data();
      const batch = writeBatch(db);
      const memberRef = doc(collection(db, "circle_members"));
      const inviteRef = doc(collection(db, "circle_invites"));
      batch.set(memberRef, {
        circle_id: circle.id,
        user_id: target.id,
        display_name: nameFor(data),
        photo_url: text(data.profile_picture_url) || null,
        contact_info: email.trim().toLowerCase(),
        is_tontine_head: false,
        payout_position: members.length + 1,
        status: "invited",
        total_contributed: 0,
        total_received: 0,
        has_received_payout: false,
      });
      batch.set(inviteRef, {
        circle_id: circle.id,
        circle_name: text(circle.title),
        invite_method: "email",
        contact_info: email.trim().toLowerCase(),
        created_by: user.uid,
        created_at: serverTimestamp(),
        status: "pending",
        existing_user_id: target.id,
      });
      batch.update(doc(db, "circles", circle.id), {
        total_members: increment(1),
      });
      await batch.commit();
      onSaved();
    } catch (cause) {
      setError(
        cause instanceof Error
          ? cause.message
          : actionError(cause, "Could not invite the member."),
      );
      setBusy(false);
    }
  }
  return (
    <Modal label="Invite circle member" onClose={onClose}>
      <h2 className="text-xl font-extrabold">Invite Member</h2>
      <p className="mt-1 text-sm text-[#64748B]">
        Invite an existing Alluwal user by email.
      </p>
      <div className="mt-5">
        <Field
          label="Email address"
          value={email}
          onChange={setEmail}
          type="email"
        />
      </div>
      {error ? (
        <p role="alert" className="mt-4 text-sm font-semibold text-red-700">
          {error}
        </p>
      ) : null}
      <button
        disabled={busy || !email.trim()}
        onClick={() => void invite()}
        className="mt-5 min-h-11 w-full rounded-xl bg-[#0F766E] font-bold text-white disabled:opacity-50"
      >
        {busy ? "Inviting…" : "Send Invitation"}
      </button>
    </Modal>
  );
}
function PaymentDialog({
  circle,
  cycle,
  user,
  member,
  existing,
  onClose,
  onSaved,
}: {
  circle: Item;
  cycle: Item;
  user: User;
  member: Item | undefined;
  existing: Item | undefined;
  onClose: () => void;
  onSaved: () => void;
}) {
  const expected = number(circle.contribution_amount);
  const [amount, setAmount] = useState(
    String(number(existing?.submitted_amount) || expected),
  );
  const [date, setDate] = useState(new Date().toISOString().slice(0, 10));
  const [file, setFile] = useState<File | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  async function save() {
    if (!file) {
      setError("Upload a payment receipt.");
      return;
    }
    if (file.size > 10 * 1024 * 1024) {
      setError("Receipt must be smaller than 10 MB.");
      return;
    }
    setBusy(true);
    const objectRef = ref(
      storage,
      `circle_receipts/${circle.id}/${cycle.id}/${user.uid}-${Date.now()}-${safe(file.name)}`,
    );
    try {
      await uploadBytes(objectRef, file, { contentType: file.type });
      const url = await getDownloadURL(objectRef);
      const existingSnap = await getDocs(
        query(
          collection(db, "circle_contributions"),
          where("cycle_id", "==", cycle.id),
          where("user_id", "==", user.uid),
          limit(1),
        ),
      );
      const contributionRef =
        existingSnap.docs[0]?.ref ||
        doc(collection(db, "circle_contributions"));
      await setDoc(
        contributionRef,
        {
          circle_id: circle.id,
          cycle_id: cycle.id,
          user_id: user.uid,
          display_name:
            text(member?.display_name) || user.displayName || user.email,
          expected_amount: expected,
          submitted_amount: number(amount),
          amount_is_correct: number(amount) === expected,
          status: "submitted",
          payment_method: "manual",
          receipt_image_url: url,
          submitted_at: serverTimestamp(),
          payment_date: Timestamp.fromDate(new Date(`${date}T12:00:00`)),
          rejection_reason: null,
        },
        { merge: true },
      );
      onSaved();
    } catch (cause) {
      await deleteObject(objectRef).catch(() => undefined);
      setError(actionError(cause, "Could not submit the payment receipt."));
      setBusy(false);
    }
  }
  return (
    <Modal label="Submit circle payment" onClose={onClose}>
      <h2 className="text-xl font-extrabold">Submit Payment</h2>
      <div className="mt-5 space-y-4">
        <Field
          label="Amount paid"
          value={amount}
          onChange={setAmount}
          type="number"
        />
        <Field
          label="Payment date"
          value={date}
          onChange={setDate}
          type="date"
        />
        <label className="block text-sm font-bold">
          Payment receipt
          <input
            aria-label="Payment receipt"
            type="file"
            accept="image/*,.pdf"
            onChange={(e) => setFile(e.target.files?.[0] || null)}
            className="mt-2 block w-full rounded-xl border p-3"
          />
        </label>
      </div>
      {error ? (
        <p role="alert" className="mt-4 text-sm font-semibold text-red-700">
          {error}
        </p>
      ) : null}
      <button
        disabled={busy}
        onClick={() => void save()}
        className="mt-5 min-h-11 w-full rounded-xl bg-[#0F766E] font-bold text-white disabled:opacity-50"
      >
        {busy ? "Submitting…" : "Submit for Review"}
      </button>
    </Modal>
  );
}

async function acceptInvite(invite: Item, user: User) {
  const inviteRef = doc(db, "circle_invites", invite.id);
  const memberSnap = await getDocs(
    query(
      collection(db, "circle_members"),
      where("circle_id", "==", text(invite.circle_id)),
      where("user_id", "==", user.uid),
      limit(1),
    ),
  );
  if (memberSnap.empty) throw new Error("Circle member record not found.");
  await runTransaction(db, async (transaction) => {
    const fresh = await transaction.get(inviteRef);
    if (!fresh.exists() || text(fresh.data().status) !== "pending")
      throw new Error("Invite is no longer available.");
    transaction.update(inviteRef, {
      status: "accepted",
      accepted_by: user.uid,
      accepted_at: serverTimestamp(),
    });
    transaction.update(memberSnap.docs[0].ref, {
      status: "active",
      joined_at: serverTimestamp(),
      display_name: user.displayName || user.email,
      contact_info: user.email || "",
    });
  });
}
async function joinOpenCircle(circle: Item, user: User, displayName: string) {
  await runTransaction(db, async (transaction) => {
    const circleRef = doc(db, "circles", circle.id);
    const fresh = await transaction.get(circleRef);
    if (
      !fresh.exists() ||
      text(fresh.data().status) !== "forming" ||
      text(fresh.data().enrollment_mode) !== "open"
    )
      throw new Error("This circle is no longer accepting members.");
    const existing = await getDocs(
      query(
        collection(db, "circle_members"),
        where("circle_id", "==", circle.id),
        where("user_id", "==", user.uid),
        limit(1),
      ),
    );
    if (!existing.empty)
      throw new Error("You are already a member of this circle.");
    const all = await getDocs(
      query(
        collection(db, "circle_members"),
        where("circle_id", "==", circle.id),
      ),
    );
    const max = number(fresh.data().max_members);
    if (max && all.size >= max) throw new Error("This circle is full.");
    transaction.set(doc(collection(db, "circle_members")), {
      circle_id: circle.id,
      user_id: user.uid,
      display_name: displayName,
      photo_url: null,
      contact_info: user.email || "",
      is_tontine_head: false,
      payout_position: all.size + 1,
      status: "active",
      joined_at: serverTimestamp(),
      total_contributed: 0,
      total_received: 0,
      has_received_payout: false,
    });
    transaction.update(circleRef, { total_members: increment(1) });
  });
}
function MobileHeader() {
  return (
    <header className="flex items-center gap-3 border-b bg-white px-4 py-3 lg:hidden">
      <button
        aria-label="Open teacher menu"
        onClick={openTeacherMobileMenu}
        className="grid h-11 w-11 place-items-center"
      >
        <Menu size={22} />
      </button>
      <p className="font-extrabold">Savings Circles</p>
    </header>
  );
}
function Modal({
  label,
  onClose,
  children,
}: {
  label: string;
  onClose: () => void;
  children: React.ReactNode;
}) {
  return (
    <section
      className="fixed inset-0 z-[90] grid items-end bg-black/45 sm:place-items-center"
      role="dialog"
      aria-modal="true"
      aria-label={label}
    >
      <div className="max-h-[92vh] w-full overflow-y-auto rounded-t-3xl bg-white p-6 sm:max-w-lg sm:rounded-3xl">
        <div className="flex justify-end">
          <button
            aria-label={`Close ${label}`}
            onClick={onClose}
            className="grid h-10 w-10 place-items-center"
          >
            <X size={20} />
          </button>
        </div>
        {children}
      </div>
    </section>
  );
}
function Field({
  label,
  value,
  onChange,
  type = "text",
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  type?: string;
}) {
  return (
    <label className="block text-sm font-bold">
      {label}
      <input
        aria-label={label}
        type={type}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="mt-2 h-11 w-full rounded-xl border px-3 font-normal"
      />
    </label>
  );
}
function Alert({ message }: { message: string }) {
  return (
    <p
      role="alert"
      className="mt-5 flex gap-2 rounded-xl border border-red-200 bg-red-50 p-4 font-semibold text-red-800"
    >
      <AlertTriangle size={20} />
      {message}
    </p>
  );
}
function ErrorCard({ message }: { message: string }) {
  return (
    <div className="rounded-2xl border border-amber-200 bg-amber-50 p-6 text-center">
      <CircleDollarSign className="mx-auto text-amber-600" size={36} />
      <h1 className="mt-3 text-xl font-extrabold">
        Savings Circles unavailable
      </h1>
      <p className="mt-2 text-sm text-amber-900">{message}</p>
    </div>
  );
}
function Empty({ onCreate }: { onCreate: () => void }) {
  return (
    <div className="mt-3 rounded-2xl border border-dashed p-10 text-center">
      <Users className="mx-auto text-[#94A3B8]" size={38} />
      <h3 className="mt-3 font-extrabold">No circles yet</h3>
      <button
        onClick={onCreate}
        className="mt-4 min-h-10 rounded-xl bg-[#0F766E] px-4 font-bold text-white"
      >
        Create your first circle
      </button>
    </div>
  );
}
function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl bg-[#F8FAFC] p-3">
      <p className="text-xs text-[#64748B]">{label}</p>
      <p className="mt-1 font-extrabold">{value}</p>
    </div>
  );
}
function Status({ value }: { value: string }) {
  const good = ["active", "confirmed", "completed", "accepted"].includes(value);
  const warn = [
    "forming",
    "pending",
    "submitted",
    "invited",
    "in_progress",
  ].includes(value);
  return (
    <span
      className={`rounded-full px-2 py-1 text-xs font-bold uppercase ${good ? "bg-emerald-100 text-emerald-700" : warn ? "bg-amber-100 text-amber-700" : "bg-red-100 text-red-700"}`}
    >
      {value.replaceAll("_", " ")}
    </span>
  );
}
function item(snap: { id: string; data: () => Data }): Item {
  return { id: snap.id, ...snap.data() };
}
function text(v: unknown) {
  return typeof v === "string" ? v.trim() : "";
}
function number(v: unknown) {
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
}
function nameFor(record: Data | null | undefined, user?: User) {
  return (
    text(record?.fullName) ||
    text(record?.displayName) ||
    text(record?.name) ||
    `${text(record?.first_name)} ${text(record?.last_name)}`.trim() ||
    user?.displayName ||
    user?.email ||
    "Teacher"
  );
}
function initials(v: string) {
  return (
    v
      .split(/\s+/)
      .slice(0, 2)
      .map((p) => p[0])
      .join("")
      .toUpperCase() || "TE"
  );
}
function money(circle: Item) {
  return `${currency(text(circle.currency) || "USD", number(circle.contribution_amount))} ${frequency(circle)}`;
}
function currency(code: string, value: number) {
  try {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: code || "USD",
    }).format(value);
  } catch {
    return `${code} ${value.toFixed(2)}`;
  }
}
function frequency(circle: Item) {
  const v = text(circle.frequency) || "monthly";
  return v === "biweekly" ? "every 2 weeks" : v;
}
function dateLabel(v: unknown) {
  const d = v instanceof Timestamp ? v.toDate() : v instanceof Date ? v : null;
  return d
    ? new Intl.DateTimeFormat("en", { dateStyle: "medium" }).format(d)
    : "Not set";
}
function safe(v: string) {
  return v.replace(/[^a-zA-Z0-9._-]/g, "-");
}
function actionError(cause: unknown, fallback: string) {
  const code =
    typeof cause === "object" && cause && "code" in cause
      ? String((cause as { code: unknown }).code)
      : "";
  if (code.includes("permission"))
    return "You do not have permission to complete this circle action.";
  if (code.includes("network") || code.includes("unavailable"))
    return "You appear to be offline. Check your connection and try again.";
  return cause instanceof Error && cause.message ? cause.message : fallback;
}
