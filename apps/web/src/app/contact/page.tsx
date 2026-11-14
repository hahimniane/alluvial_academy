"use client";

import { Mail, MapPin } from "lucide-react";
import { ContactForm } from "@/components/ContactForm";
import { PageShell } from "@/components/PageShell";
import { usePublicT } from "@/lib/publicI18n";

export default function ContactPage() {
  const t = usePublicT();
  return (
    <PageShell>
      <section className="bg-[#001E4E] px-6 py-20 text-center text-white">
        <h1 className="text-5xl font-extrabold leading-tight">{t("Get In Touch")}</h1>
        <p className="mt-4 text-lg text-white/80">{t("We’d love to hear from you")}</p>
        <p className="mx-auto mt-6 max-w-[700px] text-base leading-[1.6] text-white/70">
          {t("We are building a learning community where Islamic, African, and Western knowledge come together to equip students with the understanding and skills they need to thrive in today’s world.")}
        </p>
      </section>

      <section className="bg-white px-6 py-20">
        <div className="mx-auto grid max-w-[1200px] gap-16 lg:grid-cols-2 lg:items-start">
          <ContactForm />
          <ContactInformation />
        </div>
      </section>
    </PageShell>
  );
}

function ContactInformation() {
  const t = usePublicT();
  return (
    <div className="order-first lg:order-none">
      <h2 className="text-2xl font-bold text-[#111827]">{t("Contact Information")}</h2>
      <div className="mt-8 grid gap-6">
        <InfoItem
          icon={Mail}
          label={t("Email")}
          value="support@alluwaleducationhub.org"
          href="mailto:support@alluwaleducationhub.org"
        />
        <InfoItem icon={MapPin} label={t("Location")} value={t("Global Online Platform")} />
      </div>
    </div>
  );
}

function InfoItem({
  icon: Icon,
  label,
  value,
  href,
}: {
  icon: typeof Mail;
  label: string;
  value: string;
  href?: string;
}) {
  const valueContent = (
    <span
      className={`text-base font-semibold ${
        href ? "text-[#3B82F6] underline decoration-[#3B82F6]" : "text-[#111827]"
      }`}
    >
      {value}
    </span>
  );

  return (
    <div className="flex items-center gap-4">
      <span className="inline-flex h-[50px] w-[50px] shrink-0 items-center justify-center rounded-xl border border-slate-200 bg-[#F3F4F6] text-[#3B82F6]">
        <Icon size={24} />
      </span>
      <div>
        <div className="text-sm text-[#6B7280]">{label}</div>
        {href ? <a href={href}>{valueContent}</a> : valueContent}
      </div>
    </div>
  );
}
