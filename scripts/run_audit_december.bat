@echo off
REM Script pour générer les audits de décembre 2024 (Windows)
REM Usage: scripts\run_audit_december.bat

echo 🚀 Lancement du script de génération d'audit pour décembre 2024
echo ============================================================
echo.

REM Vérifier que Flutter est installé
where flutter >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Flutter n'est pas installé ou n'est pas dans le PATH
    exit /b 1
)

REM Aller dans le répertoire du projet
cd /d "%~dp0\.."

REM Exécuter le script
echo 📦 Exécution du script...
flutter run -d chrome --target=scripts/generate_audit_december.dart

