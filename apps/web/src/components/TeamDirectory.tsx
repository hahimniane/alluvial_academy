"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import {
  ArrowRight,
  BookOpen,
  BriefcaseBusiness,
  Code2,
  GraduationCap,
  Heart,
  Languages,
  Mail,
  MapPin,
  School,
  Sparkles,
  Star,
  UserRound,
  UsersRound,
  X,
  type LucideIcon,
} from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import {
  loadPublicMarketingBundle,
  photoAssetToPath,
  type PublicSiteTeamMember,
} from "@/lib/publicSiteCms";

const navy = "#001E4E";
const gold = "#C9A84C";
const teal = "#0D9488";

type CategoryId = "all" | "leadership" | "teacher";

type CategoryTheme = {
  id: CategoryId;
  label: string;
  tagline: string;
  description: string;
  icon: LucideIcon;
  accent: string;
  accentLight: string;
};

const categories: CategoryTheme[] = [
  {
    id: "all",
    label: "All Team",
    tagline: "The full Alluwal family",
    description: "Visionaries and educators united by one mission.",
    icon: UsersRound,
    accent: navy,
    accentLight: "#E8EEF7",
  },
  {
    id: "leadership",
    label: "Leadership",
    tagline: "Vision & Direction",
    description: "The architects and coordinators of Alluwal - shaping policy, strategy, operations and culture.",
    icon: Star,
    accent: gold,
    accentLight: "#FBF4E3",
  },
  {
    id: "teacher",
    label: "Teachers",
    tagline: "Global Knowledge Carriers",
    description: "Scholars and educators spanning 10+ countries - bringing Islamic and academic excellence to every learner, everywhere.",
    icon: BookOpen,
    accent: "#6366F1",
    accentLight: "#EEEEFD",
  },
];

const gradientPalette = [
  ["#667eea", "#764ba2"],
  ["#f093fb", "#f5576c"],
  ["#4facfe", "#00f2fe"],
  ["#43e97b", "#38f9d7"],
  ["#fa709a", "#fee140"],
  ["#a18cd1", "#fbc2eb"],
];

export function TeamDirectory() {
  const searchParams = useSearchParams();
  const requestedCategory = normalizeCategory(searchParams.get("category"));
  const [members, setMembers] = useState<PublicSiteTeamMember[]>([]);
  const [selectedCategory, setSelectedCategory] = useState<CategoryId>(requestedCategory ?? "all");
  const [selectedMember, setSelectedMember] = useState<PublicSiteTeamMember | null>(null);

  useEffect(() => {
    let active = true;
    loadPublicMarketingBundle().then((bundle) => {
      if (active) setMembers(bundle.teamMembers);
    });
    return () => {
      active = false;
    };
  }, []);

  useEffect(() => {
    if (requestedCategory) setSelectedCategory(requestedCategory);
  }, [requestedCategory]);

  useEffect(() => {
    if (!selectedMember) return;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = previousOverflow;
    };
  }, [selectedMember]);

  const selectedTheme = getTheme(selectedCategory);
  const filtered = useMemo(() => {
    if (selectedCategory === "all") return members;
    return members.filter((member) => member.category === selectedCategory);
  }, [members, selectedCategory]);

  return (
    <div className="bg-[#F8FAFC]">
      <TeamHero members={members} />
      <FilterBar
        members={members}
        selectedCategory={selectedCategory}
        onSelect={setSelectedCategory}
      />
      <CategoryContext theme={selectedTheme} />
      <TeamRoster
        filtered={filtered}
        selectedCategory={selectedCategory}
        onSelectMember={setSelectedMember}
      />
      <JoinTeamCta />
      {selectedMember ? (
        <StaffDetailSheet member={selectedMember} onClose={() => setSelectedMember(null)} />
      ) : null}
    </div>
  );
}

