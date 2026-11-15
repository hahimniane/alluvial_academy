/**
 * Words on the parent Classes page and the join page that Flutter translates
 * (ARB keys), plus the texts handed to the Zoom meeting page — the same keys
 * ZoomMeetingScreen sends. Strings Flutter hard-codes in English ("Upcoming",
 * "History", "No upcoming classes", status words, "Teacher: …", "Join Now")
 * stay English inline, as today.
 *
 * Plan default "no junk text": Title-Case or cut-off ARB strings ("Please Sign
 * In Again To Join", "This Class Link Is No Longer", "Connecting To Class")
 * and wrong French ("n'est plus long") become plain sentences.
 */
const EN = {
  classes: "Classes",
  refresh: "Refresh",
  noChildren: "No children linked to your account",
  childrenFailed: "Your children could not be loaded. Please refresh to try again.",
  connecting: "Connecting to class",
  linkGone: "This class link is no longer available.",
  noVideo: "Unable to join this class right now.",
  signIn: "Please sign in again to join this class.",
  opensIn1: "Class opens in 1 minute",
  opensInN: "Class opens in {count} minutes",
  ended: "This class has ended",
  connectFailed: "Failed to connect to class",
  slow: "Your connection is too slow to reach the class. Check your internet and try again.",
  tryAgain: "Try again",
  backToClasses: "Back to Classes",
  back: "Back",
  meetingLoadError: "Unable to load Zoom meeting.",
  meetingJoinError: "Unable to join Zoom meeting.",
  meetingInitError: "Unable to initialize Zoom.",
  leaveClass: "Leave Class",
  leaveMeeting: "Leave Meeting",
  routingStillConnecting: "Still connecting to your private classroom...",
  routingHelp: "This class is still connecting. Please leave and rejoin, or ask an administrator for help.",
  classEndingSoon: "This class ends in {minutes} min",
  classEnded: "This class has ended.",
} as const;

export type ParentClassesText = { [K in keyof typeof EN]: string };

const FR: ParentClassesText = {
  classes: "Cours",
  refresh: "Actualiser",
  noChildren: "No children linked to your account",
  childrenFailed: "Vos enfants n'ont pas pu être chargés. Actualisez pour réessayer.",
  connecting: "Connexion à la classe",
  linkGone: "Ce lien de cours n'est plus disponible.",
  noVideo: "Impossible de rejoindre cette classe pour le moment.",
  signIn: "Veuillez vous reconnecter pour rejoindre ce cours.",
  opensIn1: "La classe ouvre dans 1 minute",
  opensInN: "La classe ouvre dans {count} minutes",
  ended: "Cette classe est terminée",
  connectFailed: "Impossible de se connecter à la classe",
  slow: "Votre connexion est trop lente pour rejoindre la classe. Vérifiez votre internet et réessayez.",
  tryAgain: "Réessayer",
  backToClasses: "Retour aux cours",
  back: "Retour",
  meetingLoadError: "Impossible de charger la réunion Zoom.",
  meetingJoinError: "Impossible de rejoindre la réunion Zoom.",
  meetingInitError: "Impossible d’initialiser Zoom.",
  leaveClass: "Quitter la classe",
  leaveMeeting: "Quitter la réunion",
  routingStillConnecting: "Connexion à votre salle de classe privée...",
  routingHelp: "Cette classe est encore en cours de connexion. Veuillez quitter puis rejoindre à nouveau, ou demander de l'aide à un administrateur.",
  classEndingSoon: "Ce cours se termine dans {minutes} min",
  classEnded: "Ce cours est terminé.",
};

export function parentClassesText(fr: boolean): ParentClassesText {
  return fr ? FR : EN;
}
