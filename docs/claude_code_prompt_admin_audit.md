# Prompt Claude Code — audit des admins (copier tout le bloc ci-dessous)

**Mémo découverte / MVP** (résumé exploitable, formulaires, time clock, script) : [`admin_audit_discovery_mvp_spec.md`](admin_audit_discovery_mvp_spec.md)

---

**Préface (langue & docs)** — Réponds en **français** pour la prose et les recommandations *à l’équipe* ; garde les **identifiants de code, chemins et noms de collections** en anglais. Ne crée pas de fichiers sous `docs/` sauf si l’utilisateur le demande explicitement (sinon résume dans ta réponse). Priorité : **MVP audit admin** d’abord, puis phase 2.

**Important — traduction dans l’app (pas de texte statique en UI)** : le site utilise **Flutter l10n** (`AppLocalizations`). Toute nouvelle chaîne **visible par l’utilisateur** dans le code Flutter doit passer par les fichiers ARB — au minimum [`lib/l10n/app_en.arb`](../lib/l10n/app_en.arb), [`lib/l10n/app_fr.arb`](../lib/l10n/app_fr.arb), [`lib/l10n/app_ar.arb`](../lib/l10n/app_ar.arb) — puis `flutter gen-l10n` (voir aussi [`CLAUDE.md`](../CLAUDE.md)). **Interdit** : `Text('...')`, `SnackBar(content: Text('...'))`, libellés de boutons, etc. en dur dans une seule langue. Les clés ARB en anglais (descriptions) ; les traductions dans chaque `.arb`.

---

**MISSION — Audit des admins Alluvial Academy (découverte + proposition)**

Tu travailles sur le dépôt Flutter/Firestore **alluvial_academy**. Ne pas supposer : lire le code et les données exportées.

**Contexte métier**  
Les leaders/admins partagent souvent sur WhatsApp leurs “Goals for Today / Daily Work Plan” et le CEO assigne des tâches ou demande des comptes rendus via des formulaires (facts finding, end of shift, etc.). On veut **mieux auditer le travail admin** : pas seulement “combien de formulaires”, mais **quoi**, **ponctualité**, **alignement objectifs ↔ exécution**, et éventuellement **remplacer ou compléter** le rituel WhatsApp par une feature in-app (todo / plan du jour + clôture type end-of-shift).

**État connu (à valider / compléter dans le code)**  

- `AdminAudit` / `AdminAuditService` : métriques mensuelles agrégées depuis `form_responses` + `tasks`.  
- `forms_ai_export/forms_ai_context.json` : définitions de formulaires (titres, `allowedRoles`, questions).  
- Tasks : collection `tasks`, modèle riche (assignation, overdue, firstOpenedAt).  
- Time clock : principalement lié aux `teaching_shifts` et enseignants.

**Tâches pour toi (ordre recommandé)**

1. **Cartographie formulaires “admin / coach / CEO”**  
   - Parser `forms_ai_export/forms_ai_context.json` (ou Firestore si besoin) : lister les formulaires dont `allowedRoles` contient `admin` et/ou `coach`, ou dont le titre/description évoque CEO/leaders/operations.  
   - Pour chaque formulaire prioritaire : but métier (description), fréquence implicite, **champs extractibles pour l’audit** (ex. champs texte “ce que j’ai fait”, checklist, dates, noms de personnes, self-assessment end of shift).  
   - Produire un tableau markdown (dans un fichier `docs/` **seulement si l’utilisateur le demande** — sinon résumer dans la réponse) : `templateId`, titre, rôles, champs clés pour scoring ou drill-down.

2. **Tasks et audit**  
   - Lire `Task` + `TaskService` : comment les tâches sont créées, filtrées pour admins (`quick_tasks_screen` filtre admin / `is_admin_teacher`).  
   - Proposer comment l’audit admin devrait combiner : tâches assignées par le CEO, auto-assignées, labels, sous-tâches — sans double comptage avec les formulaires.

3. **Shifts + time clock pour admins**  
   - Tracer si un utilisateur `admin` peut **clock in** depuis l’UI shift leaderboard / time clock ; identifier garde-fous (user_type, présence de shift, règles Firestore).  
   - Conclure : “admins peuvent / ne peuvent pas / partiellement” avec chemins de fichiers.

4. **Données réelles `form_responses`**  
   - S’appuyer sur `scripts/export_forms_ai_context.mjs` (options responses) ou écrire un **petit script Node** sous `scripts/` qui : pour un mois donné, échantillonne les réponses des admins, joint `templateId`/`formId` aux titres du JSON exporté, et sort des **statistiques** (par template : volume, champs les plus remplis, longueur texte moyenne) — pas besoin de LLM dans le script ; optionnel : tags regex / mots-clés pour “incident”, “parent”, “schedule”, etc.  
   - Respecter les secrets : `serviceAccountKey.json` déjà utilisé par les autres scripts ; ne pas committer de données personnelles brutes.

5. **Produit : “daily plan / todo” pour admins**  
   - Proposer 2–3 architectures : (A) réutiliser **Tasks** avec type ou label “daily_plan”, (B) nouvelle collection légère `admin_daily_checklist` avec items datés, (C) hybride + rappel vers formulaire “Daily End of Shift”.  
   - Lier au rituel WhatsApp décrit par l’utilisateur : saisie matin (objectifs), check en fin de journée, corrélation optionnelle avec soumission du formulaire end-of-shift.  
   - Indiquer où dans l’UI (`dashboard`, FAB, sidebar) avec cohérence Win11 existante.

6. **Inspiration teacher audit**  
   - Parcourir `teacher_audit_full`, onglets audit admin existants : quels patterns réutiliser (drill-down, exports, statuts) pour un **admin audit v2** sans copier les KPIs pédagogiques.

**Contraintes**  

- Changements de code : **minimal** dans un premier temps ; privilégier spec + script + liste de tickets.  
- Si tu modifies l’audit : prévoir migration des docs `admin_audits` et rétrocompatibilité UI.  
- **i18n obligatoire pour l’UI** : aucune chaîne utilisateur en dur ; ajouter les clés dans **tous** les `.arb` alignés (en / fr / ar au minimum), utiliser `AppLocalizations.of(context)!....`, exécuter `flutter gen-l10n` après édition des ARB.

**Livrables attendus**  

- Synthèse exécutive (1 page) : recommandation “MVP audit admin” vs “phase 2”.  
- Liste priorisée de formulaires + champs auditables.  
- Décision documentée : todo in-app vs Tasks existantes.  
- Si script : chemin, usage `node scripts/...`, et exemple de sortie anonymisée.

**Note séparée (hors scope audit mais contexte)** : un bug connu côté chat audit prof : le message automatique ne tombe pas toujours dans le fil “principal” — ne pas mélanger avec cette mission sauf si tu touches `TeacherAuditService` / `ChatService` pour la même PR.

---

## Référence rapide (repo)

| Élément | Fichiers |
|--------|----------|
| Modèle + service audit admin | `lib/core/models/admin_audit.dart`, `lib/core/services/admin_audit_service.dart` |
| UI audit admin | `lib/admin/screens/admin_audit_screen.dart` |
| Tasks | `lib/features/tasks/models/task.dart`, `lib/features/tasks/services/task_service.dart` |
| Time clock | `lib/features/time_clock/screens/time_clock_screen.dart` |
| Export formulaires | `forms_ai_export/forms_ai_context.json`, `scripts/export_forms_ai_context.mjs` |

Pour limiter le scope de la mission : retirer le point **5** (produit todo) et ne garder que cartographie + script + spec audit v2.
