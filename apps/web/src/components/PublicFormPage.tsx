"use client";

import { useSearchParams } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { CheckCircle2, FileText, Loader2, Lock, Paperclip, Send } from "lucide-react";
import { auth, ensureAuthPersistence } from "@/lib/firebase";
import { flutterLoginUrl } from "@/lib/flutterApp";
import { formLabel } from "@/lib/formLabelsFr";
import { isEmptyAnswer, visibleFieldIds } from "@/lib/formConditions";
import { useLocale } from "@/lib/localeStore";
import { formatMessage, isDisplayBlock, templateFromDoc, type ParentFormField, type ParentFormTemplate } from "@/lib/parentForms";
import { cleanSubmitterName, cleanSubmitterPhone, isFileField, memberFillPath, publicAnswers, publicSubmitError } from "@/lib/publicForms";
import { fetchPublicForm, sendPublicFormResponse } from "@/lib/publicFormsData";
import { usePublicT } from "@/lib/publicI18n";
import { dashboardPathForUser } from "@/lib/userRoles";
import { LanguageSwitch } from "@/components/LanguageSwitch";
import { DisplayBlock, localizedField } from "@/components/forms/FormBlocks";
import { FormQuestionCard, type FormFieldValue, type TemplateField } from "@/components/forms/FormFields";

type View =
  | { state: "loading" }
  | { state: "error" }
  | { state: "missing" }
  | { state: "redirecting" }
  | { state: "members"; title: string }
  | { state: "notShared"; title: string; dashboard: string }
  | { state: "ready"; form: ParentFormTemplate };

type T = ReturnType<typeof usePublicT>;

/**
 * A form opened from its shared link (/form/?id=<templateId>).
 *
 * Signed-in members go to their own role's form page when it lists the form.
 * Anyone else fills it in here when an admin opened the form to anyone with
 * the link: name and phone first, then the form's questions, sent through the
 * submitPublicFormResponse callable. A members-only form asks them to sign in.
 */
export function PublicFormPage() {
  const t = usePublicT();
  const id = (useSearchParams().get("id") ?? "").trim();
  const [view, setView] = useState<View>({ state: "loading" });
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    let active = true;
    setView({ state: "loading" });
    if (!id) {
      setView({ state: "missing" });
      return;
    }
    (async () => {
      // The session is the one the Flutter app keeps; read it the same way.
      const member = ensureAuthPersistence()
        .then(() => auth.authStateReady())
        .then(() => auth.currentUser)
        .catch(() => null);
      const info = await fetchPublicForm(id);
      if (!active) return;
      if (!info.found || !info.id) return setView({ state: "missing" });
      const title = info.title || "";
      const user = await member;
      if (!active) return;
      if (user) {
        const dashboard = await dashboardPathForUser(user).catch(() => "/app/");
        if (!active) return;
        const target = memberFillPath(dashboard, info);
        if (target) {
          setView({ state: "redirecting" });
          window.location.replace(target);
          return;
        }
        if (!info.available) return setView({ state: "notShared", title, dashboard });
      } else if (!info.available) {
        return setView({ state: "members", title });
      }
      const form = templateFromDoc(info.id, { name: title, description: info.description ?? "", fields: info.fields ?? [] });
      setView({ state: "ready", form });
    })().catch(() => active && setView({ state: "error" }));
    return () => {
      active = false;
    };
  }, [id, attempt]);

  return (
    <main className="min-h-screen bg-[#F0EBF8] text-[#202124]">
      <header className="bg-white shadow-[0_1px_2px_rgba(15,23,42,0.06)]">
        <div className="mx-auto flex w-full max-w-[800px] items-center justify-between gap-3 px-4 py-3">
          <a href="/" className="flex min-w-0 items-center gap-2">
            <img src="/assets/Alluwal_Education_Hub_Logo.png" alt="" className="h-9 w-9 shrink-0 object-contain" />
            <span className="truncate text-sm font-bold text-[#001E4E]">Alluwal Education Hub</span>
          </a>
          <LanguageSwitch />
        </div>
      </header>
      <div className="mx-auto w-full max-w-[800px] px-4 py-5">
        {view.state === "loading" || view.state === "redirecting" ? <Spinner label={view.state === "loading" ? t("Loading the form…") : t("Opening your form…")} /> : null}
        {view.state === "error" ? (
          <Notice message={t("Could not load this form. Check your connection and try again.")}>
            <button type="button" onClick={() => setAttempt((n) => n + 1)} className={buttonClass}>
              {t("Try again")}
            </button>
          </Notice>
        ) : null}
        {view.state === "missing" ? <Notice message={t("This form is no longer available.")} /> : null}
        {view.state === "members" ? (
          <Notice title={view.title} message={t("This form is for Alluwal members.")} icon>
            <a href={flutterLoginUrl} className={buttonClass}>
              {t("Sign in to fill in this form")}
            </a>
          </Notice>
        ) : null}
        {view.state === "notShared" ? (
          <Notice title={view.title} message={view.dashboard === "/app/" ? t("Open this form from your dashboard.") : t("This form isn't shared with your account.")} icon>
            <a href={view.dashboard} className={buttonClass}>
              {t("Go to my dashboard")}
            </a>
          </Notice>
        ) : null}
        {view.state === "ready" ? <PublicFormBody key={view.form.id} form={view.form} t={t} /> : null}
      </div>
    </main>
  );
}

