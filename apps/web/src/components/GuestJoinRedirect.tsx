"use client";

import { useSearchParams } from "next/navigation";
import { useEffect } from "react";

export function GuestJoinRedirect() {
  const searchParams = useSearchParams();
  const guestShift = searchParams.get("guestShift")?.trim();

  useEffect(() => {
    if (!guestShift) return;
    const params = new URLSearchParams({ guestShift });
    const name = searchParams.get("name")?.trim();
    if (name) params.set("name", name);
    window.location.replace(`/classroom/join/?${params.toString()}`);
  }, [guestShift, searchParams]);

  return null;
}
