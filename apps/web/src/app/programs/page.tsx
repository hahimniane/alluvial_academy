import { Suspense } from "react";
import { ProgramsLoadingFallback } from "@/components/EnrollLoadingFallbacks";
import { PageShell } from "@/components/PageShell";
import { ProgramCatalog } from "@/components/ProgramCatalog";

export default function ProgramsPage() {
  return (
    <PageShell>
      <Suspense fallback={<ProgramsLoadingFallback />}>
        <ProgramCatalog />
      </Suspense>
    </PageShell>
  );
}
