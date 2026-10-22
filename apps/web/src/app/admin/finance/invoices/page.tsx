"use client";

import { Suspense } from "react";
import { FinanceShell } from "@/components/finance/FinanceShell";
import { InvoicesScreen } from "@/components/finance/invoices/InvoicesScreen";

export default function FinanceInvoicesPage() {
  return (
    <Suspense fallback={null}>
      <FinanceShell>
        <InvoicesScreen />
      </FinanceShell>
    </Suspense>
  );
}
