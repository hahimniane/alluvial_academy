"use client";

import { FormEvent, useState } from "react";
import {
  BookOpen,
  CheckCircle2,
  Computer,
  Languages,
  MoreHorizontal,
  PersonStanding,
  Send,
  ShieldCheck,
  UserRound,
} from "lucide-react";
import { submitLeadershipApplication, submitTeacherApplication } from "@/lib/forms";

type Status = "idle" | "saving" | "success" | "error";
type Option = { value: string; label: string };

const currentStatusOptions: Option[] = [
  { value: "university_student", label: "University Student" },
  { value: "high_school_student", label: "High School Student" },
  { value: "university_graduate", label: "University Graduate" },
  { value: "other", label: "Other" },
];

const leadershipStatusOptions: Option[] = [
  { value: "university_student", label: "University Student" },
  { value: "university_graduate", label: "University Graduate" },
  { value: "professional", label: "Professional" },
  { value: "other", label: "Other" },
];

const genderOptions: Option[] = [
  { value: "male", label: "Male" },
  { value: "female", label: "Female" },
];

const availabilityOptions: Option[] = [
  { value: "one_week", label: "In One Week" },
  { value: "two_weeks", label: "In Two Weeks" },
  { value: "three_weeks", label: "In Three Weeks" },
  { value: "one_month", label: "In a Month" },
  { value: "other", label: "Other" },
];

const languages = [
  "English",
  "Arabic",
  "French",
  "Spanish",
  "Mandingo",
  "Pular",
  "Wolof",
  "Hausa",
  "Turkish",
  "Urdu",
  "Bengali",
  "Indonesian",
  "Malay",
  "Swahili",
  "Amharic",
  "Adlam",
  "Other",
];

const teachingPrograms = [
  {
    value: "english",
    label: "After School Tutoring (English track)",
    icon: Languages,
    color: "#3B82F6",
  },
  {
    value: "islamic_studies",
    label: "Islamic Program (Quran, Arabic, Hadith, Fiqh)",
    icon: BookOpen,
    color: "#10B981",
  },
  {
    value: "adult_literacy",
    label: "Adult Literacy (English/French reading and writing)",
    icon: BookOpen,
    color: "#F59E0B",
  },
  {
    value: "adlam",
    label: "AdLaM (Reading and Writing)",
    icon: Languages,
    color: "#8B5CF6",
  },
  {
    value: "other",
    label: "Other",
    icon: MoreHorizontal,
    color: "#6B7280",
  },
];

const teacherInitial = {
  firstName: "",
  lastName: "",
  email: "",
  currentLocation: "",
  gender: "",
  phoneNumber: "",
  countryCode: "+1",
  nationality: "",
  currentStatus: "",
  currentStatusOther: "",
  teachingProgramOther: "",
  englishSubjects: "",
  timeDiscipline: "",
  scheduleBalance: "",
  tajwidLevel: "",
  quranMemorization: "",
  arabicProficiency: "",
  interestReason: "",
  electricityAccess: "",
  teachingComfort: "",
  studentInteractionGuarantee: "",
  availabilityStart: "",
  availabilityStartOther: "",
  teachingDevice: "",
  internetAccess: "",
  scenarioNonParticipatingStudent: "",
  feedbackOnForm: "",
};

const leadershipInitial = {
  firstName: "",
  lastName: "",
  email: "",
  currentLocation: "",
  gender: "",
  phoneNumber: "",
  countryCode: "+1",
  nationality: "",
  currentStatus: "",
  currentStatusOther: "",
  interestReason: "",
  relevantExperience: "",
  availabilityStart: "",
  availabilityStartOther: "",
};

function wordCount(value: string) {
  const trimmed = value.trim();
  if (!trimmed) return 0;
  return trimmed.split(/\s+/).length;
}

