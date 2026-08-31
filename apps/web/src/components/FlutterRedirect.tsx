"use client";

import { useEffect } from "react";

/**
 * Forwards the browser to the Flutter app at /app/.
 *
 * The admin and teacher consoles live in the Flutter app now, so the retired
 * Next.js /admin/ and /teacher/ routes redirect here instead of rendering.
 * Same origin, so a relative path is enough. `replace` (not `assign`) so the
 * Back button doesn't return to this empty page.
 */
export function FlutterRedirect() {
  useEffect(() => {
    window.location.replace("/app/");
  }, []);

  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-4 bg-[#F8FAFC] px-5 py-8 text-center">
      <p className="text-sm font-medium text-[#6B7280]">Taking you to the app…</p>
      <a href="/app/" className="rounded-xl bg-[#001E4E] px-5 py-3 text-sm font-semibold text-white">
        Continue to the app
      </a>
    </main>
  );
}
