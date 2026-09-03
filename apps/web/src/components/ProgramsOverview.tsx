"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import {
  Badge,
  BookOpen,
  Cake,
  CalendarDays,
  Check,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  AlertCircle,
  CloudSun,
  Clock,
  Code2,
  FunctionSquare,
  GraduationCap,
  Globe2,
  Languages,
  Link2,
  Mail,
  Mars,
  MinusCircle,
  MoonStar,
  Phone,
  PlusCircle,
  School,
  Send,
  Sun,
  UserRound,
  Users,
  UsersRound,
  Venus,
} from "lucide-react";
import { trackEvent } from "@/lib/analytics";
import {
  completeEnrollmentDraft,
  draftHasSignal,
  saveEnrollmentDraft,
  type EnrollmentDraftPayload,
} from "@/lib/enrollmentDrafts";
import { checkParentIdentity, submitEnrollment } from "@/lib/forms";
import {
  CLASS_TYPES,
  SESSION_MINUTES,
  TIME_BLOCKS,
  blockById,
  blockRangeLabel,
  hoursMatchSessions,
  normalizeBlock,
  normalizeClassType,
  sessionFitsBlock,
  sessionLabel,
  weeklyHoursFor,
} from "@/lib/enrollmentDomain";
import { MAX_HOURS_PER_WEEK, MIN_HOURS_PER_WEEK, clampHoursPerWeek } from "@/lib/enrollmentHours";
import {
  fallbackPricing,
  loadPublicMarketingBundle,
  type PublicSitePlanPricing,
  type PublicSitePricingDoc,
} from "@/lib/publicSiteCms";

type Status = "idle" | "saving" | "success" | "error";
type LinkedParent = {
  userId?: string;
  firstName?: string;
  lastName?: string;
  email?: string;
  phone?: string;
};
type StudentDraft = {
  name: string;
  age: string;
  gender: string;
  subjectId: string;
  specificLanguage: string;
  level: string;
  classType: string;
  hoursPerWeek: number;
  /** Explicit question now — it used to be derived from hoursPerWeek. */
  sessionMinutes: number;
  sessionsPerWeek: number;
  timeOfDayPreference: string;
  preferredDays: string[];
  useCustomSchedule: boolean;
};
type PricingPlans = Record<string, PublicSitePlanPricing>;

const subjectOptions = [
  {
    id: "islamic",
    subject: "Religious Studies (Quran, Arabic, etc...)",
    label: "Religious Studies",
    shortLabel: "Religious Studies",
    body: "Arabic, Quran, Tawhid, Hadith, Tafsir",
    icon: MoonStar,
    trackId: "islamic",
    color: "#3B82F6",
  },
  {
    id: "group",
    subject: "Group Classes (weekend / small group)",
    label: "Group Classes",
    shortLabel: "Group Classes",
    body: "Weekend / small group",
    icon: UsersRound,
    trackId: "group",
    color: "#7C3AED",
  },
  {
    id: "languages",
    subject: "AfroLanguages (Pular, Mandingo, Swahili, Wolof, etc...)",
    label: "AfroLanguages",
    shortLabel: "AfroLanguages",
    body: "Pular, Mandingo, Swahili, Wolof",
    icon: Languages,
    trackId: "tutoring",
    color: "#F59E0B",
  },
  {
    id: "english",
    subject: "English",
    label: "English",
    shortLabel: "English",
    body: "Reading, writing, grammar, vocabulary",
    icon: Languages,
    trackId: "tutoring",
    color: "#3B82F6",
  },
  {
    id: "french",
    subject: "French",
    label: "French",
    shortLabel: "French",
    body: "Conversation, grammar, writing",
    icon: Languages,
    trackId: "tutoring",
    color: "#6366F1",
  },
  {
    id: "adlam",
    subject: "Adlam",
    label: "Adlam",
    shortLabel: "Adlam",
    body: "Reading and writing Fulani with Adlam",
    icon: Languages,
    trackId: "adlam",
    color: "#8B5CF6",
  },
  {
    id: "entrepreneurship",
    subject: "Entrepreneurship",
    label: "Entrepreneurship",
    shortLabel: "Entrepreneurship",
    body: "Business foundations",
    icon: Badge,
    trackId: "tutoring",
    color: "#0EA5E9",
  },
  {
    id: "coding",
    subject: "Coding",
    label: "Coding",
    shortLabel: "Coding",
    body: "Web, mobile, and software",
    icon: Code2,
    trackId: "tutoring",
    color: "#111827",
  },
  {
    id: "after-school",
    subject: "After School Tutoring (Math, Science, Physics, etc...)",
    label: "After School Tutoring",
    shortLabel: "Tutoring",
    body: "Math, science, physics, and more",
    icon: FunctionSquare,
    trackId: "tutoring",
    color: "#10B981",
  },
  {
    id: "adult-literacy",
    subject: "Adult Literacy (Reading and Writing English & French, etc...)",
    label: "Adult Literacy",
    shortLabel: "Adult Literacy",
    body: "Reading and writing English & French",
    icon: BookOpen,
    trackId: "tutoring",
    color: "#F59E0B",
  },
] as const;

const steps = [
  { title: "Who's enrolling", icon: Badge },
  { title: "Student details", icon: UserRound },
  { title: "Program & pricing", icon: BookOpen },
  { title: "Schedule", icon: CalendarDays },
  { title: "Contact & review", icon: Mail },
] as const;

const roles = [
  { value: "Student", title: "Student", subtitle: "I'm signing up for myself.", icon: GraduationCap },
  { value: "Parent", title: "Parent", subtitle: "I'm enrolling one or more children.", icon: UsersRound },
  { value: "Guardian", title: "Guardian", subtitle: "I'm responsible for a learner's enrollment.", icon: UserRound },
] as const;
const trackOptions = [
  { id: "islamic", title: "Religious Studies", icon: MoonStar },
  { id: "adlam", title: "Adlam", icon: Languages },
  { id: "tutoring", title: "Tutoring & Literacy", icon: School },
  { id: "group", title: "Group Classes", icon: UsersRound },
] as const;
const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
const languages = ["English", "French", "Arabic", "Other"];
const CLASS_TYPE_ICONS: Record<string, typeof UserRound> = {
  "One-on-One": UserRound,
  "Exclusive Family Class": Users,
  "With Other Students": UsersRound,
};
const classTypes = CLASS_TYPES.map((type) => ({
  value: type.value,
  label: type.label,
  hint: type.hint,
  icon: CLASS_TYPE_ICONS[type.value] ?? UserRound,
}));
const africanLanguages = ["Pular", "Mandingo", "Swahili", "Wolof", "Hausa", "Yoruba", "Adlam", "Amharic", "Other"];

const initialContact = {
  email: "",
  phoneNumber: "",
  countryCode: "US",
  countryName: "United States",
  city: "",
  whatsAppNumber: "",
  parentName: "",
  preferredLanguage: "English",
  schedulingNotes: "",
};

