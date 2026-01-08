/// Script standalone pour générer les audits de décembre 2024
/// Ce script peut être exécuté avec: dart scripts/generate_audit_december_standalone.dart
/// NOTE: Nécessite que Firebase soit configuré pour Dart standalone (pas Flutter)

import 'dart:io';

Future<void> main() async {
  print('⚠️  Ce script nécessite d\'être exécuté via Flutter');
  print('Utilisez plutôt: flutter run -d chrome --target=scripts/generate_audit_december.dart');
  print('');
  print('OU créez une fonction de test dans l\'application elle-même.');
  exit(1);
}