function Field({
  label,
  name,
  value,
  onChange,
  required,
  type = "text",
  placeholder,
  autoComplete,
}: {
  label: string;
  name: string;
  value: string;
  onChange: (name: string, value: string) => void;
  required?: boolean;
  type?: string;
  placeholder?: string;
  autoComplete?: string;
}) {
  return (
    <label className="grid gap-3 text-[15px] font-semibold leading-[1.4] text-[#111827]">
      <span>
        {label}
        {required ? <span className="ml-1 text-red-600">*</span> : null}
      </span>
      <input
        name={name}
        value={value}
        onChange={(event) => onChange(name, event.target.value)}
        className="min-h-[54px] w-full rounded-2xl border border-[#E5E7EB] bg-[#FAFAFA] px-4 py-4 text-sm text-[#111827] outline-none transition placeholder:text-[#9CA3AF] focus:border-[#8B5CF6] focus:ring-2 focus:ring-[#8B5CF6]/20"
        required={required}
        type={type}
        placeholder={placeholder}
        autoComplete={autoComplete}
      />
    </label>
  );
}

function TextArea({
  label,
  name,
  value,
  onChange,
  required,
  minWords,
  maxWords,
  rows = 5,
  placeholder,
}: {
  label: string;
  name: string;
  value: string;
  onChange: (name: string, value: string) => void;
  required?: boolean;
  minWords?: number;
  maxWords?: number;
  rows?: number;
  placeholder?: string;
}) {
  const count = wordCount(value);
  const invalidMin = Boolean(minWords && value.trim() && count < minWords);
  const invalidMax = Boolean(maxWords && count > maxWords);

  return (
    <label className="grid gap-3 text-[15px] font-semibold leading-[1.4] text-[#111827]">
      <span>
        {label}
        {required ? <span className="ml-1 text-red-600">*</span> : null}
      </span>
      <textarea
        name={name}
        value={value}
        onChange={(event) => onChange(name, event.target.value)}
        className="w-full resize-y rounded-2xl border border-[#E5E7EB] bg-[#FAFAFA] px-4 py-4 text-sm text-[#111827] outline-none transition placeholder:text-[#9CA3AF] focus:border-[#8B5CF6] focus:ring-2 focus:ring-[#8B5CF6]/20"
        required={required}
        rows={rows}
        placeholder={placeholder}
        data-min-words={minWords}
        data-max-words={maxWords}
      />
      {minWords || maxWords ? (
        <span className={`text-xs font-bold ${invalidMin || invalidMax ? "text-red-700" : "text-slate-500"}`}>
          {count} words
          {minWords ? ` / minimum ${minWords}` : ""}
          {maxWords ? ` / maximum ${maxWords}` : ""}
        </span>
      ) : null}
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
  options: Option[];
  required?: boolean;
}) {
  return (
    <label className="grid gap-3 text-[15px] font-semibold leading-[1.4] text-[#111827]">
      <span>
        {label}
        {required ? <span className="ml-1 text-red-600">*</span> : null}
      </span>
      <select
        name={name}
        value={value}
        onChange={(event) => onChange(name, event.target.value)}
        className="min-h-[54px] w-full rounded-2xl border border-[#E5E7EB] bg-[#FAFAFA] px-4 py-4 text-sm text-[#111827] outline-none transition focus:border-[#8B5CF6] focus:ring-2 focus:ring-[#8B5CF6]/20"
        required={required}
      >
        <option value="">Select an option</option>
        {options.map((option) => (
          <option key={option.value} value={option.value}>
            {option.label}
          </option>
        ))}
      </select>
    </label>
  );
}

function SectionTitle({ icon: Icon, title }: { icon: typeof UserRound; title: string }) {
  return (
    <div className="flex items-center gap-3">
      <span className="inline-flex h-9 w-9 items-center justify-center rounded-lg bg-[#8B5CF6]/10 text-[#8B5CF6]">
        <Icon size={20} />
      </span>
      <h2 className="text-xl font-bold text-[#111827]">{title}</h2>
    </div>
  );
}

function Progress({ page, total }: { page: number; total: number }) {
  return (
    <div>
      <div className="grid gap-2" style={{ gridTemplateColumns: `repeat(${total}, minmax(0, 1fr))` }}>
        {Array.from({ length: total }, (_, index) => (
          <span
            key={index}
            className={`h-1 rounded-full ${index <= page ? "bg-[#8B5CF6]" : "bg-[#E5E7EB]"}`}
          />
        ))}
      </div>
      <p className="mt-2 text-center text-xs font-semibold text-slate-500">
        Step {page + 1} of {total}
      </p>
    </div>
  );
}

