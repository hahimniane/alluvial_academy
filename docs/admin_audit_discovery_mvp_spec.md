# Audit des admins — découvertes & proposition MVP (mémo contexte)

**Statut** : synthèse issue d’une session d’exploration ; le plan détaillé complet avait été **rejeté** côté produit tel quel — les **constats techniques** et la **piste MVP** restent valides comme référence pour la suite.

**Voir aussi** : prompt pour Claude Code [`claude_code_prompt_admin_audit.md`](claude_code_prompt_admin_audit.md) · script d’échantillonnage [`scripts/sample_admin_form_responses.mjs`](../scripts/sample_admin_form_responses.mjs).

---

## Résumé rapide (constats clés)

- **AdminAudit actuel** : 5 métriques plates (`formsSubmitted`, `totalTasksAssigned`, `tasksCompleted`, `tasksOverdue`, `tasksAcknowledged`) — pas de scoring, pas de drill-down, pas de workflow de revue.
- **Formulaires** : **14** formulaires admin / CEO repérés (3 avec `allowedRoles` explicite admin/coach, 11 par titre / description). Le plus critique pour la présence : **Daily End of Shift form — CEO** (quotidien).
- **Time clock** : les **admins purs** n’y ont **pas** accès dans la navigation rôle ; seuls les **admin_teacher** (double rôle, `user_type` teacher + `is_admin_teacher`) peuvent pointer. Vérifier `UserRoleService` et `ShiftTimesheetService` / `teaching_shifts` si le code évolue.
- **Tasks** : modèle riche (`labels`, `subTaskIds`, `firstOpenedAt`, etc.) — déjà partiellement exploité par `AdminAuditService`.
- **Script** : `node scripts/sample_admin_form_responses.mjs --month=YYYY-MM` pour stats réelles sur `form_responses` + jointure titres via `forms_ai_export/forms_ai_context.json`.

**Recommandation MVP (rappel)** : enrichir `AdminAudit` avec **breakdown par template**, **scoring de conformité** formulaires récurrents, **métriques tâches créées** — sans nouvelle collection. **Phase 2** : facteurs d’évaluation formels, daily plan in-app, review chain, etc.

---

## 1. Cartographie formulaires (admin / coach / CEO)

### Avec `allowedRoles` (admin / coach)

| # | Titre (abrégé) | templateId | Rôles | Fréquence (indicative) | Champs / intérêt audit |
|---|----------------|------------|-------|------------------------|-------------------------|
| 1 | All Bi-Weekly Coachees Performance | `0Nsvp0FofwFKa67mNVBX` | admin, coach | Bi-hebdo | Coachee, quizzes, devoirs, absences, retards, exam, midterm, schedule, rating performance |
| 2 | X Progress Summary Report | `0wxe4mCVTe3Y2ME67uEp` | admin, coach | Hebdo | Reçus parents, vérif. banque, soumissions zoom/finance/end-of-shift, vérif. schedule enseignants |
| 3 | Marketing Weekly Progress Summary Report | `3MB3jxkjcCdD11us9q4N` | admin, coach | Hebdo | Nombre end-of-shift, revues excuses, réunions hebdo, rating progrès |

### CEO / leaders (rôles implicites dans titre ou description)

| # | Titre | Fréquence | Métriques / contenu auditables |
|---|-------|-----------|--------------------------------|
| 4 | Daily End of Shift form — CEO | Quotidien | Objectifs shift, réalisations, tâches assignées / en retard, améliorations, revues formulaires, checkout |
| 5 | Forms/Facts Finding & Complains Report — leaders/CEO | Ad hoc | Plaintes, findings, actions correctives, escalade |
| 6 | Excuse Form for teachers & leaders | Ad hoc | Raison, impact projets, préavis, preuves |
| 7 | Monthly Penalty/Repercussion Record | Mensuel | Montant, raison, infractions |
| 8 | Task Assignments (For Leaders) — CEO | Ad hoc | Création / suivi tâches |
| 9 | Finance Weekly Update Form | Hebdo | Réconciliation, reçus, logs dépenses |
| 10 | PayCheck Update Form | Mensuel | Ajustements, déductions, bonus |
| 11 | CEO Weekly Progress Form | Hebdo | KPIs hebdo, perf équipe, initiatives |
| 12 | Monthly Review | Mensuel | Revues performance, recommandations |
| 13 | Award and Recognitions Tracker | Mensuel | Reconnaissances, incentives |
| 14 | IDEA SUGGESTION FORM — CEO | Ad hoc | Idées, améliorations système |

### Classification scoring (proposition)

- **Tier 1 — récurrents obligatoires (scoring auto)** : #4 Daily End of Shift CEO ; #1 bi-hebdo coachees ; #2, #3, #9, #11 rapports hebdo.
- **Tier 2 — conformité (comptage + drill-down)** : #6 excuses, #7 pénalités, #5 facts finding.
- **Tier 3 — contexte (info, scoring léger ou absent)** : #8, #10, #13, #14.

---

## 2. Tasks et audit

**Modèle** : `lib/features/tasks/models/task.dart` — `createdBy`, `assignedTo`, `dueDate`, `status`, `labels`, `subTaskIds`, `firstOpenedAt`, `completedAt`, `overdueDaysAtCompletion`, brouillons / archive, etc.

