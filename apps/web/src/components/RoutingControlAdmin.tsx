"use client";

import Link from "next/link";
import { onAuthStateChanged } from "firebase/auth";
import { httpsCallable } from "firebase/functions";
import { useCallback, useEffect, useMemo, useState, type ReactNode } from "react";
import { Activity, AlertTriangle, BarChart3, CalendarDays, ChevronLeft, Clock3, RefreshCw, Server, Users, Video, Wifi, WifiOff } from "lucide-react";
import { AdminDashboardShell } from "@/components/AdminDashboardShell";
import { auth, functions } from "@/lib/firebase";
import { isCurrentUserAdmin } from "@/lib/userRoles";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";

type RoutingTotals = {
  activeHubs: number;
  roomsOpen: number;
  onlineBots: number;
  staleBots: number;
  inRoomOccupants: number;
  attendeeCount: number;
  targetMemberCount: number;
  liveRoomCount: number;
  plannedRoomCount: number;
  lastRoutingActionCount: number;
  scheduledClassCount: number;
  openIncidentCount: number;
};

type RoutingClass = {
  shiftId: string | null;
  roomName: string;
  title: string;
  teacherName: string;
  studentNames: string[];
  start: string | null;
  end: string | null;
  scheduledNow: boolean;
  targetMemberCount: number;
  spare: boolean;
};

type RoutingHub = {
  hubDocId: string;
  lane: number;
  blockIndex: number;
  hostAccount: string;
  meetingNumber: string;
  status: string;
  active: boolean;
  roomsOpen: boolean;
  heartbeatAt: string | null;
  heartbeatAgeMs: number | null;
  heartbeatFresh: boolean;
  windowStart: string | null;
  windowEnd: string | null;
  plannedRoomCount: number;
  classRoomCount: number;
  liveRoomCount: number;
  inRoomOccupants: number;
  attendeeCount: number;
  customerKeyCount: number;
  routableRoomCount: number;
  targetMemberCount: number;
  lastRoutingActionCount: number;
  botError: string;
  forceRejoinAt: string | null;
  classes: RoutingClass[];
};

type RoutingIncident = {
  id: string;
  severity: string;
  reason: string;
  title: string;
  createdAt: string | null;
  open: boolean;
  hubDocId: string;
  lane: number;
};

type RoutingSnapshot = {
  success: boolean;
  generatedAt: string;
  totals: RoutingTotals;
  hubs: RoutingHub[];
  incidents: RoutingIncident[];
};

type CapacityLane = {
  lane: number;
  rooms: number;
  roomHeadroom: number;
  peakConcurrentClasses: number;
  peakSeats: number;
  seatHeadroom: number;
};

type CapacityBlock = {
  day: string;
  blockIndex: number;
  block: string;
  totalRooms: number;
  totalRoomHeadroom: number;
  peakConcurrentClasses: number;
  peakAt: string | null;
  status: "ok" | "warning" | "hard_limit";
  reasons: string[];
  lanes: CapacityLane[];
};

type CapacityForecast = {
  success: boolean;
  generatedAt: string;
  horizonStart: string;
  horizonEnd: string;
  summaryStatus: "ok" | "watch" | "add_account";
  recommendation: string;
  capacity: {
    laneCount: number;
    blockBoundaries: string[];
    classRoomCapPerLane: number;
    classRoomCapTotal: number;
    warningRoomsPerLane: number;
    warningRoomsTotal: number;
    participantCapPerLane: number;
    reservedSeatsPerLane: number;
    humanParticipantCapPerLane: number;
    spareRoomsPerHub: number;
  };
  totals: {
    scannedHubRoutedZoomShifts: number;
    nonHubZoomRecords: number;
    daysWithHubShifts: number;
  };
  nextHardLimit: CapacityBlock | null;
  nextWarning: CapacityBlock | null;
  busiestBlock: CapacityBlock | null;
  topDays: Array<{ day: string; hubRoutedZoomShifts: number }>;
  topBlocks: CapacityBlock[];
};

