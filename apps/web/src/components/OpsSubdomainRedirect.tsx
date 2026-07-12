"use client";

import { useEffect } from "react";

const routingControlHosts = new Set([
  "ops.alluwaleducationhub.org",
  "routing.alluwaleducationhub.org",
  "control.alluwaleducationhub.org",
]);

export function OpsSubdomainRedirect() {
  useEffect(() => {
    if (!routingControlHosts.has(window.location.hostname)) return;
    if (window.location.pathname !== "/") return;
    window.location.replace("/admin/routing-control/");
  }, []);

  return null;
}
