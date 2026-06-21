import { LoginForm } from "@/components/LoginForm";
import { PageHero, PageShell } from "@/components/PageShell";

export default function LoginPage() {
  return (
    <PageShell>
      <PageHero
        kicker="Login"
        title="Staff, parent, and student access."
        body="Access your Alluwal dashboard to manage classes, students, schedules, messages, and account details."
      />
      <section className="bg-[#F5F8FB] py-16">
        <div className="container-shell">
          <LoginForm />
        </div>
      </section>
    </PageShell>
  );
}
