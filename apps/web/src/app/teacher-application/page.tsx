import { TeacherApplicationForm } from "@/components/ApplicationForms";
import { SiteHeader } from "@/components/SiteHeader";

export default function TeacherApplicationPage() {
  return (
    <>
      <SiteHeader />
      <main>
        <section className="min-h-[calc(100vh-92px)] bg-[#F8FAFC] px-4 py-10">
          <div className="container-shell">
            <TeacherApplicationForm />
          </div>
        </section>
      </main>
    </>
  );
}
