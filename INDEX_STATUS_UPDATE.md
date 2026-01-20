# 🔥 Firestore Index Status Update

## Current Status

### ✅ Index 1: `form_responses` - **EN COURS DE CONSTRUCTION**
- **Status**: Building (en attente)
- **Action**: Attendre que l'index soit terminé (1-5 minutes)
- **Vérifier**: [Firebase Console → Indexes](https://console.firebase.google.com/project/alluwal-academy/firestore/indexes)
- **Note**: L'ordre des champs dans la requête a été corrigé pour correspondre à l'index

### ⚠️ Index 2: `teaching_shifts` - **À CRÉER**
- **Status**: Non créé
- **Action**: Créer l'index maintenant
- **Lien direct**: [Créer l'index teaching_shifts](https://console.firebase.google.com/v1/r/project/alluwal-academy/firestore/indexes?create_composite=Cldwcm9qZWN0cy9hbGx1d2FsLWFjYWRlbXkvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3RlYWNoaW5nX3NoaWZ0cy9pbmRleGVzL18QARoNCgl0ZWFjaGVySWQQARoPCgtzaGlmdF9zdGFydBACGgwKCF9fbmFtZV9fEAI)

---

## 🔧 Corrections Apportées

### 1. Ordre des champs dans la requête
**Problème**: L'ordre des `where` clauses ne correspondait pas à l'ordre des champs dans l'index.

**Avant** (incorrect):
```dart
.where('userId', isEqualTo: user.uid)
.where('formType', isEqualTo: 'daily')
.where('submittedAt', isGreaterThanOrEqualTo: timestamp)
```

**Après** (correct):
```dart
.where('formType', isEqualTo: 'daily') // Premier champ dans l'index
.where('userId', isEqualTo: user.uid) // Deuxième champ dans l'index
.where('submittedAt', isGreaterThanOrEqualTo: timestamp) // Troisième champ dans l'index
```

**Règle importante**: L'ordre des champs dans les clauses `where` doit **exactement** correspondre à l'ordre des champs dans l'index composite.

---

## 📋 Index Configurations

### Index 1: form_responses
```json
{
  "collectionGroup": "form_responses",
  "fields": [
    { "fieldPath": "formType", "order": "ASCENDING" },
    { "fieldPath": "userId", "order": "ASCENDING" },
    { "fieldPath": "submittedAt", "order": "ASCENDING" }
  ]
}
```

**Requête correspondante:**
```dart
.where('formType', isEqualTo: 'daily')
.where('userId', isEqualTo: userId)
.where('submittedAt', isGreaterThanOrEqualTo: timestamp)
.orderBy('submittedAt', descending: true)
```

### Index 2: teaching_shifts
```json
{
  "collectionGroup": "teaching_shifts",
  "fields": [
    { "fieldPath": "teacherId", "order": "ASCENDING" },
    { "fieldPath": "shift_start", "order": "ASCENDING" }
  ]
}
```

**Requête correspondante:**
```dart
.where('teacherId', isEqualTo: userId)
.where('shift_start', isGreaterThanOrEqualTo: timestamp)
.orderBy('shift_start', descending: true)
```

---

## ✅ Actions Immédiates

1. **Créer l'index teaching_shifts**:
   - Cliquez sur le lien ci-dessus
   - Vérifiez la configuration
   - Cliquez "Create Index"
   - Attendez 1-5 minutes

2. **Vérifier le statut de l'index form_responses**:
   - Allez dans [Firebase Console → Indexes](https://console.firebase.google.com/project/alluwal-academy/firestore/indexes)
   - Cherchez l'index pour `form_responses`
   - Attendez que le statut passe à "Enabled" (coche verte)

3. **Tester l'application**:
   - Une fois les deux index "Enabled"
   - Redémarrez l'application
   - Testez la navigation vers les formulaires
   - Vérifiez qu'il n'y a plus d'erreurs dans la console

---

## 🐛 Erreurs Attendues (Temporaires)

### Erreur 1: "Index is currently building"
```
The query requires an index. That index is currently building and cannot be used yet.
```
**Solution**: Attendre que l'index soit terminé (statut "Enabled")

### Erreur 2: "The query requires an index"
```
The query requires an index. You can create it here: [URL]
```
**Solution**: Créer l'index en cliquant sur le lien fourni

---

## 📝 Notes Techniques

### Pourquoi l'ordre des champs est important ?
Firestore exige que l'ordre des champs dans les clauses `where` corresponde exactement à l'ordre des champs dans l'index composite. C'est une limitation de Firestore pour optimiser les performances.

### Ordre correct:
1. **Champs d'égalité** (`isEqualTo`) en premier
2. **Champs de comparaison** (`isGreaterThanOrEqualTo`, etc.) après
3. **orderBy** doit utiliser le dernier champ de l'index (ou un champ qui n'est pas dans l'index)

### Exemple:
```dart
// ✅ CORRECT - Ordre correspond à l'index
.where('formType', isEqualTo: 'daily')      // Champ 1 de l'index
.where('userId', isEqualTo: userId)         // Champ 2 de l'index
.where('submittedAt', isGreaterThanOrEqualTo: timestamp) // Champ 3 de l'index
.orderBy('submittedAt', descending: true)   // Utilise le dernier champ

// ❌ INCORRECT - Ordre ne correspond pas
.where('userId', isEqualTo: userId)         // Devrait être après formType
.where('formType', isEqualTo: 'daily')
```

---

**Dernière mise à jour**: Après correction de l'ordre des champs dans les requêtes  
**Status**: ⏳ En attente de la fin de construction des index
