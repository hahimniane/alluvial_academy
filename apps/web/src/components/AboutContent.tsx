import Link from "next/link";
import { Eye, Rocket } from "lucide-react";

const aboutCards = [
  {
    title: "Our Mission",
    body: "To integrate Islamic, African, and Western education, offering a holistic curriculum that prepares students to navigate and succeed in a diverse world.",
    color: "#3B82F6",
    icon: Rocket,
  },
  {
    title: "Our Vision",
    body: "To create an inclusive, inspiring environment where students are encouraged to become leaders in their communities.",
    color: "#10B981",
    icon: Eye,
  },
] as const;

export function AboutContent() {
  return (
    <>
      <section className="bg-white px-6 py-14 md:py-16">
        <div className="mx-auto max-w-[1200px] text-center">
          <h1 className="text-[32px] font-extrabold leading-tight text-[#111827] md:text-[42px]">
            About Alluwal Education Hub
          </h1>
          <p className="mx-auto mt-4 max-w-[700px] text-[18px] leading-[1.6] text-[#6B7280]">
            We are fostering a world where diverse knowledge—Islamic, African, and Western—comes together to prepare students for a globalized future.
          </p>

          <div className="mt-12 grid gap-6 lg:grid-cols-2">
            {aboutCards.map(({ title, body, color, icon: Icon }) => (
              <article
                key={title}
                className="rounded-[20px] border border-[#E5E7EB] bg-white p-8 text-left shadow-[0_10px_30px_rgba(15,23,42,0.04)]"
              >
                <span
                  className="inline-flex h-16 w-16 items-center justify-center rounded-2xl"
                  style={{ backgroundColor: `${color}1a`, color }}
                >
                  <Icon size={34} />
                </span>
                <h2 className="mt-7 text-2xl font-extrabold text-[#111827]">{title}</h2>
                <p className="mt-4 text-[16px] leading-[1.7] text-[#6B7280]">{body}</p>
              </article>
            ))}
          </div>

          <Link
            href="/team/"
            className="mt-10 inline-flex min-h-[48px] items-center justify-center rounded-xl bg-[#001E4E] px-10 text-base font-bold text-white shadow-[0_6px_14px_rgba(0,30,78,0.25)]"
          >
            Learn More About Us
          </Link>
        </div>
      </section>

      <section className="bg-gradient-to-br from-[#001E4E] to-[#003399] px-6 py-14 text-white md:py-16">
        <div className="mx-auto grid max-w-[1200px] items-center gap-8 md:grid-cols-[1fr_420px]">
          <div className="text-center md:text-left">
            <h2 className="text-[30px] font-extrabold leading-tight md:text-[42px]">
              Ready to start learning?
            </h2>
            <p className="mt-4 max-w-[640px] text-[17px] leading-8 text-white/90">
              Many families and learners work with us for Islamic studies, languages, tutoring, and more. Explore our programs and get in touch when you are ready to enroll.
            </p>
            <div className="mt-8 flex flex-col gap-4 sm:flex-row sm:justify-center md:justify-start">
              <Link href="/enroll/" className="inline-flex min-h-[48px] items-center justify-center rounded-xl bg-white px-8 text-base font-semibold text-[#001E4E] shadow-[0_6px_14px_rgba(0,30,78,0.18)]">
                Enroll Now
              </Link>
              <Link href="/team/?category=teacher" className="inline-flex min-h-[48px] items-center justify-center rounded-xl border-2 border-white px-8 text-base font-semibold text-white">
                Our Teachers
              </Link>
            </div>
          </div>
          <div className="overflow-hidden rounded-[22px] border-4 border-white/80 shadow-[0_18px_45px_rgba(0,30,78,0.22)]">
            <img
              src="/assets/background_images/smiling_student.jpg"
              alt="Open Quran in a study room"
              className="h-[230px] w-full object-cover md:h-[280px]"
            />
          </div>
        </div>
      </section>
    </>
  );
}
