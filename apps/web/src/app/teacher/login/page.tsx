import { LoginForm } from "@/components/LoginForm";

export const metadata = {
  title: "Log in — Alluwal Education Hub",
  robots: { index: false, follow: false },
};

/**
 * Signing in and out for the teacher console stays inside this app.
 *
 * The shared /login/ route still forwards to the Flutter app for roles whose
 * dashboards have not been ported. Teachers must never be handed back to it:
 * they were moved off the Flutter dashboard, and bouncing them there on sign-out
 * would drop them into the app they no longer use. The form routes by role, so
 * anyone else who lands here is still sent to the right place.
 */
export default function Page() {
  return <LoginForm />;
}
