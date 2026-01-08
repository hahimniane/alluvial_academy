#!/bin/bash
# Script pour générer les audits de décembre 2024
# Usage: ./scripts/run_audit_december.sh

echo "🚀 Lancement du script de génération d'audit pour décembre 2024"
echo "============================================================"
echo ""

# Vérifier que Flutter est installé
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter n'est pas installé ou n'est pas dans le PATH"
    exit 1
fi

# Aller dans le répertoire du projet
cd "$(dirname "$0")/.." || exit 1

# Exécuter le script
echo "📦 Exécution du script..."
flutter run -d chrome --target=scripts/generate_audit_december.dart

