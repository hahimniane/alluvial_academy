// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Académie Alluwal';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonEdit => 'Modifier';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonApply => 'Appliquer';

  @override
  String get commonOk => 'OK';

  @override
  String get commonYes => 'Oui';

  @override
  String get commonNo => 'Non';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonNext => 'Suivant';

  @override
  String get commonDone => 'Terminé';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonLoading => 'Chargement...';

  @override
  String get commonError => 'Erreur';

  @override
  String get commonSuccess => 'Succès';

  @override
  String get commonSearch => 'Rechercher';

  @override
  String get commonAll => 'Tous';

  @override
  String get commonNone => 'Aucun';

  @override
  String get commonView => 'Voir';

  @override
  String get commonSubmit => 'Soumettre';

  @override
  String get commonReset => 'Réinitialiser';

  @override
  String get commonClear => 'Effacer';

  @override
  String get commonRefresh => 'Actualiser';

  @override
  String get commonExport => 'Exporter';

  @override
  String get commonCopy => 'Copier';

  @override
  String get commonCopied => 'Copié !';

  @override
  String get commonNotSet => 'Non défini';

  @override
  String get commonUnknown => 'Inconnu';

  @override
  String get commonRequired => 'Obligatoire';

  @override
  String get commonOptional => 'Optionnel';

  @override
  String get loginWelcomeBack => 'Bon retour';

  @override
  String get loginSignInContinue => 'Connectez-vous pour continuer';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginStudentId => 'ID Étudiant';

  @override
  String get loginPassword => 'Mot de passe';

  @override
  String get loginSignIn => 'Se connecter';

  @override
  String get loginEnterStudentId => 'Entrez votre ID étudiant';

  @override
  String get loginEnterEmail => 'Entrez votre email';

  @override
  String get loginEnterPassword => 'Entrez votre mot de passe';

  @override
  String get loginFieldRequired => 'Ce champ est obligatoire';

  @override
  String get loginInvalidEmail => 'Veuillez entrer un email valide';

  @override
  String get loginPasswordRequired => 'Le mot de passe est obligatoire';

  @override
  String get loginAccountArchived =>
      'Votre compte a été archivé. Veuillez contacter un administrateur pour obtenir de l\'aide.';

  @override
  String get loginNoAccountStudentId =>
      'Aucun compte trouvé avec cet ID étudiant.';

  @override
  String get loginNoAccountEmail => 'Aucun compte trouvé avec cet email.';

  @override
  String get loginIncorrectPassword =>
      'Mot de passe incorrect. Veuillez réessayer.';

  @override
  String get loginInvalidEmailFormat =>
      'Veuillez entrer une adresse email valide.';

  @override
  String get loginAccountDisabled => 'Ce compte a été désactivé.';

  @override
  String get loginTooManyAttempts =>
      'Trop de tentatives échouées. Veuillez patienter et réessayer.';

  @override
  String get loginFailed => 'Échec de la connexion. Veuillez réessayer.';

  @override
  String get loginUnexpectedError => 'Une erreur inattendue s\'est produite.';

  @override
  String get loginAlluvialHub => 'Hub Éducatif Alluvial';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsViewProfile => 'Voir le profil';

  @override
  String get settingsHelpSupport => 'Aide et support';

  @override
  String get settingsTakeAppTour => 'Visite de l\'application';

  @override
  String get settingsLearnApp => 'Apprenez à utiliser l\'application';

  @override
  String get settingsSignOut => 'Déconnexion';

  @override
  String get settingsSignOutConfirm =>
      'Êtes-vous sûr de vouloir vous déconnecter ?';

  @override
  String get settingsPrivacyPolicy => 'Politique de confidentialité';

  @override
  String get settingsPrivacySubtitle => 'Comment nous protégeons vos données';

  @override
  String get settingsTheme => 'Thème';

  @override
  String get settingsThemeSubtitle => 'Changer l\'apparence de l\'application';

  @override
  String get settingsDarkMode => 'Mode sombre';

  @override
  String get settingsLightMode => 'Mode clair';

  @override
  String get settingsSystemMode => 'Système';

  @override
  String get profileHeader => 'PROFIL';

  @override
  String get profileEmail => 'Email';

  @override
  String get profilePhone => 'Téléphone';

  @override
  String get profileTimezone => 'Fuseau horaire';

  @override
  String get profileAbout => 'À propos';

  @override
  String get profileTitle => 'Titre';

  @override
  String get profileBio => 'Biographie';

  @override
  String get profileExperience => 'Expérience';

  @override
  String get profileSpecialties => 'Spécialités';

  @override
  String get profileEditProfile => 'Modifier le profil';

  @override
  String get profileCompleteProfile => 'Complétez votre profil';

  @override
  String get profileHelpParents =>
      'Aidez les parents et les étudiants à découvrir votre expertise';

  @override
  String get profileFullName => 'Nom complet';

  @override
  String get profileProfessionalTitle => 'Titre professionnel';

  @override
  String get profileBiography => 'Biographie';

  @override
  String get profileYearsExperience => 'Années d\'expérience';

  @override
  String get profileEducationCerts => 'Formation et certifications';

  @override
  String get profileSaving => 'Enregistrement...';

  @override
  String get profileSaveProfile => 'Enregistrer le profil';

  @override
  String get profileSavedSuccess => 'Profil enregistré avec succès !';

  @override
  String profilePercentComplete(int percent) {
    return 'Profil complété à $percent%';
  }

  @override
  String get appSettingsHeader => 'PARAMÈTRES DE L\'APP';

  @override
  String get supportHeader => 'ASSISTANCE';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsSubtitle => 'Gérer les préférences de notification';

  @override
  String get languageTitle => 'Langue';

  @override
  String get selectLanguageTitle => 'Choisir la langue';

  @override
  String get languageEnglish => 'Anglais';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageArabic => 'Arabe';

  @override
  String get navHome => 'Accueil';

  @override
  String get navShifts => 'Cours';

  @override
  String get navChat => 'Chat';

  @override
  String get navForms => 'Forms';

  @override
  String get navJobs => 'Emplois';

  @override
  String get navClasses => 'Classes';

  @override
  String get navNotify => 'Alertes';

  @override
  String get navUsers => 'Comptes';

  @override
  String get navTasks => 'Tâches';

  @override
  String get navQuiz => 'Quiz';

  @override
  String get navDashboard => 'Tableau de bord';

  @override
  String get navTimeClock => 'Pointage';

  @override
  String get navSchedule => 'Emploi du temps';

  @override
  String get greetingMorning => 'Bonjour';

  @override
  String get greetingAfternoon => 'Bon après-midi';

  @override
  String get greetingEvening => 'Bonsoir';

  @override
  String get dashboardThisWeek => 'Cette semaine';

  @override
  String get dashboardClasses => 'Cours';

  @override
  String get dashboardApproved => 'Approuvé';

  @override
  String get dashboardToday => 'Aujourd\'hui';

  @override
  String get dashboardWeek => 'Semaine';

  @override
  String get dashboardMonth => 'Mois';

  @override
  String get dashboardQuickAccess => 'Accès rapide';

  @override
  String get dashboardMyForms => 'Mes formulaires';

  @override
  String get dashboardAssignments => 'Devoirs';

  @override
  String get dashboardIslamicResources => 'Ressources islamiques';

  @override
  String get dashboardActiveSession => 'Session active';

  @override
  String get dashboardInProgress => 'EN COURS';

  @override
  String get dashboardViewSession => 'Voir la session';

  @override
  String get dashboardMyTasks => 'Mes tâches';

  @override
  String get dashboardSeeAll => 'Voir tout';

  @override
  String dashboardDueDate(String date) {
    return 'Échéance $date';
  }

  @override
  String get dashboardNextClass => 'Prochain cours';

  @override
  String get dashboardTomorrow => 'Demain';

  @override
  String get dashboardNoUpcomingClasses => 'Aucun cours à venir';

  @override
  String get dashboardEnjoyFreeTime => 'Profitez de votre temps libre !';

  @override
  String readinessFormRequired(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count formulaires de préparation requis',
      one: '1 formulaire de préparation requis',
    );
    return '$_temp0';
  }

  @override
  String get readinessFormComplete =>
      'Complétez vos formulaires des cours récents';

  @override
  String get readinessFormPending => 'Formulaires de préparation en attente';

  @override
  String get readinessFormSelectShift =>
      'Sélectionnez un cours pour remplir son formulaire';

  @override
  String get readinessFormAllComplete =>
      'Tous les formulaires sont complétés !';

  @override
  String get clockInNow => 'Pointer maintenant';

  @override
  String get clockOut => 'Dépointer';

  @override
  String get clockInProgram => 'Programmer le pointage';

  @override
  String get clockInProgrammed => 'Programmé...';

  @override
  String get clockInCancelProgramming => 'Annuler la programmation';

  @override
  String clockInAvailableIn(String time) {
    return 'Pointage disponible dans $time';
  }

  @override
  String get clockInTooEarly =>
      'Trop tôt pour pointer. Veuillez attendre la fenêtre de programmation (1 minute avant le cours).';

  @override
  String clockInStartingIn(String time) {
    return 'Début dans $time';
  }

  @override
  String clockInProgrammedFor(String time) {
    return 'Pointage programmé pour $time';
  }

  @override
  String get clockInClockingIn => 'Pointage en cours...';

  @override
  String get clockInCancelled => 'Programmation annulée';

  @override
  String get clockInNotAuthenticated => 'Non authentifié';

  @override
  String get clockInLocationUnavailable =>
      'Pointage automatique - localisation indisponible';

  @override
  String get clockInLocationError =>
      'Impossible d\'obtenir la localisation. Veuillez activer les services de localisation.';

  @override
  String get clockInAutoSuccess => 'Pointage automatique réussi !';

  @override
  String get clockInSuccess => 'Pointage réussi !';

  @override
  String get clockInFailed => 'Échec du pointage';

  @override
  String get clockOutSuccess => 'Dépointage réussi !';

  @override
  String get clockOutFailed => 'Échec du dépointage';

  @override
  String get shiftStudent => 'Étudiant';

  @override
  String get shiftStudents => 'Étudiants';

  @override
  String shiftStudentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Étudiants',
      one: '1 Étudiant',
    );
    return '$_temp0';
  }

  @override
  String get shiftTeacher => 'Professeur';

  @override
  String get shiftSubject => 'Matière';

  @override
  String get shiftSchedule => 'Emploi du temps';

  @override
  String get shiftDuration => 'Durée';

  @override
  String get shiftHours => 'heures';

  @override
  String get shiftHrs => 'h';

  @override
  String get shiftMinutes => 'min';

  @override
  String get shiftMissed => 'Manqué';

  @override
  String get shiftCompleted => 'Terminé';

  @override
  String get shiftCancelled => 'Annulé';

  @override
  String get shiftScheduled => 'Planifié';

  @override
  String get shiftActive => 'Actif';

  @override
  String get shiftUpcoming => 'À venir';

  @override
  String get shiftPartial => 'Partiel';

  @override
  String get shiftReady => 'Prêt';

  @override
  String get shiftNoShiftsToday => 'Pas de cours ce jour';

  @override
  String get shiftEnjoyFreeTime =>
      'Profitez de votre temps libre ou consultez les cours disponibles.';

  @override
  String get shiftDetails => 'Détails du cours';

  @override
  String get shiftViewDetails => 'Voir les détails';

  @override
  String get shiftEditShift => 'Modifier le cours';

  @override
  String get shiftReschedule => 'Reprogrammer le cours';

  @override
  String shiftFilterHint(String name, int count) {
    return 'Cours de $name. Utilisez ← → ci-dessus pour d\'autres semaines, ou passez en Liste pour faire défiler les $count cours';
  }

  @override
  String get shiftReassignTeacher => 'Réaffecter à un autre enseignant';

  @override
  String get shiftReassignTitle => 'Réaffecter le cours';

  @override
  String shiftReassignConfirm(String teacherName) {
    return 'Êtes-vous sûr de vouloir réaffecter ce cours à $teacherName ?';
  }

  @override
  String get shiftReassignSuccess => 'Cours réaffecté avec succès';

  @override
  String get shiftReassignError => 'Échec de la réaffectation du cours';

  @override
  String get shiftSelectTeacher => 'Sélectionner un enseignant';

  @override
  String get shiftSearchTeacher => 'Rechercher des enseignants...';

  @override
  String get shiftNoTeachersFound => 'Aucun enseignant trouvé';

  @override
  String shiftOriginalTeacher(String teacherName) {
    return 'Original : $teacherName';
  }

  @override
  String get shiftReportIssue => 'Signaler un problème';

  @override
  String get shiftDate => 'Date';

  @override
  String get shiftTime => 'Heure du cours';

  @override
  String get shiftStartTime => 'Heure de début';

  @override
  String get shiftEndTime => 'Heure de fin';

  @override
  String get shiftHourlyRate => 'Taux horaire';

  @override
  String get shiftNotes => 'Notes';

  @override
  String get shiftAddNotes => 'Ajouter des notes...';

  @override
  String get chatMessages => 'Messages';

  @override
  String get chatConnectTeam =>
      'Connectez-vous et collaborez avec votre équipe';

  @override
  String get chatRecentChats => 'Récents';

  @override
  String get chatMyContacts => 'Contacts';

  @override
  String get chatSearchConversations =>
      'Rechercher des conversations et utilisateurs...';

  @override
  String get chatNoConversations => 'Aucune conversation';

  @override
  String get chatStartConversation =>
      'Commencez une conversation en parcourant tous les utilisateurs';

  @override
  String get chatNoChatsFound => 'Aucune conversation trouvée';

  @override
  String get chatTryDifferentSearch => 'Essayez un autre terme de recherche';

  @override
  String get chatNoContactsAvailable => 'Aucun contact disponible';

  @override
  String get chatContactsAppearHere =>
      'Vos professeurs, étudiants ou administrateurs apparaîtront ici selon vos cours';

  @override
  String get chatNoContactsMatch =>
      'Aucun contact ne correspond à votre recherche';

  @override
  String get chatCreateGroup => 'Créer un groupe';

  @override
  String get chatOnline => 'En ligne';

  @override
  String get chatOffline => 'Hors ligne';

  @override
  String chatLastSent(String time) {
    return 'Dernier envoi $time';
  }

  @override
  String get chatTypeMessage => 'Tapez un message...';

  @override
  String chatReplyTo(String name) {
    return 'Répondre à $name...';
  }

  @override
  String get chatPhoto => 'Photo';

  @override
  String get chatCamera => 'Appareil photo';

  @override
  String get chatDocument => 'Document';

  @override
  String get chatLocation => 'Position';

  @override
  String get chatRecording => 'Enregistrement';

  @override
  String get chatHoldToRecord => 'Maintenez pour enregistrer un message vocal';

  @override
  String get chatVoiceMessage => 'Message vocal';

  @override
  String chatStartConversationWith(String name) {
    return 'Envoyez un message pour commencer à discuter avec $name';
  }

  @override
  String get chatDeleteMessage => 'Supprimer le message';

  @override
  String get chatDeleteMessageConfirm =>
      'Êtes-vous sûr de vouloir supprimer ce message ?';

  @override
  String get chatClearChat => 'Effacer la conversation';

  @override
  String get chatClearChatConfirm =>
      'Êtes-vous sûr de vouloir effacer cette conversation ? Cette action est irréversible.';

  @override
  String get chatBlockUser => 'Bloquer l\'utilisateur';

  @override
  String chatBlockUserConfirm(String name) {
    return 'Êtes-vous sûr de vouloir bloquer $name ? Il ne pourra plus vous envoyer de messages.';
  }

  @override
  String get chatGroupInfo => 'Informations du groupe';

  @override
  String get chatAddMembers => 'Ajouter des membres';

  @override
  String get chatReact => 'Réagir';

  @override
  String get chatReply => 'Répondre';

  @override
  String get chatForward => 'Transférer';

  @override
  String get chatCopied => 'Message copié dans le presse-papiers';

  @override
  String get chatSendingImage => 'Envoi de l\'image...';

  @override
  String get chatImageSent => 'Image envoyée !';

  @override
  String get chatSendingFile => 'Envoi du fichier...';

  @override
  String get chatFileSent => 'Fichier envoyé !';

  @override
  String get chatLocationComingSoon => 'Partage de position bientôt disponible';

  @override
  String get chatFailedSendAttachment => 'Échec de l\'envoi de la pièce jointe';

  @override
  String get chatFailedSendImage => 'Échec de l\'envoi de l\'image';

  @override
  String get chatFailedSendFile => 'Échec de l\'envoi du fichier';

  @override
  String get chatFailedSendVoice => 'Échec de l\'envoi du message vocal';

  @override
  String get chatFailedStartRecording =>
      'Échec du démarrage de l\'enregistrement';

  @override
  String get chatMicPermissionRequired =>
      'L\'autorisation du microphone est requise';

  @override
  String get chatRecordingTooShort => 'Enregistrement trop court';

  @override
  String get chatNoPermissionMessage =>
      'Vous n\'avez pas la permission d\'envoyer un message à cet utilisateur';

  @override
  String get chatTeachingRelationshipOnly =>
      'Vous ne pouvez envoyer des messages qu\'aux utilisateurs avec lesquels vous avez une relation d\'enseignement';

  @override
  String get chatGroupCallsNotSupported =>
      'Les appels de groupe ne sont pas encore pris en charge';

  @override
  String get chatErrorLoadingMessages =>
      'Erreur lors du chargement des messages';

  @override
  String get chatGroupCreateTitle => 'Créer un groupe';

  @override
  String get chatGroupAddMembers =>
      'Ajouter des membres et créer une conversation de groupe';

  @override
  String get chatGroupSetNameDesc =>
      'Définissez un nom et une description pour votre groupe';

  @override
  String get chatGroupSelectMembers =>
      'Sélectionnez les utilisateurs à ajouter au groupe';

  @override
  String chatGroupMembersSelected(int count) {
    return '$count membre(s) sélectionné(s)';
  }

  @override
  String get chatGroupName => 'Nom du groupe *';

  @override
  String get chatGroupDescription => 'Description (Optionnel)';

  @override
  String get chatGroupEnterName => 'Entrez le nom du groupe';

  @override
  String get chatGroupEnterDesc => 'Entrez la description du groupe';

  @override
  String get chatGroupSearchUsers => 'Rechercher des utilisateurs...';

  @override
  String get chatGroupCreate => 'Créer';

  @override
  String get chatGroupNoUsers => 'Aucun utilisateur disponible';

  @override
  String get chatGroupNoUsersFound => 'Aucun utilisateur trouvé';

  @override
  String chatGroupCreatedSuccess(String name) {
    return 'Groupe \"$name\" créé avec succès !';
  }

  @override
  String get chatGroupCreateFailed =>
      'Échec de la création du groupe. Veuillez réessayer.';

  @override
  String get chatGroupAdminsOnly =>
      'Seuls les administrateurs peuvent créer des conversations de groupe';

  @override
  String get roleAdmin => 'Administrateur';

  @override
  String get roleTeacher => 'Professeur';

  @override
  String get roleStudent => 'Étudiant';

  @override
  String get roleParent => 'Parent';

  @override
  String get roleUser => 'Utilisateur';

  @override
  String get timeJustNow => 'à l\'instant';

  @override
  String timeMinutesAgo(int count) {
    return 'il y a $count min';
  }

  @override
  String timeHoursAgo(int count) {
    return 'il y a $count h';
  }

  @override
  String timeDaysAgo(int count) {
    return 'il y a $count jours';
  }

  @override
  String get timeYesterday => 'Hier';

  @override
  String get formClassReport => 'Rapport de cours';

  @override
  String get formSkip => 'Passer';

  @override
  String get formSubmitReport => 'Soumettre le rapport';

  @override
  String get formAutoFilled => 'Rempli automatiquement (pas besoin de saisir)';

  @override
  String get formVerifyDuration => 'Vérifier la durée';

  @override
  String get formBillableHours => 'Heures facturables';

  @override
  String get formSelectOption => 'Sélectionnez une option';

  @override
  String get formSubmittedSuccess => 'Rapport de cours soumis avec succès !';

  @override
  String get formMySubmissions => 'Mes soumissions de formulaires';

  @override
  String get formAllTime => 'Tout le temps';

  @override
  String get formSelectMonth => 'Sélectionner le mois';

  @override
  String get formCurrentMonth => 'Actuel';

  @override
  String get formSubmission => 'soumission';

  @override
  String get formSubmissions => 'soumissions';

  @override
  String get formThisMonth => 'ce mois-ci';

  @override
  String get formViewAll => 'Voir tout';

  @override
  String get formSearchByName => 'Rechercher par nom de formulaire ou statut';

  @override
  String get formNoSubmissionsYet => 'Aucune soumission de formulaire';

  @override
  String get adminAllSubmissionsTitle => 'Toutes les soumissions (Admin)';

  @override
  String get adminSubmissionsTotal => 'Total';

  @override
  String get adminSubmissionsTeachers => 'Enseignants';

  @override
  String get adminSubmissionsCompleted => 'Complétées';

  @override
  String get adminSubmissionsPending => 'En attente';

  @override
  String get adminSubmissionsSearchPlaceholder =>
      'Rechercher par enseignant ou formulaire...';

  @override
  String get adminSubmissionsTeachersAll => 'Enseignants (tous)';

  @override
  String get adminSubmissionsFilterTeachers => 'Enseignants';

  @override
  String get adminSubmissionsFilterMonth => 'Mois';

  @override
  String get adminSubmissionsFilterStatus => 'Statut';

  @override
  String get adminSubmissionsAllTime => 'Tout';

  @override
  String get adminSubmissionsAllStatus => 'Tous les statuts';

  @override
  String get adminSubmissionsAllForms => 'Tous les formulaires';

  @override
  String get adminSubmissionsFilterByForm => 'Filtrer par formulaire';

  @override
  String get adminSubmissionsClearFilters => 'Tout effacer';

  @override
  String get adminSubmissionsViewByForm => 'Par formulaire';

  @override
  String get adminSubmissionsViewByTeacher => 'Par enseignant';

  @override
  String get adminSubmissionsSelectTeachers => 'Sélectionner les enseignants';

  @override
  String get adminSubmissionsSelectMonth => 'Sélectionner le mois';

  @override
  String get adminSubmissionsFilterByStatus => 'Filtrer par statut';

  @override
  String get adminSubmissionsSelectAll => 'Tout sélectionner';

  @override
  String get adminSubmissionsClearAll => 'Tout effacer';

  @override
  String get adminSubmissionsFavoritesOnly => 'Favoris uniquement';

  @override
  String get adminSubmissionsApply => 'Appliquer';

  @override
  String get adminSubmissionsNoSubmissions => 'Aucune soumission trouvée';

  @override
  String get adminSubmissionsTryAdjustingFilters =>
      'Essayez d\'ajuster les filtres';

  @override
  String get adminSubmissionsAddToFavorites => 'Ajouter aux favoris';

  @override
  String get adminSubmissionsLoadMore => 'Charger plus';

  @override
  String get adminSubmissionsLoadOtherForms => 'Charger les autres formulaires';

  @override
  String get adminSubmissionsPriorityForm => 'Formulaire prioritaire';

  @override
  String get adminSubmissionsGroupedByTeacher => 'Par enseignant';

  @override
  String adminSubmissionsCount(int count) {
    return '$count soumission(s)';
  }

  @override
  String adminSubmissionsShiftDetail(String date, String students) {
    return '$date • $students';
  }

  @override
  String get adminSubmissionsGeneralUnknown => 'Général / Inconnu';

  @override
  String get formDefaultTitle => 'Formulaire';

  @override
  String get adminPreferencesTitle => 'Préférences admin';

  @override
  String get adminPreferencesDefaultViewMode => 'Vue par défaut';

  @override
  String get adminPreferencesByTeacher => 'Par enseignant';

  @override
  String get adminPreferencesByForm => 'Par formulaire';

  @override
  String get adminPreferencesShowAllMonthsDefault =>
      'Afficher tous les mois par défaut';

  @override
  String get adminPreferencesFavoriteTeachers => 'Enseignants favoris';

  @override
  String get adminPreferencesSaved => 'Préférences enregistrées';

  @override
  String adminPreferencesFavoriteCount(int count) {
    return '$count enseignant(s) en favori';
  }

  @override
  String get adminPreferencesUseStarHint =>
      'Utilisez l\'étoile sur les cartes pour ajouter aux favoris';

  @override
  String get adminPreferencesDefaultTeachersHint =>
      'Les enseignants favoris sont affichés par défaut. Effacez le filtre enseignant pour voir toutes les soumissions.';

  @override
  String get formNoResults => 'Aucun résultat trouvé';

  @override
  String get formSubmittedFormsAppear =>
      'Vos formulaires soumis apparaîtront ici';

  @override
  String get formTryAdjustingSearch => 'Essayez d\'ajuster votre recherche';

  @override
  String get formCompleted => 'Terminé';

  @override
  String get formDraft => 'Brouillon';

  @override
  String get formPending => 'En attente';

  @override
  String formSubmittedOn(String date) {
    return 'Soumis le $date';
  }

  @override
  String get formResponses => 'réponses';

  @override
  String get formTapToView => 'Appuyez pour voir';

  @override
  String get formReadOnly => 'Lecture seule';

  @override
  String get formNoAnswer => '(Pas de réponse)';

  @override
  String get formQuestion => 'Question';

  @override
  String get timesheetTitle => 'Feuille de temps';

  @override
  String get timesheetMyTimesheet => 'Ma feuille de temps';

  @override
  String get timesheetDate => 'Date';

  @override
  String get timesheetStart => 'Début';

  @override
  String get timesheetEnd => 'Fin';

  @override
  String timesheetTotalHours(Object hours) {
    return 'Total des heures : $hours';
  }

  @override
  String get timesheetClockInLocation => 'Lieu de pointage';

  @override
  String get timesheetClockOutLocation => 'Lieu de dépointage';

  @override
  String get timesheetStatus => 'Statut';

  @override
  String get timesheetActions => 'Actions';

  @override
  String get timesheetDraft => 'Brouillon';

  @override
  String get timesheetPending => 'En attente';

  @override
  String get timesheetApproved => 'Approuvé';

  @override
  String get timesheetRejected => 'Rejeté';

  @override
  String get timesheetAll => 'Tous';

  @override
  String get timesheetThisWeek => 'Cette semaine';

  @override
  String get timesheetThisMonth => 'Ce mois-ci';

  @override
  String get timesheetAllTime => 'Tout le temps';

  @override
  String get timesheetNoEntries => 'Aucune entrée de feuille de temps';

  @override
  String get timesheetClockInFirst =>
      'Pointez pour créer votre première entrée';

  @override
  String get timesheetSubmit => 'Soumettre';

  @override
  String get timesheetSubmitForReview => 'Soumettre pour révision';

  @override
  String get timesheetSubmitConfirm =>
      'Soumettre cette feuille de temps pour révision ?';

  @override
  String get timesheetSubmitNote =>
      'Une fois soumise, vous ne pourrez pas modifier cette entrée jusqu\'à sa révision.';

  @override
  String get timesheetSubmittedSuccess =>
      'Feuille de temps soumise pour révision !';

  @override
  String get timesheetEditTimesheet => 'Modifier la feuille de temps';

  @override
  String get timesheetEditNote =>
      'Les modifications seront soumises à l\'approbation de l\'administrateur.';

  @override
  String get timesheetApprovedLocked =>
      'Cette feuille de temps a été approuvée et ne peut plus être modifiée';

  @override
  String get timesheetClockInTime => 'Heure de pointage';

  @override
  String get timesheetClockOutTime => 'Heure de dépointage';

  @override
  String get timesheetPaymentCalculation => 'Calcul du paiement';

  @override
  String get timesheetProvideReason =>
      'Veuillez fournir une raison pour la modification';

  @override
  String get timesheetProvideMoreDetails =>
      'Veuillez fournir plus de détails (au moins 10 caractères)';

  @override
  String get timesheetSaveChanges => 'Enregistrer les modifications';

  @override
  String get timesheetUpdatedSuccess =>
      'Feuille de temps mise à jour. En attente d\'approbation.';

  @override
  String get timesheetDetails => 'Détails de l\'entrée';

  @override
  String get timesheetLocationLoading => 'Chargement de la position...';

  @override
  String get timesheetLocationUnavailable => 'Position non disponible';

  @override
  String get timesheetLocationNotCaptured => 'Non capturé';

  @override
  String get userManagementTitle => 'Gestion des utilisateurs';

  @override
  String get userSearchUsers => 'Rechercher des utilisateurs...';

  @override
  String userUsersCount(int count) {
    return '$count utilisateurs';
  }

  @override
  String get userActive => 'actif';

  @override
  String get userInactive => 'Inactif';

  @override
  String get userNoUsersFound => 'Aucun utilisateur trouvé';

  @override
  String get userFilterUsers => 'Filtrer les utilisateurs';

  @override
  String get userRole => 'Rôle';

  @override
  String get userStatus => 'Statut';

  @override
  String get userApplyFilters => 'Appliquer les filtres';

  @override
  String get userViewCredentials => 'Voir les identifiants';

  @override
  String get userStudentIdPassword => 'ID Étudiant et mot de passe';

  @override
  String get userDeactivateUser => 'Désactiver l\'utilisateur';

  @override
  String get userActivateUser => 'Activer l\'utilisateur';

  @override
  String get userPromoteToAdmin => 'Promouvoir administrateur';

  @override
  String get userEditUser => 'Modifier l\'utilisateur';

  @override
  String get userDeleteUser => 'Supprimer l\'utilisateur';

  @override
  String get userLoginCredentials => 'Identifiants de connexion';

  @override
  String get userEmailForApp => 'Email (pour l\'app)';

  @override
  String get userStudentLoginNote =>
      'Les étudiants se connectent avec leur ID et mot de passe';

  @override
  String get userResetPassword => 'Réinitialiser le mot de passe';

  @override
  String get userPasswordReset => 'Réinitialisation du mot de passe';

  @override
  String userNewPasswordFor(Object name) {
    return 'Nouveau mot de passe pour $name :';
  }

  @override
  String get userEmailSentToParent =>
      'Email envoyé au parent avec les nouveaux identifiants';

  @override
  String get userShareCredentials =>
      'Partagez ce mot de passe avec l\'étudiant ou son parent.';

  @override
  String get userPasswordNotStored => 'Mot de passe non stocké';

  @override
  String userResetPasswordFor(String name) {
    return 'Réinitialiser le mot de passe pour $name';
  }

  @override
  String get userCustomPassword => 'Mot de passe personnalisé (optionnel)';

  @override
  String get userLeaveBlankGenerate =>
      'Laissez vide pour générer un mot de passe';

  @override
  String get userPasswordMinChars =>
      'Min 6 caractères. Évitez les espaces au début/fin.';

  @override
  String get userPasswordGenerateNote =>
      'Si laissé vide, un mot de passe sécurisé sera généré.';

  @override
  String get userParentEmailNote =>
      'Si l\'étudiant a un parent lié, il recevra un email avec les nouveaux identifiants.';

  @override
  String get userPasswordNoSpaces =>
      'Le mot de passe ne peut pas commencer ou finir par des espaces';

  @override
  String get userPasswordMinLength =>
      'Le mot de passe doit contenir au moins 6 caractères';

  @override
  String get userPasswordMaxLength =>
      'Le mot de passe doit contenir 128 caractères maximum';

  @override
  String get userResettingPassword => 'Réinitialisation en cours...';

  @override
  String get userArchived => 'Utilisateur archivé';

  @override
  String get userRestored => 'Utilisateur restauré';

  @override
  String userPromoteConfirm(Object name) {
    return 'Voulez-vous vraiment promouvoir $name à admin ?';
  }

  @override
  String get userPromote => 'Promouvoir';

  @override
  String get userPromotedSuccess => 'Utilisateur promu administrateur';

  @override
  String get userCannotDeleteSelf =>
      'Vous ne pouvez pas supprimer votre propre compte.';

  @override
  String userDeleteConfirm(String name) {
    return 'Voulez-vous vraiment supprimer définitivement cet utilisateur ?';
  }

  @override
  String get userDeleteCannotUndo => 'Cette action est irréversible.';

  @override
  String get userDeleteTeacherClasses =>
      'Supprimer également les cours de ce professeur';

  @override
  String get userDeleteStudentClasses =>
      'Supprimer également les cours de cet étudiant';

  @override
  String get userGroupClassesRemain =>
      'Les cours de groupe resteront pour les autres étudiants.';

  @override
  String userDeletedSuccess(Object name) {
    return '$name a été définitivement supprimé';
  }

  @override
  String get userDeleteFailed => 'Échec de la suppression.';

  @override
  String get userAddNewUsers => 'Ajouter de nouveaux utilisateurs';

  @override
  String get userCreateAccounts =>
      'Créez des comptes utilisateurs et attribuez des rôles';

  @override
  String get userFirstName => 'Prénom';

  @override
  String get userLastName => 'Nom';

  @override
  String get userEmail => 'Adresse email';

  @override
  String get userPhone => 'Numéro de téléphone';

  @override
  String get userUserType => 'Type d\'utilisateur';

  @override
  String get userKioskCode => 'Code kiosque';

  @override
  String get userJobTitle => 'Titre du poste';

  @override
  String get userCountryCode => 'Indicatif pays';

  @override
  String get userAdult => 'Adulte';

  @override
  String get userMinor => 'Mineur';

  @override
  String get userSelectParent => 'Sélectionner le parent/tuteur';

  @override
  String get userNoParentsFound => 'Aucun parent trouvé';

  @override
  String get userCreateParentFirst => 'Créez d\'abord un parent';

  @override
  String get userStudentLoginPreview => 'Aperçu des identifiants';

  @override
  String get userReviewCredentials =>
      'Vérifiez les identifiants avant de créer le compte';

  @override
  String get userStudentInfo => 'Informations de l\'étudiant';

  @override
  String get userName => 'Nom';

  @override
  String get userType => 'Type';

  @override
  String get userAdultStudent => 'Étudiant adulte';

  @override
  String get userMinorStudent => 'Étudiant mineur';

  @override
  String get userGuardian => 'Tuteur';

  @override
  String get userStudentId => 'ID Étudiant';

  @override
  String get userLoginEmail => 'Email de connexion';

  @override
  String get userCreateAccount => 'Créer le compte';

  @override
  String get helpNeedHelp => 'Besoin d\'aide ? Nous sommes là pour vous.';

  @override
  String get helpEmailSupport => 'Support par email';

  @override
  String get helpLiveChat => 'Chat en direct';

  @override
  String get helpAvailableHours => 'Disponible 9h - 17h';

  @override
  String get errorSomethingWentWrong => 'Oups ! Une erreur s\'est produite';

  @override
  String get errorTryAgain => 'Réessayer';

  @override
  String get errorLoadingData => 'Erreur lors du chargement des données';

  @override
  String get errorSavingData => 'Erreur lors de l\'enregistrement';

  @override
  String get errorNetworkError => 'Erreur réseau. Vérifiez votre connexion.';

  @override
  String get errorUnauthorized =>
      'Vous n\'êtes pas autorisé à effectuer cette action.';

  @override
  String get errorNotFound => 'L\'élément demandé n\'a pas été trouvé.';

  @override
  String get errorAccessDenied => 'Accès refusé';

  @override
  String get errorPleaseSignIn => 'Veuillez vous connecter';

  @override
  String get errorAuthRequired => 'Authentification requise';

  @override
  String get jobNewStudentOpportunities =>
      'Nouvelles opportunités d\'étudiants';

  @override
  String get jobAcceptNewStudents =>
      'Acceptez de nouveaux étudiants pour remplir votre emploi du temps';

  @override
  String get jobNoOpportunities => 'Aucune opportunité pour le moment';

  @override
  String get jobFilledOpportunities => 'Opportunités pourvues';

  @override
  String get jobFilled => 'POURVU';

  @override
  String jobAge(String age) {
    return 'Âge : $age';
  }

  @override
  String jobSubject(String subject) {
    return 'Matière : $subject';
  }

  @override
  String jobGrade(String grade) {
    return 'Niveau : $grade';
  }

  @override
  String jobTimezone(String timezone) {
    return 'Fuseau horaire : $timezone';
  }

  @override
  String get jobPreferredTimes => 'Horaires préférés :';

  @override
  String jobDays(String days) {
    return 'Jours : $days';
  }

  @override
  String jobTimes(String times) {
    return 'Heures : $times';
  }

  @override
  String jobAcceptedOn(String date) {
    return 'Accepté le $date';
  }

  @override
  String get jobAlreadyFilled => 'Déjà pourvu';

  @override
  String get jobAcceptStudent => 'Accepter l\'étudiant';

  @override
  String get jobAcceptedSuccess =>
      'Emploi accepté ! L\'administrateur finalisera l\'emploi du temps et vous contactera.';

  @override
  String get zeroResults => '0 Résultats';

  @override
  String get time1000Am => '10h00';

  @override
  String get time1200Pm => '12h00';

  @override
  String get aComputer => 'Un ordinateur';

  @override
  String get aNewVersionOfAlluvialAcademy =>
      'Une nouvelle version de l\'Académie alluviale';

  @override
  String get aNewVersionOfAlluvialAcademy2 =>
      'Une nouvelle version de l\'Académie alluviale2';

  @override
  String get aPhone => 'Un téléphone';

  @override
  String get aTablet => 'Un comprimé';

  @override
  String get abilityToSwitchBetweenAdminAnd =>
      'Possibilité de changer d\'administrateur et';

  @override
  String get about35OrLess => 'Environ 35 ou moins';

  @override
  String get about50OrMore => 'Environ 50 ou plus';

  @override
  String get accessRestricted => 'Accès restreint';

  @override
  String get accessToUserManagementAndSystem =>
      'Accès à la gestion et au système des utilisateurs';

  @override
  String get account => 'Compte';

  @override
  String get accountNotSetUp => 'Compte non configuré';

  @override
  String get accountSettingsBuildInfo =>
      'Configuration du compte Construisez l\'information';

  @override
  String get actionFeatureComingSoon => 'Une fonctionnalité d\'action à venir';

  @override
  String get active => 'Activité';

  @override
  String get activeForms => 'Formulaires actifs';

  @override
  String get activeTemplateUpdated => 'Modèle actif mis à jour';

  @override
  String get activeUsers => 'Usagers actifs';

  @override
  String get activityWillAppearHereAsYour =>
      'L\'activité apparaîtra ici comme votre';

  @override
  String get actualPaymentsBackgroundLoad => 'Paiements réels Charge de base';

  @override
  String get add => 'Ajouter';

  @override
  String get addAndManageSubjectsForShifts =>
      'Ajouter et gérer des sujets pour les postes';

  @override
  String get addAnotherShift => 'Ajouter un autre quart de travail';

  @override
  String get addAnotherShift2 => 'Ajouter un autre Maj2';

  @override
  String get addAnotherStudent => 'Ajouter un autre élève';

  @override
  String get addAnotherTask => 'Ajouter une autre tâche';

  @override
  String get addAnotherUser => 'Ajouter un autre utilisateur';

  @override
  String get addAnyAdditionalNotesOrInstructions =>
      'Ajouter des notes ou instructions supplémentaires';

  @override
  String get addAnyCommentsOrCorrections =>
      'Ajouter des commentaires ou des corrections';

  @override
  String get addAssignment => 'Ajouter une tâche';

  @override
  String get addAtLeastOneField => 'Ajouter au moins un champ';

  @override
  String get addDate => 'Ajouter une date';

  @override
  String get addDetailsSubtasksOrFiles =>
      'Ajouter les détails Sous-tâches ou fichiers';

  @override
  String get addField => 'Ajouter un champ';

  @override
  String get addFile => 'Ajouter un fichier';

  @override
  String get addFilesToShareResourcesOr =>
      'Ajouter des fichiers pour partager des ressources ou';

  @override
  String get addFirstRate => 'Ajouter le premier taux';

  @override
  String get addImage => 'Ajouter une image';

  @override
  String get addLabel => 'Ajouter une étiquette';

  @override
  String get addLocation => 'Ajouter un emplacement';

  @override
  String get addLocationTags => 'Ajouter des étiquettes d\'emplacement';

  @override
  String get addMoreDetailsAboutThisTask =>
      'Ajouter plus de détails sur cette tâche';

  @override
  String get addMultipleTasks => 'Ajouter plusieurs tâches';

  @override
  String get addMultipleTasksInOneGo =>
      'Ajouter plusieurs tâches en une seule fois';

  @override
  String get addNewSubject => 'Ajouter un nouveau sujet';

  @override
  String get addNote => 'Ajouter une note';

  @override
  String get addOption => 'Ajouter une option';

  @override
  String get addOption2 => 'Ajouter l\'option2';

  @override
  String get addQuestion => 'Ajouter une question';

  @override
  String get addSection => 'Ajouter une section';

  @override
  String get addSingleTask => 'Ajouter une seule tâche';

  @override
  String get addSubject => 'Ajouter un sujet';

  @override
  String get addTag => 'Ajouter une étiquette';

  @override
  String get addTag2 => 'Ajouter une étiquette2';

  @override
  String get addTask => 'Ajouter une tâche';

  @override
  String get addTask2 => 'Ajouter la tâche2';

  @override
  String get addTitle => 'Ajouter le titre';

  @override
  String get addUsers => 'Ajouter des utilisateurs';

  @override
  String get addVideo => 'Ajouter une vidéo';

  @override
  String get additionalInformation => 'Informations complémentaires';

  @override
  String get additionalNotesOptional => 'Notes complémentaires Facultatives';

  @override
  String get adjustPayment => 'Ajustement du paiement';

  @override
  String get adjustPayment2 => 'Ajuster le paiement2';

  @override
  String get adjustmentAmount => 'Montant des ajustements';

  @override
  String get admin => 'Administrateur';

  @override
  String get adminApproved => 'Administrateur approuvé';

  @override
  String get adminCreated => 'Création d\'un administrateur';

  @override
  String get adminDashboard => 'Tableau de bord';

  @override
  String get adminPrivilegesHaveBeenRevoked =>
      'Privilèges administratifs Ont été révoqués';

  @override
  String get adminResponse => 'Réponse de l\'administrateur';

  @override
  String get adminReview => 'Examen administratif';

  @override
  String get adminRoleManagement => 'Gestion des rôles administratifs';

  @override
  String get adminSchoolEdu => 'École administrative Édu';

  @override
  String get adminSettings => 'Paramètres d\' administration';

  @override
  String get adminType => 'Type d\'administration';

  @override
  String get admins => 'Administrateurs';

  @override
  String get admins1 => 'Administrateurs1';

  @override
  String get adminsTabContent => 'Admins Contenu de l\'onglet';

  @override
  String get adultEnglishLiteracyProgram =>
      'Programme d\'alphabétisation en anglais pour adultes';

  @override
  String get adultStudent => 'Étudiant adulte';

  @override
  String get aeh => 'Aeh';

  @override
  String get afterSchoolTutoring => 'Après la scolarité';

  @override
  String get allAdmins => 'Tous les administrateurs';

  @override
  String get allAssociatedDataIncludingTimesheetsForms =>
      'Toutes les données associées incluant les feuilles de temps Formulaires';

  @override
  String get allClasses => 'Toutes les classes';

  @override
  String get allDepartments => 'Tous les départements';

  @override
  String get allForms => 'Tous les formulaires';

  @override
  String get allFutureShiftsInThisSeries =>
      'Tous les changements futurs dans cette série';

  @override
  String get allParents => 'Tous les parents';

  @override
  String get allPriorities => 'Toutes les priorités';

  @override
  String get allRecordsNowReflectTheNew =>
      'Tous les enregistrements reflètent maintenant le nouveau';

  @override
  String get allRoles => 'Tous les rôles';

  @override
  String get allSchedules => 'Toutes les annexes';

  @override
  String get allSelectedShiftsDeletedSuccessfully =>
      'Tous les postes sélectionnés supprimés avec succès';

  @override
  String get allStatus => 'Tous les statuts';

  @override
  String get allStatuses => 'Tous les statuts';

  @override
  String get allStudents => 'Tous les étudiants';

  @override
  String get allSystemsOperational => 'Tous systèmes opérationnels';

  @override
  String get allTasks => 'Toutes les tâches';

  @override
  String get allTeachers => 'Tous les enseignants';

  @override
  String get allTiers => 'Tous niveaux';

  @override
  String get allUsers => 'Tous les utilisateurs';

  @override
  String get allUsersGlobal => 'Tous les utilisateurs';

  @override
  String get allUsersInRole => 'Tous les utilisateurs en rôle';

  @override
  String get allowParticipantsToUnmute =>
      'Permettre aux participants Pour désamorcer';

  @override
  String get allowRestorationAtAnyTime =>
      'Permettre la restauration à tout moment';

  @override
  String get allowThemToLogInAgain => 'Laissez-les se connecter à nouveau';

  @override
  String get alluwal => 'Alluwal';

  @override
  String get alluwalAcademyIsAQuranEducation =>
      'Alluwal Academy est AQuran Education';

  @override
  String get alluwalEducationHub => 'Alluwal Education Hub';

  @override
  String get alreadyAdminTeacher => 'Déjà professeur administrateur';

  @override
  String get alreadyClockedIn => 'Déjà programmé';

  @override
  String get alsoSendAsEmailNotification =>
      'Envoyer aussi sous forme de notification par courriel';

  @override
  String get always247 => 'Toujours247';

  @override
  String get annuler => 'Année';

  @override
  String get appTour => 'Visite App';

  @override
  String get applicationDetails => 'Détails de la demande';

  @override
  String get applicationSubmitted => 'Demande présentée';

  @override
  String get applyAdjustment => 'Appliquer le rajustement';

  @override
  String get applyAnyway => 'Appliquer de toute façon';

  @override
  String get applyChanges => 'Appliquer les modifications';

  @override
  String get applyChangesToAllShiftsAnd =>
      'Appliquer les modifications à tous les postes et';

  @override
  String get applyForLeadership => 'Demande de leadership';

  @override
  String get applyTo => 'Appliquer à';

  @override
  String get applyToRole => 'Appliquer au rôle';

  @override
  String get applyToTeach => 'Appliquer pour enseigner';

  @override
  String get applyWageChangesToRecords =>
      'Appliquer les changements de salaire Aux dossiers';

  @override
  String get applyWageToRole => 'Appliquer le salaire au rôle';

  @override
  String get applyingWageChangesToAllRecords =>
      'Application des modifications salariales à tous les dossiers';

  @override
  String get approvalEarnings => 'Revenus d\'agrément';

  @override
  String get approve => 'Approuver';

  @override
  String get approve2 => 'Approuver2';

  @override
  String get approveAll => 'Tout approuver';

  @override
  String get approveCalculatePayment => 'Approuver le calcul du paiement';

  @override
  String get approveConsolidatedShift => 'Approuver Déplacement';

  @override
  String get approveEditContinue => 'Approuver l\'édition Continuer';

  @override
  String get approveTimesheet => 'Approuver la feuille de temps';

  @override
  String get arabicNameOptional => 'Nom arabe Facultatif';

  @override
  String get archive => 'Archive';

  @override
  String get archivePermanentlyDelete => 'Archiver Supprimer définitivement';

  @override
  String get archiveTheirAccountNotPermanentlyDelete =>
      'Archiver leur compte Ne pas supprimer définitivement';

  @override
  String get archiveUser => 'Utilisateur d\' archives';

  @override
  String get archived => 'Archivé';

  @override
  String get archivedUsers => 'Usagers archivés';

  @override
  String get areYouSureYouWantTo => 'Tu es sûr de vouloir';

  @override
  String get areYouSureYouWantTo10 => 'Êtes-vous sûr de vouloir 10';

  @override
  String get areYouSureYouWantTo11 => 'Êtes-vous sûr que vous voulez 11';

  @override
  String get areYouSureYouWantTo12 => 'Êtes-vous sûr que vous voulez 12';

  @override
  String get areYouSureYouWantTo13 => 'Êtes-vous sûr de vouloir 13';

  @override
  String get areYouSureYouWantTo14 => 'Êtes-vous sûr que vous voulez 14';

  @override
  String get areYouSureYouWantTo2 => 'Êtes-vous sûr que vous voulez 2';

  @override
  String get areYouSureYouWantTo3 => 'Êtes-vous sûr que vous voulez 3';

  @override
  String get areYouSureYouWantTo4 =>
      'Êtes-vous sûr de vouloir quitter la classe ?';

  @override
  String get areYouSureYouWantTo5 => 'Êtes-vous sûr que vous voulez 5';

  @override
  String get areYouSureYouWantTo6 => 'Êtes-vous sûr que vous voulez 6';

  @override
  String get areYouSureYouWantTo7 => 'Êtes-vous sûr que vous voulez 7';

  @override
  String get areYouSureYouWantTo8 => 'Êtes-vous sûr que vous voulez 8';

  @override
  String get areYouSureYouWantTo9 => 'Êtes-vous sûr que vous voulez 9';

  @override
  String get assalamuAlaikum => 'Assalamu Alaikum';

  @override
  String get assalamuAlaikumFirstname => 'Assalamu Alaikum Prénom';

  @override
  String get assignTo => 'Affecter à';

  @override
  String get assignTo2 => 'Attribuer à 2';

  @override
  String get assignToStudents => 'Assigner aux élèves';

  @override
  String get assignedByAssignedbyname => 'Assigné par Nom';

  @override
  String get assignedTo => 'Affecté à';

  @override
  String get assignedTo2 => 'Affecté à 2';

  @override
  String get assignee => 'Assigné';

  @override
  String get assignmentDeleted => 'Attribution supprimée';

  @override
  String get assignmentDeletedSuccessfully =>
      'Attribution supprimée avec succès';

  @override
  String get atLeast6CharactersLongN => 'Au moins6Caractéristiques Long N';

  @override
  String get attachedFiles => 'Fichiers joints';

  @override
  String get attachedFiles2 => 'Fichiers joints2';

  @override
  String get attachmentRemovedSuccessfully =>
      'Pièce jointe supprimée avec succès';

  @override
  String get attachments => 'Pièces jointes';

  @override
  String get attachments2 => 'Pièces jointes2';

  @override
  String get attachmentsOptional => 'Pièces jointes Facultative';

  @override
  String get attendancepercent => 'Taux de participation';

  @override
  String get aucunLogPourLeMoment => 'Aucun Log Pour Le Moment';

  @override
  String get auditGenerationErrors =>
      'Erreurs liées à la génération de vérification';

  @override
  String get auditManagement => 'Gestion de l \' audit';

  @override
  String get auditSubmittedSuccessfully => 'Vérification présentée avec succès';

  @override
  String get auditUnderReview => 'Vérification en cours';

  @override
  String get authenticationError => 'Erreur d\'authentification';

  @override
  String get authenticationService => 'Service d\'authentification';

  @override
  String get autoClockedOutShiftTimeEnded =>
      'Heure de fin du quart de travail automatique';

  @override
  String get autoFilledFromSubjectOrLeave =>
      'Auto rempli à partir de sujet ou de congé';

  @override
  String get autoGenerated => 'Autogénérés';

  @override
  String get autoLogoutInTimeuntilautologout =>
      'Déconnexion automatique Dans Timeuntilautologout';

  @override
  String get autoSendingReportIn30Seconds =>
      'Envoi automatique de rapport en30secondes';

  @override
  String get available => 'Disponible';

  @override
  String get availableForms => 'Formulaires disponibles';

  @override
  String get availableFunctions => 'Fonctions disponibles';

  @override
  String get availableOptions => 'Options disponibles';

  @override
  String get availableShifts => 'Postes disponibles';

  @override
  String get availableSubjectsClickToConfigure =>
      'Sujets disponibles Cliquez pour configurer';

  @override
  String get average => 'Moyenne';

  @override
  String get avgResponseResponserate => 'Taux de réponse';

  @override
  String get avgResponseTimeResponsetimeMs => 'Avg Temps de réponse';

  @override
  String get backToHome => 'Retour à la maison';

  @override
  String get backupCreatedSuccessfully => 'Sauvegarde réalisée avec succès';

  @override
  String get backupSettings => 'Paramètres de sauvegarde';

  @override
  String get badgeText => 'Texte de l\'insigne';

  @override
  String get ban => 'Interdiction';

  @override
  String get banForm => 'Formulaire d\'interdiction';

  @override
  String get banShift => 'Changement d\'interdiction';

  @override
  String get beTheFirstToLeaveA => 'Soyez le premier à quitter A';

  @override
  String get becomeATeacher => 'Devenez ATeacher';

  @override
  String get becomeATutor => 'Devenez ATutor';

  @override
  String get beginYourLanguageJourney => 'Commencez votre voyage linguistique';

  @override
  String get beta => 'Bêta';

  @override
  String get block => 'Bloc';

  @override
  String get blueTaskStatusUpdateNotification =>
      'Avis de mise à jour de l\'état de la tâche bleue';

  @override
  String get bonusPerExcellence => 'Bonus par excellence';

  @override
  String get bookFreeTrialClass => 'Classe d\'essai gratuite';

  @override
  String get breakDuration => 'Durée de la pause';

  @override
  String get briefDescriptionOfTheSubject => 'Brève description du sujet';

  @override
  String get broadcastLiveTeachersCanNowSee =>
      'Les enseignants en direct peuvent maintenant voir';

  @override
  String get broadcastNow => 'Diffusion actuelle';

  @override
  String get broadcastToTeachers => 'Diffusion aux enseignants';

  @override
  String get browserCacheIssueDetectedPleaseRefresh =>
      'Navigateur Cache Problème détecté S\'il vous plaît rafraîchir';

  @override
  String get buildTheFutureWithCode => 'Construire l\'avenir avec le code';

  @override
  String get bulkApproveTimesheets =>
      'Approbation en vrac des feuilles de temps';

  @override
  String get bulkEditEveryClassForThe =>
      'Modifier en vrac chaque classe pour Les';

  @override
  String get bulkEditShifts => 'Majs d\'édition en vrac';

  @override
  String get bulkRejectTimesheets => 'Calendrier des rejets en vrac';

  @override
  String get bulkUpdateFailedE => 'La mise à jour en vrac a échoué E';

  @override
  String get byApprovingYouAcceptTheEdited =>
      'En vous approuvant accepter la modification';

  @override
  String get byContinuingYouWillApproveBoth =>
      'En continuant, vous approuverez les deux';

  @override
  String get byRole => 'Par rôle';

  @override
  String get cacheClearedSuccessfully => 'Cache Effacé avec succès';

  @override
  String get callToAction => 'Appel à l\'action';

  @override
  String get cameraAndMicrophoneAccessAreNeeded =>
      'Caméra et accès au microphone sont nécessaires';

  @override
  String get cameraAndMicrophonePermissionsAreRequired =>
      'Les autorisations de caméra et de microphone sont requises';

  @override
  String get cannotEditClockOutTimeYou =>
      'Impossible de modifier l\'heure de sortie';

  @override
  String get career => 'Carrière';

  @override
  String get category => 'Catégorie';

  @override
  String get ceFormulaireNAPasDe => 'Ce Formulaire NAPas De';

  @override
  String get ceo => 'Ceo';

  @override
  String get change => 'Changement';

  @override
  String get changePassword => 'Modifier le mot de passe';

  @override
  String get changePriority => 'Changement Priorité';

  @override
  String get changeProfilePicture => 'Modifier l\'image du profil';

  @override
  String get changeStatus => 'Modifier l\'état';

  @override
  String get changeTheAssignedTeacherForAll =>
      'Changer l\'enseignant pour tous';

  @override
  String get changeTheSubjectForAllSelected =>
      'Modifier le sujet pour tous les sujets sélectionnés';

  @override
  String get changesToApply => 'Modifications pour appliquer';

  @override
  String get changesWillBeAppliedImmediatelyThe =>
      'Les changements seront appliqués immédiatement Les';

  @override
  String get changesWillUpdateTheRecurringTemplate =>
      'Les changements mettront à jour le modèle récurrent';

  @override
  String get chatFeature => 'Fonction de discussion';

  @override
  String get chatMessages2 => 'Messages de discussion2';

  @override
  String get checkOurFrequentlyAskedQuestionsFor =>
      'Consultez notre foire aux questions';

  @override
  String get checkPaymentStatus => 'Vérifier l\'état du paiement';

  @override
  String get checkingConnection => 'Vérification de la connexion';

  @override
  String get checkingForUpdates => 'Vérification des mises à jour';

  @override
  String get checkingRecurringSeries => 'Vérification des séries récurrentes';

  @override
  String get checkpoints => 'Points de contrôle';

  @override
  String get children => 'Enfants';

  @override
  String get childrenSPrivacy => 'Protection des enfants';

  @override
  String get chooseAFormFromTheSidebar =>
      'Choisissez AForm dans la barre latérale';

  @override
  String get chooseAParentForThisMinor => 'Choisissez un parent pour ce mineur';

  @override
  String get chooseAParentToViewTheir => 'Choisissez AParent pour voir leurs';

  @override
  String get chooseARole => 'Choisir ARole';

  @override
  String get chooseAnAdminOrPromotedTeacher =>
      'Choisir un administrateur ou un enseignant promu';

  @override
  String get chooseFromGallery => 'Choisissez parmi Galerie';

  @override
  String get chooseUsersToAssignThisTask =>
      'Choisir des utilisateurs pour attribuer cette tâche';

  @override
  String get chooseYourPreferredExportFormat =>
      'Choisissez votre format d\'exportation préféré';

  @override
  String get chooseYourProgram => 'Choisissez votre programme';

  @override
  String get claimShift => 'Changement de réclamation';

  @override
  String get classCards => 'Cartes de classe';

  @override
  String get classReportNotSubmitted => 'Rapport de classe non présenté';

  @override
  String get classReportSubmitted => 'Rapport de classe présenté';

  @override
  String get classReportSubmittedMissedShift =>
      'Rapport de classe soumis Poste manquant';

  @override
  String get classSignUp => 'Inscription à la classe';

  @override
  String get classSignUp2 => 'Inscription en classe2';

  @override
  String get classcount => 'Nombre de classes';

  @override
  String get classesCompleted => 'Classes terminées';

  @override
  String get cleanup => 'Nettoyage';

  @override
  String get cleanupOld => 'Nettoyage ancien';

  @override
  String get cleanupOldDrafts => 'Nettoyage des anciens brouillons';

  @override
  String get clearAll => 'Tout effacer';

  @override
  String get clearAll2 => 'Tout effacer2';

  @override
  String get clearDateRange => 'Effacer la plage de dates';

  @override
  String get clearFilter => 'Effacer le filtre';

  @override
  String get clearFilters => 'Effacer les filtres';

  @override
  String get clearLogs => 'Effacer les journaux';

  @override
  String get clearPerformanceLogs => 'Effacer les journaux de performance';

  @override
  String get clearSearch => 'Effacer la recherche';

  @override
  String get clearSelection => 'Effacer la sélection';

  @override
  String get clearTeacherFilter => 'Effacer le filtre de l\'enseignant';

  @override
  String get clickAddSubjectToCreateYour =>
      'Cliquez sur Ajouter un sujet pour créer votre';

  @override
  String get clickToAddSignature => 'Cliquez pour ajouter une signature';

  @override
  String get clickToUploadImage => 'Cliquez pour télécharger l\'image';

  @override
  String get clockIn => 'Réveil';

  @override
  String get clockInLocation => 'Horloge en place';

  @override
  String get clockInNotYet => 'Pas encore';

  @override
  String get clockIns => 'Clock Ins';

  @override
  String get clockOutLocation => 'Emplacement de l\'horloge';

  @override
  String get clockOutTimeCannotBeEdited =>
      'Temps d\'horloge ne peut pas être modifié';

  @override
  String get clockOutTimeMustBeAfter => 'Le temps de sortie doit être après';

  @override
  String get clockedIn => 'Enregistré';

  @override
  String get codingIsTheLiteracyOfThe => 'Le codage est l\'alphabétisation';

  @override
  String get codingTechnology => 'Technologie de codage';

  @override
  String get collapseSidebar => 'Réduire la barre latérale';

  @override
  String get comfortable => 'Confortable';

  @override
  String get commentDeletedSuccessfully => 'Commentaire supprimé avec succès';

  @override
  String get commentcount => 'Compte de commentaires';

  @override
  String get comments => 'Commentaires';

  @override
  String get completeNow => 'Compléter maintenant';

  @override
  String get completeProfile => 'Profil complet';

  @override
  String get completeYourProfileToAppearOn =>
      'Compléter votre profil pour apparaître';

  @override
  String get completedClassesWillAppearHere =>
      'Les classes terminées apparaîtront ici';

  @override
  String get completedcount => 'Nombre achevé';

  @override
  String get completedcountCompleted => 'Nombre achevé Achevé';

  @override
  String get composeNotification => 'Composer la notification';

  @override
  String get computeMetricsNow => 'Calculez les paramètres maintenant';

  @override
  String get computingMetricsThisMayTakeA =>
      'Computing Metrics ce qui peut prendre A';

  @override
  String get configureAndManageYourEducationPlatform =>
      'Configurer et gérer votre plateforme d\'éducation';

  @override
  String get configureApplicationSettings =>
      'Configuration des paramètres d\'application';

  @override
  String get configureIslamicEducationTeachingSchedule =>
      'Configurer le calendrier de l\'enseignement islamique';

  @override
  String get configuredRates => 'Taux configurés';

  @override
  String get confirmNewPassword => 'Confirmer un nouveau mot de passe';

  @override
  String get confirmNewPassword2 => 'Confirmer le nouveau mot de passe2';

  @override
  String get confirmPassword => 'Confirmer le mot de passe';

  @override
  String get conflictsDetected => 'Conflits détectés';

  @override
  String get connectWithTheWorldThroughLanguage =>
      'Se connecter au monde par la langue';

  @override
  String get connecteam => 'Connexion';

  @override
  String get connectingToClass => 'Connexion à la classe';

  @override
  String get connectingToTaskDatabase =>
      'Connexion à la base de données des tâches';

  @override
  String get connectionTestErrorE => 'Erreur de test de connexion E';

  @override
  String get contactInformation => 'Coordonnées';

  @override
  String get contactSupport => 'Contacter le support';

  @override
  String get contactUs => 'Contactez-nous';

  @override
  String get continueWithGoogle => 'Continuer avec Google';

  @override
  String get convertedslotTeachertzabbr => 'Convertedslot Teachertzabbr';

  @override
  String get copyAllShiftsFromCurrentWeek =>
      'Copier tous les postes de la semaine actuelle';

  @override
  String get copyClassLink => 'Copier le lien de classe';

  @override
  String get copySummary => 'Copier le résumé';

  @override
  String get copyToClipboard => 'Copier vers le presse-papiers';

  @override
  String get coreValues => 'Valeurs de base';

  @override
  String get couldNotOpenUrl => 'Impossible d\'ouvrir Url';

  @override
  String get count => 'Nombre';

  @override
  String get countTotal => 'Nombre total';

  @override
  String get courses => 'Cours';

  @override
  String get coursesEditor => 'Éditeur de cours';

  @override
  String get creErPayer => 'Cre Er Payer';

  @override
  String get createAParentAccountFirst => 'Créer un compte Parent d\'abord';

  @override
  String get createAndManageYourFormTemplates =>
      'Créer et gérer vos modèles de formulaire';

  @override
  String get createAssignment => 'Créer une attribution';

  @override
  String get createDefaultTemplates => 'Créer des modèles par défaut';

  @override
  String get createForm => 'Créer un formulaire';

  @override
  String get createMultipleTasks => 'Créer plusieurs Fonctions';

  @override
  String get createShift => 'Créer un Maj';

  @override
  String get createTask => 'Créer une tâche';

  @override
  String get createUsers => 'Créer des utilisateurs';

  @override
  String get createYourFirstAssignmentToGet =>
      'Créez votre première mission à obtenir';

  @override
  String get createYourFirstFormToGet =>
      'Créez votre premier formulaire pour obtenir';

  @override
  String get createdBy => 'Créé par';

  @override
  String get createdBy2 => 'Créé par2';

  @override
  String get createdByMe => 'Créé par moi';

  @override
  String get creating => 'Création';

  @override
  String get csv => 'Csv';

  @override
  String get csvExportedSuccessfully => 'Csv exporté avec succès';

  @override
  String get csvExportedSuccessfully2 => 'Csv exporté avec succès2';

  @override
  String get ctaEditor => 'Éditeur Cta';

  @override
  String get currentPassword => 'Mot de passe actuel';

  @override
  String get currentPayment => 'Paiement actuel';

  @override
  String get currentSchedule => 'Calendrier actuel';

  @override
  String get currentUserInfo => 'Informations utilisateur actuelles';

  @override
  String get dailyRecurrenceSettings => 'Paramètres quotidiens de récurrence';

  @override
  String get dailyReports => 'Rapports quotidiens';

  @override
  String get dataComparison => 'Comparaison des données';

  @override
  String get dataSecurity => 'Sécurité des données';

  @override
  String get databaseConnection => 'Connexion à la base de données';

  @override
  String get dateAdded => 'Date d\'ajout';

  @override
  String get dateFilterCleared => 'Filtre de date effacé';

  @override
  String get datePicker => 'Récupérateur de date';

  @override
  String get dateRange => 'Gamme de dates';

  @override
  String get dateRange2 => 'Gamme de dates2';

  @override
  String get dateSubmitted => 'Date de soumission';

  @override
  String get datestrType => 'Type de date';

  @override
  String get daylightSavingTimeAdjustment =>
      'Ajustement du temps d\'économie de jour';

  @override
  String get debug => 'Débogues';

  @override
  String get debugCheckMyAssignments => 'Vérifier mes tâches';

  @override
  String get debugErrorE => 'Erreur de débogage E';

  @override
  String get debugFirestoreDrafts => 'Déboguez les ébauches de Firestore';

  @override
  String get debugInfo => 'Informations de débogage';

  @override
  String get debugInfoN => 'Info de débogage :';

  @override
  String get decision => 'Décision';

  @override
  String get defaultTemplatesCreated => 'Modèles par défaut créés';

  @override
  String get deleteAccount => 'Supprimer le compte';

  @override
  String get deleteAll => 'Tout supprimer';

  @override
  String get deleteAllTeacherShifts =>
      'Supprimer tous les postes d\'enseignant';

  @override
  String get deleteAllTeachershifts =>
      'Supprimer tous les postes d\'enseignant';

  @override
  String get deleteAssignment => 'Supprimer l\'attribution';

  @override
  String get deleteAttachment => 'Supprimer la pièce jointe';

  @override
  String get deleteComment => 'Supprimer le commentaire';

  @override
  String get deleteDraft => 'Supprimer le projet';

  @override
  String get deleteField => 'Supprimer le champ';

  @override
  String get deleteForm => 'Supprimer le formulaire';

  @override
  String get deleteMultipleShifts => 'Supprimer plusieurs déplacements';

  @override
  String get deletePermanently => 'Supprimer définitivement';

  @override
  String get deleteShift => 'Supprimer le déplacement';

  @override
  String get deleteShift2 => 'Supprimer Shift2';

  @override
  String get deleteSubject => 'Supprimer le sujet';

  @override
  String get deleteTask => 'Supprimer la tâche';

  @override
  String get deleteTasks => 'Supprimer les tâches';

  @override
  String get deleteTeacherShifts => 'Supprimer les postes d\'enseignant';

  @override
  String get deleteTemplate => 'Supprimer le modèle';

  @override
  String get deleteThisShift => 'Supprimer ce déplacement';

  @override
  String get description => 'Désignation des marchandises';

  @override
  String get description2 => 'Désignation des marchandises';

  @override
  String get designedForAdultsWhoWantTo => 'Conçu pour les adultes qui veulent';

  @override
  String get detailedPerformanceLogs => 'Registres détaillés des performances';

  @override
  String get details => 'Détails';

  @override
  String get directUpdate => 'Mise à jour directe';

  @override
  String get discoverTheTransformativePowerOfOur =>
      'Découvrez la puissance transformatrice de notre';

  @override
  String get displayName => 'Afficher le nom';

  @override
  String get displayTimezone => 'Afficher le fuseau horaire';

  @override
  String get dispute => 'Conflit';

  @override
  String get disputeSubmittedSuccessfully => 'Conflit soumis Réussir';

  @override
  String get download => 'Télécharger';

  @override
  String get downloadFile => 'Télécharger le fichier';

  @override
  String get downloadImage => 'Télécharger l\'image';

  @override
  String get downloadPdf => 'Télécharger Pdf';

  @override
  String get draft => 'Projet';

  @override
  String get draftDeletedSuccessfully => 'Projet supprimé avec succès';

  @override
  String get draftForms => 'Projets de formulaires';

  @override
  String get dragToMoveClickToClose =>
      'Faites glisser pour déplacer Cliquez pour fermer';

  @override
  String get dstAdjustmentComplete => 'Dst Réglage terminé';

  @override
  String get dstTimeAdjustment => 'Dst Réglage du temps';

  @override
  String get dueDate => 'Date d\'échéance';

  @override
  String get dueDate2 => 'Date d\'échéance2';

  @override
  String get dueDateOptional => 'Échéance Facultative';

  @override
  String get duplicate => 'Dupliquer';

  @override
  String get duplicateKioskCodeFoundKioskcodePlease =>
      'Code du Kiosque trouvé S\'il vous plaît.';

  @override
  String get duplicateWeek => 'Semaine du double';

  @override
  String get dureEAPayerHeures => 'Durée EAPayer Heures';

  @override
  String get duringClass => 'Pendant la classe';

  @override
  String get dutyType => 'Type de droit';

  @override
  String get eChoueS => 'E Choix S';

  @override
  String get eG => 'E G';

  @override
  String get eG021Or5 => 'E G021Or5';

  @override
  String get eGEnterYourAnswerHere => 'Votre réponse ici';

  @override
  String get eGMathematics => 'E GMathématique';

  @override
  String get eGOfficeRemote => 'E GOffice Remote';

  @override
  String get eGQuranStudies => 'E GQuran Études';

  @override
  String get eGQuranStudies2 => 'E GQuran Études2';

  @override
  String get eGStudentRequestedToMove => 'E GÉÉLÉCENDANT DEMANDE DE DÉménAGE';

  @override
  String get eGWhatLessonDidYou => 'Quelle leçon avez-vous fait?';

  @override
  String get eachClassCardHasAColor => 'Chaque carte de classe a une couleur';

  @override
  String get editAllInSeries => 'Tout éditer en série';

  @override
  String get editAllShiftsForAStudent =>
      'Modifier tous les postes pour les étudiants AS';

  @override
  String get editByTimeRangeStudent =>
      'Modifier par Étudiant de la plage de temps';

  @override
  String get editEvaluation => 'Modifier l\'évaluation';

  @override
  String get editField => 'Modifier le champ';

  @override
  String get editFunctionalityComingSoonUseWeb =>
      'Modifier la fonctionnalité Bientôt Utiliser le Web';

  @override
  String get editInformation => 'Modifier l\'information';

  @override
  String get editOptions => 'Modifier les options';

  @override
  String get editShift => 'Modifier le déplacement';

  @override
  String get editSubject => 'Modifier le sujet';

  @override
  String get editTask => 'Modifier la tâche';

  @override
  String get editTemplate => 'Modifier le modèle';

  @override
  String get editTheMainLandingPageHero =>
      'Modifier la page d\'atterrissage principale Hero';

  @override
  String get editThisShiftOnly => 'Modifier seulement ce changement';

  @override
  String get edited => 'Modifié';

  @override
  String get editedTimesheetsDetected =>
      'Feuilles de temps modifiées détectées';

  @override
  String get editingComment => 'Modifier le commentaire';

  @override
  String get educationHub => 'Centre pour l \' éducation';

  @override
  String get emailAddress => 'Adresse électronique';

  @override
  String get emailNotifications => 'Notifications par courriel';

  @override
  String get emailSentToParent => 'Envoyer un courriel à un parent';

  @override
  String get emailSupportAlluwaleducationhubOrg =>
      'Soutien par courriel Alluwaleducationhub Organisme';

  @override
  String get emailSystemWebCompatible => 'Système de messagerie Web Compatible';

  @override
  String get emailTest => 'Essai par courriel';

  @override
  String get employeeNotes => 'Notes aux employés';

  @override
  String get employmentStartDate => 'Emploi Date de début';

  @override
  String get empowerYourselfWithTheSkillsOf => 'Donnez-vous les compétences de';

  @override
  String get enableDisplaynameMicrophone =>
      'Activer le nom d\'affichage Microphone';

  @override
  String get endDateOptional => 'Date de fin Facultative';

  @override
  String get endTimeMustBeAfterStart =>
      'L\'heure de fin doit être après le début';

  @override
  String get englishIsTheGlobalLanguageOf =>
      'L\'anglais est la langue mondiale de';

  @override
  String get englishLanguageProgram => 'Programme de langue anglaise';

  @override
  String get enrollInCoursename => 'Inscription au nom du cours';

  @override
  String get enrollInTutoring => 'Inscription à la formation';

  @override
  String get enrollNow => 'Inscrivez-vous maintenant';

  @override
  String get enrolledFilled => 'Remplissage';

  @override
  String get enseignantTeachername => 'Enseignant Nom du professeur';

  @override
  String get enterADescriptiveTitle => 'Entrez undescriptif Titre';

  @override
  String get enterCurrentPassword => 'Saisissez le mot de passe actuel';

  @override
  String get enterCustomShiftName => 'Saisissez le nom du poste personnalisé';

  @override
  String get enterFieldLabel => 'Entrez l\'étiquette du champ';

  @override
  String get enterFormDescription => 'Entrez la description du formulaire';

  @override
  String get enterFormTitle => 'Entrez le titre du formulaire';

  @override
  String get enterLessonDetailsNotesOrObservations =>
      'Entrez les détails de la leçon Notes ou observations';

  @override
  String get enterNewPassword => 'Saisissez un nouveau mot de passe';

  @override
  String get enterNotes => 'Saisissez les notes';

  @override
  String get enterNotificationMessage => 'Entrez la notification Message';

  @override
  String get enterNotificationTitle => 'Entrez la notification Titre';

  @override
  String get enterPlaceholderText => 'Entrez le détenteur de place Texte';

  @override
  String get enterReasonForRejection => 'Entrez le motif du rejet';

  @override
  String get enterTemplateDescription => 'Saisissez la description du modèle';

  @override
  String get enterTemplateName => 'Saisissez le nom du modèle';

  @override
  String get enterYourEmailOrKiosqueCode =>
      'Entrez votre courriel ou votre code Kiosque';

  @override
  String get entryUpdatedSuccessfully => 'Mise à jour réussie';

  @override
  String get entrycountEvents => 'Événements du compte d\'entrée';

  @override
  String get erreurLorsDeLaCreAtion => 'Erreur Lors De La Cre Ation';

  @override
  String get error => 'Erreur';

  @override
  String get errorAddingSubjectE => 'Erreur lors de l\'ajout du sujet E';

  @override
  String get errorAdjustingShiftsE => 'Erreur lors du réglage des postes E';

  @override
  String get errorApplyingPenaltyE => 'Erreur d\'application de la pénalité E';

  @override
  String get errorApplyingWageChangesE =>
      'Erreur d\'application des changements de salaire E';

  @override
  String get errorArchivingTaskE => 'Erreur lors de l\'archivage de la tâche E';

  @override
  String get errorBanningShiftE => 'Erreur Banning Shift E';

  @override
  String get errorCouldNotLoadFormTemplate =>
      'Erreur Impossible de charger le modèle de formulaire';

  @override
  String get errorCreatingStudentE =>
      'Erreur lors de la création de l\'étudiant E';

  @override
  String get errorDeletingFormE => 'Erreur de suppression du formulaire E';

  @override
  String get errorDeletingShiftE => 'Erreur de suppression du Maj E';

  @override
  String get errorDeletingShiftsE => 'Erreur Suppression des déplacements E';

  @override
  String get errorDeletingTeacherShiftsE =>
      'Erreur de suppression des postes d\'enseignant E';

  @override
  String get errorDeletingTemplateE => 'Erreur de suppression du modèle E';

  @override
  String get errorDeletingUserE => 'Erreur de suppression de l\'utilisateur E';

  @override
  String get errorDetails => 'Détails de l\'erreur';

  @override
  String get errorDuplicatingFormE => 'Erreur de duplication du formulaire E';

  @override
  String get errorDuplicatingTemplateE => 'Erreur de duplication du modèle E';

  @override
  String get errorE => 'Erreur E';

  @override
  String get errorError => 'Erreur';

  @override
  String get errorExportingCsvE => 'Erreur lors de l\'exportation de Csv E';

  @override
  String get errorExportingE => 'Erreur d\'exportation E';

  @override
  String get errorExportingExcelE => 'Erreur lors de l\'exportation d\'Excel E';

  @override
  String get errorFetchingTeachersE => 'Erreur de réception des enseignants E';

  @override
  String get errorLoadingCredentialsE =>
      'Erreur lors du chargement des lettres de créances E';

  @override
  String get errorLoadingDrafts => 'Erreur lors du chargement des ébauches';

  @override
  String get errorLoadingFormE => 'Erreur lors du chargement du formulaire E';

  @override
  String get errorLoadingLanguageSettingsPleaseRestart =>
      'Erreur lors du chargement des paramètres de langue S\'il vous plaît redémarrer';

  @override
  String get errorLoadingMetricsE => 'Erreur lors du chargement des mesures E';

  @override
  String get errorLoadingProfile => 'Erreur lors du chargement du profil';

  @override
  String get errorLoadingSettingsE =>
      'Erreur lors du chargement des paramètres E';

  @override
  String get errorLoadingShiftDetailsE =>
      'Erreur lors de la chargement des détails E';

  @override
  String get errorLoadingShiftE => 'Erreur lors de la chargement du Maj E';

  @override
  String get errorLoadingShiftsE => 'Erreur lors du chargement des Majes E';

  @override
  String get errorLoadingStudents => 'Erreur lors du chargement des étudiants';

  @override
  String get errorLoadingSubjects => 'Erreur lors du chargement des sujets';

  @override
  String get errorLoadingSubmissionE =>
      'Erreur lors du chargement de la soumission E';

  @override
  String get errorLoadingSubmissionsE =>
      'Erreur lors du chargement des soumissions E';

  @override
  String get errorLoadingTasks => 'Erreur lors du chargement des tâches';

  @override
  String get errorLoadingTemplatesE =>
      'Erreur lors du chargement des modèles E';

  @override
  String get errorLoadingTimesheetDataE =>
      'Erreur lors du chargement des données de la feuille de temps E';

  @override
  String get errorLoadingTimesheetE =>
      'Erreur lors du chargement de la feuille de temps E';

  @override
  String get errorLoadingUsers => 'Erreur lors du chargement des utilisateurs';

  @override
  String get errorLoadingUsersE =>
      'Erreur lors du chargement des utilisateurs E';

  @override
  String get errorMissingShiftInformation => 'Erreur Informations manquantes';

  @override
  String get errorOpeningFileE => 'Erreur lors de l\'ouverture du fichier E';

  @override
  String get errorOpeningLink => 'Erreur lors de l\'ouverture du lien';

  @override
  String get errorPromotingUserE => 'Erreur de promotion de l\'utilisateur E';

  @override
  String get errorReorderingSubjectsE =>
      'Erreur dans la réorganisation des sujets E';

  @override
  String get errorReschedulingShiftE =>
      'Erreur de rééchelonnement du déplacement E';

  @override
  String get errorResettingPasswordE =>
      'Erreur de réinitialisation du mot de passe E';

  @override
  String get errorSavingFormE =>
      'Erreur lors de l\'enregistrement du formulaire E';

  @override
  String get errorSavingSettingsE =>
      'Erreur lors de l\'enregistrement des paramètres E';

  @override
  String get errorSavingShiftE => 'Erreur lors de l\'enregistrement du Maj E';

  @override
  String get errorSavingTemplateE =>
      'Erreur lors de l\'enregistrement du modèle E';

  @override
  String get errorSendingMessageE => 'Erreur lors de l\'envoi du message E';

  @override
  String get errorSendingNotificationE =>
      'Erreur lors de l\'envoi de la notification E';

  @override
  String get errorSubmittingE => 'Erreur de soumission E';

  @override
  String get errorSubmittingTimesheetE =>
      'Erreur lors de la soumission de la feuille de temps E';

  @override
  String get errorUnarchivingTaskE => 'Erreur lors de la désarchivage Tâche E';

  @override
  String get errorUpdatingEntryE => 'Erreur de mise à jour de l\'entrée E';

  @override
  String get errorUpdatingStatusE =>
      'Erreur lors de la mise à jour de l\'état E';

  @override
  String get errorUpdatingSubjectE =>
      'Erreur lors de la mise à jour du sujet E';

  @override
  String get errorUpdatingSubjectStatusE =>
      'Erreur de mise à jour de l\'état du sujet E';

  @override
  String get errorUpdatingTaskE => 'Erreur de mise à jour de la tâche E';

  @override
  String get errorUpdatingTasksE =>
      'Erreur lors de la mise à jour des tâches E';

  @override
  String get errorUpdatingTimesheetE =>
      'Erreur lors de la mise à jour de la feuille de temps E';

  @override
  String get errorUpdatingUserE => 'Erreur de mise à jour de l\'utilisateur E';

  @override
  String get errorYouMustBeLoggedIn =>
      'Erreur dans laquelle vous devez être accroché';

  @override
  String get errors => 'Erreurs';

  @override
  String get estimatedEarnings => 'Revenus estimés';

  @override
  String get evaluate => 'Évaluation';

  @override
  String get everyone => 'Tous';

  @override
  String get excelReportExportedSuccessfully =>
      'Rapport Excel exporté avec succès';

  @override
  String get excelWithMonthlyPivotTables =>
      'Excel avec tableaux pivots mensuels';

  @override
  String get excludeDaysOfWeek => 'Exclure les jours de la semaine';

  @override
  String get excludeSpecificDates => 'Exclure les dates spécifiques';

  @override
  String get existingDispute => 'Différend actuel';

  @override
  String get exitApp => 'Sortie de l\'application';

  @override
  String get exitFullscreen => 'Sortie en plein écran';

  @override
  String get expand => 'Élargir';

  @override
  String get explainTheIssue => 'Expliquer le problème';

  @override
  String get explainWhyYouAreEditingThis =>
      'Expliquez pourquoi vous modifiez ceci';

  @override
  String get exportAllMonthsPivotView => 'Exporter tous les mois Vue de pivot';

  @override
  String get exportAuditReport => 'Rapport de vérification des exportations';

  @override
  String get exportCsv => 'Exportation Csv';

  @override
  String get exportData => 'Données d\'exportation';

  @override
  String get exportFailedE => 'Échec de l\'exportation E';

  @override
  String get exportPdf => 'Exportation Pdf';

  @override
  String get exportToCsv => 'Exportation vers Csv';

  @override
  String get failedLoginAttempt15MinutesAgo =>
      'Échec de la tentative de connexion15Minutes C\'est parti';

  @override
  String get failedToAddFileE => 'Impossible d\'ajouter le fichier E';

  @override
  String get failedToAddMembers => 'Échec de l\'ajout de membres';

  @override
  String get failedToClaimShiftPleaseTry =>
      'Échec du changement de demande Essayez s\'il vous plaît.';

  @override
  String get failedToCleanupDraftsE => 'Échec du nettoyage E';

  @override
  String get failedToDeleteAssignmentE =>
      'Impossible de supprimer l\'assignation E';

  @override
  String get failedToDeleteDraftE => 'Échec de la suppression du projet E';

  @override
  String get failedToGeneratePdfE => 'Impossible de générer Pdf E';

  @override
  String get failedToInitializeFirebase =>
      'Échec de l\'initialisation de la base de pompiers';

  @override
  String get failedToLinkFormToShift =>
      'Impossible de lier le formulaire au déplacement';

  @override
  String get failedToLoadAssignmentsE =>
      'Échec du chargement des affectations E';

  @override
  String get failedToLoadExistingProfileE =>
      'Impossible de charger le profil existant E';

  @override
  String get failedToLoadInvoiceNMessage =>
      'Impossible de charger la facture NMessage';

  @override
  String get failedToLoadInvoicesNMessage =>
      'Échec du chargement des factures NMessage';

  @override
  String get failedToLoadProfileE => 'Impossible de charger le profil E';

  @override
  String get failedToLoadSeriesE => 'Échec au chargement de la série E';

  @override
  String get failedToLoadStudentShiftsE =>
      'Échec du chargement des postes d\'élève E';

  @override
  String get failedToLoadTimeRangeShifts =>
      'Impossible de charger des décalages de temps';

  @override
  String get failedToOpenClassLinkE =>
      'Impossible d\'ouvrir le lien de classe E';

  @override
  String get failedToRemoveProfilePicturePlease =>
      'Impossible de supprimer l\'image de profil S\'il vous plaît.';

  @override
  String get failedToSaveContentE => 'Impossible de sauvegarder le contenu E';

  @override
  String get failedToSaveNoteE => 'Impossible d\'enregistrer la note E';

  @override
  String get failedToSavePreferencesPleaseTry =>
      'Impossible de sauvegarder les préférences Veuillez essayer';

  @override
  String get failedToSaveProfileE => 'Impossible d\'enregistrer le profil E';

  @override
  String get failedToSaveStatusE => 'Impossible de sauvegarder l\'état E';

  @override
  String get failedToSendReportPleaseTry =>
      'Échec de l\'envoi du rapport Veuillez essayer';

  @override
  String get failedToSwitchRolePleaseTry =>
      'Impossible de changer de rôle Veuillez essayer';

  @override
  String get failedToUpdatePayment => 'Impossible de mettre à jour le paiement';

  @override
  String get failedToUpdateTaskPleaseTry =>
      'Impossible de mettre à jour la tâche Veuillez essayer';

  @override
  String get failedToUploadProfilePicturePlease =>
      'Impossible de télécharger l\'image de profil S\'il vous plaît.';

  @override
  String get fallBack1Hour => 'Retour 1heure';

  @override
  String get faqs => 'Faqs';

  @override
  String get feature => 'Fonctionnalité';

  @override
  String get features => 'Caractéristiques';

  @override
  String get featuresEditorComingSoon => 'Caractéristiques Éditeur Bientôt';

  @override
  String get featuresSectionEditor => 'Éditeur de section';

  @override
  String get field => 'Champ';

  @override
  String get fieldLabel => 'Étiquette du champ';

  @override
  String get fieldLabelCannotBeEmpty => 'Label de champ ne peut pas être vide';

  @override
  String get fieldToDispute => 'Champ de litige';

  @override
  String get fieldType => 'Type de champ';

  @override
  String get fieldType2 => 'Type de champ2';

  @override
  String get fileAttachmentIsOnlySupportedOn =>
      'La pièce jointe au fichier est uniquement prise en charge';

  @override
  String get fileNotUploadedToStorage =>
      'Fichier non téléchargé vers le stockage';

  @override
  String get fileSelectionCancelled => 'Sélection de fichiers annulée';

  @override
  String get fileUpload => 'Téléchargement de fichier';

  @override
  String get fill => 'Remplir';

  @override
  String get fillClassReportNow => 'Remplir le rapport de classe maintenant';

  @override
  String get fillInTheDetailsForEach => 'Remplir les détails pour chaque';

  @override
  String get filter => 'Filtre';

  @override
  String get filterByAssignedBy => 'Filtrer par Affecté par';

  @override
  String get filterByAssignedTo => 'Filtrer par Affecté à';

  @override
  String get filterByLabels => 'Filtrer par les étiquettes';

  @override
  String get filterByParent => 'Filtrer par parent';

  @override
  String get filterByPriority => 'Filtrer par priorité';

  @override
  String get filterByRole => 'Filtrer par rôle';

  @override
  String get filterByStatus => 'Filtrer par état';

  @override
  String get filterByStatus2 => 'Filtrer par état2';

  @override
  String get filterBySubject => 'Filtrer par sujet';

  @override
  String get filterByTeacher => 'Filtrer par enseignant';

  @override
  String get filterByTeacher2 => 'Filtrer par enseignant2';

  @override
  String get filterFormResponsesByUser =>
      'Filtrer les réponses des formulaires par l\'utilisateur';

  @override
  String get filterRecurringTasks => 'Filtrer les tâches récurrentes';

  @override
  String get filters => 'Filtres';

  @override
  String get finalizeSchedule => 'Finaliser le calendrier';

  @override
  String get finalizeSchedulesForMatchedStudentsAnd =>
      'Finaliser les calendriers Pour des étudiants assortis et';

  @override
  String get financialSummary => 'Résumé financier';

  @override
  String get findPrograms => 'Trouver des programmes';

  @override
  String get findShiftsForAStudentMatching =>
      'Trouver des postes pour l\'appariement des étudiants AS';

  @override
  String get firstName => 'Prénom';

  @override
  String get firstName2 => 'Prénom2';

  @override
  String get firstname => 'Prénom';

  @override
  String get fixMyTimezoneOnly => 'Réparer mon fuseau horaire seulement';

  @override
  String get fixTimezone => 'Correction du fuseau horaire';

  @override
  String get fixTimezoneOrReportScheduleIssue =>
      'Correction du fuseau horaire ou du calendrier du rapport';

  @override
  String get footer => 'Pied de page';

  @override
  String get footerEditor => 'Éditeur de pied de page';

  @override
  String get forPrivacyQuestionsOrConcernsEmail =>
      'Pour des questions ou des préoccupations concernant la vie privée Courriel';

  @override
  String get forTheMonthSOfMonth => 'Pour le mois';

  @override
  String get forTheMonthSOfMonthcovered => 'Pour le mois';

  @override
  String get forgotPassword => 'Mot de passe oublié';

  @override
  String get form => 'Formulaire';

  @override
  String get formAlreadySubmitted => 'Formulaire déjà présenté';

  @override
  String get formBannedSuccessfully => 'Formulaire interdit avec succès';

  @override
  String get formCompliance => 'Conformité du formulaire';

  @override
  String get formDeleted => 'Formulaire supprimé';

  @override
  String get formDescription => 'Désignation du formulaire';

  @override
  String get formDescription2 => 'Désignation du formulaire2';

  @override
  String get formDetails => 'Détails du formulaire';

  @override
  String get formDuplicatedSuccessfully => 'Formulaire Dupliquer avec succès';

  @override
  String get formFields => 'Champs de formulaire';

  @override
  String get formLinkedToShiftSuccessfullyPayment =>
      'Formulaire lié au paiement réussi';

  @override
  String get formListResponseCounts =>
      'Nombres de réponses à la liste de formulaires';

  @override
  String formNotFoundIdFormidPlease(String formId) {
    return 'Formulaire introuvable (ID : $formId). Veuillez sélectionner un autre formulaire.';
  }

  @override
  String get formNotFoundPleaseContactAdmin =>
      'Formulaire non trouvé Veuillez contacter Admin';

  @override
  String get formResponses2 => 'Réponses au formulaire2';

  @override
  String get formSavedSuccessfully => 'Formulaire sauvegardé avec succès';

  @override
  String get formSavedSuccessfullyPreviousVersionsDeactivated =>
      'Formulaire sauvegardé avec succès Versions antérieures désactivées';

  @override
  String get formSettings => 'Paramètres du formulaire';

  @override
  String get formSubmitted => 'Formulaire présenté';

  @override
  String get formsWithNoSchedule => 'Formulaires sans horaire';

  @override
  String get auditTabOverview => 'Vue d\'ensemble';

  @override
  String get auditTabActivity => 'Activité';

  @override
  String get auditTabPayment => 'Paiement';

  @override
  String get auditTabForms => 'Formulaires';

  @override
  String get auditKeyIndicators => 'Indicateurs clés';

  @override
  String get auditPerformanceRates => 'Taux de performance';

  @override
  String get auditIssuesAlerts => 'Issues & alertes';

  @override
  String get auditClassesCompleted => 'Classes réalisées';

  @override
  String get auditHoursTaught => 'Heures enseignées';

  @override
  String get auditCompletionRateLabel => 'Taux de complétion';

  @override
  String get auditLateClockInsLabel => 'Retards de pointage';

  @override
  String get auditClassesMissedLabel => 'Classes manquées';

  @override
  String get auditNoLateClockIns => 'Aucun';

  @override
  String get auditNoMissedClasses => 'Aucune';

  @override
  String get auditClassCompletionRate => 'Complétion des classes';

  @override
  String get auditFormComplianceLabel => 'Conformité formulaires';

  @override
  String get auditNoIssuesDetected => 'Aucune issue détectée';

  @override
  String get auditFormsAccepted => 'Acceptés';

  @override
  String get auditFormsRejected => 'Rejetés';

  @override
  String auditFormsRejectedBreakdown(int noShift, int duplicates) {
    return '($noShift sans shift, $duplicates doublon)';
  }

  @override
  String get auditFormStatusAccepted => 'Accepté';

  @override
  String get auditFormStatusRejectedDuplicate => 'Rejeté (doublon)';

  @override
  String get auditFormStatusRejectedNoShift => 'Rejeté (sans shift)';

  @override
  String get auditTotalLabel => 'Total';

  @override
  String get auditFormsSubmittedLabel => 'Formulaires soumis';

  @override
  String get auditGeneralOrUnlinked => 'Général / Non lié';

  @override
  String get auditNoFormsSubmitted => 'Aucun formulaire soumis';

  @override
  String get auditTierExcellent => 'Excellent';

  @override
  String get auditTierGood => 'Bien';

  @override
  String get auditTierNeedsImprovement => 'À améliorer';

  @override
  String get auditTierCritical => 'Critique';

  @override
  String get auditStatusCompleted => 'Terminé';

  @override
  String get auditStatusSubmitted => 'Soumis';

  @override
  String get auditStatusDisputed => 'Contesté';

  @override
  String get auditStatusPending => 'En attente';

  @override
  String get teacherAuditTabSummary => 'Résumé';

  @override
  String get teacherAuditTabMyClasses => 'Mes classes';

  @override
  String get teacherAuditTabDispute => 'Contester';

  @override
  String get teacherAuditPaymentSection => 'Paiement';

  @override
  String get teacherAuditPerformanceSection => 'Performance';

  @override
  String get teacherAuditNetToReceive => 'NET À PERCEVOIR';

  @override
  String get teacherAuditPointsOfAttention => 'Points d\'attention';

  @override
  String get teacherAuditReportNotAvailable => 'Rapport non disponible';

  @override
  String teacherAuditReportNotFinalizedMessage(String month) {
    return 'Votre rapport pour $month n\'est pas encore finalisé ou n\'existe pas.';
  }

  @override
  String get teacherAuditClassesLabel => 'Classes';

  @override
  String get teacherAuditHoursLabel => 'Heures';

  @override
  String get teacherAuditFormsLabel => 'Formulaires';

  @override
  String get teacherAuditPunctualityLabel => 'Ponctualité';

  @override
  String get teacherAuditContestationSent => 'Contestation envoyée avec succès';

  @override
  String teacherAuditContestationError(String message) {
    return 'Erreur : $message';
  }

  @override
  String get teacherAuditNewDispute => 'Nouvelle contestation';

  @override
  String get teacherAuditExistingDispute => 'Contestation existante';

  @override
  String get teacherAuditAdminResponse => 'Réponse admin :';

  @override
  String get teacherAuditSelectField => 'Sélectionnez un champ';

  @override
  String get teacherAuditReasonLabel => 'Raison';

  @override
  String get teacherAuditSuggestedValue => 'Valeur correcte (optionnel)';

  @override
  String get teacherAuditSendDispute => 'Envoyer la contestation';

  @override
  String get teacherAuditSending => 'Envoi...';

  @override
  String get teacherAuditDisputeInfoMessage =>
      'Si vous pensez qu\'une donnée est incorrecte, soumettez une contestation ci-dessous. L\'équipe examinera votre demande.';

  @override
  String get teacherAuditFieldToDispute => 'Champ à contester';

  @override
  String get teacherAuditDetailReason =>
      'Expliquez pourquoi cette donnée vous semble incorrecte...';

  @override
  String get teacherAuditExampleValue => 'Ex. : 24h, 95 %, 3 classes...';

  @override
  String get teacherAuditGross => 'Brut';

  @override
  String get teacherAuditPenalties => 'Pénalités';

  @override
  String get teacherAuditBonuses => 'Bonus';

  @override
  String get teacherAuditAdminAdjustment => 'Ajustement admin';

  @override
  String get teacherAuditDisputeFieldLabel => 'Champ';

  @override
  String get auditPaymentCalculation => 'Calcul';

  @override
  String get auditHoursWorked => 'Heures travaillées';

  @override
  String get auditTotalAdjustments => 'Ajustements totaux';

  @override
  String get auditNetToPay => 'NET À PAYER';

  @override
  String get auditNoPaymentDataAvailable =>
      'Aucune donnée de paiement disponible';

  @override
  String get auditPaymentSummary => 'Récapitulatif de paiement';

  @override
  String get auditGrossSalary => 'Salaire brut';

  @override
  String get auditNetSalary => 'Salaire net';

  @override
  String get auditAdjustments => 'Ajustements';

  @override
  String get auditGlobalAdjustment => 'Ajustement global';

  @override
  String get formTemplates => 'Modèles de formulaire';

  @override
  String get formTitle => 'Titre du formulaire';

  @override
  String get formsCompliance => 'Formulaires Conformité';

  @override
  String get formsReports => 'Formulaires Rapports';

  @override
  String get founder => 'Fondateur';

  @override
  String get frequency => 'Fréquence';

  @override
  String get fromBasicArithmeticToAdvancedCalculus =>
      'De l\'arithmétique basique au calcul avancé';

  @override
  String get fromLogicalThinkingForKidsTo =>
      'De la pensée logique pour les enfants à';

  @override
  String get fromMasteringEnglishGrammarAndVocabulary =>
      'De Mastering Grammaire Anglais Et Vocabulaire';

  @override
  String get fromParentdisplayForStudentSStudentdisplay =>
      'De Parentdisplay pour l\'étudiant SStudentdisplay';

  @override
  String get fromParentnameForStudentSStudentname =>
      'De Parentname Pour l\'étudiant SStudentname';

  @override
  String get fromSupportAlluwaleducationhubOrg =>
      'De Support Alluwaleducationhub Organisme';

  @override
  String get fullAdmin => 'Admin complet';

  @override
  String get fullAdminPrivileges => 'Privilèges administratifs complets';

  @override
  String get fullscreen => 'Plein écran';

  @override
  String get generalSettings => 'Paramètres généraux';

  @override
  String get generateAudits => 'Générer des audits';

  @override
  String get generateNow => 'Générer maintenant';

  @override
  String get generatingCsv => 'Génération de Csv';

  @override
  String get generatingExcelReport => 'Générer un rapport Excel';

  @override
  String get getHelpContactUs => 'Obtenir de l\'aide Contactez-nous';

  @override
  String get getHelpUsingTheApp =>
      'Obtenir de l\'aide Utilisation de l\'application';

  @override
  String get getInTouch => 'Contactez-nous';

  @override
  String get getNotifiedBeforeTaskDueDate =>
      'Faites une notification avant la date d\'échéance de la tâche';

  @override
  String get getNotifiedBeforeYourShiftStarts =>
      'Faites une déclaration avant de commencer votre quart de travail';

  @override
  String get getNotifiedWhenYouReceiveMessages =>
      'Soyez informé lorsque vous recevez des messages';

  @override
  String get gettingNotifications => 'Obtenir des notifications';

  @override
  String get globalLanguagesProgram => 'Programme des langues mondiales';

  @override
  String get globalTeacherHourlyRateUsd => 'Global enseignant horaire taux usd';

  @override
  String get goToSite => 'Aller au site';

  @override
  String get goodMorning => 'Bonjour.';

  @override
  String get gotIt => 'Compris.';

  @override
  String get gradePerformance => 'Rendement par catégorie';

  @override
  String get greenWelcomeEmailForNewUsers =>
      'Email de bienvenue vert pour les nouveaux utilisateurs';

  @override
  String get gridView => 'Affichage de la grille';

  @override
  String get groupBy => 'Groupe par';

  @override
  String get groupChat => 'Discussion de groupe';

  @override
  String get groupInfo => 'Informations sur le groupe';

  @override
  String get guestClassLinkCopied => 'Lien de classe invité copié';

  @override
  String get hasAudit => 'Vérification';

  @override
  String get hassimiouNiane => 'Hassimiou Niane';

  @override
  String get healthy => 'Santé';

  @override
  String get help => 'Aide';

  @override
  String get heroSection => 'Section des héros';

  @override
  String get heroSectionEditor => 'Éditeur de section Hero';

  @override
  String get hide => 'Masquer';

  @override
  String get high => 'Élevé';

  @override
  String get highSchoolStudent => 'Élève du secondaire';

  @override
  String get history => 'Historique';

  @override
  String get hn => 'Hn';

  @override
  String get hourlyRate => 'Taux horaire';

  @override
  String get hourlyRateUsd => 'Taux horaire utilisé';

  @override
  String get hourlyWage => 'Salaire horaire';

  @override
  String get hours => 'Heures';

  @override
  String get hoursBySubject => 'Heures par sujet';

  @override
  String get hoursTaught => 'Heures enseignées';

  @override
  String get howToJoinAClass => 'Comment rejoindre AClass';

  @override
  String get howWeUseYourInformation =>
      'Comment nous utilisons vos informations';

  @override
  String get iAmABeginner => 'Je suis débutant';

  @override
  String get iAmExcellent => 'Je suis excellent';

  @override
  String get iAmIntermediate => 'Je suis intermédiaire';

  @override
  String get iMemorizeLessThanJuzuAnma => 'Je mémorise moins que Juzu Anna';

  @override
  String get iconDescription => 'Désignation des icônes';

  @override
  String get idCode => 'Code d\'identification';

  @override
  String idDisplaystudentcode(Object studentCode) {
    return 'ID : $studentCode';
  }

  @override
  String get ifLeftBlankASecurePassword =>
      'Si gauche blanc ASecure Mot de passe';

  @override
  String get ifYouBelieveThereSAn => 'Si vous y croyez SAn';

  @override
  String get imageUploadFailed => 'Impossible de télécharger l\'image';

  @override
  String get immerseInTheProfoundNdepthsOf =>
      'Immerger dans les profondeurs profondes de';

  @override
  String get inAMonthFromNow => 'À partir de maintenant';

  @override
  String get inOneWeekFromNow => 'Dans une semaine à partir de maintenant';

  @override
  String get inThreeWeeksFromNow => 'Dans trois semaines';

  @override
  String get inTwoWeeksFromNow => 'Dans deux semaines';

  @override
  String get individual => 'Individuel';

  @override
  String get individualUser => 'Utilisateur individuel';

  @override
  String get informationWeCollect => 'Information que nous recueillons';

  @override
  String get initializingApplication => 'Initialisation de la demande';

  @override
  String get interactiveLearningExperience =>
      'Expérience d\'apprentissage interactif';

  @override
  String get internalName => 'Nom interne';

  @override
  String get invoiceDetails => 'Détails de la facture';

  @override
  String get invoiceNotFoundForThisPayment =>
      'Facture non trouvée pour ce paiement';

  @override
  String get invoices => 'Factures';

  @override
  String get isAdminIsadmin => 'Est administrateur Isadmin';

  @override
  String get isParentIsparent => 'Est parent Isparent';

  @override
  String get isStudentIsstudent => 'Est étudiant étudiant';

  @override
  String get isTeacherIsteacher => 'C\'est l\'enseignant.';

  @override
  String get islamicCalendar => 'Calendrier islamique';

  @override
  String get islamicPrograms => 'Programmes islamiques';

  @override
  String get islamicStudiesTeacher => 'Professeur d\'études islamiques';

  @override
  String get issuesFlags => 'Drapeaux';

  @override
  String get issuesToAddress => 'Questions à régler';

  @override
  String get janeSmithEmailCom => 'Jane Smith Courriel Com';

  @override
  String get johnDoeEmailCom => 'John Doe Email Com';

  @override
  String get joinClass => 'Rejoindre la classe';

  @override
  String get joinLiveClass => 'Rejoindre la classe en direct';

  @override
  String get joinLiveClasses => 'Rejoignez les classes en direct';

  @override
  String get joinNow => 'Rejoignez maintenant';

  @override
  String get joinOurLeadershipTeam => 'Rejoignez notre équipe de leadership';

  @override
  String get joinOurLeadershipTeam2 => 'Rejoignez notre équipe de leadership2';

  @override
  String get joinOurTeam => 'Rejoignez notre équipe';

  @override
  String get joinOurTeamOfDedicatedIslamic =>
      'Rejoignez notre équipe de l\'islam dédié';

  @override
  String get joinThousandsOfMuslimFamiliesWorldwide =>
      'Rejoignez des milliers de familles musulmanes dans le monde';

  @override
  String get joinThousandsOfStudentsExcellingIn =>
      'Rejoignez des milliers d\'étudiants Excelling in';

  @override
  String get joinThousandsOfStudentsLearningFrom =>
      'Joignez-vous à des milliers d\'étudiants';

  @override
  String get joiningClass => 'Rejoindre la classe';

  @override
  String get jpgPngGifUpTo10mb => 'Jpg Png Gif jusqu\'à 10m b';

  @override
  String get jumpToDate => 'Aller à la date';

  @override
  String get k12Support => 'K12Support';

  @override
  String get keepTheirTeacherRoleIntact =>
      'Gardez leur rôle d\'enseignant Intact';

  @override
  String get keyPerformanceIndicators => 'Principaux indicateurs de rendement';

  @override
  String get kioskCode => 'Code du kiosque';

  @override
  String get kioskCodeKioskcodeAlreadyExistsPlease =>
      'Kiosque Code Kiosque existe déjà S\'il vous plaît.';

  @override
  String get laDureEDoitETre => 'La Dure EDoit ETre';

  @override
  String get label => 'Étiquette';

  @override
  String get label2 => 'Étiquette2';

  @override
  String get labelCopied => 'Étiquette copiée';

  @override
  String get labelOptional => 'Étiquette Facultative';

  @override
  String get labelValue => 'Valeur de l\'étiquette';

  @override
  String get labelsOptional => 'Étiquettes Facultatives';

  @override
  String get languageExcellence => 'Excellence linguistique';

  @override
  String get languagesWeOffer => 'Langues que nous offrons';

  @override
  String get last24Hours => 'Dernières 24heures';

  @override
  String get lastClassCompleted => 'Dernière classe terminée';

  @override
  String get lastLogin => 'Dernière connexion';

  @override
  String get lastModified => 'Dernière modification';

  @override
  String get lastName => 'Nom de famille';

  @override
  String get lastName2 => 'Nom de famille2';

  @override
  String get lastSystemCheck => 'Dernière vérification du système';

  @override
  String get lastTaskCompleted => 'Dernière tâche terminée';

  @override
  String get lastUpdatedJanuary2024 => 'Dernière mise à jour janvier2024';

  @override
  String get later => 'Plus tard';

  @override
  String get lePaiementSeraCalculeDureE => 'Le Paiement Sera Calcul Dure E';

  @override
  String get leSujetEstRequis => 'Le Sujet Est Requis';

  @override
  String get leadInspireAndMakeALasting => 'Inspirer et faire durer';

  @override
  String get leaderDuty => 'Chef de file';

  @override
  String get leadersOnly => 'Leaders seulement';

  @override
  String get leadershipInterest => 'Intérêt du leadership';

  @override
  String get learnEnglishReadingWritingSpeakingFor =>
      'Apprendre l\'anglais lecture écriture parler pour';

  @override
  String get learnFromCertifiedNislamicScholars =>
      'Apprendre des chercheurs Nislamiques certifiés';

  @override
  String get learnLeadThrive => 'Apprendre le plomb Thrive';

  @override
  String get learnMore => 'En savoir plus';

  @override
  String get learningTracks => 'Les pistes d\'apprentissage';

  @override
  String get leave => 'Quitter';

  @override
  String get leaveClass => 'Quitter la classe';

  @override
  String get lessComfortable => 'Moins confortable';

  @override
  String get letSGetStarted => 'Laissez-le commencer';

  @override
  String get link => 'Lien';

  @override
  String get linkForm => 'Formulaire de lien';

  @override
  String get linkFormToShift => 'Lien vers le formulaire de déplacement';

  @override
  String get linkToShift => 'Lien vers le déplacement';

  @override
  String get linkYourAccountToManageAll =>
      'Lien de votre compte pour gérer tout';

  @override
  String get linkingFormAndRecalculatingPayment =>
      'Lier le formulaire et recalculer le paiement';

  @override
  String get listView => 'Affichage de la liste';

  @override
  String get live => 'Vivre';

  @override
  String get live2 => 'En direct2';

  @override
  String get liveOnJobBoard => 'Conseil d\'administration en direct';

  @override
  String get liveParticipants => 'Participants vivants';

  @override
  String get livePreview => 'Aperçu en direct';

  @override
  String get liveWebinars => 'Webinaires en direct';

  @override
  String get loadUserRole => 'Chargement du rôle de l\'utilisateur';

  @override
  String get loadUserRoleFirst => 'Charger d\'abord le rôle de l\'utilisateur';

  @override
  String get loadingAuditsForSelectedyearmonth => 'Chargement des audits…';

  @override
  String get loadingDashboard => 'Chargement du tableau de bord';

  @override
  String get loadingEvaluationFactors =>
      'Chargement des facteurs d\'évaluation';

  @override
  String get loadingForms => 'Chargement des formulaires';

  @override
  String get loadingMessages => 'Chargement des messages';

  @override
  String get loadingPrayerTimes => 'Chargement des heures de prière';

  @override
  String get loadingProfile => 'Chargement du profil';

  @override
  String get loadingSeries => 'Chargement des séries';

  @override
  String get loadingShiftInformation =>
      'Chargement de l\'information sur le déplacement';

  @override
  String get loadingStudents => 'Chargement des étudiants';

  @override
  String get loadingTeachers => 'Chargement des enseignants';

  @override
  String get loadingUserProfile => 'Chargement du profil utilisateur';

  @override
  String get loadingWebsiteContent => 'Chargement du contenu du site Web';

  @override
  String get loadingYourExistingProfileInformation =>
      'Chargement de l\'information existante sur votre profil';

  @override
  String get locationError => 'Erreur d\'emplacement';

  @override
  String get locationInformation => 'Informations sur l\'emplacement';

  @override
  String get locationInformationRequired =>
      'Renseignements sur l\'emplacement requis';

  @override
  String get locationInformationWasNotCapturedFor =>
      'L\'information sur l\'emplacement n\'a pas été saisie pour';

  @override
  String get locationIsMandatoryForAllTimesheet =>
      'L\'emplacement est obligatoire pour tous les horaires';

  @override
  String get locationIsMandatoryPleaseWaitFor =>
      'L\'emplacement est obligatoire Veuillez attendre';

  @override
  String get locationOptional => 'Emplacement Facultatif';

  @override
  String get logIn => 'Connectez-vous';

  @override
  String get logInSignUp => 'Connexion Inscription';

  @override
  String get logOutOfYourAccount => 'Déconnexion de votre compte';

  @override
  String get loginLogs => 'Connexion des journaux';

  @override
  String get logs => 'Registres';

  @override
  String get longAnswerText => 'Texte de la longue réponse';

  @override
  String get mainHeadline => 'En-tête principal';

  @override
  String get maintenance => 'Entretien';

  @override
  String get manageIndividualWages => 'Gérer les individus Salaires';

  @override
  String get manageRoleBasedWages => 'Gérer les salaires basés sur le rôle';

  @override
  String get manageShift => 'Gérer le déplacement';

  @override
  String get manageStudentApplicationsAndEnrollment =>
      'Gérer les demandes des étudiants Et Inscription';

  @override
  String get manageSubjects => 'Gérer les sujets';

  @override
  String get manageSubjectsForShiftCreation =>
      'Gérer les sujets pour la création de postes';

  @override
  String get manageTeacherPerformanceAndPayments =>
      'Gérer le rendement et les paiements des enseignants';

  @override
  String get managerNotes => 'Notes du gestionnaire';

  @override
  String get managerNotes2 => 'Notes du gestionnaire2';

  @override
  String get markAsPending => 'Marquer comme en attente';

  @override
  String get markAsReviewed => 'Marques examinées';

  @override
  String get markedAsContactedMovedToReady =>
      'Marqué comme contacté déplacé à prêt';

  @override
  String get masterEnglishAfricanNindigenousLanguages =>
      'Master Anglais African Nindigenous Langues';

  @override
  String get masterEnglishWithNconfidenceFluency =>
      'Maîtriser l\'anglais avec confiance en soi';

  @override
  String get masterMathematicsWithNconfidenceClarity =>
      'Master Mathématiques Avec confiance en soi Clarity';

  @override
  String get matched => 'Corrigé';

  @override
  String get mathematicsIsMoreThanJustNumbers =>
      'Les mathématiques sont plus que des chiffres';

  @override
  String get mathematicsProgram => 'Programme de mathématiques';

  @override
  String get mayAllahBlessYourTeachingEfforts =>
      'Puisse Allah bénir vos efforts d\'enseignement';

  @override
  String get maybeButIWillTry => 'Peut-être, mais je le ferai Essaie';

  @override
  String get meeting => 'Réunion';

  @override
  String get meetingIsNotReadyYetContact =>
      'La réunion n\'est pas encore prête Contact';

  @override
  String get menu => 'Menu';

  @override
  String get message => 'Message';

  @override
  String get messageDeletionNotYetImplemented =>
      'Suppression du message non encore mise en œuvre';

  @override
  String get messageForwardingNotYetImplemented =>
      'Message transmis non encore mis en œuvre';

  @override
  String get messageSentSuccessfullyWeWillContact =>
      'Message envoyé avec succès Nous contacterons';

  @override
  String get methodFirebaseCloudFunctionHostingerSmtp =>
      'Méthode Firebase Cloud Fonction Hostinger Smtp';

  @override
  String get minutesMinutes => 'Procès-verbal';

  @override
  String get missedShiftClassReportRequired =>
      'Rapport de classe de poste manquant requis';

  @override
  String get mobilePhone => 'Téléphone portable';

  @override
  String get modificationHistory => 'Historique des modifications';

  @override
  String get modifiedSchedule => 'Calendrier modifié';

  @override
  String get monthly => 'Mensuel';

  @override
  String get monthlyFeesPayment => 'Paiement des taxes mensuelles';

  @override
  String get monthlyRecurrenceSettings => 'Paramètres mensuels de récurrence';

  @override
  String get moreOptions => 'Autres options';

  @override
  String get moveAllShifts1HourEarlier =>
      'Déplacer tous les postes1heure plus tôt';

  @override
  String get moveAllShifts1HourLater =>
      'Déplacer tous les postes1heure plus tard';

  @override
  String get moveDown => 'Déplacer vers le bas';

  @override
  String get moveUp => 'En haut';

  @override
  String get muteAll => 'Mute tout';

  @override
  String get muteEveryone => 'Mute tout le monde';

  @override
  String get myAssignments => 'Mes missions';

  @override
  String get myChildren => 'Mes enfants';

  @override
  String get myClasses => 'Mes cours';

  @override
  String get myIslamicClasses => 'Mes classes islamiques';

  @override
  String get myMonthlyReport => 'Mon rapport mensuel';

  @override
  String get myPerformanceAudit => 'Mon audit de rendement';

  @override
  String get myProgress => 'Mes progrès';

  @override
  String get myStudents => 'Mes étudiants';

  @override
  String get myStudentsOverview => 'Aperçu de mes élèves';

  @override
  String get nA => 'N A';

  @override
  String get nameAZ => 'Nom AZ';

  @override
  String get navigatingToAddNewUser =>
      'Navigation pour ajouter un nouvel utilisateur';

  @override
  String get navigatingToFormBuilder =>
      'Naviguer vers le constructeur de formulaire';

  @override
  String get navigatingToReports => 'Navigation vers les rapports';

  @override
  String get navigation => 'Navigation';

  @override
  String get needHelpWeReHereFor => 'Besoin d\'aide Nous sommes ici pour';

  @override
  String get needsRevision => 'Révision des besoins';

  @override
  String get never => 'Jamais';

  @override
  String get neverLoggedIn => 'Jamais accroché';

  @override
  String get neverMissAClass => 'Ne manquez jamais la classe A';

  @override
  String get newEndTime => 'Nouvelle heure de fin';

  @override
  String get newHourlyWage => 'Nouveau salaire horaire';

  @override
  String get newPassword => 'Nouveau mot de passe';

  @override
  String get newStartTime => 'Nouvelle heure de départ';

  @override
  String get newStudentWillBeLinkedTo => 'Un nouvel étudiant sera lié à';

  @override
  String get newVersion => 'Nouvelle version';

  @override
  String get newestFirst => 'Première';

  @override
  String get nextWeek => 'Semaine prochaine';

  @override
  String get noActiveFormsFound => 'Aucun formulaire actif trouvé';

  @override
  String get noActiveShift => 'Pas de changement actif';

  @override
  String get noAdminUsersFound => 'Aucun utilisateur Admin trouvé';

  @override
  String get noApplicationsFound => 'Aucune application trouvée';

  @override
  String get noAssignmentsYet => 'Aucune affectation Encore';

  @override
  String get noAttachments => 'Pas de pièces jointes';

  @override
  String get noAttachmentsAdded => 'Aucune pièce jointe ajoutée';

  @override
  String get noAttachmentsYet => 'Pas encore de pièces jointes';

  @override
  String get noAuditDataAvailable => 'Aucune donnée de vérification disponible';

  @override
  String get noAuditDataForSelectedmonth =>
      'Pas de données d\'audit pour le mois sélectionné';

  @override
  String get noAuditsFound => 'Aucun audit trouvé';

  @override
  String get noAvailableShifts => 'Pas de postes disponibles';

  @override
  String get noChildrenLinkedToThisParent => 'Aucun enfant lié à ce parent';

  @override
  String get noClassHistory => 'Pas d\'historique de classe';

  @override
  String get noClassesAvailable => 'Aucune catégorie disponible';

  @override
  String get noClassesFound => 'Aucune classe trouvée';

  @override
  String get noClassesRightNow => 'Pas de classes en ce moment';

  @override
  String get noClassesScheduledToday => 'Aucune classe prévue aujourd\'hui';

  @override
  String get noClassesToday => 'Pas de classes aujourd\'hui';

  @override
  String get noCommentsYet => 'Pas encore de commentaire';

  @override
  String get noCompleteRowsToSave => 'Pas de lignes complètes à enregistrer';

  @override
  String get noContentAvailable => 'Aucun contenu disponible';

  @override
  String get noData => 'Aucune donnée';

  @override
  String get noDataAvailable => 'Aucune donnée disponible';

  @override
  String get noDataFoundToExport => 'Aucune donnée trouvée pour exporter';

  @override
  String get noDataToExport => 'Aucune donnée à exporter';

  @override
  String get noDataToExportWithCurrent =>
      'Aucune donnée à exporter avec le courant';

  @override
  String get noDataWillBePermanentlyLost =>
      'Aucune donnée ne sera définitivement perdue';

  @override
  String get noDataYet => 'Aucune donnée Encore';

  @override
  String get noDevice => 'Aucun périphérique';

  @override
  String get noDocumentsFoundInThisCollection =>
      'Aucun document trouvé dans cette collection';

  @override
  String get noFieldsYetAddYourFirst =>
      'Aucun champ encore ajouter votre premier';

  @override
  String get noFilesSelected => 'Aucun fichier sélectionné';

  @override
  String get noFilledOpportunitiesYet => 'Aucune possibilité remplie Encore';

  @override
  String get noForm => 'Aucun formulaire';

  @override
  String get noFormFieldsAreCurrentlyVisible =>
      'Aucun champ de formulaire n\'est actuellement visible';

  @override
  String get noFormResponsesFound => 'Aucune réponse trouvée';

  @override
  String get noFormResponsesToExport =>
      'Aucune réponse au formulaire à exporter';

  @override
  String get noFormsFound => 'Aucun formulaire trouvé';

  @override
  String get noFormsSubmittedForThisPeriod =>
      'Aucun formulaire soumis pour cette période';

  @override
  String get noFormsYet => 'Aucun formulaire Encore';

  @override
  String get noICanT => 'Non, je ne peux pas.';

  @override
  String get noInternet => 'Pas d\'Internet';

  @override
  String get noInvoicesFound => 'Aucune facture trouvée';

  @override
  String get noInvoicesYet => 'Pas encore de factures';

  @override
  String get noItemsOnThisInvoice => 'Aucun élément sur cette facture';

  @override
  String get noKnownStudentsYet => 'Aucun élève connu Encore';

  @override
  String get noLabelsAvailable => 'Aucune étiquette disponible';

  @override
  String get noMatchingLogsYet => 'Pas de journaux correspondants Encore';

  @override
  String get noOneHasJoinedYet => 'Personne ne s\'est joint Encore';

  @override
  String get noOneIsInTheRoom => 'Personne n\'est dans la chambre';

  @override
  String get noOptionsAvailable => 'Aucune option disponible';

  @override
  String get noOrphanShiftsFoundNearby =>
      'Aucun poste d\'orphelin trouvé à proximité';

  @override
  String get noParentsFound => 'Aucun parent trouvé';

  @override
  String get noParticipants => 'Pas de participants';

  @override
  String get noParticipantsYet => 'Pas de participants Encore';

  @override
  String get noPaymentDataAvailable => 'Aucune donnée de paiement disponible';

  @override
  String get noPaymentsYet => 'Pas encore de paiements';

  @override
  String get noRatesConfigured => 'Aucun tarif configuré';

  @override
  String get noRecentActivity => 'Aucune activité récente';

  @override
  String get noRecentLessons => 'Pas de leçons récentes';

  @override
  String get noRecentShiftsFoundToReport =>
      'Aucun changement récent trouvé pour signaler';

  @override
  String get noResponse => 'Pas de réponse';

  @override
  String get noResponseDataAvailable => 'Aucune donnée de réponse disponible';

  @override
  String get noResponses => 'Pas de réponse';

  @override
  String get noResponsesFound => 'Aucune réponse trouvée';

  @override
  String get noResponsesRecorded => 'Aucune réponse enregistrée';

  @override
  String get noSavedDrafts => 'Pas d\'ébauches sauvegardées';

  @override
  String get noScheduledShiftsFoundToDelete =>
      'Aucun changement prévu trouvé pour supprimer';

  @override
  String get noScheduledShiftsFoundToEdit =>
      'Aucun changement prévu trouvé pour modifier';

  @override
  String get noShiftAssociated => 'Pas de poste associé';

  @override
  String get noShiftsOrFormsFoundFor =>
      'Aucun changement ou formulaire trouvé pour';

  @override
  String get noShiftsSelected => 'Aucun changement sélectionné';

  @override
  String get noShiftsWithFormsFoundLink =>
      'Aucun changement avec les formulaires trouvés lien';

  @override
  String get missedClassFormSubmittedRecovery =>
      'Cours manqué • Formulaire soumis (récupération)';

  @override
  String get noStudentsAvailableInTheSystem =>
      'Aucun étudiant disponible dans le système';

  @override
  String get noStudentsFound => 'Aucun étudiant trouvé';

  @override
  String get noStudentsHaveJoinedTheClass =>
      'Aucun étudiant n\'a rejoint La classe';

  @override
  String get noStudentsYet => 'Pas encore d\'étudiants';

  @override
  String get noSubTasksClickAddTo =>
      'Pas de tâches secondaires Cliquez sur Ajouter à';

  @override
  String get noSubjectData => 'Aucune donnée';

  @override
  String get noSubmissionsToExport => 'Aucune présentation à l\'exportation';

  @override
  String get noTasksFound => 'Aucune tâche trouvée';

  @override
  String get noTeachersFound => 'Aucun enseignant trouvé';

  @override
  String get noTeachersFoundMakeSureTeachers =>
      'Aucun enseignant trouvé. Vérifiez que des audits existent pour la période choisie.';

  @override
  String get noTemplatesForThisFrequency =>
      'Pas de modèles pour cette fréquence';

  @override
  String get noTimesheetFoundForThisShift =>
      'Aucune feuille de temps trouvée pour ce changement';

  @override
  String get noTimesheetRecordFoundForThis =>
      'Aucun enregistrement de feuille de temps trouvé pour Cette';

  @override
  String get noTimesheetsFound => 'Aucune feuille de temps trouvée';

  @override
  String get noUnlinkedFormsFoundNearby =>
      'Aucun formulaire non lié trouvé à proximité';

  @override
  String get noUpcomingClasses => 'Aucune classe à venir';

  @override
  String get noUpcomingEvents => 'Pas d\'événements à venir';

  @override
  String get noUsersAvailableToAdd => 'Aucun utilisateur disponible à ajouter';

  @override
  String get noUsersSelected => 'Aucun utilisateur sélectionné';

  @override
  String get noValidShiftFoundForClock =>
      'Aucun poste valide trouvé pour l\'horloge';

  @override
  String get noVideoCallIsConfiguredFor =>
      'Aucun appel vidéo n\'est configuré pour';

  @override
  String get notAtAll => 'Pas du tout';

  @override
  String get notConnected => 'Non connecté';

  @override
  String get noteSavedSuccessfully => 'Note enregistrée avec succès';

  @override
  String get noteStudentsNeedingEnglishHelpShould =>
      'Remarque Les étudiants qui ont besoin d\'aide en anglais devraient';

  @override
  String get notes => 'Annexe';

  @override
  String get notificationContent => 'Contenu de la notification';

  @override
  String get notificationMessage => 'Message de notification';

  @override
  String get notificationPreferences => 'Préférences de notification';

  @override
  String get notificationPreferencesSaved =>
      'Préférences de notification enregistrées';

  @override
  String get notificationResults => 'Résultats de la notification';

  @override
  String get notificationSent => 'Notification envoyée';

  @override
  String get notificationSettings => 'Paramètres de notification';

  @override
  String get notificationTitle => 'Titre de la notification';

  @override
  String get notificationsHelpYouStayOnTop =>
      'Les notifications vous aident à rester en haut';

  @override
  String get notificationsPrivacyTheme => 'Avis Confidentialité Thème';

  @override
  String get notificationsWillBeSentInstantlyTo =>
      'Les notifications seront envoyées immédiatement à';

  @override
  String get notifyMeBeforeDueDate =>
      'Avertissez-moi avant la date d\'échéance';

  @override
  String get notifyMeBeforeShift => 'Avertissez-moi avant le changement';

  @override
  String get number => 'Numéro';

  @override
  String get oftenFewDaysAWeek => 'Souvent peu de jours';

  @override
  String get okay => 'Très bien.';

  @override
  String get oldDraftsCleanedUpSuccessfully =>
      'Anciens drafts nettoyés avec succès';

  @override
  String get oldestFirst => 'Les plus vieux d\'abord';

  @override
  String get onceSubmittedYouCannotEditThis =>
      'Une fois soumis, vous ne pouvez pas modifier Cette';

  @override
  String get oneTimeOnly => 'Une seule fois';

  @override
  String get onlyIfYouNeedTheRaw => 'Seulement si vous avez besoin de la brute';

  @override
  String get onlyScheduledShiftsThatHavenT =>
      'Seuls les postes programmés qui ont';

  @override
  String get onlyTeachersCanShareTheirScreen =>
      'Seuls les enseignants peuvent partager leur écran';

  @override
  String get onlyTheTaskCreatorCanDelete =>
      'Seul le Créateur de la tâche peut supprimer';

  @override
  String get open => 'Ouvrir';

  @override
  String get openActivityLog => 'Ouvrir le journal des activités';

  @override
  String get openCheckoutLinkAgain => 'Ouvrez encore le lien de vérification';

  @override
  String get openSettings => 'Ouvrir les paramètres';

  @override
  String get openingFilename => 'Ouverture du nom de fichier';

  @override
  String get operational => 'Opérations';

  @override
  String get option1Option2Option3 => 'Option1Option2Option3';

  @override
  String get options => 'Options';

  @override
  String get or => 'Ou';

  @override
  String get orangeTaskAssignmentNotification =>
      'Notification d\'attribution de tâches orange';

  @override
  String get original => 'FRANÇAIS Original';

  @override
  String get originalDataNotAvailable => 'Données originales non disponibles';

  @override
  String get originalSchedule => 'Calendrier initial';

  @override
  String get other => 'Autres';

  @override
  String get ourIslamicCourses => 'Nos cours islamiques';

  @override
  String get ourIslamicProgramIsMeticulouslyDesigned =>
      'Notre programme islamique est conçu avec méticulosité';

  @override
  String get ourJourney => 'Notre voyage';

  @override
  String get ourLanguageProgramsAreDesignedTo =>
      'Nos programmes linguistiques sont conçus pour';

  @override
  String get ourLeadership => 'Notre leadership';

  @override
  String get ourMission => 'Notre mission';

  @override
  String get ourTeachers => 'Nos enseignants';

  @override
  String get ourTeachersAreCertifiedIslamicScholars =>
      'Nos enseignants sont des chercheurs islamiques certifiés';

  @override
  String get ourVision => 'Notre vision';

  @override
  String get overallAttendance => 'Participation générale';

  @override
  String get overallScore => 'Score général';

  @override
  String get overdue => 'Excédent';

  @override
  String get overdue2 => 'Excédent2';

  @override
  String get overduetasksOverdue => 'Excédents';

  @override
  String get overview => 'Aperçu général';

  @override
  String get parentResources => 'Ressources parentales';

  @override
  String get parentSettings => 'Paramètres parent';

  @override
  String get parents => 'Les parents';

  @override
  String get participantcount => 'Nombre de participants';

  @override
  String get participantcountInClass => 'Nombre de participants En classe';

  @override
  String get participants => 'Participants';

  @override
  String get passwordChangedSuccessfully => 'Mot de passe modifié avec succès';

  @override
  String get passwordsDoNotMatch => 'Les mots de passe ne correspondent pas';

  @override
  String get pleaseEnterCurrentPassword =>
      'Veuillez entrer votre mot de passe actuel';

  @override
  String get pleaseEnterNewPassword =>
      'Veuillez entrer un nouveau mot de passe';

  @override
  String get pleaseConfirmNewPassword =>
      'Veuillez confirmer votre nouveau mot de passe';

  @override
  String get passwordMustBeAtLeast6Characters =>
      'Le mot de passe doit contenir au moins 6 caractères';

  @override
  String get failedToChangePassword =>
      'Échec de la modification du mot de passe';

  @override
  String get incorrectCurrentPassword => 'Mot de passe actuel incorrect';

  @override
  String get passwordTooWeak => 'Le mot de passe est trop faible';

  @override
  String get updateYourPassword => 'Mettre à jour votre mot de passe';

  @override
  String get studentId => 'ID étudiant';

  @override
  String get passwordRequirements => 'Exigences relatives au mot de passe';

  @override
  String get passwordResetInitiatedForAllUsers =>
      'Mot de passe Reset Initié pour tous les utilisateurs';

  @override
  String get passwordResetSuccessfully =>
      'Mot de passe Réinitialiser avec succès';

  @override
  String get payInvoice => 'Facture de paye';

  @override
  String get payNow => 'Payez maintenant';

  @override
  String get paySettings => 'Paramètres de paye';

  @override
  String get payment => 'Paiement';

  @override
  String get paymentAdjustedSuccessfully => 'Paiement ajusté avec succès';

  @override
  String get paymentBySubject => 'Paiement par sujet';

  @override
  String get paymentHistory => 'Historique des paiements';

  @override
  String get paymentHistoryWillAppearOnceYou =>
      'L\'historique des paiements apparaîtra une fois que vous';

  @override
  String get payments => 'Paiements';

  @override
  String get penaltyPerMissedClass => 'Peine par classe manquante';

  @override
  String get penaltyPerMissing => 'Pénalité par manque';

  @override
  String get penaltyPerShift => 'Peine par poste';

  @override
  String get pendingapprovals => 'Approbations en attente';

  @override
  String get performance => 'Rendement';

  @override
  String get performanceEvaluation => 'Évaluation du rendement';

  @override
  String get performanceSummaryCopied => 'Résumé du rendement Copié';

  @override
  String get performanceSummaryCopiedToClipboard =>
      'Sommaire du rendement Copied to Clipboard';

  @override
  String get performanceTier => 'Niveau de performance';

  @override
  String get permanentlyDeleteUser =>
      'Supprimer définitivement l\' utilisateur';

  @override
  String get permissionsDenied => 'Autorisations refusées';

  @override
  String get permissionsRequired => 'Autorisations requises';

  @override
  String get personalInformation => 'Renseignements personnels';

  @override
  String get phoneNumberOptional => 'Numéro de téléphone Facultatif';

  @override
  String get pictureInPicture => 'Image en image';

  @override
  String get pilot => 'Pilote';

  @override
  String get pilotOnly => 'Pilote seulement';

  @override
  String get placeholder => 'Titulaire';

  @override
  String get placeholderOptional => 'Dépositaire Facultatif';

  @override
  String get platformUptime => 'Mise à jour de la plateforme';

  @override
  String get pleaseCheck => 'Veuillez vérifier';

  @override
  String get pleaseCheckYourInternetConnectionAnd =>
      'Veuillez vérifier votre connexion Internet et';

  @override
  String get pleaseContactYourSupervisorIfYou =>
      'Veuillez contacter votre superviseur';

  @override
  String get pleaseEnablePermissionsInSettingsTo =>
      'Veuillez activer les permissions dans les paramètres';

  @override
  String get pleaseEnterAFormTitle => 'Veuillez saisir le titre du formulaire';

  @override
  String get pleaseEnterAValidNumber => 'Veuillez saisir le numéro AValid';

  @override
  String get pleaseEnterAValidWageAmount =>
      'Veuillez saisir le montant du salaire AValid';

  @override
  String get pleaseEnterYourCurrentPasswordAnd =>
      'Veuillez saisir votre mot de passe actuel et';

  @override
  String get pleaseExplainWhyYouBelieveThis =>
      'Expliquez pourquoi vous croyez Cette';

  @override
  String get pleaseFillInAllRequiredFields =>
      'Veuillez remplir tous les champs obligatoires';

  @override
  String get pleaseProvideAReason => 'Veuillez fournir AReason';

  @override
  String get pleaseProvideAReasonForRejection =>
      'Veuillez fournir AReason pour rejet';

  @override
  String get pleaseProvideAtLeastOneOption =>
      'Veuillez fournir au moins une option';

  @override
  String get pleaseRefreshThePage => 'Veuillez rafraîchir La page';

  @override
  String get pleaseSelectADutyTypeFor => 'Veuillez sélectionner ADuty Type for';

  @override
  String get pleaseSelectARole => 'Veuillez sélectionner ARole';

  @override
  String get pleaseSelectAStudent => 'Veuillez sélectionner AStudent';

  @override
  String get pleaseSelectATeacher => 'Veuillez sélectionner ATeacher';

  @override
  String get pleaseSelectAUserRole => 'Veuillez sélectionner le rôle AUser';

  @override
  String get pleaseSelectAnIssueType =>
      'Veuillez sélectionner un type de problème';

  @override
  String get pleaseSelectAtLeastOneLanguage =>
      'Veuillez sélectionner au moins une langue';

  @override
  String get pleaseSelectAtLeastOneOption =>
      'Veuillez sélectionner au moins une option';

  @override
  String get pleaseSelectAtLeastOneRecipient =>
      'Veuillez sélectionner au moins un bénéficiaire';

  @override
  String get pleaseSelectAtLeastOneStudent =>
      'Veuillez sélectionner au moins un élève';

  @override
  String get pleaseSelectAtLeastOneStudent2 =>
      'Veuillez sélectionner au moins un élève2';

  @override
  String get pleaseSelectAtLeastOneTeaching =>
      'Veuillez sélectionner au moins un enseignement';

  @override
  String get pleaseSelectBothStartAndEnd =>
      'Veuillez sélectionner le début et la fin';

  @override
  String get pleaseSelectWhichClassThisReport =>
      'Veuillez choisir quelle classe ce rapport';

  @override
  String get pleaseSignInAgainToJoin =>
      'Veuillez vous identifier à nouveau pour vous joindre';

  @override
  String get pleaseSignInToAccessForms =>
      'Veuillez vous connecter pour accéder aux formulaires';

  @override
  String get pleaseSignInToViewForms =>
      'Veuillez vous connecter pour voir les formulaires';

  @override
  String get pleaseSignInToViewYour =>
      'Veuillez vous connecter pour voir votre';

  @override
  String get pleaseSignInToYourAccount =>
      'Veuillez vous connecter à votre compte';

  @override
  String get pleaseTrySigningOutAndSigning => 'Essayez de signer et de signer';

  @override
  String get pleaseUpdateToContinueUsingThe =>
      'Veuillez mettre à jour pour continuer à utiliser Les';

  @override
  String get pleaseWaitWhileWeConnectYou =>
      'S\'il vous plaît attendez pendant qu\'on vous connecte';

  @override
  String get pleaseWaitWhileWeLoadYour =>
      'Attendez pendant que nous chargeons votre';

  @override
  String get possibleCausesN => 'Causes possibles :';

  @override
  String get preFilled => 'Prérempli';

  @override
  String get preserveAllTheirDataSafely =>
      'Préserver tous leurs Données en toute sécurité';

  @override
  String get preview => 'Aperçu';

  @override
  String get previewChanges => 'Aperçu des modifications';

  @override
  String get previewInTeacherTimezone =>
      'Aperçu dans le fuseau horaire de l\'enseignant';

  @override
  String get previous => 'Précédent';

  @override
  String get previousWeek => 'Semaine précédente';

  @override
  String get price => 'Prix';

  @override
  String get primaryButton => 'Bouton primaire';

  @override
  String get priority => 'Priorité';

  @override
  String get priority2 => 'Priorité2';

  @override
  String get proceedAnyway => 'Procéder de toute façon';

  @override
  String get processing => 'Traitement';

  @override
  String get profile => 'Profil';

  @override
  String get profileCompletionpercentageComplete =>
      'Pourcentage d\'achèvement du profil Terminé';

  @override
  String get profilePercentageComplete => 'Profil Pourcentage Terminé';

  @override
  String get profilePictureRemovedSuccessfully =>
      'Image de profil supprimée avec succès';

  @override
  String get profilePictureUpdatedSuccessfully =>
      'Image de profil mise à jour avec succès';

  @override
  String get profileUpdatedSuccessfully => 'Profil mis à jour avec succès';

  @override
  String get programDetails => 'Détails du programme';

  @override
  String get programDetailsForEachStudent =>
      'Détails du programme pour chaque étudiant';

  @override
  String get programOverview => 'Aperçu du programme';

  @override
  String get programs => 'Programmes';

  @override
  String get programs2 => 'Programmes2';

  @override
  String get progress => 'Progrès accomplis';

  @override
  String get progress2 => 'Progrès réalisés2';

  @override
  String get progressNotes => 'Notes intérimaires';

  @override
  String get progressionProgressTotal => 'Progrès réalisés Total';

  @override
  String get promoteTeachersFromTheUsersTab =>
      'Promouvoir les enseignants à partir de l\'onglet utilisateurs';

  @override
  String get promoteTeachersToAdminTeacherDual =>
      'Promouvoir les enseignants à l\'administration de l\'enseignant double';

  @override
  String get promoteToAdminTeacher => 'Promouvoir l\'admin enseignant';

  @override
  String get prophetMuhammadPbuh => 'Le prophète Muhammad Pbuh';

  @override
  String get public => 'Public';

  @override
  String get published => 'Publié';

  @override
  String get punctuality => 'Ponctualité';

  @override
  String get purpleBasicEmailTest => 'Test d\'email de base pourpre';

  @override
  String get pushNotifications => 'Notifications de poussée';

  @override
  String get qty => 'Quantité';

  @override
  String get qualifiedIslamicEducators => 'Éducateurs islamiques qualifiés';

  @override
  String get qualityIslamicEducationFromAnywhereIn =>
      'Éducation islamique de qualité de n\'importe où dans';

  @override
  String get questionLabel => 'Question Étiquette';

  @override
  String get quickActions => 'Actions rapides';

  @override
  String get quickEdit => 'Édition rapide';

  @override
  String get quickEditOrFullEditorFor =>
      'Édition rapide ou éditeur complet pour';

  @override
  String get quickStats => 'Statistiques rapides';

  @override
  String get quickTasks => 'Tâches rapides';

  @override
  String get quran => 'Coran';

  @override
  String get rarely => 'Rarement';

  @override
  String get rarelyFewHoursAWeek => 'Rarement peu d\'heures';

  @override
  String get rateUpdatedSuccessfully => 'Taux actualisé avec succès';

  @override
  String get reEnableAccessToTheSystem => 'Re Activer l\'accès au système';

  @override
  String get reGularisationAdministrative => 'Re Gularisation Administrative';

  @override
  String get reUssis => 'RéUssis';

  @override
  String get reactionAddedReaction => 'Réaction ajoutée Réaction';

  @override
  String get readOurPrivacyPolicy => 'Lire notre politique de confidentialité';

  @override
  String get readinessFormRequired2 => 'Formulaire de préparation requis2';

  @override
  String get reason => 'Motifs';

  @override
  String get reasonForDispute => 'Motif du différend';

  @override
  String get reasonForEdit => 'Motif de la modification';

  @override
  String get reasonForReschedulingRequired => 'Motif du rééchelonnement requis';

  @override
  String get reasonRequired => 'Motif requis';

  @override
  String get recentActivity => 'Activité récente';

  @override
  String get recentInvoices => 'Factures récentes';

  @override
  String get recentLessons => 'Enseignements récents';

  @override
  String get recentPayments => 'Paiements récents';

  @override
  String get recipientsWillReceiveBothPushNotification =>
      'Les récipiendaires recevront les deux notifications Push';

  @override
  String get recurrence => 'Récurrence';

  @override
  String get recurrenceSettings => 'Paramètres de récurrence';

  @override
  String get recurrenceType => 'Type de récidive';

  @override
  String get recurring => 'Récurrent';

  @override
  String get recurringOnly => 'Récidive seulement';

  @override
  String get refreshData => 'Actualiser les données';

  @override
  String get regenerateCode => 'Code de régénération';

  @override
  String get reject => 'Rejet';

  @override
  String get reject2 => 'Rejet2';

  @override
  String get rejectAll => 'Tout rejeter';

  @override
  String get rejectEditedTimesheet => 'Feuille de temps modifiée de rejet';

  @override
  String get rejectTheEntireTimesheetRequiresReason =>
      'Rejeter la feuille de temps entière exige un motif';

  @override
  String get rejectTimesheet => 'Feuille de temps de rejet';

  @override
  String get remainingcount => 'Compte restant';

  @override
  String get remove => 'Supprimer';

  @override
  String get removeAccessToAdminFunctions =>
      'Supprimer l\'accès aux fonctions administratives';

  @override
  String get removeAccessToTheSystem => 'Supprimer l\'accès au système';

  @override
  String get removeAdminPrivileges => 'Supprimer les privilèges administratifs';

  @override
  String get removeAttachment => 'Supprimer la pièce jointe';

  @override
  String get removeDisplaynameFromTheMeeting =>
      'Supprimer le nom d\'affichage De la Réunion';

  @override
  String get removeOverride => 'Supprimer le dépassement';

  @override
  String get removeParticipant => 'Supprimer le participant';

  @override
  String get removePicture => 'Supprimer l\'image';

  @override
  String get removeStudent => 'Supprimer l\'élève';

  @override
  String get removeTask => 'Supprimer la tâche';

  @override
  String get replaceTheStudentListForAll =>
      'Remplacer la liste des élèves pour tous';

  @override
  String get reportNow => 'Reportez-vous';

  @override
  String get reportOpenedInNewTabUse =>
      'Rapport ouvert dans un nouvel onglet Utilisation';

  @override
  String get reportScheduleIssue => 'Calendrier des rapports Numéro';

  @override
  String get reportedIssues => 'Questions signalées';

  @override
  String get requestReceived => 'Demande reçue';

  @override
  String get requiredField => 'Champ requis';

  @override
  String get requiredFieldDefaultReviewed =>
      'Champ obligatoire par défaut examiné';

  @override
  String get requiredRatingBelow9 => 'Note requise ci-dessous9';

  @override
  String get rescheduleShift => 'Changement de calendrier';

  @override
  String get resetAll => 'Tout réinitialiser';

  @override
  String get resetAllPasswords => 'Réinitialiser tous les mots de passe';

  @override
  String get resetLayout => 'Réinitialiser la mise en page';

  @override
  String get resetToDefaults => 'Réinitialiser aux valeurs par défaut';

  @override
  String get resetZoom => 'Réinitialiser Zoom';

  @override
  String get responseDetails => 'Détails de la réponse';

  @override
  String get responses => 'Réponses';

  @override
  String get restoreAllTheirPreviousData =>
      'Restaurer toutes leurs données antérieures';

  @override
  String get restoreBackup => 'Restauration de sauvegarde';

  @override
  String get restoreOriginalTimesAndKeepTimesheet =>
      'Restaurer les temps originaux et garder la feuille de temps';

  @override
  String get restoreTheirAccountFromArchive =>
      'Restaurer leur compte des archives';

  @override
  String get restoreUser => 'Restaurer l\'utilisateur';

  @override
  String get resume => 'Résumé';

  @override
  String get resumeWorkingOnYourUnfinishedForms =>
      'Reprendre le travail sur vos formulaires inachevés';

  @override
  String get retryNow => 'Réessayez maintenant';

  @override
  String get returnHome => 'Retour';

  @override
  String get revertToOriginal => 'Retour à l\'original';

  @override
  String get review => 'Révision';

  @override
  String get reviewAndApproveEmployeeTimesheets =>
      'Examiner et approuver les feuilles de temps des employés';

  @override
  String get reviewAs => 'Révision';

  @override
  String get reviewComment => 'Commentaire du réexamen';

  @override
  String get reviewSubmitted => 'Examen soumis';

  @override
  String get reviewed => 'Révision';

  @override
  String get revoke => 'Révocation';

  @override
  String get revokeAdminPrivileges =>
      'Révoquer les privilèges des administrateurs';

  @override
  String get roleBasedPermissionsAreConfiguredAutomatically =>
      'Les autorisations basées sur le rôle sont configurées automatiquement';

  @override
  String get roleCheckResults => 'Résultats de la vérification des rôles';

  @override
  String get rolePermissions => 'Rôles autorisés';

  @override
  String get roleSystemTest => 'Essai du système de rôle';

  @override
  String get roleType => 'Type de rôle';

  @override
  String get roundingAdjustmentPenaltyBonusEtc =>
      'Indemnité d\'ajustement arrondie de la pénalité etc';

  @override
  String get rowsPerPage => 'Lignes par page';

  @override
  String get runBasicTests => 'Essais de base';

  @override
  String get runTheComputeScriptToGenerate =>
      'Exécutez le script de calcul pour générer';

  @override
  String get sampleAssignments => 'Attributions d\'échantillons';

  @override
  String get saveDraft => 'Enregistrer l\'ébauche';

  @override
  String get saveField => 'Enregistrer le champ';

  @override
  String get saveForm => 'Enregistrer le formulaire';

  @override
  String get saveSettings => 'Enregistrer les paramètres';

  @override
  String get savedDrafts => 'Projets sauvegardés';

  @override
  String get schedule => 'Tableau';

  @override
  String get schedule2 => 'Tableau 2';

  @override
  String get scheduleInformation => 'Renseignements sur le calendrier';

  @override
  String get schedulePreferences => 'Préférences du calendrier';

  @override
  String get scheduleType => 'Type de calendrier';

  @override
  String get schoolAnnouncements => 'Annonces scolaires';

  @override
  String get schoolUpdates => 'Mises à jour scolaires';

  @override
  String get score => 'Score';

  @override
  String get score2 => 'Note 2';

  @override
  String get score3 => 'Score3';

  @override
  String get scoreBreakdown => 'Répartition des scores';

  @override
  String get screenNotFound => 'Écran non trouvé';

  @override
  String get search => 'Rechercher';

  @override
  String get searchActiveForms => 'Recherche de formulaires actifs';

  @override
  String get searchAnything => 'Chercher n\'importe quoi';

  @override
  String get searchByCityTimezoneIdOr => 'Recherche par ville Timezone Id ou';

  @override
  String get searchByFormOrCreator => 'Recherche par forme ou par créateur';

  @override
  String get searchByNameEmailOrRole => 'Recherche par nom Courriel ou rôle';

  @override
  String get searchByNameOrEmail => 'Recherche par nom ou par courriel';

  @override
  String get searchByNameOrNumber => 'Recherche par nom ou numéro';

  @override
  String get searchByNameOrRole => 'Recherche par nom ou rôle';

  @override
  String get searchByOperationIdMetadata =>
      'Recherche par opération Id Métadonnées';

  @override
  String get searchClassesTeacherStudentSubject =>
      'Classes de recherche Enseignant Sujet étudiant';

  @override
  String get searchCountry => 'Pays de recherche';

  @override
  String get searchForms => 'Formulaires de recherche';

  @override
  String get searchInvoiceNumber => 'Numéro de la facture de recherche';

  @override
  String get searchParentsByNameOrEmail =>
      'Rechercher les parents Par nom ou par courriel';

  @override
  String get searchStudents => 'Rechercher les étudiants';

  @override
  String get searchSubjects => 'Sujets de recherche';

  @override
  String get searchTasks => 'Tâches de recherche';

  @override
  String get searchTeacher => 'Rechercher par nom ou email';

  @override
  String get periodOneMonth => 'Un mois';

  @override
  String get periodTwoMonths => 'Deux mois';

  @override
  String get periodCustomRange => 'Plage personnalisée';

  @override
  String get periodAllTime => 'Tout';

  @override
  String get startMonth => 'Mois de début';

  @override
  String get endMonth => 'Mois de fin';

  @override
  String get auditPeriodLabel => 'Période';

  @override
  String get searchTeachers => 'Rechercher les enseignants';

  @override
  String get searchTeachers2 => 'Rechercher les enseignants 2';

  @override
  String get searchUserOrName => 'Nom de l\'utilisateur ou de la recherche';

  @override
  String get searchUsersByNameOrEmail =>
      'Utilisateurs de recherche par nom ou par courriel';

  @override
  String get searchUsersOrShifts => 'Rechercher des utilisateurs ou des postes';

  @override
  String get secondaryButton => 'Bouton secondaire';

  @override
  String get securitySettings => 'Paramètres de sécurité';

  @override
  String get select => 'Sélectionner';

  @override
  String get selectABackupToRestoreFrom =>
      'Sélectionnez ABackup Pour restaurer de';

  @override
  String get selectAFormToGetStarted =>
      'Sélectionnez un formulaire pour commencer';

  @override
  String get selectAProgramForEachStudent =>
      'Sélectionner un programme Pour chaque étudiant';

  @override
  String get selectARoleAndSetThe => 'Sélectionnez ARole et définissez Les';

  @override
  String get selectAShift => 'Sélectionner AShift';

  @override
  String get selectAShiftToReportAn => 'Sélectionnez AShift pour signaler un';

  @override
  String get selectAdjustment => 'Sélectionner le réglage';

  @override
  String get selectAll => 'Tout sélectionner';

  @override
  String get selectAll2 => 'Sélectionner tout2';

  @override
  String get selectAssignedBy => 'Sélectionner Attribué Par';

  @override
  String get selectAssignedTo => 'Sélectionner Attribué Aux';

  @override
  String get selectAtLeastOneChangeTo =>
      'Sélectionner au moins un changement à';

  @override
  String get selectByUserGroupEG =>
      'Sélectionner par groupe d\'utilisateurs EG';

  @override
  String get selectClass => 'Sélectionner une classe';

  @override
  String get selectDaysOfMonth => 'Quelques jours de mois';

  @override
  String get selectDaysOfWeek => 'Quelques jours de semaine';

  @override
  String get selectDueDate => 'Sélectionner la date d\'échéance';

  @override
  String get selectDurationAndTimeOfDay =>
      'Sélectionner la durée et l\'heure du jour';

  @override
  String get selectDutyType => 'Sélectionner le type de droits';

  @override
  String get selectIndividualUsers => 'Sélectionner un individu Utilisateur';

  @override
  String get selectItems => 'Sélectionner des éléments';

  @override
  String get selectLabel => 'Sélectionner l\'étiquette';

  @override
  String get selectMonths => 'Sélectionner des mois';

  @override
  String get selectNewOnly => 'Sélectionner seulement Nouveau';

  @override
  String get selectParent => 'Sélectionner le parent';

  @override
  String get selectPeriod => 'Sélectionner une période';

  @override
  String get selectRole => 'Sélectionner le rôle';

  @override
  String get selectStudent => 'Sélectionner un étudiant';

  @override
  String get selectStudent2 => 'Sélectionnez Étudiant2';

  @override
  String get selectStudents => 'Sélectionnez les étudiants';

  @override
  String get selectSubject => 'Sélectionner un sujet';

  @override
  String get selectTeacher => 'Sélectionner l\'enseignant';

  @override
  String get selectTeachersToGenerateRegenerateAudit =>
      'Choisir des enseignants pour générer une vérification régénérée';

  @override
  String get selectTeamMembers => 'Sélectionnez les membres de l\'équipe';

  @override
  String get selectTheAppropriateRoleForThis =>
      'Choisir le rôle approprié pour Cette';

  @override
  String get selectTheProgramSYouAre => 'Sélectionnez le programme SYou Sont';

  @override
  String get selectUserWhoCreatedTheTasks =>
      'Sélectionnez l\'utilisateur qui a créé Les tâches';

  @override
  String get selectUsers => 'Sélectionner les utilisateurs';

  @override
  String get selectUsers2 => 'Sélectionner Utilisateurs2';

  @override
  String get selectUsersToFilterTasks =>
      'Sélectionnez les utilisateurs pour filtrer les tâches';

  @override
  String get selectYourCorrectTimezone =>
      'Sélectionnez votre fuseau horaire correct';

  @override
  String get selected => 'Sélectionné';

  @override
  String get selectedSelectedteachername => 'Nom de l\'enseignant sélectionné';

  @override
  String get selectedShifts => 'Majs sélectionnés';

  @override
  String get selectedShiftsUseMultipleTimezonesApplying =>
      'Utilisation de plusieurs fuseaux horaires';

  @override
  String get selectedUsers => 'Utilisateurs sélectionnés';

  @override
  String get selectionMethod => 'Méthode de sélection';

  @override
  String get sendMessage => 'Envoyer un message';

  @override
  String get sendNotification => 'Envoyer une notification';

  @override
  String get sendTestEmail => 'Envoyer un courriel d\'essai';

  @override
  String get sendTo => 'Envoyer à';

  @override
  String get sendTo2 => 'Envoyer à2';

  @override
  String get sendUsAnEmail => 'Envoyez-nous un courriel';

  @override
  String get series => 'Série';

  @override
  String get sessionAlreadyClosedBySystemTimer =>
      'Session déjà fermée par minuteur système';

  @override
  String get setANewStartEndTime =>
      'Définir une nouvelle heure de fin de départ';

  @override
  String get setAsActive => 'Définir comme actif';

  @override
  String get setDefaultRates => 'Définir les taux par défaut';

  @override
  String get setDefaults => 'Définir les valeurs par défaut';

  @override
  String get setDifferentHourlyRatesForEach =>
      'Fixer des taux horaires différents pour chaque';

  @override
  String get setHourlyRatesForEachSubject =>
      'Fixer des tarifs horaires pour chaque sujet';

  @override
  String get setNotesForAllSelectedShifts =>
      'Définir des notes pour tous les déplacements sélectionnés';

  @override
  String get settingsSavedSuccessfully => 'Paramètres sauvegardés avec succès';

  @override
  String get settingsSavedSuccessfully2 =>
      'Paramètres sauvegardés avec succès2';

  @override
  String get sharing => 'Partage';

  @override
  String get sheetsIncludedInExport => 'Feuilles incluses dans l\'exportation';

  @override
  String get shiftBannedSuccessfullyRecalculatingAudit =>
      'Changement interdit Recalcul de la vérification';

  @override
  String get shiftClaimedSuccessfullyCheckMyShifts =>
      'Affectation demandée avec succès Vérifiez mes quarts';

  @override
  String get shiftCompleted2 => 'Poste terminé2';

  @override
  String get shiftCreEEtPaiementSynchronise =>
      'Synchronisation du temps de travail de l\'équipe';

  @override
  String get shiftCreatedSyncedToTeacherTimezone =>
      'Shift Created Synced to Teacher Timezone';

  @override
  String get shiftDeleted => 'Maj supprimé';

  @override
  String get shiftDetailsConsolidated => 'Détails du poste Consolidé';

  @override
  String get shiftEndTimeMustBeDifferent =>
      'L\'heure de fin de poste doit être différente';

  @override
  String get shiftEndedClockOutRecorded => 'Heure de fin de quart enregistrée';

  @override
  String get shiftInformationAutofilled =>
      'Information sur le poste rempli automatiquement';

  @override
  String get shiftName => 'Nom du poste';

  @override
  String get shiftNotFound => 'Maj non trouvé';

  @override
  String get shiftReminders => 'Rappels de quarts';

  @override
  String get shiftUpdated => 'Mise à jour du changement';

  @override
  String get shiftsWithoutForms => 'Postes sans formulaires';

  @override
  String get shortAnswerText => 'Texte de réponse courte';

  @override
  String get showInactive => 'Afficher inactif';

  @override
  String get showingStartEndOfTotalResults =>
      'Affichage de la fin du début des résultats totaux';

  @override
  String get showsPerformanceloggerStartCheckpointEndEvents =>
      'Affiche l\'enregistreur de performances Début des événements de fin de checkpoint';

  @override
  String get signUp => 'Inscription';

  @override
  String get signUpForNewClass => 'Inscription pour une nouvelle classe';

  @override
  String get signature => 'Signature';

  @override
  String get signatureCaptured => 'Signature saisie';

  @override
  String get simpleClock => 'Horloge simple';

  @override
  String get slotStudenttzabbr => 'Slot Studenttzabbr';

  @override
  String get slowestEnd => 'Fin la plus lente';

  @override
  String get slowestInCurrentLogBuffer => 'Lenteur du tampon de journal actuel';

  @override
  String get someStudentsOnThisShiftCould =>
      'Certains étudiants sur ce changement pourrait';

  @override
  String get somethingWentWrong => 'Quelque chose ne va pas';

  @override
  String get sometimes => 'Parfois';

  @override
  String get sorryNotAtAllIAm => 'Désolé de ne pas être du tout';

  @override
  String get source => 'Source';

  @override
  String get sourceWeek => 'Semaine source';

  @override
  String get specificRole => 'Rôle spécifique';

  @override
  String get specificUsers => 'Utilisateurs spécifiques';

  @override
  String get springForward1Hour => 'Printemps à venir1heure';

  @override
  String get startCodingToday => 'Commencez à coder aujourd\'hui';

  @override
  String get startDate => 'Date de début';

  @override
  String get startLearning => 'Début de l\'apprentissage';

  @override
  String get startTheConversation => 'Début de la conversation';

  @override
  String get startYourChildSIslamicJourney =>
      'Commencez votre enfant islamique Voyage';

  @override
  String get startYourLearningJourneyToday =>
      'Commencez votre voyage d\'apprentissage aujourd\'hui';

  @override
  String get startdatetextStarttimetextEndtimetext =>
      'Startdatetext Starttimetext Endtimetext';

  @override
  String get startingScreenShare => 'Partage d\'écran de démarrage';

  @override
  String get starttimeEndtime => 'Heure de début Heure de fin';

  @override
  String get statistics => 'Statistiques';

  @override
  String get statsEditor => 'Éditeur de statistiques';

  @override
  String get status => 'État';

  @override
  String get statusStatus => 'État d \' avancement';

  @override
  String statusUpdatedToNewstatus(String newStatus) {
    return 'État mis à jour vers $newStatus';
  }

  @override
  String statusUpdatedToStatus(String status) {
    return 'État mis à jour vers $status';
  }

  @override
  String get stayOnTrackWithReminders =>
      'Restez sur la bonne voie avec les rappels';

  @override
  String get stepnumberOfTotalsteps => 'Nombre d\'étapes';

  @override
  String get stillNoInternetConnectionPleaseTry =>
      'Toujours aucune connexion Internet Veuillez essayer';

  @override
  String get storageService => 'Service de stockage';

  @override
  String get structuredLearningPaths => 'Voies d\'apprentissage structurées';

  @override
  String get student1 => 'Étudiant1';

  @override
  String studentAccountCreatedIdStudentcode(String studentCode) {
    return 'Compte étudiant créé. ID : $studentCode';
  }

  @override
  String get studentApplicants => 'Candidats étudiants';

  @override
  String studentIdStudentcode(Object studentCode) {
    return 'ID étudiant : $studentCode';
  }

  @override
  String get studentJoined => 'Étudiant rejoint';

  @override
  String get studentLoginCredentials => 'Connexion étudiante Pouvoirs';

  @override
  String get studentProgressOverview => 'Aperçu des progrès des élèves';

  @override
  String get studentSInformation => 'Informations sur les étudiants';

  @override
  String get studentStudent => 'Étudiant';

  @override
  String get studentType => 'Type d\'étudiant';

  @override
  String get studentWillUseStudentIdAnd =>
      'L\'étudiant utilisera son identité et';

  @override
  String get students => 'Élèves';

  @override
  String get studentsWillAppearHereAfterYou =>
      'Les étudiants apparaîtront ici après vous';

  @override
  String get subTasksOptional => 'Sous-tâches Facultative';

  @override
  String get subject => 'Sujet';

  @override
  String subjectDisplaynameAddedSuccessfully(String displayName) {
    return 'Sujet \"$displayName\" ajouté avec succès';
  }

  @override
  String subjectDisplaynameUpdatedSuccessfully(String displayName) {
    return 'Sujet \"$displayName\" mis à jour avec succès';
  }

  @override
  String get subjectHourlyRates => 'Sujet Taux horaires';

  @override
  String get subjectManagement => 'Gestion des sujets';

  @override
  String get subjectName => 'Nom du sujet';

  @override
  String get subjectPerformanceWillAppearHereAs =>
      'L\'interprétation du sujet apparaîtra ici comme';

  @override
  String get submissionFailedE => 'Échec de la soumission E';

  @override
  String get submissionInfo => 'Informations sur la soumission';

  @override
  String get submissions => 'Présentations';

  @override
  String get submitAgain => 'Soumettre à nouveau';

  @override
  String get submitAllDrafts => 'Soumettre tous les projets';

  @override
  String get submitApplication => 'Soumettre une demande';

  @override
  String get submitEvaluation => 'Soumettre l\'évaluation';

  @override
  String get submitForm => 'Soumettre le formulaire';

  @override
  String get submitNewDispute => 'Soumettre un nouveau différend';

  @override
  String get submitReportsFeedback => 'Soumettre des rapports Commentaires';

  @override
  String get submitTimesheet => 'Soumettre une feuille de temps';

  @override
  String get submitWithoutImage => 'Soumettre sans image';

  @override
  String get submitted => 'Présenté';

  @override
  String get submittedDatestr => 'Datestr soumise';

  @override
  String get submitting => 'Présentation';

  @override
  String get subtitle => 'Sous-titre';

  @override
  String get successcountSuccessfulN => 'Nombre de réussites N';

  @override
  String get successfulLogin1HourAgo => 'Connexion réussie1Hour Ago';

  @override
  String get successfulLogin2MinutesAgo => 'Avec succès Login2Minutes Ago';

  @override
  String get successfuluploadsFileSUploadedSuccessfully =>
      'Envois réussis Fichier SUploadé Réussir';

  @override
  String get suggestedCorrectValueOptional =>
      'Valeur correcte suggérée Facultative';

  @override
  String get sujetDuCours => 'Sujet Du Cours';

  @override
  String get summary => 'Résumé';

  @override
  String get summary2 => 'Résumé2';

  @override
  String get supportAlluwaleducationhubOrg =>
      'Soutien Alluwaleducationhub Organisme';

  @override
  String get surah => 'Sourate';

  @override
  String get sync => 'Synchronisation';

  @override
  String get syncWithSubjects => 'Synchroniser avec les sujets';

  @override
  String get syncedSyncedSubjectsWithRates => 'Sujets syndiqués avec taux';

  @override
  String get systemDiagnostics => 'Diagnostic du système';

  @override
  String get systemHealth => 'Santé du système';

  @override
  String get systemInformation => 'Informations sur le système';

  @override
  String get systemLoad => 'Charge du système';

  @override
  String get systemOverview => 'Aperçu du système';

  @override
  String get systemPerformance => 'Performance du système';

  @override
  String get systemSettings => 'Paramètres du système';

  @override
  String get systemSettings2 => 'Paramètres du système2';

  @override
  String get takeAPhoto => 'Prendre une photo';

  @override
  String get tapAndHoldForMoreDetails =>
      'Appuyez sur et maintenez pour plus de détails';

  @override
  String get tapOnUsersBelowToSelect =>
      'Appuyez sur Utilisateurs ci-dessous pour sélectionner';

  @override
  String get tapToSelectUsers =>
      'Appuyez sur pour sélectionner les utilisateurs';

  @override
  String get targetAudienceAllowedRoles => 'Public cible Rôles autorisés';

  @override
  String get targetWeek => 'Semaine cible';

  @override
  String get taskArchived => 'Tâche archivée';

  @override
  String get taskDeletedSuccessfully => 'Tâche supprimée avec succès';

  @override
  String get taskName => 'Nom de la tâche';

  @override
  String get taskName2 => 'Nom de la tâche2';

  @override
  String get taskReminders => 'Rappel des tâches';

  @override
  String get taskTitle => 'Titre de la tâche';

  @override
  String taskSubtasksCount(Object count) {
    return 'Sous-tâches : $count';
  }

  @override
  String get taskUnarchived => 'Tâche non archivée';

  @override
  String get teachForUs => 'Apprenez-nous';

  @override
  String get teacherApplicants => 'Candidats enseignants';

  @override
  String get teacherApplication => 'Application pour les enseignants';

  @override
  String get teacherArrived => 'Professeur arrivé';

  @override
  String get teacherAuditDashboard =>
      'Tableau de bord de la vérification des enseignants';

  @override
  String get teacherClass => 'Classe d \' enseignants';

  @override
  String get teacherDidNotSubmitReadinessForm =>
      'L\'enseignant n\'a pas soumis le formulaire de préparation';

  @override
  String get teacherIdNotFound => 'Idée de professeur non trouvée';

  @override
  String get teacherInformationNotAvailable =>
      'Renseignements pour les enseignants Non disponible';

  @override
  String get teacherNotHere => 'Professeur non ici';

  @override
  String get teacherProfile => 'Profil de l\'enseignant';

  @override
  String get teacherSelectedSelectedteachername =>
      'Nom de l\'enseignant sélectionné';

  @override
  String get teacherUstaz => 'Enseignant Ustaz';

  @override
  String get teacherUstaza => 'Professeur Ustaza';

  @override
  String get teachers => 'Enseignants';

  @override
  String get teachers2 => 'Enseignants2';

  @override
  String get teachersOnly => 'Enseignants seulement';

  @override
  String get teachershiftsShiftsWillBePermanentlyDeleted =>
      'Les postes d\'enseignant seront définitivement supprimés';

  @override
  String get teachingSelectedstudentname =>
      'Enseignement Nom de l\'étudiant sélectionné';

  @override
  String get tealTestLastLoginUpdateTracking =>
      'Test Teal Dernière connexion Suivi des mises à jour';

  @override
  String get templateDeleted => 'Modèle supprimé';

  @override
  String get templateDuplicatedSuccessfully => 'Modèle dupliqué Réussir';

  @override
  String get templateMustHaveAtLeastOne => 'Modèle doit avoir au moins un';

  @override
  String get templateName => 'Nom du modèle';

  @override
  String get templateNameCannotBeEmpty =>
      'Le nom du modèle ne peut pas être vide';

  @override
  String get templateUpdatedSuccessfully => 'Modèle mis à jour avec succès';

  @override
  String get testConnection => 'Connexion d\'essai';

  @override
  String get testDraftCreation => 'Création du projet d\'essai';

  @override
  String get testGeNeRationAuditDe => 'Vérification de la qualité';

  @override
  String get testLoginTracking => 'Tester le suivi de connexion';

  @override
  String get testNotificationSentSuccessfully =>
      'Notification d\'essai Envoyé avec succès';

  @override
  String get testRoleChecks => 'Vérification des rôles d\'essai';

  @override
  String get testStatusUpdate => 'Mise à jour de l\'état des essais';

  @override
  String get testTaskAssignment => 'Attribution des tâches d\'essai';

  @override
  String get testWelcomeEmail => 'Test Email de bienvenue';

  @override
  String get testimonials => 'Témoignages';

  @override
  String get testimonialsEditor => 'Éditeur de témoignages';

  @override
  String get testingConnection => 'Essai de connexion';

  @override
  String get text => 'Texte';

  @override
  String get text10 => '*';

  @override
  String get text2 => 'Texte2';

  @override
  String get text3 => 'Texte3';

  @override
  String get text4 => '#';

  @override
  String get text5 => 'Non renseigné';

  @override
  String get text6 => ' • ';

  @override
  String get text7 => 'Texte7';

  @override
  String get text8 => 'à';

  @override
  String get text9 => ' • ';

  @override
  String get thankYouForYourInterestIn => 'Merci de votre intérêt pour';

  @override
  String get thankYouForYourInterestIn2 => 'Merci de votre intérêt pour In2';

  @override
  String get thankYouForYourInterestIn3 => 'Merci de votre intérêt pour In3';

  @override
  String get thankYouForYourInterestPlease => 'Merci de votre intérêt.';

  @override
  String get thankYouForYourInterestPlease2 =>
      'Merci pour votre intérêt s\'il vous plaît2';

  @override
  String get thankYouForYourInterestWe => 'Merci de votre intérêt';

  @override
  String get theBestOfPeopleAreThose => 'Le meilleur des gens sont ceux';

  @override
  String get theDailySchedulerWillGenerateNew =>
      'Le calendrier quotidien Générera une nouvelle';

  @override
  String get theFormCreatorHasNotAdded =>
      'La forme Créateur n\'a pas été ajoutée';

  @override
  String get theSmallBusinessPlan => 'Le Plan pour les petites entreprises';

  @override
  String get theTimezoneForTheTimesBelow => 'Le fuseau horaire des temps';

  @override
  String get theTimezoneForTheTimesYou => 'Le fuseau horaire des temps';

  @override
  String get theTimezoneUsedForTheStart =>
      'Le fuseau horaire utilisé pour le début';

  @override
  String get theViewContains => 'La vue contient';

  @override
  String get thereAreCurrentlyNoPublishedShifts =>
      'Il n\'y a actuellement aucun changement publié';

  @override
  String get theseShiftsWereCompletedButNo =>
      'Ces postes ont été terminés mais non';

  @override
  String get thisActionCannotBeUndone => 'Cette action ne peut être annulée';

  @override
  String get thisAppRequiresAnActiveInternet =>
      'Cette application nécessite un Internet actif';

  @override
  String get thisClassDoesNotHaveA => 'Cette classe n\'a pas de';

  @override
  String get thisClassLinkIsNoLonger => 'Ce lien de classe n\'est plus long';

  @override
  String get thisEmailWillReceiveNotificationsFor =>
      'Ce courriel recevra des notifications Pour';

  @override
  String get thisFileWasNotUploadedTo =>
      'Ce fichier n\'a pas été téléchargé vers';

  @override
  String get thisFormIndicatesTheTeacherConducted =>
      'Ce formulaire indique l\'enseignant';

  @override
  String get thisIsTheTaskscreenScreen => 'C\'est l\'écran des tâches';

  @override
  String get thisIsTheTimeoffscreenScreen => 'C\'est l\'écran Timeoff';

  @override
  String get thisShiftSpansTwoDaysIn =>
      'Ce quart de travail s\'étend sur deux jours';

  @override
  String get thisShiftSpansTwoDaysIn2 => 'Ce poste s\'étale sur deux jours';

  @override
  String get thisShiftWasMissedPleaseFill =>
      'Ce poste a manqué Veuillez remplir';

  @override
  String get thisTimesheetHasBeenApprovedAnd =>
      'Cette feuille de temps a été approuvée et';

  @override
  String get thisTimesheetWasEditedAndRequires =>
      'Cette feuille de temps a été modifiée et nécessite';

  @override
  String get thisTimesheetWasEditedButThe =>
      'Cette feuille de temps a été modifiée';

  @override
  String get thisTimesheetWasEditedChooseAn =>
      'Cette feuille de temps a été modifiée Choisir un';

  @override
  String get thisWill => 'Cette volonté';

  @override
  String get thisWillAdjustAllFutureScheduled =>
      'Cela ajustera tous les futurs calendriers';

  @override
  String get thisWillDeleteAllDraftsOlder =>
      'Cela supprimera toutes les ébauches plus anciennes';

  @override
  String get thisWillGiveThem => 'Cela donnera Eux';

  @override
  String get thisWillMakeTheOpportunityVisible =>
      'Cela rendra l\'occasion visible';

  @override
  String get thisWillMuteAllParticipantsExcept => 'Tous les participants sauf';

  @override
  String get thisWillPermanentlyDeleteThisShift =>
      'Ce sera définitivement supprimer ce changement';

  @override
  String get thisWillSetDefaultRatesFor =>
      'Cela définira les taux par défaut pour';

  @override
  String get thisWillUpdateAllExistingShifts =>
      'Cette mise à jour mettra à jour tous les postes existants';

  @override
  String get thisWillUpdateTheDefaultwageField =>
      'Ceci mettra à jour le champ par défaut';

  @override
  String get thisWillUpdateTheRecurringTemplate =>
      'Cette mise à jour mettra à jour le modèle récurrent';

  @override
  String get timeConversionPreview => 'Aperçu de la conversion du temps';

  @override
  String get timePicker => 'Cueillette de temps';

  @override
  String get timeUntilShiftsDisplay =>
      'Temps jusqu\'à l\'affichage des changements';

  @override
  String get timeUntilTimesheetsDisplay =>
      'Temps avant l\'affichage des feuilles de temps';

  @override
  String get timesWillBeAppliedInThis => 'Les temps seront appliqués dans ce';

  @override
  String get timesheetDetails2 => 'Détails du calendrier2';

  @override
  String get timesheetReview => 'Révision du calendrier';

  @override
  String get timesheetSubmittedForReview => 'Calendrier soumis à l\'examen';

  @override
  String get timesheetWasEdited => 'La feuille de temps a été modifiée';

  @override
  String get timesheets => 'Feuilles horaires';

  @override
  String timezoneUpdatedToSelectedtimezone(String timezone) {
    return 'Fuseau horaire mis à jour vers $timezone';
  }

  @override
  String get tipIfYouJustCompletedPayment =>
      'Conseil Si vous venez de compléter le paiement';

  @override
  String get title => 'Titre';

  @override
  String get to => 'Aux';

  @override
  String get toCreateAnInclusiveInspiringEnvironment =>
      'Créer un environnement inspirant inclusif';

  @override
  String get toHassimiouNianeMaineEdu => 'À Hassimiou Niane Maine Edu';

  @override
  String get toIntegrateIslamicAfricanAndWestern =>
      'Intégrer l\'islam africain et occidental';

  @override
  String get tooEarlyToClockInPlease => 'Trop tôt pour entrer s\'il vous plaît';

  @override
  String get topicsWeCover => 'Sujets traités';

  @override
  String get total => 'Total général';

  @override
  String get totalClasses => 'Total des classes';

  @override
  String get totalPayment => 'Total des paiements';

  @override
  String get totalPenalty => 'Pénalité totale';

  @override
  String get totalTeachingHours => 'Total des heures d\'enseignement';

  @override
  String get totalTotalusersUsers => 'Total utilisateurs Utilisateur';

  @override
  String get totalscoreMaxscore => 'Totalscore Maxscore';

  @override
  String get training => 'Formation';

  @override
  String get transformativeEducationNbeyondTraditionalBoundaries =>
      'Éducation transformatrice Nbeyond limites traditionnelles';

  @override
  String get trustIndicator => 'Indicateur de confiance';

  @override
  String get tryAdjustingYourFiltersOrSearch =>
      'Essayez d\'ajuster vos filtres ou de rechercher';

  @override
  String get tryAdjustingYourFiltersOrSearch2 =>
      'Essayez d\'ajuster vos filtres ou de rechercher2';

  @override
  String get tryAdjustingYourSearchOrFilters =>
      'Essayez d\'ajuster votre recherche ou filtres';

  @override
  String get tryAgain => 'Essaie encore';

  @override
  String get tryChangingTheFilterOrCheck =>
      'Essayez de modifier le filtre ou de vérifier';

  @override
  String get tryChangingTheMonthOrGenerating =>
      'Essayez de changer le mois ou de générer';

  @override
  String get turnOffToKeepParticipantsMuted =>
      'Éteindre pour garder les participants Muets';

  @override
  String get unBroadcast => 'Non diffusé';

  @override
  String get unableToFindAuditContext =>
      'Impossible de trouver le contexte de la vérification';

  @override
  String get unableToGetYourLocationE =>
      'Impossible d\'obtenir votre emplacement E';

  @override
  String get unableToJoin => 'Impossible de se joindre';

  @override
  String get unableToLoadClassesNMessage =>
      'Impossible de charger les classes NMessage';

  @override
  String get unableToLoadParentAccountPlease =>
      'Impossible de charger le compte parent';

  @override
  String get unableToLoadQuran => 'Impossible de charger le Coran';

  @override
  String get unableToLoadSeriesShifts =>
      'Impossible de charger des déplacements de série';

  @override
  String get unableToLoadSurah => 'Impossible de charger la sourate';

  @override
  String get uncomfortable => 'Inconfortable';

  @override
  String get understandingClassColors => 'Comprendre les couleurs des classes';

  @override
  String get universityGraduate => 'Diplômé';

  @override
  String get universityStudent => 'Étudiant';

  @override
  String get unknownUserRole => 'Rôle de l\'utilisateur inconnu';

  @override
  String get unlink => 'Déconnecter';

  @override
  String get unlockYourFullPotentialWithExpert =>
      'Débloquer votre plein potentiel avec l\'expert';

  @override
  String get unlockYourMathPotentialToday =>
      'Débloquer votre potentiel de mathématiques aujourd\'hui';

  @override
  String get unmute => 'Sans changement';

  @override
  String get unmuteParticipant => 'Participant';

  @override
  String get unsaved => 'Non sauvé';

  @override
  String get unsavedChanges => 'Changements non enregistrés';

  @override
  String get untitledForm => 'Formulaire sans titre';

  @override
  String get untitledForm2 => 'Formulaire sans titre2';

  @override
  String get upcomingEvents => 'Événements à venir';

  @override
  String get upcomingOccurrences => 'Événements à venir';

  @override
  String get upcomingTasks => 'Tâches futures';

  @override
  String get update => 'Mise à jour';

  @override
  String get updateNow => 'Mettre à jour';

  @override
  String get updateRecurringTemplate => 'Mettre à jour le modèle récurrent';

  @override
  String get updateRequired => 'Mise à jour requise';

  @override
  String get updateStatus => 'État de mise à jour';

  @override
  String get updateSubject => 'Sujet de mise à jour';

  @override
  String get updateTimezoneWithoutReportingAShift =>
      'Mettre à jour le fuseau horaire sans rapport AShift';

  @override
  String get updateUserInformationAndSettings =>
      'Mettre à jour les informations utilisateur et les paramètres';

  @override
  String get updatedDefaultRatesForUpdatedSubjects =>
      'Taux par défaut mis à jour pour les sujets mis à jour';

  @override
  String get updatedSelectedcountTaskS =>
      'Numéro sélectionné mis à jour Tâche S';

  @override
  String get uploadImageOrUseSignaturePad =>
      'Télécharger une image ou utiliser le tampon de signature';

  @override
  String get uptime => 'Temps de disponibilité';

  @override
  String get use => 'Utilisation';

  @override
  String get useCustomShiftName => 'Utiliser un nom de poste personnalisé';

  @override
  String get useLowercaseWithUnderscores =>
      'Utiliser la minuscule avec les sous-scores';

  @override
  String get useStudentId => 'Utiliser la carte d\'étudiant';

  @override
  String get userAnalytics => 'Analyse utilisateur';

  @override
  String get userData => 'Données utilisateur';

  @override
  String get userDataNotLoaded => 'Données utilisateur non chargées';

  @override
  String get userDetails => 'Détails de l\'utilisateur';

  @override
  String get userDistribution => 'Distribution des utilisateurs';

  @override
  String get userDocumentNotFound => 'Document utilisateur non trouvé';

  @override
  String get userListScreenComingSoon =>
      'L\'écran de la liste des utilisateurs arrive bientôt';

  @override
  String get userRole2 => 'Rôle de l\'utilisateur2';

  @override
  String get userType2 => 'Type d\'utilisateur2';

  @override
  String get userUpdatedSuccessfully => 'Utilisateur mis à jour avec succès';

  @override
  String get userUpdatedSuccessfully2 => 'Utilisateur mis à jour avec succès2';

  @override
  String get usersDidnTLogInYet =>
      'Les utilisateurs n\'ont pas encore connecté';

  @override
  String get usersWillReceiveLoginCredentialsVia =>
      'Les utilisateurs recevront les identifiants de connexion Voie';

  @override
  String get v => 'V';

  @override
  String get version100 => 'Version100';

  @override
  String get versionAndAppInformation =>
      'Informations sur la version et l\'application';

  @override
  String get veryComfortable => 'Très confortable';

  @override
  String get videoProvider => 'Fournisseur de vidéo';

  @override
  String get viewAllActivity => 'Afficher toutes les activités';

  @override
  String get viewAndPay => 'Afficher et payer';

  @override
  String get viewAttachment => 'Afficher la pièce jointe';

  @override
  String get viewAuditDetails => 'Voir les détails de l\'audit';

  @override
  String get viewFile => 'Affichage du fichier';

  @override
  String get viewForm => 'Afficher le formulaire';

  @override
  String get viewFormDetails => 'Afficher les détails du formulaire';

  @override
  String get viewOptions => 'Options d\'affichage';

  @override
  String get viewResponse => 'Afficher la réponse';

  @override
  String get viewShift => 'Affichage Maj';

  @override
  String get wageChangesApplied => 'Évolution des salaires appliquée';

  @override
  String get wageManagement => 'Gestion des salaires';

  @override
  String get waitingForOthersToJoin => 'Attendre que d\'autres se joignent';

  @override
  String get wantToBecomeATeacher => 'Voulez devenir ATeacher';

  @override
  String get weAreCommittedToProtectingChildren =>
      'Nous nous engageons à protéger les enfants';

  @override
  String get weAreFosteringAWorldWhere => 'Nous encourageons un monde où';

  @override
  String get weCollectInformationYouProvideDirectly =>
      'Nous recueillons les renseignements que vous fournissez directement';

  @override
  String get weDLoveToHearFrom => 'Nous aimons entendre de';

  @override
  String get weImplementIndustryStandardSecurityMeasures =>
      'Nous mettons en oeuvre les mesures de sécurité normalisées de l\'industrie';

  @override
  String get websiteContentSavedSuccessfullyChangesWill =>
      'Contenu du site Web sauvegardé avec succès Changements';

  @override
  String get websiteManagement => 'Gestion du site Web';

  @override
  String get weekCalendar => 'Calendrier hebdomadaire';

  @override
  String get weekly => 'Semaine';

  @override
  String get weeklyCalendar => 'Calendrier hebdomadaire';

  @override
  String get weeklyRecurrenceSettings =>
      'Paramètres hebdomadaires de récurrence';

  @override
  String get welcomeBackFirstname => 'Accueil Retour Prénom';

  @override
  String get welcomeToAlluvialAcademy => 'Bienvenue à l\'Académie Alluviale';

  @override
  String get whatNeedsToBeDone => 'Ce qu\'il faut faire';

  @override
  String get whatSTheIssue => 'Qu\'est-ce que le problème';

  @override
  String get whatShouldTheCorrectTimesBe => 'Que devrait être le temps correct';

  @override
  String get whatShouldTheCorrectValueBe =>
      'Que devrait être la valeur correcte';

  @override
  String get whatsapp => 'Quoi?';

  @override
  String get whatsappNumber => 'Numéro Whatsapp';

  @override
  String get whatsappNumber2 => 'Numéro Whatsapp2';

  @override
  String get whenInvoicesAreCreatedTheyWill =>
      'Quand les factures seront créées, elles seront';

  @override
  String get whereEducationTranscendsBoundaries =>
      'Où l\'éducation transcend les limites';

  @override
  String get whyChooseOurEnglishProgram =>
      'Pourquoi choisir notre programme anglais';

  @override
  String get whyChooseOurMathProgram =>
      'Pourquoi choisir notre programme de mathématiques';

  @override
  String get whyChooseOurTeachers => 'Pourquoi choisir nos enseignants';

  @override
  String get whyLearnToCode => 'Pourquoi apprendre à coder';

  @override
  String get worldClassEducation => 'Éducation de classe mondiale';

  @override
  String get wouldYouLikeToClockOut => 'Voudriez-vous vous arranger';

  @override
  String get wouldYouLikeToCompleteThe => 'Aimeriez-vous compléter Les';

  @override
  String get yearlyRecurrenceSettings => 'Paramètres annuels de récurrence';

  @override
  String get yesAndAlways => 'Oui et toujours';

  @override
  String get yesUpdateTemplate => 'Oui Modèle de mise à jour';

  @override
  String youAreAboutToRejectCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vous êtes sur le point de rejeter $count feuilles de temps.',
      one: 'Vous êtes sur le point de rejeter 1 feuille de temps.',
    );
    return '$_temp0';
  }

  @override
  String get youAreNotAssignedToThis => 'Vous n\'êtes pas assigné à ceci';

  @override
  String get youCanAddMultipleStudentsIn =>
      'Vous pouvez ajouter plusieurs étudiants dans';

  @override
  String get youCanOnlyDeleteTasksYou =>
      'Vous ne pouvez supprimer que les tâches Toi';

  @override
  String get youDonTHavePermissionTo => 'Vous avez la permission de';

  @override
  String get youHaveAlreadySubmittedThisForm =>
      'Vous avez déjà soumis ce formulaire';

  @override
  String get youHaveAlreadySubmittedThisForm2 =>
      'Vous avez déjà soumis ce formulaire2';

  @override
  String get youHaveNoCompletedOrMissed =>
      'Vous n\'avez aucune classe terminée ou manquée. Si vous essayez de soumettre un rapport pour une classe plus ancienne, veuillez contacter votre administrateur.';

  @override
  String get youHaveTheRightToAccess => 'Vous avez le droit d\'accéder';

  @override
  String get youHaveUnsavedChangesAreYou =>
      'Vous avez des changements non sauvés';

  @override
  String get youMustBeLoggedInTo => 'Vous devez être accroché à';

  @override
  String get youReAllSet => 'Vous êtes tous ensemble';

  @override
  String get youReManagingRoledisplay => 'La gestion de l\'affichage des rôles';

  @override
  String get youReSignedInAsRoledisplay =>
      'Vous êtes Signé en tant qu\'affichage de rôles';

  @override
  String get yourAccountHasNotBeenSet => 'Votre compte n\'a pas été défini';

  @override
  String get yourAuditReportWillBeAvailable =>
      'Votre rapport de vérification sera disponible';

  @override
  String get yourChildHasNoScheduledClasses =>
      'Votre enfant n\'a pas de classes prévues';

  @override
  String get yourChildHasNoUpcomingClasses =>
      'Votre enfant n\'a pas de classe à venir';

  @override
  String get yourClasses => 'Vos cours';

  @override
  String get yourInformation => 'Vos informations';

  @override
  String get yourInformationIsUsedToProvide =>
      'Vos informations sont utilisées pour fournir';

  @override
  String get yourIslamicEducationJourneyStartsHere =>
      'Votre voyage d\'éducation islamique commence ici';

  @override
  String get yourPerformanceDataWillAppearHere =>
      'Vos données de performance apparaîtront ici';

  @override
  String get yourPrivacyIsImportantToUs =>
      'Votre vie privée est importante pour nous';

  @override
  String get yourProfileSettings => 'Paramètres de votre profil';

  @override
  String get yourProgressWillBeAutomaticallySaved =>
      'Vos progrès seront automatiquement enregistrés';

  @override
  String get yourRights => 'Vos droits';

  @override
  String get yourScheduledClassesWillAppearHere =>
      'Vos classes programmées apparaîtront ici';

  @override
  String get yourTeacherHasnTJoinedThe => 'Votre professeur s\'est joint Les';

  @override
  String get yourTimezone => 'Votre fuseau horaire';

  @override
  String get commonNotSignedIn => 'Non signé';

  @override
  String get commonNotAvailable => 'Sans objet';

  @override
  String get commonNotLoaded => 'Non chargé';

  @override
  String commonErrorWithDetails(Object details) {
    return 'Erreur : $details';
  }

  @override
  String get commonActivated => 'activé';

  @override
  String get commonDeactivated => 'désactivé';

  @override
  String testRoleAuthUser(Object email) {
    return 'Utilisateur auth : $email';
  }

  @override
  String testRoleUserId(Object userId) {
    return 'ID utilisateur : $userId';
  }

  @override
  String testRoleRole(Object role) {
    return 'Rôle : $role';
  }

  @override
  String testRoleKeyValue(Object key, Object value) {
    return '$key : $value';
  }

  @override
  String debugDocumentId(Object id) {
    return 'Numéro d\'identification : $id';
  }

  @override
  String debugEmail(Object email) {
    return 'Courriel: $email';
  }

  @override
  String debugName(Object name) {
    return 'Nom: $name';
  }

  @override
  String debugType(Object type) {
    return 'Type: $type';
  }

  @override
  String debugMoreDocuments(Object count) {
    return '... et $count plus de documents';
  }

  @override
  String applicationSubmitFailed(Object details) {
    return 'La demande a échoué : $details';
  }

  @override
  String get notificationSentSuccess => 'Notifications envoyées avec succès';

  @override
  String notificationRecipients(Object count) {
    return 'Bénéficiaires : $count';
  }

  @override
  String notificationSuccessCount(Object count) {
    return '✓ Succès : $count';
  }

  @override
  String notificationFailedCount(Object count) {
    return 'Échec : $count';
  }

  @override
  String notificationTotalRecipients(Object count) {
    return 'Total des bénéficiaires : $count';
  }

  @override
  String notificationEmailsSentCount(Object count) {
    return '✓ Envoyé : $count';
  }

  @override
  String notificationEmailsFailedCount(Object count) {
    return 'Échec : $count';
  }

  @override
  String classJoinFailed(Object details) {
    return 'Impossible de rejoindre la classe : $details';
  }

  @override
  String formsListFormStatus(Object status, Object statut) {
    return 'Formulaire $statut';
  }

  @override
  String formsListTemplateStatus(Object status, Object statut) {
    return 'Modèle $statut';
  }

  @override
  String formsListDeleteFieldConfirm(Object field) {
    return 'Voulez-vous vraiment supprimer \"$field\" ?';
  }

  @override
  String formsListOptionHint(Object index) {
    return 'Option $index';
  }

  @override
  String userDetailName(Object name) {
    return 'Nom: $name';
  }

  @override
  String userDetailEmail(Object email) {
    return 'Courriel: $email';
  }

  @override
  String userDetailRole(Object role) {
    return 'Rôle : $role';
  }

  @override
  String userPromoteError(Object details) {
    return 'Erreur de promotion de l\'utilisateur : $details';
  }

  @override
  String get userRevokeFailed =>
      'Impossible de révoquer les privilèges de l\'administration.';

  @override
  String userRevokeError(Object details) {
    return 'Erreur lors de la révocation des privilèges : $details';
  }

  @override
  String get userArchiveFailed => 'Impossible d\'archiver l\'utilisateur.';

  @override
  String userDeactivateError(Object details) {
    return 'Erreur lors de la désactivation de l\'utilisateur : $details';
  }

  @override
  String get userRestoreFailed => 'Impossible de restaurer l\'utilisateur.';

  @override
  String userActivateError(Object details) {
    return 'Erreur lors de l\'activation de l\'utilisateur : $details';
  }

  @override
  String userCredentialsLoadError(Object details) {
    return 'Erreur lors du chargement des identifiants : $details';
  }

  @override
  String userResetPasswordError(Object details) {
    return 'Erreur de réinitialisation du mot de passe : $details';
  }

  @override
  String get userDeleteSelfNotAllowed =>
      'Vous ne pouvez pas supprimer votre propre compte.';

  @override
  String get userArchiveBeforeDeleteFailed =>
      'Impossible d\'archiver l\'utilisateur avant la suppression.';

  @override
  String userDeleteError(Object details) {
    return 'Erreur de suppression de l\'utilisateur : $details';
  }

  @override
  String get userArchiveAndDeleteTitle => 'Archive & Permanentement Supprimer';

  @override
  String get userDeletePermanentTitle =>
      'Supprimer définitivement l\' utilisateur';

  @override
  String get userDeleteActiveInfo =>
      'Cet utilisateur est actuellement actif. Ils seront archivés d\'abord, puis définitivement supprimés.';

  @override
  String get userDeletedSuccessfully => 'L\'utilisateur supprimé avec succès';

  @override
  String userEmailRole(Object email, Object role) {
    return '$email • $role';
  }

  @override
  String auditMetricsComputed(Object score) {
    return 'métriques calculées ! Note & #160;: $score%';
  }

  @override
  String wageUpdatedUsers(Object count) {
    return 'Salaires actualisés pour les utilisateurs $count';
  }

  @override
  String wageUpdatedShifts(Object count) {
    return 'C\'est vrai. Mise à jour des équipes $count';
  }

  @override
  String wageUpdatedTimesheets(Object count) {
    return 'C\'est vrai. Entrées à jour de la feuille de temps $count';
  }

  @override
  String timesheetSubmitDrafts(Object count) {
    return 'Soumettre les projets ($count)';
  }

  @override
  String formsErrorLoading(Object details) {
    return 'Erreur lors du chargement des formulaires : $details';
  }

  @override
  String get formsNoDataReceived =>
      'Aucun formulaire n\'a été reçu. Veuillez vérifier votre connexion.';

  @override
  String formsErrorLoadingForm(Object details) {
    return 'Erreur lors du chargement du formulaire : $details';
  }

  @override
  String livekitParticipantsCount(Object count) {
    return 'Participants ($count)';
  }

  @override
  String auditGenerateCount(Object count) {
    return 'Générer ($count)';
  }

  @override
  String auditScoreWithTier(Object score, Object tier) {
    return 'Score : $score% • $tier';
  }

  @override
  String auditPaymentUpdated(Object amount) {
    return 'Paiement mis à jour en \$$amount. Total du paiement recalculé.';
  }

  @override
  String auditPenaltyApplied(Object amount) {
    return 'Peine de $amount appliquée';
  }

  @override
  String auditMaxPayment(
      Object subject, Object amount, Object hourly, Object sujet, Object time) {
    return 'Le paiement maximal pour $sujet est \$$amount (maximum \$$time/heure)';
  }

  @override
  String auditDayLabel(Object day, Object jour) {
    return 'Jour: $jour';
  }

  @override
  String auditShiftTitle(Object student, Object subject) {
    return '$student - $subject';
  }

  @override
  String auditDisputeField(Object field) {
    return 'Champ : $field';
  }

  @override
  String auditDisputeReason(Object reason) {
    return 'Raison: $reason';
  }

  @override
  String payHourlyRateUpdated(Object amount) {
    return 'Taux horaire mis à jour à \$$amount';
  }

  @override
  String paySaveFailed(Object details) {
    return 'Impossible d\'enregistrer : $details';
  }

  @override
  String timeClockClockOutExceed(Object time) {
    return 'L\'heure d\'horloge ne peut dépasser l\'heure de fin de quart prévue ($time)';
  }

  @override
  String timeClockClockOutExceedShort(Object time) {
    return 'Le temps d\'horloge ne peut pas dépasser la fin du quart: $time';
  }

  @override
  String assignmentErrorOpeningFile(Object details) {
    return 'Erreur lors de l\'ouverture du fichier : $details';
  }

  @override
  String assignmentDeleteConfirm(Object title) {
    return 'Voulez-vous vraiment supprimer \"$title\"? Cette action ne peut être annulée.';
  }

  @override
  String assignmentLoadedCount(Object count) {
    return 'Affectations chargées (limite 10): $count';
  }

  @override
  String assignmentUserId(Object id) {
    return 'Votre identifiant utilisateur : $id';
  }

  @override
  String assignmentDocId(Object id) {
    return 'Numéro d\'identification : $id';
  }

  @override
  String assignmentTitle(Object title) {
    return 'Titre: $title';
  }

  @override
  String assignmentTeacherId(Object id) {
    return 'ID de l\'enseignant : $id';
  }

  @override
  String assignmentStudentsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# étudiants',
      one: '# étudiant',
    );
    return '$_temp0';
  }

  @override
  String assignmentUploadingFile(Object fileName) {
    return 'Téléchargement de \"$fileName\"...';
  }

  @override
  String assignmentUploadSuccess(Object fileName) {
    return 'Fichier \"$fileName\" téléchargé avec succès!';
  }

  @override
  String assignmentUploadError(Object details) {
    return 'Erreur de téléchargement du fichier : $details';
  }

  @override
  String taskDownloadFailed(Object details) {
    return 'Impossible de télécharger le fichier : $details';
  }

  @override
  String taskRemoveAttachmentFailed(Object details) {
    return 'Impossible de supprimer la pièce jointe : $details';
  }

  @override
  String taskDeleteAttachmentConfirm(Object fileName) {
    return 'Voulez-vous vraiment supprimer $fileName ?';
  }

  @override
  String taskDeleteCommentError(Object details) {
    return 'Erreur lors de la suppression du commentaire : $details';
  }

  @override
  String taskSubtaskHint(Object index) {
    return 'Sous-tâche $index';
  }

  @override
  String timesheetPendingReview(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# nouvelles feuilles de temps en attente d\'examen',
      one: '# nouvelle feuille de temps en attente de révision',
    );
    return '$_temp0';
  }

  @override
  String timesheetTotalEntries(Object count) {
    return 'Total des entrées $count';
  }

  @override
  String timesheetTotalPayment(Object amount) {
    return 'Paiement total : $amount';
  }

  @override
  String timesheetTimeRange(Object start, Object end) {
    return '$start - $end';
  }

  @override
  String timesheetEntrySummary(Object hours, Object amount) {
    return '$hours heures • \$$amount';
  }

  @override
  String formSubmissionsTitle(Object title) {
    return 'Présentations • $title';
  }

  @override
  String formSubmissionsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# soumissions',
      one: '# soumission',
    );
    return '$_temp0';
  }

  @override
  String timeClockAutoClockOut(Object shift) {
    return 'Fin du quart de travail - automatiquement sorti de $shift';
  }

  @override
  String timeClockClockOutFailed(Object details) {
    return 'L\'horloge a échoué : $details';
  }

  @override
  String timeClockClockInFailed(Object details) {
    return 'L\'horloge a échoué : $details';
  }

  @override
  String shiftSelectedTimeRange(Object abbr, Object startDate, Object startTime,
      Object endDatePart, Object endTime) {
    return 'Sélectionné ($abbr): $startDate, $startTime - $endDatePart $endTime';
  }

  @override
  String shiftSelectedCount(Object count) {
    return 'Sélectionné ($count)';
  }

  @override
  String shiftConfirmCount(Object count) {
    return 'Confirmer ($count)';
  }

  @override
  String taskBulkChangeStatus(Object count) {
    return 'Modifier l\'état pour $count Fonctions';
  }

  @override
  String taskBulkChangePriority(Object count) {
    return 'Modifier la priorité pour $count Fonctions';
  }

  @override
  String taskBulkDeleteConfirm(Object count) {
    return 'Voulez-vous vraiment supprimer $count tâche(s) ? Cette action ne peut être annulée.';
  }

  @override
  String taskDeleteConfirm(Object title) {
    return 'Voulez-vous vraiment supprimer \"$title\"?';
  }

  @override
  String shiftDeletingCount(Object count) {
    return 'Suppression des équipes $count...';
  }

  @override
  String dashboardErrorLoadingFormDetails(Object details) {
    return 'Erreur lors du chargement des détails du formulaire : $details';
  }

  @override
  String dashboardErrorOpeningLink(Object details) {
    return 'Erreur lors de l\'ouverture du lien : $details';
  }

  @override
  String dashboardClockInProgrammed(Object time) {
    return 'Clock-in programmé pour $time';
  }

  @override
  String dashboardAssignmentCreateFailed(Object details) {
    return 'Impossible de créer l\'assignation : $details';
  }

  @override
  String dashboardFileAdded(Object fileName) {
    return 'Fichier \"$fileName\" ajouté avec succès!';
  }

  @override
  String get performanceLogViewerOnlyendevents => 'Only END events';

  @override
  String get performanceLogViewerPerfenabled => 'Perf enabled';

  @override
  String get performanceLogViewerCaptureenabled => 'Capture enabled';

  @override
  String get performanceLogViewerEndops => 'END ops';

  @override
  String get performanceLogViewerSlow => 'SLOW';

  @override
  String get performanceLogViewerModerate => 'MODERATE';

  @override
  String get performanceLogViewerFast => 'FAST';

  @override
  String get performanceLogViewerAvg => 'Avg';

  @override
  String get adminSettingsNotificationemail => 'Notification Email';

  @override
  String notificationPreferencesMinutesmin(int minutes) {
    return '$minutes min';
  }

  @override
  String get quickTasksAssignedby => 'Assigned By';

  @override
  String get quickTasksLabels => 'Labels';

  @override
  String get quickTasksAssignedbyme => 'Assigned by Me';

  @override
  String get quickTasksAssignedtome => 'Assigned to Me';

  @override
  String get quranReaderTranslation => 'Translation';

  @override
  String get quranReaderReload => 'Reload';

  @override
  String get adminDashboardActivetoday => 'Active today';

  @override
  String get adminDashboardOnlinenow => 'Online now';

  @override
  String get adminDashboardLiveforms => 'Live forms';

  @override
  String get timelineShiftClockinnotyet => 'Clock In (Not Yet)';

  @override
  String get timelineShiftProgrammed => 'PROGRAMMED';

  @override
  String get timelineShiftActive => 'ACTIVE';

  @override
  String get timelineShiftCompleted => 'COMPLETED';

  @override
  String get timelineShiftPartial => 'PARTIAL';

  @override
  String get timelineShiftMissed => 'MISSED';

  @override
  String get timelineShiftCancelled => 'CANCELLED';

  @override
  String get timelineShiftReady => 'READY';

  @override
  String get timelineShiftUpcoming => 'UPCOMING';

  @override
  String get shiftManagementTitle => 'Gestion des cours';

  @override
  String get shiftThisWeek => 'Cette semaine';

  @override
  String get shiftSelectDays => 'Choisir les jours';

  @override
  String get shiftNoTemplatesFound => 'Aucun modèle d\'horaire trouvé';

  @override
  String get shiftTimeLabel => 'Heure';

  @override
  String get shiftTimePerDayLabel => 'Heure par jour';

  @override
  String get shiftScheduleUpdatedSuccess => 'Horaire mis à jour avec succès';

  @override
  String get shiftScheduleUpdateFailed =>
      'Échec de la mise à jour de l\'horaire';

  @override
  String get hideFilters => 'Masquer les filtres';

  @override
  String get showFilters => 'Afficher les filtres';

  @override
  String get shiftManagementGrid => 'Grille';

  @override
  String get shiftManagementList => 'Liste';

  @override
  String shiftTabAllCount(int count) {
    return 'Tous les cours ($count)';
  }

  @override
  String shiftTabTodayCount(int count) {
    return 'Aujourd\'hui ($count)';
  }

  @override
  String shiftTabUpcomingCount(int count) {
    return 'À venir ($count)';
  }

  @override
  String shiftTabActiveCount(int count) {
    return 'Actifs ($count)';
  }

  @override
  String get shiftTemplateManagement => 'Modèles d\'horaire';

  @override
  String get shiftTemplateDeactivate => 'Désactiver l\'horaire';

  @override
  String get shiftTemplateReactivate => 'Réactiver l\'horaire';

  @override
  String get shiftTemplateReassign => 'Réaffecter l\'horaire';

  @override
  String get shiftTemplateModifyDays => 'Modifier les jours';

  @override
  String get shiftTemplateDeactivateConfirm =>
      'Cela arrêtera la génération de futurs cours. Les cours existants ne seront pas supprimés.';

  @override
  String get shiftTemplateReactivateConfirm =>
      'Cela reprendra la génération de futurs cours pour cet horaire.';

  @override
  String get shiftTemplateDeactivated => 'Horaire désactivé';

  @override
  String get shiftTemplateReactivated => 'Horaire réactivé';

  @override
  String get shiftTemplateFilterTeacher => 'Filtrer par enseignant';

  @override
  String get shiftTemplateCompleteSchedule => 'Horaire complet';

  @override
  String get shiftTemplateSearchPlaceholder =>
      'Rechercher enseignant, élève...';

  @override
  String get shiftTemplateViewTemplates => 'Modèles';

  @override
  String get shiftTemplateViewSchedule => 'Horaire complet';

  @override
  String get shiftTemplateAllTeachers => 'Tous les enseignants';

  @override
  String get shiftTemplateSelectTeacher => 'Sélectionner un enseignant';

  @override
  String get shiftTemplateStudentSchedule => 'Horaire de l\'élève';

  @override
  String get shiftWeeklyScheduleSetup =>
      'Configuration de l\'horaire hebdomadaire';

  @override
  String get shiftPerDayTime => 'Définir l\'heure par jour';

  @override
  String get shiftSameTimeAllDays => 'Même heure tous les jours';

  @override
  String get shiftDifferentTimePerDay => 'Heure différente par jour';

  @override
  String get subjectManagementDisplayname => 'Display Name *';

  @override
  String get subjectManagementArabicnameoptional => 'Arabic Name (Optional)';

  @override
  String get subjectManagementDefaulthourlywageoptional =>
      'Default Hourly Wage (Optional)';

  @override
  String get shiftDetailsTimeworked => 'Time Worked';

  @override
  String get shiftDetailsRate => 'Rate';

  @override
  String get parentInvoicesPaid => 'Paid';

  @override
  String get studentQuickStatsAttendance => 'Attendance';

  @override
  String get studentQuickStatsTasksdone => 'Tasks Done';

  @override
  String get studentProgressTabTotalhours => 'Total Hours';

  @override
  String get studentProgressTabSubjects => 'Subjects';

  @override
  String get financialSummaryOutstanding => 'Outstanding';

  @override
  String get zoomCheckingwhosintheroom => 'Checking who’s in the room…';

  @override
  String get zoomUnabletoloadparticipants => 'Unable to load participants';

  @override
  String zoomInclassnowcount(int count) {
    return 'En classe maintenant : $count';
  }

  @override
  String get studentFeatureTourLive => 'LIVE';

  @override
  String get studentFeatureTourJoinnow => 'JOIN NOW';

  @override
  String get studentFeatureTourStartingsoon => 'Starting soon';

  @override
  String get studentFeatureTourStartingin15min => 'Starting in 15 min';

  @override
  String get formsListNewquestion => 'New Question';

  @override
  String get adminAuditAvgscore => 'Avg Score';

  @override
  String get adminAuditTotalteachersaudited => 'Total Teachers Audited';

  @override
  String get adminAuditAveragescore => 'Average Score';

  @override
  String get adminAuditTotalpayoutdue => 'Total Payout Due';

  @override
  String get adminAuditPendingreviews => 'Pending Reviews';

  @override
  String get adminAuditPayout => 'Payout';

  @override
  String get adminAuditAdjust => 'Adjust';

  @override
  String get adminAuditPlanned => 'Planned';

  @override
  String get adminAuditMissing => 'Missing';

  @override
  String get formTemplate1unacceptable => '1 - Unacceptable';

  @override
  String get formTemplate1verypoor => '1 - Very Poor';

  @override
  String get formTemplate12days => '1-2 days';

  @override
  String get formTemplate10outstanding => '10 - Outstanding';

  @override
  String get formTemplate2poor => '2 - Poor';

  @override
  String get formTemplate2verypoor => '2 - Very Poor';

  @override
  String get formTemplate2448hours => '24-48 hours';

  @override
  String get formTemplate3average => '3 - Average';

  @override
  String get formTemplate3poor => '3 - Poor';

  @override
  String get formTemplate37days => '3-7 days';

  @override
  String get formTemplate4belowaverage => '4 - Below Average';

  @override
  String get formTemplate4good => '4 - Good';

  @override
  String get formTemplate5average => '5 - Average';

  @override
  String get formTemplate5excellent => '5 - Excellent';

  @override
  String get formTemplate6satisfactory => '6 - Satisfactory';

  @override
  String get formTemplate7good => '7 - Good';

  @override
  String get formTemplate8verygood => '8 - Very Good';

  @override
  String get formTemplate9excellent => '9 - Excellent';

  @override
  String get formTemplateActionplanfornextmonth => 'Action Plan for Next Month';

  @override
  String get formTemplateAdditionalcomments => 'Additional Comments';

  @override
  String get formTemplateAdditionalnotes => 'Additional Notes';

  @override
  String get formTemplateAdditionalcommentsforadmin =>
      'Additional comments for admin';

  @override
  String get formTemplateAdvanced => 'Advanced';

  @override
  String get formTemplateAllontime => 'All on time';

  @override
  String get formTemplateAllretained => 'All retained';

  @override
  String get formTemplateAlwaysontime => 'Always on time';

  @override
  String get formTemplateAnyadditionalobservationsaboutthestudent =>
      'Any additional observations about the student...';

  @override
  String get formTemplateAnychallengesorsupportneeded =>
      'Any challenges or support needed?';

  @override
  String get formTemplateAnyfeedbackrequestsorconcerns =>
      'Any feedback, requests, or concerns';

  @override
  String get formTemplateAnyissuesorconcerns => 'Any issues or concerns?';

  @override
  String get formTemplateAnyotherfeedbackorsuggestions =>
      'Any other feedback or suggestions...';

  @override
  String get formTemplateAnysuggestionsforimprovement =>
      'Any suggestions for improvement?';

  @override
  String get formTemplateArabicreadinglevel => 'Arabic Reading Level';

  @override
  String get formTemplateArabicwritinglevel => 'Arabic Writing Level';

  @override
  String get formTemplateAreasforimprovement => 'Areas for Improvement';

  @override
  String get formTemplateAssessmenttype => 'Assessment Type';

  @override
  String get formTemplateAudittimeliness => 'Audit Timeliness';

  @override
  String get formTemplateAuditscompletedthismonth =>
      'Audits Completed This Month';

  @override
  String get formTemplateAverageresponsetimetoissues =>
      'Average Response Time to Issues';

  @override
  String get formTemplateBeginner => 'Beginner';

  @override
  String get formTemplateBelowexpectations => 'Below expectations';

  @override
  String get formTemplateBiggestachievementthismonth =>
      'Biggest Achievement This Month';

  @override
  String get formTemplateBiggestchallengefaced => 'Biggest Challenge Faced';

  @override
  String get formTemplateBrieftopicofyourfeedback =>
      'Brief topic of your feedback';

  @override
  String get formTemplateChallenging => 'Challenging';

  @override
  String get formTemplateChild => 'Child\\';

  @override
  String get formTemplateClassesshouldbecancelled =>
      'Classes should be cancelled';

  @override
  String get formTemplateCoachname => 'Coach Name';

  @override
  String get formTemplateComplaint => 'Complaint';

  @override
  String get formTemplateCritical => 'Critical';

  @override
  String get formTemplateDateofincident => 'Date of Incident';

  @override
  String get formTemplateDefinitelyno => 'Definitely no';

  @override
  String get formTemplateDefinitelyyes => 'Definitely yes';

  @override
  String get formTemplateDescribeanyimmediateactiontaken =>
      'Describe any immediate action taken...';

  @override
  String get formTemplateDescribewhathappened => 'Describe what happened';

  @override
  String get formTemplateDescribeyourmainaccomplishment =>
      'Describe your main accomplishment...';

  @override
  String get formTemplateDetaileddescription => 'Detailed Description';

  @override
  String get formTemplateDissatisfied => 'Dissatisfied';

  @override
  String get formTemplateEnddate => 'End Date';

  @override
  String get formTemplateEndofsemester => 'End of Semester';

  @override
  String get formTemplateEnterstudentfullname => 'Enter student full name';

  @override
  String get formTemplateExcellent => 'Excellent';

  @override
  String get formTemplateFamilyemergency => 'Family Emergency';

  @override
  String get formTemplateFewgoals => 'Few goals';

  @override
  String get formTemplateFluent => 'Fluent';

  @override
  String get formTemplateGoalsfornextmonth => 'Goals for Next Month';

  @override
  String get formTemplateGood => 'Good';

  @override
  String get formTemplateHaveyouarrangedforcoverage =>
      'Have you arranged for coverage?';

  @override
  String get formTemplateHighturnover => 'High turnover';

  @override
  String get formTemplateHowdidthesessiongo => 'How did the session go?';

  @override
  String get formTemplateHoweffectiveistheircommunication =>
      'How effective is their communication?';

  @override
  String get formTemplateHowhelpfulisthesupportyoureceive =>
      'How helpful is the support you receive?';

  @override
  String get formTemplateHowmanyhadithsdoesthisstudentknow =>
      'How many Hadiths does this student know?';

  @override
  String get formTemplateHowmanysurahsdoesthisstudentknow =>
      'How many Surahs does this student know?';

  @override
  String get formTemplateHowmanyclasseswillbemissed =>
      'How many classes will be missed?';

  @override
  String get formTemplateHowmanystudentsattended =>
      'How many students attended?';

  @override
  String get formTemplateHowmuchadvancenoticeareyouproviding =>
      'How much advance notice are you providing?';

  @override
  String get formTemplateHowurgentisthis => 'How urgent is this?';

  @override
  String get formTemplateHowwouldyouratethismonth =>
      'How would you rate this month?';

  @override
  String get formTemplateHowwouldyouratethisweekoverall =>
      'How would you rate this week overall?';

  @override
  String get formTemplateHowwouldyourateyourcoachleaderoverall =>
      'How would you rate your coach/leader overall?';

  @override
  String get formTemplateInitialnewstudent => 'Initial (New Student)';

  @override
  String get formTemplateIntermediate => 'Intermediate';

  @override
  String get formTemplateIsfollowupneeded => 'Is follow-up needed?';

  @override
  String get formTemplateIsyourchildmakingprogress =>
      'Is your child making progress?';

  @override
  String get formTemplateIssuesproblemsresolved => 'Issues/Problems Resolved';

  @override
  String get formTemplateKeystrengths => 'Key Strengths';

  @override
  String get formTemplateLeaveemptyifnone => 'Leave empty if none';

  @override
  String get formTemplateLittleprogress => 'Little progress';

  @override
  String get formTemplateLow => 'Low';

  @override
  String get formTemplateMedium => 'Medium';

  @override
  String get formTemplateMidsemester => 'Mid-Semester';

  @override
  String get formTemplateMinorturnover12 => 'Minor turnover (1-2)';

  @override
  String get formTemplateModerateturnover3 => 'Moderate turnover (3+)';

  @override
  String get formTemplateMorethan1week => 'More than 1 week';

  @override
  String get formTemplateMorethan48hours => 'More than 48 hours';

  @override
  String get formTemplateMostgoals => 'Most goals';

  @override
  String get formTemplateMostontime80 => 'Most on time (>80%)';

  @override
  String get formTemplateNameofcoachbeingreviewed =>
      'Name of coach being reviewed';

  @override
  String get formTemplateNamesofpeopleinvolved => 'Names of people involved';

  @override
  String get formTemplateNeedsimprovement => 'Needs Improvement';

  @override
  String get formTemplateNeutral => 'Neutral';

  @override
  String get formTemplateNoneedadminhelp => 'No - need admin help';

  @override
  String get formTemplateNoprogress => 'No progress';

  @override
  String get formTemplateNoincludemyname => 'No, include my name';

  @override
  String get formTemplateNothelpful => 'Not Helpful';

  @override
  String get formTemplateNotstarted => 'Not Started';

  @override
  String get formTemplateNotsure => 'Not sure';

  @override
  String get formTemplateNumberofhadiths => 'Number of Hadiths';

  @override
  String get formTemplateNumberofsurahs => 'Number of Surahs';

  @override
  String get formTemplateNumberofteachersmanaged =>
      'Number of Teachers Managed';

  @override
  String get formTemplateNumberofteachersyousupported =>
      'Number of Teachers You Supported';

  @override
  String get formTemplateNumberofshiftsaffected => 'Number of shifts affected';

  @override
  String get formTemplateNumberofstudentspresent =>
      'Number of students present';

  @override
  String get formTemplateOftenlate => 'Often late';

  @override
  String get formTemplateOverallcoachrating110 => 'Overall Coach Rating (1-10)';

  @override
  String get formTemplateOverallsatisfactionwithteacher =>
      'Overall Satisfaction with Teacher';

  @override
  String get formTemplateOverallstudentlevel => 'Overall Student Level';

  @override
  String get formTemplateParentconcern => 'Parent Concern';

  @override
  String get formTemplatePersonalemergency => 'Personal Emergency';

  @override
  String get formTemplatePlanfornextsession => 'Plan for next session';

  @override
  String get formTemplatePleaseexplainthereasonforyourrequest =>
      'Please explain the reason for your request...';

  @override
  String get formTemplatePleaseprovideadetaileddescription =>
      'Please provide a detailed description...';

  @override
  String get formTemplatePleaseprovidedetailsaboutyourfeedback =>
      'Please provide details about your feedback...';

  @override
  String get formTemplatePoor => 'Poor';

  @override
  String get formTemplatePraise => 'Praise';

  @override
  String get formTemplatePreplannedabsence => 'Pre-planned Absence';

  @override
  String get formTemplateProbablyno => 'Probably no';

  @override
  String get formTemplateProbablyyes => 'Probably yes';

  @override
  String get formTemplateQualityofcommunication => 'Quality of Communication';

  @override
  String get formTemplateQualityofteachersupport =>
      'Quality of Teacher Support';

  @override
  String get formTemplateRateyourperformancethismonth =>
      'Rate Your Performance This Month';

  @override
  String get formTemplateRatereadingskills15 => 'Rate reading skills (1-5)';

  @override
  String get formTemplateRatewritingskills15 => 'Rate writing skills (1-5)';

  @override
  String get formTemplateReasonforleave => 'Reason for Leave';

  @override
  String get formTemplateReligiousholiday => 'Religious Holiday';

  @override
  String get formTemplateSameday => 'Same day';

  @override
  String get formTemplateSatisfied => 'Satisfied';

  @override
  String get formTemplateSchedulingconflict => 'Scheduling Conflict';

  @override
  String get formTemplateSickleave => 'Sick Leave';

  @override
  String get formTemplateSignificantdelays => 'Significant delays';

  @override
  String get formTemplateSignificantprogress => 'Significant progress';

  @override
  String get formTemplateSomedelays80 => 'Some delays (<80%)';

  @override
  String get formTemplateSomegoals => 'Some goals';

  @override
  String get formTemplateSomeprogress => 'Some progress';

  @override
  String get formTemplateSometimeslate => 'Sometimes late';

  @override
  String get formTemplateSomewhathelpful => 'Somewhat Helpful';

  @override
  String get formTemplateSpecificgoalsoractions =>
      'Specific goals or actions...';

  @override
  String get formTemplateStudentbehavior => 'Student Behavior';

  @override
  String get formTemplateStudentname => 'Student Name';

  @override
  String get formTemplateSubjecttopic => 'Subject/Topic';

  @override
  String get formTemplateSubmitanonymously => 'Submit anonymously?';

  @override
  String get formTemplateSuggestion => 'Suggestion';

  @override
  String get formTemplateSummarizestudentprogressmilestonesreachedetc =>
      'Summarize student progress, milestones reached, etc.';

  @override
  String get formTemplateSupportneededfromleadership =>
      'Support Needed from Leadership';

  @override
  String get formTemplateTaskscompletedthismonth =>
      'Tasks Completed This Month';

  @override
  String get formTemplateTaskscurrentlyoverdue => 'Tasks Currently Overdue';

  @override
  String get formTemplateTeachername => 'Teacher Name';

  @override
  String get formTemplateTeacherpunctuality => 'Teacher Punctuality';

  @override
  String get formTemplateTeacherretentioninteam => 'Teacher Retention in Team';

  @override
  String get formTemplateTechnicalissue => 'Technical Issue';

  @override
  String get formTemplateTypeoffeedback => 'Type of Feedback';

  @override
  String get formTemplateTypeofincident => 'Type of Incident';

  @override
  String get formTemplateTypeofleave => 'Type of Leave';

  @override
  String get formTemplateUsuallyontime => 'Usually on time';

  @override
  String get formTemplateVerydissatisfied => 'Very Dissatisfied';

  @override
  String get formTemplateVeryhelpful => 'Very Helpful';

  @override
  String get formTemplateVerysatisfied => 'Very Satisfied';

  @override
  String get formTemplateWereyourteachinggoalsmet =>
      'Were your teaching goals met?';

  @override
  String get formTemplateWhatactiondidyoutake => 'What action did you take?';

  @override
  String get formTemplateWhatadditionalsupportwouldhelpyou =>
      'What additional support would help you?';

  @override
  String get formTemplateWhatcouldbedonebetter => 'What could be done better?';

  @override
  String get formTemplateWhatdoyouplantoaccomplish =>
      'What do you plan to accomplish?';

  @override
  String get formTemplateWhatdoesthiscoachdowell =>
      'What does this coach do well?';

  @override
  String get formTemplateWhatlessontopicdidyoucovertoday =>
      'What lesson/topic did you cover today?';

  @override
  String get formTemplateWhatshouldthiscoachworkon =>
      'What should this coach work on?';

  @override
  String get formTemplateWhatwasyourmainchallenge =>
      'What was your main challenge?';

  @override
  String get formTemplateWhatwerethekeyachievementsthisweek =>
      'What were the key achievements this week?';

  @override
  String get formTemplateWhatwillyoucovernext => 'What will you cover next?';

  @override
  String get formTemplateWhowasinvolved => 'Who was involved?';

  @override
  String get formTemplateWithin24hours => 'Within 24 hours';

  @override
  String get formTemplateWouldyourecommendthisteacher =>
      'Would you recommend this teacher?';

  @override
  String get formTemplateYesnonurgent => 'Yes - Non-urgent';

  @override
  String get formTemplateYesurgent => 'Yes - Urgent';

  @override
  String get formTemplateYesanotherteacherwillcover =>
      'Yes - another teacher will cover';

  @override
  String get formTemplateYesallgoals => 'Yes, all goals';

  @override
  String get formTemplateYeskeepanonymous => 'Yes, keep anonymous';

  @override
  String get formTemplateEgsurahalfatihaverses13 =>
      'e.g., Surah Al-Fatiha verses 1-3';

  @override
  String get formTemplateAdminselfassessment => 'Admin Self-Assessment';

  @override
  String get formTemplateCoachperformancereview => 'Coach Performance Review';

  @override
  String get formTemplateCollectfeedbackfromparentsabouttheirchild =>
      'Collect feedback from parents about their child\\';

  @override
  String get formTemplateDailyclassreport => 'Daily Class Report';

  @override
  String get formTemplateEndofmonthteachingreview =>
      'End of month teaching review';

  @override
  String get formTemplateEndofweekteachingsummary =>
      'End of week teaching summary';

  @override
  String
      get formTemplateEvaluatestudentprogressandskillsatenrollmentorsemesterend =>
          'Evaluate student progress and skills at enrollment or semester end';

  @override
  String get formTemplateFeedbackforleaders => 'Feedback for Leaders';

  @override
  String get formTemplateIncidentreport => 'Incident Report';

  @override
  String get formTemplateLeaverequest => 'Leave Request';

  @override
  String get formTemplateMonthlyreview => 'Monthly Review';

  @override
  String
      get formTemplateMonthlyevaluationofcoachsupervisorperformanceadminonly =>
          'Monthly evaluation of coach/supervisor performance (Admin only)';

  @override
  String get formTemplateMonthlyselfevaluationforadministratorsandcoaches =>
      'Monthly self-evaluation for administrators and coaches';

  @override
  String get formTemplateParentguardianfeedback => 'Parent/Guardian Feedback';

  @override
  String get formTemplateQuickreportaftereachteachingsession =>
      'Quick report after each teaching session';

  @override
  String get formTemplateRateandprovidefeedbackaboutyourcoachsupervisor =>
      'Rate and provide feedback about your coach/supervisor';

  @override
  String get formTemplateReportanincidentorissuethatoccurred =>
      'Report an incident or issue that occurred';

  @override
  String get formTemplateRequesttimeofforabsencefromscheduledshifts =>
      'Request time off or absence from scheduled shifts';

  @override
  String get formTemplateStudentassessment => 'Student Assessment';

  @override
  String get formTemplateSubmitfeedbacksuggestionsorcomplaintstoleadership =>
      'Submit feedback, suggestions, or complaints to leadership';

  @override
  String get formTemplateTeacherfeedbackcomplaints =>
      'Teacher Feedback & Complaints';

  @override
  String get formTemplateWeeklysummary => 'Weekly Summary';

  @override
  String get sidebarAudits => 'Audits';

  @override
  String get sidebarCms => 'CMS';

  @override
  String get sidebarCommunication => 'Communication';

  @override
  String get sidebarFormbuilder => 'Form Builder';

  @override
  String get sidebarLearning => 'Learning';

  @override
  String get sidebarMyreport => 'My Report';

  @override
  String get sidebarMyshifts => 'My Shifts';

  @override
  String get sidebarOperations => 'Operations';

  @override
  String get sidebarPeople => 'People';

  @override
  String get sidebarReports => 'Reports';

  @override
  String get sidebarRolestest => 'Roles (Test)';

  @override
  String get sidebarSubjectrates => 'Subject Rates';

  @override
  String get sidebarTestauditgeneration => 'Test Audit Génération';

  @override
  String get sidebarWebsite => 'Website';

  @override
  String get sidebarWork => 'Work';

  @override
  String get recurrenceNone => 'Aucune récurrence';

  @override
  String get recurrenceDaily => 'Quotidien';

  @override
  String recurrenceDailyExcludingDays(Object days) {
    return 'Quotidien (sauf $days)';
  }

  @override
  String recurrenceExcludedDates(Object count) {
    return '($count dates spécifiques exclues)';
  }

  @override
  String recurrenceWeeklyOn(Object days) {
    return 'Hebdomadaire le $days';
  }

  @override
  String recurrenceMonthlyOn(Object days) {
    return 'Mensuel le $days';
  }

  @override
  String recurrenceMonthlyOnCount(Object count) {
    return 'Mensuel sur $count jours sélectionnés';
  }

  @override
  String recurrenceYearlyIn(Object months) {
    return 'Annuel en $months';
  }

  @override
  String get settingsTourJoinClassDescription =>
      'Touchez une carte de cours à venir et cliquez sur \"Rejoindre le cours\" au moment venu.';

  @override
  String get settingsTourEnableNotificationsDescription =>
      'Activez les notifications dans les paramètres pour recevoir des rappels avant vos cours.';

  @override
  String get settingsTourMediaControlsDescription =>
      'Utilisez les boutons micro et caméra pour contrôler votre audio et votre vidéo.';

  @override
  String get settingsTourChatDescription =>
      'Envoyez des messages à votre enseignant via l\'onglet Chat.';

  @override
  String taskSubtaskOf(Object title) {
    return 'Sous-tâche de : $title';
  }

  @override
  String get taskUnassigned => 'Non attribué';

  @override
  String get taskSelectMultiple => 'Sélection multiple';

  @override
  String get taskExitSelection => 'Quitter la sélection';

  @override
  String editAllInSeriesCount(Object count) {
    return 'Modifier toute la série ($count)';
  }

  @override
  String get shiftUpdatesTemplate => 'Met à jour le modèle';

  @override
  String get selectStartTime => 'Sélectionner l\'heure de début';

  @override
  String get selectEndTime => 'Sélectionner l\'heure de fin';

  @override
  String shiftTimesheetRecords(Object count) {
    return 'Enregistrements de feuille de temps ($count)';
  }

  @override
  String shiftDurationHours(Object hours) {
    return '$hours heures';
  }

  @override
  String shiftHourlyRateValue(Object rate) {
    return '\$$rate/h';
  }

  @override
  String get shiftActiveNow => 'Actif maintenant';

  @override
  String get shiftDetailDate => 'Date';

  @override
  String get shiftDetailTime => 'Heure';

  @override
  String get shiftDetailDuration => 'Durée';

  @override
  String get shiftDetailSubject => 'Matière';

  @override
  String get shiftDetailHourlyRate => 'Taux horaire';

  @override
  String get shiftDetailNotes => 'Notes';

  @override
  String get shiftDetailTeacher => 'Enseignant';

  @override
  String get shiftDetailTotalWorked => 'Total travaillé';

  @override
  String get shiftDetailClockIn => 'Pointage d\'entrée';

  @override
  String get shiftDetailClockOut => 'Pointage de sortie';

  @override
  String get shiftStatusInProgress => 'En cours';

  @override
  String shiftElapsedTime(Object time) {
    return 'Temps écoulé : $time';
  }

  @override
  String get shiftStatusFullyCompleted => 'Entièrement terminé';

  @override
  String get shiftStatusAllScheduledTimeWorked =>
      'Tout le temps programmé a été travaillé';

  @override
  String get shiftStatusPartiallyCompleted => 'Partiellement terminé';

  @override
  String get shiftStatusSomeTimeWorked =>
      'Une partie du temps a été travaillée';

  @override
  String get shiftStatusMissed => 'Manqué';

  @override
  String get shiftStatusNotAttended => 'Ce cours n\'a pas été effectué';

  @override
  String get shiftStatusReadyToStart => 'Prêt à commencer';

  @override
  String get shiftStatusCanClockInNow => 'Vous pouvez pointer maintenant !';

  @override
  String get shiftStatusUpcoming => 'À venir';

  @override
  String shiftStartsInDays(Object count) {
    return 'Commence dans $count jours';
  }

  @override
  String shiftStartsInHours(Object count) {
    return 'Commence dans $count heures';
  }

  @override
  String shiftStartsInMinutes(Object count) {
    return 'Commence dans $count minutes';
  }

  @override
  String get shiftStatusScheduled => 'Planifié';

  @override
  String get shiftStatusActive => 'Actif';

  @override
  String get shiftStatusCompleted => 'Terminé';

  @override
  String get shiftStatusCancelled => 'Annulé';

  @override
  String get shiftStatusApproved => 'Approuvé';

  @override
  String shiftStatusApprovedOn(Object date) {
    return 'Approuvé le $date';
  }

  @override
  String get shiftStatusPaid => 'Payé';

  @override
  String get shiftStatusPaymentProcessed => 'Paiement traité';

  @override
  String get shiftStatusRejected => 'Rejeté';

  @override
  String get shiftStatusReviewResubmit => 'Veuillez vérifier et renvoyer';

  @override
  String get shiftStatusPendingApproval => 'En attente d\'approbation';

  @override
  String get shiftStatusAwaitingAdminReview =>
      'En attente de validation de l\'administrateur';

  @override
  String get shiftStatusEditPending => 'Modification en attente';

  @override
  String get shiftStatusEditAwaitingApproval =>
      'Votre modification est en attente d\'approbation';

  @override
  String get localTime => 'Heure locale';

  @override
  String get shiftStatusConfirmed => '✓ Confirmé';

  @override
  String get shiftStatusPending => 'En attente';

  @override
  String weeklyScheduleTeachersCount(Object count) {
    return 'ENSEIGNANTS ($count)';
  }

  @override
  String weeklyScheduleLeadersCount(Object count) {
    return 'RESPONSABLES ($count)';
  }

  @override
  String weeklyScheduleDateRange(Object start, Object end) {
    return '$start → $end';
  }

  @override
  String weeklyScheduleShiftsScheduled(Object count) {
    return '$count cours planifiés';
  }

  @override
  String weeklyScheduleShiftNumber(Object number) {
    return 'Cours n°$number';
  }

  @override
  String get auditScheduled => 'Planifié';

  @override
  String get auditCompleted => 'Terminé';

  @override
  String get auditMissed => 'Manqué';

  @override
  String get auditCompletionRate => 'Taux de complétion';

  @override
  String get auditTotalClockIns => 'Total des pointages';

  @override
  String get auditOnTime => 'À l\'heure';

  @override
  String get auditLate => 'En retard';

  @override
  String get auditPunctualityRate => 'Taux de ponctualité';

  @override
  String get auditRequired => 'Requis';

  @override
  String get auditSubmitted => 'Soumis';

  @override
  String get auditComplianceRate => 'Taux de conformité';

  @override
  String auditCompletionPercent(Object percent) {
    return '$percent % de complétion';
  }

  @override
  String auditSubjectsCount(Object count) {
    return '$count matières';
  }

  @override
  String auditOnTimeClockIns(Object onTime, Object total) {
    return '$onTime/$total à l\'heure';
  }

  @override
  String auditCompliancePercent(Object percent) {
    return '$percent % de conformité';
  }

  @override
  String get notificationSelectAtLeastOneUser =>
      'Sélectionnez au moins un utilisateur';

  @override
  String notificationConfirmSelected(Object count) {
    return 'Confirmer ($count sélectionné(s))';
  }

  @override
  String get notificationEnterTitle => 'Veuillez saisir un titre';

  @override
  String get notificationEnterMessage => 'Veuillez saisir un message';

  @override
  String notificationUsersSelected(Object count) {
    return '$count utilisateurs sélectionnés';
  }

  @override
  String get noUsersFound => 'Aucun utilisateur trouvé';

  @override
  String get noUsersMatchSearch =>
      'Aucun utilisateur ne correspond à votre recherche';

  @override
  String get commonUser => 'Utilisateur';

  @override
  String get commonUnknownUser => 'Utilisateur inconnu';

  @override
  String get commonUnknownParent => 'Parent inconnu';

  @override
  String get commonUnknownSubject => 'Matière inconnue';

  @override
  String get commonUnknownTeacher => 'Enseignant inconnu';

  @override
  String get commonUnknownStudent => 'Élève inconnu';

  @override
  String get commonUnknownShift => 'Cours inconnu';

  @override
  String get commonUnknownClass => 'Classe inconnue';

  @override
  String get commonUnknownForm => 'Formulaire inconnu';

  @override
  String get commonUnknownDate => 'Date inconnue';

  @override
  String get commonUnknownFile => 'Fichier inconnu';

  @override
  String get commonUnknownError => 'Erreur inconnue';

  @override
  String get commonUnknownInitial => 'I';

  @override
  String timeClockTeachingSessionWith(Object name) {
    return 'Séance d\'enseignement avec $name';
  }

  @override
  String formQuestionNumber(Object number) {
    return 'Question $number';
  }

  @override
  String get formSelectMultipleOptions => 'Sélectionnez plusieurs options...';

  @override
  String get selectUser => 'Sélectionner un utilisateur';

  @override
  String get selectDateRange => 'Sélectionner une plage de dates';

  @override
  String get selectDateRangeForFormResponses =>
      'Sélectionner une plage de dates pour les réponses';

  @override
  String get selectDateRangeForFormSubmissions =>
      'Sélectionner une plage de dates pour les soumissions';

  @override
  String get selectDateRangeForTimesheetReview =>
      'Sélectionner une plage de dates pour la revue des feuilles de temps';

  @override
  String get selectDateRangeForTasks =>
      'Sélectionner une plage de dates pour les tâches';

  @override
  String get selectDueDateRange =>
      'Sélectionner une plage de dates d\'échéance';

  @override
  String get selectDates => 'Sélectionner des dates';

  @override
  String selectStudentsWithCount(Object count) {
    return 'Sélectionner des élèves ($count sélectionné(s))';
  }

  @override
  String get selectTimezone => 'Sélectionner un fuseau horaire';

  @override
  String get selectTimezonePlaceholder => 'Sélectionner un fuseau horaire…';

  @override
  String get selectEndDate => 'Sélectionner la date de fin';

  @override
  String get formsNoActiveMatching =>
      'Aucun formulaire actif ne correspond à votre recherche.';

  @override
  String formsNoActiveForRole(Object role) {
    return 'Aucun formulaire actif pour $role.';
  }

  @override
  String formsFieldCount(Object count) {
    return '$count champs';
  }

  @override
  String get livekitMuteAll => 'Tout couper';

  @override
  String get livekitPip => 'Image dans l\'image';

  @override
  String get livekitQuran => 'Coran';

  @override
  String get livekitLeave => 'Quitter';

  @override
  String get whiteboard => 'Tableau blanc';

  @override
  String get whiteboardClose => 'Fermer tableau';

  @override
  String get whiteboardTeacherView => 'Tableau de l\'enseignant';

  @override
  String get whiteboardViewOnly => 'Lecture seule';

  @override
  String get whiteboardStudentsCanDraw => 'Les élèves peuvent dessiner';

  @override
  String parentInvoiceDueDate(Object date) {
    return 'Échéance $date';
  }

  @override
  String get studentFeatureTourLiveDesc => 'Ce cours est en direct maintenant.';

  @override
  String get studentFeatureTourJoinNowDesc =>
      'Rejoignez votre cours lorsque le bouton apparaît.';

  @override
  String get studentFeatureTourStartingSoonDesc => 'Ce cours commence bientôt.';

  @override
  String get studentFeatureTourStartingSoon15Desc =>
      'Ce cours commence dans environ 15 minutes.';

  @override
  String get studentFeatureTourScheduledDesc =>
      'Ce cours est programmé pour plus tard.';

  @override
  String get formsUntitledForm => 'Formulaire sans titre';

  @override
  String get formsUntitledField => 'Champ sans titre';

  @override
  String get formsEnterValue => 'Saisissez une valeur';

  @override
  String roleUnknownMessage(Object role) {
    return 'Rôle : $role\nVeuillez contacter un administrateur.';
  }

  @override
  String get navTutor => 'Tuteur';

  @override
  String get tutorTitle => 'Tuteur IA';

  @override
  String get tutorSubtitle => 'Votre assistant d\'apprentissage personnel';

  @override
  String get tutorConnecting => 'Connexion à votre tuteur...';

  @override
  String get tutorConnectionError => 'Erreur de connexion';

  @override
  String get tutorConnectionFailed =>
      'Échec de la connexion au tuteur IA. Veuillez réessayer.';

  @override
  String get tutorMicPermissionRequired =>
      'L\'autorisation du microphone est requise pour parler au tuteur IA.';

  @override
  String get tutorNotAvailableForRole =>
      'Le tuteur IA est disponible uniquement pour les étudiants.';

  @override
  String get tutorServiceUnavailable =>
      'Le service de tuteur IA est actuellement indisponible. Veuillez réessayer plus tard.';

  @override
  String get tutorListening => 'À l\'écoute...';

  @override
  String get tutorWaitingForAgent => 'Connexion à Alluwal';

  @override
  String get tutorSpeakNow =>
      'Posez-moi n\'importe quelle question sur vos études!';

  @override
  String get tutorAgentConnecting => 'Alluwal arrive...';

  @override
  String get tutorMicOn => 'Micro activé';

  @override
  String get tutorMicOff => 'Micro désactivé';

  @override
  String get tutorEndSession => 'Terminer';

  @override
  String get tutorShowAI => 'Montrer IA';

  @override
  String get tutorWhiteboardSent => 'Tableau envoyé à l\'IA';

  @override
  String get tutorWhiteboardFailed => 'Échec de l\'envoi du tableau';

  @override
  String get tutorStartSession => 'Commencer la session';

  @override
  String get tutorDescription =>
      'Parlez à Alluwal, votre compagnon d\'apprentissage IA. Posez des questions sur les matières scolaires ou explorez les histoires de l\'histoire islamique.';

  @override
  String get classJoin => 'Rejoindre';

  @override
  String get classMeetingNotReady => 'Réunion pas prête';

  @override
  String classJoinIn(String time) {
    return 'Rejoindre ($time)';
  }

  @override
  String get classEnded => 'Terminé';

  @override
  String get classFilterAll => 'Tous';

  @override
  String get classFilterJoinable => 'Disponibles';

  @override
  String get classFilterActive => 'Actifs';

  @override
  String get classFilterUpcoming => 'À venir';

  @override
  String get classFilterPast => 'Passés';

  @override
  String get livekitErrorNotDeployed => 'Fonction de présence non déployée';

  @override
  String get livekitErrorPermissionDenied => 'Permission refusée';

  @override
  String get livekitErrorUnauthenticated => 'Veuillez vous reconnecter';

  @override
  String get livekitErrorServiceUnavailable => 'Service indisponible';

  @override
  String get classAvailableWhenJoinable =>
      'Disponible lorsque le cours peut être rejoint';

  @override
  String get classNoOneJoinedYet => 'Personne n\'a encore rejoint';

  @override
  String get classesMyClasses => 'Mes cours';

  @override
  String get classesYourClasses => 'Vos cours';

  @override
  String get classesJoinDescription =>
      'Rejoignez vos cours directement dans l\'application. Le bouton Rejoindre devient actif 10 minutes avant le début du cours.';

  @override
  String filtersCount(int count) {
    return 'Filtres ($count)';
  }

  @override
  String get filterAny => 'Tous';

  @override
  String get classesNoActiveClassesNow => 'Aucun cours actif en ce moment';

  @override
  String get classesSwitchTimeFilter =>
      'Changez le filtre Heure sur À venir ou Tous pour parcourir d\'autres cours.';

  @override
  String classesResultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count résultats',
      one: '1 résultat',
    );
    return '$_temp0';
  }

  @override
  String classesParticipantsCount(int count) {
    return 'Participants ($count)';
  }

  @override
  String get classesNoMatchFilters => 'Aucun cours ne correspond à vos filtres';

  @override
  String get classesNoClassesFound => 'Aucun cours trouvé';

  @override
  String get classesTryAdjustingFilters =>
      'Essayez d\'ajuster vos filtres ou de les effacer.';

  @override
  String get classesTryClearingFilters =>
      'Essayez d\'effacer les filtres ou revenez plus tard.';

  @override
  String get teamOurGlobalTeam => 'NOTRE ÉQUIPE MONDIALE';

  @override
  String get teamMeetThePeopleBehindAlluwal =>
      'Découvrez les personnes derrière Alluwal';

  @override
  String get teamHeroSubtitle =>
      'Éducateurs, responsables et innovateurs unis par une même mission : rendre une éducation islamique et scolaire de qualité accessible à tous, partout dans le monde.';

  @override
  String get teamAllTeam => 'Toute l\'équipe';

  @override
  String get teamAllTeamTagline => 'La grande famille Alluwal';

  @override
  String get teamAllTeamDescription =>
      'Visionnaires et éducateurs unis par une seule mission.';

  @override
  String get teamLeadership => 'Équipe dirigeante';

  @override
  String get teamLeadershipTagline => 'Vision et cap';

  @override
  String get teamLeadershipDescription =>
      'Ceux qui conçoivent et coordonnent Alluwal — politique, stratégie, opérations et culture.';

  @override
  String get teamTeachers => 'Enseignants';

  @override
  String get teamTeachersTagline => 'Passeurs de savoir mondiaux';

  @override
  String get teamTeachersDescription =>
      'Savants et éducateurs dans plus de 10 pays — ils apportent l\'excellence islamique et scolaire à chaque apprenant, partout dans le monde.';

  @override
  String get teamFounderBadge => '✦  FONDATEUR';

  @override
  String get teamViewFullProfile => 'Voir le profil complet';

  @override
  String get teamWantToJoinOurTeam => 'Vous voulez rejoindre notre équipe ?';

  @override
  String get teamJoinSubtitle =>
      'Nous sommes toujours à la recherche d\'éducateurs et de professionnels passionnés qui partagent notre vision. Rejoignez-nous pour faire la différence.';

  @override
  String get teamViewProfile => 'Voir le profil';

  @override
  String teamAboutName(String name) {
    return 'À propos de $name';
  }

  @override
  String get teamWhyAlluwal => 'Pourquoi Alluwal';

  @override
  String get teamLanguages => 'Langues';

  @override
  String teamContactName(String name) {
    return 'Contacter $name';
  }

  @override
  String teamMessageForName(String name) {
    return 'Message pour $name';
  }

  @override
  String get teamStaffFallbackSnippet =>
      'Diffuser le savoir et la lumière à travers Alluwal Education Hub.';

  @override
  String get teamStaffFallbackBio =>
      'Un membre dévoué de l\'équipe Alluwal, engagé à offrir une éducation islamique et académique de qualité aux apprenants du monde entier.';

  @override
  String get teamStaffFallbackWhyAlluwal =>
      'Je crois en la mission d\'Alluwal : rendre l\'éducation accessible et permettre à chaque élève de s\'épanouir spirituellement et scolairement, où qu\'il soit.';

  @override
  String get teamPartOfTeamBuildsPlatform =>
      'Membre de l\'équipe qui construit notre plateforme · Maths et sciences';

  @override
  String get always24Hours7Days => 'Toujours (24/7)';

  @override
  String get chatMessagesLabel => 'Messages de discussion';

  @override
  String get adjustmentAmountExampleHint => 'e.g., +0.2 or -5';

  @override
  String get formResponsesTitle => 'Réponses au formulaire';

  @override
  String get optionsCommaSeparatedExample => 'ex. Option 1, Option 2, Option 3';

  @override
  String get readinessFormRequiredTitle => 'Formulaire de préparation requis';

  @override
  String get requiredForRatingsBelow9 => 'Note requise ci-dessous 9';

  @override
  String get shiftCompletedLabel => 'Poste terminé';

  @override
  String get studentDefaultName1 => 'Étudiant 1';

  @override
  String get requiredAsterisk => '*';

  @override
  String get notProvidedLabel => 'Non renseigné';

  @override
  String get bulletSeparator => ' • ';

  @override
  String get timesheetDetailsTitle => 'Détails du calendrier';

  @override
  String get userRoleLabel => 'Rôle de l\'utilisateur';

  @override
  String get userTypeLabel => 'Type d\'utilisateur';

  @override
  String get confirmDeleteAccountMessage =>
      'Êtes-vous sûr de vouloir supprimer votre compte ? Cette action est irréversible.';

  @override
  String get confirmResetAllPasswordsMessage =>
      'Êtes-vous sûr de vouloir réinitialiser tous les mots de passe ?';

  @override
  String get confirmLeaveClassMessage =>
      'Êtes-vous sûr de vouloir quitter ce cours ?';

  @override
  String get confirmDeleteCommentMessage =>
      'Êtes-vous sûr de vouloir supprimer ce commentaire ?';

  @override
  String get confirmDeleteAllTeacherShiftsMessage =>
      'Êtes-vous sûr de vouloir supprimer tous les shifts de cet enseignant ?';

  @override
  String get confirmClaimShiftMessage =>
      'Êtes-vous sûr de vouloir prendre ce shift ?';

  @override
  String get confirmDeleteTemplateMessage =>
      'Êtes-vous sûr de vouloir supprimer ce modèle ?';

  @override
  String get confirmDeleteFormMessage =>
      'Êtes-vous sûr de vouloir supprimer ce formulaire ?';

  @override
  String get confirmDeleteDraftMessage =>
      'Êtes-vous sûr de vouloir supprimer ce brouillon ?';

  @override
  String get confirmBanShiftMessage =>
      'Êtes-vous sûr de vouloir bannir ce shift ?';

  @override
  String get confirmBanFormMessage =>
      'Êtes-vous sûr de vouloir bannir ce formulaire ?';
}