function TeamHero({ members }: { members: PublicSiteTeamMember[] }) {
  const preview = members.slice(0, 5);
  return (
    <section className="bg-[#001E4E] px-5 pb-14 pt-20 text-white md:pb-14 md:pt-20">
      <div className="mx-auto flex max-w-[920px] flex-col items-center text-center">
        <div className="rounded-full border border-[#C9A84C]/30 bg-[#C9A84C]/15 px-4 py-2 text-[13px] font-bold uppercase tracking-[1.5px] text-[#C9A84C]">
          Our Global Team
        </div>
        <h1 className="mt-8 text-[28px] font-extrabold leading-[1.15] text-white md:text-[48px] md:leading-[1.1]">
          Meet the People Behind Alluwal
        </h1>
        <p className="mt-5 max-w-[650px] text-[15px] leading-[1.55] text-white/88 md:mt-6 md:text-[18px]">
          Educators, leaders, and innovators united by a shared mission — to make quality Islamic and academic education accessible to every learner, everywhere.
        </p>
        {preview.length > 0 ? (
          <div className="mt-9 flex items-center justify-center">
            {preview.map((member) => (
              <div key={member.id} className="px-[3px]">
                <StaffAvatar member={member} size={40} borderClassName="border-[#001E4E]" />
              </div>
            ))}
            <div className="ml-[6px] flex h-10 w-10 items-center justify-center rounded-full border-[1.5px] border-[#C9A84C] bg-[#C9A84C]/20 text-[22px] font-bold text-[#C9A84C]">
              +
            </div>
          </div>
        ) : null}
      </div>
    </section>
  );
}

function FilterBar({
  members,
  selectedCategory,
  onSelect,
}: {
  members: PublicSiteTeamMember[];
  selectedCategory: CategoryId;
  onSelect: (category: CategoryId) => void;
}) {
  return (
    <section className="px-6 pt-9">
      <div className="mx-auto flex max-w-[1400px] justify-start overflow-x-auto pb-1 md:justify-center">
        <div className="flex min-w-max gap-2.5">
          {categories.map((theme) => {
            const selected = selectedCategory === theme.id;
            const count =
              theme.id === "all"
                ? members.length
                : members.filter((member) => member.category === theme.id).length;
            const Icon = theme.icon;
            return (
              <button
                key={theme.id}
                type="button"
                className="flex min-h-[58px] min-w-[168px] items-center rounded-2xl border px-4 py-3 text-left transition duration-200"
                style={{
                  backgroundColor: selected ? theme.accent : "#FFFFFF",
                  borderColor: selected ? theme.accent : "#E5E7EB",
                  boxShadow: selected ? `0 6px 16px ${hexToRgba(theme.accent, 0.25)}` : "none",
                }}
                onClick={() => onSelect(theme.id)}
              >
                <span
                  className="flex h-[27px] w-[27px] shrink-0 items-center justify-center rounded-lg"
                  style={{ backgroundColor: selected ? "rgba(255,255,255,0.2)" : theme.accentLight }}
                >
                  <Icon size={15} color={selected ? "#FFFFFF" : theme.accent} />
                </span>
                <span className="ml-2.5 min-w-0 flex-1">
                  <span
                    className="block truncate text-[13px] font-bold leading-tight"
                    style={{ color: selected ? "#FFFFFF" : "#111827" }}
                  >
                    {theme.label}
                  </span>
                  <span
                    className="mt-1 block max-w-[116px] text-[10px] leading-[1.25]"
                    style={{ color: selected ? "rgba(255,255,255,0.82)" : "#6B7280" }}
                  >
                    {theme.tagline}
                  </span>
                </span>
                <span
                  className="ml-2.5 rounded-lg px-[7px] py-[3px] text-[12px] font-extrabold"
                  style={{
                    backgroundColor: selected ? "rgba(255,255,255,0.22)" : theme.accentLight,
                    color: selected ? "#FFFFFF" : theme.accent,
                  }}
                >
                  {count}
                </span>
              </button>
            );
          })}
        </div>
      </div>
    </section>
  );
}