export function ProgramsOverview() {
  const searchParams = useSearchParams();
  const initialCategory = searchParams.get("category") ?? "";
  const initialTrack = searchParams.get("track") ?? "";
  const initialSubjectName = searchParams.get("subject") ?? "";
  const requestedHours = Number(searchParams.get("hours") ?? 1);
  const initialSubject = resolveInitialSubject(initialCategory, initialSubjectName, initialTrack);
  const initialHours = Number.isFinite(requestedHours) ? clampHoursPerWeek(requestedHours) : MIN_HOURS_PER_WEEK;
  const initialStudentCount = searchParams.get("students") === "multiple" ? 2 : 1;

  const [step, setStep] = useState(0);
  const [role, setRole] = useState("");
  const [students, setStudents] = useState<StudentDraft[]>(
    Array.from({ length: initialStudentCount }, () => makeStudentDraft(initialSubject?.id ?? "", initialHours)),
  );
  const [activeStudentIndex, setActiveStudentIndex] = useState(0);
  const [applyProgramToAll, setApplyProgramToAll] = useState(true);
  const [preferredLanguage, setPreferredLanguage] = useState("");
  const [contact, setContact] = useState({ ...initialContact });
  const [parentIdentifier, setParentIdentifier] = useState("");
  const [linkedParent, setLinkedParent] = useState<LinkedParent | null>(null);
  const [checkingParent, setCheckingParent] = useState(false);
  const [parentLookupMessage, setParentLookupMessage] = useState("");
  const [showDetailedSlots, setShowDetailedSlots] = useState(true);
  const [customStart, setCustomStart] = useState("17:00");
  const [customEnd, setCustomEnd] = useState("18:00");
  const [status, setStatus] = useState<Status>("idle");
  const [error, setError] = useState("");
  const [pricing, setPricing] = useState<PublicSitePricingDoc>(fallbackPricing);

  useEffect(() => {
    let active = true;
    loadPublicMarketingBundle().then((bundle) => {
      if (active) setPricing(bundle.pricing);
    });
    return () => {
      active = false;
    };
  }, []);

  useEffect(() => {
    if (status === "success") {
      document.body.dataset.enrollmentSuccess = "true";
    } else {
      delete document.body.dataset.enrollmentSuccess;
    }
    return () => {
      delete document.body.dataset.enrollmentSuccess;
    };
  }, [status]);

  useEffect(() => {
    trackEvent("enrollment_form_viewed", {
      initial_track: initialTrack || undefined,
      initial_subject: initialSubject?.id ?? undefined,
    });
  }, []);

  useEffect(() => {
    if (status === "success") return;
    const payload: EnrollmentDraftPayload = {
      step,
      stepTitle: steps[step]?.title ?? "",
      role,
      preferredLanguage,
      timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC",
      students: students.map((student) => {
        const subject = subjectFor(student.subjectId);
        return {
          name: student.name,
          age: student.age,
          gender: student.gender,
          subject: subject?.label ?? "",
          level: student.level,
          classType: student.classType,
          hoursPerWeek: student.hoursPerWeek,
          preferredDays: student.preferredDays,
        };
      }),
      contact: {
        email: contact.email,
        phoneNumber: contact.phoneNumber,
        whatsAppNumber: contact.whatsAppNumber,
        parentName: contact.parentName,
        city: contact.city,
        countryName: contact.countryName,
      },
    };
    if (!draftHasSignal(payload)) return;
    const timer = setTimeout(() => {
      void saveEnrollmentDraft(payload);
    }, 1500);
    return () => clearTimeout(timer);
  }, [step, role, students, contact, preferredLanguage, status]);

  const isParentGuardian = role === "Parent" || role === "Guardian";
  const primaryStudent = students[0];
  const activeStudent = students[activeStudentIndex] ?? primaryStudent;
  const primarySubject = subjectFor(primaryStudent.subjectId);
  const summaryLines = students.map((student, index) => {
    const subject = subjectFor(student.subjectId);
    return {
      title: student.name.trim() || `Student ${index + 1}`,
      // Program and hours only — the monthly figure is settled with the family.
      detail: subject
        ? `${subject.shortLabel} · ${student.hoursPerWeek} hrs/wk`
        : `— · ${student.hoursPerWeek} hrs/wk`,
    };
  });
  const totalHours = students.reduce((sum, student) => sum + student.hoursPerWeek, 0);
  const programStudents = applyProgramToAll || students.length === 1 ? [primaryStudent] : students;
  const stepOneIncomplete = step === 1 && students.some((student) => !student.name.trim() || !student.age.trim());
  const stepTwoIncomplete = step === 2 && (
    !preferredLanguage ||
    programStudents.some((student) => {
      const subject = subjectFor(student.subjectId);
      if (!subject) return true;
      if (subject.id === "languages" && !student.specificLanguage) return true;
      return !student.level || !student.classType;
    })
  );
  const stepThreeIncomplete =
    step === 3 &&
    students.some(
      (student) =>
        student.preferredDays.length === 0 ||
        !blockById(student.timeOfDayPreference) ||
        !sessionFitsBlock(blockById(student.timeOfDayPreference), student.sessionMinutes),
    );
  const submitDisabled = status === "saving" || (step === 0 && !role) || stepOneIncomplete || stepTwoIncomplete || stepThreeIncomplete;

  const updateContact = (name: string, value: string) => {
    setContact((current) => ({ ...current, [name]: value }));
  };

  const updateStudent = (index: number, patch: Partial<StudentDraft>) => {
    setStudents((current) => current.map((student, studentIndex) => {
      if (studentIndex !== index) return student;
      return { ...student, ...patch };
    }));
  };

  const updatePrimaryProgram = (patch: Partial<StudentDraft>) => {
    setStudents((current) => {
      const next = current.map((student, index) => {
        if (index === 0 || applyProgramToAll) {
          return { ...student, ...patch };
        }
        return student;
      });
      return next;
    });
  };

  const setProgramForStudent = (index: number, subjectId: string) => {
    const subject = subjectFor(subjectId);
    const patch = {
      subjectId,
      specificLanguage: "",
      level: "",
      classType: "",
    };
    if (index === 0 && applyProgramToAll) {
      updatePrimaryProgram(patch);
    } else {
      updateStudent(index, patch);
    }
    if (subject?.id === "group") {
      updateStudent(index, { classType: "Group" });
    }
  };

  const addStudent = () => {
    setStudents((current) => {
      const base = applyProgramToAll ? current[0] : makeStudentDraft(primaryStudent.subjectId, primaryStudent.hoursPerWeek);
      const next = [
        ...current,
        {
          ...base,
          name: "",
          age: "",
          gender: "",
          preferredDays: [...base.preferredDays],
          useCustomSchedule: false,
        },
      ];
      setActiveStudentIndex((currentIndex) => Math.min(currentIndex, next.length - 1));
      return next;
    });
  };

  const removeLastStudent = () => {
    setStudents((current) => {
      if (current.length <= 1) return current;
      const next = current.slice(0, -1);
      setActiveStudentIndex(Math.min(activeStudentIndex, next.length - 1));
      return next;
    });
  };

  const toggleDay = (studentIndex: number, day: string) => {
    const student = students[studentIndex];
    const nextDays = student.preferredDays.includes(day)
      ? student.preferredDays.filter((item) => item !== day)
      : [...student.preferredDays, day];
    if (studentIndex === 0 && !students.some((item, index) => index > 0 && item.useCustomSchedule)) {
      setStudents((current) => current.map((item) => ({ ...item, preferredDays: nextDays })));
    } else {
      updateStudent(studentIndex, { preferredDays: nextDays });
    }
  };


  const updateHours = (studentIndex: number, hours: number) => {
    const bounded = clampHoursPerWeek(hours);
    const patch = { hoursPerWeek: bounded };
    if (studentIndex === 0 && applyProgramToAll) {
      updatePrimaryProgram(patch);
    } else {
      updateStudent(studentIndex, patch);
    }
  };

  async function onParentLookup() {
    const identifier = parentIdentifier.trim();
    if (!identifier) {
      setParentLookupMessage("Please enter an email or kiosque code to link account.");
      return;
    }
    setCheckingParent(true);
    setParentLookupMessage("");
    try {
      const result = await checkParentIdentity(identifier);
      if (result.found) {
        const parent = result as LinkedParent & { found: boolean };
        setLinkedParent(parent);
        const fullName = [parent.firstName, parent.lastName].filter(Boolean).join(" ").trim();
        setContact((current) => ({
          ...current,
          parentName: fullName || current.parentName,
          email: parent.email || current.email,
          phoneNumber: parent.phone || current.phoneNumber,
        }));
        setParentLookupMessage("Account linked successfully.");
      } else {
        setParentLookupMessage("No parent account found with that email or kiosque code.");
      }
    } catch {
      setParentLookupMessage("Could not verify account right now. Please try again.");
    } finally {
      setCheckingParent(false);
    }
  }

  function validateStep(form: HTMLFormElement) {
    setError("");
    if (!form.reportValidity()) return false;
    if (step === 0 && !role) return fail("Please select who you are (Student, Parent, or Guardian).");
    if (step === 1) {
      const missingIndex = students.findIndex((student) => !student.name.trim());
      if (missingIndex >= 0) return fail(`Please enter name for Student ${missingIndex + 1}.`);
    }
    if (step === 2) {
      for (let index = 0; index < students.length; index += 1) {
        const student = students[index];
        const subject = subjectFor(student.subjectId);
        if (!subject) return fail(`Please select a program for Student ${index + 1}.`);
        if (subject.id === "languages" && !student.specificLanguage) {
          return fail(`Please select a specific language for Student ${index + 1}.`);
        }
        if (!student.level) return fail(`Please select a level for Student ${index + 1}.`);
        if (!student.classType) return fail(`Please select a class type for Student ${index + 1}.`);
      }
    }
    if (step === 3) {
      for (let index = 0; index < students.length; index += 1) {
        const student = students[index];
        if (student.preferredDays.length === 0) return fail(`Student ${index + 1}: please select at least one preferred day.`);
        const block = blockById(student.timeOfDayPreference);
        if (!block) return fail(`Student ${index + 1}: please choose a part of the day.`);
        if (!sessionFitsBlock(block, student.sessionMinutes)) {
          return fail(
            `Student ${index + 1}: a ${sessionLabel(student.sessionMinutes)} session doesn't fit inside ${block.label.toLowerCase()}.`,
          );
        }
      }
    }
    if (step === 4) {
      if (isParentGuardian && !linkedParent && !contact.parentName.trim()) {
        return fail("Please enter the parent or guardian name.");
      }
    }
    return true;
  }

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    if (!validateStep(form)) return;
    if (step < 4) {
      trackEvent("enrollment_step_completed", { step, step_title: steps[step]?.title });
      if (step === 0) setActiveStudentIndex(0);
      setStep((current) => current + 1);
      window.scrollTo({ top: 0, behavior: "smooth" });
      return;
    }

    setStatus("saving");
    try {
      await submitEnrollment({
        role,
        guardianId: linkedParent?.userId,
        parentName: contact.parentName,
        email: contact.email,
        phoneNumber: contact.phoneNumber,
        countryCode: contact.countryCode,
        countryName: contact.countryName,
        city: contact.city,
        whatsAppNumber: contact.whatsAppNumber,
        preferredLanguage,
        timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC",
        schedulingNotes: contact.schedulingNotes,
        pricingPlanId: primarySubject ? legacyPlanForTrack(primarySubject.trackId) : undefined,
        pricingPlanLabel: primarySubject ? pricingLabelForTrack(primarySubject.trackId) : undefined,
        trackId: primarySubject?.trackId ?? "tutoring",
        hoursPerWeek: primaryStudent.hoursPerWeek,
        pricingPlans: pricing.plans,
        students: students.map((student) => {
          const subject = subjectFor(student.subjectId);
          return {
            name: student.name,
            age: student.age,
            gender: student.gender,
            subject: subject?.subject ?? "",
            specificLanguage: subject?.id === "languages" ? student.specificLanguage : undefined,
            level: student.level,
            classType: student.classType,
            sessionDuration: sessionLabel(student.sessionMinutes),
            sessionMinutes: student.sessionMinutes,
            sessionsPerWeek: student.sessionsPerWeek,
            hoursPerWeek: student.hoursPerWeek,
            timeOfDayPreference: student.timeOfDayPreference,
            preferredDays: student.preferredDays,
            trackId: subject?.trackId ?? "tutoring",
          };
        }),
      });
      trackEvent("enrollment_submitted", {
        students: students.length,
        track: primarySubject?.trackId ?? "tutoring",
        role,
      });
      void completeEnrollmentDraft();
      setStatus("success");
    } catch {
      trackEvent("enrollment_submit_failed", { step });
      setStatus("error");
    }
  }

  function fail(message: string) {
    setError(message);
    return false;
  }

  if (status === "success") {
    return (
      <section className="flex min-h-screen items-center justify-center bg-white px-8 py-12 text-center">
        <div className="flex max-w-[760px] flex-col items-center">
          <div className="rounded-full bg-[#10B981]/10 p-6">
            <CheckCircle2 size={80} className="text-[#10B981]" strokeWidth={2.4} />
          </div>
          <h1 className="mt-8 text-[32px] font-extrabold leading-tight text-[#111827]">Request Received</h1>
          <p className="mt-4 text-lg leading-[1.6] text-[#6B7280]">Thank You For Your Interest In</p>
          <Link href="/" className="alluwal-button alluwal-button-primary mt-12 min-h-[52px] px-8 text-base font-semibold">
            Back To Home
          </Link>
        </div>
      </section>
    );
  }

  return (
    <section className="bg-[#F8FAFC] px-2 py-2 md:px-3">
      <div className="mx-auto flex min-h-[calc(100vh-104px)] max-w-[640px] flex-col">
        <StepBar currentStep={step} />
        <form onSubmit={onSubmit} className="mt-1 flex min-h-0 flex-1 flex-col overflow-hidden rounded-xl bg-white shadow-sm">
          <div className="min-h-0 flex-1 overflow-y-auto px-3 py-3 md:px-4">
            {step === 0 ? (
              <StepCard title="Who's enrolling" subtitle="Student, parent, or guardian — and how many children if applicable.">
                <div className="grid gap-1.5">
                  {roles.map(({ value, title, subtitle, icon: Icon }) => (
                    <button
                      key={value}
                      type="button"
                      className={`flex w-full items-center gap-3 rounded-xl border px-3.5 py-3 text-left transition ${
                        role === value ? "border-[#4F46E5] bg-[#EEF2FF]" : "border-[#E2E8F0] bg-[#F8FAFC]"
                      }`}
                      onClick={() => setRole(value)}
                    >
                      <Icon size={22} className={role === value ? "text-[#4338CA]" : "text-slate-500"} />
                      <span className="min-w-0 flex-1">
                        <span className="block text-sm font-bold text-slate-900">{title}</span>
                        <span className="mt-0.5 block text-[11px] leading-4 text-slate-500">{subtitle}</span>
                      </span>
                      {role === value ? <CheckCircle2 size={20} className="text-[#4F46E5]" /> : null}
                    </button>
                  ))}
                </div>

                {isParentGuardian ? (
                  <div className="mt-2 rounded-xl border border-[#BFDBFE] bg-[#F0F9FF] px-3.5 py-3">
                    <div className="flex items-center gap-3">
                      <div className="min-w-0 flex-1">
                        <p className="text-[13px] font-bold text-slate-900">Children</p>
                        <p className="text-[11px] leading-4 text-slate-500">You can add multiple students in this enrollment.</p>
                      </div>
                      <button
                        type="button"
                        aria-label="Remove student"
                        className="inline-flex h-9 w-9 items-center justify-center rounded-full text-slate-500 disabled:text-slate-300"
                        onClick={removeLastStudent}
                        disabled={students.length <= 1}
                      >
                        <MinusCircle size={22} />
                      </button>
                      <span className="w-7 text-center text-xl font-black text-slate-900">{students.length}</span>
                      <button
                        type="button"
                        aria-label="Add student"
                        className="inline-flex h-9 w-9 items-center justify-center rounded-full text-slate-600"
                        onClick={addStudent}
                      >
                        <PlusCircle size={22} />
                      </button>
                    </div>
                  </div>
                ) : null}

                {isParentGuardian ? (
                  <ParentLookup
                    identifier={parentIdentifier}
                    onIdentifierChange={setParentIdentifier}
                    onLookup={onParentLookup}
                    checking={checkingParent}
                    linkedParent={linkedParent}
                    message={parentLookupMessage}
                    onUnlink={() => {
                      setLinkedParent(null);
                      setParentIdentifier("");
                      setParentLookupMessage("");
                    }}
                  />
                ) : null}
              </StepCard>
            ) : null}

            {step === 1 ? (
              <StepCard
                title={isParentGuardian ? "Student's Information" : "Your Information"}
                subtitle="Names, ages, and genders for each learner."
              >
                {students.length > 1 ? (
                  <StudentTabs
                    students={students}
                    activeIndex={activeStudentIndex}
                    onSelect={setActiveStudentIndex}
                  />
                ) : null}
                <StudentProfileFields
                  student={activeStudent}
                  index={activeStudentIndex}
                  isSelfEnrollment={!isParentGuardian}
                  onChange={(patch) => updateStudent(activeStudentIndex, patch)}
                />
                <div className="mt-4 rounded-xl border border-[#BAE6FD] bg-[#F0F9FF] px-3.5 py-3">
                  <p className="text-[12px] font-bold text-slate-900">Stay in touch while you apply (optional)</p>
                  <p className="mt-0.5 text-[11px] leading-4 text-slate-500">
                    Leave an email or WhatsApp number and our team can help you finish enrolling if you get interrupted.
                  </p>
                  <div className="mt-2.5 grid gap-3 sm:grid-cols-2">
                    <IconField
                      label="Email"
                      name="earlyEmail"
                      value={contact.email}
                      placeholder="your@email.com"
                      icon={<Mail size={17} />}
                      onChange={(value) => updateContact("email", value)}
                      type="email"
                    />
                    <IconField
                      label="WhatsApp / phone"
                      name="earlyWhatsApp"
                      value={contact.whatsAppNumber}
                      placeholder="+1 555 000 0000"
                      icon={<Phone size={17} />}
                      onChange={(value) => updateContact("whatsAppNumber", value)}
                    />
                  </div>
                </div>
              </StepCard>
            ) : null}

            {step === 2 ? (
              <StepCard title="Program Details" subtitle={students.length > 1 && !applyProgramToAll ? "Each student can have a separate program and hours." : "Choose a program track, class preferences, and weekly hours."}>
                {isParentGuardian && students.length > 1 ? (
                  <label className="mb-3 flex items-center justify-between gap-3 rounded-xl border border-slate-200 bg-slate-50 px-3 py-2.5 text-sm font-bold text-slate-800">
                    Customize per student
                    <input
                      type="checkbox"
                      checked={!applyProgramToAll}
                      onChange={(event) => setApplyProgramToAll(!event.target.checked)}
                      className="h-5 w-5 accent-[#4F46E5]"
                    />
                  </label>
                ) : null}
                {applyProgramToAll || students.length === 1 ? (
                  <ProgramEditor
                    student={primaryStudent}
                    studentIndex={0}
                    title={students.length > 1 ? "All children" : ""}
                    onProgramChange={(subjectId) => setProgramForStudent(0, subjectId)}
                    onStudentChange={(patch) => updatePrimaryProgram(patch)}
                    onHoursChange={(hours) => updateHours(0, hours)}
                    preferredLanguage={preferredLanguage}
                    onPreferredLanguageChange={setPreferredLanguage}
                    pricingPlans={pricing.plans}
                  />
                ) : (
                  <div className="grid gap-3">
                    <StudentTabs students={students} activeIndex={activeStudentIndex} onSelect={setActiveStudentIndex} />
                    <ProgramEditor
                      student={activeStudent}
                      studentIndex={activeStudentIndex}
                      title={activeStudent.name || `Student ${activeStudentIndex + 1}`}
                      onProgramChange={(subjectId) => setProgramForStudent(activeStudentIndex, subjectId)}
                      onStudentChange={(patch) => updateStudent(activeStudentIndex, patch)}
                      onHoursChange={(hours) => updateHours(activeStudentIndex, hours)}
                      preferredLanguage={preferredLanguage}
                      onPreferredLanguageChange={setPreferredLanguage}
                      pricingPlans={pricing.plans}
                    />
                  </div>
                )}
              </StepCard>
            ) : null}

            {step === 3 ? (
              <StepCard title="Schedule Preferences" subtitle="Choose the days and the part of the day that suit you. We confirm exact times with you afterwards.">
                {students.length > 1 ? (
                  <StudentTabs students={students} activeIndex={activeStudentIndex} onSelect={setActiveStudentIndex} />
                ) : null}
                <ScheduleEditor
                  student={activeStudent}
                  studentIndex={activeStudentIndex}
                  onStudentChange={(patch) => updateStudent(activeStudentIndex, patch)}
                  onDayToggle={(day) => toggleDay(activeStudentIndex, day)}
                />
              </StepCard>
            ) : null}

            {step === 4 ? (
              <StepCard title="Contact & review" subtitle="Review your selections, enter contact details, then submit." centerHeader>
                <ReviewPanel
                  students={students}
                  onEditStep={setStep}
                />
                <ContactPanel
                  isParentGuardian={isParentGuardian}
                  linkedParent={linkedParent}
                  contact={contact}
                  onChange={updateContact}
                />
              </StepCard>
            ) : null}

            {error ? <p className="mt-3 rounded-xl bg-red-50 p-3 text-sm font-bold text-red-700">{error}</p> : null}
            {status === "error" ? <p className="mt-3 rounded-xl bg-red-50 p-3 text-sm font-bold text-red-700">We could not submit the enrollment request. Please try again.</p> : null}
            {step <= 3 ? (
              <div className="mt-2">
                {step >= 1 ? (
                  <EnrollmentInlineSummary
                    students={students.length}
                    totalHours={totalHours}
                  />
                ) : null}
                {step >= 2 ? <EnrollmentSelectionSummary lines={summaryLines} /> : null}
                <EnrollmentActions
                  step={step}
                  status={status}
                  disabled={submitDisabled}
                  onPrevious={() => setStep((current) => current - 1)}
                />
              </div>
            ) : null}
            {step === 4 ? (
              <div className="mt-3">
                <EnrollmentActions
                  step={step}
                  status={status}
                  disabled={submitDisabled}
                  onPrevious={() => setStep((current) => current - 1)}
                />
              </div>
            ) : null}
          </div>
        </form>
      </div>
    </section>
  );
}

