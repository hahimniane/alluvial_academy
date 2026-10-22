"use client";

import { Suspense } from "react";
import { DiscountsScreen } from "@/components/finance/DiscountsScreen";
import { FinanceShell } from "@/components/finance/FinanceShell";

export default function FinanceDiscountsPage() {
  return (
    <Suspense fallback={null}>
      <FinanceShell>
        <DiscountsScreen />
      </FinanceShell>
    </Suspense>
  );
}
