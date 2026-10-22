"use client";

import { Suspense } from "react";
import { FinancePlaceholder, FinanceShell } from "@/components/finance/FinanceShell";

export default function FinanceInvoicesPage() {
  return (
    <Suspense fallback={null}>
      <FinanceShell>
        <FinancePlaceholder title="Invoices" />
      </FinanceShell>
    </Suspense>
  );
}
