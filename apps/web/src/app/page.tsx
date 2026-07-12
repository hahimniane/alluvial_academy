import { Suspense } from "react";
import { GuestJoinRedirect } from "@/components/GuestJoinRedirect";
import { MarketingHome } from "@/components/MarketingHome";
import { OpsSubdomainRedirect } from "@/components/OpsSubdomainRedirect";
import { PageShell } from "@/components/PageShell";

export default function HomePage() {
  return (
    <PageShell>
      <Suspense fallback={null}>
        <OpsSubdomainRedirect />
        <GuestJoinRedirect />
      </Suspense>
      <MarketingHome />
    </PageShell>
  );
}