**Service** : `lib/features/tasks/services/task_service.dart` — ex. `getRoleBasedTasks()` : les admins voient toutes les tâches ; notifications via Cloud Functions ; opérations bulk.

**Déjà dans AdminAuditService** : totaux assignés, complétées, overdue, acknowledged (mois calendaire sur `dueDate`).

**Métriques MVP suggérées (ajout)** :

| Métrique | Source | Intérêt |
|----------|--------|---------|
| `tasksCreatedByAdmin` | `tasks.createdBy == adminId` | Initiative |
| `avgCompletionDays` | `completedAt - createdAt` | Vélocité |
| `tasksByLabel` | `labels[]` | Répartition domaine |
| `subTasksRatio` | `subTaskIds.length` vs total | Décomposition du travail |

**Double comptage formulaire ↔ tâche** : le formulaire “Task Assignments” peut documenter l’intention pendant que `tasks` documente l’exécution — **ne pas dédupliquer** en MVP ; à terme option `formResponseOrigin` sur `tasks`.

---

## 3. Shifts + time clock (admins)

**Conclusion** : time clock **non** destiné aux admins purs dans la config modules actuelle.

**Pistes de preuve à maintenir à jour dans le code** :

- `UserRoleService.getModulesForRole()` — liste `admin` / `super_admin` vs `teacher` (présence ou absence de `time_clock`).
- `ShiftTimesheetService` / queries sur `teaching_shifts` filtrées par `teacher_id`.

**Exception** : `is_admin_teacher` avec `user_type` teacher conserve l’accès time clock.

**Impact audit** : pas d’heures / ponctualité Firestore pour admins purs → **Daily End of Shift CEO** comme proxy principal de “présence” côté formulaires.

---

## 4. Script d’échantillonnage

**Fichier** : [`scripts/sample_admin_form_responses.mjs`](../scripts/sample_admin_form_responses.mjs)

```bash
node scripts/sample_admin_form_responses.mjs --month=2026-03
node scripts/sample_admin_form_responses.mjs --month=2026-03 --out=./tmp/admin_stats.json
```

**Rôle** : jointure `templateId` → titres (`forms_ai_export/forms_ai_context.json`), stats par template et par admin, tags regex optionnels (incident, parent, schedule, finance, etc.), éviter données perso brutes en sortie.

---

## 5. Inspiration teacher audit (`teacher_audit_full`)

**À réutiliser** : facteurs avec scores, formule type `(total/max)×100`, `isNotApplicable`, drill-down (`detailedForms`, `detailedTasks`), champs éditables + historique, export Excel (`AdvancedExcelExportService`).

**À ne pas copier** : KPIs pédagogiques, métriques timesheet pour admins purs, champs hardcodés à 0 (anti-pattern).

**Review chain (idée Phase 2 admin)** : simplifié par rapport au prof — ex. `pending → reviewed → completed` (un niveau CEO).

---

## 6. MVP vs phase 2 (proposition — non validée en plan unique)

### MVP (cible ~2–3 semaines)

1. **`AdminAudit`** (`lib/core/models/admin_audit.dart`) : `formsBreakdown` (map template → count), `tasksCreatedByAdmin`, `avgTaskCompletionDays`, scores (`formComplianceScore`, `taskEfficiencyScore`, `overallScore`), `ceoNotes` éditable.
2. **`AdminAuditService.generateAdminAudits()`** : agrégation breakdown ; conformité Tier 1 (ratio soumis / attendu) ; métriques tâches créées / vélocité.
3. **UI** [`admin_audit_screen.dart`](../lib/admin/screens/admin_audit_screen.dart) : scores, drill-down formulaires par template, drill-down tâches créées vs assignées vs complétées, notes CEO.
4. **i18n** : toutes nouvelles chaînes dans `app_en.arb` / `app_fr.arb` / `app_ar.arb` + `flutter gen-l10n`.
5. **Migration** : `SetOptions(merge: true)` — champs manquants = défauts côté modèle.

### Phase 2

- Facteurs 0–5 + review chain formelle.
- Daily plan in-app (recommandation : **Tasks + label réservé `daily_plan`**) ; widget dashboard ; corrélation fin de journée avec Daily End of Shift.
- Export Excel admin dédié ; notifications formulaires manquants.

---

## 7. Décision TODO in-app

**Recommandation enregistrée** : réutiliser **Tasks** avec label **`daily_plan`** (pas de nouvelle collection en phase 2) ; FAB rapide ; filtre UI ; lien optionnel à la soumission Daily End of Shift.

---

## Fichiers critiques (MVP)

| Fichier | Modification envisagée |
|---------|-------------------------|
| `lib/core/models/admin_audit.dart` | Nouveaux champs + sérialisation |
| `lib/core/services/admin_audit_service.dart` | Calculs breakdown / scores |
| `lib/admin/screens/admin_audit_screen.dart` | UI scores, drill-down, i18n |
| `lib/l10n/app_*.arb` | Clés |
| `scripts/sample_admin_form_responses.mjs` | Déjà présent — valider sur un mois réel |

## Checklist de vérification

1. Script : sortie cohérente pour un mois donné.
2. Génération audit UI → documents `admin_audits` enrichis dans Firestore.
3. Drill-down admin → breakdown par template.
4. FR / AR : pas de chaînes UI en dur.
5. Anciens docs `admin_audits` : valeurs par défaut, pas de régression.
