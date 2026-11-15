/**
 * Words for the parent Forms, Profile and Settings pages that the app
 * translates (ARB keys, French from app_fr.arb). Text the app hard-codes in
 * English stays English in both languages, as today. Junk ARB text is replaced
 * with a plain sentence: "Failed To Save Profile E", "Account Settings Build
 * Info", "New Version", "Formulaires de recherche", "Autres" for a reason.
 */
const EN = {
  // Forms list (TeacherFormsScreen, parentOnly)
  formsTitle: "Family Forms",
  formsSubtitle: "Submit an excuse request or share feedback with school leaders.",
  mySubmissions: "My Form Submissions",
  searchForms: "Search Forms",
  clearSearch: "Clear Search",
  noMatch: "No active forms match your search.",
  tryAdjusting: "Try adjusting your search",
  somethingWrong: "Oops! Something went wrong",
  tryAgain: "Try Again",
  required: "Required",
  // Built-in excuse form
  excuseTitle: "Student Absence / Excuse Request",
  excuseDescription: "Let the school know why your child will miss or has missed a class.",
  excuseStudentName: "Child's full name",
  excuseClassOrTeacher: "Class or teacher (optional)",
  excuseAbsenceDate: "Date of the missed class",
  excuseReason: "Reason for the absence",
  excuseReasons: ["Illness", "Appointment", "Family emergency", "Technical issue", "Other"],
  excuseDetails: "Please explain the absence",
  excusePreferredContact: "Preferred follow-up method (optional)",
  excuseContacts: ["In-app chat", "Email", "Phone"],
  // Profile (ParentProfileScreen)
  editProfile: "Edit Profile",
  personalInformation: "Personal Information",
  firstName: "First Name",
  lastName: "Last Name",
  email: "Email",
  phone: "Phone Number",
  saveChanges: "Save Changes",
  profileSaved: "Profile Updated Successfully",
  profileLoadFailed: "Could not load your profile. Check your connection and reload the page.",
  profileSaveFailed: "Could not save your profile. Check your connection and try again.",
  // Settings (RoleSettingsScreen)
  settingsTitle: "Parent Settings",
  settingsSubtitle: "Language, password and app version",
  language: "Language",
  chooseLanguage: "Choose language",
  version: "Version",
} as const;

export type ParentFormsText = { [K in keyof typeof EN]: (typeof EN)[K] extends readonly string[] ? string[] : string };

const FR: ParentFormsText = {
  formsTitle: "Formulaires familiaux",
  formsSubtitle: "Envoyez une demande d'excuse ou partagez vos commentaires avec les responsables de l'école.",
  mySubmissions: "Mes soumissions de formulaires",
  searchForms: "Rechercher des formulaires",
  clearSearch: "Effacer la recherche",
  noMatch: "Aucun formulaire actif ne correspond à votre recherche.",
  tryAdjusting: "Essayez d'ajuster votre recherche",
  somethingWrong: "Oups ! Une erreur s'est produite",
  tryAgain: "Réessayer",
  required: "Obligatoire",
  excuseTitle: "Demande d'excuse d'absence de l'élève",
  excuseDescription: "Informez l'école de la raison pour laquelle votre enfant manquera ou a manqué un cours.",
  excuseStudentName: "Nom complet de l'enfant",
  excuseClassOrTeacher: "Cours ou enseignant (facultatif)",
  excuseAbsenceDate: "Date du cours manqué",
  excuseReason: "Motif de l'absence",
  excuseReasons: ["Maladie", "Rendez-vous", "Urgence familiale", "Problème technique", "Autre"],
  excuseDetails: "Veuillez expliquer l'absence",
  excusePreferredContact: "Mode de suivi préféré (facultatif)",
  excuseContacts: ["Chat dans l'application", "E-mail", "Téléphone"],
  editProfile: "Modifier le profil",
  personalInformation: "Renseignements personnels",
  firstName: "Prénom",
  lastName: "Nom de famille",
  email: "Email",
  phone: "Numéro de téléphone",
  saveChanges: "Enregistrer les modifications",
  profileSaved: "Profil mis à jour avec succès",
  profileLoadFailed: "Impossible de charger votre profil. Vérifiez votre connexion et rechargez la page.",
  profileSaveFailed: "Impossible d'enregistrer votre profil. Vérifiez votre connexion et réessayez.",
  settingsTitle: "Paramètres parent",
  settingsSubtitle: "Langue, mot de passe et version de l'application",
  language: "Langue",
  chooseLanguage: "Choisir la langue",
  version: "Version",
};

export function parentFormsText(fr: boolean): ParentFormsText {
  return fr ? FR : (EN as unknown as ParentFormsText);
}