const emptyTotals: RoutingTotals = {
  activeHubs: 0,
  roomsOpen: 0,
  onlineBots: 0,
  staleBots: 0,
  inRoomOccupants: 0,
  attendeeCount: 0,
  targetMemberCount: 0,
  liveRoomCount: 0,
  plannedRoomCount: 0,
  lastRoutingActionCount: 0,
  scheduledClassCount: 0,
  openIncidentCount: 0,
};

export function RoutingControlAdmin() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [snapshot, setSnapshot] = useState<RoutingSnapshot | null>(null);
  const [forecast, setForecast] = useState<CapacityForecast | null>(null);
  const [loading, setLoading] = useState(true);
  const [forecastLoading, setForecastLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [message, setMessage] = useState("");
  const [forecastMessage, setForecastMessage] = useState("");

  const loadSnapshot = useCallback(async (background = false) => {
    if (background) setRefreshing(true);
    else setLoading(true);
    try {
      const callable = httpsCallable<unknown, RoutingSnapshot>(functions, "getZoomHubRoutingStatus");
      const result = await callable({});
      setSnapshot(result.data);
      setMessage("");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Unable to load routing status.");
    } finally {
      if (background) setRefreshing(false);
      else setLoading(false);
    }
  }, []);

  const loadForecast = useCallback(async () => {
    setForecastLoading(true);
    try {
      const callable = httpsCallable<unknown, CapacityForecast>(functions, "getZoomHubCapacityForecast");
      const result = await callable({});
      setForecast(result.data);
      setForecastMessage("");
    } catch (error) {
      setForecastMessage(error instanceof Error ? error.message : "Unable to load Zoom capacity forecast.");
    } finally {
      setForecastLoading(false);
    }
  }, []);

  useEffect(() => {
    let mounted = true;
    return onAuthStateChanged(auth, async (user) => {
      if (!mounted) return;
      if (!user) {
        setAccess("signedOut");
        setLoading(false);
        return;
      }
      setAccess("checking");
      setLoading(true);
      try {
        const allowed = await isCurrentUserAdmin(user);
        if (!mounted) return;
        if (!allowed) {
          setAccess("denied");
          setLoading(false);
          return;
        }
        setAccess("allowed");
        await Promise.all([loadSnapshot(), loadForecast()]);
      } catch (error) {
        if (mounted) {
          setAccess("allowed");
          setMessage(error instanceof Error ? error.message : "Unable to load routing status.");
          setLoading(false);
        }
      }
    });
  }, [loadForecast, loadSnapshot]);

  useEffect(() => {
    if (access !== "allowed") return undefined;
    const timer = window.setInterval(() => void loadSnapshot(true), 10000);
    return () => window.clearInterval(timer);
  }, [access, loadSnapshot]);

  useEffect(() => {
    if (access !== "allowed") return undefined;
    const timer = window.setInterval(() => void loadForecast(), 5 * 60 * 1000);
    return () => window.clearInterval(timer);
  }, [access, loadForecast]);

  const totals = snapshot?.totals ?? emptyTotals;
  const activeHubs = useMemo(() => snapshot?.hubs.filter((hub) => hub.active) ?? [], [snapshot]);
  const visibleHubs = activeHubs.length > 0 ? activeHubs : snapshot?.hubs ?? [];
  const allBotsHealthy = totals.staleBots === 0 && totals.openIncidentCount === 0;
  const roomsOpenLabel = `${totals.roomsOpen}/${Math.max(totals.activeHubs, totals.roomsOpen)}`;

  if (access !== "allowed") return <RoutingAccessPrompt access={access} />;

  return (
    <AdminDashboardShell activeLabel="Routing Control" breadcrumb="Communication / Routing Control">
      <main className="min-h-[calc(100vh-56px)] bg-[#07111F] text-white">
        <header className="sticky top-0 z-30 border-b border-white/10 bg-[#08111E]/95 backdrop-blur">
          <div className="grid min-h-16 grid-cols-[48px_1fr_48px] items-center px-3 sm:px-4">
            <Link href="/admin/" aria-label="Back to dashboard" className="grid h-11 w-11 place-items-center rounded-lg text-white/80 hover:bg-white/10">
              <ChevronLeft size={24} />
            </Link>
            <div className="min-w-0 text-center">
              <div className="flex items-center justify-center gap-2">
                <span className={`h-2.5 w-2.5 rounded-full ${allBotsHealthy ? "bg-emerald-300 shadow-[0_0_14px_rgba(110,231,183,0.9)]" : "bg-amber-300"}`} />
                <h1 className="truncate text-base font-black tracking-[0.08em] text-white sm:text-lg">Routing Control</h1>
              </div>
              <p className="mt-0.5 truncate text-[11px] font-semibold text-white/55">
                {totals.onlineBots} bot{totals.onlineBots === 1 ? "" : "s"} online · {snapshot ? formatClock(snapshot.generatedAt) : "syncing"}
              </p>
            </div>
            <button
              type="button"
              aria-label="Refresh routing status"
              onClick={() => void loadSnapshot(true)}
              disabled={refreshing}
              className="grid h-11 w-11 place-items-center rounded-lg text-cyan-200 hover:bg-white/10 disabled:opacity-50"
            >
              <RefreshCw size={20} className={refreshing ? "animate-spin" : ""} />
            </button>
          </div>
        </header>

        <section className="mx-auto max-w-7xl px-3 pb-24 pt-4 sm:px-4 lg:px-6 lg:pb-8">
          <div className="mb-4 grid gap-3 rounded-lg border border-white/10 bg-[#0D1A2B] px-4 py-4 shadow-[0_18px_70px_rgba(0,0,0,0.24)] sm:grid-cols-[1fr_auto] sm:items-center">
            <div className="min-w-0">
              <p className="text-[11px] font-black uppercase tracking-[0.16em] text-cyan-200/70">Live Firestore</p>
              <p className="mt-1 truncate text-xl font-black text-white sm:text-2xl">
                {allBotsHealthy ? "Routing is healthy" : "Routing needs attention"}
              </p>
              <p className="mt-1 text-xs font-semibold leading-5 text-white/55">
                Rooms {roomsOpenLabel} · {totals.inRoomOccupants} in rooms · {totals.targetMemberCount} routed targets
              </p>
            </div>
            <div className={`inline-flex min-h-11 items-center justify-center gap-2 rounded-lg border px-3 text-sm font-black ${allBotsHealthy ? "border-emerald-300/30 bg-emerald-400/10 text-emerald-100" : "border-amber-300/30 bg-amber-400/10 text-amber-100"}`}>
              {allBotsHealthy ? <Wifi size={18} /> : <WifiOff size={18} />}
              {allBotsHealthy ? "Online" : "Check bots"}
            </div>
          </div>

          {message ? <p className="mb-4 rounded-lg border border-red-400/30 bg-red-500/10 px-4 py-3 text-sm font-bold text-red-100">{message}</p> : null}

          <section className="-mx-3 flex snap-x gap-3 overflow-x-auto px-3 pb-2 sm:mx-0 sm:grid sm:grid-cols-2 sm:overflow-visible sm:px-0 xl:grid-cols-6">
            <MetricCard icon={<Users size={19} />} label="In breakout rooms" value={totals.inRoomOccupants} />
            <MetricCard icon={<Video size={19} />} label="Scheduled now" value={totals.scheduledClassCount} />
            <MetricCard icon={<Server size={19} />} label="Rooms open" value={roomsOpenLabel} />
            <MetricCard icon={<Activity size={19} />} label="Last loop actions" value={totals.lastRoutingActionCount} />
            <MetricCard icon={<Clock3 size={19} />} label="Target members" value={totals.targetMemberCount} />
            <MetricCard icon={<AlertTriangle size={19} />} label="Open incidents" value={totals.openIncidentCount} tone={totals.openIncidentCount > 0 ? "warn" : "normal"} />
          </section>

          <CapacityForecastPanel forecast={forecast} loading={forecastLoading} message={forecastMessage} />

          {loading ? <LoadingPanel /> : null}

          {!loading && visibleHubs.length === 0 ? (
            <section className="mt-5 rounded-lg border border-dashed border-white/15 bg-white/[0.03] px-5 py-8 text-center">
              <p className="text-sm font-bold text-white/75">No active Zoom hub data in the current window.</p>
            </section>
          ) : null}

          <section className="mt-5 grid gap-4 xl:grid-cols-[minmax(0,1.35fr)_minmax(360px,0.65fr)]">
            <div className="grid gap-4">
              {visibleHubs.map((hub) => <HubPanel key={hub.hubDocId} hub={hub} />)}
            </div>
            <IncidentPanel incidents={snapshot?.incidents ?? []} />
          </section>
        </section>
      </main>
    </AdminDashboardShell>
  );
}

