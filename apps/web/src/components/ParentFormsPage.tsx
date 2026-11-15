"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useCallback, useEffect, useMemo, useState } from "react";
import {
  BarChart3,
  Calendar,
  CalendarDays,
  CalendarRange,
  Check,
  ChevronRight,
  ClipboardList,
  CloudOff,
  History,
  ListChecks,
  Lock,
  MessageSquareText,
  MousePointerClick,
  Clock,
  School,
  Search,
  SearchX,
  X,
  type LucideIcon,
} from "lucide-react";
import { ParentSpinner, alpha } from "@/components/ParentUi";
import { useLocale } from "@/lib/i18n";
import {
  CATEGORY_COLORS,
  CATEGORY_ORDER,
  availabilityLabel,
  availableToday,
  categoryTitle,
  fallbackSections,
  frequencyLabel,
  matchesFormSearch,
  parentFormSections,
  sortSection,
  visibleFieldCount,
  type FormCategory,
  type FormFrequency,
  type ParentFormTemplate,
} from "@/lib/parentForms";
import { loadFormTemplates, parentBuiltIns } from "@/lib/parentFormsData";
import { parentFormsText } from "@/lib/parentFormsText";
import { PARENT_ROUTES } from "@/lib/parentWeb";
import { useNow } from "@/components/ParentUi";

type Load = { state: "loading" } | { state: "ready"; sections: Map<FormCategory, ParentFormTemplate[]> };

const CATEGORY_ICONS: Record<FormCategory, LucideIcon> = {
  teaching: School,
  studentAssessment: BarChart3,
  feedback: MessageSquareText,
  administrative: ClipboardList,
  other: ClipboardList,
};

const FREQUENCY_ICONS: Record<FormFrequency, LucideIcon> = {
  perSession: Calendar,
  weekly: CalendarRange,
  monthly: CalendarDays,
  onDemand: MousePointerClick,
};

/**
 * Forms (ParentFormsScreen → TeacherFormsScreen parentOnly, B-123…B-133): the
 * forms the school aims at parents, the built-in absence excuse form, and the
 * built-in feedback form when no feedback form is published. Opening a form
 * goes to its own page, as the app pushes FormScreen.
 */
export default function ParentFormsPage() {
  const fr = useLocale() === "fr";
  const text = parentFormsText(fr);
  const builtIns = useMemo(() => parentBuiltIns(text), [text]);
  const router = useRouter();
  const params = useSearchParams();
  const now = useNow(60_000);
  const [templates, setTemplates] = useState<ParentFormTemplate[] | null | "failed">(null);
  const [search, setSearch] = useState("");
  const [submitted, setSubmitted] = useState(false);

  const load = useCallback(() => {
    setTemplates(null);
    loadFormTemplates()
      .then(setTemplates)
      .catch(() => setTemplates("failed"));
  }, []);

  useEffect(() => load(), [load]);

  // FormScreen closes itself after a submission and shows a green snackbar.
  useEffect(() => {
    if (params.get("submitted") !== "1") return;
    setSubmitted(true);
    router.replace(PARENT_ROUTES.forms);
    const timer = window.setTimeout(() => setSubmitted(false), 4000);
    return () => window.clearTimeout(timer);
  }, [params, router]);

  const view: Load = useMemo(() => {
    if (templates === null) return { state: "loading" };
    // A failed read still offers the two built-in forms, with no error (B-129).
    if (templates === "failed") return { state: "ready", sections: fallbackSections(builtIns) };
    return { state: "ready", sections: parentFormSections(templates, builtIns) };
  }, [templates, builtIns]);

  return (
    <div className="min-h-full bg-[#F1F5F9]">
      <header className="bg-[linear-gradient(135deg,#6366F1,#8B5CF6)] px-5 pb-6 pt-5 text-white">
        <div className="flex items-start gap-3">
          <div className="min-w-0 flex-1">
            <h1 className="text-2xl font-bold">{text.formsTitle}</h1>
            <p className="mt-1 text-sm text-white/80">{text.formsSubtitle}</p>
          </div>
          <Link
            href={PARENT_ROUTES.formSubmissions}
            aria-label={text.mySubmissions}
            title={text.mySubmissions}
            className="grid h-11 w-11 shrink-0 place-items-center rounded-full text-white hover:bg-white/15"
          >
            <History size={24} />
          </Link>
        </div>
      </header>

      {submitted ? (
        <p role="status" className="mx-4 mt-4 flex items-center gap-2 rounded-xl bg-[#10B981] px-4 py-3 text-sm font-semibold text-white">
          <Check size={18} />
          Form submitted successfully!
        </p>
      ) : null}

      <div className="px-4 pb-1 pt-4">
        <label className="relative block rounded-[14px] bg-white shadow-[0_2px_8px_rgba(100,116,139,0.08)]">
          <Search size={20} className="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-[#64748B]" />
          <input
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder={text.searchForms}
            aria-label={text.searchForms}
            className="min-h-12 w-full rounded-[14px] bg-transparent pl-12 pr-12 text-sm text-[#0F172A] outline-none placeholder:text-[#94A3B8]"
          />
          {search.trim() ? (
            <button type="button" onClick={() => setSearch("")} aria-label={text.clearSearch} title={text.clearSearch} className="absolute right-2 top-1/2 grid h-9 w-9 -translate-y-1/2 place-items-center rounded-full text-[#64748B] hover:bg-[#F1F5F9]">
              <X size={18} />
            </button>
          ) : null}
        </label>
      </div>

      {view.state === "loading" ? (
        <ParentSpinner padding={48} label="Loading" />
      ) : (
        <FormSections sections={view.sections} search={search} now={now} text={text} onOpen={(template) => router.push(PARENT_ROUTES.formFill(template.id))} />
      )}
      {templates === "failed" ? <RetryHint onRetry={load} label={text.tryAgain} /> : null}
    </div>
  );
}