function CategoryContext({ theme }: { theme: CategoryTheme }) {
  const Icon = theme.icon;
  return (
    <section className="px-6 pt-4">
      <div
        className="mx-auto flex max-w-[1392px] items-center rounded-[14px] border px-[18px] py-3.5"
        style={{ backgroundColor: theme.accentLight, borderColor: hexToRgba(theme.accent, 0.2) }}
      >
        <span
          className="flex h-[40px] w-[40px] shrink-0 items-center justify-center rounded-[10px]"
          style={{ backgroundColor: hexToRgba(theme.accent, 0.14) }}
        >
          <Icon size={18} color={theme.accent} />
        </span>
        <span className="ml-3.5 min-w-0">
          <span className="block text-[14px] font-bold text-[#111827]">{theme.label}</span>
          <span className="mt-0.5 block text-[12.5px] leading-[1.5] text-[#4B5563]">
            {theme.description}
          </span>
        </span>
      </div>
    </section>
  );
}

function TeamRoster({
  filtered,
  selectedCategory,
  onSelectMember,
}: {
  filtered: PublicSiteTeamMember[];
  selectedCategory: CategoryId;
  onSelectMember: (member: PublicSiteTeamMember) => void;
}) {
  if (filtered.length === 0) {
    return (
      <section className="mx-auto max-w-[1400px] px-6 pt-1">
        <div className="grid gap-4 md:grid-cols-3">
          {Array.from({ length: 6 }, (_, index) => (
            <div key={index} className="h-[220px] animate-pulse rounded-[18px] bg-white shadow-[0_8px_16px_rgba(0,0,0,0.05)]" />
          ))}
        </div>
      </section>
    );
  }

  if (selectedCategory === "all") {
    const leadership = filtered.filter((member) => member.category === "leadership");
    const teachers = filtered.filter((member) => member.category === "teacher");
    const founder = leadership[0];
    const leadershipRest = leadership.slice(1);
    return (
      <section className="mx-auto max-w-[1400px] px-6 pt-10">
        {founder ? <FounderSpotlight member={founder} onSelect={() => onSelectMember(founder)} /> : null}
        {leadershipRest.length > 0 ? (
          <CategoryGroup
            category="leadership"
            members={leadershipRest}
            onSelectMember={onSelectMember}
          />
        ) : null}
        {teachers.length > 0 ? (
          <CategoryGroup
            category="teacher"
            members={teachers}
            onSelectMember={onSelectMember}
          />
        ) : null}
      </section>
    );
  }

  if (selectedCategory === "leadership") {
    const founder = filtered[0];
    const rest = filtered.slice(1);
    return (
      <section className="mx-auto max-w-[1400px] px-6 pt-4">
        {founder ? <FounderSpotlight member={founder} onSelect={() => onSelectMember(founder)} /> : null}
        {rest.length > 0 ? (
          <LeadershipGrid members={rest} onSelectMember={onSelectMember} />
        ) : null}
      </section>
    );
  }

  return (
    <section className="mx-auto max-w-[1400px] px-6 pt-2">
      <TeacherRoster members={filtered} onSelectMember={onSelectMember} />
    </section>
  );
}

function CategoryGroup({
  category,
  members,
  onSelectMember,
}: {
  category: "leadership" | "teacher";
  members: PublicSiteTeamMember[];
  onSelectMember: (member: PublicSiteTeamMember) => void;
}) {
  const theme = getTheme(category);
  const Icon = theme.icon;
  return (
    <div className="pt-10">
      <div className="mb-5 flex items-center">
        <span
          className="flex h-8 w-8 items-center justify-center rounded-[10px]"
          style={{ backgroundColor: theme.accentLight }}
        >
          <Icon size={16} color={theme.accent} />
        </span>
        <h2 className="ml-3 text-[22px] font-extrabold text-[#111827]">{theme.label}</h2>
        <span
          className="ml-2.5 rounded-[10px] px-[9px] py-1 text-[12px] font-extrabold"
          style={{ backgroundColor: theme.accentLight, color: theme.accent }}
        >
          {members.length}
        </span>
      </div>
      {category === "teacher" ? (
        <TeacherRoster members={members} onSelectMember={onSelectMember} />
      ) : (
        <LeadershipGrid members={members} onSelectMember={onSelectMember} />
      )}
    </div>
  );
}

