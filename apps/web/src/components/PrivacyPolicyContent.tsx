import Link from "next/link";
import { PageShell } from "@/components/PageShell";

const effectiveDate = "July 9, 2026";

const dataRows = [
  {
    title: "Account and profile information",
    body: "Names, email addresses, phone numbers, roles, parent or guardian relationships, student details, teacher profiles, and login identifiers used to create and manage accounts.",
  },
  {
    title: "Enrollment, scheduling, and class information",
    body: "Program interests, enrollment answers, class schedules, attendance records, classroom participation, submitted forms, assignments, messages, and progress-related records.",
  },
  {
    title: "Live class permissions and media",
    body: "Camera, microphone, audio device, and screen sharing access may be used when a user joins a live class or meeting. Audio, video, or screen content is processed only to provide live classroom features. Recordings are used only when a class or meeting recording feature is enabled.",
  },
  {
    title: "Notifications and device information",
    body: "Push notification tokens, app version, device type, operating system, crash logs, diagnostic data, timezone, and app settings used to deliver notices, improve reliability, and troubleshoot issues.",
  },
  {
    title: "Location data",
    body: "Location may be requested for staff clock-in and clock-out verification and for location-based prayer time features when enabled by the user. Location is not sold.",
  },
  {
    title: "Files, photos, audio, and messages",
    body: "Uploaded profile photos, form attachments, curriculum files, chat messages, voice notes, or support communications may be stored when a user chooses to provide them.",
  },
  {
    title: "Payment and billing information",
    body: "Billing status, invoice records, payment references, and related transaction metadata may be processed. Card or bank payment details are handled by payment processors such as Stripe and are not stored directly by Alluwal Education Hub.",
  },
];

const uses = [
  "Provide online classes, tutoring, enrollment, scheduling, attendance, messaging, assignments, recordings, and administrative services.",
  "Authenticate users, protect accounts, enforce role-based access, and maintain classroom safety.",
  "Send service messages, class reminders, push notifications, support responses, and account notices.",
  "Process invoices, payments, refunds, and financial records.",
  "Improve app reliability, diagnose crashes, prevent abuse, and maintain security.",
  "Comply with legal, tax, accounting, child-safety, education, and operational obligations.",
];

const sharing = [
  "Firebase and Google Cloud services for authentication, database, storage, notifications, hosting, analytics, and crash reporting.",
  "Video classroom providers such as Zoom, LiveKit, or RealtimeKit when users join live classes or meetings.",
  "Payment processors such as Stripe and other payment methods selected by families for billing and payment handling.",
  "Communication providers used to send email, push notifications, WhatsApp messages, or support responses.",
  "Authorized Alluwal Education Hub administrators, teachers, staff, parents, guardians, and students only as needed for education, operations, support, and safety.",
  "Government, legal, safety, or compliance recipients when required by law or necessary to protect users or the service.",
];