function MetricCard({ icon, label, value, tone = "normal" }: { icon: ReactNode; label: string; value: number | string; tone?: "normal" | "warn" }) {
  return (
    <div className="min-w-[168px] snap-start rounded-lg border border-white/10 bg-white/[0.06] px-4 py-3 shadow-[0_10px_35px_rgba(0,0,0,0.18)] sm:min-w-0">
      <div className={`mb-2 flex h-8 w-8 items-center justify-center rounded-lg ${tone === "warn" ? "bg-amber-400/15 text-amber-200" : "bg-teal-300/15 text-teal-100"}`}>
        {icon}
      </div>
      <p className="min-h-8 text-[10px] font-black uppercase leading-4 tracking-[0.12em] text-white/45">{label}</p>
      <p className="mt-1 text-3xl font-black tabular-nums text-white sm:text-2xl">{value}</p>
    </div>
  );
}

function CapacityForecastPanel({ forecast, loading, message }: { forecast: CapacityForecast | null; loading: boolean; message: string }) {
  const block = forecast?.busiestBlock ?? null;
  const status = forecast?.summaryStatus ?? "ok";
  const tone = capacityTone(status);
  const headline = status === "add_account"
    ? "Add account before the listed block"
    : status === "watch"
      ? "Plan another account soon"
      : "No new Zoom account needed";

  return (
    <section className={`mt-4 overflow-hidden rounded-lg border ${tone.border} ${tone.bg} shadow-[0_18px_60px_rgba(0,0,0,0.2)]`}>
      <header className="grid gap-3 border-b border-white/10 px-4 py-4 sm:grid-cols-[1fr_auto] sm:items-center">
        <div className="min-w-0">
          <div className="flex items-center gap-2">
            <span className={`grid h-8 w-8 place-items-center rounded-lg ${tone.iconBg} ${tone.text}`}>
              <BarChart3 size={18} />
            </span>
            <div className="min-w-0">
              <p className="text-[11px] font-black uppercase tracking-[0.16em] text-white/45">Zoom account forecast</p>
              <h2 className="truncate text-lg font-black text-white">{loading && !forecast ? "Calculating capacity" : headline}</h2>
            </div>
          </div>
          <p className="mt-3 text-sm font-semibold leading-6 text-white/65">
            {forecast?.recommendation ?? "Reading upcoming Zoom shifts and lane pressure."}
          </p>
          <p className="mt-2 text-xs font-bold leading-5 text-white/45">
            Buy trigger: peak concurrent human seats in one hub, or breakout rooms required in the same hub block. One host-bot seat is reserved per lane.
          </p>
          {message ? <p className="mt-2 rounded-md bg-red-500/10 px-3 py-2 text-xs font-bold text-red-100">{message}</p> : null}
        </div>
        <div className="rounded-lg border border-white/10 bg-black/20 px-3 py-2 text-sm font-black text-white">
          {forecast ? `${formatDateLabel(forecast.horizonStart)} - ${formatDateLabel(forecast.horizonEnd)}` : "Forecast"}
        </div>
      </header>

      {forecast && block ? (
        <div className="grid gap-4 px-4 py-4 lg:grid-cols-[minmax(0,0.95fr)_minmax(0,1.05fr)]">
          <div className="rounded-lg border border-white/10 bg-black/15 p-3">
            <div className="flex items-start justify-between gap-3">
              <div>
                <p className="text-xs font-black uppercase tracking-[0.12em] text-white/45">Highest pressure block</p>
                <p className="mt-1 text-xl font-black text-white">{formatDateLabel(block.day)}</p>
                <p className="text-sm font-bold text-cyan-100/70">{block.block} · peak {block.peakConcurrentClasses} classes</p>
              </div>
              <span className={`rounded-md px-2 py-1 text-[11px] font-black uppercase tracking-[0.06em] ${tone.pill}`}>
                {status === "add_account" ? "buy" : status}
              </span>
            </div>
            <div className="mt-4 grid grid-cols-3 gap-2">
              <HubStat label="Block rooms" value={block.totalRooms} />
              <HubStat label="Room gap" value={block.totalRoomHeadroom} />
              <HubStat label="Peak classes" value={block.peakConcurrentClasses} />
            </div>
          </div>

          <div className="grid gap-3">
            {block.lanes.map((lane) => (
              <CapacityLaneRow key={lane.lane} lane={lane} cap={forecast.capacity.classRoomCapPerLane} seatCap={forecast.capacity.humanParticipantCapPerLane} />
            ))}
          </div>

          <div className="lg:col-span-2">
            <div className="mb-2 flex items-center gap-2 text-xs font-black uppercase tracking-[0.12em] text-white/45">
              <CalendarDays size={15} />
              Daily volume, not the buy trigger
            </div>
            <div className="-mx-1 flex gap-2 overflow-x-auto px-1 pb-1">
              {(forecast.topDays ?? []).slice(0, 8).map((day) => (
                <div key={day.day} className="min-w-[118px] rounded-lg border border-white/10 bg-white/[0.05] px-3 py-2">
                  <p className="text-xs font-black text-white">{formatDateLabel(day.day)}</p>
                  <p className="mt-1 text-lg font-black tabular-nums text-cyan-100">{day.hubRoutedZoomShifts}</p>
                  <p className="text-[10px] font-black uppercase tracking-[0.08em] text-white/40">shifts</p>
                </div>
              ))}
            </div>
          </div>
        </div>
      ) : loading ? (
        <div className="m-4 h-32 animate-pulse rounded-lg bg-white/[0.05]" />
      ) : (
        <p className="px-4 py-5 text-sm font-semibold text-white/55">No upcoming hub-routed Zoom shifts found.</p>
      )}
    </section>
  );
}