function FounderSpotlight({
  member,
  onSelect,
}: {
  member: PublicSiteTeamMember;
  onSelect: () => void;
}) {
  return (
    <button
      type="button"
      className="group relative mb-12 block w-full overflow-hidden rounded-[28px] bg-gradient-to-br from-[#001024] via-[#001E4E] to-[#0D2D6B] text-left shadow-[0_20px_50px_rgba(0,30,78,0.45)]"
      onClick={onSelect}
    >
      <div className="absolute inset-x-0 top-0 h-[3px] bg-gradient-to-r from-[#C9A84C] to-[#0D9488]" />
      <div className="px-7 py-9 md:px-9 md:py-11">
        <div className="grid gap-8 md:grid-cols-[180px_1fr] md:items-center">
          <div className="flex flex-col items-center">
            <div className="rounded-full bg-gradient-to-br from-[#C9A84C] via-[#E8C66A] to-[#0D9488] p-[3px]">
              <div className="rounded-full bg-[#001E4E] p-1">
                <StaffAvatar member={member} size={128} borderClassName="border-transparent" />
              </div>
            </div>
            <span className="mt-5 rounded-full border border-[#C9A84C]/50 bg-[#C9A84C]/12 px-3.5 py-[7px] text-[11px] font-extrabold uppercase tracking-[2.5px] text-[#C9A84C]">
              Founder
            </span>
          </div>
          <div className="text-center md:text-left">
            <h2 className="text-[28px] font-extrabold leading-[1.1] text-white md:text-[38px]">
              {member.name}
            </h2>
            <p className="mt-2 text-[12px] font-bold uppercase tracking-[2.5px] text-[#C9A84C]">
              {member.role}
            </p>
            <div className="mx-auto mt-5 h-0.5 w-14 rounded-full bg-gradient-to-r from-[#C9A84C] to-[#0D9488] md:mx-0" />
            <p className="mt-5 text-[14px] italic leading-[1.7] text-white/78 md:text-[15px] md:leading-[1.75]">
              "{truncate(member.bio, 200)}"
            </p>
            <div className="mt-6 flex flex-wrap justify-center gap-2.5 md:justify-start">
              <FounderChip icon={MapPin} label={cityLabel(member)} />
              <FounderChip icon={School} label={truncate(member.education, 32)} />
            </div>
            <span className="mt-7 inline-flex items-center rounded-full bg-[#C9A84C] px-6 py-3 text-[14px] font-bold text-[#001E4E] shadow-[0_8px_18px_rgba(201,168,76,0.4)]">
              View Full Profile
              <ArrowRight size={16} className="ml-2" />
            </span>
          </div>
        </div>
      </div>
    </button>
  );
}

function FounderChip({ icon: Icon, label }: { icon: LucideIcon; label: string }) {
  return (
    <span className="inline-flex items-center rounded-full border border-white/15 bg-white/7 px-3 py-[7px] text-[13px] text-white/80">
      <Icon size={13} className="mr-1.5 text-white/65" />
      {label}
    </span>
  );
}

function LeadershipGrid({
  members,
  onSelectMember,
}: {
  members: PublicSiteTeamMember[];
  onSelectMember: (member: PublicSiteTeamMember) => void;
}) {
  return (
    <div className="grid gap-4 sm:grid-cols-2 md:grid-cols-3 xl:grid-cols-5">
      {members.map((member) => (
        <StaffCard key={member.id} member={member} onSelect={() => onSelectMember(member)} />
      ))}
    </div>
  );
}

