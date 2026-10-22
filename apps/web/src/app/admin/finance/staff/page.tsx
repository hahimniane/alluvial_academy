"use client";

import { Suspense } from "react";
import { FinancePlaceholder, FinanceShell } from "@/components/finance/FinanceShell";

export default function FinanceStaffPage() {
  return (
    <Suspense fallback={null}>
      <FinanceShell>
        <FinancePlaceholder title="Staff pay" />
      </FinanceShell>
    </Suspense>
  );
}
