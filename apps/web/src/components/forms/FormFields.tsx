"use client";

/**
 * The question cards, inputs and file handling every "fill in a form" page
 * shares (teachers, students), so a form looks and submits the same whoever
 * opens it.
 */
import { useState } from "react";
import { serverTimestamp } from "firebase/firestore";
import { deleteObject, getDownloadURL, ref, uploadBytes } from "firebase/storage";
import { AlertCircle, Check, Image as ImageIcon, PenLine, Trash2, Upload } from "lucide-react";
import { storage } from "@/lib/firebase";
import { tr } from "@/lib/i18n";
import { storedOrder } from "@/lib/formAnswerOrder";
import { missingRequiredFieldIds } from "@/lib/formConditions";

export type FieldType =
  | "text"
  | "email"
  | "phone"
  | "long_text"
  | "multiline"
  | "description"
  | "dropdown"
  | "select"
  | "multi_select"
  | "radio"
  | "number"
  | "date"
  | "time"
  | "boolean"
  | "yes_no"
  | "yesNo"
  | "image_upload"
  | "imageUpload"
  | "signature";

export type FileFieldKind = "image" | "signature";

export type PendingFileValue = {
  kind: "pendingFile";
  fieldType: FileFieldKind;
  file: File;
  fileName: string;
  size: number;
  contentType: string;
  previewUrl: string;
};

export type UploadedFileValue = {
  fileName: string;
  downloadURL: string;
  url: string;
  storagePath: string;
  size: number;
  contentType: string;
  type: FileFieldKind;
  uploadedAt: ReturnType<typeof serverTimestamp>;
};

export type FormFieldValue = string | string[] | PendingFileValue | UploadedFileValue;

export type SubmittedFieldValue = string | string[] | UploadedFileValue | Record<string, unknown>;

export type TemplateField = {
  id: string;
  label: string;
  type: FieldType;
  placeholder: string;
  required: boolean;
  order: number;
  options: string[];
  conditionalLogic?: unknown;
};

export function FormQuestionCard({ field, value, error, onChange }: { field: TemplateField; value: FormFieldValue | undefined; error?: string; onChange: (value: FormFieldValue) => void }) {
  return (
    <section className="mb-4 rounded-lg bg-white p-6 shadow-[0_1px_2px_rgba(15,23,42,0.06)] focus-within:border-l-4 focus-within:border-[#0386FF] max-[700px]:p-5">
      <label className="block text-base font-medium text-black/85">
        {field.label}
        {field.required ? <span className="ml-1 text-red-600">*</span> : null}
      </label>
      <div className="mt-4">{renderFieldInput(field, value, onChange)}</div>
      {error ? (
        <p className="mt-3 inline-flex items-center gap-1 text-xs font-semibold text-red-600">
          <AlertCircle size={14} />
          {error}
        </p>
      ) : null}
    </section>
  );
}