function CapacityLaneRow({ lane, cap, seatCap }: { lane: CapacityLane; cap: number; seatCap: number }) {
  const roomRatio = cap > 0 ? Math.min(1, lane.rooms / cap) : 0;
  const seatRatio = seatCap > 0 ? Math.min(1, lane.peakSeats / seatCap) : 0;
  return (
    <div className="rounded-lg border border-white/10 bg-black/15 p-3">
      <div className="flex items-center justify-between">
        <p className="text-sm font-black text-white">Lane {lane.lane}</p>
        <p className="text-xs font-black text-white/55">{lane.rooms}/{cap} rooms</p>
      </div>
      <div className="mt-3 h-2 overflow-hidden rounded-full bg-white/10">
        <div className="h-full rounded-full bg-cyan-300" style={{ width: `${Math.round(roomRatio * 100)}%` }} />
      </div>
      <div className="mt-3 flex items-center justify-between text-xs font-semibold text-white/55">
        <span>{lane.roomHeadroom} room headroom</span>
        <span>{lane.peakSeats}/{seatCap} seats</span>
      </div>
      <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-white/10">
        <div className="h-full rounded-full bg-emerald-300" style={{ width: `${Math.round(seatRatio * 100)}%` }} />
      </div>
    </div>
  );
}

function capacityTone(status: CapacityForecast["summaryStatus"]) {
  if (status === "add_account") {
    return {
      bg: "bg-red-500/10",
      border: "border-red-300/25",
      iconBg: "bg-red-400/15",
      text: "text-red-100",
      pill: "bg-red-400/15 text-red-100",
    };
  }
  if (status === "watch") {
    return {
      bg: "bg-amber-500/10",
      border: "border-amber-300/25",
      iconBg: "bg-amber-400/15",
      text: "text-amber-100",
      pill: "bg-amber-400/15 text-amber-100",
    };
  }
  return {
    bg: "bg-emerald-500/10",
    border: "border-emerald-300/20",
    iconBg: "bg-emerald-400/15",
    text: "text-emerald-100",
    pill: "bg-emerald-400/15 text-emerald-100",
  };
}

