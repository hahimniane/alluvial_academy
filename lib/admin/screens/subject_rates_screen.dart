import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/models/teacher_audit_full.dart';
import '../../core/services/teacher_audit_service.dart';
import '../../core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Admin screen for managing subject hourly rates
class SubjectRatesScreen extends StatefulWidget {
  const SubjectRatesScreen({super.key});

  @override
  State<SubjectRatesScreen> createState() => _SubjectRatesScreenState();
}

class _SubjectRatesScreenState extends State<SubjectRatesScreen> {
  List<SubjectHourlyRate> _rates = [];
  bool _isLoading = true;
  bool _isRefreshing = false; // Prevent multiple simultaneous refreshes

  // Default subjects if none exist
  // English/Maths: 5$ | Quran/Islam/Arabic: 4$
  static const List<Map<String, dynamic>> _defaultSubjects = [
    {'id': 'quran', 'name': 'Quran Studies', 'rate': 4.0, 'color': Color(0xff10B981)},
    {'id': 'arabic', 'name': 'Arabic Language', 'rate': 4.0, 'color': Color(0xff3B82F6)},
    {'id': 'english', 'name': 'English', 'rate': 5.0, 'color': Color(0xff2563EB)},
    {'id': 'maths', 'name': 'Mathematics', 'rate': 5.0, 'color': Color(0xff059669)},
    {'id': 'science', 'name': 'Science', 'rate': 5.0, 'color': Color(0xff7C3AED)},
    {'id': 'programming', 'name': 'Programming', 'rate': 5.0, 'color': Color(0xff0EA5E9)},
    {'id': 'hadith', 'name': 'Hadith Studies', 'rate': 4.0, 'color': Color(0xffF59E0B)},
    {'id': 'fiqh', 'name': 'Islamic Jurisprudence', 'rate': 4.0, 'color': Color(0xff8B5CF6)},
    {'id': 'tutoring', 'name': 'Tutoring', 'rate': 4.0, 'color': Color(0xffD97706)},
  ];

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  Future<void> _loadRates() async {
    // Prevent multiple simultaneous calls
    if (_isRefreshing || _isLoading) return;
    
    setState(() {
      if (_rates.isEmpty) {
        _isLoading = true;
      } else {
        _isRefreshing = true;
      }
    });

    try {
      final rates = await TeacherAuditService.getSubjectRates();
      if (mounted) {
        setState(() {
          _rates = rates;
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _showEditDialog(SubjectHourlyRate? rate, {Map<String, dynamic>? defaultSubject}) async {
    final nameController = TextEditingController(text: rate?.subjectName ?? defaultSubject?['name'] ?? '');
    final hourlyRateController = TextEditingController(
        text: (rate?.hourlyRate ?? defaultSubject?['rate'] ?? 15.0).toStringAsFixed(2));
    final penaltyController =
        TextEditingController(text: (rate?.penaltyRatePerMissedClass ?? 5.0).toStringAsFixed(2));
    final bonusController =
        TextEditingController(text: (rate?.bonusRatePerExcellence ?? 10.0).toStringAsFixed(2));

    final subjectId = rate?.subjectId ?? defaultSubject?['id'] ?? '';

    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            rate != null ? 'Edit Rate: ${rate.subjectName}' : 'Add Subject Rate',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (rate == null && defaultSubject == null)
                  TextField(
                    controller: nameController,
                    enabled: !isSaving,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.subjectName,
                      hintText: AppLocalizations.of(context)!.eGMathematics,
                    ),
                  ),
                SizedBox(height: 16),
                TextField(
                  controller: hourlyRateController,
                  enabled: !isSaving,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.hourlyRate,
                    prefixText: '\$ ',
                    hintText: '15.00',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: penaltyController,
                  enabled: !isSaving,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.penaltyPerMissedClass,
                    prefixText: '\$ ',
                    hintText: '5.00',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: bonusController,
                  enabled: !isSaving,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.bonusPerExcellence,
                    prefixText: '\$ ',
                    hintText: '10.00',
                  ),
                ),
                if (isSaving) ...[
                  const SizedBox(height: 16),
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: Text(AppLocalizations.of(context)!.commonCancel),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);

                      try {
                        final id = subjectId.isNotEmpty
                            ? subjectId
                            : nameController.text.toLowerCase().replaceAll(' ', '_');
                        final newRate = double.tryParse(hourlyRateController.text) ?? 15.0;
                        final newPenalty = double.tryParse(penaltyController.text) ?? 5.0;
                        final newBonus = double.tryParse(bonusController.text) ?? 10.0;

                        await TeacherAuditService.updateSubjectRate(
                          subjectId: id,
                          hourlyRate: newRate,
                          penaltyRate: newPenalty,
                          bonusRate: newBonus,
                        );

                        if (mounted) {
                          Navigator.pop(dialogContext);
                          // Debounce the refresh to avoid multiple rapid calls
                          Future.microtask(() {
                            if (mounted) {
                              _loadRates();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(AppLocalizations.of(context)!.rateUpdatedSuccessfully),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          });
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                foregroundColor: Colors.white,
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(AppLocalizations.of(context)!.commonSave),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.subjectHourlyRates,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRates,
            tooltip: AppLocalizations.of(context)!.commonRefresh,
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: Row(
                  children: [
                    const Icon(Icons.speed, size: 20),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.of(context)!.setDefaultRates, style: GoogleFonts.inter()),
                  ],
                ),
                onTap: () => Future.delayed(
                  const Duration(milliseconds: 100),
                  () => _setDefaultRates(),
                ),
              ),
              PopupMenuItem(
                child: Row(
                  children: [
                    const Icon(Icons.sync, size: 20),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.of(context)!.syncWithSubjects, style: GoogleFonts.inter()),
                  ],
                ),
                onTap: () => Future.delayed(
                  const Duration(milliseconds: 100),
                  () => _syncWithSubjects(),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showEditDialog(null),
            tooltip: AppLocalizations.of(context)!.addSubject,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    // Combine existing rates with defaults not yet added
    final existingIds = _rates.map((r) => r.subjectId).toSet();
    final missingDefaults = _defaultSubjects
        .where((d) => !existingIds.contains(d['id']))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.setHourlyRatesForEachSubject,
                    style: GoogleFonts.inter(color: Colors.blue.shade800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Existing rates
          if (_rates.isNotEmpty) ...[
            Text(
              AppLocalizations.of(context)!.configuredRates,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _buildRatesTable(_rates),
            const SizedBox(height: 32),
          ],

          // Missing defaults
          if (missingDefaults.isNotEmpty) ...[
            Text(
              AppLocalizations.of(context)!.availableSubjectsClickToConfigure,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: missingDefaults.map((subject) {
                return ActionChip(
                  avatar: CircleAvatar(
                    backgroundColor: subject['color'] as Color,
                    radius: 12,
                  ),
                  label: Text(
                    '${subject['name']} - \$${(subject['rate'] as double).toStringAsFixed(2)}/hr',
                    style: GoogleFonts.inter(),
                  ),
                  onPressed: () => _showEditDialog(null, defaultSubject: subject),
                );
              }).toList(),
            ),
          ],

          // If no rates at all
          if (_rates.isEmpty && missingDefaults.isEmpty) ...[
            Center(
              child: Column(
                children: [
                  Icon(Icons.monetization_on_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.noRatesConfigured,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showEditDialog(null),
                    icon: const Icon(Icons.add),
                    label: Text(AppLocalizations.of(context)!.addFirstRate),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatesTable(List<SubjectHourlyRate> rates) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1),
            3: FlexColumnWidth(1),
            4: FixedColumnWidth(80),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              children: [
                _tableHeader('Subject'),
                _tableHeader('Hourly Rate'),
                _tableHeader('Penalty'),
                _tableHeader('Bonus'),
                _tableHeader('Actions'),
              ],
            ),
            ...rates.map((rate) => TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getSubjectColor(rate.subjectId),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              rate.subjectName,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        '\$${rate.hourlyRate.toStringAsFixed(2)}/hr',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        '-\$${rate.penaltyRatePerMissedClass.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(color: Colors.red.shade600),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        '+\$${rate.bonusRatePerExcellence.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(color: Colors.green.shade600),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _showEditDialog(rate),
                        tooltip: AppLocalizations.of(context)!.commonEdit,
                      ),
                    ),
                  ],
                )),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _getSubjectColor(String subjectId) {
    final defaultSubject = _defaultSubjects.firstWhere(
      (s) => s['id'] == subjectId,
      orElse: () => {'color': Colors.grey},
    );
    return defaultSubject['color'] as Color;
  }

  /// Quickly set default rates for all subjects
  /// English/Maths: 5$ | Quran/Islam/Arabic: 4$
  Future<void> _setDefaultRates() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)!.setDefaultRates,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          '${AppLocalizations.of(context)!.thisWillSetDefaultRatesFor}\n'
          '• English, Maths, Science, Programming: \$5.00/hr\n'
          '• Quran, Arabic, Hadith, Fiqh, Tutoring: \$4.00/hr\n\n'
          'Existing rates will be overwritten. Continue?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff0386FF),
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context)!.setDefaults),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      int updated = 0;
      for (final subject in _defaultSubjects) {
        final subjectId = subject['id'] as String;
        final rate = subject['rate'] as double;
        
        await TeacherAuditService.updateSubjectRate(
          subjectId: subjectId,
          hourlyRate: rate,
          penaltyRate: 5.0,
          bonusRate: 10.0,
        );
        updated++;
      }

      if (mounted) {
        await _loadRates();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.updatedDefaultRatesForUpdatedSubjects),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorE),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Sync rates with subjects collection (update defaultWage)
  Future<void> _syncWithSubjects() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)!.syncWithSubjects,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          '${AppLocalizations.of(context)!.thisWillUpdateTheDefaultwageField} '
          'to match the hourly rates configured here. This ensures that when '
          'creating new shifts, the correct default rate is used.\n\n'
          'Continue?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff0386FF),
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context)!.sync),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      int synced = 0;
      
      for (final rate in _rates) {
        try {
          // Find subject by name (case-insensitive) or displayName
          final subjectsSnapshot = await FirebaseFirestore.instance
              .collection('subjects')
              .where('name', isEqualTo: rate.subjectId)
              .limit(1)
              .get();
          
          String? subjectDocId;
          if (subjectsSnapshot.docs.isNotEmpty) {
            subjectDocId = subjectsSnapshot.docs.first.id;
          } else {
            // Try by displayName
            final byDisplayName = await FirebaseFirestore.instance
                .collection('subjects')
                .where('displayName', isEqualTo: rate.subjectName)
                .limit(1)
                .get();
            if (byDisplayName.docs.isNotEmpty) {
              subjectDocId = byDisplayName.docs.first.id;
            }
          }
          
          if (subjectDocId != null) {
            await FirebaseFirestore.instance
                .collection('subjects')
                .doc(subjectDocId)
                .update({
              'defaultWage': rate.hourlyRate,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            synced++;
          }
        } catch (e) {
          // Continue with other subjects even if one fails
          AppLogger.error('Error syncing ${rate.subjectName}: $e');
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.syncedSyncedSubjectsWithRates),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorE),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

