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
  String get navChat => 'Messages';

  @override
  String get navForms => 'Formulaires';

  @override
  String get navJobs => 'Emplois';

  @override
  String get navClasses => 'Classes';

  @override
  String get navNotify => 'Notifier';

  @override
  String get navUsers => 'Utilisateurs';

  @override
  String get navTasks => 'Tâches';

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
  String get shiftReportIssue => 'Signaler un problème';

  @override
  String get shiftDate => 'Date';

  @override
  String get shiftTime => 'Heure';

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
  String get chatRecentChats => 'Conversations récentes';

  @override
  String get chatMyContacts => 'Mes contacts';

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
  String get timesheetTotalHours => 'Heures totales';

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
  String userNewPasswordFor(String name) {
    return 'Nouveau mot de passe pour $name';
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
  String userPromoteConfirm(String name) {
    return 'Êtes-vous sûr de vouloir promouvoir $name administrateur ?';
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
    return 'Êtes-vous sûr de vouloir supprimer définitivement $name ?';
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
  String get userDeletedSuccess => 'Utilisateur supprimé avec succès';

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
}