const buttonClass = "inline-flex min-h-11 items-center justify-center rounded-lg bg-[#673AB7] px-5 text-sm font-bold text-white hover:bg-[#5E35B1]";

function Spinner({ label }: { label: string }) {
  return (
    <div className="grid place-items-center gap-3 py-16 text-[#5F6368]">
      <Loader2 size={28} className="animate-spin text-[#673AB7]" />
      <p className="text-sm">{label}</p>
    </div>
  );
}

function Notice({ title, message, icon, children }: { title?: string; message: string; icon?: boolean; children?: React.ReactNode }) {
  return (
    <section className="overflow-hidden rounded-lg bg-white shadow-[0_1px_2px_rgba(15,23,42,0.06)]">
      <div className="h-2.5 bg-[#673AB7]" />
      <div className="grid justify-items-center gap-4 px-6 py-10 text-center">
        {icon ? (
          <span className="grid h-12 w-12 place-items-center rounded-xl bg-[#673AB7]/10 text-[#673AB7]">
            <Lock size={22} />
          </span>
        ) : null}
        {title ? <h1 className="text-2xl font-normal leading-tight">{title}</h1> : null}
        <p className="max-w-[460px] text-sm leading-6 text-[#5F6368]">{message}</p>
        {children}
      </div>
    </section>
  );
}

const NAME_ID = "__submitter_name";
const PHONE_ID = "__submitter_phone";

