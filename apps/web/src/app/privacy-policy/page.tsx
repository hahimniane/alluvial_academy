import type { Metadata } from "next";
import { PrivacyPolicyContent } from "@/components/PrivacyPolicyContent";

export const metadata: Metadata = {
  title: "Privacy Policy | Alluwal Education Hub",
  description: "Privacy Policy for the Alluwal mobile app and Alluwal Education Hub services.",
  alternates: {
    canonical: "https://alluwaleducationhub.org/privacy-policy",
  },
};

export default function PrivacyPolicyPage() {
  return <PrivacyPolicyContent />;
}
