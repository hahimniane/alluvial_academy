import { Suspense } from "react";
import { PageShell } from "@/components/PageShell";
import { ProgramCatalog } from "@/components/ProgramCatalog";

export default function ProgramsPage() {
  return (
    <PageShell>
      <Suspense fallback={<div className="container-shell py-16 text-slate-600">Loading programs...</div>}>
        <ProgramCatalog />
      </Suspense>
    </PageShell>
  );
}
