"use client";

import { Suspense } from "react";
import { FinanceShell } from "@/components/finance/FinanceShell";
import { FinanceClose } from "@/components/finance/close/ClosePage";

export default function FinanceClosePage() {
  return (
    <Suspense fallback={null}>
      <FinanceShell>
        <FinanceClose />
      </FinanceShell>
    </Suspense>
  );
}