function renderFieldInput(field: TemplateField, value: FormFieldValue | undefined, onChange: (value: FormFieldValue) => void) {
  const current = Array.isArray(value) ? value.join(", ") : typeof value === "string" ? value : "";
  const inputClasses = "w-full rounded-xl border border-[#E5E7EB] bg-[#F9FAFB] px-4 py-3 text-sm text-[#111827] outline-none placeholder:text-[#9CA3AF] focus:border-[#0386FF]";
  if (field.type === "long_text" || field.type === "multiline" || field.type === "description") {
    return <textarea aria-label={field.label} value={current} onChange={(event) => onChange(event.target.value)} placeholder={field.placeholder || "Your answer"} rows={4} className={`${inputClasses} min-h-[120px] resize-y leading-6`} />;
  }
  if (field.type === "dropdown" || field.type === "select") {
    return (
      <select aria-label={field.label} value={current} onChange={(event) => onChange(event.target.value)} className={inputClasses}>
        <option value="">{field.placeholder || "Select an option"}</option>
        {field.options.map((option) => (
          <option key={option} value={option}>
            {option}
          </option>
        ))}
      </select>
    );
  }
  if (field.type === "radio" && field.options.length > 0) {
    return (
      <div className="max-h-[220px] overflow-y-auto rounded-xl border border-[#E5E7EB] bg-[#F9FAFB] p-3">
        {field.options.map((option) => (
          <label key={option} className="flex cursor-pointer items-center gap-3 rounded-lg px-2 py-2 text-sm text-[#111827] hover:bg-white">
            <input aria-label={`${field.label}: ${option}`} type="radio" name={field.id} value={option} checked={current === option} onChange={() => onChange(option)} className="h-4 w-4 accent-[#0386FF]" />
            <span>{option}</span>
          </label>
        ))}
      </div>
    );
  }
  if (field.type === "multi_select") {
    const selected = Array.isArray(value) ? value : [];
    return (
      <div className="rounded-xl border border-[#E5E7EB] bg-[#F9FAFB] p-3">
        {field.options.map((option) => (
          <label key={option} className="flex cursor-pointer items-center gap-3 rounded-lg px-2 py-2 text-sm text-[#111827] hover:bg-white">
            <input
              type="checkbox"
              aria-label={`${field.label}: ${option}`}
              checked={selected.includes(option)}
              onChange={(event) => onChange(event.target.checked ? [...selected, option] : selected.filter((item) => item !== option))}
              className="h-4 w-4 rounded accent-[#0386FF]"
            />
            <span>{option}</span>
          </label>
        ))}
      </div>
    );
  }
  if (field.type === "radio" || field.type === "boolean" || field.type === "yes_no" || field.type === "yesNo") {
    return (
      <div className="flex gap-6 rounded-xl border border-[#E5E7EB] bg-[#F9FAFB] p-4">
        {["Yes", "No"].map((option) => (
          <label key={option} className="flex cursor-pointer items-center gap-2 text-sm text-[#111827]">
            <input aria-label={`${field.label}: ${option}`} type="radio" name={field.id} value={option} checked={current === option} onChange={() => onChange(option)} className="h-4 w-4 accent-[#0386FF]" />
            {option}
          </label>
        ))}
      </div>
    );
  }
  if (field.type === "image_upload" || field.type === "imageUpload" || field.type === "signature") {
    return <FileFieldInput field={field} value={value} onChange={onChange} />;
  }
  return <input aria-label={field.label} value={current} type={htmlInputType(field.type)} onChange={(event) => onChange(event.target.value)} placeholder={field.placeholder || "Your answer"} className={inputClasses} />;
}

function FileFieldInput({ field, value, onChange }: { field: TemplateField; value: FormFieldValue | undefined; onChange: (value: FormFieldValue) => void }) {
  const kind: FileFieldKind = field.type === "signature" ? "signature" : "image";
  const [fileError, setFileError] = useState("");
  const pending = isPendingFileValue(value) ? value : null;
  const uploaded = isUploadedFileValue(value) ? value : null;
  const selectedFileName = pending?.fileName ?? uploaded?.fileName ?? "";
  const selectedSize = pending?.size ?? uploaded?.size ?? 0;
  const maxBytes = kind === "signature" ? 5 * 1024 * 1024 : 10 * 1024 * 1024;
  const Icon = kind === "signature" ? PenLine : ImageIcon;

  const onFileSelected = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) return;
    if (file.size > maxBytes) {
      setFileError(kind === "signature" ? "Signature file size must be less than 5MB." : "File size must be less than 10MB.");
      return;
    }
    if (!file.type.startsWith("image/")) {
      setFileError("Please choose an image file.");
      return;
    }
    setFileError("");
    onChange({
      kind: "pendingFile",
      fieldType: kind,
      file,
      fileName: file.name,
      size: file.size,
      contentType: file.type || contentTypeForFileName(file.name),
      previewUrl: URL.createObjectURL(file),
    });
  };

  if (pending || uploaded) {
    return (
      <div className="space-y-3">
        <div className={`relative grid ${kind === "signature" ? "h-[120px]" : "min-h-[180px]"} place-items-center overflow-hidden rounded-xl border-2 border-[#0386FF] bg-white`}>
          {pending ? <img src={pending.previewUrl} alt="" className="h-full w-full object-contain" /> : <Icon size={36} className="text-[#0386FF]" />}
          <button
            type="button"
            onClick={() => {
              setFileError("");
              onChange("");
            }}
            aria-label={`Remove ${field.label}`}
            className="absolute right-2 top-2 grid h-8 w-8 place-items-center rounded-full bg-[#EF4444] text-white shadow-sm"
          >
            <Trash2 size={16} />
          </button>
        </div>
        <div className="flex items-center gap-3 rounded-lg border border-green-200 bg-green-50 p-3">
          <Check size={20} className="shrink-0 text-green-600" />
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-semibold text-[#111827]">{kind === "signature" ? tr("Signature captured") : selectedFileName}</p>
            <p className="text-xs text-[#6B7280]">{formatFileSize(selectedSize)}</p>
          </div>
          <label className="cursor-pointer rounded-lg px-3 py-2 text-xs font-bold text-[#0386FF] hover:bg-white">
            {tr("Change")}
            <input type="file" accept="image/*" onChange={onFileSelected} className="sr-only" aria-label={`Change ${field.label}`} />
          </label>
        </div>
        {fileError ? <p className="rounded-lg bg-[#FEF2F2] px-3 py-2 text-sm font-semibold text-[#DC2626]">{fileError}</p> : null}
      </div>
    );
  }

  return (
    <div className="space-y-2">
      <label className={`grid w-full cursor-pointer place-items-center rounded-xl border border-[#E5E7EB] bg-[#F9FAFB] p-6 text-center ${kind === "signature" ? "min-h-[120px]" : "min-h-[180px]"}`}>
        <span className={`grid rounded-full ${kind === "signature" ? "bg-[#9B51E0]/10 p-3 text-[#9B51E0]" : "bg-[#0386FF]/10 p-4 text-[#0386FF]"}`}>
          {kind === "signature" ? <PenLine size={24} /> : <Upload size={32} />}
        </span>
        <span className="mt-3 block text-sm font-bold text-[#111827]">{kind === "signature" ? tr("Click to add signature") : tr("Click to upload image")}</span>
        <span className="mt-1 block text-xs text-[#6B7280]">{kind === "signature" ? tr("Upload image or use signature pad") : tr("JPG, PNG, GIF up to 10MB")}</span>
        <input type="file" accept="image/*" onChange={onFileSelected} className="sr-only" aria-label={field.label} />
      </label>
      {fileError ? <p className="rounded-lg bg-[#FEF2F2] px-3 py-2 text-sm font-semibold text-[#DC2626]">{fileError}</p> : null}
    </div>
  );
}

