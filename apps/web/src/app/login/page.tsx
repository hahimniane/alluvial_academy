import { LoginRedirect } from "@/components/LoginRedirect";

export const metadata = {
  title: "Log in — Alluwal Education Hub",
  robots: { index: false, follow: false },
};

/**
 * Signing in happens in the Flutter app on the main domain during the
 * migration, so this route only forwards there.
 *
 * It is kept rather than deleted because several places still link to /login/:
 * old bookmarks, and the "you are signed out" links inside the unfinished Next
 * admin and teacher pages. Forwarding means every one of them reaches the real
 * login without hunting down each link.
 */
export default function LoginPage() {
  return <LoginRedirect />;
}
