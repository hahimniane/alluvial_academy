"use client";

import { useEffect } from "react";

export default function InvoicesPage() {
  useEffect(() => {
    window.location.replace("/admin/finance/invoices/?embed=1");
  }, []);

  return null;
}
