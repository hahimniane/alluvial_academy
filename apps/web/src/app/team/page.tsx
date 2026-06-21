import { Suspense } from "react";
import { PageShell } from "@/components/PageShell";
import { TeamDirectory } from "@/components/TeamDirectory";

export default function TeamPage() {
  return (
    <PageShell>
      <Suspense fallback={<div className="container-shell py-16 text-slate-600">Loading team...</div>}>
        <TeamDirectory />
      </Suspense>
    </PageShell>
  );
}
