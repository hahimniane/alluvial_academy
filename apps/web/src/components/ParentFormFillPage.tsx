"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useMemo, useRef, useState } from "react";
import { FileText, Loader2, Send } from "lucide-react";
import { auth } from "@/lib/firebase";
import { useParentSession } from "@/components/ParentArea";
import { ParentAppBar, ParentErrorCard, ParentSpinner } from "@/components/ParentUi";
import {
  FormQuestionCard,
  cleanupUploadedFiles,
  formActionError,
  isPendingFileValue,
  uploadPendingFiles,
  type FormFieldValue,
} from "@/components/forms/FormFields";
import { DisplayBlock, isYesNoField, localizedField } from "@/components/forms/FormBlocks";
import { isEmptyAnswer, visibleFieldIds } from "@/lib/formConditions";
import { formLabel } from "@/lib/formLabelsFr";
import { useLocale } from "@/lib/i18n";
import { availableToday, formatMessage, isDisplayBlock, parentMaySee, requiredMessage, storedDate, type ParentFormTemplate } from "@/lib/parentForms";
import { loadFormTemplate, parentBuiltIns, submitParentForm } from "@/lib/parentFormsData";
import { parentFormsText } from "@/lib/parentFormsText";
import { PARENT_ROUTES } from "@/lib/parentWeb";

type Load = { state: "loading" } | { state: "missing" } | { state: "locked" } | { state: "error" } | { state: "ready"; form: ParentFormTemplate };

/**
 * Filling in one form (FormScreen, B-134…B-140): the form's title,
 * description and questions, "show only if" rules, the app's checks, and a
 * submission that writes the same form_responses document the app writes.
 * After a successful send the page closes itself, as the app's does.
 */
export default function ParentFormFillPage() {
  const session = useParentSession();
  const fr = useLocale() === "fr";
  const text = parentFormsText(fr);
  const builtIns = useMemo(() => parentBuiltIns(text), [text]);
  const id = useSearchParams().get("id") ?? "";
  const [load, setLoad] = useState<Load>({ state: "loading" });
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    let active = true;
    setLoad({ state: "loading" });
    loadFormTemplate(id, builtIns)
      .then((form) => {
        if (!active) return;
        if (!form || !parentMaySee(form)) return setLoad({ state: "missing" });
        if (!availableToday(form.frequency, new Date())) return setLoad({ state: "locked" });
        setLoad({ state: "ready", form });
      })
      .catch(() => active && setLoad({ state: "error" }));
    return () => {
      active = false;
    };
  }, [id, builtIns, attempt]);

  const title = load.state === "ready" ? load.form.name : text.formsTitle;
  return (
    <div className="min-h-screen bg-[#F0EBF8]">
      <ParentAppBar title={title} backHref={PARENT_ROUTES.forms} backLabel="Back" />
      <div className="mx-auto w-full max-w-[800px] px-4 py-5">
        {load.state === "loading" ? <ParentSpinner padding={48} label="Loading" /> : null}
        {load.state === "error" ? <ParentErrorCard message="Could not load this form. Check your connection and try again." onRetry={() => setAttempt((n) => n + 1)} retryLabel={text.tryAgain} /> : null}
        {load.state === "missing" ? <ParentErrorCard message="This form is no longer available." /> : null}
        {load.state === "locked" ? <ParentErrorCard message="This form can only be filled in at certain times. Check back when it opens." /> : null}
        {load.state === "ready" ? <FormBody key={load.form.id} form={load.form} uid={session.uid} fr={fr} requiredWord={text.required} /> : null}
      </div>
    </div>
  );
}

