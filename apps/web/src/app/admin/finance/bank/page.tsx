"use client";

import { Suspense } from "react";
import { BankDeposits } from "@/components/finance/BankDeposits";
import { FinanceShell } from "@/components/finance/FinanceShell";

export default function FinanceBankPage() {
  return (
    <Suspense fallback={null}>
      <FinanceShell>
        <BankDeposits />
      </FinanceShell>
    </Suspense>
  );
}
