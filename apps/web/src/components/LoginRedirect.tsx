"use client";

import { useEffect } from "react";
import { flutterLoginUrl } from "@/lib/flutterApp";

/**
 * Forwards to the Flutter login on the main domain.
 *
 * The site is a static export, so there is no server-side redirect available —
 * this runs on the client. `replace` rather than `assign` so the browser Back
 * button returns to the page the user came from instead of bouncing them
 * through here again.
 *
 * The visible link is the fallback: if JavaScript is blocked or the redirect is
 * slow, the person still has something to click rather than a blank page.
 */
export function LoginRedirect() {
  useEffect(() => {
    window.location.replace(flutterLoginUrl);
  }, []);

  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-4 bg-[#F8FAFC] px-5 py-8 text-center">
      <p className="text-sm font-medium text-[#6B7280]">Taking you to the login page…</p>
      <a
        href={flutterLoginUrl}
        className="rounded-xl bg-[#001E4E] px-5 py-3 text-sm font-semibold text-white"
      >
        Continue to login
      </a>
    </main>
  );
}
