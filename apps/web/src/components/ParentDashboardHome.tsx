"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useState } from "react";
import {
  AlarmClockCheck,
  AlertTriangle,
  BarChart3,
  CalendarDays,
  ChevronRight,
  Clock,
  CreditCard,
  Info,
  Lightbulb,
  ListChecks,
  Loader2,
  Lock,
  ReceiptText,
  RefreshCw,
  Timer,
  TrendingDown,
  TrendingUp,
  MoveRight,
  Users,
  Wallet,
  Banknote,
} from "lucide-react";
import { ClassContactsCard } from "@/components/ClassContactsCard";
import { useParentSession } from "@/components/ParentArea";
import { ParentInvoiceCard } from "@/components/ParentInvoiceCard";
import { ParentEmptyCard, ParentErrorCard, ParentSpinner, alpha, cardShadow } from "@/components/ParentUi";
import { useLocale } from "@/lib/i18n";
import {
  fetchAttendanceReport,
  fetchShiftHistory,
  invoiceExists,
  watchMoney,
  watchRecentInvoices,
  watchRecentPayments,
  watchSuspendedChildren,
} from "@/lib/parentData";
import {
  ATTENTION_COLOR,
  ATTENTION_LABEL,
  PAYMENT_DOT,
  childAnalytics,
  childProgress,
  classesCountLabel,
  familyAnalytics,
  familyProgress,
  financialSummary,
  formatUsd,
  formatWeekday,
  joinOffset,
  mergeRecentInvoices,
  paymentSubtitle,
  percent,
  trendColor,
  trendLabel,
  weeklyBarHeight,
  type AttendancePeriod,
  type ChildAnalytics,
  type ChildProgress,
  type FamilyAnalytics,
  type FamilyProgress,
  type ParentInvoice,
  type ParentPayment,
} from "@/lib/parentHome";
import { fill, parentHomeText, type ParentHomeText } from "@/lib/parentHomeText";
import { fetchParentChildren } from "@/lib/parentSession";
import { PARENT_ROUTES, type ParentChild } from "@/lib/parentWeb";

type Load<T> = { state: "loading" } | { state: "error" } | { state: "ready"; value: T };

const DAY_MS = 86_400_000;

/** The time used for "overdue" and cutoff labels, refreshed every minute. */
function useNow(intervalMs = 60_000) {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    const timer = window.setInterval(() => setNow(new Date()), intervalMs);
    return () => window.clearInterval(timer);
  }, [intervalMs]);
  return now;
}

/**
 * The parent home (ParentDashboardScreen, A-030…A-057), top to bottom:
 * greeting · suspension banner · money summary · two quick actions · Family
 * Progress · Attendance Analytics · children · teachers' numbers · recent
 * invoices · recent payments. Refresh (A-032) re-runs the children, the
 * progress figures and the money/suspension listeners, and asks the server to
 * regenerate the attendance reports; Flutter only offers it as pull-to-refresh.
 */
