# Guide de Migration des Données Utilisateur

## 📋 Contexte du Problème

Quand un compte utilisateur est supprimé dans Firebase Auth puis recréé:
- Un **nouveau UID** est généré pour le nouvel compte
- Les **anciennes données** (shifts, timesheets, formulaires, etc.) font toujours référence à l'**ancien UID**
- L'utilisateur ne voit plus ses données car elles ne correspondent plus à son nouvel UID

## 🎯 Cas Spécifique: ALIOU DIALLO

- **Email:** aliou9716@gmail.com
- **Nom:** ALIOU DIALLO (Prénom: Aliou)
- **Rôle:** Professeur + Admin

## 🛠️ Scripts Disponibles

### 1. Script de Scan Automatique (`migrate_user_data.js`)

Ce script scanne automatiquement toutes les collections pour trouver les données associées à l'utilisateur.

```bash
# Aller dans le dossier du projet
cd D:\alluvial_academy

# Mode audit (ne modifie rien, montre ce qui serait fait)
node scripts/migrate_user_data.js

# Mode exécution (applique les modifications)
node scripts/migrate_user_data.js --execute
```

### 2. Script de Migration Directe (`migrate_user_by_uid.js`)

Si vous connaissez déjà l'ancien et le nouvel UID, utilisez ce script:

```bash
# Mode audit
node scripts/migrate_user_by_uid.js ANCIEN_UID NOUVEAU_UID

# Mode exécution
node scripts/migrate_user_by_uid.js ANCIEN_UID NOUVEAU_UID --execute
```

**Exemple:**
```bash
node scripts/migrate_user_by_uid.js xYz123OldUid aBc456NewUid --execute
```

## 📊 Collections Affectées

Le script parcourt et met à jour les collections suivantes:

| Collection | Champs mis à jour |
|------------|-------------------|
| `users` | `uid` |
| `teaching_shifts` | `teacher_id`, `created_by_admin_id` |
| `timesheet_entries` | `teacher_id`, `teacherId` |
| `form_responses` | `userId` |
| `form_drafts` | `createdBy` |
| `tasks` | `createdBy`, `assignedTo[]` |
| `teacher_profiles` | `user_id`, document ID |
| `shift_modifications` | `modified_by`, `teacher_id` |
| `notifications` | `userId`, `recipientId`, `senderId` |
| `chat_messages` | `senderId`, `receiverId` |

## 🔍 Comment Trouver les UIDs

### Trouver l'ancien UID

1. Dans la **Console Firebase** > **Firestore**
2. Allez dans une collection comme `teaching_shifts` ou `timesheet_entries`
3. Cherchez des documents avec:
   - `teacher_email` = `aliou9716@gmail.com`
   - OU `teacher_name` contenant "ALIOU DIALLO"
4. Notez la valeur du champ `teacher_id` - c'est l'ancien UID

### Trouver le nouveau UID

1. Dans la **Console Firebase** > **Authentication**
2. Recherchez l'utilisateur par email: `aliou9716@gmail.com`
3. L'UID affiché est le nouveau UID

**Alternative via Firestore:**
1. Collection `users`
2. Filtrez par `e-mail` == `aliou9716@gmail.com`
3. Le document ID est l'UID

## 📝 Procédure Complète Recommandée

### Étape 1: Vérification préliminaire

```bash
# Lancer l'audit pour voir les données existantes
node scripts/migrate_user_data.js
```

Vérifiez le rapport pour:
- L'ancien UID trouvé dans les documents
- Le nouvel UID du compte recréé
- Le nombre de documents à migrer par collection

### Étape 2: Sauvegarde (optionnel mais recommandé)

Dans Firebase Console:
1. Firestore > Export data
2. Exportez les collections affectées

### Étape 3: Exécuter la migration

```bash
# Migration automatique basée sur l'email
node scripts/migrate_user_data.js --execute

# OU migration directe si vous avez les UIDs
node scripts/migrate_user_by_uid.js ANCIEN_UID NOUVEAU_UID --execute
```

### Étape 4: Vérification post-migration

1. Connectez-vous avec le compte d'ALIOU DIALLO
2. Vérifiez:
   - ✅ Les shifts apparaissent dans son emploi du temps
   - ✅ Les timesheets historiques sont visibles
   - ✅ Les réponses aux formulaires sont liées
   - ✅ Les tâches assignées sont visibles
   - ✅ Le profil enseignant est accessible

## ⚠️ Notes Importantes

1. **Toujours faire un dry run d'abord** - N'exécutez jamais `--execute` sans avoir fait un audit préalable

2. **Les documents users** - Si l'ancien document user existe toujours, il sera supprimé après migration vers le nouveau

3. **Champs de traçabilité** - Les scripts ajoutent:
   - `_migrated_from_uid`: L'ancien UID
   - `_migrated_at`: Date/heure de migration

4. **Cas particuliers**:
   - `teacher_profiles` a son document ID = UID, donc le document est déplacé
   - `tasks.assignedTo` est un tableau, traité correctement

## 🆘 En cas de problème

1. Les documents migrés contiennent `_migrated_from_uid` - vous pouvez identifier ce qui a été modifié
2. Si besoin de rollback, utilisez le script en inversant old/new UIDs

## 📞 Support

Si vous rencontrez des problèmes avec cette migration, vérifiez:
1. Que `serviceAccountKey.json` existe dans la racine du projet
2. Que vous avez les droits d'écriture sur Firestore
3. Les logs d'erreur dans la console