function validateVisibleForm(form: HTMLFormElement) {
  if (!form.reportValidity()) return false;
  const textareas = Array.from(form.querySelectorAll("textarea")) as HTMLTextAreaElement[];
  for (const textarea of textareas) {
    const count = wordCount(textarea.value);
    const min = Number(textarea.dataset.minWords ?? 0);
    const max = Number(textarea.dataset.maxWords ?? 0);
    if (min && count < min) {
      textarea.setCustomValidity(`Please write at least ${min} words.`);
      textarea.reportValidity();
      textarea.setCustomValidity("");
      return false;
    }
    if (max && count > max) {
      textarea.setCustomValidity(`Please limit this answer to ${max} words.`);
      textarea.reportValidity();
      textarea.setCustomValidity("");
      return false;
    }
  }
  return true;
}

export function TeacherApplicationForm() {
  const [page, setPage] = useState(0);
  const [status, setStatus] = useState<Status>("idle");
  const [error, setError] = useState("");
  const [values, setValues] = useState({ ...teacherInitial });
  const [selectedPrograms, setSelectedPrograms] = useState<string[]>([]);
  const [selectedLanguages, setSelectedLanguages] = useState<string[]>([]);

  const isIslamicSelected = selectedPrograms.includes("islamic_studies");
  const isEnglishSelected = selectedPrograms.includes("english");
  const totalPages = 5;

  const update = (name: string, value: string) => {
    setValues((current) => ({ ...current, [name]: value }));
  };

  const toggleProgram = (value: string) => {
    setSelectedPrograms((current) =>
      current.includes(value) ? current.filter((item) => item !== value) : [...current, value],
    );
  };

  const toggleLanguage = (value: string) => {
    setSelectedLanguages((current) =>
      current.includes(value) ? current.filter((item) => item !== value) : [...current, value],
    );
  };

  function goNext(form: HTMLFormElement) {
    setError("");
    if (!validateVisibleForm(form)) return;
    if (page === 1 && selectedPrograms.length === 0) {
      setError("Please select at least one teaching program.");
      return;
    }
    if (page === 1 && selectedLanguages.length === 0) {
      setError("Please select at least one language.");
      return;
    }
    setPage((current) => Math.min(current + 1, totalPages - 1));
  }

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    if (page < totalPages - 1) {
      goNext(form);
      return;
    }
    setError("");
    if (!validateVisibleForm(form)) return;
    setStatus("saving");
    try {
      await submitTeacherApplication({
        ...values,
        teachingPrograms: selectedPrograms,
        teachingProgramOther: selectedPrograms.includes("other") ? values.teachingProgramOther : "",
        englishSubjects: isEnglishSelected ? values.englishSubjects : "",
        languages: selectedLanguages,
        tajwidLevel: isIslamicSelected ? values.tajwidLevel : "",
        quranMemorization: isIslamicSelected ? values.quranMemorization : "",
        arabicProficiency: isIslamicSelected ? values.arabicProficiency : "",
        availabilityStartOther: values.availabilityStart === "other" ? values.availabilityStartOther : "",
      });
      setValues({ ...teacherInitial });
      setSelectedPrograms([]);
      setSelectedLanguages([]);
      setPage(0);
      setStatus("success");
    } catch {
      setStatus("error");
    }
  }

  return (
    <form
      onSubmit={onSubmit}
      className="mx-auto max-w-[800px] rounded-[24px] bg-white p-4 shadow-[0_10px_30px_rgba(0,0,0,0.06)] md:p-8"
    >
      <div className="text-center">
        <span className="inline-flex rounded-full border border-[#8B5CF6]/20 bg-[#8B5CF6]/10 px-4 py-2 text-sm font-semibold text-[#8B5CF6]">
          Join Our Team
        </span>
        <h1 className="mt-5 text-[32px] font-extrabold leading-tight text-[#111827]">Teacher Application</h1>
        <p className="mx-auto mt-3 max-w-2xl text-base leading-7 text-[#6B7280]">
          Thank you for your interest in teaching with us. Please complete every step so we can review your application properly.
        </p>
      </div>

      <div className="mt-8">
        <Progress page={page} total={totalPages} />
      </div>

      <div className="mt-8 min-h-[600px]">
        {page === 0 ? (
          <div className="grid gap-4">
            <SectionTitle title="Personal Information" icon={UserRound} />
            <Field label="First Name" name="firstName" value={values.firstName} onChange={update} required placeholder="Mahmoud" autoComplete="given-name" />
            <Field label="Last Name" name="lastName" value={values.lastName} onChange={update} required placeholder="Barry" autoComplete="family-name" />
            <Field label="Email" name="email" value={values.email} onChange={update} required type="email" placeholder="Mahmoud.barry@example.com" autoComplete="email" />
            <Field label="Current Location (Country and City)" name="currentLocation" value={values.currentLocation} onChange={update} required placeholder="United States, New York" />
            <SelectField label="Gender" name="gender" value={values.gender} onChange={update} options={genderOptions} required />
            <div className="grid gap-4 md:grid-cols-[150px_1fr]">
              <Field label="Country code" name="countryCode" value={values.countryCode} onChange={update} required placeholder="+1" autoComplete="tel-country-code" />
              <Field label="WhatsApp Number" name="phoneNumber" value={values.phoneNumber} onChange={update} required placeholder="6468728590" autoComplete="tel" />
            </div>
            <Field label="Nationality" name="nationality" value={values.nationality} onChange={update} required placeholder="American" />
            <SelectField label="I am currently a..." name="currentStatus" value={values.currentStatus} onChange={update} options={currentStatusOptions} required />
            {values.currentStatus === "other" ? (
              <Field label="Please specify" name="currentStatusOther" value={values.currentStatusOther} onChange={update} required placeholder="Your current status" />
            ) : null}
          </div>
        ) : null}

        {page === 1 ? (
          <div className="grid gap-4">
            <SectionTitle title="Teaching Programs" icon={BookOpen} />
            <p className="text-sm text-[#6B7280]">Select the program(s) you are interested in teaching.</p>
            <div className="grid gap-3">
              {teachingPrograms.map(({ value, label, icon: Icon, color }) => {
                const selected = selectedPrograms.includes(value);
                const accessibleLabel =
                  value === "islamic_studies" ? "Islamic & AdLam Islamic Program" : label;
                return (
                  <button
                    key={value}
                    type="button"
                    onClick={() => toggleProgram(value)}
                    className="flex items-center gap-3 rounded-xl border p-4 text-left transition"
                    style={{
                      borderColor: selected ? color : "#E5E7EB",
                      borderWidth: selected ? 2 : 1,
                      backgroundColor: selected ? `${color}18` : "white",
                    }}
                    aria-pressed={selected}
                    aria-label={accessibleLabel}
                  >
                    <span className="inline-flex h-9 w-9 items-center justify-center rounded-lg" style={{ backgroundColor: selected ? `${color}2e` : "#F3F4F6", color }}>
                      <Icon size={20} />
                    </span>
                    <span className="flex-1 text-sm font-semibold" style={{ color: selected ? color : "#374151" }}>
                      {label}
                    </span>
                    <CheckCircle2 size={24} className={selected ? "" : "opacity-25"} style={{ color }} />
                  </button>
                );
              })}
            </div>
            {selectedPrograms.includes("other") ? (
              <Field label="Please specify other program" name="teachingProgramOther" value={values.teachingProgramOther} onChange={update} required placeholder="Your program" />
            ) : null}
            {isEnglishSelected ? (
              <TextArea
                label="If interested in the After School English track, list subjects you can teach"
                name="englishSubjects"
                value={values.englishSubjects}
                onChange={update}
                rows={3}
                placeholder="Reading, Writing, Grammar, Vocabulary..."
              />
            ) : null}
            {isIslamicSelected ? (
              <div className="grid gap-4 rounded-2xl border border-slate-200 bg-slate-50 p-4">
                <h3 className="font-bold text-[#374151]">Islamic Studies Qualifications</h3>
                <SelectField
                  label="Are you excellent in Tajwid Rules?"
                  name="tajwidLevel"
                  value={values.tajwidLevel}
                  onChange={update}
                  options={[
                    { value: "yes", label: "Yes" },
                    { value: "no", label: "No" },
                    { value: "average", label: "Average" },
                    { value: "n/a", label: "N/A" },
                  ]}
                />
                <SelectField
                  label="What is your level of Quran Memorization?"
                  name="quranMemorization"
                  value={values.quranMemorization}
                  onChange={update}
                  options={[
                    { value: "hafiz", label: "100% - I am Hafiz" },
                    { value: "50%_or_more", label: "About 50% or more" },
                    { value: "35%_or_less", label: "About 35% or less" },
                    { value: "less_than_juzu_anma", label: "I memorize less than Juzu Anma" },
                    { value: "n/a", label: "N/A" },
                  ]}
                />
                <SelectField
                  label="How perfectly do you read and write Arabic?"
                  name="arabicProficiency"
                  value={values.arabicProficiency}
                  onChange={update}
                  options={[
                    { value: "excellent", label: "I Am Excellent" },
                    { value: "intermediate", label: "I Am Intermediate" },
                    { value: "beginner", label: "I Am A Beginner" },
                    { value: "n/a", label: "N/A" },
                  ]}
                />
              </div>
            ) : null}
            <div>
              <h3 className="mb-3 font-bold text-[#374151]">Languages You Fluently Speak</h3>
              <div className="flex flex-wrap gap-2">
                {languages.map((language) => {
                  const selected = selectedLanguages.includes(language);
                  return (
                    <button
                      key={language}
                      type="button"
                      onClick={() => toggleLanguage(language)}
                      className={`rounded-full border px-3 py-2 text-sm font-semibold transition ${
                        selected
                          ? "border-[#8B5CF6] bg-[#8B5CF6]/15 text-[#6D28D9]"
                          : "border-slate-200 bg-white text-slate-700"
                      }`}
                      aria-pressed={selected}
                    >
                      {language}
                    </button>
                  );
                })}
              </div>
            </div>
          </div>
        ) : null}

        {page === 2 ? (
          <div className="grid gap-4">
            <SectionTitle title="Experience & Commitment" icon={ShieldCheck} />
            <SelectField
              label="How disciplined are you with time, especially working late at night?"
              name="timeDiscipline"
              value={values.timeDiscipline}
              onChange={update}
              required
              options={[
                { value: "100%", label: "100% - Sleep will never cause me to miss a class" },
                { value: "50%", label: "50% - Sleep and personal engagement might affect me" },
                { value: "<30%", label: "<30% - Resisting sleep and planning ahead is hard" },
                { value: "day_person", label: "Sorry, not at all - I am a day person" },
              ]}
            />
            <SelectField
              label="How well can you balance school/personal schedule with teaching (6 hrs/week required)?"
              name="scheduleBalance"
              value={values.scheduleBalance}
              onChange={update}
              required
              options={[
                { value: "100%", label: "100% - I am always on top of things" },
                { value: "50%", label: "50% - I often try to be balanced" },
                { value: ">30%", label: ">30% - Life balance is not one of my strengths" },
                { value: "not_at_all", label: "Not at all" },
                { value: "n/a", label: "N/A" },
              ]}
            />
            <TextArea
              label="Why are you interested in applying for a teaching role with us? (100-400 words)"
              name="interestReason"
              value={values.interestReason}
              onChange={update}
              required
              minWords={100}
              maxWords={400}
              rows={6}
              placeholder="Describe your motivation..."
            />
            <SelectField
              label="How often do you have electricity/energy at home?"
              name="electricityAccess"
              value={values.electricityAccess}
              onChange={update}
              required
              options={[
                { value: "always", label: "Always / 24 hours / 7 days" },
                { value: "sometimes", label: "Sometimes" },
                { value: "rarely", label: "Rarely" },
                { value: "never", label: "Never" },
              ]}
            />
            <SelectField
              label="How comfortable are you teaching teenagers, adults, and children online?"
              name="teachingComfort"
              value={values.teachingComfort}
              onChange={update}
              required
              options={[
                { value: "very_comfortable", label: "Very comfortable" },
                { value: "comfortable", label: "Comfortable" },
                { value: "less_comfortable", label: "Less comfortable" },
                { value: "uncomfortable", label: "Uncomfortable" },
              ]}
            />
            <SelectField
              label="Do you guarantee responsible, legal, and moral interaction with students, especially minors?"
              name="studentInteractionGuarantee"
              value={values.studentInteractionGuarantee}
              onChange={update}
              required
              options={[
                { value: "yes_always", label: "Yes, and always" },
                { value: "sometimes", label: "Sometimes" },
                { value: "maybe_try", label: "Maybe, but I will try" },
                { value: "no_cant", label: "No, I can't" },
              ]}
            />
            <SelectField label="How soon are you available to start teaching?" name="availabilityStart" value={values.availabilityStart} onChange={update} options={availabilityOptions} required />
            {values.availabilityStart === "other" ? (
              <Field label="Please specify availability" name="availabilityStartOther" value={values.availabilityStartOther} onChange={update} required placeholder="Your availability" />
            ) : null}
          </div>
        ) : null}

        {page === 3 ? (
          <div className="grid gap-4">
            <SectionTitle title="Technical Requirements" icon={Computer} />
            <SelectField
              label="What device do you intend to use to teach classes?"
              name="teachingDevice"
              value={values.teachingDevice}
              onChange={update}
              required
              options={[
                { value: "computer", label: "A Computer" },
                { value: "tablet", label: "A Tablet" },
                { value: "phone", label: "A Phone" },
                { value: "no_device", label: "No Device" },
              ]}
            />
            <SelectField
              label="How often do you have access to the internet?"
              name="internetAccess"
              value={values.internetAccess}
              onChange={update}
              required
              options={[
                { value: "always", label: "Always / 24 hours / 7 days" },
                { value: "often", label: "Often / Few days a week" },
                { value: "rarely", label: "Rarely / Few hours a week" },
                { value: "not_at_all", label: "Not at all" },
              ]}
            />
          </div>
        ) : null}

        {page === 4 ? (
          <div className="grid gap-4">
            <SectionTitle title="Teaching Scenarios" icon={PersonStanding} />
            <TextArea
              label="Scenario: What would you do if a student (child) does not want to participate/read during class? (100-300 words)"
              name="scenarioNonParticipatingStudent"
              value={values.scenarioNonParticipatingStudent}
              onChange={update}
              required
              minWords={100}
              maxWords={300}
              rows={6}
              placeholder="Describe your approach..."
            />
            <SectionTitle title="Feedback" icon={Send} />
            <TextArea
              label="Any feedback on this application form? What didn't you like? (Optional)"
              name="feedbackOnForm"
              value={values.feedbackOnForm}
              onChange={update}
              rows={4}
              placeholder="Your feedback helps us improve..."
            />
          </div>
        ) : null}
      </div>

      {error ? <p className="mt-4 rounded-lg bg-red-50 p-3 text-sm font-bold text-red-700">{error}</p> : null}
      {status === "success" ? <p className="mt-4 rounded-lg bg-emerald-50 p-3 text-sm font-bold text-emerald-700">Application submitted successfully.</p> : null}
      {status === "error" ? <p className="mt-4 rounded-lg bg-red-50 p-3 text-sm font-bold text-red-700">We could not submit the application. Please try again.</p> : null}

      <div className="mt-8 flex items-center justify-between gap-3">
        {page > 0 ? (
          <button
            type="button"
            className="min-h-12 rounded-xl border border-[#E5E7EB] bg-white px-6 py-4 font-semibold text-[#374151] transition hover:bg-[#F9FAFB]"
            onClick={() => setPage((current) => Math.max(0, current - 1))}
          >
            Previous
          </button>
        ) : (
          <span />
        )}
        <button
          type="submit"
          className="min-h-12 min-w-[180px] rounded-xl bg-[#8B5CF6] px-6 py-4 font-semibold text-white transition hover:bg-[#7C3AED] disabled:cursor-wait disabled:opacity-75"
          disabled={status === "saving"}
        >
          {status === "saving" ? "Submitting..." : page < totalPages - 1 ? "Next" : "Submit Application"}
        </button>
      </div>
    </form>
  );
}

