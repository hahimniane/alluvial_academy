"use client";

import { Suspense } from "react";
import { FinancePlaceholder, FinanceShell } from "@/components/finance/FinanceShell";

export default function FinanceBankPage() {
  return (
    <Suspense fallback={null}>
      <FinanceShell>
        <FinancePlaceholder title="Bank deposits" />
      </FinanceShell>
    </Suspense>
  );
}
