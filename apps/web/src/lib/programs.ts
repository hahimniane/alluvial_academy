import { BookOpen, Code2, FunctionSquare, Languages, MoonStar, School } from "lucide-react";
import type { LucideIcon } from "lucide-react";

export type Program = {
  id: string;
  title: string;
  description: string;
  audience: string;
  icon: LucideIcon;
};

export const programs: Program[] = [
  {
    id: "islamic",
    title: "Islamic Studies",
    description: "Quran recitation, memorization support, Islamic foundations, and values-centered learning.",
    audience: "Children, teens, and adults",
    icon: MoonStar,
  },
  {
    id: "languages",
    title: "African & World Languages",
    description: "Language learning that honors identity, family connection, and cultural preservation.",
    audience: "Heritage learners and beginners",
    icon: Languages,
  },
  {
    id: "math",
    title: "Math & Science Tutoring",
    description: "Personalized academic support for homework, concepts, exams, and confidence building.",
    audience: "Elementary through high school",
    icon: FunctionSquare,
  },
  {
    id: "programming",
    title: "Programming",
    description: "Structured coding lessons that help students think clearly and build useful projects.",
    audience: "Curious beginners and builders",
    icon: Code2,
  },
  {
    id: "adult-literacy",
    title: "Adult Literacy",
    description: "Patient reading, writing, and communication support for adult learners.",
    audience: "Adult learners",
    icon: BookOpen,
  },
  {
    id: "after-school",
    title: "After School Support",
    description: "Reliable academic help and guided practice after regular school hours.",
    audience: "Busy families and students",
    icon: School,
  },
];
