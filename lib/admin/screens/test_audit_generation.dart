/// Page de test pour générer les audits de décembre sans passer par l'UI complète
/// Accessible via une route de debug

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/teacher_audit_service.dart';
import '../../core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class TestAuditGenerationScreen extends StatefulWidget {
  const TestAuditGenerationScreen({super.key});

  @override
  State<TestAuditGenerationScreen> createState() => _TestAuditGenerationScreenState();
}

class _TestAuditGenerationScreenState extends State<TestAuditGenerationScreen> {
  bool _isRunning = false;
  String _status = 'Prêt';
  int _progress = 0;
  int _total = 0;
  int _completed = 0;
  int _failed = 0;
  final List<String> _failedTeachers = [];
  final List<String> _logs = [];

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
      if (_logs.length > 100) {
        _logs.removeAt(0); // Garder seulement les 100 derniers logs
      }
    });
  }

  Future<void> _generateAudits() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _status = 'Initialisation...';
      _progress = 0;
      _total = 0;
      _completed = 0;
      _failed = 0;
      _failedTeachers.clear();
      _logs.clear();
    });

    try {
      _addLog('🚀 Démarrage de la génération d\'audit pour décembre 2024');

      // Récupérer tous les IDs des enseignants depuis les données du mois
      _addLog('📋 Extraction des IDs enseignants...');
      final firestore = FirebaseFirestore.instance;

      // Dates pour décembre 2024
      final startDate = DateTime(2024, 12, 1);
      final endDate = DateTime(2024, 12, 31, 23, 59, 59);
      final queryStart = Timestamp.fromDate(startDate);
      final queryEnd = Timestamp.fromDate(endDate);

      // Charger shifts, timesheets et forms en parallèle
      _addLog('   Chargement des shifts, timesheets et forms...');
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

      _addLog('   ✅ ${shiftsSnapshot.docs.length} shifts, ${timesheetsSnapshot.docs.length} timesheets, ${formsSnapshot.docs.length} forms');

      // Extraire les IDs enseignants
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
      _addLog('✅ ${teacherIdsList.length} enseignants uniques trouvés');

      if (teacherIdsList.isEmpty) {
        setState(() {
          _status = 'Aucun enseignant trouvé';
          _isRunning = false;
        });
        _addLog('❌ Aucun enseignant trouvé avec des données en décembre 2024');
        return;
      }

      // Générer les audits
      _addLog('🎯 Génération des audits...');
      setState(() {
        _total = teacherIdsList.length;
        _status = 'Génération en cours...';
      });

      final results = await TeacherAuditService.computeAuditsBatch(
        teacherIds: teacherIdsList,
        yearMonth: '2024-12',
        onProgress: (completedCount, total) {
          setState(() {
            _progress = completedCount;
            _total = total;
          });
          _addLog('📊 Progression: $completedCount/$total');
        },
      );

      // Analyser les résultats
      setState(() {
        for (final entry in results.entries) {
          if (entry.value) {
            _completed++;
          } else {
            _failed++;
            _failedTeachers.add(entry.key);
          }
        }
        _status = 'Terminé';
        _isRunning = false;
      });

      _addLog('✅ Audits générés avec succès: $_completed');
      if (_failed > 0) {
        _addLog('❌ Audits échoués: $_failed');
        for (final teacherId in _failedTeachers) {
          _addLog('   - $teacherId');
        }
      }

      _addLog('✅ Génération terminée!');
    } catch (e, stackTrace) {
      setState(() {
        _status = 'Erreur';
        _isRunning = false;
      });
      _addLog('❌ ERREUR: $e');
      _addLog('Stack trace: $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.testGeNeRationAuditDe),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.statusStatus,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (_total > 0) ...[
                      SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _progress / _total,
                      ),
                      const SizedBox(height: 8),
                      Text(AppLocalizations.of(context)!.progressionProgressTotal),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoCard(
                            title: AppLocalizations.of(context)!.reUssis,
                            value: '$_completed',
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _InfoCard(
                            title: AppLocalizations.of(context)!.eChoueS,
                            value: '$_failed',
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isRunning ? null : _generateAudits,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          _isRunning ? 'Génération en cours...' : 'Générer les audits',
                          style: const TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        AppLocalizations.of(context)!.logs,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8.0),
                        child: _logs.isEmpty
                            ? Center(child: Text(AppLocalizations.of(context)!.aucunLogPourLeMoment))
                            : ListView.builder(
                                itemCount: _logs.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                                    child: Text(
                                      _logs[index],
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _InfoCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

