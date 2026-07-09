import { LoginForm } from "@/components/LoginForm";

export default function LoginPage() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center bg-[#F8FAFC] px-5 py-8">
      <LoginForm />
      <p className="mt-8 text-sm font-medium text-[#9CA3AF] md:hidden">Alluwal Education Hub</p>
    </main>
  );
}
