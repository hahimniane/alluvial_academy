"use client";

import { onAuthStateChanged, type User } from "firebase/auth";
import { addDoc, collection, getDocs, limit, query, serverTimestamp, Timestamp, where } from "firebase/firestore";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { ClipboardList, FileText, Loader2, Send, X } from "lucide-react";
import { auth, db } from "@/lib/firebase";
import { cachedStudentSession, resolveStudentSession } from "@/lib/studentSession";
import { dateLocale, useT } from "@/lib/i18n";
import { StudentAccessPrompt, StudentShell } from "@/components/StudentDashboardHome";
import { studentCanSeeForm } from "@/lib/formAudience";
import { visibleFieldIds } from "@/lib/formConditions";
import { normalizeReviewStatus, reviewStatusClasses, reviewStatusLabel, type ReviewStatus } from "@/lib/formReview";
import { latestStudentForms, studentSubmissionData, type StudentFormSource } from "@/lib/studentForms";
import {
  FormQuestionCard,
  cleanupUploadedFiles,
  formActionError,
  formFieldErrors,
  isPendingFileValue,
  normalizeFields,
  stringValue,
  uploadPendingFiles,
  type FormFieldValue,
  type SubmittedFieldValue,
  type TemplateField,
} from "@/components/forms/FormFields";

type AccessState = "checking" | "signedOut" | "denied" | "allowed";

type StudentForm = StudentFormSource & {
  description: string;
  frequency: string;
  fields: TemplateField[];
};

type SentForm = {
  id: string;
  formId: string;
  title: string;
  submittedAt: Date | null;
  reviewStatus: ReviewStatus;
};

/**
 * The forms the school aims at students ("Who can see this" includes
 * Students), which a student fills in and sends from here. Mirrors the
 * student Forms screen in the app.
 */
