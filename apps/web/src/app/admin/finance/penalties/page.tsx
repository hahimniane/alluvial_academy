"use client";

import { Suspense } from "react";
import { FinanceShell } from "@/components/finance/FinanceShell";
import { PenaltiesPage } from "@/components/finance/penalties/PenaltiesPage";

export default function FinancePenaltiesPage() {
  return (
    <Suspense fallback={null}>
      <FinanceShell>
        <PenaltiesPage />
      </FinanceShell>
    </Suspense>
  );
}
