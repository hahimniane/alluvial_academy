import { LoginForm } from "@/components/LoginForm";

export const metadata = {
  title: "Log in — Alluwal Education Hub",
  robots: { index: false, follow: false },
};

/**
 * Signing in and out for the student dashboard stays inside this app.
 *
 * The shared /login/ route still forwards to the Flutter app for roles whose
 * dashboards have not been ported, so it is left alone; students get their own
 * route rather than being bounced out of the dashboard they just signed out of.
 * The form itself routes by role, so a teacher or admin who lands here is still
 * sent to the right place.
 */
export default function Page() {
  return <LoginForm />;
}