export function LeadershipApplicationForm() {
  const [status, setStatus] = useState<Status>("idle");
  const [values, setValues] = useState({ ...leadershipInitial });

  const update = (name: string, value: string) => {
    setValues((current) => ({ ...current, [name]: value }));
  };

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    if (!validateVisibleForm(form)) return;
    setStatus("saving");
    try {
      await submitLeadershipApplication({
        ...values,
        currentStatusOther: values.currentStatus === "other" ? values.currentStatusOther : "",
        availabilityStartOther: values.availabilityStart === "other" ? values.availabilityStartOther : "",
      });
      setValues({ ...leadershipInitial });
      setStatus("success");
    } catch {
      setStatus("error");
    }
  }

  return (
    <form
      onSubmit={onSubmit}
      className="mx-auto grid max-w-[800px] gap-6 rounded-[24px] bg-white p-5 shadow-[0_10px_30px_rgba(0,0,0,0.06)] md:p-8"
    >
      <div className="text-center">
        <span className="inline-flex rounded-full border border-[#10B981]/20 bg-[#10B981]/10 px-4 py-2 text-sm font-semibold text-[#10B981]">
          Join Our Leadership Team
        </span>
        <h1 className="mt-5 text-[32px] font-extrabold leading-tight text-[#111827]">Join Our Leadership Team</h1>
        <p className="mx-auto mt-3 max-w-2xl text-base leading-7 text-[#6B7280]">
          Lead, inspire, and make a lasting impact by helping Alluwal grow with care and structure.
        </p>
      </div>

      <SectionTitle title="Personal Information" icon={UserRound} />
      <div className="grid gap-4 md:grid-cols-2">
        <Field label="First Name" name="firstName" value={values.firstName} onChange={update} required autoComplete="given-name" />
        <Field label="Last Name" name="lastName" value={values.lastName} onChange={update} required autoComplete="family-name" />
      </div>
      <Field label="Email" name="email" value={values.email} onChange={update} required type="email" autoComplete="email" />
      <Field label="Current Location (Country and City)" name="currentLocation" value={values.currentLocation} onChange={update} required />
      <div className="grid gap-4 md:grid-cols-2">
        <SelectField label="Gender" name="gender" value={values.gender} onChange={update} options={genderOptions} required />
        <Field label="Nationality" name="nationality" value={values.nationality} onChange={update} required />
      </div>
      <div className="grid gap-4 md:grid-cols-[150px_1fr]">
        <Field label="Country code" name="countryCode" value={values.countryCode} onChange={update} required placeholder="+1" autoComplete="tel-country-code" />
        <Field label="WhatsApp Number" name="phoneNumber" value={values.phoneNumber} onChange={update} required autoComplete="tel" />
      </div>
      <SelectField label="I am currently a..." name="currentStatus" value={values.currentStatus} onChange={update} options={leadershipStatusOptions} required />
      {values.currentStatus === "other" ? (
        <Field label="Please specify" name="currentStatusOther" value={values.currentStatusOther} onChange={update} required />
      ) : null}

      <SectionTitle title="Leadership Interest" icon={ShieldCheck} />
      <TextArea
        label="Why are you interested in a leadership role?"
        name="interestReason"
        value={values.interestReason}
        onChange={update}
        required
        rows={4}
      />
      <TextArea
        label="Relevant Leadership/Management Experience (Optional)"
        name="relevantExperience"
        value={values.relevantExperience}
        onChange={update}
        rows={4}
      />
      <SelectField label="How soon are you available to start?" name="availabilityStart" value={values.availabilityStart} onChange={update} options={availabilityOptions} required />
      {values.availabilityStart === "other" ? (
        <Field label="Please specify availability" name="availabilityStartOther" value={values.availabilityStartOther} onChange={update} required />
      ) : null}

      <button type="submit" className="alluwal-button alluwal-button-primary" disabled={status === "saving"}>
        <Send size={18} />
        {status === "saving" ? "Submitting..." : "Submit Application"}
      </button>
      {status === "success" ? <p className="text-sm font-bold text-emerald-700">Application submitted successfully.</p> : null}
      {status === "error" ? <p className="text-sm font-bold text-red-700">We could not submit the application. Please try again.</p> : null}
    </form>
  );
}