function FormBody({ form, uid, fr, requiredWord }: { form: ParentFormTemplate; uid: string; fr: boolean; requiredWord: string }) {
  const router = useRouter();
  const [values, setValues] = useState<Record<string, FormFieldValue>>({});
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [submitting, setSubmitting] = useState(false);
  const [failure, setFailure] = useState("");
  const previews = useRef<Set<string>>(new Set());

  const shown = useMemo(() => visibleFieldIds(form.fields, values), [form.fields, values]);
  const shownFields = form.fields.filter((field) => shown.has(field.id));

  useEffect(() => {
    const urls = previews.current;
    return () => urls.forEach((url) => URL.revokeObjectURL(url));
  }, []);

  const setValue = (fieldId: string, value: FormFieldValue) => {
    setValues((current) => {
      const previous = current[fieldId];
      if (isPendingFileValue(previous)) URL.revokeObjectURL(previous.previewUrl);
      if (isPendingFileValue(value)) previews.current.add(value.previewUrl);
      return { ...current, [fieldId]: value };
    });
    setErrors((current) => {
      if (!current[fieldId]) return current;
      const next = { ...current };
      delete next[fieldId];
      return next;
    });
  };

  const validate = () => {
    const next: Record<string, string> = {};
    for (const field of shownFields) {
      if (isDisplayBlock(field.type)) continue;
      const value = values[field.id];
      if (field.required && isEmptyAnswer(value)) {
        const message = requiredMessage({ ...field, label: formLabel(field.label, fr) });
        if (message) next[field.id] = message;
        continue;
      }
      if (typeof value === "string") {
        const message = formatMessage(field.type, value);
        if (message) next[field.id] = message;
      }
    }
    return next;
  };

  const submit = async () => {
    const nextErrors = validate();
    setErrors(nextErrors);
    if (Object.keys(nextErrors).length > 0) {
      document.getElementById(`field-${Object.keys(nextErrors)[0]}`)?.scrollIntoView({ behavior: "smooth", block: "center" });
      return;
    }
    setSubmitting(true);
    setFailure("");
    let uploaded: string[] = [];
    try {
      // Hidden questions and display blocks are left out of the answers.
      const answerable = shownFields.filter((field) => !isDisplayBlock(field.type));
      const raw: Record<string, FormFieldValue> = {};
      const yesNo: Record<string, boolean> = {};
      for (const field of answerable) {
        const value = values[field.id];
        // The app stores every question on screen, an unanswered one as "".
        if (value === undefined || (Array.isArray(value) && value.length === 0)) raw[field.id] = "";
        else if (isYesNoField(field) && typeof value === "string") yesNo[field.id] = value === "Yes";
        else raw[field.id] = field.type === "date" && typeof value === "string" ? storedDate(value) : value;
      }
      const result = await uploadPendingFiles(raw, uid);
      uploaded = result.storagePaths;
      // Answered Yes/No questions are stored as true / false, as the app does.
      const responses = { ...result.values, ...yesNo };
      await submitParentForm({ form, uid, email: auth.currentUser?.email ?? null, responses });
      router.replace(`${PARENT_ROUTES.forms}?submitted=1`);
    } catch (error) {
      if (uploaded.length) await cleanupUploadedFiles(uploaded);
      setFailure(formActionError(error, "Could not submit this form. Try again."));
      setSubmitting(false);
    }
  };

  return (
    <>
      <section className="overflow-hidden rounded-lg bg-white shadow-[0_1px_2px_rgba(15,23,42,0.06)]">
        <div className="h-2.5 bg-[#673AB7]" />
        <div className="flex gap-4 p-6">
          <span className="grid h-12 w-12 shrink-0 place-items-center rounded-xl bg-[#673AB7]/10 text-[#673AB7]">
            <FileText size={24} />
          </span>
          <div className="min-w-0">
            <h2 className="text-[28px] font-normal leading-tight text-[#202124] max-[700px]:text-2xl">{formLabel(form.name, fr)}</h2>
            {form.description ? <p className="mt-2 whitespace-pre-line text-sm leading-6 text-[#5F6368]">{formLabel(form.description, fr)}</p> : null}
          </div>
        </div>
      </section>

      <div className="mt-4">
        {shownFields.map((field) =>
          isDisplayBlock(field.type) ? (
            <DisplayBlock key={field.id} field={field} fr={fr} />
          ) : (
            <div key={field.id} id={`field-${field.id}`}>
              <FormQuestionCard
                field={localizedField(field, fr)}
                value={values[field.id]}
                error={errors[field.id]}
                onChange={(value) => setValue(field.id, value)}
              />
            </div>
          ),
        )}
      </div>

      <section className="mb-10 mt-2 rounded-lg bg-white p-6 shadow-[0_1px_2px_rgba(15,23,42,0.06)]">
        {failure ? <p role="alert" className="mb-4 rounded-lg bg-red-50 px-4 py-3 text-sm font-semibold text-red-700">{failure}</p> : null}
        <p className="mb-4 text-xs text-[#5F6368]">
          <span className="text-red-600">*</span> {requiredWord}
        </p>
        <button
          type="button"
          onClick={() => void submit()}
          disabled={submitting}
          className="inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-lg bg-[#673AB7] px-6 text-sm font-bold text-white disabled:cursor-not-allowed disabled:opacity-60"
        >
          {submitting ? <Loader2 size={18} className="animate-spin" /> : <Send size={18} />}
          Submit Form
        </button>
      </section>
    </>
  );
}