function StaffCard({
  member,
  onSelect,
}: {
  member: PublicSiteTeamMember;
  onSelect: () => void;
}) {
  const theme = getTheme(member.category as CategoryId);
  return (
    <button
      type="button"
      className="group flex min-h-[300px] flex-col overflow-hidden rounded-[20px] bg-white text-center shadow-[0_8px_16px_rgba(0,0,0,0.06)] transition duration-200 hover:shadow-[0_8px_26px_rgba(0,0,0,0.09)]"
      onClick={onSelect}
      style={{ border: `1px solid transparent` }}
    >
      <div
        className="h-1"
        style={{
          background: `linear-gradient(90deg, ${theme.accent}, ${hexToRgba(theme.accent, 0.45)})`,
        }}
      />
      <div className="flex flex-1 flex-col items-center px-3.5 pb-2.5 pt-[18px]">
        <StaffAvatar member={member} size={66} borderClassName="border-white" />
        <h3 className="mt-2.5 line-clamp-2 text-[13px] font-bold leading-[1.2] text-[#111827]">
          {member.name}
        </h3>
        <span
          className="mt-1.5 max-w-full rounded-full px-2 py-[3px] text-[8.5px] font-extrabold uppercase tracking-[0.6px]"
          style={{ backgroundColor: theme.accentLight, color: theme.accent }}
        >
          {member.role}
        </span>
        <div className="mt-2 flex max-w-full items-start justify-center text-[10px] text-[#6B7280]">
          <MapPin size={11} className="mr-0.5 mt-[1px] shrink-0" />
          <span className="line-clamp-2">{cityLabel(member)}</span>
        </div>
        <p className="mt-2.5 line-clamp-3 w-full flex-1 rounded-[10px] bg-[#F8FAFC] p-2.5 text-left text-[10.5px] leading-[1.55] text-[#6B7280] group-hover:bg-[var(--team-light)]" style={{ "--team-light": theme.accentLight } as React.CSSProperties}>
          {cardSnippet(member)}
        </p>
        <div className="mt-2 flex flex-wrap justify-center gap-1">
          {member.languages.slice(0, 3).map((language) => (
            <span key={language} className="rounded-md border border-[#E5E7EB] bg-white px-[7px] py-[3px] text-[9.5px] font-semibold text-[#6B7280]">
              {language}
            </span>
          ))}
        </div>
      </div>
      <div className="flex h-[30px] items-center justify-center text-[10.5px] font-bold text-[#6B7280]/40 transition group-hover:bg-slate-50 group-hover:text-[#6B7280]">
        View Profile
        <ArrowRight size={10} className="ml-1" />
      </div>
    </button>
  );
}

function TeacherRoster({
  members,
  onSelectMember,
}: {
  members: PublicSiteTeamMember[];
  onSelectMember: (member: PublicSiteTeamMember) => void;
}) {
  return (
    <div className="grid gap-2.5 md:grid-cols-2">
      {members.map((member) => (
        <TeacherRosterCard key={member.id} member={member} onSelect={() => onSelectMember(member)} />
      ))}
    </div>
  );
}

