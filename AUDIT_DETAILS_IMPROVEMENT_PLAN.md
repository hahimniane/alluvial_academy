# Plan d'Amélioration des Détails d'Audit

## Objectif
Améliorer l'affichage et la gestion des détails d'audit avec focus sur les shifts orphelins et forms non linked, permettant un link manuel optimal.

---

## Phase 1: Restructuration des Données Affichées

### 1.1 Créer une vue unifiée Shifts + Forms
**Fichier**: `lib/admin/screens/admin_audit_screen.dart`

**Nouvelle structure de données**:
```dart
class _AuditDayItem {
  final DateTime date; // Jour du mois
  final List<_ShiftItem> shifts; // Shifts de ce jour
  final List<_FormItem> forms; // Forms de ce jour
}

class _ShiftItem {
  final String shiftId;
  final DateTime date;
  final String studentName; // Nom(s) de(s) étudiant(s)
  final String subject;
  final String status; // completed, missed, etc.
  final bool hasForm; // Si un form est lié
  final String? linkedFormId;
  final double scheduledHours;
  final double workedHours;
}

class _FormItem {
  final String formId;
  final DateTime? submissionDate;
  final String? dayOfWeek; // Depuis le form (champ "Class Day")
  final bool isLinked;
  final String? linkedShiftId;
  final String? linkedShiftTitle;
  final double durationHours; // Depuis le form
}
```

### 1.2 Regrouper par jour du mois
- Parcourir `detailedShifts` et `detailedForms`
- Grouper par jour (1-31)
- Créer `List<_AuditDayItem>` ordonnée chronologiquement

---

## Phase 2: Nouvelle Interface d'Affichage

### 2.1 Section "Forms Compliance Summary"
**Emplacement**: En haut de l'audit detail modal

**Afficher**:
- **Forms Planifiés**: `totalClassesCompleted + totalClassesMissed`
- **Forms Soumis**: `readinessFormsSubmitted`
- **Forms Manquants**: Calculé (planifiés - soumis)
- **Pénalité Unitäre**: Input pour saisir le montant
- **Total Pénalité**: `formsManquants × pénalitéUnitäre`
- **Bouton "Appliquer Pénalité"**: Met à jour le `paymentSummary`

### 2.2 Section "Shifts & Forms par Jour"
**Affichage**: Liste chronologique jour par jour

**Pour chaque jour**:
```
📅 Jour 15 Décembre
  ├─ 🎓 Shift: Aliou Diallo - Quran - Abdoulaye Barry (10:00-11:00)
  │    └─ ✅ Form soumis (Dec 15, 10:30 AM)
  ├─ 🎓 Shift: Aliou Diallo - Arabic - Mamadou (14:00-15:00)
  │    └─ ⚠️ PAS DE FORM (Orphelin)
  │        [Bouton: Link Form]
  └─ 📝 Form: Day=Lundi, Soumis: Dec 15, 8:00 AM
       └─ ⚠️ PAS DE SHIFT (Non linked)
           [Dropdown: Sélectionner Shift Orphelin]
           [Bouton: Link Shift]
```

**Composants**:
- `_DaySection`: Container avec date et liste des items
- `_ShiftRow`: Affichage shift avec status form
- `_FormRow`: Affichage form avec status link

---

## Phase 3: Modal de Détails de Form (Icône Œil)

### 3.1 Remplacer expansion par icône
**Fichier**: `_AdminFormCard`

**Changement**:
- ❌ Retirer `_isExpanded` et expansion inline
- ✅ Ajouter `IconButton` avec `Icons.visibility_outlined`
- ✅ Au clic: Ouvrir `_FormDetailsModal`

### 3.2 Créer `_FormDetailsModal`
**Composant**: `DraggableScrollableSheet` ou `Dialog`

**Contenu**:
- Header: "Form Details" + Bouton fermer
- Section: Informations générales (Date, Shift linked, etc.)
- Section: Toutes les réponses du form avec labels
- Section: Actions (Link Shift, Voir Shift, etc.)

**Style**: Fluide, moderne, scrollable

---

## Phase 4: Fonctionnalité de Link Manuel