function HubPanel({ hub }: { hub: RoutingHub }) {
  const roomRatio = hub.plannedRoomCount > 0 ? Math.min(1, hub.liveRoomCount / hub.plannedRoomCount) : 0;
  const displayedClasses = hub.classes.filter((classRoom) => classRoom.scheduledNow || classRoom.targetMemberCount > 0).slice(0, 10);

  return (
    <article className="overflow-hidden rounded-lg border border-white/10 bg-[#0B1628] shadow-[0_18px_60px_rgba(0,0,0,0.22)]">
      <header className="grid gap-3 border-b border-white/10 px-4 py-4 sm:grid-cols-[1fr_auto] sm:items-start">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <span className={`h-2.5 w-2.5 rounded-full ${hub.heartbeatFresh ? "bg-emerald-300 shadow-[0_0_12px_rgba(110,231,183,0.85)]" : "bg-amber-300"}`} />
            <h2 className="min-w-0 flex-1 truncate text-base font-black text-white">{hub.hostAccount || `Lane ${hub.lane}`}</h2>
            <span className="rounded-md border border-white/10 bg-white/[0.04] px-2 py-1 text-[11px] font-black uppercase tracking-[0.08em] text-white/60">
              Lane {hub.lane}
            </span>
          </div>
          <p className="mt-1 truncate text-xs font-semibold text-white/45">{hub.hubDocId}</p>
          <p className="mt-0.5 text-xs font-bold tabular-nums text-cyan-100/75">{hub.meetingNumber || "no meeting id"}</p>
        </div>
        <div className="flex flex-wrap gap-2 sm:justify-end">
          <StatusPill label={hub.roomsOpen ? "rooms open" : hub.status} good={hub.roomsOpen && hub.heartbeatFresh} />
          <StatusPill label={hub.heartbeatFresh ? "bot online" : "heartbeat stale"} good={hub.heartbeatFresh} />
        </div>
      </header>

      <section className="grid gap-4 px-4 py-4 lg:grid-cols-[minmax(0,0.95fr)_minmax(0,1.05fr)]">
        <div>
          <div className="grid grid-cols-4 gap-2">
            <HubStat label="In rooms" value={hub.inRoomOccupants} />
            <HubStat label="Attendees" value={hub.attendeeCount} />
            <HubStat label="Targets" value={hub.targetMemberCount} />
            <HubStat label="Actions" value={hub.lastRoutingActionCount} />
          </div>
          <div className="mt-4 rounded-lg border border-white/10 bg-black/15 p-3">
            <div className="mb-2 flex items-center justify-between text-xs font-black uppercase tracking-[0.1em] text-white/45">
              <span>Live rooms</span>
              <span>{hub.liveRoomCount} / {hub.plannedRoomCount}</span>
            </div>
            <div className="h-2 overflow-hidden rounded-full bg-white/10">
              <div className={`${hub.liveRoomCount === 0 && hub.targetMemberCount > 0 ? "bg-red-400" : "bg-cyan-300"} h-full rounded-full`} style={{ width: `${Math.round(roomRatio * 100)}%` }} />
            </div>
            <p className="mt-3 text-xs font-semibold leading-5 text-white/50">
              Window {formatClock(hub.windowStart)} - {formatClock(hub.windowEnd)} · heartbeat {formatAge(hub.heartbeatAgeMs)}
            </p>
            {hub.botError ? <p className="mt-2 rounded-md bg-red-500/10 px-3 py-2 text-xs font-bold text-red-100">{hub.botError}</p> : null}
            {hub.forceRejoinAt ? <p className="mt-2 rounded-md bg-amber-400/10 px-3 py-2 text-xs font-bold text-amber-100">Force rejoin stamped {formatClock(hub.forceRejoinAt)}</p> : null}
          </div>
        </div>

        <div className="min-w-0 rounded-lg border border-white/10 bg-black/15">
          <div className="flex items-center justify-between border-b border-white/10 px-3 py-2">
            <p className="text-xs font-black uppercase tracking-[0.1em] text-white/45">Class rooms</p>
            <span className="text-xs font-black text-cyan-200">{hub.classRoomCount}</span>
          </div>
          <div className="max-h-[55vh] overflow-y-auto sm:max-h-[340px]">
            {displayedClasses.length === 0 ? (
              <p className="px-3 py-5 text-sm font-semibold text-white/45">No target members in this hub.</p>
            ) : displayedClasses.map((classRoom) => (
              <ClassRoomRow key={`${classRoom.shiftId || classRoom.roomName}-${classRoom.roomName}`} classRoom={classRoom} />
            ))}
          </div>
        </div>
      </section>
    </article>
  );
}