function TeacherRosterCard({
  member,
  onSelect,
}: {
  member: PublicSiteTeamMember;
  onSelect: () => void;
}) {
  return (
    <button
      type="button"
      className="group flex items-start rounded-[18px] border border-[#E8E8F8] bg-white p-3.5 text-left shadow-[0_4px_10px_rgba(0,0,0,0.05)] transition duration-200 hover:border-[#6366F1]/40 hover:bg-[#F5F5FE] hover:shadow-[0_4px_22px_rgba(99,102,241,0.12)]"
      onClick={onSelect}
    >
      <div className="rounded-full bg-gradient-to-br from-[#E8E8F8] to-[#DDDDF8] p-[2.5px] transition group-hover:from-[#6366F1] group-hover:to-[#A5B4FC]">
        <StaffAvatar member={member} size={56} borderClassName="border-white" />
      </div>
      <div className="ml-3 min-w-0 flex-1">
        <div className="flex items-start gap-1.5">
          <div className="min-w-0 flex-1">
            <h3 className="truncate text-[13.5px] font-bold leading-[1.2] text-[#111827]">
              {member.name}
            </h3>
            <span className="mt-1 inline-flex max-w-full rounded-full bg-[#EEEEFD] px-2 py-[2.5px] text-[9.5px] font-bold tracking-[0.3px] text-[#6366F1]">
              <span className="line-clamp-2">{member.role}</span>
            </span>
            {member.id === "aliou_diallo" ? (
              <div className="mt-1 flex text-[9px] leading-[1.25] text-[#6B7280]">
                <Code2 size={9} className="mr-1 mt-[1px] shrink-0 text-[#6366F1]/80" />
                <span className="line-clamp-3">Part of the team that builds the platform.</span>
              </div>
            ) : null}
          </div>
          <span className="flex h-[21px] w-[21px] shrink-0 items-center justify-center rounded-full bg-[#EEEEFD] text-[#6366F1] transition group-hover:bg-[#6366F1] group-hover:text-white">
            <ArrowRight size={11} />
          </span>
        </div>
        <div className="mt-2">
          <div className="flex items-start text-[10.5px] font-medium text-[#6B7280]">
            <MapPin size={11} className="mr-1 mt-[1px] shrink-0 text-[#6366F1]/70" />
            <span className="line-clamp-2">{cityLabel(member)}</span>
          </div>
          {member.education ? (
            <span className="mt-1.5 inline-flex rounded-md border border-[#86EFAC] bg-[#F0FDF4] px-1.5 py-0.5 text-[9px] font-semibold text-[#16A34A]">
              <span className="line-clamp-2">{member.education.split("—")[0].split("-")[0].trim()}</span>
            </span>
          ) : null}
        </div>
        <p className="mt-2 line-clamp-4 text-[10.5px] leading-[1.45] text-[#6B7280]">
          {cardSnippet(member)}
        </p>
        <div className="mt-2 flex flex-wrap gap-1">
          {member.languages.slice(0, 4).map((language) => (
            <span key={language} className="inline-flex items-center rounded-md border border-[#E5E7EB] bg-white px-[7px] py-[3px] text-[9.5px] font-semibold text-[#6B7280] group-hover:border-[#6366F1]/30 group-hover:text-[#6366F1]">
              <Languages size={9} className="mr-1" />
              {language}
            </span>
          ))}
        </div>
      </div>
    </button>
  );
}

function JoinTeamCta() {
  return (
    <section className="mt-12 bg-gradient-to-r from-[#3B82F6] to-[#1E40AF] px-6 py-20 text-center text-white">
      <h2 className="text-[30px] font-extrabold leading-tight md:text-[36px]">
        Want to Join Our Team?
      </h2>
      <p className="mx-auto mt-4 max-w-[600px] text-[16px] leading-[1.6] text-white/90">
        We are always looking for passionate educators and professionals who share our vision. Join us in making a difference.
      </p>
      <div className="mt-8 flex flex-wrap justify-center gap-3">
        <Link
          href="/teacher-application/"
          className="inline-flex min-h-[54px] items-center rounded-xl bg-white px-7 text-[15px] font-bold text-[#3B82F6]"
        >
          <GraduationCap size={20} className="mr-2" />
          Apply to Teach
        </Link>
        <Link
          href="/contact/"
          className="inline-flex min-h-[54px] items-center rounded-xl border-2 border-white px-7 text-[15px] font-bold text-white"
        >
          <Mail size={20} className="mr-2" />
          Contact Us
        </Link>
      </div>
    </section>
  );
}

