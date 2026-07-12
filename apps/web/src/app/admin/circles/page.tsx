import { AdminDashboardShell } from "@/components/AdminDashboardShell";
import { PublicSiteCmsAdmin } from "@/components/PublicSiteCmsAdmin";

export default function CirclesAdminPage() {
  return (
    <AdminDashboardShell activeLabel="Circles" breadcrumb="Website / Pricing & public team">
      <PublicSiteCmsAdmin />
    </AdminDashboardShell>
  );
}
