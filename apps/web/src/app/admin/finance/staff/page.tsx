"use client";

import { Suspense } from "react";
import { FinanceShell } from "@/components/finance/FinanceShell";
import { StaffPayPage } from "@/components/finance/staff/StaffPayPage";

export default function FinanceStaffPage() {
  return (
    <Suspense fallback={null}>
      <FinanceShell>
        <StaffPayPage />
      </FinanceShell>
    </Suspense>
  );
}
