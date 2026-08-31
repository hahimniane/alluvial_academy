import { BayanahPlayPage } from "@/components/BayanahPlayPage";

export const metadata = {
  title: "Bayanah Live",
  description: "Join the live Bayanah competition.",
};

/**
 * Deliberately outside the student dashboard shell: on game day this page has
 * to open fast on a room full of phones, so it renders only the game.
 */
export default function Page() {
  return <BayanahPlayPage />;
}