function htmlInputType(type: FieldType) {
  if (type === "number") return "number";
  if (type === "date") return "date";
  if (type === "time") return "time";
  if (type === "email") return "email";
  if (type === "phone") return "tel";
  return "text";
}

export function isPendingFileValue(value: unknown): value is PendingFileValue {
  return Boolean(value && typeof value === "object" && (value as PendingFileValue).kind === "pendingFile" && (value as PendingFileValue).file instanceof File);
}

export function isUploadedFileValue(value: unknown): value is UploadedFileValue {
  return Boolean(value && typeof value === "object" && stringValue((value as Record<string, unknown>).downloadURL) && stringValue((value as Record<string, unknown>).fileName));
}

export function isEmptyFormValue(value: FormFieldValue | undefined) {
  if (Array.isArray(value)) return value.length === 0;
  if (isPendingFileValue(value) || isUploadedFileValue(value)) return false;
  return !String(value ?? "").trim();
}

export async function uploadPendingFiles(values: Record<string, FormFieldValue>, uid: string) {
  const uploaded: Record<string, SubmittedFieldValue> = {};
  const storagePaths: string[] = [];
  try {
    for (const [fieldId, value] of Object.entries(values)) {
      if (!isPendingFileValue(value)) {
        uploaded[fieldId] = value as SubmittedFieldValue;
        continue;
      }
      const safeName = safeStorageFileName(value.fileName);
      const storagePath = `form_images/${uid}/${Date.now()}_${safeName}`;
      const storageRef = ref(storage, storagePath);
      const snapshot = await uploadBytes(storageRef, value.file, {
        contentType: value.contentType || contentTypeForFileName(value.fileName),
        customMetadata: {
          uploadedBy: uid,
          originalFileName: value.fileName,
        },
      });
      storagePaths.push(storagePath);
      const downloadURL = await getDownloadURL(snapshot.ref);
      uploaded[fieldId] = {
        fileName: value.fileName,
        downloadURL,
        url: downloadURL,
        storagePath,
        size: value.size,
        contentType: value.contentType || contentTypeForFileName(value.fileName),
        type: value.fieldType,
        uploadedAt: serverTimestamp(),
      };
    }
    return { values: uploaded, storagePaths };
  } catch (error) {
    await cleanupUploadedFiles(storagePaths);
    throw error;
  }
}

