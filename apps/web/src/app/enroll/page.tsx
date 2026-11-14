import { Suspense } from "react";
import { EnrollLoadingFallback } from "@/components/EnrollLoadingFallbacks";
import { ProgramsOverview } from "@/components/ProgramsOverview";
import { SiteHeader } from "@/components/SiteHeader";

export default function EnrollPage() {
  return (
    <>
      <SiteHeader />
      <main>
        <Suspense fallback={<EnrollLoadingFallback />}>
          <ProgramsOverview />
        </Suspense>
      </main>
    </>
  );
}