function ClassRoomRow({ classRoom }: { classRoom: RoutingClass }) {
  return (
    <div className="grid gap-1.5 border-b border-white/5 px-3 py-3.5 last:border-b-0">
      <div className="flex min-w-0 items-center justify-between gap-3">
        <p className="min-w-0 truncate text-sm font-black text-white">{classRoom.title || classRoom.roomName}</p>
        <span className={`shrink-0 rounded-md px-2 py-1 text-[10px] font-black uppercase tracking-[0.06em] ${classRoom.scheduledNow ? "bg-emerald-400/15 text-emerald-200" : "bg-white/10 text-white/45"}`}>
          {classRoom.scheduledNow ? "now" : `${classRoom.targetMemberCount} target`}
        </span>
      </div>
      <p className="truncate text-xs font-semibold text-white/45">{classRoom.roomName}</p>
      <p className="truncate text-xs font-semibold text-white/55">
        {classRoom.teacherName || "Teacher not set"}{classRoom.studentNames.length ? ` · ${classRoom.studentNames.slice(0, 3).join(", ")}` : ""}
      </p>
    </div>
  );
}

function IncidentPanel({ incidents }: { incidents: RoutingIncident[] }) {
  return (
    <aside className="overflow-hidden rounded-lg border border-white/10 bg-[#0B1628] shadow-[0_18px_60px_rgba(0,0,0,0.22)]">
      <header className="flex items-center justify-between border-b border-white/10 px-4 py-3">
        <p className="text-xs font-black uppercase tracking-[0.14em] text-white/55">Incidents</p>
        <span className="rounded-md border border-white/10 bg-white/[0.04] px-2 py-1 text-xs font-black text-white/65">
          {incidents.filter((incident) => incident.open).length} open
        </span>
      </header>
      <div className="max-h-[50vh] overflow-y-auto xl:max-h-[520px]">
        {incidents.length === 0 ? (
          <p className="px-4 py-6 text-sm font-semibold text-white/45">No recent Zoom hub incidents.</p>
        ) : incidents.map((incident) => (
          <div key={incident.id} className="border-b border-white/5 px-4 py-3.5 last:border-b-0">
            <div className="flex items-start gap-3">
              <span className={`mt-1 h-2 w-2 rounded-full ${incident.severity === "critical" ? "bg-red-300" : "bg-amber-300"}`} />
              <div className="min-w-0 flex-1">
                <p className="text-sm font-bold leading-5 text-white">{incident.title}</p>
                <p className="mt-1 text-xs font-semibold text-white/45">
                  {formatClock(incident.createdAt)} · {incident.reason || "zoom_hub"}{incident.lane ? ` · lane ${incident.lane}` : ""}
                </p>
              </div>
              <span className={`rounded-md px-2 py-1 text-[11px] font-black uppercase tracking-[0.06em] ${incident.open ? "bg-red-400/15 text-red-100" : "bg-white/10 text-white/45"}`}>
                {incident.open ? "open" : "closed"}
              </span>
            </div>
          </div>
        ))}
      </div>
    </aside>
  );
}

