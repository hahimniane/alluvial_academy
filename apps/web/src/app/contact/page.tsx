import { Mail, MapPin, Phone } from "lucide-react";
import { ContactForm } from "@/components/ContactForm";
import { PageShell } from "@/components/PageShell";

export default function ContactPage() {
  return (
    <PageShell>
      <section className="bg-[#001E4E] px-6 py-20 text-center text-white">
        <h1 className="text-5xl font-extrabold leading-tight">Get In Touch</h1>
        <p className="mt-4 text-lg text-white/80">We DLove To Hear From</p>
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
  return (
    <div className="order-first lg:order-none">
      <h2 className="text-2xl font-bold text-[#111827]">Contact Information</h2>
      <div className="mt-8 grid gap-6">
        <InfoItem
          icon={Mail}
          label="Email"
          value="support@alluwaleducationhub.org"
          href="mailto:support@alluwaleducationhub.org"
        />
        <InfoItem
          icon={Phone}
          label="Phone"
          value="+1 (555) 123-4567"
          href="tel:+15551234567"
        />
        <InfoItem icon={MapPin} label="Location" value="Global Online Platform" />
      </div>

      <div className="mt-12 rounded-[20px] bg-[#EFF6FF] p-6">
        <h3 className="text-lg font-bold text-[#1E40AF]">Faqs</h3>
        <p className="mt-4 leading-6 text-[#1E3A8A]">Check Our Frequently Asked Questions For</p>
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
