# Scripts de génération d'audit

## ⚠️ IMPORTANT: Meilleure méthode recommandée

**Pour éviter les problèmes d'authentification, utilisez plutôt la page de test intégrée dans l'application :**

1. Lancez l'application: `flutter run -d chrome`
2. Connectez-vous en tant qu'admin
3. Dans le menu sidebar, allez dans **System** → **Test Audit Génération**
4. Cliquez sur **"Générer les audits"**

Cette méthode est plus simple car elle partage automatiquement votre session de connexion.

---

## Script de génération d'audit pour décembre (Alternative)

Ce script permet de générer les audits pour tous les enseignants ayant des données en décembre 2024, mais **nécessite une authentification manuelle**.

### Utilisation

#### Option 1: Avec Flutter (recommandé)
```bash
flutter run -d chrome --target=scripts/generate_audit_december.dart
```

#### Option 2: Avec Dart directement (si configuré)
```bash
dart run scripts/generate_audit_december.dart
```

### Ce que fait le script

1. **Initialise Firebase** avec les options par défaut
2. **Extrait les IDs des enseignants** depuis les données de décembre 2024 (shifts, timesheets, forms)
3. **Génère les audits** pour tous ces enseignants en utilisant `TeacherAuditService.computeAuditsBatch`
4. **Affiche les résultats** avec le nombre de succès et d'échecs

### Avantages

- ✅ Pas besoin de lancer l'application complète
- ✅ Pas besoin de se connecter via l'interface
- ✅ Exécution rapide et directe
- ✅ Affichage des résultats en temps réel
- ✅ Liste des enseignants en échec si nécessaire

### Notes

- ⚠️ **Le script nécessite une authentification Firebase** pour accéder à Firestore
- Le script demande vos identifiants admin si vous n'êtes pas connecté
- ⚠️ Sur Flutter Web, `stdin.readLineSync()` peut ne pas fonctionner - dans ce cas, utilisez plutôt la page de test dans l'application
- Le script utilise les mêmes fonctions que l'application, donc les résultats sont identiques
- Les logs sont affichés dans la console
- Le script s'arrête automatiquement à la fin

### Problème d'authentification?

Si vous obtenez une erreur `[cloud_firestore/permission-denied]`, c'est parce que :

- **Les scripts JavaScript** (`.js`) utilisent **Firebase Admin SDK** avec un fichier `serviceAccountKey.json`, ce qui leur donne des privilèges administrateur et contourne les règles de sécurité Firestore.

- **Le script Dart** (`.dart`) utilise le **SDK Firebase client Flutter**, qui nécessite une authentification utilisateur et respecte les règles de sécurité Firestore.

**Solutions :**

1. **✅ RECOMMANDÉ :** Utilisez la page de test dans l'application (voir section ci-dessus) - elle partage votre session de connexion existante.

2. **Alternative :** Si vous devez absolument utiliser un script terminal, vous pouvez créer une version JavaScript qui utilise Firebase Admin SDK (comme `compute_audit_metrics.js`), mais cela nécessiterait de réimplémenter la logique d'audit en JavaScript.

3. **Pour les scripts JavaScript existants** : Assurez-vous d'avoir un fichier `serviceAccountKey.json` dans la racine du projet, ou exécutez `firebase login` pour utiliser les credentials par défaut.