function PublicFormBody({ form, t }: { form: ParentFormTemplate; t: T }) {
  const fr = useLocale() === "fr";
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [values, setValues] = useState<Record<string, FormFieldValue>>({});
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [submitting, setSubmitting] = useState(false);
  const [failure, setFailure] = useState("");
  const [sent, setSent] = useState(false);

  const shown = useMemo(() => visibleFieldIds(form.fields, values), [form.fields, values]);
  const shownFields = form.fields.filter((field) => shown.has(field.id));

  const clearError = (fieldId: string) =>
    setErrors((current) => {
      if (!current[fieldId]) return current;
      const next = { ...current };
      delete next[fieldId];
      return next;
    });

  const validate = () => {
    const next: Record<string, string> = {};
    if (!cleanSubmitterName(name)) next[NAME_ID] = t("Enter your full name.");
    if (!cleanSubmitterPhone(phone)) next[PHONE_ID] = t("Enter a valid phone or WhatsApp number.");
    for (const field of shownFields) {
      if (isDisplayBlock(field.type) || isFileField(field.type)) continue;
      const value = values[field.id];
      if (field.required && isEmptyAnswer(value)) {
        next[field.id] = t("This question is required");
        continue;
      }
      if (typeof value === "string") {
        const message = formatMessage(field.type, value);
        if (message) next[field.id] = t(message);
      }
    }
    return next;
  };

  const submit = async () => {
    const nextErrors = validate();
    setErrors(nextErrors);
    const first = Object.keys(nextErrors)[0];
    if (first) {
      document.getElementById(`field-${first}`)?.scrollIntoView({ behavior: "smooth", block: "center" });
      return;
    }
    setSubmitting(true);
    setFailure("");
    try {
      await sendPublicFormResponse({
        id: form.id,
        name: cleanSubmitterName(name) ?? name,
        phone: cleanSubmitterPhone(phone) ?? phone,
        responses: publicAnswers(form.fields, shown, values),
      });
      setSent(true);
      window.scrollTo({ top: 0, behavior: "smooth" });
    } catch (error) {
      setFailure(t(publicSubmitError(error)));
    } finally {
      setSubmitting(false);
    }
  };

  if (sent) {
    return (
      <section className="overflow-hidden rounded-lg bg-white shadow-[0_1px_2px_rgba(15,23,42,0.06)]">
        <div className="h-2.5 bg-[#673AB7]" />
        <div role="status" className="grid justify-items-center gap-3 px-6 py-10 text-center">
          <span className="grid h-14 w-14 place-items-center rounded-full bg-green-50 text-green-600">
            <CheckCircle2 size={32} />
          </span>
          <h1 className="text-2xl font-normal leading-tight">{t("Thank you!")}</h1>
          <p className="max-w-[460px] text-sm leading-6 text-[#5F6368]">{t("Your answers have been sent to Alluwal Education Hub.")}</p>
          <p className="text-sm font-semibold text-[#202124]">{formLabel(form.name, fr)}</p>
          <button
            type="button"
            onClick={() => {
              setValues({});
              setErrors({});
              setSent(false);
            }}
            className="mt-2 text-sm font-semibold text-[#673AB7] underline"
          >
            {t("Fill it in again")}
          </button>
        </div>
      </section>
    );
  }

  return (
    <>
      <section className="overflow-hidden rounded-lg bg-white shadow-[0_1px_2px_rgba(15,23,42,0.06)]">
        <div className="h-2.5 bg-[#673AB7]" />
        <div className="flex gap-4 p-6">
          <span className="grid h-12 w-12 shrink-0 place-items-center rounded-xl bg-[#673AB7]/10 text-[#673AB7]">
            <FileText size={24} />
          </span>
          <div className="min-w-0">
            <h1 className="text-[28px] font-normal leading-tight max-[700px]:text-2xl">{formLabel(form.name, fr)}</h1>
            {form.description ? <p className="mt-2 whitespace-pre-line text-sm leading-6 text-[#5F6368]">{formLabel(form.description, fr)}</p> : null}
          </div>
        </div>
      </section>

      <div className="mt-4">
        <div id={`field-${NAME_ID}`}>
          <FormQuestionCard
            field={contactField(NAME_ID, t("Your full name"), "text", t)}
            value={name}
            error={errors[NAME_ID]}
            onChange={(value) => {
              setName(typeof value === "string" ? value : "");
              clearError(NAME_ID);
            }}
          />
        </div>
        <div id={`field-${PHONE_ID}`}>
          <FormQuestionCard
            field={contactField(PHONE_ID, t("Phone / WhatsApp number"), "phone", t)}
            value={phone}
            error={errors[PHONE_ID]}
            onChange={(value) => {
              setPhone(typeof value === "string" ? value : "");
              clearError(PHONE_ID);
            }}
          />
        </div>

        {shownFields.map((field) =>
          isDisplayBlock(field.type) ? (
            <DisplayBlock key={field.id} field={field} fr={fr} />
          ) : isFileField(field.type) ? (
            <FileQuestion key={field.id} field={field} fr={fr} t={t} />
          ) : (
            <div key={field.id} id={`field-${field.id}`}>
              <FormQuestionCard
                field={withPlaceholder(localizedField(field, fr), t)}
                value={values[field.id]}
                error={errors[field.id]}
                onChange={(value) => {
                  setValues((current) => ({ ...current, [field.id]: value }));
                  clearError(field.id);
                }}
              />
            </div>
          ),
        )}
      </div>

      <section className="mb-10 mt-2 rounded-lg bg-white p-6 shadow-[0_1px_2px_rgba(15,23,42,0.06)]">
        {failure ? (
          <p role="alert" className="mb-4 rounded-lg bg-red-50 px-4 py-3 text-sm font-semibold text-red-700">
            {failure}
          </p>
        ) : null}
        <p className="mb-4 text-xs text-[#5F6368]">
          <span className="text-red-600">*</span> {t("Required")}
        </p>
        <button
          type="button"
          onClick={() => void submit()}
          disabled={submitting}
          className="inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-lg bg-[#673AB7] px-6 text-sm font-bold text-white disabled:cursor-not-allowed disabled:opacity-60"
        >
          {submitting ? <Loader2 size={18} className="animate-spin" /> : <Send size={18} />}
          {submitting ? t("Sending…") : t("Send")}
        </button>
      </section>
    </>
  );
}

function contactField(id: string, label: string, type: "text" | "phone", t: T): TemplateField {
  return { id, label, type, placeholder: t("Your answer"), required: true, order: 0, options: [] };
}

/** The form's own hint when it has one, the generic one in the reader's language otherwise. */
function withPlaceholder(field: TemplateField, t: T): TemplateField {
  if (field.placeholder) return field;
  const choice = field.type === "dropdown" || field.type === "select";
  return { ...field, placeholder: choice ? t("Select an option") : t("Your answer") };
}

/** A file question, shown so the form reads as written, with no way to attach a file here. */
function FileQuestion({ field, fr, t }: { field: ParentFormField; fr: boolean; t: T }) {
  return (
    <section className="mb-4 rounded-lg bg-white p-6 shadow-[0_1px_2px_rgba(15,23,42,0.06)] max-[700px]:p-5">
      <p className="text-base font-medium text-black/85">{formLabel(field.label, fr)}</p>
      <div aria-disabled="true" className="mt-4 flex items-center gap-3 rounded-xl border border-dashed border-[#D1D5DB] bg-[#F3F4F6] px-4 py-4 text-sm text-[#6B7280]">
        <Paperclip size={18} className="shrink-0" />
        {t("Files can't be attached on this page.")}
      </div>
    </section>
  );
}
