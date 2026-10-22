"use client";

import { Suspense } from "react";
import { FinanceShell } from "@/components/finance/FinanceShell";
import { FinanceOverview } from "@/components/finance/overview/OverviewPage";

export default function FinanceOverviewPage() {
  return (
    <Suspense fallback={null}>
      <FinanceShell>
        <FinanceOverview />
      </FinanceShell>
    </Suspense>
  );
}
