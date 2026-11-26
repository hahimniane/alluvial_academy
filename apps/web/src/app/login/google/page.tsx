import { GoogleSignIn } from "@/components/GoogleSignIn";

export const metadata = {
  title: "Sign in with Google — Alluwal Education Hub",
  robots: { index: false, follow: false },
};

/**
 * Google sign-in for the Flutter app on the web.
 *
 * /app/ is cross-origin isolated (COOP same-origin) for the Zoom SDK, and that
 * cuts the link to Google's sign-in popup: the app sees the popup as closed
 * the instant it opens. This page lives outside /app/, so the popup works; the
 * session it stores is the one Flutter reads, and the person is sent on to
 * their dashboard signed in.
 */
export default function Page() {
  return <GoogleSignIn />;
}