export default function ParentDashboardHome() {
  const session = useParentSession();
  const router = useRouter();
  const fr = useLocale() === "fr";
  const text = parentHomeText(fr);
  const now = useNow();
  const [refreshKey, setRefreshKey] = useState(0);
  const [period, setPeriod] = useState<AttendancePeriod>("weekly");
  const [toast, setToast] = useState<string | null>(null);

  const [children, setChildren] = useState<Load<ParentChild[]>>({ state: "loading" });
  const [progress, setProgress] = useState<Load<FamilyProgress>>({ state: "loading" });
  const [analytics, setAnalytics] = useState<Load<FamilyAnalytics>>({ state: "loading" });

  // D2 → Family Progress (D3 per child). Re-run on refresh.
  useEffect(() => {
    let active = true;
    setChildren({ state: "loading" });
    setProgress({ state: "loading" });
    fetchParentChildren(session.uid)
      .then(async (list) => {
        if (!active) return;
        setChildren({ state: "ready", value: list });
        const at = new Date();
        const monthStart = new Date(at.getTime() - 30 * DAY_MS);
        const snapshots: ChildProgress[] = await Promise.all(
          list.map(async (child) => childProgress(child, child.id ? await fetchShiftHistory(child.id, at, monthStart) : [], at)),
        );
        if (active) setProgress({ state: "ready", value: familyProgress(snapshots, at) });
      })
      .catch(() => {
        if (!active) return;
        setChildren({ state: "error" });
        setProgress({ state: "error" });
      });
    return () => {
      active = false;
    };
  }, [session.uid, refreshKey]);

  // D5 per child, for the chosen period. A refresh asks the server to regenerate.
  const childList = children.state === "ready" ? children.value : null;
  const childrenFailed = children.state === "error";
  const [forceNext, setForceNext] = useState(false);
  useEffect(() => {
    if (childrenFailed) {
      setAnalytics({ state: "error" });
      return;
    }
    if (!childList) {
      setAnalytics({ state: "loading" });
      return;
    }
    let active = true;
    setAnalytics({ state: "loading" });
    const force = forceNext;
    Promise.all(childList.map(async (child) => childAnalytics(child, child.id.trim() ? await fetchAttendanceReport(child.id, period, force) : null)))
      .then((list: ChildAnalytics[]) => {
        if (active) setAnalytics({ state: "ready", value: familyAnalytics(list) });
      })
      .catch(() => {
        if (active) setAnalytics({ state: "error" });
      });
    return () => {
      active = false;
    };
    // forceNext is read once per run; it is reset when the period changes.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [childList, childrenFailed, period]);

  const refresh = () => {
    setForceNext(true);
    setRefreshKey((k) => k + 1);
  };
  const choosePeriod = (next: AttendancePeriod) => {
    if (next === period) return;
    setForceNext(false);
    setPeriod(next);
  };

  useEffect(() => {
    if (!toast) return;
    const timer = window.setTimeout(() => setToast(null), 4000);
    return () => window.clearTimeout(timer);
  }, [toast]);

  const openPaymentInvoice = useCallback(
    async (payment: ParentPayment) => {
      const invoiceId = payment.invoiceId.trim();
      if (!invoiceId) return;
      const result = await invoiceExists(invoiceId);
      if (result === "found") router.push(PARENT_ROUTES.invoice(invoiceId));
      else if (result === "missing") setToast(text.invoiceNotFound);
    },
    [router, text.invoiceNotFound],
  );

  return (
    <div className="p-4">
      <div className="flex items-center gap-2">
        <h1 className="min-w-0 flex-1 text-[22px] font-extrabold text-[#111827]">{session.greeting}</h1>
        <button
          type="button"
          onClick={refresh}
          title={text.refresh}
          aria-label={text.refresh}
          className="grid h-10 w-10 shrink-0 place-items-center rounded-full text-[#6B7280] hover:bg-black/5"
        >
          <RefreshCw size={20} />
        </button>
      </div>
      <div className="h-4" />

      <SuspensionBanner parentId={session.uid} refreshKey={refreshKey} />
      <MoneySummary parentId={session.uid} refreshKey={refreshKey} text={text} />

      <div className="mt-4 flex gap-3">
        <QuickAction href={PARENT_ROUTES.invoices} icon={ReceiptText} title={text.invoices} subtitle={text.viewAndPay} />
        <QuickAction href={PARENT_ROUTES.payments} icon={Banknote} title={text.payments} subtitle={text.history} />
      </div>

      <div className="mt-4">
        {progress.state === "loading" ? (
          <div className="flex items-center gap-3 rounded-[20px] bg-[#0F2B57] p-5" role="status">
            <Loader2 size={20} className="animate-spin text-white" />
            <span className="text-[13px] font-semibold text-white">Building family progress insights...</span>
          </div>
        ) : progress.state === "error" ? (
          <ParentErrorCard message="Failed to load progress insights. Please refresh to try again." />
        ) : progress.value.children.length === 0 ? (
          <ParentEmptyCard
            icon={Lightbulb}
            title="Progress insights will appear here"
            subtitle="Once classes are scheduled, you will see weekly and child-level progress charts."
          />
        ) : (
          <FamilyProgressCard overview={progress.value} text={text} />
        )}
      </div>

      <div className="mt-4">
        {analytics.state === "loading" ? (
          <div className="flex items-center gap-2.5 rounded-[18px] border border-[#E2E8F0] bg-white p-[18px]" role="status">
            <Loader2 size={18} className="animate-spin text-[#0386FF]" />
            <span className="text-[13px] font-semibold text-[#334155]">Loading attendance analytics...</span>
          </div>
        ) : analytics.state === "error" ? (
          <ParentErrorCard message="Failed to load attendance analytics. Please refresh to try again." />
        ) : analytics.value.children.length === 0 ? (
          <ParentEmptyCard
            icon={BarChart3}
            title="Attendance analytics will appear here"
            subtitle="Weekly and monthly attendance insights will show once classes and joins are recorded."
          />
        ) : (
          <AttendanceAnalyticsCard overview={analytics.value} period={period} onPeriod={choosePeriod} text={text} />
        )}
      </div>

      <div className="mt-4">
        {children.state === "loading" ? (
          <ParentSpinner label={text.loading} />
        ) : children.state === "error" ? (
          <ParentErrorCard message="Failed to load children. Please refresh to try again." />
        ) : (
          <ChildrenList list={children.value} text={text} />
        )}
      </div>

      <div className="mt-5 mb-5 [&>section]:mt-0">
        <ClassContactsCard variant="parent" />
      </div>

      <RecentInvoices parentId={session.uid} now={now} text={text} onOpen={(id) => router.push(PARENT_ROUTES.invoice(id))} onPay={(id) => router.push(PARENT_ROUTES.pay(id))} />
      <div className="h-5" />
      <RecentPayments parentId={session.uid} text={text} onOpen={(p) => void openPaymentInvoice(p)} />
      <div className="h-4" />

      {toast ? (
        <div role="status" className="fixed bottom-6 left-1/2 z-[120] -translate-x-1/2 rounded-xl bg-[#323232] px-4 py-3 text-sm font-medium text-white shadow-xl">
          {toast}
        </div>
      ) : null}
    </div>
  );
}

// ─── Suspension banner (A-034) ─────────────────────────────────────────────

function SuspensionBanner({ parentId, refreshKey }: { parentId: string; refreshKey: number }) {
  const [names, setNames] = useState<string[]>([]);
  useEffect(() => watchSuspendedChildren(parentId, setNames), [parentId, refreshKey]);
  if (names.length === 0) return null;
  const count = names.length;
  return (
    <div className="mb-4 flex items-start gap-3 rounded-[14px] border border-[#FECACA] bg-[#FEF2F2] p-4" role="alert">
      <Lock size={22} className="shrink-0 text-[#DC2626]" />
      <div className="min-w-0 flex-1">
        <p className="text-sm font-extrabold text-[#991B1B]">{count === 1 ? "Platform access suspended" : `${count} students have been suspended`}</p>
        <p className="mt-1 text-[13px] leading-normal text-[#B91C1C]">
          {names.join(", ")} {count === 1 ? "has" : "have"} lost platform access due to an unpaid invoice. Pay now to restore access immediately.
        </p>
        <Link href={PARENT_ROUTES.invoicesPending} className="mt-2.5 inline-block rounded-lg bg-[#DC2626] px-3.5 py-2 text-xs font-bold text-white hover:bg-[#B91C1C]">
          View &amp; pay invoices
        </Link>
      </div>
    </div>
  );
}

// ─── Money summary (A-035…A-037) ───────────────────────────────────────────

function MoneySummary({ parentId, refreshKey, text }: { parentId: string; refreshKey: number; text: ParentHomeText }) {
  const [data, setData] = useState<Load<{ invoices: ParentInvoice[]; payments: ParentPayment[] }>>({ state: "loading" });
  const now = useNow();
  useEffect(() => {
    setData({ state: "loading" });
    return watchMoney(
      parentId,
      (invoices, payments) => setData({ state: "ready", value: { invoices, payments } }),
      () => setData({ state: "error" }),
    );
  }, [parentId, refreshKey]);

  const totals = data.state === "ready" ? financialSummary(data.value.invoices, data.value.payments, now) : null;
  const outstanding = totals?.outstanding ?? 0;
  const overdue = totals?.overdue ?? 0;

  return (
    <section className="rounded-[18px] bg-gradient-to-br from-[#0F172A] to-[#1E293B] p-5 shadow-[0_10px_18px_rgba(0,0,0,0.12)]" aria-label={text.financialSummary}>
      <div className="flex min-h-11 items-center gap-2.5">
        <Wallet size={22} className="shrink-0 text-white" />
        <h2 className="min-w-0 flex-1 text-base font-bold text-white">{text.financialSummary}</h2>
        {outstanding > 0 ? (
          <Link href={PARENT_ROUTES.invoicesPending} className="inline-flex shrink-0 items-center gap-2 rounded-xl bg-[#0386FF] px-3.5 py-3 text-sm font-bold text-white hover:bg-[#0276E0]">
            <CreditCard size={18} />
            {text.payNow}
          </Link>
        ) : null}
      </div>
      {data.state === "error" ? (
        <p className="mt-2 text-xs font-semibold text-[#FCA5A5]" role="alert">
          We couldn&apos;t load your balance. Please refresh to try again.
        </p>
      ) : null}
      <div className="mt-4 flex gap-3">
        <MoneyMetric label={text.outstanding} value={totals ? formatUsd(outstanding) : null} accent={outstanding > 0 ? "#38BDF8" : "#FFFFFF"} loading={data.state === "loading"} />
        <MoneyMetric label={text.overdue} value={totals ? formatUsd(overdue) : null} accent={overdue > 0 ? "#FCA5A5" : "#FFFFFF"} loading={data.state === "loading"} />
      </div>
    </section>
  );
}

function MoneyMetric({ label, value, accent, loading }: { label: string; value: string | null; accent: string; loading: boolean }) {
  return (
    <div className="min-w-0 flex-1 rounded-[14px] border border-white/[0.12] bg-white/[0.08] p-3.5">
      <p className="text-[11px] font-semibold text-white/75">{label}</p>
      <p className="mt-1.5 truncate text-base font-extrabold" style={{ color: accent }}>
        {loading ? <Loader2 size={16} className="my-[3px] animate-spin text-white/70" aria-label="Loading" /> : (value ?? "—")}
      </p>
    </div>
  );
}

function QuickAction({ href, icon: Icon, title, subtitle }: { href: string; icon: typeof Wallet; title: string; subtitle: string }) {
  return (
    <Link href={href} className={`flex min-w-0 flex-1 items-center gap-3 rounded-2xl border border-[#E5E7EB] bg-white p-4 hover:bg-[#FAFAFA] ${cardShadow}`}>
      <span className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-[#EFF6FF] text-[#1D4ED8]">
        <Icon size={24} />
      </span>
      <span className="min-w-0 flex-1">
        <span className="block break-words text-[13px] font-extrabold text-[#111827]">{title}</span>
        <span className="mt-0.5 block break-words text-xs font-medium text-[#6B7280]">{subtitle}</span>
      </span>
      <ChevronRight size={24} className="shrink-0 text-[#9CA3AF]" />
    </Link>
  );
}

// ─── Family Progress (A-041…A-045) ─────────────────────────────────────────

function FamilyProgressCard({ overview, text }: { overview: FamilyProgress; text: ParentHomeText }) {
  const avg = percent(overview.averageAttendanceRate);
  const support = overview.needsSupportChildren;
  return (
    <section className="rounded-[22px] bg-gradient-to-br from-[#0F2B57] to-[#1659B7] p-[18px] shadow-[0_12px_24px_rgba(15,43,87,0.28)]">
      <div className="flex items-start gap-3">
        <div className="min-w-0 flex-1">
          <h2 className="text-[19px] font-extrabold text-white">{text.progressTitle}</h2>
          <p className="mt-1.5 text-[12.5px] leading-[1.35] font-medium text-white/[0.86]">{text.progressSubtitle}</p>
        </div>
        <Ring value={overview.averageAttendanceRate} label={`${avg}%`} caption={text.progressAvg} captionSize={11} />
      </div>
      <div className="@container mt-4">
        <div className="grid gap-2.5 @min-[680px]:grid-cols-4">
          <HeroTile icon={Users} value={`${overview.children.length}`} label={text.progressChildren} hint={text.progressLinkedAccounts} />
          <HeroTile icon={CalendarDays} value={`${overview.classesThisWeek}`} label={text.progressClassesThisWeek} hint={text.progressLast7Days} />
          <HeroTile icon={Clock} value={overview.totalLearningHours.toFixed(1)} label={text.progressLearningHours} hint={text.progressPast30Days} />
          <HeroTile
            icon={AlertTriangle}
            value={`${support}`}
            label={text.progressNeedsSupport}
            hint={text.progressUnder60}
            accent={support > 0 ? "#FCA5A5" : "#A7F3D0"}
          />
        </div>
      </div>
      <div className="mt-4">
        <WeeklyChart counts={overview.classesByDay} days={overview.dayLabels} total={overview.classesThisWeek} />
      </div>
      {overview.topSubjects.length > 0 ? (
        <>
          <h3 className="mt-3.5 text-[13px] font-bold text-white">{text.progressTopSubjects}</h3>
          <div className="mt-2 flex flex-wrap gap-2">
            {overview.topSubjects.map(([subject, count]) => (
              <span key={subject} className="rounded-full border border-white/[0.24] bg-white/[0.16] px-2.5 py-1.5 text-[11.5px] font-semibold text-white">
                {subject} ({count})
              </span>
            ))}
          </div>
        </>
      ) : null}
      <h3 className="mt-3.5 text-sm font-bold text-white">{text.progressChildPerformance}</h3>
      <div className="mt-2.5 grid gap-2.5">
        {overview.children.map((child) => (
          <ChildProgressCard key={child.id || child.name} child={child} />
        ))}
      </div>
    </section>
  );
}

/** Flutter's 86 px CircularProgressIndicator ring with the figure inside. */
export function Ring({ value, label, caption, captionSize }: { value: number; label: string; caption: string; captionSize: number }) {
  const r = 39;
  const c = 2 * Math.PI * r;
  const v = Math.min(1, Math.max(0, value));
  return (
    <div className="relative grid h-[86px] w-[86px] shrink-0 place-items-center">
      <svg viewBox="0 0 86 86" className="absolute inset-0 -rotate-90" aria-hidden="true">
        <circle cx="43" cy="43" r={r} fill="none" stroke="rgba(255,255,255,0.24)" strokeWidth="8" />
        <circle cx="43" cy="43" r={r} fill="none" stroke="#FFFFFF" strokeWidth="8" strokeDasharray={`${c * v} ${c}`} />
      </svg>
      <div className="relative text-center">
        <p className="text-lg leading-tight font-extrabold text-white">{label}</p>
        <p className="font-semibold text-white/[0.86]" style={{ fontSize: captionSize }}>
          {caption}
        </p>
      </div>
    </div>
  );
}

function HeroTile({ icon: Icon, value, label, hint, accent = "#BFDBFE" }: { icon: typeof Users; value: string; label: string; hint: string; accent?: string }) {
  return (
    <div className="flex min-w-0 items-center gap-2.5 rounded-[14px] border border-white/[0.24] bg-white/[0.14] p-3">
      <span className="grid h-[34px] w-[34px] shrink-0 place-items-center rounded-[10px] text-white" style={{ backgroundColor: alpha(accent, 0.25) }}>
        <Icon size={18} />
      </span>
      <span className="min-w-0">
        <span className="block text-[17px] font-extrabold text-white">{value}</span>
        <span className="block text-[11.5px] font-bold text-white/[0.88]">{label}</span>
        <span className="block text-[10.5px] font-medium text-white/[0.72]">{hint}</span>
      </span>
    </div>
  );
}

/** The 7-bar Weekly Activity chart (A-043, A-083). */
export function WeeklyChart({ counts, days, total }: { counts: number[]; days: Date[]; total: number }) {
  const max = Math.max(0, ...counts);
  return (
    <div className="rounded-[14px] border border-white/[0.24] bg-white/[0.14] p-3.5">
      <div className="flex items-center">
        <h3 className="text-[13.5px] font-bold text-white">Weekly Activity</h3>
        <span className="ml-auto text-[11.5px] font-semibold text-white/90">{classesCountLabel(total)}</span>
      </div>
      <div className="mt-2.5 flex h-[112px] items-end">
        {counts.map((value, index) => (
          <div key={index} className="flex h-full flex-1 flex-col items-center justify-end">
            <span className="h-3 text-[10.5px] leading-3 font-semibold text-white/[0.86]">{value}</span>
            <div className="mt-1 flex w-full flex-1 items-end justify-center">
              <span
                className="w-4 rounded-full transition-[height] ease-out"
                style={{
                  height: weeklyBarHeight(value, max),
                  backgroundColor: `rgba(255,255,255,${value === 0 ? 0.3 : 0.88})`,
                  transitionDuration: `${320 + index * 35}ms`,
                }}
              />
            </div>
            <span className="mt-1 h-3 text-[10.5px] leading-3 font-semibold text-white/[0.86]">{days[index] ? formatWeekday(days[index]) : ""}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

function ChildProgressCard({ child }: { child: ChildProgress }) {
  const delta = child.recentClasses - child.previousClasses;
  const color = trendColor(delta, "#6B7280");
  const TrendIcon = delta > 0 ? TrendingUp : delta < 0 ? TrendingDown : MoveRight;
  const badge = ATTENTION_COLOR[child.attentionLevel];
  return (
    <div className="rounded-[14px] bg-white/[0.96] p-3">
      <div className="flex items-start gap-2.5">
        <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-[#E0E7FF] text-sm font-extrabold text-[#1E3A8A]">
          {child.name ? child.name[0].toUpperCase() : "?"}
        </span>
        <div className="min-w-0 flex-1">
          <p className="text-sm font-extrabold text-[#111827]">{child.name}</p>
          <p className="mt-0.5 text-[11.5px] font-semibold text-[#4B5563]">{child.primarySubject}</p>
        </div>
        <span className="shrink-0 rounded-full px-2 py-[5px] text-[10.5px] font-bold" style={{ color: badge, backgroundColor: alpha(badge, 0.16) }}>
          {ATTENTION_LABEL[child.attentionLevel]}
        </span>
      </div>
      <div className="mt-2.5">
        <SplitBar completed={child.completedClasses} missed={child.missedClasses} cancelled={child.cancelledClasses} />
      </div>
      <div className="mt-2.5 flex">
        <SmallMetric label="Attendance" value={child.totalTrackedClasses === 0 ? "--" : `${percent(child.attendanceRate)}%`} color="#0F172A" />
        <SmallMetric label="Last 7 Days" value={`${child.classesLast7Days} class${child.classesLast7Days === 1 ? "" : "es"}`} color="#1D4ED8" />
        <SmallMetric label="Learning Hours" value={`${child.learningHoursLast30Days.toFixed(1)}h`} color="#0F766E" />
      </div>
      <p className="mt-2 flex items-center gap-1.5 text-[11.5px] font-semibold" style={{ color }}>
        <TrendIcon size={16} />
        {trendLabel(delta, "Stable vs previous week")}
      </p>
    </div>
  );
}

/** Green / red / grey bar split by completed, missed and cancelled classes. */
export function SplitBar({ completed, missed, cancelled }: { completed: number; missed: number; cancelled: number }) {
  if (completed + missed + cancelled === 0) return <div className="h-2 rounded-full bg-[#E5E7EB]" />;
  return (
    <div className="flex h-2 overflow-hidden rounded-full">
      {completed > 0 ? <span className="bg-[#16A34A]" style={{ flexGrow: completed }} /> : null}
      {missed > 0 ? <span className="bg-[#DC2626]" style={{ flexGrow: missed }} /> : null}
      {cancelled > 0 ? <span className="bg-[#9CA3AF]" style={{ flexGrow: cancelled }} /> : null}
    </div>
  );
}

function SmallMetric({ label, value, color }: { label: string; value: string; color: string }) {
  return (
    <div className="min-w-0 flex-1">
      <p className="text-[12.5px] font-bold" style={{ color }}>
        {value}
      </p>
      <p className="mt-0.5 text-[10.5px] font-semibold text-[#6B7280]">{label}</p>
    </div>
  );
}

// ─── Attendance Analytics (A-047…A-049) ────────────────────────────────────

function AttendanceAnalyticsCard({
  overview,
  period,
  onPeriod,
  text,
}: {
  overview: FamilyAnalytics;
  period: AttendancePeriod;
  onPeriod: (p: AttendancePeriod) => void;
  text: ParentHomeText;
}) {
  return (
    <section className="rounded-[20px] border border-[#E2E8F0] bg-white p-[18px] shadow-[0_6px_12px_rgba(0,0,0,0.03)]">
      <div className="flex flex-wrap items-center gap-2.5">
        <div className="min-w-0 flex-1">
          <h2 className="text-lg font-extrabold text-[#0F172A]">{text.analyticsTitle}</h2>
          <p className="mt-1 text-xs font-medium text-[#64748B]">{period === "weekly" ? text.analyticsWeeklySubtitle : text.analyticsMonthlySubtitle}</p>
        </div>
        <div className="flex gap-2" role="group" aria-label={text.analyticsTitle}>
          {(["weekly", "monthly"] as const).map((p) => (
            <button
              key={p}
              type="button"
              aria-pressed={period === p}
              onClick={() => onPeriod(p)}
              className={`rounded-full border px-3 py-[7px] text-[11.5px] font-bold ${period === p ? "border-[#1D4ED8] bg-[#1D4ED8] text-white" : "border-[#E2E8F0] bg-[#F1F5F9] text-[#334155]"}`}
            >
              {p === "weekly" ? text.weekly : text.monthly}
            </button>
          ))}
        </div>
      </div>
      <div className="@container mt-3.5">
        <div className="grid gap-2.5 @min-[680px]:grid-cols-5">
          <AnalyticsTile icon={Clock} label={text.familyClassTime} value={fill(text.hoursValue, { hours: (overview.totalPresenceMinutes / 60).toFixed(1) })} accent="#7C3AED" />
          <AnalyticsTile icon={ListChecks} label={text.attendanceAvg} value={`${percent(overview.averageAttendanceRate)}%`} accent="#1D4ED8" />
          <AnalyticsTile icon={AlarmClockCheck} label={text.punctualityAvg} value={`${percent(overview.averagePunctualityRate)}%`} accent="#0F766E" />
          <AnalyticsTile icon={Timer} label={text.lateClasses} value={`${overview.totalLateClasses}`} accent="#D97706" />
          <AnalyticsTile icon={AlertTriangle} label={text.teacherAbsent} value={`${overview.totalTeacherAbsentIncidents}`} accent="#DC2626" />
        </div>
      </div>
      <h3 className="mt-3.5 text-sm font-bold text-[#0F172A]">{text.byChild}</h3>
      <div className="mt-2.5 grid gap-2.5">
        {overview.children.map((child) => (
          <ChildAnalyticsCard key={child.id || child.name} child={child} text={text} />
        ))}
      </div>
    </section>
  );
}

function AnalyticsTile({ icon: Icon, label, value, accent }: { icon: typeof Clock; label: string; value: string; accent: string }) {
  return (
    <div className="flex min-w-0 items-center gap-2.5 rounded-xl border border-[#E2E8F0] bg-[#F8FAFC] p-3">
      <span className="grid h-[34px] w-[34px] shrink-0 place-items-center rounded-[10px]" style={{ color: accent, backgroundColor: alpha(accent, 0.12) }}>
        <Icon size={18} />
      </span>
      <span className="min-w-0">
        <span className="block text-base font-extrabold text-[#0F172A]">{value}</span>
        <span className="block text-[11.2px] font-semibold text-[#64748B]">{label}</span>
      </span>
    </div>
  );
}

function ChildAnalyticsCard({ child, text }: { child: ChildAnalytics; text: ParentHomeText }) {
  const offset = joinOffset(child.averageJoinOffsetMinutes);
  const offsetText =
    offset.kind === "none"
      ? "--"
      : offset.kind === "onTime"
        ? text.onTime
        : fill(offset.kind === "early" ? text.minEarly : text.minLate, { minutes: offset.minutes });
  const metrics: Array<[string, string, string]> = [
    [text.scheduled, `${child.scheduledClasses}`, "#334155"],
    [text.attended, `${child.attendedClasses}`, "#15803D"],
    [text.absent, `${child.absentClasses}`, "#DC2626"],
    [text.late, `${percent(child.lateRate)}%`, "#D97706"],
    [text.teacherAbsent, `${child.teacherAbsentClasses}`, "#B91C1C"],
    [text.earlyJoins, `${child.joinsBeforeStartEvents}`, "#0F766E"],
  ];
  return (
    <div className="rounded-[14px] border border-[#E2E8F0] bg-[#F8FAFC] p-3">
      <div className="flex items-center gap-2">
        <p className="min-w-0 flex-1 text-[13.5px] font-extrabold text-[#0F172A]">{child.name}</p>
        <span className="shrink-0 rounded-full bg-[#EFF6FF] px-2 py-1 text-[10.5px] font-bold text-[#1E40AF]">
          {fill(text.attendancePercent, { percent: percent(child.attendanceRate) })}
        </span>
      </div>
      <div className="mt-2 flex flex-wrap gap-x-2.5 gap-y-1.5">
        {metrics.map(([label, value, color]) => (
          <span key={label} className="text-[11px] font-semibold text-[#334155]">
            <span className="font-extrabold" style={{ color }}>
              {value}{" "}
            </span>
            {label}
          </span>
        ))}
      </div>
      <div className="mt-2.5 flex gap-2.5">
        <ProgressLine label={text.attendance} value={child.attendanceRate} color="#2563EB" />
        <ProgressLine label={text.punctuality} value={child.punctualityRate} color="#0F766E" />
      </div>
      <p className="mt-2 text-[10.8px] font-semibold text-[#64748B]">
        {fill(text.avgJoinOffset, { offset: offsetText })}
        {"  •  "}
        {text.classTime}: {fill(text.hoursValue, { hours: (child.totalPresenceMinutes / 60).toFixed(1) })}
        {"  •  "}
        {fill(text.overlap, { minutes: child.totalOverlapMinutes.toFixed(1) })}
      </p>
    </div>
  );
}

function ProgressLine({ label, value, color }: { label: string; value: number; color: string }) {
  const v = Math.min(1, Math.max(0, value));
  return (
    <div className="min-w-0 flex-1">
      <div className="flex items-center">
        <span className="min-w-0 flex-1 truncate text-[10.8px] font-bold text-[#475569]">{label}</span>
        <span className="text-[10.8px] font-extrabold" style={{ color }}>
          {percent(v)}%
        </span>
      </div>
      <div className="mt-1 h-1.5 overflow-hidden rounded-full bg-[#E2E8F0]">
        <div className="h-full" style={{ width: `${v * 100}%`, backgroundColor: color }} />
      </div>
    </div>
  );
}

// ─── Children list (A-050, A-051) ──────────────────────────────────────────

function ChildrenList({ list, text }: { list: ParentChild[]; text: ParentHomeText }) {
  if (list.length === 0) {
    return (
      <div className="flex items-center gap-2.5 rounded-2xl border border-[#E5E7EB] bg-white p-4">
        <Info size={24} className="shrink-0 text-[#6B7280]" />
        <p className="text-[13px] font-medium text-[#6B7280]">{text.noChildren}</p>
      </div>
    );
  }
  return (
    <section className={`rounded-2xl border border-[#E5E7EB] bg-white ${cardShadow}`}>
      <h2 className="flex items-center gap-2.5 px-4 pt-4 pb-2 text-sm font-bold text-[#111827]">
        <Users size={20} />
        {text.children}
      </h2>
      <hr className="border-[#E5E7EB]" />
      <ul>
        {list.map((child) => {
          const code = (child.studentCode ?? child.kioskCode ?? "").trim();
          return (
            <li key={child.id}>
              <Link href={PARENT_ROUTES.child(child.id)} className="flex min-h-[72px] items-center gap-4 px-4 py-2 hover:bg-[#F9FAFB]">
                <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-[#EFF6FF] text-base font-extrabold text-[#1D4ED8]">
                  {child.name ? child.name[0].toUpperCase() : "?"}
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-[13px] font-bold text-[#111827]">{child.name || "Student"}</span>
                  {code ? <span className="block text-xs text-[#6B7280]">ID: {code}</span> : null}
                </span>
                <ChevronRight size={24} className="shrink-0 text-[#9CA3AF]" />
              </Link>
            </li>
          );
        })}
      </ul>
    </section>
  );
}

// ─── Recent invoices and payments (A-053…A-056) ────────────────────────────

function SeeAll({ href }: { href: string }) {
  return (
    <Link href={href} className="rounded-full px-3 py-2 text-sm font-bold text-[#0386FF] hover:bg-[#0386FF]/10">
      See all
    </Link>
  );
}

function RecentInvoices({
  parentId,
  now,
  text,
  onOpen,
  onPay,
}: {
  parentId: string;
  now: Date;
  text: ParentHomeText;
  onOpen: (id: string) => void;
  onPay: (id: string) => void;
}) {
  const [data, setData] = useState<Load<ParentInvoice[]>>({ state: "loading" });
  useEffect(
    () =>
      watchRecentInvoices(
        parentId,
        (byParent, byStudent) => setData({ state: "ready", value: mergeRecentInvoices(byParent, byStudent) }),
        () => setData({ state: "error" }),
      ),
    [parentId],
  );
  return (
    <section>
      <div className="flex items-center">
        <h2 className="min-w-0 flex-1 text-base font-extrabold text-[#111827]">{text.recentInvoices}</h2>
        <SeeAll href={PARENT_ROUTES.invoices} />
      </div>
      <div className="mt-2.5">
        {data.state === "loading" ? (
          <ParentSpinner label={text.loading} />
        ) : data.state === "error" ? (
          <ParentErrorCard message="Failed to load invoices. Please refresh to try again." />
        ) : data.value.length === 0 ? (
          <ParentEmptyCard icon={ReceiptText} title={text.noInvoices} subtitle={text.noInvoicesBody} />
        ) : (
          <div className="grid gap-3">
            {data.value.map((invoice) => (
              <ParentInvoiceCard
                key={invoice.id}
                invoice={invoice}
                now={now}
                payLabel={text.payNow}
                onOpen={() => onOpen(invoice.id)}
                onPay={() => onPay(invoice.id)}
              />
            ))}
          </div>
        )}
      </div>
    </section>
  );
}

function RecentPayments({ parentId, text, onOpen }: { parentId: string; text: ParentHomeText; onOpen: (payment: ParentPayment) => void }) {
  const [data, setData] = useState<Load<ParentPayment[]>>({ state: "loading" });
  useEffect(
    () =>
      watchRecentPayments(
        parentId,
        (list) => setData({ state: "ready", value: list }),
        () => setData({ state: "error" }),
      ),
    [parentId],
  );
  const rows = useMemo(() => (data.state === "ready" ? data.value : []), [data]);
  return (
    <section>
      <div className="flex items-center">
        <h2 className="min-w-0 flex-1 text-base font-extrabold text-[#111827]">{text.recentPayments}</h2>
        <SeeAll href={PARENT_ROUTES.payments} />
      </div>
      <div className="mt-2.5">
        {data.state === "loading" ? (
          <ParentSpinner label={text.loading} />
        ) : data.state === "error" ? (
          <ParentErrorCard message="Failed to load payments. Please refresh to try again." />
        ) : rows.length === 0 ? (
          <ParentEmptyCard icon={Banknote} title={text.noPayments} subtitle={text.noPaymentsBody} />
        ) : (
          <ul className={`rounded-2xl border border-[#E5E7EB] bg-white ${cardShadow}`}>
            {rows.map((payment) => (
              <li key={payment.id}>
                <button type="button" onClick={() => onOpen(payment)} className="flex min-h-[72px] w-full items-center gap-4 px-4 py-2 text-left hover:bg-[#F9FAFB]">
                  <span className="h-2.5 w-2.5 shrink-0 rounded-full" style={{ backgroundColor: PAYMENT_DOT[payment.status] }} />
                  <span className="min-w-0 flex-1">
                    <span className="block text-[13px] font-extrabold text-[#111827]">{formatUsd(payment.amount)}</span>
                    <span className="block text-xs text-[#6B7280]">{paymentSubtitle(payment)}</span>
                  </span>
                  <ChevronRight size={24} className="shrink-0 text-[#9CA3AF]" />
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>
    </section>
  );
}
