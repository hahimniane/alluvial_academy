# 🚀 Déployer les Index Firestore depuis le Projet

## Méthode Rapide

### Option 1: Script Node.js (Recommandé)
```bash
node scripts/deploy_firestore_indexes.js
```

### Option 2: Script Bash (Linux/Mac/Git Bash)
```bash
chmod +x scripts/setup_firestore_indexes.sh
./scripts/setup_firestore_indexes.sh
```

### Option 3: Firebase CLI Direct
```bash
firebase deploy --only firestore:indexes
```

---

## Prérequis

### 1. Installer Firebase CLI
```bash
npm install -g firebase-tools
```

### 2. Se connecter à Firebase
```bash
firebase login
```

### 3. Vérifier le projet
```bash
firebase use alluwal-academy
```

---

## Fichiers Configurés

✅ **firestore.indexes.json** - Définition des index (déjà créé)
✅ **firebase.json** - Configuration Firebase (déjà configuré)

---

## Index à Déployer

### 1. Index `form_responses`
- **Collection**: `form_responses`
- **Champs**: `formType`, `userId`, `submittedAt`
- **Usage**: Vérifier les soumissions de formulaires

### 2. Index `teaching_shifts`
- **Collection**: `teaching_shifts`
- **Champs**: `teacherId`, `shift_start`
- **Usage**: Sélectionner les shifts pour les rapports quotidiens

---

## Après le Déploiement

1. **Attendre 1-5 minutes** pour que les index se construisent
2. **Vérifier le statut**:
   - [Firebase Console → Indexes](https://console.firebase.google.com/project/alluwal-academy/firestore/indexes)
   - Chercher le statut "Enabled" (coche verte)
3. **Tester l'application**:
   - Redémarrer l'app Flutter
   - Naviguer vers les formulaires
   - Vérifier qu'il n'y a plus d'erreurs

---

## Dépannage

### Erreur: "Firebase CLI not found"
```bash
npm install -g firebase-tools
```

### Erreur: "Not logged in"
```bash
firebase login
```

### Erreur: "Project not found"
```bash
firebase use alluwal-academy
```

### Erreur: "Index is still building"
- Attendre quelques minutes
- Vérifier dans la console Firebase

---

## Vérification

Après le déploiement, vous devriez voir:
```
✅ Deploy complete!
```

Et dans la console Firebase:
- Statut: "Building" → "Enabled" (après quelques minutes)
- 2 index créés

---

**Dernière mise à jour**: Après correction de l'ordre des champs  
**Status**: ✅ Prêt à déployer
