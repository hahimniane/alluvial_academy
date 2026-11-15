/**
 * French for form labels, placeholders and options, generated from
 * lib/features/forms/utils/form_localization.dart and app_fr.arb (the
 * dictionary the app's form page uses). Text not in this list shows as typed
 * by the admin in both languages, as in the app.
 */
export const FORM_LABELS_FR: Readonly<Record<string, string>> = {
  "Average": "Moyenne",
  "Child\\\\": "Child\\",
  "Collect feedback from parents about their child\\\\": "Collect feedback from parents about their child\\",
  "High": "Élevé",
  "N/A": "Sans objet",
  "No": "Non",
  "Other": "Autres",
  "Start Date": "Date de début",
};

export function formLabel(text: string, fr: boolean) {
  return fr ? FORM_LABELS_FR[text] ?? text : text;
}
