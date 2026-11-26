"use client";

/**
 * Pieces of a filled-in form shared by the parent form page and form links:
 * display blocks (headings, sections, images, videos) and a question in the
 * reader's language.
 */
import type { FieldType, TemplateField } from "@/components/forms/FormFields";
import { formLabel } from "@/lib/formLabelsFr";
import type { ParentFormField } from "@/lib/parentForms";

/** Yes/No questions (and a radio with no options) — the app stores true / false. */
export function isYesNoField(field: ParentFormField) {
  return field.type === "boolean" || field.type === "yes_no" || field.type === "yesNo" || (field.type === "radio" && field.options.length === 0);
}

/** The question as the parent reads it: label, hint and options in their language (FormLocalization). */
export function localizedField(field: ParentFormField, fr: boolean): TemplateField {
  return {
    id: field.id,
    label: formLabel(field.label, fr),
    type: field.type as FieldType,
    placeholder: formLabel(field.placeholder, fr),
    required: field.required,
    order: field.order,
    options: field.options.map((option) => formLabel(option, fr)),
  };
}

export function DisplayBlock({ field, fr }: { field: ParentFormField; fr: boolean }) {
  const label = formLabel(field.label, fr);
  const body = field.placeholder.trim();
  if (field.type === "image") {
    if (!body) return null;
    return (
      <div className="py-3">
        {label.trim() && label.trim() !== "Image" ? <p className="mb-2 text-[15px] font-semibold text-[#202124]">{label}</p> : null}
        <img src={body} alt={label} className="max-h-[420px] rounded-lg object-contain" onError={(event) => (event.currentTarget.style.display = "none")} />
      </div>
    );
  }
  if (field.type === "video") {
    return (
      <div className="py-3">
        {label.trim() ? <p className="mb-2 text-[15px] font-semibold text-[#202124]">{label}</p> : null}
        {/^https?:\/\//i.test(body) ? (
          <a href={body} target="_blank" rel="noreferrer" className="text-sm font-semibold text-[#673AB7] underline">
            {body}
          </a>
        ) : null}
      </div>
    );
  }
  return (
    <div className={field.type === "section" ? "pb-2 pt-6" : "pb-2 pt-4"}>
      {field.type === "section" ? <hr className="mb-4 border-[#DADCE0]" /> : null}
      <p className="text-lg font-bold text-[#202124]">{label}</p>
      {body ? <p className="mt-1 text-sm text-[#616161]">{formLabel(body, fr)}</p> : null}
    </div>
  );
}
