import Link from "next/link";
import { ArrowLeft } from "lucide-react";

export default function DashboardBridgePage() {
  return (
    <main className="min-h-screen bg-[#F5F8FB] px-4 py-12">
      <div className="mx-auto max-w-xl rounded-lg border border-slate-200 bg-white p-6 shadow-sm">
        <img src="/assets/Alluwal_Education_Hub_Logo.png" alt="" className="h-16 w-16 rounded-lg object-contain" />
        <h1 className="mt-6 text-3xl font-black text-[#001E4E]">Alluwal dashboard</h1>
        <p className="mt-4 leading-7 text-slate-600">
          Open your dashboard to manage learning, schedules, messages, student progress, and account settings.
        </p>
        <div className="mt-6">
          <Link href="/" className="alluwal-button alluwal-button-light">
            <ArrowLeft size={18} />
            Home
          </Link>
        </div>
      </div>
    </main>
  );
}
