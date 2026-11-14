/**
 * French for the public website, keyed by the English source text. A missing
 * key falls back to English. Formal "vous"; {var} placeholders are kept.
 *
 * Covers the team page (/team), the teacher and leadership application forms
 * and the login forwarding page. Only what is shown is translated: the
 * application forms keep saving their English values.
 */
export const FR_PUBLIC_TEAM: Record<string, string> = {
  // ── /team ────────────────────────────────────────────────────────────────
  "Loading team...": "Chargement de l'équipe...",
  "Our Global Team": "Notre équipe internationale",
  "Meet the People Behind Alluwal": "Découvrez celles et ceux qui font Alluwal",
  "Educators, leaders, and innovators united by a shared mission — to make quality religious and academic education accessible to every learner, everywhere.":
    "Des éducateurs, des responsables et des innovateurs unis par une mission commune : rendre une éducation religieuse et scolaire de qualité accessible à chaque apprenant, où qu'il soit.",

  "All Team": "Toute l'équipe",
  "The full Alluwal family": "Toute la famille Alluwal",
  "Visionaries and educators united by one mission.": "Des visionnaires et des éducateurs unis par une même mission.",
  "Leadership": "Direction",
  "Vision & Direction": "Vision et orientation",
  "The architects and coordinators of Alluwal - shaping policy, strategy, operations and culture.":
    "Les architectes et coordinateurs d'Alluwal : ils façonnent les règles, la stratégie, le fonctionnement et la culture.",
  "Teachers": "Enseignants",
  "Global Knowledge Carriers": "Porteurs de savoir à travers le monde",
  "Scholars and educators spanning 10+ countries - bringing religious and academic excellence to every learner, everywhere.":
    "Des érudits et des éducateurs présents dans plus de 10 pays, qui apportent l'excellence religieuse et scolaire à chaque apprenant, où qu'il soit.",

  "Founder": "Fondateur",
  "View Full Profile": "Voir le profil complet",
  "View Profile": "Voir le profil",
  "Part of the team that builds the platform.": "Membre de l'équipe qui conçoit la plateforme.",
  "Location to be announced": "Lieu à préciser",
  "Profile details are coming soon.": "Le profil détaillé sera bientôt disponible.",

  "Want to Join Our Team?": "Envie de rejoindre notre équipe ?",
  "We are always looking for passionate educators and professionals who share our vision. Join us in making a difference.":
    "Nous sommes toujours à la recherche d'éducateurs et de professionnels passionnés qui partagent notre vision. Rejoignez-nous pour faire la différence.",
  "Apply to Teach": "Postuler pour enseigner",
  "Contact Us": "Nous contacter",

  "{name} profile": "Profil : {name}",
  "Close profile": "Fermer le profil",
  "About {name}": "{name} en quelques mots",
  "Why Alluwal": "Pourquoi Alluwal",
  "This team member is part of Alluwal's mission to support learners and families.":
    "Ce membre de l'équipe participe à la mission d'Alluwal : accompagner les apprenants et les familles.",
  "Languages": "Langues",
  "Contact {name}": "Contacter {name}",

  // ── Application forms: shared pieces ─────────────────────────────────────
  "Select an option": "Sélectionnez une option",
  "WhatsApp Number": "Numéro WhatsApp",
  "Country code": "Indicatif du pays",
  "Step {current} of {total}": "Étape {current} sur {total}",
  "{count} words / minimum {min} / maximum {max}": "Mots : {count} / minimum {min} / maximum {max}",
  "{count} words / minimum {min}": "Mots : {count} / minimum {min}",
  "{count} words / maximum {max}": "Mots : {count} / maximum {max}",
  "Please write at least {min} words.": "Veuillez écrire au moins {min} mots.",
  "Please limit this answer to {max} words.": "Veuillez limiter cette réponse à {max} mots.",
  "Application submitted successfully.": "Votre candidature a bien été envoyée.",
  "We could not submit the application. Please try again.": "Nous n'avons pas pu envoyer votre candidature. Veuillez réessayer.",
  "Submitting...": "Envoi en cours...",
  "Submit Application": "Envoyer ma candidature",
  "Previous": "Précédent",
  "Next": "Suivant",

  "Personal Information": "Informations personnelles",
  "First Name": "Prénom",
  "Last Name": "Nom",
  "Email": "E-mail",
  "Current Location (Country and City)": "Lieu de résidence actuel (pays et ville)",
  "United States, New York": "États-Unis, New York",
  "Gender": "Genre",
  "Male": "Homme",
  "Female": "Femme",
  "Nationality": "Nationalité",
  "American": "Américaine",
  "I am currently a...": "Je suis actuellement...",
  "University Student": "Étudiant(e) à l'université",
  "High School Student": "Lycéen(ne)",
  "University Graduate": "Diplômé(e) de l'université",
  "Professional": "Professionnel(le)",
  "Other": "Autre",
  "Please specify": "Veuillez préciser",
  "Your current status": "Votre situation actuelle",

  "In One Week": "Dans une semaine",
  "In Two Weeks": "Dans deux semaines",
  "In Three Weeks": "Dans trois semaines",
  "In a Month": "Dans un mois",
  "Please specify availability": "Veuillez préciser votre disponibilité",
  "Your availability": "Votre disponibilité",

  // ── /teacher-application ─────────────────────────────────────────────────
  "Join Our Team": "Rejoignez notre équipe",
  "Teacher Application": "Candidature d'enseignant",
  "Thank you for your interest in teaching with us. Please complete every step so we can review your application properly.":
    "Merci de l'intérêt que vous portez à l'enseignement à nos côtés. Veuillez remplir chaque étape afin que nous puissions étudier votre candidature avec soin.",

  "Teaching Programs": "Programmes d'enseignement",
  "Select the program(s) you are interested in teaching.": "Sélectionnez le ou les programmes que vous souhaitez enseigner.",
  "After School Tutoring (English track)": "Soutien scolaire après l'école (parcours en anglais)",
  "Religious Studies (Quran, Arabic, Hadith, Fiqh)": "Études religieuses (Coran, arabe, hadith, fiqh)",
  "Adult Literacy (English/French reading and writing)": "Alphabétisation des adultes (lecture et écriture en anglais/français)",
  "AdLaM (Reading and Writing)": "AdLaM (lecture et écriture)",
  "Please select at least one teaching program.": "Veuillez sélectionner au moins un programme d'enseignement.",
  "Please select at least one language.": "Veuillez sélectionner au moins une langue.",
  "Please specify other program": "Veuillez préciser l'autre programme",
  "Your program": "Votre programme",
  "If interested in the After School English track, list subjects you can teach":
    "Si le parcours en anglais du soutien scolaire vous intéresse, indiquez les matières que vous pouvez enseigner",
  "Reading, Writing, Grammar, Vocabulary...": "Lecture, écriture, grammaire, vocabulaire...",

  "Religious Studies Qualifications": "Qualifications en études religieuses",
  "Are you excellent in Tajwid Rules?": "Maîtrisez-vous parfaitement les règles du tajwid ?",
  "Yes": "Oui",
  "No": "Non",
  "Average": "Moyennement",
  "N/A": "Sans objet",
  "What is your level of Quran Memorization?": "Quel est votre niveau de mémorisation du Coran ?",
  "100% - I am Hafiz": "100 % - Je suis hafiz",
  "About 50% or more": "Environ 50 % ou plus",
  "About 35% or less": "Environ 35 % ou moins",
  "I memorize less than Juzu Anma": "J'ai mémorisé moins que le Juz' Amma",
  "How perfectly do you read and write Arabic?": "Quel est votre niveau de lecture et d'écriture en arabe ?",
  "I Am Excellent": "J'ai un excellent niveau",
  "I Am Intermediate": "J'ai un niveau intermédiaire",
  "I Am A Beginner": "Je suis débutant(e)",

  "Languages You Fluently Speak": "Langues que vous parlez couramment",
  "English|language": "Anglais",
  "Arabic|language": "Arabe",
  "French|language": "Français",
  "Spanish|language": "Espagnol",
  "Mandingo|language": "Mandingue",
  "Pular|language": "Pular",
  "Wolof|language": "Wolof",
  "Hausa|language": "Haoussa",
  "Turkish|language": "Turc",
  "Urdu|language": "Ourdou",
  "Bengali|language": "Bengali",
  "Indonesian|language": "Indonésien",
  "Malay|language": "Malais",
  "Swahili|language": "Swahili",
  "Amharic|language": "Amharique",
  "Adlam|language": "Adlam",
  "Other|language": "Autre",

  "Experience & Commitment": "Expérience et engagement",
  "How disciplined are you with time, especially working late at night?":
    "Quelle est votre discipline en matière d'horaires, notamment pour travailler tard le soir ?",
  "100% - Sleep will never cause me to miss a class": "100 % - Le sommeil ne me fera jamais manquer un cours",
  "50% - Sleep and personal engagement might affect me": "50 % - Le sommeil et mes engagements personnels pourraient m'affecter",
  "<30% - Resisting sleep and planning ahead is hard": "<30 % - Résister au sommeil et m'organiser à l'avance m'est difficile",
  "Sorry, not at all - I am a day person": "Désolé(e), pas du tout - je travaille mieux en journée",
  "How well can you balance school/personal schedule with teaching (6 hrs/week required)?":
    "Dans quelle mesure pouvez-vous concilier vos études ou votre emploi du temps personnel avec l'enseignement (6 h par semaine requises) ?",
  "100% - I am always on top of things": "100 % - Je suis toujours parfaitement organisé(e)",
  "50% - I often try to be balanced": "50 % - J'essaie souvent de trouver un équilibre",
  ">30% - Life balance is not one of my strengths": ">30 % - L'équilibre de vie n'est pas l'un de mes points forts",
  "Not at all": "Pas du tout",
  "Why are you interested in applying for a teaching role with us? (100-400 words)":
    "Pourquoi souhaitez-vous postuler à un poste d'enseignant chez nous ? (100 à 400 mots)",
  "Describe your motivation...": "Décrivez votre motivation...",
  "How often do you have electricity/energy at home?": "À quelle fréquence disposez-vous d'électricité à votre domicile ?",
  "Always / 24 hours / 7 days": "Toujours / 24 h sur 24 / 7 j sur 7",
  "Sometimes": "Parfois",
  "Rarely": "Rarement",
  "Never": "Jamais",
  "How comfortable are you teaching teenagers, adults, and children online?":
    "Dans quelle mesure êtes-vous à l'aise pour enseigner en ligne à des adolescents, des adultes et des enfants ?",
  "Very comfortable": "Très à l'aise",
  "Comfortable": "À l'aise",
  "Less comfortable": "Moins à l'aise",
  "Uncomfortable": "Pas à l'aise",
  "Do you guarantee responsible, legal, and moral interaction with students, especially minors?":
    "Garantissez-vous des échanges responsables, légaux et moraux avec les élèves, en particulier les mineurs ?",
  "Yes, and always": "Oui, toujours",
  "Maybe, but I will try": "Peut-être, mais je ferai de mon mieux",
  "No, I can't": "Non, je ne peux pas",
  "How soon are you available to start teaching?": "Quand êtes-vous disponible pour commencer à enseigner ?",

  "Technical Requirements": "Conditions techniques",
  "What device do you intend to use to teach classes?": "Quel appareil comptez-vous utiliser pour donner vos cours ?",
  "A Computer": "Un ordinateur",
  "A Tablet": "Une tablette",
  "A Phone": "Un téléphone",
  "No Device": "Aucun appareil",
  "How often do you have access to the internet?": "À quelle fréquence avez-vous accès à Internet ?",
  "Often / Few days a week": "Souvent / quelques jours par semaine",
  "Rarely / Few hours a week": "Rarement / quelques heures par semaine",

  "Teaching Scenarios": "Mises en situation",
  "Scenario: What would you do if a student (child) does not want to participate/read during class? (100-300 words)":
    "Mise en situation : que feriez-vous si un élève (enfant) ne voulait pas participer ou lire pendant le cours ? (100 à 300 mots)",
  "Describe your approach...": "Décrivez votre approche...",
  "Feedback": "Vos remarques",
  "Any feedback on this application form? What didn't you like? (Optional)":
    "Avez-vous des remarques sur ce formulaire de candidature ? Qu'est-ce qui vous a déplu ? (facultatif)",
  "Your feedback helps us improve...": "Vos remarques nous aident à nous améliorer...",

  // ── /leadership-application ──────────────────────────────────────────────
  "Join Our Leadership Team": "Rejoignez notre équipe de direction",
  "Lead, inspire, and make a lasting impact by helping Alluwal grow with care and structure.":
    "Dirigez, inspirez et laissez une empreinte durable en aidant Alluwal à grandir avec soin et méthode.",
  "Leadership Interest": "Votre intérêt pour un rôle de responsable",
  "Why are you interested in a leadership role?": "Pourquoi un rôle de responsable vous intéresse-t-il ?",
  "Relevant Leadership/Management Experience (Optional)": "Expérience pertinente en direction ou en gestion (facultatif)",
  "How soon are you available to start?": "Quand êtes-vous disponible pour commencer ?",

  // ── /login (forwards to the sign-in page) ────────────────────────────────
  "Taking you to the login page…": "Redirection vers la page de connexion…",
  "Continue to login": "Continuer vers la connexion",
};