### 4.1 Identifier Shifts Orphelins et Forms Non Linked
**Logique**:
```dart
// Shifts orphelins = shifts complétés sans form linked
final orphanShifts = detailedShifts.where((s) => 
  s['status'] in ['completed', 'fullyCompleted'] && 
  !_hasLinkedForm(s['id'])
).toList();

// Forms non linked = forms sans shiftId ou shiftId vide/null
final unlinkedForms = detailedForms.where((f) => 
  f['shiftId'] == null || f['shiftId'] == ''
).toList();
```

### 4.2 Interface de Link
**Pour Form Non Linked**:
- Dropdown avec shifts orphelins disponibles (filtrés par date proche)
- Affichage: "Shift: [Subject] - [Student] - [Date/Time]"
- Bouton "Link" → Appelle `linkFormToShift(formId, shiftId)`

**Pour Shift Orphelin**:
- Bouton "Link Form"
- Ouvrir dialog avec liste des forms non linked (filtrés par date proche)
- Sélection → Link

### 4.3 Service de Link
**Nouveau**: `TeacherAuditService.linkFormToShift()`

**Fonctions**:
```dart
static Future<bool> linkFormToShift({
  required String formId,
  required String shiftId,
}) async {
  // 1. Mettre à jour form_responses avec shiftId
  // 2. Recalculer l'audit si nécessaire
  // 3. Refresh UI
}
```

---

## Phase 5: Application de Pénalité

### 5.1 Interface de Pénalité
**Dans Forms Compliance Summary**:
```
┌─────────────────────────────────────────┐
│ Forms Compliance                        │
├─────────────────────────────────────────┤
│ Planifiés: 32                           │
│ Soumis: 30                              │
│ Manquants: 2                            │
│                                         │
│ Pénalité unitaire: [$____]             │
│ Total pénalité: $10.00                  │
│                                         │
│ [Appliquer Pénalité]                    │
└─────────────────────────────────────────┘
```

### 5.2 Calcul et Application
**Service**: `TeacherAuditService.applyFormPenalty()`

**Logique**:
1. Calculer `missingForms = planifiés - soumis`
2. `totalPenalty = missingForms × pénalitéUnitäre`
3. Mettre à jour `paymentSummary.totalPenalties`
4. Recalculer `paymentSummary.totalNetPayment`

---

## Phase 6: Optimisations

### 6.1 Performance
- **Caching**: Mettre en cache les labels de forms (déjà fait)
- **Lazy Loading**: Charger les détails de forms seulement au clic sur l'icône
- **Batch Operations**: Traiter les links en batch si possible

### 6.2 UX
- **Feedback Visuel**: 
  - Animation lors du link
  - Toast de confirmation
  - Loading states
- **Tri et Filtres**:
  - Tri par date (déjà fait)
  - Filtre par status (Orphelins, Linked, etc.)

---

## Structure de Fichiers Modifiés

1. **lib/admin/screens/admin_audit_screen.dart**
   - Ajouter `_AuditDayItem`, `_ShiftItem`, `_FormItem` classes
   - Refactoriser `_AuditDetailSheet` pour nouveau layout
   - Créer `_FormsComplianceSummary` widget
   - Créer `_FormDetailsModal` widget
   - Créer `_DaySection`, `_ShiftRow`, `_FormRow` widgets
   - Ajouter logique de link manuel

2. **lib/core/services/teacher_audit_service.dart**
   - Ajouter `linkFormToShift()` method
   - Ajouter `applyFormPenalty()` method

3. **lib/core/models/teacher_audit_full.dart**
   - Ajouter champ `formPenaltyPerMissing` (optionnel)

---

## Ordre d'Implémentation Recommandé

1. ✅ **Phase 1**: Restructuration des données
2. ✅ **Phase 2.1**: Forms Compliance Summary
3. ✅ **Phase 3**: Modal de détails (icône œil)
4. ✅ **Phase 2.2**: Nouveau layout par jour
5. ✅ **Phase 4**: Fonctionnalité de link
6. ✅ **Phase 5**: Application de pénalité
7. ✅ **Phase 6**: Optimisations finales

---

## Tests à Effectuer

- [ ] Affichage correct de tous les shifts et forms
- [ ] Identification correcte des orphelins
- [ ] Link manuel fonctionne (form ↔ shift)
- [ ] Calcul de pénalité correct
- [ ] Performance acceptable (pas de lag)
- [ ] UX fluide (animations, feedback)

