import { getAnalytics, isSupported, logEvent, type Analytics } from "firebase/analytics";
import { firebaseApp } from "@/lib/firebase";

let analyticsPromise: Promise<Analytics | null> | null = null;

function analyticsInstance() {
  if (typeof window === "undefined") return Promise.resolve(null);
  analyticsPromise ??= isSupported()
    .then((supported) => (supported ? getAnalytics(firebaseApp) : null))
    .catch(() => null);
  return analyticsPromise;
}

export function trackEvent(name: string, params?: Record<string, unknown>) {
  void analyticsInstance().then((analytics) => {
    if (!analytics) return;
    try {
      logEvent(analytics, name, params);
    } catch {
      // Analytics must never break the page.
    }
  });
}

export function trackPageView(pagePath: string) {
  if (typeof window === "undefined") return;
  trackEvent("page_view", {
    page_path: pagePath,
    page_location: window.location.href,
    page_title: document.title,
    page_referrer: document.referrer || undefined,
  });
}
