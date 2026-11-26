// The two messages are repeated from signInChecks rather than imported so this
// file stays free of Firebase and can be unit-tested on its own.
const NOT_REGISTERED_MESSAGE =
  "No account found with this email. Please contact an administrator to create your account.";
const ARCHIVED_MESSAGE = "Your account has been archived. Please contact an administrator for assistance.";

const FAILED = "Google sign-in failed. Please try again.";

/** English text for a failed sign-in; null when the person simply closed the Google window. */
export function googleErrorText(error: unknown): string | null {
  const code = String((error as { code?: unknown })?.code ?? "");
  if (code === "user-not-registered") return NOT_REGISTERED_MESSAGE;
  if (code === "user-deactivated") return ARCHIVED_MESSAGE;
  if (code === "auth/popup-closed-by-user" || code === "auth/cancelled-popup-request") return null;
  if (code === "auth/popup-blocked") return "The Google window was blocked. Allow pop-ups for this site and try again.";
  if (code === "auth/account-exists-with-different-credential") {
    return "This Google address is already used with another sign-in method. Sign in with your email and password instead.";
  }
  if (code === "auth/network-request-failed") return "Network connection failed. Please check your internet connection and try again.";
  return FAILED;
}