function FormSections({
  sections,
  search,
  now,
  text,
  onOpen,
}: {
  sections: Map<FormCategory, ParentFormTemplate[]>;
  search: string;
  now: Date;
  text: ReturnType<typeof parentFormsText>;
  onOpen: (template: ParentFormTemplate) => void;
}) {
  const visible = CATEGORY_ORDER.map((category) => ({
    category,
    templates: sortSection(category, (sections.get(category) ?? []).filter((template) => matchesFormSearch(template, category, search))),
  })).filter((section) => section.templates.length > 0);

  if (visible.length === 0) {
    return (
      <div className="grid place-items-center px-6 py-16 text-center">
        <SearchX size={56} className="text-[#B0BEC5]" />
        <p className="mt-3 text-base font-bold text-[#455A64]">{text.noMatch}</p>
        <p className="mt-1.5 text-[13px] text-[#90A4AE]">{text.tryAdjusting}</p>
      </div>
    );
  }

  return (
    <div className="pb-24">
      {visible.map(({ category, templates }) => (
        <section key={category} className="px-4 py-3">
          <div className="mb-3 flex items-center gap-2 pl-1">
            <h2 className="text-xs font-bold uppercase tracking-[1.2px] text-[#90A4AE]">{categoryTitle(category)}</h2>
            <span className="h-px flex-1 bg-[#CFD8DC]" />
          </div>
          {templates.map((template) => (
            <FormCard key={template.id} template={template} category={category} now={now} onOpen={() => onOpen(template)} />
          ))}
        </section>
      ))}
    </div>
  );
}

function FormCard({ template, category, now, onOpen }: { template: ParentFormTemplate; category: FormCategory; now: Date; onOpen: () => void }) {
  const accent = CATEGORY_COLORS[category];
  const available = availableToday(template.frequency, now);
  const Icon = FREQUENCY_ICONS[template.frequency] ?? CATEGORY_ICONS[category];
  const body = (
    <>
      <span className="grid h-[52px] w-[52px] shrink-0 place-items-center rounded-2xl" style={{ background: available ? alpha(accent, 0.1) : "#F5F5F5", color: available ? accent : "#BDBDBD" }}>
        <Icon size={26} />
      </span>
      <span className="min-w-0 flex-1">
        <span className="flex flex-wrap items-center gap-x-2 gap-y-1">
          <span className={`text-base font-bold leading-tight ${available ? "text-[#1E293B]" : "text-[#BDBDBD]"}`}>{template.name}</span>
          {!available ? (
            <span className="inline-flex items-center gap-1 rounded-md border border-[#FFE0B2] bg-[#FFF3E0] px-2 py-0.5 text-[10px] font-bold text-[#EF6C00]">
              <Lock size={10} />
              {availabilityLabel(template.frequency)}
            </span>
          ) : null}
        </span>
        {template.description ? <span className="mt-1.5 line-clamp-2 block text-[13px] leading-[1.4] text-[#90A4AE]">{template.description}</span> : null}
        <span className="mt-3 flex items-center gap-3 text-xs font-medium text-[#90A4AE]">
          <span className="inline-flex items-center gap-1">
            <ListChecks size={14} className="text-[#B0BEC5]" />
            {visibleFieldCount(template)} items
          </span>
          <span className="inline-flex items-center gap-1">
            <Clock size={14} className="text-[#B0BEC5]" />
            {frequencyLabel(template.frequency)}
          </span>
        </span>
      </span>
      {available ? <ChevronRight size={18} className="mt-3 shrink-0 text-[#B0BEC5]" /> : null}
    </>
  );
  const shell = "mb-4 flex w-full items-start gap-4 rounded-[20px] bg-white p-5 text-left shadow-[0_4px_12px_rgba(100,116,139,0.08)]";
  return available ? (
    <button type="button" onClick={onOpen} className={`${shell} hover:shadow-[0_6px_16px_rgba(100,116,139,0.14)]`}>
      {body}
    </button>
  ) : (
    <div className={shell} aria-disabled="true">
      {body}
    </div>
  );
}

function RetryHint({ onRetry, label }: { onRetry: () => void; label: string }) {
  return (
    <div className="flex justify-center pb-10">
      <button type="button" onClick={onRetry} className="inline-flex min-h-10 items-center gap-2 rounded-xl px-4 text-sm font-semibold text-[#6366F1] hover:bg-white">
        <CloudOff size={16} />
        {label}
      </button>
    </div>
  );
}