export function StudentFormsPage() {
  const t = useT();
  const [access, setAccess] = useState<AccessState>(() => (cachedStudentSession() ? "allowed" : "checking"));
  const [summary, setSummary] = useState(() => cachedStudentSession()?.summary ?? { displayName: "Student", firstName: "Student", initials: "ST" });
  const [isAdultStudent, setIsAdultStudent] = useState(() => cachedStudentSession()?.isAdultStudent ?? false);
  const [user, setUser] = useState<User | null>(() => auth.currentUser);
  const [forms, setForms] = useState<StudentForm[]>([]);
  const [sent, setSent] = useState<SentForm[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(false);
  const [openForm, setOpenForm] = useState<StudentForm | null>(null);

  useEffect(() => {
    return onAuthStateChanged(auth, async (nextUser) => {
      if (!nextUser) {
        setUser(null);
        setAccess("signedOut");
        setLoading(false);
        return;
      }
      setUser(nextUser);
      const session = await resolveStudentSession(nextUser);
      if (!session.isStudent) {
        setAccess("denied");
        setLoading(false);
        return;
      }
      setSummary(session.summary);
      setIsAdultStudent(session.isAdultStudent);
      setAccess("allowed");
    });
  }, []);

  const loadSent = useCallback(async (uid: string) => {
    const snap = await getDocs(query(collection(db, "form_responses"), where("userId", "==", uid), limit(200)));
    const rows = snap.docs.map((entry) => {
      const data = entry.data() as Record<string, unknown>;
      return {
        id: entry.id,
        formId: stringValue(data.templateId) || stringValue(data.formId),
        title: stringValue(data.formTitle) || stringValue(data.formName),
        submittedAt: data.submittedAt instanceof Timestamp ? data.submittedAt.toDate() : null,
        reviewStatus: normalizeReviewStatus(data.reviewStatus),
      };
    });
    rows.sort((a, b) => (b.submittedAt?.getTime() ?? 0) - (a.submittedAt?.getTime() ?? 0));
    setSent(rows);
  }, []);

  useEffect(() => {
    if (access !== "allowed" || !user) return;
    let cancelled = false;
    (async () => {
      setLoading(true);
      setLoadError(false);
      try {
        const snap = await getDocs(collection(db, "form_templates"));
        const visible = snap.docs
          .map((entry) => ({ id: entry.id, data: entry.data() as Record<string, unknown> }))
          .filter(({ data }) => studentCanSeeForm(data))
          .map(({ id, data }) => ({
            id,
            name: stringValue(data.name) || "Untitled",
            description: stringValue(data.description),
            frequency: stringValue(data.frequency) || "onDemand",
            version: typeof data.version === "number" ? data.version : Number(data.version) || 1,
            updatedAt: data.updatedAt instanceof Timestamp ? data.updatedAt.toMillis() : 0,
            fields: normalizeFields(data.fields),
          }));
        if (cancelled) return;
        setForms(latestStudentForms(visible));
        await loadSent(user.uid).catch(() => null);
      } catch {
        if (!cancelled) setLoadError(true);
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [access, user, loadSent]);

  const sentByForm = useMemo(() => {
    const map = new Map<string, SentForm[]>();
    sent.forEach((item) => {
      const list = map.get(item.formId) ?? [];
      list.push(item);
      map.set(item.formId, list);
    });
    return map;
  }, [sent]);

  const formTitles = useMemo(() => new Map(forms.map((form) => [form.id, form.name])), [forms]);

  if (access !== "allowed") return <StudentAccessPrompt access={access} />;

  return (
    <StudentShell activeLabel="Forms" breadcrumb="Communication / Forms" summary={summary} isAdultStudent={isAdultStudent}>
      <div className="mx-auto w-full max-w-[900px] px-4 py-6 md:px-6">
        <h1 className="text-2xl font-black text-[#0F172A]">{t("Forms")}</h1>
        <p className="mt-1 text-sm text-[#64748B]">{t("Fill in a form and send it to the school.")}</p>

        {loading ? (
          <div className="mt-10 grid place-items-center text-[#64748B]">
            <Loader2 className="animate-spin" size={28} aria-label={t("Loading")} />
          </div>
        ) : loadError ? (
          <p className="mt-6 rounded-xl bg-red-50 px-4 py-3 text-sm font-semibold text-red-700">{t("Could not load your forms. Check your connection and reload the page.")}</p>
        ) : forms.length === 0 ? (
          <div className="mt-10 grid place-items-center rounded-2xl border border-dashed border-[#CBD5E1] bg-white px-6 py-12 text-center">
            <ClipboardList size={44} className="text-[#94A3B8]" />
            <p className="mt-4 text-base font-bold text-[#334155]">{t("No forms for you right now")}</p>
            <p className="mt-1 text-sm text-[#64748B]">{t("When the school shares a form with students, it appears here.")}</p>
          </div>
        ) : (
          <div className="mt-5 grid gap-3">
            {forms.map((form) => {
              const mine = sentByForm.get(form.id) ?? [];
              const last = mine[0]?.submittedAt ?? null;
              return (
                <button
                  key={form.id}
                  type="button"
                  onClick={() => setOpenForm(form)}
                  className="grid grid-cols-[48px_minmax(0,1fr)_auto] items-center gap-4 rounded-2xl border border-[#E2E8F0] bg-white p-4 text-left hover:border-[#BFDBFE] hover:shadow-sm"
                >
                  <span className="grid h-12 w-12 place-items-center rounded-xl bg-[#0386FF]/10 text-[#0386FF]">
                    <FileText size={24} />
                  </span>
                  <span className="min-w-0">
                    <span className="block text-base font-bold text-[#1E293B]">{form.name}</span>
                    {form.description ? <span className="mt-1 line-clamp-2 block text-sm text-[#64748B]">{form.description}</span> : null}
                    {mine.length > 0 ? (
                      <span className="mt-2 block text-xs font-semibold text-[#16A34A]">
                        {sentSummary(t, mine.length, last)}
                      </span>
                    ) : null}
                  </span>
                  <span className="rounded-xl bg-[#0386FF] px-4 py-2 text-sm font-bold text-white">{t("Fill in")}</span>
                </button>
              );
            })}
          </div>
        )}

        {sent.length > 0 ? (
          <section className="mt-10">
            <h2 className="text-lg font-bold text-[#0F172A]">{t("Forms you sent")}</h2>
            <ul className="mt-3 divide-y divide-[#E2E8F0] rounded-2xl border border-[#E2E8F0] bg-white">
              {sent.slice(0, 30).map((item) => (
                <li key={item.id} className="flex flex-wrap items-center gap-x-4 gap-y-1 px-4 py-3">
                  <span className="min-w-0 flex-1 truncate text-sm font-semibold text-[#1E293B]">{item.title || formTitles.get(item.formId) || t("Form")}</span>
                  <span className="text-xs text-[#64748B]">{item.submittedAt ? shortDate(item.submittedAt) : ""}</span>
                  <span className={`rounded-full px-2 py-0.5 text-xs font-semibold ${reviewStatusClasses(item.reviewStatus)}`}>{t(reviewStatusLabel(item.reviewStatus))}</span>
                </li>
              ))}
            </ul>
          </section>
        ) : null}
      </div>

      {openForm && user ? (
        <StudentFormSheet
          form={openForm}
          user={user}
          firstName={summary.firstName}
          displayName={summary.displayName}
          onClose={() => setOpenForm(null)}
          onSubmitted={() => loadSent(user.uid).catch(() => null)}
        />
      ) : null}
    </StudentShell>
  );
}

function StudentFormSheet({
  form,
  user,
  firstName,
  displayName,
  onClose,
  onSubmitted,
}: {
  form: StudentForm;
  user: User;
  firstName: string;
  displayName: string;
  onClose: () => void;
  onSubmitted: () => Promise<unknown>;
}) {
  const t = useT();
  const fields = form.fields;
  const [values, setValues] = useState<Record<string, FormFieldValue>>({});
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [submitting, setSubmitting] = useState(false);
  const [done, setDone] = useState(false);
  const [failure, setFailure] = useState("");
  const previewUrlsRef = useRef<Set<string>>(new Set());
  const shownFieldIds = useMemo(() => visibleFieldIds(fields, values), [fields, values]);
  const shownFields = fields.filter((item) => shownFieldIds.has(item.id));

  useEffect(() => {
    const urls = previewUrlsRef.current;
    return () => {
      urls.forEach((previewUrl) => URL.revokeObjectURL(previewUrl));
      urls.clear();
    };
  }, []);

  const setValue = (fieldId: string, value: FormFieldValue) => {
    setValues((current) => {
      const previous = current[fieldId];
      if (isPendingFileValue(previous) && previous.previewUrl !== (isPendingFileValue(value) ? value.previewUrl : "")) {
        URL.revokeObjectURL(previous.previewUrl);
        previewUrlsRef.current.delete(previous.previewUrl);
      }
      if (isPendingFileValue(value)) previewUrlsRef.current.add(value.previewUrl);
      return { ...current, [fieldId]: value };
    });
    setErrors((current) => {
      if (!current[fieldId]) return current;
      const next = { ...current };
      delete next[fieldId];
      return next;
    });
  };

  const submit = async () => {
    const nextErrors = formFieldErrors(fields, shownFields, values);
    setErrors(nextErrors);
    if (Object.keys(nextErrors).length > 0) return;

    setSubmitting(true);
    setFailure("");
    let uploadedPaths: string[] = [];
    try {
      if (!navigator.onLine) throw new Error(t("You appear to be offline. Reconnect and try again."));
      // A question hidden by its condition is not part of this submission.
      const shownValues = Object.fromEntries(Object.entries(values).filter(([fieldId]) => shownFieldIds.has(fieldId)));
      const uploadResult = await uploadPendingFiles(shownValues, user.uid);
      uploadedPaths = uploadResult.storagePaths;
      const responses = shownFields.reduce<Record<string, SubmittedFieldValue>>((acc, item) => {
        acc[item.id] = uploadResult.values[item.id] ?? "";
        return acc;
      }, {});
      await addDoc(collection(db, "form_responses"), {
        ...studentSubmissionData({
          form,
          uid: user.uid,
          email: user.email ?? "",
          firstName,
          displayName,
          now: new Date(),
        }),
        responses,
        submittedAt: serverTimestamp(),
        lastUpdated: serverTimestamp(),
      });
      setDone(true);
      await onSubmitted();
      window.setTimeout(onClose, 1100);
    } catch (error) {
      if (uploadedPaths.length) await cleanupUploadedFiles(uploadedPaths);
      setFailure(t(formActionError(error, "Could not submit this form.")));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto bg-[#0F172A]/45 px-4 py-5" role="dialog" aria-modal="true" aria-label={form.name}>
      <div className="mx-auto max-w-[800px]">
        <div className="mb-4 flex justify-end">
          <button type="button" onClick={onClose} aria-label={t("Close form")} className="grid h-10 w-10 place-items-center rounded-full bg-white text-[#334155] shadow-sm">
            <X size={20} />
          </button>
        </div>
        <section className="rounded-2xl bg-white p-8 shadow-[0_4px_10px_rgba(15,23,42,0.08)] max-[700px]:p-5">
          <div className="flex gap-4">
            <span className="grid h-12 w-12 shrink-0 place-items-center rounded-xl bg-[#0386FF]/10 text-[#0386FF]">
              <FileText size={24} />
            </span>
            <div className="min-w-0">
              <h2 className="text-[28px] font-bold leading-tight text-[#111827] max-[700px]:text-2xl">{form.name}</h2>
              {form.description ? <p className="mt-2 text-base leading-6 text-[#6B7280]">{form.description}</p> : null}
            </div>
          </div>
        </section>

        <div className="mt-6">
          {shownFields.length === 0 ? (
            <div className="rounded-lg border border-[#F59E0B] bg-[#FEF3C7] p-4 text-sm font-semibold text-[#B45309]">{t("No form fields are currently visible.")}</div>
          ) : (
            shownFields.map((item) => (
              <FormQuestionCard key={item.id} field={item} value={values[item.id]} error={errors[item.id] ? t(errors[item.id]) : undefined} onChange={(value) => setValue(item.id, value)} />
            ))
          )}
        </div>

        <section className="mb-8 mt-2 rounded-2xl bg-white p-6 shadow-[0_4px_10px_rgba(15,23,42,0.08)] max-[700px]:p-4">
          {done ? <p className="mb-4 rounded-xl bg-green-50 px-4 py-3 text-sm font-semibold text-green-700">{t("Form submitted successfully")}</p> : null}
          {failure ? <p className="mb-4 rounded-xl bg-red-50 px-4 py-3 text-sm font-semibold text-red-700">{failure}</p> : null}
          <div className="flex flex-wrap justify-end gap-3 max-[700px]:grid max-[700px]:grid-cols-1">
            <button type="button" onClick={onClose} className="rounded-xl border border-[#E5E7EB] px-5 py-3 text-sm font-bold text-[#6B7280] hover:bg-[#F8FAFC]">
              {t("Cancel")}
            </button>
            <button
              type="button"
              onClick={submit}
              disabled={submitting || done || shownFields.length === 0}
              className="inline-flex items-center justify-center gap-2 rounded-xl bg-[#0386FF] px-6 py-3 text-sm font-bold text-white shadow-sm disabled:cursor-not-allowed disabled:bg-[#93C5FD]"
            >
              {submitting ? <Loader2 size={18} className="animate-spin" /> : <Send size={18} />}
              {submitting ? t("Submitting...") : t("Submit Form")}
            </button>
          </div>
        </section>
      </div>
    </div>
  );
}

function sentSummary(t: ReturnType<typeof useT>, count: number, last: Date | null) {
  if (count === 1) return last ? t("Sent on {date}", { date: shortDate(last) }) : t("Sent once");
  return last ? t("Sent {n} times, last on {date}", { n: count, date: shortDate(last) }) : t("Sent {n} times", { n: count });
}

function shortDate(value: Date) {
  return new Intl.DateTimeFormat(dateLocale(), { month: "short", day: "numeric", year: "numeric" }).format(value);
}
