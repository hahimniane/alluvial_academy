import { AdminDashboardShell } from "@/components/AdminDashboardShell";
import { PublicSiteCmsAdmin } from "@/components/PublicSiteCmsAdmin";

export default function PublicSiteCmsAdminPage() {
  return (
    <AdminDashboardShell activeLabel="Pricing & public team" breadcrumb="Website / Pricing & public team">
      <PublicSiteCmsAdmin />
    </AdminDashboardShell>
  );
}
