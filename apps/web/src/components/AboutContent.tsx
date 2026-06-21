"use client";

import Link from "next/link";
import {
  ArrowDown,
  ArrowRight,
  BookOpen,
  Globe2,
  GraduationCap,
  HeartHandshake,
  Quote,
  Rocket,
  ShieldCheck,
  Sparkles,
  Star,
  UsersRound,
} from "lucide-react";
import { useEffect, useState } from "react";
import {
  loadPublicMarketingBundle,
  photoAssetToPath,
  type PublicSiteTeamMember,
} from "@/lib/publicSiteCms";

const values = [
  { title: "Authenticity", body: "Rooted in Quran and Sunnah", icon: ShieldCheck },
  { title: "Compassion", body: "Patience and care for all", icon: HeartHandshake },
  { title: "Excellence", body: "High standards in education", icon: Star },
  { title: "Community", body: "Supportive global network", icon: UsersRound },
  { title: "Knowledge", body: "Transformative learning", icon: BookOpen },
  { title: "Accessibility", body: "Available worldwide", icon: Globe2 },
] as const;

const timeline = [
  ["2020", "Vision Founded", "The seed of Alluwal was planted."],
  ["2021", "First Teachers", "Recruited passionate educators."],
  ["2022", "Platform Launch", "Officially opened our virtual doors."],
  ["2023", "Global Expansion", "Reached students in 20+ countries."],
  ["2024", "Growth", "New courses and 5,000+ students reached."],
] as const;

const stats = [
  ["5K+", "Happy Students"],
  ["200+", "Qualified Teachers"],
  ["50+", "Countries Served"],
  ["98%", "Satisfaction Rate"],
] as const;