function StaffDetailSheet({
  member,
  onClose,
}: {
  member: PublicSiteTeamMember;
  onClose: () => void;
}) {
  const theme = getTheme(member.category as CategoryId);
  const Icon = theme.icon;
  return (
    <div className="fixed inset-0 z-[80] bg-slate-950/45" role="dialog" aria-modal="true" aria-label={`${member.name} profile`}>
      <button type="button" className="absolute inset-0 h-full w-full cursor-default" aria-label="Close profile" onClick={onClose} />
      <div className="absolute inset-x-0 bottom-0 mx-auto max-h-[96vh] max-w-[860px] overflow-y-auto rounded-t-[28px] bg-white shadow-2xl">
        <div className="sticky top-0 z-10 flex justify-center bg-white pt-2">
          <span className="h-1 w-10 rounded-full bg-slate-300" />
          <button
            type="button"
            className="absolute right-4 top-3 flex h-9 w-9 items-center justify-center rounded-full bg-slate-100 text-slate-700"
            aria-label="Close profile"
            onClick={onClose}
          >
            <X size={18} />
          </button>
        </div>
        <div
          className="mt-2 px-6 py-5 text-center"
          style={{
            background: `linear-gradient(180deg, ${hexToRgba(theme.accent, 0.13)}, ${hexToRgba(theme.accent, 0.03)})`,
          }}
        >
          <span
            className="inline-flex items-center rounded-full border px-3 py-1.5 text-[9px] font-extrabold uppercase tracking-[1.2px]"
            style={{ backgroundColor: theme.accentLight, borderColor: hexToRgba(theme.accent, 0.25), color: theme.accent }}
          >
            <Icon size={11} className="mr-1.5" />
            {theme.label}
          </span>
          <div className="mt-4 flex justify-center">
            <StaffAvatar member={member} size={104} borderClassName="border-white" />
          </div>
        </div>
        <div className="px-6 pb-7 text-center">
          <h2 className="mt-2 text-[24px] font-extrabold leading-[1.1] text-[#111827]">
            {member.name}
          </h2>
          <span
            className="mt-2 inline-flex items-center rounded-full px-3.5 py-1.5 text-[11px] font-extrabold uppercase tracking-[1.8px]"
            style={{ backgroundColor: theme.accentLight, color: theme.accent }}
          >
            <Icon size={13} className="mr-2" />
            {member.role}
          </span>
          <div className="mt-3 flex flex-wrap justify-center gap-2">
            <DetailChip icon={MapPin} label={cityLabel(member)} />
            {member.education ? <DetailChip icon={School} label={member.education} /> : null}
          </div>
          <div className="my-4 flex items-center">
            <span className="h-px flex-1 bg-[#F3F4F6]" />
            <span
              className="mx-2.5 flex h-6 w-6 items-center justify-center rounded-full"
              style={{ backgroundColor: theme.accentLight, color: theme.accent }}
            >
              <Sparkles size={12} />
            </span>
            <span className="h-px flex-1 bg-[#F3F4F6]" />
          </div>
          <div className="grid gap-3 text-left md:grid-cols-2">
            <DetailSection
              icon={UserRound}
              title={`About ${member.name.split(" ")[0]}`}
              content={member.bio || "Profile details are coming soon."}
              accent={theme.accent}
              light={theme.accentLight}
            />
            <DetailSection
              icon={Heart}
              title="Why Alluwal"
              content={member.whyAlluwal || "This team member is part of Alluwal's mission to support learners and families."}
              accent={teal}
              light="#E6F6F5"
              quote
            />
          </div>
          <div className="mt-5 text-left">
            <div className="mb-2 flex items-center text-[14px] font-bold text-[#111827]">
              <Languages size={15} className="mr-1.5 text-[#6B7280]" />
              Languages
            </div>
            <div className="flex flex-wrap gap-1.5">
              {member.languages.map((language) => (
                <span
                  key={language}
                  className="rounded-full border px-3 py-1.5 text-[12px] font-semibold"
                  style={{ backgroundColor: theme.accentLight, borderColor: hexToRgba(theme.accent, 0.2), color: theme.accent }}
                >
                  {language}
                </span>
              ))}
            </div>
          </div>
          <a
            href={`mailto:support@alluwaleducationhub.org?subject=${encodeURIComponent(`Message for ${member.name}`)}`}
            className="mt-5 inline-flex min-h-[48px] w-full items-center justify-center rounded-xl px-5 text-[15px] font-bold text-white"
            style={{ backgroundColor: theme.accent }}
          >
            <Mail size={18} className="mr-2" />
            Contact {member.name.split(" ")[0]}
          </a>
        </div>
      </div>
    </div>
  );
}