export function PrivacyPolicyContent() {
  return (
    <PageShell>
      <section className="bg-[#F8FAFC] px-6 py-16">
        <div className="mx-auto max-w-4xl">
          <p className="text-sm font-black uppercase tracking-[0.14em] text-[#2563EB]">Alluwal Education Hub</p>
          <h1 className="mt-3 text-4xl font-black leading-tight text-[#0B1B3A] md:text-6xl">Privacy Policy</h1>
          <p className="mt-5 text-lg leading-8 text-slate-600">
            This Privacy Policy explains how Alluwal Education Hub collects, uses, shares, protects, retains, and deletes
            information in connection with the Alluwal mobile app, package name <strong>org.alluvaleducationhub.academy</strong>,
            and related web services.
          </p>
          <p className="mt-4 text-sm font-bold text-slate-500">Effective date: {effectiveDate}</p>
        </div>
      </section>

      <section className="bg-white px-6 py-14">
        <div className="mx-auto grid max-w-4xl gap-10">
          <PolicySection title="Developer and Privacy Contact">
            <p>
              The app is provided by Alluwal Education Hub. For privacy questions, access requests, correction requests,
              deletion requests, or other data inquiries, contact us at{" "}
              <a className="font-bold text-[#2563EB] underline" href="mailto:support@alluwaleducationhub.org">
                support@alluwaleducationhub.org
              </a>
              .
            </p>
          </PolicySection>

          <PolicySection title="Information We Collect">
            <div className="grid gap-5">
              {dataRows.map((row) => (
                <div key={row.title} className="rounded-2xl border border-slate-200 bg-slate-50 p-5">
                  <h3 className="text-base font-black text-[#0B1B3A]">{row.title}</h3>
                  <p className="mt-2 leading-7 text-slate-600">{row.body}</p>
                </div>
              ))}
            </div>
          </PolicySection>

          <PolicySection title="How We Use Information">
            <BulletList items={uses} />
          </PolicySection>

          <PolicySection title="How We Share Information">
            <p>
              We do not sell personal information. We share information only when needed to operate, protect, support,
              or improve the app and education services.
            </p>
            <BulletList items={sharing} />
          </PolicySection>

          <PolicySection title="Children and Students">
            <p>
              Alluwal Education Hub provides education services for families and students, including children. Student
              information is used to deliver classes, support learning, communicate with parents or guardians, and maintain
              safety and records. We do not use student information for third-party behavioral advertising or sell student data.
            </p>
          </PolicySection>

          <PolicySection title="Security">
            <p>
              We use technical and organizational safeguards designed to protect personal information, including encrypted
              network connections, Firebase security controls, role-based access, and restricted administrative access.
              No system can be guaranteed to be completely secure, but we work to protect user data and limit access to
              people and service providers who need it.
            </p>
          </PolicySection>

          <PolicySection title="Retention and Deletion">
            <p>
              We retain information for as long as needed to provide the service, maintain education and billing records,
              resolve disputes, comply with legal obligations, protect users, and operate the app. Some records, such as
              invoices, attendance, compliance, security, or transaction records, may be retained where required or permitted
              by law.
            </p>
            <p>
              Users may request access, correction, or deletion of their account or personal information by emailing{" "}
              <a className="font-bold text-[#2563EB] underline" href="mailto:support@alluwaleducationhub.org">
                support@alluwaleducationhub.org
              </a>
              . We may need to verify the requester before completing a request.
            </p>
          </PolicySection>

          <PolicySection title="Third-Party Services">
            <p>
              The app may use third-party services, including Firebase and Google Cloud, Google Analytics or Crashlytics,
              Stripe, Zoom, LiveKit, RealtimeKit, email providers, notification providers, and hosting providers. These
              providers process information according to their own terms and privacy practices.
            </p>
          </PolicySection>

          <PolicySection title="International Use">
            <p>
              Alluwal Education Hub serves families and staff in multiple locations. Information may be processed in the
              United States or other countries where our service providers operate.
            </p>
          </PolicySection>

          <PolicySection title="Changes to This Policy">
            <p>
              We may update this Privacy Policy when our services, legal obligations, or data practices change. The updated
              policy will be posted at this URL with a new effective date.
            </p>
          </PolicySection>

          <div className="rounded-2xl border border-[#BFDBFE] bg-[#EFF6FF] p-6">
            <h2 className="text-xl font-black text-[#0B1B3A]">Direct Policy URL for App Stores</h2>
            <p className="mt-3 leading-7 text-slate-700">
              This page is the direct privacy policy for the Alluwal app. Use this URL in app store privacy policy fields:
            </p>
            <p className="mt-3 break-all rounded-xl bg-white p-4 font-mono text-sm font-bold text-[#1D4ED8]">
              https://alluwaleducationhub.org/privacy-policy
            </p>
          </div>

          <div className="pt-2">
            <Link href="/" className="inline-flex rounded-full bg-[#0B1B3A] px-6 py-3 font-bold text-white">
              Return to Alluwal Education Hub
            </Link>
          </div>
        </div>
      </section>
    </PageShell>
  );
}

function PolicySection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="grid gap-4">
      <h2 className="text-2xl font-black text-[#0B1B3A]">{title}</h2>
      <div className="grid gap-4 text-base leading-8 text-slate-600">{children}</div>
    </section>
  );
}

function BulletList({ items }: { items: string[] }) {
  return (
    <ul className="grid gap-3 pl-5 text-slate-600">
      {items.map((item) => (
        <li key={item} className="list-disc leading-7">
          {item}
        </li>
      ))}
    </ul>
  );
}
