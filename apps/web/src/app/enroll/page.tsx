import { Suspense } from "react";
import { ProgramsOverview } from "@/components/ProgramsOverview";
import { SiteHeader } from "@/components/SiteHeader";

export default function EnrollPage() {
  return (
    <>
      <SiteHeader />
      <main>
        <Suspense fallback={<div className="container-shell py-16 text-slate-600">Loading enrollment...</div>}>
          <ProgramsOverview />
        </Suspense>
      </main>
    </>
  );
}