function DetailChip({ icon: Icon, label }: { icon: LucideIcon; label: string }) {
  if (!label) return null;
  return (
    <span className="inline-flex max-w-full items-center rounded-full border border-[#E5E7EB] bg-[#F9FAFB] px-3 py-1.5 text-[12px] font-semibold text-[#6B7280]">
      <Icon size={13} className="mr-1.5 shrink-0" />
      <span className="line-clamp-2">{label}</span>
    </span>
  );
}

function DetailSection({
  icon: Icon,
  title,
  content,
  accent,
  light,
  quote,
}: {
  icon: LucideIcon;
  title: string;
  content: string;
  accent: string;
  light: string;
  quote?: boolean;
}) {
  return (
    <section className="rounded-2xl border border-[#F3F4F6] bg-white p-4 shadow-sm">
      <div className="mb-3 flex items-center">
        <span className="flex h-8 w-8 items-center justify-center rounded-[10px]" style={{ backgroundColor: light }}>
          <Icon size={16} color={accent} />
        </span>
        <h3 className="ml-2.5 text-[14px] font-bold text-[#111827]">{title}</h3>
      </div>
      <p className={`text-[13px] leading-[1.7] text-[#4B5563] ${quote ? "italic" : ""}`}>
        {content}
      </p>
    </section>
  );
}

function StaffAvatar({
  member,
  size,
  borderClassName,
}: {
  member: PublicSiteTeamMember;
  size: number;
  borderClassName: string;
}) {
  const [failed, setFailed] = useState(false);
  const src = failed ? null : avatarSrc(member);

  useEffect(() => {
    setFailed(false);
  }, [member.id]);

  if (!src) {
    const [start, end] = avatarGradient(member.name);
    return (
      <span
        className={`flex shrink-0 items-center justify-center rounded-full border-2 ${borderClassName} font-bold text-white shadow-[0_1px_6px_rgba(0,0,0,0.2)]`}
        style={{
          width: size,
          height: size,
          fontSize: Math.round(size * 0.36),
          background: `linear-gradient(135deg, ${start}, ${end})`,
        }}
      >
        {initials(member.name)}
      </span>
    );
  }

  return (
    <img
      src={src}
      alt={member.name}
      width={size}
      height={size}
      className={`shrink-0 rounded-full border-2 ${borderClassName} object-cover shadow-[0_1px_6px_rgba(0,0,0,0.2)]`}
      style={{ width: size, height: size }}
      onError={() => setFailed(true)}
    />
  );
}

function normalizeCategory(value: string | null): CategoryId | null {
  if (value === "teacher" || value === "leadership" || value === "all") return value;
  return null;
}

function getTheme(category: CategoryId | string): CategoryTheme {
  return categories.find((item) => item.id === category) ?? categories[0];
}

function avatarSrc(member: PublicSiteTeamMember) {
  return member.imageUrl || photoAssetToPath(member.photoAsset);
}

function initials(name: string) {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? "")
    .join("");
}

function avatarGradient(name: string) {
  const total = Array.from(name).reduce((sum, char) => sum + char.charCodeAt(0), 0);
  return gradientPalette[total % gradientPalette.length];
}

function cityLabel(member: PublicSiteTeamMember) {
  return member.city || "Location to be announced";
}

function cardSnippet(member: PublicSiteTeamMember) {
  return member.bio || member.whyAlluwal || "Profile details are coming soon.";
}

function truncate(value: string, length: number) {
  if (!value || value.length <= length) return value;
  return `${value.slice(0, length)}...`;
}

function hexToRgba(hex: string, alpha: number) {
  const normalized = hex.replace("#", "");
  const value = normalized.length === 3
    ? normalized.split("").map((char) => `${char}${char}`).join("")
    : normalized;
  const number = Number.parseInt(value, 16);
  const red = (number >> 16) & 255;
  const green = (number >> 8) & 255;
  const blue = number & 255;
  return `rgba(${red}, ${green}, ${blue}, ${alpha})`;
}
