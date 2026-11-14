import { Suspense } from "react";
import { PageShell } from "@/components/PageShell";
import { TeamDirectory, TeamDirectoryFallback } from "@/components/TeamDirectory";

export default function TeamPage() {
  return (
    <PageShell>
      <Suspense fallback={<TeamDirectoryFallback />}>
        <TeamDirectory />
      </Suspense>
    </PageShell>
  );
}