function StepBar({ currentStep }: { currentStep: number }) {
  return (
    <div className="overflow-x-auto bg-gradient-to-r from-[#0F172A] to-[#1E293B] px-2 py-1.5">
      <div className="flex min-w-max items-center justify-center">
        {steps.map(({ title, icon: Icon }, index) => {
          const complete = index < currentStep;
          const current = index === currentStep;
          return (
            <div key={title} className="flex items-center">
              {index > 0 ? <span className={`mx-1 h-0.5 w-6 rounded ${index <= currentStep ? "bg-emerald-500" : "bg-slate-700"}`} /> : null}
              <div className="flex min-w-[68px] flex-col items-center px-1">
                <span className={`inline-flex h-6 w-6 items-center justify-center rounded-full text-[10px] font-bold ${
                  complete ? "bg-emerald-500 text-white" : current ? "bg-amber-500 text-white shadow" : "bg-slate-700 text-slate-400"
                }`}>
                  {complete ? <Check size={13} /> : current ? <Icon size={13} /> : index + 1}
                </span>
                <span className={`mt-0.5 whitespace-nowrap text-[8.5px] ${current ? "font-bold text-white" : "text-slate-400"}`}>{title}</span>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function EnrollmentActions({
  step,
  status,
  disabled,
  onPrevious,
}: {
  step: number;
  status: Status;
  disabled: boolean;
  onPrevious: () => void;
}) {
  const isFirstStep = step === 0;
  const compactActions = step <= 4;
  const isFinalStep = step >= 4;
  const previousLabel = step <= 4 ? "Back" : "Previous";
  const actionLabel = status === "saving" ? "Submitting..." : isFinalStep ? "Submit Request" : "Continue";

  return (
    <div className={`flex items-center gap-3 ${compactActions ? "justify-start" : "justify-between"}`}>
      {isFirstStep ? null : (
        <button type="button" className="alluwal-button alluwal-button-light min-h-[42px]" onClick={onPrevious}>
          <ChevronLeft size={18} />
          {previousLabel}
        </button>
      )}
      <button
        type="submit"
        className={`alluwal-button min-h-[42px] min-w-[160px] ${isFirstStep ? "w-full md:w-auto" : ""} ${
          disabled
            ? "cursor-not-allowed bg-[#CBD5E1] text-[#94A3B8] shadow-none hover:translate-y-0"
            : "alluwal-button-primary"
        }`}
        disabled={disabled}
      >
        {actionLabel}
        {isFinalStep ? <Send size={18} /> : <ChevronRight size={18} />}
      </button>
    </div>
  );
}

function EnrollmentInlineSummary({ students, totalHours }: { students: number; totalHours: number }) {
  return (
    <div className="mb-2 border-t border-slate-200 pt-2">
      <div className="flex items-center justify-between text-[11px] text-slate-500">
        <span>{students} student{students > 1 ? "s" : ""} · {totalHours} hrs/wk</span>
        <span className="h-0.5 w-3 rounded bg-emerald-500" aria-hidden="true" />
      </div>
    </div>
  );
}

function EnrollmentSelectionSummary({ lines }: { lines: { title: string; detail: string }[] }) {
  return (
    <div className="mb-2 rounded-t-md border-t border-slate-200 bg-[#F8FAFC] px-3 py-2">
      <p className="text-[11px] font-bold text-[#4F46E5]">Your selections</p>
      <div className="mt-2 grid gap-1">
        {lines.map((line) => (
          <div key={line.title} className="text-[11px] leading-4">
            <p className="font-bold text-slate-900">{line.title}</p>
            <p className="text-slate-500">{line.detail}</p>
          </div>
        ))}
      </div>
    </div>
  );
}

function StepCard({
  title,
  subtitle,
  children,
  centerHeader = false,
}: {
  title: string;
  subtitle: string;
  children: React.ReactNode;
  centerHeader?: boolean;
}) {
  return (
    <div className={centerHeader ? "text-center" : undefined}>
      <h1 className="text-[14px] font-black leading-tight text-slate-900">{title}</h1>
      <p className="mt-0.5 text-[11px] leading-4 text-slate-500">{subtitle}</p>
      <span className={`mt-1.5 block h-0.5 w-7 rounded bg-[#2563EB] ${centerHeader ? "mx-auto" : ""}`} />
      <div className={`mt-1.5 ${centerHeader ? "text-left" : ""}`}>{children}</div>
    </div>
  );
}

function IconField({
  label,
  name,
  value,
  placeholder,
  icon,
  onChange,
  required,
  type = "text",
  min,
  max,
}: {
  label: string;
  name: string;
  value: string;
  placeholder: string;
  icon: React.ReactNode;
  onChange: (value: string) => void;
  required?: boolean;
  type?: string;
  min?: number;
  max?: number;
}) {
  return (
    <label className="grid gap-1.5">
      <span className="text-[12px] font-bold text-slate-700">{label}</span>
      <span className="flex min-h-[39px] items-center gap-3 rounded-xl border border-[#CBD5E1] bg-white px-3 text-slate-500 shadow-[0_1px_3px_rgba(15,23,42,0.03)] focus-within:border-[#3B82F6] focus-within:ring-2 focus-within:ring-blue-100">
        <span className="inline-flex h-5 w-5 shrink-0 items-center justify-center text-[#64748B]">{icon}</span>
        <input
          name={name}
          value={value}
          onChange={(event) => onChange(event.target.value)}
          required={required}
          type={type}
          min={min}
          max={max}
          placeholder={placeholder}
          className="min-h-[37px] flex-1 border-0 bg-transparent p-0 text-[13px] font-medium text-slate-900 outline-none placeholder:text-[#94A3B8]"
        />
      </span>
    </label>
  );
}

function GenderSegment({ name, value, onChange }: { name: string; value: string; onChange: (value: string) => void }) {
  const options = [
    { value: "Male", icon: Mars },
    { value: "Female", icon: Venus },
  ] as const;

  return (
    <div className="grid gap-1.5">
      <p className="text-[12px] font-bold text-slate-700">Gender</p>
      <input type="hidden" name={name} value={value} />
      <div className="inline-flex w-fit overflow-hidden rounded-xl border border-[#E2E8F0] bg-[#FAFBFC] shadow-[0_1px_4px_rgba(15,23,42,0.02)]">
        {options.map(({ value: optionValue, icon: Icon }, index) => {
          const selected = value === optionValue;
          return (
            <button
              key={optionValue}
              type="button"
              aria-pressed={selected}
              className={`inline-flex min-h-[32px] items-center gap-2 px-4 text-[12px] font-semibold transition ${
                selected ? "bg-[#3B82F6] text-white" : "bg-white text-slate-500 hover:bg-slate-50"
              } ${index > 0 ? "border-l border-[#E2E8F0]" : ""}`}
              onClick={() => onChange(selected ? "" : optionValue)}
            >
              <Icon size={14} />
              {optionValue}
            </button>
          );
        })}
      </div>
    </div>
  );
}

function ProgramClassTypeSegment({
  name,
  value,
  onChange,
}: {
  name: string;
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <div className="grid justify-center gap-1.5">
      <p className="text-center text-[12px] font-bold text-slate-700">Class Type</p>
      <input type="hidden" name={name} value={value} />
      <div className="inline-flex overflow-hidden rounded-xl border border-[#E2E8F0] bg-[#FAFBFC] shadow-[0_1px_4px_rgba(15,23,42,0.02)]">
        {classTypes.map(({ value: optionValue, label, icon: Icon }, index) => {
          const selected = value === optionValue;
          return (
            <button
              key={optionValue}
              type="button"
              aria-pressed={selected}
              className={`inline-flex min-h-[32px] min-w-[84px] items-center justify-center gap-2 px-3 text-[12px] font-semibold transition ${
                selected ? "bg-[#3B82F6] text-white" : "bg-white text-slate-500 hover:bg-slate-50"
              } ${index > 0 ? "border-l border-[#E2E8F0]" : ""}`}
              onClick={() => onChange(selected ? "" : optionValue)}
            >
              {Icon ? <Icon size={14} /> : null}
              {label}
            </button>
          );
        })}
      </div>
    </div>
  );
}

function ParentLookup({
  identifier,
  onIdentifierChange,
  onLookup,
  checking,
  linkedParent,
  message,
  onUnlink,
}: {
  identifier: string;
  onIdentifierChange: (value: string) => void;
  onLookup: () => void;
  checking: boolean;
  linkedParent: LinkedParent | null;
  message: string;
  onUnlink: () => void;
}) {
  return (
    <div className={`mt-3 rounded-2xl border p-4 ${linkedParent ? "border-emerald-200 bg-emerald-50" : "border-blue-100 bg-blue-50"}`}>
      <div className="flex items-start gap-3">
        <span className={`inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-xl ${linkedParent ? "bg-emerald-100 text-emerald-700" : "bg-blue-100 text-blue-700"}`}>
          {linkedParent ? <CheckCircle2 size={20} /> : <Link2 size={20} />}
        </span>
        <div className="min-w-0 flex-1">
          <p className={`text-sm font-bold ${linkedParent ? "text-emerald-800" : "text-blue-900"}`}>{linkedParent ? "Account linked" : "Already have a child enrolled?"}</p>
          <p className="mt-0.5 text-[11px] leading-4 text-slate-500">Link your account to manage all students together.</p>
        </div>
      </div>
      {linkedParent ? (
        <div className="mt-3 flex items-center justify-between rounded-xl bg-white p-3 text-sm">
          <span className="font-bold text-slate-900">{[linkedParent.firstName, linkedParent.lastName].filter(Boolean).join(" ") || linkedParent.email || "Linked parent"}</span>
          <button type="button" className="text-xs font-bold text-slate-500" onClick={onUnlink}>Unlink</button>
        </div>
      ) : (
        <div className="mt-3 flex gap-2">
          <input
            value={identifier}
            onChange={(event) => onIdentifierChange(event.target.value)}
            className="field-input min-h-[42px] flex-1"
            placeholder="Email or kiosque code"
            aria-label="Parent email or kiosque code"
          />
          <button type="button" className="alluwal-button alluwal-button-primary min-h-[42px]" onClick={onLookup} disabled={checking}>
            {checking ? "Checking..." : "Link"}
          </button>
        </div>
      )}
      {message ? <p className="mt-2 text-xs font-semibold text-slate-600">{message}</p> : null}
    </div>
  );
}

function StudentTabs({ students, activeIndex, onSelect }: { students: StudentDraft[]; activeIndex: number; onSelect: (index: number) => void }) {
  return (
    <div className="mb-3 flex gap-2 overflow-x-auto pb-1">
      {students.map((student, index) => (
        <button
          key={index}
          type="button"
          className={`inline-flex shrink-0 items-center rounded-full border px-3 py-2 text-xs font-black ${
            activeIndex === index ? "border-[#4F46E5] bg-[#EEF2FF] text-[#4338CA]" : "border-slate-200 bg-white text-slate-600"
          }`}
          onClick={() => onSelect(index)}
        >
          {student.name || `Student ${index + 1}`}
        </button>
      ))}
    </div>
  );
}

function StudentProfileFields({
  student,
  index,
  isSelfEnrollment,
  onChange,
}: {
  student: StudentDraft;
  index: number;
  isSelfEnrollment: boolean;
  onChange: (patch: Partial<StudentDraft>) => void;
}) {
  const nameLabel = isSelfEnrollment && index === 0 ? "Full Name" : `Student ${index + 1} name`;
  const namePlaceholder = isSelfEnrollment && index === 0 ? "Enter your full name" : `Student ${index + 1} full name`;

  return (
    <div className="grid gap-4">
      <IconField
        label={nameLabel}
        name={index === 0 ? "name" : `student${index + 1}Name`}
        value={student.name}
        placeholder={namePlaceholder}
        icon={<UserRound size={17} />}
        onChange={(value) => onChange({ name: value })}
        required
      />
      <div className="grid items-start gap-3 sm:grid-cols-[1fr_1fr]">
        <IconField
          label="Age"
          name={index === 0 ? "age" : `student${index + 1}Age`}
          value={student.age}
          placeholder="Years"
          icon={<Cake size={17} />}
          onChange={(value) => onChange({ age: value })}
          required
          type="number"
          min={1}
          max={99}
        />
        <GenderSegment
          name={index === 0 ? "gender" : `student${index + 1}Gender`}
          value={student.gender}
          onChange={(value) => onChange({ gender: value })}
        />
      </div>
    </div>
  );
}

function ProgramEditor({
  student,
  studentIndex,
  title,
  onProgramChange,
  onStudentChange,
  onHoursChange,
  preferredLanguage,
  onPreferredLanguageChange,
  pricingPlans,
}: {
  student: StudentDraft;
  studentIndex: number;
  title: string;
  onProgramChange: (subjectId: string) => void;
  onStudentChange: (patch: Partial<StudentDraft>) => void;
  onHoursChange: (hours: number) => void;
  preferredLanguage: string;
  onPreferredLanguageChange: (value: string) => void;
  pricingPlans: PricingPlans;
}) {
  const subject = subjectFor(student.subjectId);
  const levels = levelsForSubject(subject?.id ?? "");
  const selectedTrackId = subject?.trackId ?? "";
  return (
    <div className="grid gap-4">
      {title ? <p className="text-sm font-black text-slate-900">{title}</p> : null}
      <EnrollmentSubCard title="1. Choose a Program">
        <p className="mb-2 text-[11px] font-semibold text-slate-700">Select a learning track</p>
        <TrackSelector
          selectedTrackId={selectedTrackId}
          onTrackSelected={(trackId) => onProgramChange(defaultSubjectIdForTrack(trackId))}
        />
      </EnrollmentSubCard>

      <EnrollmentSubCard title="2. Class Preferences">
        <div className="grid gap-3">
          {subject?.id === "languages" ? (
            <SelectField
              label="Specific Language"
              name={studentIndex === 0 ? "specificLanguage" : `student${studentIndex + 1}SpecificLanguage`}
              value={student.specificLanguage}
              onChange={(_, value) => onStudentChange({ specificLanguage: value })}
              options={africanLanguages.map((value) => ({ value, label: value }))}
              required
            />
          ) : null}
          {subject ? (
            <SelectField
              label={subject.id === "after-school" ? "Grade Level" : "Proficiency Level"}
              name={studentIndex === 0 ? "level" : `student${studentIndex + 1}Level`}
              value={student.level}
              onChange={(_, value) => onStudentChange({ level: value })}
              options={levels.map((value) => ({ value, label: value }))}
              required
            />
          ) : null}
          <ProgramClassTypeSegment
            name={studentIndex === 0 ? "classType" : `student${studentIndex + 1}ClassType`}
            value={student.classType}
            onChange={(value) => onStudentChange({ classType: value })}
          />
          <SelectField
            label="Preferred Language"
            name="preferredLanguage"
            value={preferredLanguage}
            onChange={(_, value) => onPreferredLanguageChange(value)}
            options={languages.map((value) => ({ value, label: value }))}
            required
          />
        </div>
      </EnrollmentSubCard>

      <EnrollmentSubCard title="3. Pricing & Hours">
        <SessionShapeFields student={student} onStudentChange={onStudentChange} />
        <HoursStepper
          hours={student.hoursPerWeek}
          trackId={subject?.trackId ?? ""}
          onHoursChange={onHoursChange}
          pricingPlans={pricingPlans}
        />
      </EnrollmentSubCard>
    </div>
  );
}

/**
 * How long each class is, and how many a week. These used to be inferred from
 * weekly hours, which is what produced a single four-hour "slot" for a family
 * asking for 4 hrs/week. Asking directly is what makes the slot maths work.
 *
 * The two numbers are reconciled, never silently corrected: families reason
 * about price in hours per week, so we say what does not add up and offer the
 * fix rather than moving their number for them.
 */
function SessionShapeFields({
  student,
  onStudentChange,
}: {
  student: StudentDraft;
  onStudentChange: (patch: Partial<StudentDraft>) => void;
}) {
  const computed = weeklyHoursFor(student.sessionsPerWeek, student.sessionMinutes);
  const agrees = hoursMatchSessions(student.hoursPerWeek, student.sessionsPerWeek, student.sessionMinutes);

  return (
    <div className="grid gap-2.5 pb-3">
      <div>
        <p className="mb-1.5 text-[13px] font-bold text-slate-800">How long is each class?</p>
        <div className="flex flex-wrap gap-1.5">
          {SESSION_MINUTES.map((minutes) => {
            const selected = student.sessionMinutes === minutes;
            return (
              <button
                key={minutes}
                type="button"
                aria-pressed={selected}
                onClick={() => onStudentChange({ sessionMinutes: minutes })}
                className={`min-h-[32px] rounded-lg px-2.5 py-1.5 text-[12px] font-semibold transition ${
                  selected
                    ? "bg-gradient-to-r from-[#3B82F6] to-[#2563EB] text-white"
                    : "bg-[#F1F5F9] text-[#64748B] hover:bg-slate-200"
                }`}
              >
                {sessionLabel(minutes)}
              </button>
            );
          })}
        </div>
      </div>

      <div>
        <p className="mb-1.5 text-[13px] font-bold text-slate-800">How many classes a week?</p>
        <div className="inline-flex items-center gap-3 rounded-lg border-[1.5px] border-[#E2E8F0] bg-[#FAFBFC] px-2.5 py-2">
          <button
            type="button"
            aria-label="Fewer classes per week"
            onClick={() => onStudentChange({ sessionsPerWeek: Math.max(1, student.sessionsPerWeek - 1) })}
            className="text-[#3B82F6] disabled:text-[#CBD5E1]"
            disabled={student.sessionsPerWeek <= 1}
          >
            <MinusCircle size={19} />
          </button>
          <span className="min-w-[1.5rem] text-center text-[13px] font-bold text-slate-800">
            {student.sessionsPerWeek}
          </span>
          <button
            type="button"
            aria-label="More classes per week"
            onClick={() => onStudentChange({ sessionsPerWeek: Math.min(14, student.sessionsPerWeek + 1) })}
            className="text-[#3B82F6] disabled:text-[#CBD5E1]"
            disabled={student.sessionsPerWeek >= 14}
          >
            <PlusCircle size={19} />
          </button>
        </div>
      </div>

      {!agrees ? (
        <div className="flex items-start gap-2 rounded-lg border-[1.5px] border-[#FDE68A] bg-[#FFFBEB] px-2.5 py-2">
          <AlertCircle size={15} className="mt-px shrink-0 text-[#B45309]" />
          <div className="min-w-0">
            <p className="text-[11px] font-semibold text-[#92400E]">These two don&apos;t add up</p>
            <p className="mt-0.5 text-[10px] font-medium leading-[1.3] text-[#92400E]">
              {student.sessionsPerWeek} session{student.sessionsPerWeek === 1 ? "" : "s"} of{" "}
              {sessionLabel(student.sessionMinutes)} is {computed} hrs a week, but you&apos;ve asked for{" "}
              {student.hoursPerWeek} hrs.
            </p>
            <button
              type="button"
              onClick={() => onStudentChange({ hoursPerWeek: computed })}
              className="mt-1.5 rounded-lg border-[1.5px] border-[#FDE68A] bg-white px-2.5 py-1 text-[10px] font-semibold text-[#92400E]"
            >
              Set hours to {computed}
            </button>
          </div>
        </div>
      ) : null}
    </div>
  );
}

function HoursStepper({
  hours,
  trackId,
  onHoursChange,
  pricingPlans,
}: {
  hours: number;
  trackId: string;
  onHoursChange: (hours: number) => void;
  pricingPlans: PricingPlans;
}) {
  return (
    <div className="rounded-xl border border-slate-200 bg-[#FAFBFC] p-3">
      <div className="flex items-center justify-between gap-3">
        <span className="text-[11px] font-bold text-slate-700">Select hours per week</span>
        <span className="inline-flex items-center rounded-lg border border-slate-200 bg-white">
          <button type="button" aria-label="Decrease hours" className="inline-flex h-8 w-8 items-center justify-center text-[#3B82F6] disabled:text-slate-300" disabled={hours <= MIN_HOURS_PER_WEEK} onClick={() => onHoursChange(hours - 1)}>
            <MinusCircle size={18} />
          </button>
          <span className="w-8 text-center text-sm font-black text-slate-900">{hours}</span>
          <button type="button" aria-label="Increase hours" className="inline-flex h-8 w-8 items-center justify-center text-[#3B82F6] disabled:text-slate-300" disabled={hours >= MAX_HOURS_PER_WEEK} onClick={() => onHoursChange(hours + 1)}>
            <PlusCircle size={18} />
          </button>
        </span>
      </div>
      {trackId ? (
        // No monthly total here. Rates are negotiated with the family, and a
        // hard number at this step reads as a bill and puts people off before
        // anyone has spoken to them.
        <p className="mt-2 rounded-md border border-slate-200 bg-white px-2 py-1.5 text-[10px] font-semibold text-slate-600">
          We&rsquo;ll confirm pricing with you after this — schedules and rates are flexible.
        </p>
      ) : null}
    </div>
  );
}

function EnrollmentSubCard({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-[0_2px_4px_rgba(15,23,42,0.02)]">
      <div className="border-b border-slate-200 bg-[#F8FAFC] px-4 py-3">
        <h2 className="text-sm font-bold text-slate-800">{title}</h2>
      </div>
      <div className="p-4">{children}</div>
    </section>
  );
}

function TrackSelector({
  selectedTrackId,
  onTrackSelected,
}: {
  selectedTrackId: string;
  onTrackSelected: (trackId: string) => void;
}) {
  return (
    <div className="flex flex-wrap gap-1.5">
      {trackOptions.map(({ id, title, icon: Icon }) => {
        const selected = selectedTrackId === id;
        const accessibleLabel = id === "islamic" ? "Religious Studies" : title;
        return (
          <button
            key={id}
            type="button"
            aria-label={accessibleLabel}
            className={`inline-flex items-center gap-1.5 rounded-full border px-3 py-2 text-xs font-bold transition ${
              selected
                ? "border-[#4F46E5] bg-gradient-to-r from-[#4F46E5] to-[#6366F1] text-white"
                : "border-slate-200 bg-[#F1F5F9] text-slate-700"
            }`}
            onClick={() => onTrackSelected(id)}
          >
            <Icon size={14} />
            {title}
          </button>
        );
      })}
    </div>
  );
}

function ScheduleEditor({
  student,
  studentIndex,
  onStudentChange,
  onDayToggle,
}: {
  student: StudentDraft;
  studentIndex: number;
  onStudentChange: (patch: Partial<StudentDraft>) => void;
  onDayToggle: (day: string) => void;
}) {
  const timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC";

  return (
    <div className="grid gap-4">
      {studentIndex > 0 ? (
        <label className="flex items-center justify-between rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-sm font-bold text-slate-800">
          Custom schedule for this student
          <input
            type="checkbox"
            checked={student.useCustomSchedule}
            onChange={(event) => onStudentChange({ useCustomSchedule: event.target.checked })}
            className="h-5 w-5 accent-[#4F46E5]"
          />
        </label>
      ) : null}
      <div className="flex items-start gap-2 text-[13px] leading-5 text-slate-800">
        <Globe2 size={16} className="mt-0.5 shrink-0 text-[#3B82F6]" />
        <p>
          All times are in your local timezone: <span className="font-bold">{timeZone}</span>
        </p>
      </div>
      <p className="text-[12px] font-medium leading-5 text-slate-500">
        Exact class times are confirmed with you after we review your request.
      </p>
      <ChipGroup title="Which days work best?" items={days} selected={student.preferredDays} onToggle={onDayToggle} />
      <TimeOfDayCards
        value={student.timeOfDayPreference}
        onChange={(value) => onStudentChange({ timeOfDayPreference: value })}
      />
      <ScheduleConfirmationLine student={student} />
    </div>
  );
}

/**
 * Replaces the slot grid parents used to pick from. They give a window; we say
 * back exactly what we will book inside it, or that the session cannot fit.
 */
function ScheduleConfirmationLine({ student }: { student: StudentDraft }) {
  const block = blockById(student.timeOfDayPreference);
  const sessionMinutes = student.sessionMinutes;
  const dayList = student.preferredDays.join(", ");

  if (!block || student.preferredDays.length === 0) return null;

  const fits = sessionFitsBlock(block, sessionMinutes);
  if (!fits) {
    return (
      <div className="flex items-start gap-2 rounded-lg border-[1.5px] border-[#FDE68A] bg-[#FFFBEB] px-2.5 py-2">
        <AlertCircle size={15} className="mt-px shrink-0 text-[#B45309]" />
        <p className="text-[10px] font-medium leading-[1.3] text-[#92400E]">
          A {sessionLabel(sessionMinutes)} session doesn&apos;t fit inside {block.label.toLowerCase()} (
          {blockRangeLabel(block)}). Choose a shorter session or another part of the day.
        </p>
      </div>
    );
  }

  return (
    <div className="flex items-start gap-2 rounded-lg border-[1.5px] border-[#E2E8F0] bg-[#FAFBFC] px-2.5 py-2">
      <Clock size={15} className="mt-px shrink-0 text-[#64748B]" />
      <p className="text-[10px] font-medium leading-[1.3] text-[#64748B]">
        We&apos;ll book {student.sessionsPerWeek} × {sessionLabel(sessionMinutes)} somewhere between{" "}
        {blockRangeLabel(block)} on {dayList}, and confirm the exact times with you.
      </p>
    </div>
  );
}

function ReviewPanel({
  students,
  onEditStep,
}: {
  students: StudentDraft[];
  onEditStep: (step: number) => void;
}) {
  const enrollmentRows: [string, string][] = [];
  students.forEach((student, index) => {
    const subject = subjectFor(student.subjectId);
    enrollmentRows.push([
      `Student ${index + 1}`,
      `${student.name || `Student ${index + 1}`}${student.age ? `, ${student.age}` : ""}`,
    ]);
    if (students.length === 1) {
      if (subject) enrollmentRows.push(["Program", subject.shortLabel]);
      if (student.level) enrollmentRows.push(["Level", student.level]);
      if (student.classType) enrollmentRows.push(["Format", classTypeReviewLabel(student.classType)]);
      if (student.hoursPerWeek > 0) enrollmentRows.push(["Hours/week", `${student.hoursPerWeek}h`]);
    } else {
      enrollmentRows.push([
        `${student.name || `Student ${index + 1}`} program`,
        `${subject?.shortLabel ?? "Program?"} · ${student.level || "—"} · ${classTypeReviewLabel(student.classType) || "—"} · ${student.hoursPerWeek}h`,
      ]);
    }
  });

  const scheduleRows: [string, string][] = [];
  students.forEach((student, index) => {
    const name = students.length === 1 ? "" : `${student.name || `Student ${index + 1}`} — `;
    if (student.preferredDays.length > 0) scheduleRows.push([`${name}Days`, student.preferredDays.join(", ")]);
    const reviewBlock = blockById(student.timeOfDayPreference);
    if (reviewBlock) {
      scheduleRows.push([`${name}Window`, `${reviewBlock.label} (${blockRangeLabel(reviewBlock)})`]);
    }
    scheduleRows.push([
      `${name}Sessions`,
      `${student.sessionsPerWeek} × ${sessionLabel(student.sessionMinutes)} · ${student.hoursPerWeek} hrs/wk`,
    ]);
  });

  return (
    <div className="grid gap-1.5">
      <ReviewSection title="Enrollment Details" icon="📋" action={() => onEditStep(1)} rows={enrollmentRows} />
      {scheduleRows.length > 0 ? (
        <ReviewSection title="Schedule" icon="📅" action={() => onEditStep(3)} rows={scheduleRows} />
      ) : null}
    </div>
  );
}

function ReviewSection({ title, icon, rows, action }: { title: string; icon: string; rows: [string, string][]; action: () => void }) {
  return (
    <section className="rounded-[10px] border border-[#334155] bg-gradient-to-br from-[#1E293B] to-[#0F172A] p-[11px]">
      <div className="flex items-center justify-between">
        <div className="flex min-w-0 items-center gap-1.5">
          <span className="text-sm" aria-hidden="true">{icon}</span>
          <h2 className="truncate text-[10px] font-black uppercase tracking-[0.08em] text-[#94A3B8]">{title}</h2>
        </div>
        <button type="button" className="rounded-lg bg-[#334155] px-2 py-1 text-[10px] font-semibold text-[#F59E0B]" onClick={action}>Edit</button>
      </div>
      <div className="mt-2 grid gap-1">
        {rows.map(([label, value]) => (
          <div key={`${title}-${label}`} className="grid grid-cols-[2fr_3fr] gap-2 text-[11px] leading-4">
            <span className="text-[#94A3B8]">{label}</span>
            <span className="text-right font-semibold text-white">{value}</span>
          </div>
        ))}
      </div>
    </section>
  );
}

function ContactPanel({
  isParentGuardian,
  linkedParent,
  contact,
  onChange,
}: {
  isParentGuardian: boolean;
  linkedParent: LinkedParent | null;
  contact: typeof initialContact;
  onChange: (name: string, value: string) => void;
}) {
  return (
    <div className="mt-4 rounded-2xl border border-[#334155] bg-gradient-to-br from-[#0F172A] to-[#1E293B] p-[18px] shadow-[0_8px_22px_rgba(0,0,0,0.12)]">
      <h2 className="text-lg font-bold text-white">Your contact info</h2>
      <p className="mt-1.5 text-xs font-medium leading-5 text-[#94A3B8]">
        We use this to confirm enrollment and reach you about scheduling.
      </p>

      <div className="mt-4 grid gap-4">
        {isParentGuardian ? (
          <div className="grid gap-3 sm:grid-cols-2">
            <DarkField
              label="Parent / guardian name"
              name="parentName"
              value={contact.parentName}
              onChange={onChange}
              required={!linkedParent}
              placeholder="As on ID or school records"
              disabled={Boolean(linkedParent)}
            />
            <DarkField label="Email" name="email" value={contact.email} onChange={onChange} required type="email" placeholder="your@email.com" disabled={Boolean(linkedParent)} />
          </div>
        ) : (
          <DarkField label="Email" name="email" value={contact.email} onChange={onChange} required type="email" placeholder="your@email.com" />
        )}

        <div className="grid gap-3 sm:grid-cols-2">
          <DarkField label="Whatsapp Number" name="whatsAppNumber" value={contact.whatsAppNumber} onChange={onChange} placeholder="Whatsapp Number" />
          <DarkField label="Phone Number" name="phoneNumber" value={contact.phoneNumber} onChange={onChange} required placeholder="Phone Number" />
        </div>

        <div className="grid gap-3 sm:grid-cols-[90px_2fr_1fr]">
          <DarkField label="Code" name="countryCode" value={contact.countryCode} onChange={onChange} required placeholder="US" />
          <DarkField label="Select Country" name="countryName" value={contact.countryName} onChange={onChange} required placeholder="Select Country" />
          <DarkField label="City" name="city" value={contact.city} onChange={onChange} required placeholder="City" />
        </div>

        <DarkTextarea
          label="Scheduling notes (optional)"
          value={contact.schedulingNotes}
          onChange={(value) => onChange("schedulingNotes", value)}
          placeholder="e.g. prefer after 4pm weekdays, avoid Fridays..."
        />
      </div>
    </div>
  );
}

function DarkField({
  label,
  name,
  value,
  onChange,
  required,
  type = "text",
  placeholder,
  disabled,
}: {
  label: string;
  name: string;
  value: string;
  onChange: (name: string, value: string) => void;
  required?: boolean;
  type?: string;
  placeholder?: string;
  disabled?: boolean;
}) {
  return (
    <label className="grid gap-1.5">
      <span className="text-[12px] font-bold text-[#CBD5E1]">
        {label}{required ? <span className="ml-1 text-red-300">*</span> : null}
      </span>
      <input
        name={name}
        value={value}
        onChange={(event) => onChange(name, event.target.value)}
        required={required}
        type={type}
        placeholder={placeholder}
        disabled={disabled}
        className="min-h-[46px] rounded-xl border border-[#CBD5E1] bg-white px-3 text-[13px] font-medium text-slate-900 outline-none placeholder:text-[#94A3B8] focus:border-[#3B82F6] focus:ring-2 focus:ring-blue-100 disabled:bg-slate-100 disabled:text-slate-500"
      />
    </label>
  );
}

function DarkTextarea({
  label,
  value,
  onChange,
  placeholder,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  placeholder: string;
}) {
  return (
    <label className="grid gap-1.5">
      <span className="text-[12px] font-bold text-[#CBD5E1]">{label}</span>
      <textarea
        value={value}
        onChange={(event) => onChange(event.target.value)}
        placeholder={placeholder}
        className="min-h-24 resize-y rounded-xl border border-[#CBD5E1] bg-white px-3 py-3 text-[13px] font-medium text-slate-900 outline-none placeholder:text-[#94A3B8] focus:border-[#3B82F6] focus:ring-2 focus:ring-blue-100"
      />
    </label>
  );
}

function ChipGroup({
  title,
  items,
  selected,
  onToggle,
  tone = "blue",
}: {
  title?: string;
  items: string[];
  selected: string[];
  onToggle: (value: string) => void;
  tone?: "blue" | "green";
}) {
  return (
    <div>
      {title ? <p className="mb-2 text-[13px] font-bold text-slate-800">{title}</p> : null}
      <div className="flex flex-wrap gap-1.5">
        {items.map((item) => (
          <button
            key={item}
            type="button"
            className={`rounded-lg px-3 py-2 text-xs font-semibold transition ${
              selected.includes(item)
                ? tone === "green"
                  ? "bg-gradient-to-r from-[#10B981] to-[#059669] text-white"
                  : "bg-gradient-to-r from-[#3B82F6] to-[#2563EB] text-white"
                : "bg-[#F1F5F9] text-slate-500 hover:bg-slate-200"
            }`}
            onClick={() => onToggle(item)}
          >
            {item}
          </button>
        ))}
      </div>
    </div>
  );
}

const BLOCK_ICONS: Record<string, typeof Sun> = {
  Morning: Sun,
  Afternoon: CloudSun,
  Evening: MoonStar,
  Night: MoonStar,
  "Late night": Clock,
};

function TimeOfDayCards({ value, onChange }: { value: string; onChange: (value: string) => void }) {
  return (
    <div>
      <p className="mb-1.5 text-[13px] font-bold text-slate-800">Preferred Time of Day</p>
      <div className="flex flex-wrap gap-1.5">
        {TIME_BLOCKS.map((block) => {
          const Icon = BLOCK_ICONS[block.id] ?? Clock;
          const selected = value === block.id;
          return (
            <button
              key={block.id}
              type="button"
              className="inline-flex min-h-[32px] flex-col items-start gap-0.5 rounded-lg border px-2.5 py-1.5 text-left shadow-[0_1px_2px_rgba(15,23,42,0.02)] transition"
              style={{
                borderColor: selected ? block.color : "#E2E8F0",
                borderWidth: selected ? 2 : 1.5,
                color: selected ? block.color : "#475569",
                background: selected ? `${block.color}18` : "#FAFBFC",
              }}
              onClick={() => onChange(selected ? "" : block.id)}
            >
              <span className="inline-flex items-center gap-1.5 text-[11px] font-semibold">
                <Icon size={15} />
                {block.label}
              </span>
              <span className="text-[9px] font-medium text-[#94A3B8]">{blockRangeLabel(block)}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
}

function Field({
  label,
  name,
  value,
  onChange,
  required,
  type = "text",
}: {
  label: string;
  name: string;
  value: string;
  onChange: (name: string, value: string) => void;
  required?: boolean;
  type?: string;
}) {
  return (
    <label className="field-label">
      <span>{label}{required ? <span className="ml-1 text-red-600">*</span> : null}</span>
      <input name={name} value={value} onChange={(event) => onChange(name, event.target.value)} required={required} type={type} className="field-input" />
    </label>
  );
}

function SelectField({
  label,
  name,
  value,
  onChange,
  options,
  required,
}: {
  label: string;
  name: string;
  value: string;
  onChange: (name: string, value: string) => void;
  options: { value: string; label: string }[];
  required?: boolean;
}) {
  return (
    <label className="field-label mt-3">
      <span>{label}{required ? <span className="ml-1 text-red-600">*</span> : null}</span>
      <select name={name} value={value} onChange={(event) => onChange(name, event.target.value)} required={required} className="field-input">
        <option value="">Select an option</option>
        {options.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}
      </select>
    </label>
  );
}

function makeStudentDraft(subjectId: string, hours: number): StudentDraft {
  return {
    name: "",
    age: "",
    gender: "",
    subjectId,
    specificLanguage: "",
    level: "",
    classType: "",
    hoursPerWeek: hours,
    // Session length is its own question now. Default to one hour and let
    // sessions-per-week follow the hours the family already chose, so the two
    // start out agreeing instead of tripping the reconcile warning on arrival.
    sessionMinutes: 60,
    sessionsPerWeek: Math.max(1, Math.round(hours)),
    timeOfDayPreference: "",
    preferredDays: [],
    useCustomSchedule: false,
  };
}

function resolveInitialSubject(category: string, subjectName: string, track: string) {
  const bySubject = subjectOptions.find((item) => item.subject === subjectName || item.id === normalizeSubjectId(subjectName));
  if (bySubject) return bySubject;
  const byCategory = subjectOptions.find((item) => item.id === normalizeSubjectId(category));
  if (byCategory) return byCategory;
  const byTrack = subjectOptions.find((item) => item.trackId === track);
  return byTrack ?? null;
}

function subjectFor(subjectId: string) {
  return subjectOptions.find((item) => item.id === subjectId) ?? null;
}

function defaultSubjectIdForTrack(trackId: string) {
  if (trackId === "group") return "group";
  if (trackId === "tutoring") return "after-school";
  return "islamic";
}

function levelsForSubject(subjectId: string) {
  if (subjectId === "after-school") return ["Elementary School", "Middle School", "High School", "University"];
  return ["Beginner", "Intermediate", "Advanced"];
}

function classTypeReviewLabel(value: string) {
  if (value === "One-on-One") return "1-on-1";
  return value;
}





function formatClockInput(value: string) {
  const [hourRaw, minuteRaw] = value.split(":");
  const hour = Number(hourRaw);
  const minute = Number(minuteRaw);
  const period = hour >= 12 ? "PM" : "AM";
  const h = hour % 12 === 0 ? 12 : hour % 12;
  return `${h}:${String(minute).padStart(2, "0")} ${period}`;
}

function hourlyRate(trackId: string, hours: number, pricingPlans?: PricingPlans) {
  const plan = pricingPlans?.[trackId];
  if (trackId === "islamic") {
    const threshold = numberValue(plan?.islamicDiscountThreshold, 4);
    return hours > threshold
      ? numberValue(plan?.islamicDiscountUsd ?? plan?.islamicHr5PlusUsd, 6.99)
      : numberValue(plan?.islamicBaseUsd ?? plan?.islamicHrUnder5Usd, 8.5);
  }
  if (trackId === "group") return numberValue(plan?.groupHourlyUsd ?? plan?.hourlyUsd, 2.5);
  const threshold = numberValue(plan?.tutoringDiscountThreshold, 4);
  return hours > threshold
    ? numberValue(plan?.tutoringDiscountUsd ?? plan?.tutoringHr4PlusUsd, 9.99)
    : numberValue(plan?.tutoringBaseUsd ?? plan?.tutoringHrUnder4Usd, 11.99);
}

function monthlyEstimateRaw(trackId: string, hours: number, pricingPlans?: PricingPlans) {
  return hourlyRate(trackId, hours, pricingPlans) * hours * (trackId === "group" ? 4.33 : 4);
}

function monthlyEstimate(trackId: string, hours: number, pricingPlans?: PricingPlans) {
  return `$${monthlyEstimateRaw(trackId, hours, pricingPlans).toFixed(0)}/mo`;
}

function numberValue(value: unknown, fallback: number) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return fallback;
}

function legacyPlanForTrack(trackId: string) {
  if (trackId === "islamic") return "islamic_1_4";
  if (trackId === "group") return "islamic_weekend";
  return "tutoring_1_3";
}

function pricingLabelForTrack(trackId: string) {
  if (trackId === "islamic") return "Islamic & AdLam";
  if (trackId === "group") return "Group Classes";
  return "Tutoring & Literacy";
}

function normalizeSubjectId(value: string) {
  const trimmed = value.trim();
  if (trimmed === "English") return "english";
  if (trimmed === "French") return "french";
  if (trimmed === "Adlam") return "adlam";
  const lower = trimmed.toLowerCase();
  if (lower === "english") return "english";
  if (lower === "french") return "french";
  if (lower === "adlam") return "adlam";
  if (lower === "adult-literacy") return "adult-literacy";
  if (lower === "afterschool" || lower === "after-school") return "after-school";
  if (lower.includes("group")) return "group";
  if (lower.includes("islamic") || lower.includes("quran") || lower.includes("arabic")) return "islamic";
  if (lower.includes("afro") || lower.includes("adlam") || lower.includes("language")) return "languages";
  if (lower.includes("entrepreneur")) return "entrepreneurship";
  if (lower.includes("coding") || lower.includes("programming")) return "coding";
  if (lower.includes("math") || lower.includes("science") || lower.includes("after school")) return "after-school";
  return lower;
}
