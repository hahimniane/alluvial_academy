/// Script standalone pour générer les audits de décembre pour tous les enseignants
/// Usage: flutter run -d chrome --target=scripts/generate_audit_december.dart
/// ou: dart run scripts/generate_audit_december.dart (si configuré)

import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:alluwalacademyadmin/firebase_options.dart';
import 'package:alluwalacademyadmin/features/audit/services/teacher_audit_service.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

Future<void> main() async {
  print('🚀 Script de génération d\'audit pour décembre 2024');
  print('=' * 60);
  
  try {
    // Initialiser Flutter
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialiser Firebase
    print('\n📦 Initialisation de Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialisé');
    
    // Vérifier/Configurer l'authentification
    final auth = FirebaseAuth.instance;
    User? currentUser = auth.currentUser;
    
    if (currentUser == null) {
      print('\n🔐 Aucun utilisateur connecté.');
      print('   Pour générer les audits, une connexion admin est nécessaire.');
      print('');
      print('   Options:');
      print('   1. Connectez-vous d\'abord dans l\'application (laissez le script ouvert)');
      print('   2. OU entrez vos identifiants admin ci-dessous');
      print('');
      print('   Entrez votre email admin (ou appuyez sur Entrée pour utiliser l\'application):');
      stdout.write('   Email: ');
      final email = stdin.readLineSync();
      
      if (email != null && email.isNotEmpty) {
        stdout.write('   Mot de passe: ');
        final password = stdin.readLineSync();
        
        if (password != null && password.isNotEmpty) {
          print('   Connexion en cours...');
          try {
            final credential = await auth.signInWithEmailAndPassword(
              email: email.trim(),
              password: password,
            );
            currentUser = credential.user;
            print('   ✅ Connecté en tant que: ${currentUser?.email}');
          } catch (e) {
            print('   ❌ Erreur de connexion: $e');
            print('   Le script va tenter de continuer, mais peut échouer si les règles Firestore le bloquent.');
          }
        } else {
          print('   ⚠️  Pas de mot de passe fourni. Le script va tenter de continuer...');
        }
      } else {
        print('   ⚠️  Pas d\'email fourni.');
        print('   Astuce: Ouvrez l\'application dans un autre onglet, connectez-vous,');
        print('   puis relancez ce script - il utilisera votre session active.');
        print('');
        print('   Le script va tenter de continuer, mais peut échouer si les règles Firestore le bloquent.');
      }
    } else {
      print('✅ Utilisateur connecté: ${currentUser.email ?? currentUser.uid}');
    }
    
    // Récupérer tous les IDs des enseignants depuis les données du mois
    // (même logique que dans TeacherAuditService)
    print('\n📋 Extraction des IDs enseignants depuis les données de décembre 2024...');
    final firestore = FirebaseFirestore.instance;
    
    // Dates pour décembre 2024
    final startDate = DateTime(2024, 12, 1);
    final endDate = DateTime(2024, 12, 31, 23, 59, 59);
    final queryStart = Timestamp.fromDate(startDate);
    final queryEnd = Timestamp.fromDate(endDate);
    
    // Charger shifts, timesheets et forms en parallèle
    print('   Chargement des shifts, timesheets et forms...');
    final dataFutures = await Future.wait([
      firestore
          .collection('teaching_shifts')
          .where('shift_start', isGreaterThanOrEqualTo: queryStart)
          .where('shift_start', isLessThanOrEqualTo: queryEnd)
          .get(),
      firestore
          .collection('timesheet_entries')
          .where('created_at', isGreaterThanOrEqualTo: queryStart)
          .where('created_at', isLessThanOrEqualTo: queryEnd)
          .get(),
      firestore
          .collection('form_responses')
          .where('yearMonth', isEqualTo: '2024-12')
          .get(),
    ]);
    
    final shiftsSnapshot = dataFutures[0] as QuerySnapshot;
    final timesheetsSnapshot = dataFutures[1] as QuerySnapshot;
    final formsSnapshot = dataFutures[2] as QuerySnapshot;
    
    print('   ✅ ${shiftsSnapshot.docs.length} shifts, ${timesheetsSnapshot.docs.length} timesheets, ${formsSnapshot.docs.length} forms');
    
    // Extraire les IDs enseignants (même logique que dans le service)
    final teacherIds = <String>{};
    
    // Depuis shifts
    for (var doc in shiftsSnapshot.docs) {
      final data = doc.data();
      if (data != null) {
        final dataMap = data as Map<String, dynamic>;
        final teacherId = dataMap['teacher_id'] as String?;
        if (teacherId != null && teacherId.isNotEmpty) {
          teacherIds.add(teacherId);
        }
      }
    }
    
    // Depuis timesheets
    for (var doc in timesheetsSnapshot.docs) {
      final data = doc.data();
      if (data != null) {
        final dataMap = data as Map<String, dynamic>;
        final teacherId = dataMap['teacher_id'] as String?;
        if (teacherId != null && teacherId.isNotEmpty) {
          teacherIds.add(teacherId);
        }
      }
    }
    
    // Depuis forms
    for (var doc in formsSnapshot.docs) {
      final data = doc.data();
      if (data != null) {
        final dataMap = data as Map<String, dynamic>;
        final teacherId = dataMap['userId'] as String? ?? dataMap['submitted_by'] as String?;
        if (teacherId != null && teacherId.isNotEmpty) {
          teacherIds.add(teacherId);
        }
      }
    }
    
    final teacherIdsList = teacherIds.toList();
    print('✅ ${teacherIdsList.length} enseignants uniques trouvés');
    
    if (teacherIdsList.isEmpty) {
      print('❌ Aucun enseignant trouvé avec des données en décembre 2024. Arrêt du script.');
      exit(1);
    }
    
    // Afficher quelques IDs pour vérification
    print('\n📝 Exemples d\'IDs enseignants:');
    for (var i = 0; i < (teacherIdsList.length > 5 ? 5 : teacherIdsList.length); i++) {
      print('   - ${teacherIdsList[i]}');
    }
    if (teacherIdsList.length > 5) {
      print('   ... et ${teacherIdsList.length - 5} autres');
    }
    
    // Générer les audits pour décembre 2024
    const yearMonth = '2024-12';
    print('\n🎯 Génération des audits pour $yearMonth...');
    print('=' * 60);
    
    int completed = 0;
    int failed = 0;
    final failedTeachers = <String>[];
    
    final results = await TeacherAuditService.computeAuditsBatch(
      teacherIds: teacherIdsList,
      yearMonth: yearMonth,
      onProgress: (completedCount, total) {
        final percentage = (completedCount / total * 100).toStringAsFixed(1);
        stdout.write('\r📊 Progression: $completedCount/$total ($percentage%)');
        if (completedCount == total) {
          stdout.write('\n');
        }
      },
    );
    
    // Analyser les résultats
    print('\n' + '=' * 60);
    print('📊 RÉSULTATS:');
    print('=' * 60);
    
    for (final entry in results.entries) {
      if (entry.value) {
        completed++;
      } else {
        failed++;
        failedTeachers.add(entry.key);
      }
    }
    
    print('✅ Audits générés avec succès: $completed');
    print('❌ Audits échoués: $failed');
    
    if (failedTeachers.isNotEmpty) {
      print('\n⚠️  Enseignants avec échec:');
      for (final teacherId in failedTeachers) {
        print('   - $teacherId');
      }
    }
    
    print('\n' + '=' * 60);
    print('✅ Script terminé avec succès!');
    print('=' * 60);
    
    exit(0);
  } catch (e, stackTrace) {
    print('\n' + '=' * 60);
    print('❌ ERREUR:');
    print('=' * 60);
    print('$e');
    print('\nStack trace:');
    print(stackTrace);
    exit(1);
  }
}