export function AboutContent() {
  const [leadership, setLeadership] = useState<PublicSiteTeamMember[]>([]);

  useEffect(() => {
    let active = true;
    loadPublicMarketingBundle().then((bundle) => {
      if (!active) return;
      setLeadership(bundle.teamMembers.filter((member) => member.category.toLowerCase() === "leadership"));
    });
    return () => {
      active = false;
    };
  }, []);

  const founder = leadership[0];
  const otherLeaders = leadership.slice(1);

  return (
    <>
      <section className="bg-[#001E4E] px-6 py-20 text-white md:py-24">
        <div className="mx-auto max-w-[1200px] text-center">
          <div className="mx-auto inline-flex rounded-full bg-white/10 px-4 py-2 text-sm font-semibold">
            Learn. Lead. Thrive.
          </div>
          <h1 className="mx-auto mt-8 max-w-4xl text-4xl font-black leading-tight md:text-6xl">
            Where education transcends boundaries
          </h1>
          <p className="mx-auto mt-6 max-w-3xl text-lg leading-8 text-white/80">
            We are fostering a world where diverse knowledge, Islamic, African, and Western, comes together to prepare students for a globalized future.
          </p>
        </div>
      </section>

      <section className="px-6 py-20">
        <div className="mx-auto grid max-w-[1200px] gap-8 lg:grid-cols-2">
          <InfoCard
            icon={Rocket}
            title="Our Mission"
            color="#3B82F6"
            body="To integrate Islamic, African, and Western education, offering a holistic curriculum that prepares students to navigate and succeed in a diverse world."
          />
          <InfoCard
            icon={Sparkles}
            title="Our Vision"
            color="#10B981"
            body="To create an inclusive, inspiring environment where students are encouraged to become leaders in their communities."
          />
        </div>
      </section>

      <section className="bg-[#F8FAFC] px-6 py-20">
        <div className="mx-auto max-w-[1200px]">
          <h2 className="text-center text-4xl font-black text-slate-900">Core Values</h2>
          <div className="mt-12 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
            {values.map(({ title, body, icon: Icon }) => (
              <div key={title} className="rounded-lg bg-white p-6 text-center shadow-[0_8px_20px_rgba(15,23,42,0.05)]">
                <Icon className="mx-auto text-[#3B82F6]" size={40} />
                <h3 className="mt-4 text-xl font-bold text-slate-900">{title}</h3>
                <p className="mt-2 text-base text-slate-500">{body}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="px-6 py-20">
        <div className="mx-auto max-w-3xl">
          <h2 className="text-center text-4xl font-black text-slate-900">Our Journey</h2>
          <div className="mt-12 grid gap-4">
            {timeline.map(([year, title, body], index) => (
              <div key={year}>
                <div className="flex gap-6 rounded-lg border border-slate-200 bg-white p-6">
                  <div className="w-20 shrink-0 text-2xl font-black text-[#3B82F6]">{year}</div>
                  <div>
                    <h3 className="text-lg font-bold text-slate-900">{title}</h3>
                    <p className="mt-1 text-base text-slate-500">{body}</p>
                  </div>
                </div>
                {index < timeline.length - 1 ? <ArrowDown className="mx-auto my-4 text-slate-400" size={28} /> : null}
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="bg-[#F8FAFC] px-6 py-20">
        <div className="mx-auto max-w-[960px] text-center">
          <div className="inline-flex rounded-full border border-[#C9A84C]/30 bg-[#C9A84C]/10 px-4 py-2 text-xs font-black uppercase tracking-[0.18em] text-[#A37D18]">
            Our Leadership
          </div>
          <h2 className="mt-5 text-4xl font-black text-slate-900">Our Leadership</h2>
          <p className="mx-auto mt-4 max-w-xl leading-7 text-slate-500">
            Dedicated professionals driving our mission to make quality education accessible worldwide.
          </p>
          {founder ? <FounderCard member={founder} /> : <FounderFallbackCard />}
          {otherLeaders.length > 0 ? (
            <div className="mt-10 grid gap-4 md:grid-cols-2">
              {otherLeaders.map((member) => (
                <LeadershipMiniCard key={member.id} member={member} />
              ))}
            </div>
          ) : null}
          <Link href="/team/" className="alluwal-button alluwal-button-primary mx-auto mt-10 w-fit">
            Meet Our Full Team
            <ArrowRight size={18} />
          </Link>
        </div>
      </section>

      <section className="px-6 py-20">
        <div className="mx-auto grid max-w-[980px] gap-8 text-center sm:grid-cols-2 lg:grid-cols-4">
          {stats.map(([value, label]) => (
            <div key={label}>
              <div className="text-5xl font-black text-[#3B82F6]">{value}</div>
              <div className="mt-2 text-base font-semibold text-slate-500">{label}</div>
            </div>
          ))}
        </div>
      </section>

      <section className="bg-[#111827] px-6 py-16 text-center text-white">
        <Quote className="mx-auto text-white/25" size={48} />
        <p className="mx-auto mt-6 max-w-3xl text-2xl font-semibold italic leading-10">
          The best of people are those who are most beneficial to people.
        </p>
        <p className="mt-4 text-white/60">Prophet Muhammad, peace be upon him</p>
      </section>
    </>
  );
}

function FounderCard({ member }: { member: PublicSiteTeamMember }) {
  const image = teamImage(member);
  return (
    <div className="mt-10 rounded-lg bg-[#001E4E] p-8 text-left text-white shadow-[0_18px_48px_rgba(0,30,78,0.28)]">
      <div className="grid gap-8 md:grid-cols-[160px_1fr] md:items-center">
        <div className="grid justify-items-center gap-4">
          <div className="flex h-32 w-32 items-center justify-center overflow-hidden rounded-full bg-white/10 ring-4 ring-[#C9A84C]/40">
            {image ? (
              <img src={image} alt={member.name} className="h-full w-full object-cover" />
            ) : (
              <GraduationCap size={48} className="text-[#C9A84C]" />
            )}
          </div>
          <span className="rounded-full border border-[#C9A84C]/50 bg-[#C9A84C]/10 px-4 py-2 text-xs font-black uppercase tracking-[0.2em] text-[#C9A84C]">
            Founder
          </span>
        </div>
        <div>
          <h3 className="text-3xl font-black">{member.name}</h3>
          <p className="mt-2 text-xs font-bold uppercase tracking-[0.2em] text-[#C9A84C]">{member.role}</p>
          <p className="mt-5 leading-8 text-white/80">{truncate(member.bio || member.whyAlluwal, 220)}</p>
          <div className="mt-5 flex flex-wrap gap-2 text-sm font-semibold text-white/75">
            {member.city ? <span className="rounded-full border border-white/15 bg-white/10 px-3 py-1">{member.city}</span> : null}
            {member.education ? <span className="rounded-full border border-white/15 bg-white/10 px-3 py-1">{truncate(member.education, 42)}</span> : null}
          </div>
        </div>
      </div>
    </div>
  );
}

function FounderFallbackCard() {
  return (
    <div className="mt-10 rounded-lg bg-[#001E4E] p-8 text-left text-white shadow-[0_18px_48px_rgba(0,30,78,0.28)]">
      <div className="grid gap-8 md:grid-cols-[160px_1fr] md:items-center">
        <div className="grid justify-items-center gap-4">
          <div className="flex h-28 w-28 items-center justify-center rounded-full bg-white/10">
            <GraduationCap size={48} className="text-[#C9A84C]" />
          </div>
          <span className="rounded-full border border-[#C9A84C]/50 bg-[#C9A84C]/10 px-4 py-2 text-xs font-black uppercase tracking-[0.2em] text-[#C9A84C]">
            Founder
          </span>
        </div>
        <div>
          <h3 className="text-3xl font-black">Alluwal Education Hub</h3>
          <p className="mt-2 text-xs font-bold uppercase tracking-[0.2em] text-[#C9A84C]">Vision and direction</p>
          <p className="mt-5 leading-8 text-white/80">
            A leadership team focused on Islamic character, academic growth, and practical access for families around the world.
          </p>
        </div>
      </div>
    </div>
  );
}

function LeadershipMiniCard({ member }: { member: PublicSiteTeamMember }) {
  const image = teamImage(member);
  return (
    <article className="flex gap-4 rounded-lg border border-slate-200 bg-white p-5 text-left shadow-[0_8px_24px_rgba(15,23,42,0.05)]">
      <div className="flex h-[70px] w-[70px] shrink-0 items-center justify-center overflow-hidden rounded-full bg-slate-100">
        {image ? <img src={image} alt={member.name} className="h-full w-full object-cover" /> : <UsersRound className="text-slate-400" size={28} />}
      </div>
      <div className="min-w-0">
        <h3 className="text-base font-bold text-slate-900">{member.name}</h3>
        <p className="mt-1 text-[10px] font-black uppercase tracking-[0.14em] text-[#C9A84C]">{member.role}</p>
        <p className="mt-2 text-sm leading-6 text-slate-500">{member.city}</p>
      </div>
    </article>
  );
}

function teamImage(member: PublicSiteTeamMember) {
  return member.imageUrl || photoAssetToPath(member.photoAsset) || null;
}

function truncate(value: string, maxLength: number) {
  if (value.length <= maxLength) return value;
  return `${value.slice(0, maxLength).trim()}...`;
}

function InfoCard({
  icon: Icon,
  title,
  color,
  body,
}: {
  icon: typeof Rocket;
  title: string;
  color: string;
  body: string;
}) {
  return (
    <article className="rounded-lg border border-slate-200 bg-white p-8 shadow-[0_10px_30px_rgba(15,23,42,0.05)]">
      <div className="inline-flex rounded-xl p-3" style={{ backgroundColor: `${color}1A`, color }}>
        <Icon size={32} />
      </div>
      <h2 className="mt-6 text-2xl font-bold text-slate-900">{title}</h2>
      <p className="mt-4 text-base leading-7 text-slate-500">{body}</p>
    </article>
  );
}
