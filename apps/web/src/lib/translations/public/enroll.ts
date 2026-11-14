/**
 * French for the public website, keyed by the English source text. A missing
 * key falls back to English. Formal "vous"; {var} placeholders are kept.
 *
 * Covers /enroll and /programs. Only what is shown is translated: everything
 * an enrollment stores (subjects, levels, class types, days, time blocks,
 * languages) stays English in the form and is translated where it is drawn.
 * A key ending in "|subject", "|language" or "|program" is one of those names.
 */
export const FR_PUBLIC_ENROLL: Record<string, string> = {
  // ------------------------------------------------------------- pages --
  "Loading enrollment...": "Chargement de l'inscription...",
  "Loading programs...": "Chargement des programmes...",

  // ------------------------------------------------- enroll: step bar --
  "Who's enrolling": "Qui s'inscrit",
  "Student details": "Infos de l'élève",
  "Program & pricing": "Programme et tarifs",
  "Schedule": "Horaires",
  "Contact & review": "Contact et récapitulatif",

  // ------------------------------------------ enroll: who's enrolling --
  "Student, parent, or guardian — and how many children if applicable.":
    "Étudiant, parent ou tuteur — et le nombre d'enfants, le cas échéant.",
  "Student": "Étudiant",
  "I'm signing up for myself.": "Je m'inscris moi-même.",
  "Parent": "Parent",
  "I'm enrolling one or more children.": "J'inscris un ou plusieurs enfants.",
  "Guardian": "Tuteur",
  "I'm responsible for a learner's enrollment.": "Je suis responsable de l'inscription d'un apprenant.",
  "Children": "Enfants",
  "You can add multiple students in this enrollment.": "Vous pouvez ajouter plusieurs élèves à cette inscription.",
  "Remove student": "Retirer un élève",
  "Add student": "Ajouter un élève",
  "Account linked": "Compte associé",
  "Already have a child enrolled?": "Vous avez déjà un enfant inscrit ?",
  "Link your account to manage all students together.": "Associez votre compte pour gérer tous les élèves ensemble.",
  "Linked parent": "Parent associé",
  "Unlink": "Dissocier",
  "Email or kiosque code": "E-mail ou code kiosque",
  "Parent email or kiosque code": "E-mail ou code kiosque du parent",
  "Checking...": "Vérification...",
  "Link|verb": "Associer",
  "Please enter an email or kiosque code to link account.":
    "Veuillez saisir un e-mail ou un code kiosque pour associer le compte.",
  "Account linked successfully.": "Compte associé avec succès.",
  "No parent account found with that email or kiosque code.":
    "Aucun compte parent trouvé avec cet e-mail ou ce code kiosque.",
  "Could not verify account right now. Please try again.":
    "Impossible de vérifier le compte pour le moment. Veuillez réessayer.",

  // ------------------------------------------ enroll: student details --
  "Student's Information": "Informations sur l'élève",
  "Your Information": "Vos informations",
  "Names, ages, and genders for each learner.": "Nom, âge et genre de chaque apprenant.",
  "Student {number}": "Élève {number}",
  "Full Name": "Nom complet",
  "Student {number} name": "Nom de l'élève {number}",
  "Enter your full name": "Saisissez votre nom complet",
  "Student {number} full name": "Nom complet de l'élève {number}",
  "Age": "Âge",
  "Years": "En années",
  "Gender": "Genre",
  "Male": "Homme",
  "Female": "Femme",
  "Stay in touch while you apply (optional)": "Restons en contact pendant votre inscription (facultatif)",
  "Leave an email or WhatsApp number and our team can help you finish enrolling if you get interrupted.":
    "Laissez une adresse e-mail ou un numéro WhatsApp : notre équipe pourra vous aider à terminer l'inscription si vous êtes interrompu.",
  "Email": "E-mail",
  "your@email.com": "votre@email.com",
  "WhatsApp / phone": "WhatsApp / téléphone",

  // ------------------------------------------ enroll: program details --
  "Program Details": "Détails du programme",
  "Each student can have a separate program and hours.":
    "Chaque élève peut avoir son propre programme et ses propres heures.",
  "Choose a program track, class preferences, and weekly hours.":
    "Choisissez un parcours, vos préférences de cours et le nombre d'heures par semaine.",
  "Customize per student": "Personnaliser pour chaque élève",
  "All children": "Tous les enfants",
  "+ Add another program for {name}": "+ Ajouter un autre programme pour {name}",
  "+ Add another program for All children": "+ Ajouter un autre programme pour tous les enfants",
  "+ Add another program for this student": "+ Ajouter un autre programme pour cet élève",
  "Program {number}": "Programme {number}",
  "Program details": "Détails du programme",
  "Remove program {number}": "Supprimer le programme {number}",
  "1. Choose a Program": "1. Choisissez un programme",
  "Select a learning track": "Sélectionnez un parcours d'apprentissage",
  "Religious Studies": "Études religieuses",
  "Adlam": "Adlam",
  "Tutoring & Literacy": "Soutien scolaire et alphabétisation",
  "Group Classes": "Cours en groupe",
  "2. Class Preferences": "2. Préférences de cours",
  "Specific Language": "Langue souhaitée",
  "Grade Level": "Niveau scolaire",
  "Proficiency Level": "Niveau de maîtrise",
  "Select an option": "Sélectionnez une option",
  "Beginner": "Débutant",
  "Intermediate": "Intermédiaire",
  "Advanced": "Avancé",
  "Elementary School": "École primaire",
  "Middle School": "Collège",
  "High School": "Lycée",
  "University": "Université",
  "Class Type": "Type de cours",
  "1-on-1": "Cours individuel",
  "Just this student with the teacher.": "Uniquement cet élève avec l'enseignant.",
  "Exclusive family class": "Cours réservé à la famille",
  "Only your children in the class, taught together.": "Seuls vos enfants suivent le cours, ensemble.",
  "With other students on the platform": "Avec d'autres élèves de la plateforme",
  "We place the student in a group and set the timetable.":
    "Nous plaçons l'élève dans un groupe et fixons l'emploi du temps.",
  "Exclusive Family Class": "Cours réservé à la famille",
  "With Other Students": "Avec d'autres élèves",
  "Preferred Language": "Langue préférée",
  "3. Pricing & Hours": "3. Tarifs et heures",
  "How long is each class?": "Quelle est la durée de chaque cours ?",
  "How many classes a week?": "Combien de cours par semaine ?",
  "Fewer classes per week": "Moins de cours par semaine",
  "More classes per week": "Plus de cours par semaine",
  "30 min": "30 min",
  "1 hour": "1 heure",
  "1.5 hours": "1 h 30",
  "2 hours": "2 heures",
  "Hours per week": "Heures par semaine",
  "hr": "h",
  "hrs": "h",
  "{hours} hrs/wk": "{hours} h/sem.",
  "We’ll confirm pricing with you after this — schedules and rates are flexible.":
    "Nous confirmerons les tarifs avec vous ensuite — les horaires et les tarifs sont flexibles.",

  // ------------------------------------------------ enroll: subjects --
  "Religious Studies|subject": "Études religieuses",
  "Group Classes|subject": "Cours en groupe",
  "AfroLanguages|subject": "Langues africaines",
  "English|subject": "Anglais",
  "French|subject": "Français",
  "Adlam|subject": "Adlam",
  "Entrepreneurship|subject": "Entrepreneuriat",
  "Coding|subject": "Programmation",
  "Tutoring|subject": "Soutien scolaire",
  "Adult Literacy|subject": "Alphabétisation des adultes",

  // ----------------------------------------------- enroll: languages --
  "English|language": "Anglais",
  "French|language": "Français",
  "Arabic|language": "Arabe",
  "Other|language": "Autre",
  "Pular|language": "Pular",
  "Mandingo|language": "Mandingue",
  "Swahili|language": "Swahili",
  "Wolof|language": "Wolof",
  "Hausa|language": "Haoussa",
  "Yoruba|language": "Yoruba",
  "Adlam|language": "Adlam",
  "Amharic|language": "Amharique",

  // ------------------------------------------------ enroll: schedule --
  "Schedule Preferences": "Préférences d'horaires",
  "Choose the days and the part of the day that suit you. We confirm exact times with you afterwards.":
    "Choisissez les jours et le moment de la journée qui vous conviennent. Nous confirmons ensuite les horaires exacts avec vous.",
  "Program": "Programme",
  "We'll place {name} in a group": "Nous placerons {name} dans un groupe",
  "We'll place this student in a group": "Nous placerons cet élève dans un groupe",
  "Group classes run on a set timetable. Tell us the days and part of the day that suit you and we'll find the closest group.":
    "Les cours en groupe suivent un emploi du temps fixe. Indiquez-nous les jours et le moment de la journée qui vous conviennent et nous trouverons le groupe le plus proche.",
  "Which days work best?": "Quels jours vous conviennent le mieux ?",
  "Mon": "Lun",
  "Tue": "Mar",
  "Wed": "Mer",
  "Thu": "Jeu",
  "Fri": "Ven",
  "Sat": "Sam",
  "Sun": "Dim",
  "Preferred Time of Day": "Moment de la journée préféré",
  "Morning": "Matin",
  "Afternoon": "Après-midi",
  "Evening": "Soir",
  "Night": "Nuit",
  "Late night": "Tard dans la nuit",
  "A {duration} session doesn't fit inside {block} ({range}). Choose a shorter session or another part of the day.":
    "Une séance de {duration} ne tient pas dans la plage « {block} » ({range}). Choisissez une séance plus courte ou un autre moment de la journée.",
  "We'll book {count} × {duration} somewhere between {range} on {days}, and confirm the exact times with you.":
    "Nous réserverons {count} × {duration} entre {range}, les jours suivants : {days}, puis nous confirmerons les horaires exacts avec vous.",

  // ---------------------------------------- enroll: contact & review --
  "Review your selections, enter contact details, then submit.":
    "Vérifiez vos choix, saisissez vos coordonnées, puis envoyez.",
  "Enrollment Details": "Détails de l'inscription",
  "Edit": "Modifier",
  "{who} program": "Programme de {who}",
  "{who} · program {number}": "{who} · programme {number}",
  "Level": "Niveau",
  "Format": "Format",
  "Hours/week": "Heures/semaine",
  "Program?": "Programme ?",
  "Days": "Jours",
  "Window": "Plage horaire",
  "Sessions": "Séances",
  "Your contact info": "Vos coordonnées",
  "We use this to confirm enrollment and reach you about scheduling.":
    "Nous les utilisons pour confirmer l'inscription et vous contacter au sujet des horaires.",
  "Parent / guardian name": "Nom du parent ou tuteur",
  "As on ID or school records": "Comme sur la pièce d'identité ou le dossier scolaire",
  "Whatsapp Number": "Numéro WhatsApp",
  "Phone Number": "Numéro de téléphone",
  "Code": "Code",
  "Select Country": "Pays",
  "City": "Ville",
  "Scheduling notes (optional)": "Remarques sur les horaires (facultatif)",
  "e.g. prefer after 4pm weekdays, avoid Fridays...": "ex. : de préférence après 16 h en semaine, éviter le vendredi...",

  // ------------------------------------- enroll: summary and actions --
  "{count} student": "{count} élève",
  "{count} students": "{count} élèves",
  "Your selections": "Vos choix",
  "Back": "Retour",
  "Previous": "Précédent",
  "Submitting...": "Envoi en cours...",
  "Submit Request": "Envoyer la demande",
  "Continue": "Continuer",

  // ---------------------------------------------- enroll: validation --
  "Please select who you are (Student, Parent, or Guardian).":
    "Veuillez indiquer qui vous êtes (étudiant, parent ou tuteur).",
  "Please enter name for Student {number}.": "Veuillez saisir le nom de l'élève {number}.",
  "{who}, program {number}": "{who}, programme {number}",
  "Please select a program for {which}.": "Veuillez sélectionner un programme pour {which}.",
  "Please select a specific language for {which}.": "Veuillez sélectionner une langue pour {which}.",
  "Please select a level for {which}.": "Veuillez sélectionner un niveau pour {which}.",
  "Please select a class type for {which}.": "Veuillez sélectionner un type de cours pour {which}.",
  "{which}: sessions and weekly hours don't match yet.":
    "{which} : les séances et les heures par semaine ne correspondent pas encore.",
  "{which}: please select at least one preferred day.": "{which} : veuillez sélectionner au moins un jour.",
  "{which}: please choose a part of the day.": "{which} : veuillez choisir un moment de la journée.",
  "{which}: a {duration} session doesn't fit inside {block}.":
    "{which} : une séance de {duration} ne tient pas dans la plage « {block} ».",
  "Please enter the parent or guardian name.": "Veuillez saisir le nom du parent ou tuteur.",
  "We could not submit the enrollment request. Please try again.":
    "Nous n'avons pas pu envoyer la demande d'inscription. Veuillez réessayer.",

  // ------------------------------------------------- enroll: success --
  "Request Received": "Demande reçue",
  "Thank You For Your Interest In": "Merci de votre intérêt",
  "Back To Home": "Retour à l'accueil",

  // ------------------------------------------------ programs: header --
  "Explore our programs": "Découvrez nos programmes",
  "Choose a program, preview pricing by hours per week, then continue to enrollment — all in one place.":
    "Choisissez un programme, consultez les tarifs selon le nombre d'heures par semaine, puis passez à l'inscription — le tout au même endroit.",
  "Browse Programs": "Parcourir les programmes",
  "35+ Programs": "Plus de 35 programmes",
  "Flexible Scheduling": "Horaires flexibles",
  "Expert Tutors": "Enseignants experts",
  "{count} subjects": "{count} matières",
  "Collapse {title}": "Réduire {title}",
  "Decrease hours per week": "Diminuer les heures par semaine",
  "Increase hours per week": "Augmenter les heures par semaine",
  "per hour": "par heure",
  "{hours} hrs/wk · rates are flexible": "{hours} h/sem. · tarifs flexibles",
  "Continue to enrollment": "Continuer vers l'inscription",

  // -------------------------------------------- programs: categories --
  "Religious studies": "Études religieuses",
  "Quran, Hadith, Arabic Language, Tawhid, Tafsir, and Fiqh": "Coran, Hadith, langue arabe, Tawhid, Tafsir et Fiqh",
  "Languages": "Langues",
  "English, French, Adlam, Swahili, Yoruba, and more": "Anglais, français, Adlam, swahili, yoruba et plus encore",
  "English & literacy": "Anglais et alphabétisation",
  "Grammar, Reading, Creative Writing, and Test Prep":
    "Grammaire, lecture, écriture créative et préparation aux examens",
  "Mathematics": "Mathématiques",
  "Elementary through Calculus and Statistics": "Du primaire à l'analyse et aux statistiques",
  "Coding & technology": "Programmation et technologie",
  "Kids Coding, Web, Mobile, Python, and Game Dev": "Programmation pour enfants, web, mobile, Python et jeux vidéo",
  "After-school tutoring": "Soutien scolaire après l'école",
  "Elementary, Middle School, and High School support": "Accompagnement au primaire, au collège et au lycée",

  // ------------------------------------- programs: religious studies --
  "Quran|program": "Coran",
  "Complete Quran learning program including recitation, memorization, and understanding.":
    "Programme complet d'apprentissage du Coran : récitation, mémorisation et compréhension.",
  "Hadith|program": "Hadith",
  "Study the recorded sayings and teachings central to Islamic tradition.":
    "Étudiez les paroles et les enseignements rapportés, au cœur de la tradition islamique.",
  "Arabic language|program": "Langue arabe",
  "Learn Arabic from basics to fluency, for study and everyday use.":
    "Apprenez l'arabe, des bases jusqu'à la maîtrise, pour l'étude et la vie quotidienne.",
  "Tawhid|program": "Tawhid",
  "Core theological beliefs and their foundations.": "Les croyances théologiques essentielles et leurs fondements.",
  "Tafsir|program": "Tafsir",
  "Deep reading and interpretation of scripture.": "Lecture approfondie et interprétation des textes sacrés.",
  "Fiqh|program": "Fiqh",
  "Religious law and practical worship.": "Droit religieux et pratique du culte.",

  // --------------------------------------------- programs: languages --
  "English|program": "Anglais",
  "Complete support for reading, writing, grammar, vocabulary, and exam prep.":
    "Accompagnement complet en lecture, écriture, grammaire, vocabulaire et préparation aux examens.",
  "French|program": "Français",
  "Master French language skills including conversation, grammar, and cultural understanding.":
    "Maîtrisez le français : conversation, grammaire et compréhension culturelle.",
  "Adlam|program": "Adlam",
  "Learn the Adlam script for writing Fulani with a modern West African alphabet.":
    "Apprenez l'écriture Adlam pour écrire le peul avec un alphabet moderne d'Afrique de l'Ouest.",
  "Swahili|program": "Swahili",
  "East African Swahili with authentic instruction.": "Le swahili d'Afrique de l'Est, avec un enseignement authentique.",
  "Yoruba|program": "Yoruba",
  "West African Yoruba with structured lessons.": "Le yoruba d'Afrique de l'Ouest, avec des leçons structurées.",
  "Amharic|program": "Amharique",
  "Horn of Africa Amharic with clear progression.": "L'amharique de la Corne de l'Afrique, avec une progression claire.",
  "Wolof|program": "Wolof",
  "West African Wolof for learners at any level.": "Le wolof d'Afrique de l'Ouest, pour les apprenants de tous niveaux.",
  "Hausa|program": "Haoussa",
  "Hausa across West and Central Africa.": "Le haoussa, parlé en Afrique de l'Ouest et en Afrique centrale.",

  // ------------------------------------ programs: English & literacy --
  "Grammar & vocabulary|program": "Grammaire et vocabulaire",
  "Master English grammar rules, sentence structure, and expand your vocabulary.":
    "Maîtrisez les règles de la grammaire anglaise et la structure des phrases, et enrichissez votre vocabulaire.",
  "Reading comprehension|program": "Compréhension écrite",
  "Develop critical reading skills and analyze texts across various genres.":
    "Développez une lecture critique et analysez des textes de genres variés.",
  "Creative writing|program": "Écriture créative",
  "Express yourself through stories, poetry, and creative narratives.":
    "Exprimez-vous à travers des histoires, de la poésie et des récits créatifs.",
  "Academic writing|program": "Rédaction académique",
  "Master essays, research papers, and formal academic composition.":
    "Maîtrisez la dissertation, les travaux de recherche et la rédaction académique.",
  "Literature analysis|program": "Analyse littéraire",
  "Explore classic and contemporary literature with in-depth analysis.":
    "Explorez la littérature classique et contemporaine grâce à une analyse approfondie.",
  "Test preparation|program": "Préparation aux examens",
  "Prepare for standardized tests including SAT, ACT, IELTS, and TOEFL.":
    "Préparez les tests standardisés, notamment le SAT, l'ACT, l'IELTS et le TOEFL.",

  // ------------------------------------------- programs: mathematics --
  "Elementary math|program": "Mathématiques du primaire",
  "Building a strong foundation in arithmetic, shapes, and problem-solving.":
    "Des bases solides en arithmétique, en géométrie et en résolution de problèmes.",
  "Pre-algebra & algebra|program": "Pré-algèbre et algèbre",
  "Mastering variables, equations, functions, and graphing.":
    "Maîtrisez les variables, les équations, les fonctions et les graphiques.",
  "Geometry|program": "Géométrie",
  "Exploring shapes, sizes, relative positions, and properties of space.":
    "Explorez les formes, les dimensions, les positions relatives et les propriétés de l'espace.",
  "Trigonometry|program": "Trigonométrie",
  "Understanding relationships between side lengths and angles of triangles.":
    "Comprenez les relations entre les longueurs des côtés et les angles des triangles.",
  "Calculus|program": "Calcul différentiel et intégral",
  "Limits, derivatives, integrals, and infinite series.": "Limites, dérivées, intégrales et séries infinies.",
  "Statistics|program": "Statistiques",
  "Analyzing data, probability, distributions, and inference.":
    "Analyse de données, probabilités, distributions et inférence.",

  // ----------------------------------- programs: coding & technology --
  "Coding for kids|program": "Programmation pour enfants",
  "Introduction to logic, algorithms, and creativity through Scratch and Python basics.":
    "Initiation à la logique, aux algorithmes et à la créativité avec Scratch et les bases de Python.",
  "Web development|program": "Développement web",
  "Build responsive websites using HTML, CSS, JavaScript, and modern frameworks.":
    "Créez des sites web adaptatifs avec HTML, CSS, JavaScript et des frameworks modernes.",
  "Mobile app development|program": "Développement d'applications mobiles",
  "Create iOS and Android apps with Flutter and Dart.": "Créez des applications iOS et Android avec Flutter et Dart.",
  "Python programming|program": "Programmation Python",
  "Data science, automation, and backend development with Python.":
    "Science des données, automatisation et développement backend avec Python.",
  "Game development|program": "Développement de jeux vidéo",
  "Design and code your own video games using Unity or Godot.":
    "Concevez et programmez vos propres jeux vidéo avec Unity ou Godot.",
  "Intro to computer science|program": "Introduction à l'informatique",
  "Preparation for AP Computer Science and university-level studies.":
    "Préparation à l'AP Computer Science et aux études universitaires.",

  // --------------------------------- programs: after-school tutoring --
  "Elementary (K-5)|program": "Primaire (K-5)",
  "Foundational support across subjects with caring tutors.":
    "Un accompagnement de base dans toutes les matières, avec des enseignants bienveillants.",
  "Middle school (6-8)|program": "Collège (6-8)",
  "Support through middle grades with structured study habits.":
    "Un accompagnement tout au long du collège, avec des habitudes de travail structurées.",
  "High school (9-12)|program": "Lycée (9-12)",
  "Rigorous support for high school courses and exams.":
    "Un accompagnement rigoureux pour les cours et les examens du lycée.",

  // -------------------------------------- programs: who each one suits --
  "All ages": "Tous âges",
  "Ages 7+": "Dès 7 ans",
  "Ages 8+": "Dès 8 ans",
  "Ages 10+": "Dès 10 ans",
  "Ages 12+": "Dès 12 ans",
  "Ages 7-12": "7 à 12 ans",
  "Global": "Monde entier",
  "West Africa": "Afrique de l'Ouest",
  "East Africa": "Afrique de l'Est",
  "Horn of Africa": "Corne de l'Afrique",
  "West and Central Africa": "Afrique de l'Ouest et centrale",
  "All levels": "Tous niveaux",
  "Elementary to advanced": "Débutant à avancé",
  "Grades K-5": "Classes K à 5",
  "Grades 3-12": "Classes 3 à 12",
  "Grades 6-8": "Classes 6 à 8",
  "Grades 6-9": "Classes 6 à 9",
  "Grades 8-10": "Classes 8 à 10",
  "Grades 9-12": "Classes 9 à 12",
  "Grades 10-11": "Classes 10 et 11",
  "Grades 11-12+": "Classes 11, 12 et plus",
  "High school & college": "Lycée et université",
  "High school": "Lycée",
  "Teens & adults": "Adolescents et adultes",
  "Teens": "Adolescents",
};