function HubStat({ label, value }: { label: string; value: number }) {
  return (
    <div className="rounded-lg bg-white/[0.05] px-2.5 py-3">
      <p className="truncate text-[9px] font-black uppercase tracking-[0.08em] text-white/40 sm:text-[10px]">{label}</p>
      <p className="mt-1 text-lg font-black tabular-nums text-white sm:text-xl">{value}</p>
    </div>
  );
}

function StatusPill({ label, good }: { label: string; good: boolean }) {
  return (
    <span className={`rounded-md border px-2.5 py-1 text-[11px] font-black uppercase tracking-[0.08em] ${good ? "border-emerald-300/25 bg-emerald-400/10 text-emerald-200" : "border-amber-300/25 bg-amber-400/10 text-amber-100"}`}>
      {label}
    </span>
  );
}

function LoadingPanel() {
  return (
    <section className="mt-5 grid gap-4 lg:grid-cols-2">
      {[0, 1].map((item) => (
        <div key={item} className="h-56 animate-pulse rounded-lg border border-white/10 bg-white/[0.04]" />
      ))}
    </section>
  );
}

function RoutingAccessPrompt({ access }: { access: AccessState }) {
  const title = access === "signedOut" ? "Sign in required" : access === "denied" ? "Admin access required" : "Checking access";
  const body = access === "signedOut"
    ? "Use an administrator account to view Zoom routing status."
    : access === "denied"
      ? "This page is limited to administrators."
      : "Verifying your account.";
  return (
    <main className="min-h-screen bg-[#F8FAFC] px-4 py-12 text-[#0F172A]">
      <section className="mx-auto max-w-md rounded-lg border border-[#DDE7F2] bg-white p-6 shadow-[0_20px_70px_rgba(15,23,42,0.12)]">
        <span className="mb-4 inline-flex h-11 w-11 items-center justify-center rounded-lg bg-[#0386FF]/10 text-[#0369C9]">
          <Activity size={22} />
        </span>
        <h1 className="text-2xl font-black">{title}</h1>
        <p className="mt-3 text-sm font-semibold leading-6 text-[#64748B]">{body}</p>
        <div className="mt-5 flex gap-3">
          <Link href="/login/" className="inline-flex min-h-11 items-center rounded-lg bg-[#0386FF] px-4 text-sm font-black text-white">
            Log in
          </Link>
          <Link href="/admin/" className="inline-flex min-h-11 items-center rounded-lg border border-[#CBD5E1] px-4 text-sm font-black text-[#334155]">
            Dashboard
          </Link>
        </div>
      </section>
    </main>
  );
}

function formatClock(value: string | null) {
  if (!value) return "not available";
  const date = new Date(value);
  if (!Number.isFinite(date.getTime())) return "not available";
  return new Intl.DateTimeFormat("en-US", {
    hour: "numeric",
    minute: "2-digit",
    second: "2-digit",
    timeZoneName: "short",
  }).format(date);
}

function formatDateLabel(value: string | null) {
  if (!value) return "not available";
  const date = new Date(`${value}T12:00:00`);
  if (!Number.isFinite(date.getTime())) return value;
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
  }).format(date);
}

function formatAge(ms: number | null) {
  if (ms === null) return "not available";
  if (ms < 1000) return "just now";
  const seconds = Math.round(ms / 1000);
  if (seconds < 60) return `${seconds}s ago`;
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.round(minutes / 60);
  return `${hours}h ago`;
}