export async function cleanupUploadedFiles(storagePaths: string[]) {
  await Promise.allSettled(storagePaths.map((storagePath) => deleteObject(ref(storage, storagePath))));
}

export function formActionError(error: unknown, fallback: string) {
  const message = error instanceof Error ? error.message : String(error || "");
  if (/permission-denied|insufficient permissions/i.test(message)) return "You do not have permission to submit this form. Contact an administrator if this continues.";
  if (/unavailable|network|offline/i.test(message) || !navigator.onLine) return "You appear to be offline. Reconnect and try again.";
  return message.replace(/^Firebase:\s*/i, "").trim() || fallback;
}

function safeStorageFileName(fileName: string) {
  const trimmed = fileName.trim() || "upload.jpg";
  return trimmed.replace(/[^a-zA-Z0-9._-]+/g, "_").slice(0, 120);
}

function contentTypeForFileName(fileName: string) {
  const extension = fileName.toLowerCase().split(".").pop();
  if (extension === "png") return "image/png";
  if (extension === "gif") return "image/gif";
  if (extension === "webp") return "image/webp";
  return "image/jpeg";
}

function formatFileSize(bytes: number) {
  if (!Number.isFinite(bytes) || bytes <= 0) return "0 B";
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export function field(id: string, label: string, type: FieldType, order: number, required = false, placeholder = "", options: string[] = []): TemplateField {
  return { id, label, type, order, required, placeholder, options };
}

export function normalizeFields(value: unknown): TemplateField[] {
  const entries: Array<[string, unknown]> = Array.isArray(value)
    ? value.map((item, index) => [stringValue((item as Record<string, unknown>)?.id) || `field_${index}`, item])
    : value && typeof value === "object"
      ? Object.entries(value as Record<string, unknown>)
      : [];

  return entries
    .map(([id, item], index) => {
      const data = item && typeof item === "object" ? (item as Record<string, unknown>) : {};
      const normalized = field(
        id,
        stringValue(data.label) || stringValue(data.name) || "Untitled Field",
        normalizeFieldType(stringValue(data.type)),
        storedOrder(data.order) ?? index,
        data.required === true,
        stringValue(data.placeholder),
        stringArray(data.options),
      );
      if (data.conditionalLogic !== undefined && data.conditionalLogic !== null) normalized.conditionalLogic = data.conditionalLogic;
      return normalized;
    })
    .sort((a, b) => a.order - b.order);
}

function normalizeFieldType(value: string): FieldType {
  if (value === "email" || value === "phone") return value;
  if (value === "long_text" || value === "multiline" || value === "description") return value;
  if (value === "dropdown" || value === "select") return value;
  if (value === "multi_select") return value;
  if (value === "radio") return "radio";
  if (value === "number") return "number";
  if (value === "date") return "date";
  if (value === "time") return "time";
  if (value === "boolean" || value === "yes_no" || value === "yesNo") return value;
  if (value === "image_upload" || value === "imageUpload" || value === "signature") return value;
  return "text";
}

export function stringArray(value: unknown) {
  if (Array.isArray(value)) return value.map((item) => String(item ?? "").trim()).filter(Boolean);
  if (value && typeof value === "object") return Object.values(value).map((item) => String(item ?? "").trim()).filter(Boolean);
  return [];
}

export function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

/**
 * What is wrong with the answers to the questions on screen, keyed by field
 * id: a required question left empty, or a malformed email / phone number.
 */
export function formFieldErrors(fields: TemplateField[], shownFields: TemplateField[], values: Record<string, FormFieldValue>) {
  const errors: Record<string, string> = {};
  const missingRequired = new Set(missingRequiredFieldIds(fields, values));
  shownFields.forEach((item) => {
    const value = values[item.id];
    const empty = isEmptyFormValue(value);
    if (missingRequired.has(item.id)) errors[item.id] = "This question is required";
    if (!empty && item.type === "email" && typeof value === "string" && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(value.trim())) {
      errors[item.id] = "Please enter a valid email address";
    }
    if (!empty && item.type === "phone" && typeof value === "string" && !/^\+?[\d\s-]+$/.test(value.trim())) {
      errors[item.id] = "Please enter a valid phone number";
    }
  });
  return errors;
}
