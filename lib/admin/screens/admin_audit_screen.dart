import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:universal_html/html.dart' as html;
import '../../core/models/teacher_audit_full.dart';
import '../../core/services/teacher_audit_service.dart';
import '../../core/models/teaching_shift.dart';
import '../../core/services/form_labels_cache_service.dart';
import '../../core/services/audit_performance_optimizer.dart';
import '../../core/services/advanced_excel_export_service.dart';
import '../../core/utils/app_logger.dart';
import '../../features/shift_management/widgets/shift_details_dialog.dart';
import '../../features/forms/widgets/form_details_modal.dart';
import 'coach_evaluation_screen.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Windows 11 Fluent Design Colors
class Win11Colors {
  static const Color accent = Color(0xff0078D4); // Bleu Windows
  static const Color background = Color(0xffF3F3F3);
  static const Color card = Colors.white;
  static const Color border = Color(0xffE5E5E5);
  static const Color textMain = Color(0xff1A1A1A);
  static const Color textSecondary = Color(0xff616161);
}

/// Admin screen for managing all teacher audits
class AdminAuditScreen extends StatefulWidget {
  const AdminAuditScreen({super.key});

  @override
  State<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends State<AdminAuditScreen> with SingleTickerProviderStateMixin {
  List<TeacherAuditFull> _audits = [];
  bool _isLoading = true;
  bool _isGenerating = false;
  bool _isRefreshing = false; // Prevent multiple simultaneous refreshes
  String _selectedYearMonth = DateFormat('yyyy-MM').format(DateTime.now());
  String _selectedEndYearMonth = DateFormat('yyyy-MM').format(DateTime.now()); // for two months / custom
  String _periodMode = 'one_month'; // one_month | two_months | custom | all_time
  String _statusFilter = 'all';
  String _tierFilter = 'all';
  String _searchQuery = ''; // For search functionality
  int _currentPage = 0;
  final int _itemsPerPage = 10;
  String? _sortColumn;
  bool _sortAscending = true;

  // Animation controller pour l'entrée
  late AnimationController _animationController;

  final Color _primaryColor = Win11Colors.accent;
  final Color _backgroundColor = Win11Colors.background;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadAudits();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAudits({bool force = false}) async {
    // Prevent multiple simultaneous calls, but allow forced reloads
    if (!force && (_isRefreshing || (_isLoading && _audits.isNotEmpty))) {
      AppLogger.debug('Skipping _loadAudits: force=$force, isRefreshing=$_isRefreshing, isLoading=$_isLoading, auditsCount=${_audits.length}');
      return;
    }
    
    setState(() {
      if (_audits.isEmpty || force) {
        _isLoading = true;
        _isRefreshing = false;
      } else {
        _isRefreshing = true;
      }
    });

    try {
      AppLogger.debug('Loading audits: periodMode=$_periodMode, start=$_selectedYearMonth, end=$_selectedEndYearMonth');
      List<TeacherAuditFull> audits;
      if (_periodMode == 'all_time') {
        audits = await OptimizedAuditLoader.loadAuditsOptimized(allTime: true);
      } else if (_periodMode == 'one_month') {
        audits = await OptimizedAuditLoader.loadAuditsOptimized(yearMonth: _selectedYearMonth);
      } else {
        final months = <String>[];
        final start = DateTime.parse('$_selectedYearMonth-01');
        final end = DateTime.parse('$_selectedEndYearMonth-01');
        if (end.isBefore(start)) {
          for (var d = DateTime(end.year, end.month); !d.isAfter(DateTime(start.year, start.month)); d = DateTime(d.year, d.month + 1)) {
            months.add(DateFormat('yyyy-MM').format(d));
          }
        } else {
          for (var d = DateTime(start.year, start.month); !d.isAfter(DateTime(end.year, end.month)); d = DateTime(d.year, d.month + 1)) {
            months.add(DateFormat('yyyy-MM').format(d));
          }
        }
        audits = await OptimizedAuditLoader.loadAuditsOptimized(yearMonths: months);
      }
      AppLogger.debug('Loaded ${audits.length} audits');
      if (mounted) {
        setState(() {
          _audits = audits;
          _isLoading = false;
          _isRefreshing = false;
        });
        _animationController.forward(from: 0.0);
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

  List<TeacherAuditFull> get _filteredAudits {
    var filtered = _audits.where((audit) {
      // Status filter
      if (_statusFilter != 'all' && audit.status.name != _statusFilter) return false;
      // Tier filter
      if (_tierFilter != 'all' && audit.performanceTier != _tierFilter) return false;
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!audit.teacherName.toLowerCase().contains(query) &&
            !audit.teacherEmail.toLowerCase().contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();

    // Sorting
    if (_sortColumn != null) {
      filtered.sort((a, b) {
        int comparison = 0;
        switch (_sortColumn) {
          case 'name':
            comparison = a.teacherName.compareTo(b.teacherName);
            break;
          case 'score':
            comparison = a.overallScore.compareTo(b.overallScore);
            break;
          case 'date':
            comparison = a.yearMonth.compareTo(b.yearMonth);
            break;
        }
        return _sortAscending ? comparison : -comparison;
      });
    }

    return filtered;
  }

  List<TeacherAuditFull> get _paginatedAudits {
    final start = _currentPage * _itemsPerPage;
    final end = (start + _itemsPerPage).clamp(0, _filteredAudits.length);
    return _filteredAudits.sublist(start.clamp(0, _filteredAudits.length), end);
  }

  int get _totalPages => (_filteredAudits.length / _itemsPerPage).ceil();

  String get _periodLabel {
    final l10n = AppLocalizations.of(context)!;
    if (_periodMode == 'all_time') return l10n.periodAllTime;
    if (_periodMode == 'one_month') {
      return DateFormat('MMM yyyy').format(DateTime.parse('$_selectedYearMonth-01'));
    }
    final start = DateFormat('MMM yyyy').format(DateTime.parse('$_selectedYearMonth-01'));
    final end = DateFormat('MMM yyyy').format(DateTime.parse('$_selectedEndYearMonth-01'));
    if (start == end) return start;
    return '$start – $end';
  }

  void _selectPeriod() async {
    HapticFeedback.lightImpact();
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final months = List.generate(24, (i) {
      final date = DateTime(now.year, now.month - i);
      return DateFormat('yyyy-MM').format(date);
    });

    String? dialogMode = _periodMode;
    String? dialogStart = _selectedYearMonth;
    String? dialogEnd = _selectedEndYearMonth;

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 380,
                constraints: const BoxConstraints(maxHeight: 520),
                decoration: BoxDecoration(
                  color: Win11Colors.card,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Win11Colors.border, width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.selectPeriod,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Win11Colors.textMain,
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              child: Icon(Icons.close, size: 18, color: Win11Colors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Win11Colors.border),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _periodChip(l10n.periodOneMonth, 'one_month', dialogMode ?? 'one_month', setDialogState, (v) => dialogMode = v),
                            const SizedBox(width: 6),
                            _periodChip(l10n.periodTwoMonths, 'two_months', dialogMode ?? 'one_month', setDialogState, (v) => dialogMode = v),
                            const SizedBox(width: 6),
                            _periodChip(l10n.periodCustomRange, 'custom', dialogMode ?? 'one_month', setDialogState, (v) => dialogMode = v),
                            const SizedBox(width: 6),
                            _periodChip(l10n.periodAllTime, 'all_time', dialogMode ?? 'one_month', setDialogState, (v) => dialogMode = v),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (dialogMode != 'all_time') ...[
                      if (dialogMode == 'one_month')
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: months.length,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            itemBuilder: (context, index) {
                              final m = months[index];
                              final date = DateTime.parse('$m-01');
                              final isSelected = m == dialogStart;
                              return InkWell(
                                onTap: () => setDialogState(() => dialogStart = m),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Win11Colors.accent.withOpacity(0.1) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: isSelected ? Border.all(color: Win11Colors.accent, width: 1.5) : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          DateFormat('MMMM yyyy').format(date),
                                          style: GoogleFonts.inter(
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                            fontSize: 14,
                                            color: isSelected ? Win11Colors.accent : Win11Colors.textMain,
                                          ),
                                        ),
                                      ),
                                      if (isSelected) Icon(Icons.check_circle, color: Win11Colors.accent, size: 20),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      else if (dialogMode == 'two_months') ...[
                        Text(l10n.startMonth, style: GoogleFonts.inter(fontSize: 12, color: Win11Colors.textSecondary)),
                        const SizedBox(height: 4),
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: months.length - 1,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            itemBuilder: (context, index) {
                              final m = months[index];
                              final date = DateTime.parse('$m-01');
                              final endDate = DateTime(date.year, date.month + 1);
                              final endStr = DateFormat('yyyy-MM').format(endDate);
                              final isSelected = dialogStart == m;
                              return InkWell(
                                onTap: () => setDialogState(() {
                                  dialogStart = m;
                                  dialogEnd = endStr;
                                }),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Win11Colors.accent.withOpacity(0.1) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: isSelected ? Border.all(color: Win11Colors.accent, width: 1.5) : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${DateFormat('MMM yyyy').format(date)} – ${DateFormat('MMM yyyy').format(endDate)}',
                                          style: GoogleFonts.inter(
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                            fontSize: 14,
                                            color: isSelected ? Win11Colors.accent : Win11Colors.textMain,
                                          ),
                                        ),
                                      ),
                                      if (isSelected) Icon(Icons.check_circle, color: Win11Colors.accent, size: 20),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ] else ...[
                        Text(l10n.startMonth, style: GoogleFonts.inter(fontSize: 12, color: Win11Colors.textSecondary)),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: months.length,
                            itemBuilder: (context, index) {
                              final m = months[index];
                              final isSelected = m == dialogStart;
                              return InkWell(
                                onTap: () => setDialogState(() {
                                  dialogStart = m;
                                  if (dialogEnd != null && dialogEnd!.compareTo(m) < 0) dialogEnd = m;
                                }),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                    DateFormat('MMMM yyyy').format(DateTime.parse('$m-01')),
                                    style: GoogleFonts.inter(
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                      fontSize: 13,
                                      color: isSelected ? Win11Colors.accent : Win11Colors.textMain,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(l10n.endMonth, style: GoogleFonts.inter(fontSize: 12, color: Win11Colors.textSecondary)),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: months.length,
                            itemBuilder: (context, index) {
                              final m = months[index];
                              final isSelected = m == dialogEnd;
                              final startOk = dialogStart != null && m.compareTo(dialogStart!) >= 0;
                              return InkWell(
                                onTap: startOk
                                    ? () => setDialogState(() => dialogEnd = m)
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                    DateFormat('MMMM yyyy').format(DateTime.parse('$m-01')),
                                    style: GoogleFonts.inter(
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                      fontSize: 13,
                                      color: isSelected ? Win11Colors.accent : (startOk ? Win11Colors.textMain : Win11Colors.textSecondary),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(l10n.commonCancel),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () {
                              if (dialogMode == 'all_time') {
                                Navigator.pop(context, {'mode': 'all_time', 'start': dialogStart ?? _selectedYearMonth, 'end': dialogEnd ?? _selectedEndYearMonth});
                              } else if (dialogMode == 'one_month' && dialogStart != null) {
                                Navigator.pop(context, {'mode': 'one_month', 'start': dialogStart, 'end': dialogStart});
                              } else if (dialogMode == 'two_months' && dialogStart != null && dialogEnd != null) {
                                Navigator.pop(context, {'mode': 'two_months', 'start': dialogStart, 'end': dialogEnd});
                              } else if (dialogMode == 'custom' && dialogStart != null && dialogEnd != null) {
                                Navigator.pop(context, {'mode': 'custom', 'start': dialogStart, 'end': dialogEnd});
                              }
                            },
                            child: Text(l10n.commonApply),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _periodMode = result['mode']!;
        _selectedYearMonth = result['start']!;
        _selectedEndYearMonth = result['end']!;
        _audits = [];
        _isLoading = true;
        _isRefreshing = false;
      });
      Future.microtask(() => _loadAudits(force: true));
    }
  }

  Widget _periodChip(String label, String value, String current, void Function(void Function()) setDialogState, void Function(String) onSelect) {
    final selected = current == value;
    return InkWell(
      onTap: () => setDialogState(() => onSelect(value)),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Win11Colors.accent.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: selected ? Border.all(color: Win11Colors.accent, width: 1.5) : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Win11Colors.accent : Win11Colors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// Show dialog to generate audits for selected teachers
  Future<void> _showGenerateAuditDialog() async {
    // Show smooth loading indicator while fetching teachers
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.loadingTeachers,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    List<Map<String, dynamic>> teachers = [];
    try {
      // Use optimized parallel teacher loading
      teachers = await OptimizedTeacherLoader.loadTeachers();
      
      if (teachers.isEmpty) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.noTeachersFoundMakeSureTeachers),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    } catch (e) {
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorFetchingTeachersE)),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context); // Close loading

    // Check which teachers already have audits
    final existingAuditIds = _audits.map((a) => a.oderId).toSet();
    final Set<String> selectedTeachers = {};

    // Small delay for smooth transition
    await Future.delayed(const Duration(milliseconds: 150));

    if (!mounted) return;

    String generateDialogSearchQuery = '';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final query = generateDialogSearchQuery.toLowerCase();
          final filteredTeachers = query.isEmpty
              ? teachers
              : teachers.where((t) {
                  final name = (t['name'] as String? ?? '').toLowerCase();
                  final email = (t['email'] as String? ?? '').toLowerCase();
                  return name.contains(query) || email.contains(query);
                }).toList();
          return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                const Icon(Icons.calculate, color: Color(0xff0386FF)),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context)!.generateAudits,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          content: SizedBox(
            width: 500,
            height: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.selectTeachersToGenerateRegenerateAudit,
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (value) => setDialogState(() => generateDialogSearchQuery = value),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.searchTeacher,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: GoogleFonts.inter(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        // Select all visible (filtered) teachers
                        final ids = filteredTeachers.map((t) => t['id'] as String).toList();
                        setDialogState(() {
                          selectedTeachers.addAll(ids);
                        });
                      },
                      child: Text(AppLocalizations.of(context)!.selectAll),
                    ),
                    TextButton(
                      onPressed: () {
                        // Select only visible teachers without audits
                        final newTeachers = filteredTeachers
                            .where((t) => !existingAuditIds.contains(t['id']))
                            .map((t) => t['id'] as String)
                            .toList();
                        setDialogState(() {
                          selectedTeachers.addAll(newTeachers);
                        });
                      },
                      child: Text(AppLocalizations.of(context)!.selectNewOnly),
                    ),
                    TextButton(
                      onPressed: () {
                        setDialogState(() => selectedTeachers.clear());
                      },
                      child: Text(AppLocalizations.of(context)!.commonClear),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: filteredTeachers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_search, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                generateDialogSearchQuery.isEmpty
                                    ? AppLocalizations.of(context)!.noTeachersFound
                                    : AppLocalizations.of(context)!.noTeachersFoundMakeSureTeachers,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredTeachers.length,
                          itemBuilder: (context, index) {
                      final teacher = filteredTeachers[index];
                      final teacherId = teacher['id'] as String;
                      final hasAudit = existingAuditIds.contains(teacherId);
                      final isSelected = selectedTeachers.contains(teacherId);

                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == true) {
                              selectedTeachers.add(teacherId);
                            } else {
                              selectedTeachers.remove(teacherId);
                            }
                          });
                        },
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                teacher['name'] as String,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (hasAudit)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Text(
                                  AppLocalizations.of(context)!.hasAudit,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: Colors.blue.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          teacher['email'] as String,
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.commonCancel),
            ),
            ElevatedButton.icon(
              onPressed: selectedTeachers.isEmpty
                  ? null
                  : () {
                      Navigator.pop(context);
                      _generateAuditsForTeachers(
                        selectedTeachers.toList(),
                        teachers,
                      );
                    },
              icon: const Icon(Icons.calculate),
              label: Text('Generate (${selectedTeachers.length})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                foregroundColor: Colors.white,
              ),
            ),
          ],
          ),
        );
        },
      ),
    );
  }

  /// Generate audits for selected teachers efficiently
  Future<void> _generateAuditsForTeachers(
    List<String> teacherIds,
    List<Map<String, dynamic>> allTeachers,
  ) async {
    // Track dialog for proper closing
    BuildContext? dialogContext;
    
    // Progress tracking
    final progressController = StreamController<_AuditProgressState>.broadcast();
    final startTime = DateTime.now();
    
    // Fun messages to keep user entertained
    final funMessages = [
      '🔍 Analyzing teaching hours...',
      '📊 Crunching the numbers...',
      '📝 Checking form submissions...',
      '⏰ Calculating punctuality scores...',
      '🎯 Computing performance metrics...',
      '💰 Processing payment data...',
      '📈 Building performance reports...',
      '✨ Almost there, hang tight!',
      '🚀 Turbo-charging calculations...',
      '🧮 Running final computations...',
    ];
    
    // Show enhanced progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) {
        dialogContext = ctx;
        return _EnhancedProgressDialog(
          progressStream: progressController.stream,
          totalTeachers: teacherIds.length,
          funMessages: funMessages,
          startTime: startTime,
        );
      },
    );

    setState(() => _isGenerating = true);

    // Use the optimized batch processing with detailed progress
    final results = await OptimizedAuditGenerator.generateAuditsBatch(
      teacherIds: teacherIds,
      yearMonth: _selectedYearMonth,
      onProgress: (completed, total) {
        if (!progressController.isClosed) {
          // Get current teacher name if available
          String currentTeacher = '';
          if (completed < allTeachers.length) {
            currentTeacher = allTeachers[completed]['name'] ?? 
                           allTeachers[completed]['fullName'] ?? '';
          }
          progressController.add(_AuditProgressState(
            progress: completed / total,
            completed: completed,
            total: total,
            currentTeacher: currentTeacher,
            elapsedSeconds: DateTime.now().difference(startTime).inSeconds,
          ));
        }
      },
    );
    
    // Brief delay to show 100% completion
    if (!progressController.isClosed) {
      progressController.add(_AuditProgressState(
        progress: 1.0,
        completed: teacherIds.length,
        total: teacherIds.length,
        currentTeacher: 'Complete!',
        elapsedSeconds: DateTime.now().difference(startTime).inSeconds,
        isComplete: true,
      ));
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    // Close the dialog safely
    await progressController.close();
    
    // Pop dialog using its own context
    if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
      Navigator.of(dialogContext!).pop();
    }
    
    if (!mounted) {
      setState(() => _isGenerating = false);
      return;
    }

    // Get detailed error messages FIRST (before clearing)
    final errorDetails = TeacherAuditService.getLastAuditGenerationErrors();
    
    // Calculate counts correctly:
    // - successCount: teachers with successful audits (results[id] == true)
    // - actualErrorCount: ONLY actual errors (from errorDetails map), NOT skipped teachers
    // - skippedCount: teachers with false result but NOT in errorDetails (no data available)
    final successCount = results.values.where((v) => v).length;
    final actualErrorCount = errorDetails.length; // Only real errors, not skipped
    
    // Count skipped: teachers with false result but not in errorDetails
    final skippedTeachers = results.entries
        .where((e) => !e.value && !errorDetails.containsKey(e.key))
        .length;

    setState(() => _isGenerating = false);
    await _loadAudits();

    // Build informative message - only show errors if there are actual errors
    String message = 'Generated $successCount audit(s)';
    if (skippedTeachers > 0) {
      message += '. $skippedTeachers teacher(s) with no data';
    }
    if (actualErrorCount > 0) {
      message += '. $actualErrorCount error(s)';
    }
    
    final totalTime = DateTime.now().difference(startTime).inSeconds;
    message += ' in ${totalTime}s';

    // Show detailed error dialog if there are ACTUAL errors (not skipped)
    if (actualErrorCount > 0 && errorDetails.isNotEmpty && mounted) {
      TeacherAuditService.clearLastAuditGenerationErrors();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showErrorDetailsDialog(errorDetails, successCount, skippedTeachers);
        }
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                successCount > 0 ? Icons.check_circle : Icons.info,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: actualErrorCount > 0 ? Colors.orange : (skippedTeachers > 0 ? Colors.blue : Colors.green),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Win11Colors.background,
      body: Stack(
        children: [
          Column(
            children: [
              // Header avec breadcrumb et stats intégrées
              _buildHeader(),

              // Search and Filter Bar
              if (!_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), // Reduced vertical from 12 to 8
                  child: _buildSearchAndFilterBar(),
                ),

              // Table View with Progressive Loading
              Expanded(
                child: _isLoading
                    ? _buildSkeletonLoading()
                    : _filteredAudits.isEmpty
                        ? _buildEmptyState()
                        : _buildTableView(),
              ),

              // Pagination
              if (!_isLoading && _filteredAudits.isNotEmpty)
                _buildPagination(),

              // Bottom Action Bar
              _buildBottomActionBar(),
            ],
          ),
          // Loading overlay when refreshing data
          if (_isRefreshing)
            Container(
              color: Colors.black.withOpacity(0.1),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final total = _audits.length;
    final avgScore = _audits.isEmpty 
        ? 0.0 
        : (_audits.fold(0.0, (s, a) => s + a.overallScore) / total) / 10;
    
    // Calculate total payment - use gross payment if net is 0 or null
    double totalPayment = 0.0;
    int auditsWithPayment = 0;
    for (var audit in _audits) {
      if (audit.paymentSummary != null) {
        // Use net payment if available and > 0, otherwise use gross payment
        final payment = audit.paymentSummary!.totalNetPayment > 0
            ? audit.paymentSummary!.totalNetPayment
            : audit.paymentSummary!.totalGrossPayment;
        
        if (payment > 0) {
          totalPayment += payment;
          auditsWithPayment++;
        }
      }
    }
    
    // Debug: Log payment info
    if (kDebugMode && _audits.isNotEmpty) {
      print('Payment Debug: ${_audits.length} audits, $auditsWithPayment with payment, total: \$${totalPayment.toStringAsFixed(2)}');
      for (var audit in _audits.take(3)) {
        final pmt = audit.paymentSummary;
        print('  - ${audit.teacherName}: paymentSummary=${pmt != null}, '
            'gross=${pmt?.totalGrossPayment ?? 0}, '
            'net=${pmt?.totalNetPayment ?? 0}, '
            'workedHours=${audit.totalWorkedHours}');
      }
    }
    
    // Display payment (show 0.00 if no payment found)
    final paymentDisplay = totalPayment > 0 
        ? '\$${totalPayment.toStringAsFixed(2)}'
        : '\$0.00';
    
    final pendingCount = _audits.where((a) => 
        a.status == AuditStatus.pending || a.status == AuditStatus.coachSubmitted).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Win11Colors.card,
        border: Border(bottom: BorderSide(color: Win11Colors.border, width: 1)),
      ),
      child: Row(
        children: [
          // Title section
          Flexible(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context)!.auditManagement,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Win11Colors.textMain,
                  ),
                ),
                Text(
                  AppLocalizations.of(context)!.manageTeacherPerformanceAndPayments,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Win11Colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // User-friendly stats with labels - Flexible to prevent overflow
          if (_audits.isNotEmpty && !_isLoading) ...[
            Flexible(
              child: _StatCard(
                icon: Icons.group_rounded,
                label: 'Teachers',
                value: '$total',
                iconColor: Win11Colors.accent,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: _StatCard(
                icon: Icons.bar_chart_rounded,
                label: 'Avg Score',
                value: '${avgScore.toStringAsFixed(1)}/10',
                iconColor: Colors.purple,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: _StatCard(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Total Payment',
                value: paymentDisplay,
                iconColor: Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: _StatCard(
                icon: Icons.description_rounded,
                label: 'Pending',
                value: '$pendingCount',
                iconColor: Colors.pink,
                badge: pendingCount > 0 ? '!' : null,
              ),
            ),
            const SizedBox(width: 8),
          ],
          const Spacer(),
          // Header Actions (Windows 11 style)
          _buildHeaderAction(
            icon: Icons.calendar_today_outlined,
            label: _periodLabel,
            onTap: _selectPeriod,
          ),
          const SizedBox(width: 8),
          _buildHeaderAction(
            icon: Icons.refresh_rounded,
            label: AppLocalizations.of(context)!.commonRefresh,
            onTap: () {
              HapticFeedback.lightImpact();
              _loadAudits(force: true);
            },
          ),
          const SizedBox(width: 8),
          // Profile icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Win11Colors.border.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.person_outline, size: 16, color: Win11Colors.textSecondary),
              onPressed: () {},
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  /// Header Action Button (Windows 11 style with fine borders)
  Widget _buildHeaderAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Win11Colors.border, width: 1),
          borderRadius: BorderRadius.circular(6),
          color: Win11Colors.card,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Win11Colors.textMain),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Win11Colors.textMain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Row(
      children: [
        // Search bar with icon
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.searchTeacher,
                hintStyle: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 14),
                prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey.shade400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: GoogleFonts.inter(fontSize: 14),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _currentPage = 0;
                });
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Department dropdown
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButton<String>(
            value: null,
            hint: Text(
              AppLocalizations.of(context)!.allDepartments,
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade700),
            ),
            underline: const SizedBox(),
            icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
            items: [],
            onChanged: (value) {},
          ),
        ),
        const SizedBox(width: 8),
        // Filter icon button
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: IconButton(
            icon: Icon(Icons.filter_list, size: 20, color: Colors.grey.shade700),
            onPressed: () {},
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(width: 12),
        // Export CSV button
        ElevatedButton.icon(
          onPressed: _exportToCSV,
          icon: const Icon(Icons.download, size: 18),
          label: Text(
            AppLocalizations.of(context)!.csv,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
        ),
        const SizedBox(width: 8),
        // Export Excel button (with colors and formatting)
        ElevatedButton.icon(
          onPressed: _showExportDialog,
          icon: const Icon(Icons.table_chart, size: 18),
          label: Text(
            AppLocalizations.of(context)!.commonExport,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xff217346), // Excel green
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('All', 'all', _statusFilter, (val) => setState(() => _statusFilter = val)),
          const SizedBox(width: 8),
          _buildFilterChip('Pending', 'pending', _statusFilter, (val) => setState(() => _statusFilter = val)),
          const SizedBox(width: 8),
          _buildFilterChip('Submitted', 'coachSubmitted', _statusFilter, (val) => setState(() => _statusFilter = val)),
          const SizedBox(width: 8),
          _buildFilterChip('Completed', 'completed', _statusFilter, (val) => setState(() => _statusFilter = val)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, String groupValue, Function(String) onSelect) {
    final isSelected = value == groupValue;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        onSelect(value);
        setState(() => _currentPage = 0);
      },
      backgroundColor: Colors.white,
      selectedColor: _primaryColor.withOpacity(0.1),
      checkmarkColor: _primaryColor,
      labelStyle: GoogleFonts.inter(
        color: isSelected ? _primaryColor : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected ? _primaryColor : Colors.grey.shade300,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  /// Build bottom action bar with Generate Audits button
  Widget _buildBottomActionBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Generate Audits button (Primary action)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _showGenerateAuditDialog,
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.yellow),
                          ),
                        )
                      : const Icon(Icons.bolt_rounded, color: Colors.yellow, size: 20),
                  label: Text(
                    _isGenerating ? 'Generating...' : 'Generate Audits',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.yellow.withOpacity(0.3), width: 1),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build table view with columns matching the image layout
  Widget _buildTableView() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Win11Colors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Win11Colors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xffF9F9F9),
                border: Border(bottom: BorderSide(color: Win11Colors.border, width: 1)),
              ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildSortableHeader('Teacher Profile', 'name'),
                ),
                Expanded(
                  flex: 2,
                  child: _buildSortableHeader('Department', null),
                ),
                Expanded(
                  flex: 2,
                  child: _buildSortableHeader('Audit Date', 'date'),
                ),
                Expanded(
                  flex: 2,
                  child: _buildSortableHeader('Score', 'score'),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    AppLocalizations.of(context)!.userStatus,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Win11Colors.textMain,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    AppLocalizations.of(context)!.timesheetActions,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Win11Colors.textMain,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Table Body
          Expanded(
            child: ListView.separated(
              itemCount: _paginatedAudits.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: Win11Colors.border),
              itemBuilder: (context, index) {
                final audit = _paginatedAudits[index];
                return _buildTableRow(audit);
              },
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildSortableHeader(String label, String? columnName) {
    final isSorted = _sortColumn == columnName;
    return InkWell(
      onTap: columnName != null
          ? () {
              HapticFeedback.selectionClick();
              setState(() {
                if (_sortColumn == columnName) {
                  _sortAscending = !_sortAscending;
                } else {
                  _sortColumn = columnName;
                  _sortAscending = true;
                }
              });
            }
          : null,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Win11Colors.textMain,
              ),
            ),
          if (columnName != null) ...[
            const SizedBox(width: 4),
            Icon(
              isSorted
                  ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                  : Icons.arrow_upward,
              size: 14,
              color: isSorted ? Win11Colors.accent : Win11Colors.textSecondary,
            ),
          ],
          ],
        ),
      ),
    );
  }

  Widget _buildTableRow(TeacherAuditFull audit) {
    final tierColor = _getTierColor(audit.performanceTier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Reduced vertical from 12 to 8
      child: Row(
        children: [
          // Teacher Profile
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18, // Reduced from 20
                  backgroundColor: tierColor.withOpacity(0.1),
                  child: Text(
                    audit.teacherName.isNotEmpty ? audit.teacherName[0].toUpperCase() : '?',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 13, // Reduced from 14
                      color: tierColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10), // Reduced from 12
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        audit.teacherName,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 13, // Reduced from 14
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        audit.teacherEmail,
                        style: GoogleFonts.inter(
                          fontSize: 11, // Reduced from 12
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Department (using subject as department)
          Expanded(
            flex: 2,
            child: Text(
              audit.hoursTaughtBySubject.keys.isNotEmpty
                  ? audit.hoursTaughtBySubject.keys.first
                  : 'N/A',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700), // Reduced from 13
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Audit Date
          Expanded(
            flex: 2,
            child: Text(
              DateFormat('MMM d, yyyy').format(DateTime.parse('${audit.yearMonth}-01')),
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700), // Reduced from 13
            ),
          ),
          // Score with progress bar
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: audit.overallScore / 100,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                          minHeight: 5, // Reduced from 6
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${audit.overallScore.toStringAsFixed(1)}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 12, // Reduced from 13
                        color: tierColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Status
          Expanded(
            flex: 2,
            child: _buildStatusBadge(audit.status),
          ),
          // Actions
          Expanded(
            flex: 2,
            child: _buildTableActions(audit),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(AuditStatus status) {
    Color dotColor;
    Color bgColor;
    String label;

    switch (status) {
      case AuditStatus.pending:
        dotColor = Colors.orange;
        bgColor = Colors.orange.shade50;
        label = 'Pending Review';
        break;
      case AuditStatus.completed:
        dotColor = Colors.green;
        bgColor = Colors.green.shade50;
        label = 'Approved';
        break;
      case AuditStatus.disputed:
        dotColor = Colors.red;
        bgColor = Colors.red.shade50;
        label = 'Disputed';
        break;
      case AuditStatus.coachSubmitted:
        dotColor = Colors.blue;
        bgColor = Colors.blue.shade50;
        label = 'Submitted';
        break;
      default:
        dotColor = Colors.grey;
        bgColor = Colors.grey.shade50;
        label = status.name;
    }

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: dotColor,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTableActions(TeacherAuditFull audit) {
    final bool isPending = audit.status == AuditStatus.pending;
    final bool isCoachSubmitted = audit.status == AuditStatus.coachSubmitted;
    final bool isCompleted = audit.status == AuditStatus.completed;
    final bool isDisputed = audit.status == AuditStatus.disputed;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Always show view icon to see audit details
        IconButton(
          icon: Icon(Icons.visibility_outlined, size: 18, color: Colors.grey.shade600),
          onPressed: () => _showAuditDetails(audit),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: AppLocalizations.of(context)!.viewAuditDetails,
        ),
        
        if (isPending) ...[
          // If pending, coach needs to evaluate
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _openCoachEvaluation(audit),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: Text(
              AppLocalizations.of(context)!.evaluate,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ] else if (isCoachSubmitted) ...[
          // Coach has submitted, CEO/owner needs to review
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _showReviewDialog(audit),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: Text(
              AppLocalizations.of(context)!.review,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          // Coach can still edit their evaluation
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 18, color: Colors.grey.shade600),
            onPressed: () => _openCoachEvaluation(audit),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: AppLocalizations.of(context)!.editEvaluation,
          ),
        ] else if (isCompleted) ...[
          // Completed, can view and optionally edit
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 18, color: Colors.grey.shade600),
            onPressed: () => _openCoachEvaluation(audit),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: AppLocalizations.of(context)!.editEvaluation,
          ),
        ] else if (isDisputed) ...[
          // Disputed, CEO/owner needs to review
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _showReviewDialog(audit),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: Text(
              AppLocalizations.of(context)!.review,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'excellent': return const Color(0xFF10B981);
      case 'good': return const Color(0xFF3B82F6);
      case 'needsImprovement': return const Color(0xFFF59E0B);
      default: return const Color(0xFFEF4444);
    }
  }

  Widget _buildPagination() {
    final start = (_currentPage * _itemsPerPage) + 1;
    final end = ((_currentPage + 1) * _itemsPerPage).clamp(0, _filteredAudits.length);
    final total = _filteredAudits.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            AppLocalizations.of(context)!.showingStartEndOfTotalResults,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage--)
                    : null,
                child: Text(AppLocalizations.of(context)!.previous, style: GoogleFonts.inter(fontSize: 13)),
              ),
              SizedBox(width: 8),
              TextButton(
                onPressed: _currentPage < _totalPages - 1
                    ? () => setState(() => _currentPage++)
                    : null,
                child: Text(AppLocalizations.of(context)!.commonNext, style: GoogleFonts.inter(fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _exportToCSV() async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.generatingCsv),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Use optimized parallel CSV generation
      final csv = await OptimizedCSVExporter.generateCSV(_filteredAudits);

      // Download CSV (web only)
      if (kIsWeb) {
        final blob = html.Blob([csv], 'text/csv');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'teacher_audits_$_selectedYearMonth.csv')
          ..click();
        html.Url.revokeObjectUrl(url);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.csvExportedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorExportingCsvE),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show export dialog with options for filtering by teacher and global export
  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => _ExportDialog(
        audits: _filteredAudits,
        selectedYearMonth: _selectedYearMonth,
        allAudits: _audits,
      ),
    );
  }

  Future<void> _exportToExcel() async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.generatingExcelReport),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Use advanced Excel export with colors and formatting (locale for translated sheet/headers)
      await AdvancedExcelExportService.exportToExcel(
        audits: _filteredAudits,
        yearMonth: _selectedYearMonth,
        locale: Localizations.localeOf(context).languageCode,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.excelReportExportedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorExportingExcelE),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildModernActionButton({required IconData icon, required String label, required VoidCallback onTap, bool isPrimary = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isPrimary ? _primaryColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: isPrimary ? null : Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isPrimary ? Colors.white : Colors.black87),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: isPrimary ? Colors.white : Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildModernFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // Status Filters
          _buildFilterChip('All', 'all', _statusFilter, (val) => setState(() => _statusFilter = val)),
          const SizedBox(width: 8),
          _buildFilterChip('Pending', 'pending', _statusFilter, (val) => setState(() => _statusFilter = val)),
          const SizedBox(width: 8),
          _buildFilterChip('Submitted', 'coachSubmitted', _statusFilter, (val) => setState(() => _statusFilter = val)),
          const SizedBox(width: 8),
          _buildFilterChip('Completed', 'completed', _statusFilter, (val) => setState(() => _statusFilter = val)),
          
          Container(height: 24, width: 1, color: Colors.grey[300], margin: const EdgeInsets.symmetric(horizontal: 12)),
          
          // Tier Filters
           _buildFilterChip('🏆 Excellent', 'excellent', _tierFilter, (val) => setState(() => _tierFilter = val)),
           const SizedBox(width: 8),
           _buildFilterChip('⚠️ Critical', 'critical', _tierFilter, (val) => setState(() => _tierFilter = val)),
        ],
      ),
    );
  }

  /// Summary cards matching the image layout
  Widget _buildSummaryGrid() {
    final total = _audits.length;
    final avgScore = _audits.isEmpty 
        ? 0.0 
        : (_audits.fold(0.0, (s, a) => s + a.overallScore) / total) / 10; // Convert to /10 scale
    
    // Calculate total payment - use same logic as header (use gross if net is 0 or null)
    double totalPayment = 0.0;
    int auditsWithPayment = 0;
    int auditsWithZeroPayment = 0;
    
    for (var audit in _audits) {
      if (audit.paymentSummary != null) {
        // Use net payment if available and > 0, otherwise use gross payment
        final netPayment = audit.paymentSummary!.totalNetPayment;
        final grossPayment = audit.paymentSummary!.totalGrossPayment;
        final payment = netPayment > 0 ? netPayment : grossPayment;
        
        if (payment > 0) {
          totalPayment += payment;
          auditsWithPayment++;
        } else {
          auditsWithZeroPayment++;
        }
        
        // Debug first few audits
        if (kDebugMode && auditsWithPayment + auditsWithZeroPayment <= 5) {
          print('Payment Debug - ${audit.teacherName}: '
              'gross=\$${grossPayment.toStringAsFixed(2)}, '
              'net=\$${netPayment.toStringAsFixed(2)}, '
              'hours=${audit.totalHoursTaught}, '
              'completed=${audit.totalClassesCompleted}');
        }
      } else {
        auditsWithZeroPayment++;
      }
    }
    
    // Debug summary
    if (kDebugMode) {
      print('Payment Summary Debug:');
      print('  Total audits: ${_audits.length}');
      print('  Audits with payment > 0: $auditsWithPayment');
      print('  Audits with zero/no payment: $auditsWithZeroPayment');
      print('  Total payment: \$${totalPayment.toStringAsFixed(2)}');
    }
    
    final pendingCount = _audits.where((a) => 
        a.status == AuditStatus.pending || a.status == AuditStatus.coachSubmitted).length;

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.group_rounded,
            iconColor: Colors.blue,
            value: '$total',
            label: 'Total Teachers Audited',
            trend: '+12%',
            trendColor: Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SummaryCard(
            icon: Icons.bar_chart_rounded,
            iconColor: Colors.purple,
            value: '${avgScore.toStringAsFixed(1)}/10',
            label: 'Average Score',
            trend: '+2.1%',
            trendColor: Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SummaryCard(
            icon: Icons.account_balance_wallet_rounded,
            iconColor: Colors.orange,
            value: '\$${totalPayment.toStringAsFixed(0)}',
            label: 'Total Payout Due',
            subLabel: 'This Month',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SummaryCard(
            icon: Icons.description_rounded,
            iconColor: Colors.pink,
            value: '$pendingCount',
            label: 'Pending Reviews',
            attentionLabel: 'Attention',
            attentionColor: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedAuditCard(TeacherAuditFull audit, int index) {
    // Staggered Animation Logic
    final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval((index / 10).clamp(0.0, 1.0) * 0.5, 1.0, curve: Curves.easeOutQuart),
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - animation.value)),
          child: Opacity(
            opacity: animation.value,
            child: _ModernAuditCard(
              audit: audit,
              onTap: () => _showAuditDetails(audit),
              onEvaluate: () => _openCoachEvaluation(audit),
              onAdjustPayment: () => _showPaymentAdjustmentDialog(audit),
              onReview: () => _showReviewDialog(audit),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernSkeletonLoader() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          height: 140,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle)),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 120, height: 14, color: Colors.grey[100]),
                        const SizedBox(height: 8),
                        Container(width: 80, height: 10, color: Colors.grey[50]),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 20),
                Container(width: double.infinity, height: 1, color: Colors.grey[50]),
                const SizedBox(height: 20),
                Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Container(width: 60, height: 10, color: Colors.grey[50]),
                     Container(width: 60, height: 10, color: Colors.grey[50]),
                     Container(width: 60, height: 10, color: Colors.grey[50]),
                   ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  /// Skeleton loading UI for progressive feel while loading
  Widget _buildSkeletonLoading() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Progress indicator at top
          LinearProgressIndicator(
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(_primaryColor),
          ),
          const SizedBox(height: 16),
          // Loading message
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sync, color: _primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.loadingAuditsForSelectedyearmonth,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Skeleton rows
          Expanded(
            child: ListView.builder(
              itemCount: 6,
              itemBuilder: (context, index) {
                return _buildSkeletonRow(index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonRow(int index) {
    // Shimmer effect delay based on index
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 100)),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                // Avatar placeholder
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                // Text placeholders
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 10,
                        width: 180,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                // Score placeholder
                Container(
                  width: 60,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(width: 16),
                // Status placeholder
                Container(
                  width: 80,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle),
            child: Icon(Icons.analytics_outlined, size: 48, color: Colors.blue[300]),
          ),
          SizedBox(height: 24),
          Text(AppLocalizations.of(context)!.noAuditsFound, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          Text(AppLocalizations.of(context)!.tryChangingTheMonthOrGenerating, style: GoogleFonts.inter(color: Colors.grey[500])),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: _showGenerateAuditDialog,
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide(color: _primaryColor),
            ),
            child: Text(AppLocalizations.of(context)!.generateNow, style: TextStyle(color: _primaryColor)),
          ),
        ],
      ),
    );
  }

  void _showAuditDetails(TeacherAuditFull audit) {
    HapticFeedback.lightImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: AppLocalizations.of(context)?.commonClose ?? 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.25),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 680,
              height: double.infinity,
              margin: const EdgeInsets.only(top: 0, right: 0, bottom: 0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 24,
                    offset: const Offset(-4, 0),
                  ),
                ],
              ),
              child: _AuditDetailFullPanel(audit: audit),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  void _openCoachEvaluation(TeacherAuditFull audit) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close evaluation panel',
      barrierColor: Colors.black.withOpacity(0.3),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: CoachEvaluationScreen(
              audit: audit,
              onSaved: () {
                // Close the panel FIRST for immediate feedback
                Navigator.pop(context);
                // Then refresh data in background
                _loadAudits(force: true);
              },
            ),
          ),
        );
      },
    );
  }

  /// Fixed payment adjustment dialog
  void _showPaymentAdjustmentDialog(TeacherAuditFull audit) {
    final adjustmentController = TextEditingController();
    final reasonController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.payments, color: Color(0xff0386FF)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.adjustPayment,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(
                  audit.teacherName,
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppLocalizations.of(context)!.currentPayment),
                      Text(
                        '\$${audit.paymentSummary?.totalNetPayment.toStringAsFixed(2) ?? '0.00'}',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: adjustmentController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.adjustmentAmount,
                    hintText: AppLocalizations.of(context)!.adjustmentAmountExampleHint,
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.reasonRequired,
                    hintText: AppLocalizations.of(context)!.roundingAdjustmentPenaltyBonusEtc,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
              child: Text(AppLocalizations.of(context)!.commonCancel),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final adjustment = double.tryParse(adjustmentController.text);
                      if (adjustment == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context)!.pleaseEnterAValidNumber)),
                        );
                        return;
                      }
                      if (reasonController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context)!.pleaseProvideAReason)),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);

                      try {
                        await TeacherAuditService.updatePaymentAdjustment(
                          auditId: audit.id,
                          adjustment: adjustment,
                          reason: reasonController.text.trim(),
                        );

                        if (mounted) {
                          Navigator.pop(dialogContext);
                          _loadAudits();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppLocalizations.of(context)!.paymentAdjustedSuccessfully),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppLocalizations.of(context)!.errorE), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                foregroundColor: Colors.white,
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(AppLocalizations.of(context)!.applyAdjustment),
            ),
          ],
        ),
      ),
    );
  }

  /// CEO/Founder review dialog
  void _showReviewDialog(TeacherAuditFull audit) {
    final notesController = TextEditingController(text: AppLocalizations.of(context)!.reviewed); // Default comment
    String selectedRole = 'ceo';
    String selectedStatus = 'approved';
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.verified_user, color: Color(0xff0386FF)),
              SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)!.adminReview,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Teacher info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        child: Text(audit.teacherName.isNotEmpty ? audit.teacherName[0] : '?'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(audit.teacherName, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                            Text('Score: ${audit.overallScore.toStringAsFixed(0)}% • ${audit.performanceTier}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Current status
                Text(
                  'Current Status: ${audit.status.name.toUpperCase()}',
                  style: GoogleFonts.inter(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),

                // Role selection
                Text(AppLocalizations.of(context)!.reviewAs, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text(AppLocalizations.of(context)!.ceo),
                        value: 'ceo',
                        groupValue: selectedRole,
                        onChanged: (v) => setDialogState(() => selectedRole = v!),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text(AppLocalizations.of(context)!.founder),
                        value: 'founder',
                        groupValue: selectedRole,
                        onChanged: (v) => setDialogState(() => selectedRole = v!),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Decision
                Text(AppLocalizations.of(context)!.decision, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    DropdownMenuItem(value: 'approved', child: Text(AppLocalizations.of(context)!.approve)),
                    DropdownMenuItem(value: 'needs_revision', child: Text(AppLocalizations.of(context)!.needsRevision)),
                    DropdownMenuItem(value: 'rejected', child: Text(AppLocalizations.of(context)!.reject)),
                  ],
                  onChanged: (v) => setDialogState(() => selectedStatus = v!),
                ),
                const SizedBox(height: 12),

                // Notes (Required - default "reviewed")
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.reviewComment,
                    hintText: AppLocalizations.of(context)!.addAnyCommentsOrCorrections,
                    border: const OutlineInputBorder(),
                    helperText: AppLocalizations.of(context)!.requiredFieldDefaultReviewed,
                    helperStyle: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  onChanged: (value) {
                    // If empty, set back to default
                    if (value.trim().isEmpty) {
                      notesController.text = 'reviewed';
                      notesController.selection = TextSelection.fromPosition(
                        TextPosition(offset: notesController.text.length),
                      );
                    }
                  },
                ),
              ],
            ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
              child: Text(AppLocalizations.of(context)!.commonCancel),
            ),
            ElevatedButton.icon(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() => isSubmitting = true);

                      try {
                        // Ensure comment is not empty, use default if empty
                        final comment = notesController.text.trim().isEmpty 
                            ? 'reviewed' 
                            : notesController.text.trim();
                        
                        await TeacherAuditService.submitReview(
                          auditId: audit.id,
                          role: selectedRole,
                          status: selectedStatus,
                          notes: comment,
                        );

                        if (mounted) {
                          Navigator.pop(dialogContext);
                          _loadAudits();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppLocalizations.of(context)!.reviewSubmitted),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppLocalizations.of(context)!.errorE), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              icon: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check),
              label: Text(isSubmitting ? 'Submitting...' : 'Submit Review'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Show detailed error dialog with all error messages
  void _showErrorDetailsDialog(Map<String, String> errorDetails, int successCount, int skippedCount) {
    // Build teacher name map from existing audits
    final teacherNameMap = <String, String>{};
    for (var audit in _audits) {
      if (!teacherNameMap.containsKey(audit.oderId)) {
        teacherNameMap[audit.oderId] = audit.teacherName;
      }
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.auditGenerationErrors,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.summary,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '✅ $successCount successful\n'
                      '❌ ${errorDetails.length} errors\n'
                      '⏭️ $skippedCount skipped (no data)',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Error details
              Text(
                AppLocalizations.of(context)!.errorDetails,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              
              // Scrollable error list
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: errorDetails.length,
                  itemBuilder: (context, index) {
                    final entry = errorDetails.entries.elementAt(index);
                    final teacherId = entry.key;
                    final errorMessage = entry.value;
                    
                    // Get teacher name from map or use ID
                    final teacherName = teacherNameMap[teacherId] ?? 
                                      'Teacher ${teacherId.substring(0, 8)}...';
                    
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade200,
                            width: index < errorDetails.length - 1 ? 1 : 0,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person, size: 16, color: Colors.red.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  teacherName,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 24),
                            child: SelectableText(
                              errorMessage,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              AppLocalizations.of(context)!.commonClose,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
            child: Text(
              AppLocalizations.of(context)!.commonOk,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full audit detail panel – 680px side panel with 4 tabs (Overview, Activity, Payment, Forms).
class _AuditDetailFullPanel extends StatefulWidget {
  final TeacherAuditFull audit;
  const _AuditDetailFullPanel({required this.audit});

  @override
  State<_AuditDetailFullPanel> createState() => _AuditDetailFullPanelState();
}

class _AuditDetailFullPanelState extends State<_AuditDetailFullPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Color _tierColor(String tier) {
    switch (tier) {
      case 'excellent': return const Color(0xFF10B981);
      case 'good': return const Color(0xFF3B82F6);
      case 'needsImprovement': return const Color(0xFFF59E0B);
      default: return const Color(0xFFEF4444);
    }
  }

  String _tierLabel(String tier) {
    switch (tier) {
      case 'excellent': return AppLocalizations.of(context)!.auditTierExcellent;
      case 'good': return AppLocalizations.of(context)!.auditTierGood;
      case 'needsImprovement': return AppLocalizations.of(context)!.auditTierNeedsImprovement;
      default: return AppLocalizations.of(context)!.auditTierCritical;
    }
  }

  Color _statusColor(AuditStatus s) {
    switch (s) {
      case AuditStatus.completed: return const Color(0xFF10B981);
      case AuditStatus.coachSubmitted: return const Color(0xFF3B82F6);
      case AuditStatus.disputed: return const Color(0xFFEF4444);
      default: return const Color(0xFF9CA3AF);
    }
  }

  String _statusLabel(AuditStatus s) {
    switch (s) {
      case AuditStatus.completed: return AppLocalizations.of(context)!.auditStatusCompleted;
      case AuditStatus.coachSubmitted: return AppLocalizations.of(context)!.auditStatusSubmitted;
      case AuditStatus.disputed: return AppLocalizations.of(context)!.auditStatusDisputed;
      default: return AppLocalizations.of(context)!.auditStatusPending;
    }
  }

  @override
  Widget build(BuildContext context) {
    final audit = widget.audit;
    final tier = audit.performanceTier;
    final tc = _tierColor(tier);

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: tc.withOpacity(0.15),
                    child: Text(
                      audit.teacherName.isNotEmpty
                          ? audit.teacherName[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: tc,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          audit.teacherName,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xff1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${audit.teacherEmail}  ·  ${audit.yearMonth}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xff64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: const Color(0xff64748B),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _AuditDetailPill(
                    label: '${audit.overallScore.toStringAsFixed(0)}%',
                    color: tc,
                  ),
                  const SizedBox(width: 6),
                  _AuditDetailPill(
                    label: _tierLabel(tier),
                    color: tc,
                    outlined: true,
                  ),
                  const SizedBox(width: 6),
                  _AuditDetailPill(
                    label: _statusLabel(audit.status),
                    color: _statusColor(audit.status),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xffE2E8F0), width: 1),
            ),
          ),
          child: TabBar(
            controller: _tab,
            isScrollable: false,
            labelColor: const Color(0xff0078D4),
            unselectedLabelColor: const Color(0xff64748B),
            indicatorColor: const Color(0xff0078D4),
            indicatorWeight: 2,
            labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
            tabs: [
              Tab(text: AppLocalizations.of(context)!.auditTabOverview),
              Tab(text: AppLocalizations.of(context)!.auditTabActivity),
              Tab(text: AppLocalizations.of(context)!.auditTabPayment),
              Tab(text: AppLocalizations.of(context)!.auditTabForms),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _AuditOverviewTab(audit: audit),
              _AuditActivityTab(audit: audit),
              _AuditPaymentTab(audit: audit),
              _AuditFormsTab(audit: audit),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuditDetailPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool outlined;

  const _AuditDetailPill({required this.label, required this.color, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: outlined ? color : Colors.transparent),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _AuditOverviewTab extends StatelessWidget {
  final TeacherAuditFull audit;
  const _AuditOverviewTab({required this.audit});

  @override
  Widget build(BuildContext context) {
    final hasIssues = audit.issues.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _AuditSectionTitle(title: AppLocalizations.of(context)!.auditKeyIndicators),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: [
            _AuditKpiCard(
              icon: Icons.school_outlined,
              color: const Color(0xFF3B82F6),
              label: AppLocalizations.of(context)!.auditClassesCompleted,
              value: '${audit.totalClassesCompleted} / ${audit.totalClassesScheduled}',
            ),
            _AuditKpiCard(
              icon: Icons.timer_outlined,
              color: const Color(0xFF10B981),
              label: AppLocalizations.of(context)!.auditHoursTaught,
              value: '${audit.totalHoursTaught.toStringAsFixed(1)} h',
            ),
            _AuditKpiCard(
              icon: Icons.description_outlined,
              color: const Color(0xFF8B5CF6),
              label: AppLocalizations.of(context)!.auditTabForms,
              value: '${audit.readinessFormsSubmitted} / ${audit.readinessFormsRequired}',
            ),
            _AuditKpiCard(
              icon: Icons.check_circle_outline,
              color: const Color(0xFF059669),
              label: AppLocalizations.of(context)!.auditCompletionRateLabel,
              value: '${audit.completionRate.clamp(0, 100).toStringAsFixed(0)}%',
            ),
            _AuditKpiCard(
              icon: Icons.access_time_outlined,
              color: audit.lateClockIns > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
              label: AppLocalizations.of(context)!.auditLateClockInsLabel,
              value: audit.lateClockIns == 0 ? '✓ ${AppLocalizations.of(context)!.auditNoLateClockIns}' : '${audit.lateClockIns}',
            ),
            _AuditKpiCard(
              icon: Icons.assignment_late_outlined,
              color: audit.totalClassesMissed > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
              label: AppLocalizations.of(context)!.auditClassesMissedLabel,
              value: audit.totalClassesMissed > 0 ? '${audit.totalClassesMissed}' : '✓ ${AppLocalizations.of(context)!.auditNoMissedClasses}',
            ),
          ],
        ),
        const SizedBox(height: 20),
        _AuditSectionTitle(title: AppLocalizations.of(context)!.auditPerformanceRates),
        const SizedBox(height: 10),
        _AuditRateBar(label: AppLocalizations.of(context)!.auditClassCompletionRate, rate: audit.completionRate, goodThreshold: 80, warningThreshold: 60),
        const SizedBox(height: 8),
        _AuditRateBar(label: AppLocalizations.of(context)!.punctuality, rate: audit.punctualityRate, goodThreshold: 85, warningThreshold: 70),
        const SizedBox(height: 8),
        _AuditRateBar(label: AppLocalizations.of(context)!.auditFormComplianceLabel, rate: audit.formComplianceRate, goodThreshold: 90, warningThreshold: 70),
        if (audit.hoursTaughtBySubject.isNotEmpty) ...[
          const SizedBox(height: 20),
          _AuditSectionTitle(title: AppLocalizations.of(context)!.hoursBySubject),
          const SizedBox(height: 10),
          ...(audit.hoursTaughtBySubject.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
              .take(8)
              .map((e) => _AuditSubjectRow(
                    subject: e.key,
                    hours: e.value,
                    maxHours: audit.hoursTaughtBySubject.values.fold(0.0, (a, b) => a > b ? a : b),
                  )),
        ],
        const SizedBox(height: 20),
        _AuditSectionTitle(title: AppLocalizations.of(context)!.auditIssuesAlerts),
        const SizedBox(height: 8),
        if (!hasIssues)
          _AuditEmptyState(
            icon: Icons.check_circle_outline,
            message: AppLocalizations.of(context)!.auditNoIssuesDetected,
            color: const Color(0xFF10B981),
          )
        else
          Column(
            children: audit.issues.map((issue) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${issue.type}: ${issue.description}',
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF991B1B)),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _AuditActivityTab extends StatelessWidget {
  final TeacherAuditFull audit;
  const _AuditActivityTab({required this.audit});

  @override
  Widget build(BuildContext context) {
    final shifts = audit.detailedShifts;

    return shifts.isEmpty
        ? _AuditEmptyState(icon: Icons.calendar_today_outlined, message: 'Aucun shift enregistré')
        : Column(
            children: [
              Container(
                color: const Color(0xFFF8FAFC),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    _AuditMiniStat(label: AppLocalizations.of(context)!.auditTotalLabel, value: '${shifts.length}', icon: Icons.event_note),
                    const SizedBox(width: 16),
                    _AuditMiniStat(label: AppLocalizations.of(context)!.auditCompleted, value: '${audit.totalClassesCompleted}', icon: Icons.check_circle_outline, color: const Color(0xFF10B981)),
                    const SizedBox(width: 16),
                    _AuditMiniStat(label: AppLocalizations.of(context)!.auditMissed, value: '${audit.totalClassesMissed}', icon: Icons.cancel_outlined, color: audit.totalClassesMissed > 0 ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF)),
                    const SizedBox(width: 16),
                    _AuditMiniStat(label: AppLocalizations.of(context)!.hours, value: '${audit.totalHoursTaught.toStringAsFixed(1)}h', icon: Icons.timer_outlined, color: const Color(0xFF3B82F6)),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xffE2E8F0)),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: shifts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 56, color: Color(0xffF1F5F9)),
                  itemBuilder: (context, index) {
                    final shift = shifts[index];
                    final title = (shift['title'] as String?) ?? '—';
                    final status = (shift['status'] as String?) ?? '';
                    final start = (shift['start'] as Timestamp?)?.toDate();
                    final duration = (shift['duration'] as num?)?.toDouble() ?? 0;

                    final isDone = status == 'fullyCompleted' || status == 'completed' || status == 'partiallyCompleted';
                    final isMissed = status == 'missed';
                    final statusColor = isDone ? const Color(0xFF10B981) : isMissed ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
                    final statusBg = isDone ? const Color(0xFFDCFCE7) : isMissed ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7);
                    final statusLabel = isDone ? 'Done' : isMissed ? 'Missed' : (status.isNotEmpty ? status : '—');

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)),
                        child: Icon(isDone ? Icons.check : isMissed ? Icons.close : Icons.schedule, size: 18, color: statusColor),
                      ),
                      title: Text(
                        title,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xff1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        start != null ? DateFormat('EEE d MMM · HH:mm').format(start) : '—',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xff94A3B8)),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
                            child: Text(
                              statusLabel,
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor),
                            ),
                          ),
                          if (duration > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${duration.toStringAsFixed(1)}h',
                              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xff94A3B8)),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
  }
}

class _AuditPaymentTab extends StatelessWidget {
  final TeacherAuditFull audit;
  const _AuditPaymentTab({required this.audit});

  @override
  Widget build(BuildContext context) {
    final ps = audit.paymentSummary;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _AuditSectionTitle(title: AppLocalizations.of(context)!.auditPaymentSummary),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _AuditPayCard(
                label: AppLocalizations.of(context)!.auditGrossSalary,
                amount: ps?.totalGrossPayment ?? 0,
                color: const Color(0xFF3B82F6),
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AuditPayCard(
                label: AppLocalizations.of(context)!.auditNetSalary,
                amount: ps?.totalNetPayment ?? 0,
                color: const Color(0xFF10B981),
                icon: Icons.payments_outlined,
                isHighlighted: true,
              ),
            ),
          ],
        ),
        if (ps != null && (ps.shiftPaymentAdjustments.isNotEmpty || ps.adminAdjustment != 0)) ...[
          const SizedBox(height: 16),
          _AuditSectionTitle(title: AppLocalizations.of(context)!.auditAdjustments),
          const SizedBox(height: 10),
          if (ps.adminAdjustment != 0) ...[
            _AuditAdjustmentRow(
              amount: ps.adminAdjustment,
              reason: ps.adjustmentReason.isNotEmpty ? ps.adjustmentReason : AppLocalizations.of(context)!.auditGlobalAdjustment,
            ),
          ],
          ...ps.shiftPaymentAdjustments.entries.map((e) => _AuditAdjustmentRow(
                amount: e.value,
                reason: 'Shift ${e.key.length > 12 ? e.key.substring(e.key.length - 8) : e.key}',
              )),
          const SizedBox(height: 12),
        ],
        _AuditSectionTitle(title: AppLocalizations.of(context)!.auditPaymentCalculation),
        const SizedBox(height: 10),
        _AuditPayDetailRow(label: AppLocalizations.of(context)!.auditClassesCompleted, value: '${audit.totalClassesCompleted}'),
        _AuditPayDetailRow(label: AppLocalizations.of(context)!.auditHoursWorked, value: '${audit.totalHoursTaught.toStringAsFixed(2)} h'),
        _AuditPayDetailRow(label: AppLocalizations.of(context)!.auditFormsSubmittedLabel, value: '${audit.readinessFormsSubmitted} / ${audit.readinessFormsRequired}'),
        if (ps != null) ...[
          const Divider(height: 20, color: Color(0xffE2E8F0)),
          _AuditPayDetailRow(label: AppLocalizations.of(context)!.teacherAuditGross, value: '\$${ps.totalGrossPayment.toStringAsFixed(2)}'),
          _AuditPayDetailRow(
            label: AppLocalizations.of(context)!.auditTotalAdjustments,
            value: '\$${(ps.totalNetPayment - ps.totalGrossPayment).toStringAsFixed(2)}',
            valueColor: ps.totalNetPayment >= ps.totalGrossPayment ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          ),
          const Divider(height: 12, color: Color(0xffE2E8F0)),
          _AuditPayDetailRow(
            label: AppLocalizations.of(context)!.auditNetToPay,
            value: '\$${ps.totalNetPayment.toStringAsFixed(2)}',
            isBold: true,
            valueColor: const Color(0xFF10B981),
            fontSize: 16,
          ),
        ],
        if (ps == null)
          _AuditEmptyState(icon: Icons.money_off_outlined, message: AppLocalizations.of(context)!.auditNoPaymentDataAvailable),
      ],
    );
  }
}

class _AuditAdjustmentRow extends StatelessWidget {
  final double amount;
  final String reason;

  const _AuditAdjustmentRow({required this.amount, required this.reason});

  @override
  Widget build(BuildContext context) {
    final isPositive = amount >= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isPositive ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isPositive ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          Icon(
            isPositive ? Icons.add_circle_outline : Icons.remove_circle_outline,
            size: 16,
            color: isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(reason, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xff374151))),
          ),
          Text(
            '${isPositive ? '+' : ''}\$${amount.toStringAsFixed(2)}',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
          ),
        ],
      ),
    );
  }
}

class _AuditFormsTab extends StatelessWidget {
  final TeacherAuditFull audit;
  const _AuditFormsTab({required this.audit});

  static String _extractStudentName(String title) {
    final parts = title.split(' - ');
    if (parts.length >= 3) return parts[2].trim();
    if (parts.length == 2) return parts[1].trim();
    return title.trim();
  }

  @override
  Widget build(BuildContext context) {
    const generalKey = 'General / Unknown';

    final shiftIdToStudent = <String, String>{};
    for (var shift in audit.detailedShifts) {
      final id = shift['id'] as String? ?? '';
      final title = shift['title'] as String? ?? '';
      if (id.isNotEmpty) shiftIdToStudent[id] = _extractStudentName(title);
    }

    final allForms = <Map<String, dynamic>>[...audit.detailedForms];
    for (final f in audit.detailedFormsNoSchedule) {
      allForms.add({...f, '_noSchedule': true, 'rejectionReason': 'no_shift'});
    }
    for (final f in audit.detailedFormsRejected) {
      allForms.add({...f, 'rejectionReason': f['rejectionReason'] ?? 'duplicate'});
    }

    final byStudent = <String, List<Map<String, dynamic>>>{};
    for (var map in allForms) {
      final sid = (map['shiftId'] as String?) ?? '';
      final studentName = (sid.isNotEmpty && shiftIdToStudent.containsKey(sid)) ? shiftIdToStudent[sid]! : generalKey;
      byStudent.putIfAbsent(studentName, () => []).add(map);
    }

    final sorted = byStudent.keys.toList()
      ..sort((a, b) {
        if (a == generalKey) return 1;
        if (b == generalKey) return -1;
        return a.compareTo(b);
      });

    if (allForms.isEmpty) {
      return _AuditEmptyState(icon: Icons.description_outlined, message: AppLocalizations.of(context)!.auditNoFormsSubmitted);
    }

    final acceptedCount = audit.detailedForms.length;
    final rejectedNoShift = audit.detailedFormsNoSchedule.length;
    final rejectedDuplicates = audit.detailedFormsRejected.length;
    final rejectedCount = rejectedNoShift + rejectedDuplicates;

    return Column(
      children: [
        Container(
          color: const Color(0xFFF8FAFC),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              _AuditMiniStat(label: AppLocalizations.of(context)!.auditTotalLabel, value: '${allForms.length}', icon: Icons.description_outlined),
              const SizedBox(width: 16),
              _AuditMiniStat(
                label: AppLocalizations.of(context)!.auditFormsAccepted,
                value: '$acceptedCount',
                icon: Icons.check_circle_outline,
                color: const Color(0xFF10B981),
              ),
              const SizedBox(width: 16),
              _AuditMiniStat(
                label: AppLocalizations.of(context)!.auditFormsRejected,
                value: '$rejectedCount',
                icon: Icons.cancel_outlined,
                color: rejectedCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF),
              ),
              if (rejectedCount > 0) ...[
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context)!.auditFormsRejectedBreakdown(rejectedNoShift, rejectedDuplicates),
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xff64748B)),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xffE2E8F0)),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: sorted.length,
            itemBuilder: (context, si) {
              final student = sorted[si];
              final docs = byStudent[student]!;
              final displayName = student == generalKey ? AppLocalizations.of(context)!.auditGeneralOrUnlinked : student;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    color: const Color(0xffF8FAFC),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: const Color(0xff0078D4).withOpacity(0.15),
                          child: Text(
                            displayName[0].toUpperCase(),
                            style: GoogleFonts.inter(fontSize: 9, color: const Color(0xff0078D4), fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            displayName,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xff475569)),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xff0078D4).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${docs.length} form${docs.length > 1 ? 's' : ''}',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xff0078D4)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...docs.map((map) {
                    final submittedAt = (map['submittedAt'] as Timestamp?)?.toDate();
                    final dateStr = submittedAt != null ? DateFormat('MMM d, HH:mm').format(submittedAt) : '—';
                    final rejectionReason = map['rejectionReason'] as String?;
                    final isAccepted = rejectionReason == null || rejectionReason.isEmpty;
                    final isNoShift = rejectionReason == 'no_shift' || map['_noSchedule'] == true;
                    final isDuplicate = rejectionReason == 'duplicate';
                    final formId = (map['id'] as String?) ?? '';
                    final shiftId = (map['shiftId'] as String?)?.toString() ?? '';
                    final responses = (map['responses'] as Map<String, dynamic>?) ?? {};

                    String statusLabel;
                    Color statusColor;
                    Color statusBg;
                    IconData statusIcon;
                    if (isAccepted) {
                      statusLabel = AppLocalizations.of(context)!.auditFormStatusAccepted;
                      statusColor = const Color(0xFF16A34A);
                      statusBg = const Color(0xFFDCFCE7);
                      statusIcon = Icons.check_circle_outline;
                    } else if (isDuplicate) {
                      statusLabel = AppLocalizations.of(context)!.auditFormStatusRejectedDuplicate;
                      statusColor = const Color(0xFFDC2626);
                      statusBg = const Color(0xFFFEE2E2);
                      statusIcon = Icons.copy_outlined;
                    } else {
                      statusLabel = AppLocalizations.of(context)!.auditFormStatusRejectedNoShift;
                      statusColor = const Color(0xFFB45309);
                      statusBg = const Color(0xFFFEF3C7);
                      statusIcon = Icons.link_off_outlined;
                    }

                    return InkWell(
                      onTap: () {
                        FormDetailsModal.show(context, formId: formId, shiftId: shiftId, responses: responses);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Row(
                          children: [
                            Icon(statusIcon, size: 16, color: statusColor),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(dateStr, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xff475569))),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                statusLabel,
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right, size: 16, color: Color(0xff94A3B8)),
                          ],
                        ),
                      ),
                    );
                  }),
                  const Divider(height: 1, color: Color(0xffF1F5F9)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AuditSectionTitle extends StatelessWidget {
  final String title;
  const _AuditSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xff9CA3AF), letterSpacing: 0.8),
    );
  }
}

class _AuditKpiCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _AuditKpiCard({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xffE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 16, color: color),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xff1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(label, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xff94A3B8)), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuditRateBar extends StatelessWidget {
  final String label;
  final double rate;
  final double goodThreshold;
  final double warningThreshold;

  const _AuditRateBar({required this.label, required this.rate, this.goodThreshold = 80, this.warningThreshold = 60});

  Color get _color {
    if (rate >= goodThreshold) return const Color(0xFF10B981);
    if (rate >= warningThreshold) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final clamped = rate.clamp(0.0, 100.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xff475569))),
            Text('${clamped.toStringAsFixed(0)}%', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: clamped / 100,
            minHeight: 6,
            backgroundColor: const Color(0xffF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(_color),
          ),
        ),
      ],
    );
  }
}

class _AuditSubjectRow extends StatelessWidget {
  final String subject;
  final double hours;
  final double maxHours;

  const _AuditSubjectRow({required this.subject, required this.hours, required this.maxHours});

  @override
  Widget build(BuildContext context) {
    final fraction = maxHours > 0 ? (hours / maxHours).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(subject, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xff374151)), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                backgroundColor: const Color(0xffF1F5F9),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xff0078D4)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text('${hours.toStringAsFixed(1)}h', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xff64748B), fontWeight: FontWeight.w600), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _AuditEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color? color;

  const _AuditEmptyState({required this.icon, required this.message, this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: color ?? const Color(0xffCBD5E1)),
          const SizedBox(height: 12),
          Text(message, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xff94A3B8)), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _AuditMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _AuditMiniStat({required this.label, required this.value, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color ?? const Color(0xff9CA3AF)),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: color ?? const Color(0xff1E293B))),
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xff9CA3AF))),
          ],
        ),
      ],
    );
  }
}

class _AuditPayCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  final bool isHighlighted;

  const _AuditPayCard({required this.label, required this.amount, required this.color, required this.icon, this.isHighlighted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlighted ? color.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isHighlighted ? color.withOpacity(0.3) : const Color(0xffE2E8F0), width: isHighlighted ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 6), Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xff64748B)))]),
          const SizedBox(height: 8),
          Text('\$${amount.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: isHighlighted ? color : const Color(0xff1E293B))),
        ],
      ),
    );
  }
}

class _AuditPayDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;
  final double fontSize;

  const _AuditPayDetailRow({required this.label, required this.value, this.isBold = false, this.valueColor, this.fontSize = 13});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: fontSize, fontWeight: isBold ? FontWeight.w700 : FontWeight.normal, color: const Color(0xff374151))),
          Text(value, style: GoogleFonts.inter(fontSize: fontSize, fontWeight: isBold ? FontWeight.w700 : FontWeight.w600, color: valueColor ?? const Color(0xff1E293B))),
        ],
      ),
    );
  }
}

/// Responsive stat tile for summary grid (NO OVERFLOW)
/// Summary card widget matching the image layout
/// **Draggable Full-Screen Dialog Widget**
class _DraggableFullScreenDialog extends StatefulWidget {
  final Widget child;

  const _DraggableFullScreenDialog({required this.child});

  @override
  State<_DraggableFullScreenDialog> createState() => _DraggableFullScreenDialogState();
}

class _DraggableFullScreenDialogState extends State<_DraggableFullScreenDialog> {
  Offset _position = Offset.zero;
  bool _isDragging = false;
  Offset _dragStart = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: GestureDetector(
        onPanStart: (details) {
          setState(() {
            _isDragging = true;
            _dragStart = details.globalPosition;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
          });
        },
        onPanEnd: (details) {
          setState(() {
            _isDragging = false;
          });
        },
        child: Transform.translate(
          offset: _position,
          child: Container(
            width: screenSize.width,
            height: screenSize.height,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(0)),
            ),
            child: Stack(
              children: [
                // Draggable header bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Icon(Icons.drag_handle, color: Colors.grey.shade600, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            AppLocalizations.of(context)!.dragToMoveClickToClose,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.grey.shade700),
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: AppLocalizations.of(context)!.commonClose,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Content
                Positioned(
                  top: 50,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: widget.child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String? trend;
  final Color? trendColor;
  final String? subLabel;
  final String? attentionLabel;
  final Color? attentionColor;

  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.trend,
    this.trendColor,
    this.subLabel,
    this.attentionLabel,
    this.attentionColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12), // Reduced from 20
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6), // Reduced from 10
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18), // Reduced from 24
              ),
              if (trend != null)
                Row(
                  children: [
                    Icon(Icons.arrow_upward, size: 12, color: trendColor ?? Colors.green), // Reduced from 14
                    const SizedBox(width: 3),
                    Text(
                      trend!,
                      style: GoogleFonts.inter(
                        fontSize: 10, // Reduced from 12
                        fontWeight: FontWeight.w600,
                        color: trendColor ?? Colors.green,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10), // Reduced from 16
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20, // Reduced from 24
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2), // Reduced from 4
          Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11, // Reduced from 13
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (attentionLabel != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (attentionColor ?? Colors.orange).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    attentionLabel!,
                    style: GoogleFonts.inter(
                      fontSize: 9, // Reduced from 11
                      fontWeight: FontWeight.w600,
                      color: attentionColor ?? Colors.orange,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (subLabel != null) ...[
            const SizedBox(height: 2),
            Text(
              subLabel!,
              style: GoogleFonts.inter(
                fontSize: 10, // Reduced from 12
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.grey[500],
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A Clean, Modern Card Design
class _ModernAuditCard extends StatelessWidget {
  final TeacherAuditFull audit;
  final VoidCallback onTap;
  final VoidCallback onEvaluate;
  final VoidCallback onAdjustPayment;
  final VoidCallback onReview;

  const _ModernAuditCard({
    required this.audit,
    required this.onTap,
    required this.onEvaluate,
    required this.onAdjustPayment,
    required this.onReview,
  });

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'excellent': return const Color(0xFF10B981);
      case 'good': return const Color(0xFF3B82F6);
      case 'needsImprovement': return const Color(0xFFF59E0B);
      default: return const Color(0xFFEF4444);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tierColor = _getTierColor(audit.performanceTier);

    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 0, right: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. HEADER : Identité et Statut
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    _buildAvatar(tierColor),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            audit.teacherName,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: const Color(0xFF1A1C1E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            audit.teacherEmail,
                            style: GoogleFonts.inter(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    _ModernStatusPill(status: audit.status),
                  ],
                ),
              ),

              // 2. BODY : Métriques avec visuels clairs
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: _MetricItem(
                        icon: Icons.star_rounded,
                        label: 'Score',
                        value: '${audit.overallScore.round()}%',
                        color: tierColor,
                      ),
                    ),
                    Expanded(
                      child: _MetricItem(
                        icon: Icons.school_rounded,
                        label: 'Classes',
                        value: '${audit.totalClassesCompleted}',
                      ),
                    ),
                    Expanded(
                      child: _MetricItem(
                        icon: Icons.payments_rounded,
                        label: 'Payout',
                        value: '\$${audit.paymentSummary?.totalNetPayment.round() ?? 0}',
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              // 3. FOOTER : Actions explicites avec meilleur espacement
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
                ),
                child: Row(
                  children: [
                    // Action Secondaire : Ajuster
                    _SecondaryActionButton(
                      icon: Icons.edit_note_rounded,
                      label: 'Adjust',
                      onTap: onAdjustPayment,
                    ),
                    const SizedBox(width: 10),
                    // Action Principale : Évaluer (plus visible)
                    Expanded(
                      child: _PrimaryActionButton(
                        icon: Icons.rate_review_rounded,
                        label: 'Evaluate',
                        onTap: onEvaluate,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Action de Validation : Review
                    _SecondaryActionButton(
                      icon: Icons.verified_user_rounded,
                      label: 'Review',
                      onTap: onReview,
                      isHighlight: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(Color tierColor) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: tierColor.withOpacity(0.1),
          child: Text(
            audit.teacherName.isNotEmpty ? audit.teacherName[0].toUpperCase() : '?',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: tierColor,
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            height: 16,
            width: 16,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: CircleAvatar(backgroundColor: tierColor),
          ),
        ),
      ],
    );
  }
}

class _ModernStatusPill extends StatelessWidget {
  final AuditStatus status;
  const _ModernStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    String label;
    IconData? icon;

    switch (status) {
      case AuditStatus.pending:
        bg = Colors.grey[100]!;
        text = Colors.grey[700]!;
        label = 'Pending';
        break;
      case AuditStatus.completed:
        bg = const Color(0xFFE8F5E9);
        text = const Color(0xFF2E7D32);
        label = 'Done';
        icon = Icons.check_circle_outline;
        break;
      case AuditStatus.ceoApproved:
        bg = const Color(0xFFF3E5F5);
        text = const Color(0xFF7B1FA2);
        label = 'Approved';
        icon = Icons.verified_outlined;
        break;
      case AuditStatus.coachReview:
      case AuditStatus.coachSubmitted:
        bg = const Color(0xFFFFF3E0);
        text = const Color(0xFFEF6C00);
        label = 'Review';
        icon = Icons.rate_review_outlined;
        break;
      default:
        bg = Colors.grey[100]!;
        text = Colors.grey[600]!;
        label = status.name;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: text.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: text),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: text,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _MetricItem({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color ?? Colors.grey.shade400),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: color ?? Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade500,
            letterSpacing: 0.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PrimaryActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isHighlight;

  const _SecondaryActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        constraints: const BoxConstraints(minWidth: 75),
        decoration: BoxDecoration(
          color: isHighlight ? const Color(0xFFE0E7FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isHighlight
                ? const Color(0xFF4338CA).withOpacity(0.3)
                : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isHighlight ? const Color(0xFF4338CA) : Colors.black87,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isHighlight ? const Color(0xFF4338CA) : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final AuditStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case AuditStatus.pending:
        color = Colors.grey;
        label = 'PENDING';
        break;
      case AuditStatus.coachReview:
        color = Colors.orange;
        label = 'COACH REVIEW';
        break;
      case AuditStatus.coachSubmitted:
        color = Colors.blue;
        label = 'SUBMITTED';
        break;
      case AuditStatus.ceoApproved:
        color = Colors.purple;
        label = 'CEO APPROVED';
        break;
      case AuditStatus.completed:
        color = Colors.green;
        label = 'COMPLETED';
        break;
      case AuditStatus.disputed:
        color = Colors.red;
        label = 'DISPUTED';
        break;
      default:
        color = Colors.grey;
        label = status.name.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(color: color, fontSize: 9, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String label;
  final String value;

  const _QuickStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }
}

/// **OPTIMIZATION: Helper classes for efficient data grouping**
class _AuditDayItem {
  final DateTime date;
  final List<_ShiftItem> shifts;
  final List<_FormItem> forms;

  _AuditDayItem({
    required this.date,
    required this.shifts,
    required this.forms,
  });
}

class _ShiftItem {
  final String shiftId;
  final DateTime date;
  final String studentName;
  final String subject;
  final String status;
  final bool hasForm;
  final String? linkedFormId;
  final double scheduledHours;
  final double workedHours;

  _ShiftItem({
    required this.shiftId,
    required this.date,
    required this.studentName,
    required this.subject,
    required this.status,
    required this.hasForm,
    this.linkedFormId,
    required this.scheduledHours,
    required this.workedHours,
  });
}

class _FormItem {
  final String formId;
  final DateTime? submissionDate;
  final String? dayOfWeek;
  final bool isLinked;
  final String? linkedShiftId;
  final String? linkedShiftTitle;
  final double durationHours;
  final DateTime? formDate;

  _FormItem({
    required this.formId,
    this.submissionDate,
    this.dayOfWeek,
    required this.isLinked,
    this.linkedShiftId,
    this.linkedShiftTitle,
    required this.durationHours,
    this.formDate,
  });
}

class _AuditDetailSheet extends StatefulWidget {
  final TeacherAuditFull audit;
  final ScrollController scrollController;

  const _AuditDetailSheet({required this.audit, required this.scrollController});

  @override
  State<_AuditDetailSheet> createState() => _AuditDetailSheetState();
}

class _AuditDetailSheetState extends State<_AuditDetailSheet> {
  // **OPTIMIZATION: Cache grouped data to avoid recalculation**
  List<_AuditDayItem>? _cachedDayItems;
  List<_ShiftItem>? _cachedOrphanShifts;
  List<_FormItem>? _cachedUnlinkedForms;
  double? _cachedPenaltyPerMissing;
  bool _isLoadingDayData = true;
  
  @override
  void initState() {
    super.initState();
    // Preload all form labels in background for instant display
    _preloadFormLabels();
    // Pre-compute grouped data once
    _computeGroupedData(); // Fire and forget - async operation
  }

  void _preloadFormLabels() {
    // Preload labels for all forms in background
    for (var form in widget.audit.detailedForms) {
      final formId = form['id'] as String? ?? '';
      if (formId.isNotEmpty) {
        // Fire and forget - cache will be ready when user expands
        FormLabelsCacheService().getLabelsForFormResponse(formId);
      }
    }
  }
  
  /// **OPTIMIZATION: Compute grouped data once and cache it (synchronous – no Firestore in loop).**
  Future<void> _computeGroupedData() async {
    if (_cachedDayItems != null) {
      _isLoadingDayData = false;
      return; // Already computed
    }
    
    if (mounted) {
      setState(() {
        _isLoadingDayData = true;
      });
    }
    
    // Build shiftId -> start DateTime from in-memory detailedShifts (no Firestore)
    final shiftIdToStart = <String, DateTime>{};
    for (var shift in widget.audit.detailedShifts) {
      final shiftId = shift['id'] as String? ?? '';
      final start = shift['start'] as Timestamp?;
      if (shiftId.isNotEmpty && start != null) {
        shiftIdToStart[shiftId] = start.toDate();
      }
    }
    
    // Build lookup maps for O(1) access
    final shiftFormMap = <String, String>{}; // shiftId -> formId
    
    for (var form in widget.audit.detailedForms) {
      final formId = form['id'] as String? ?? '';
      final shiftId = form['shiftId'] as String?;
      if (formId.isNotEmpty && shiftId != null && shiftId.isNotEmpty) {
        shiftFormMap[shiftId] = formId;
      }
    }
    
    // Group shifts by day (1-31)
    final shiftsByDay = <int, List<_ShiftItem>>{};
    final orphanShifts = <_ShiftItem>[];
    
    for (var shift in widget.audit.detailedShifts) {
      final start = (shift['start'] as Timestamp).toDate();
      final day = start.day;
      final shiftId = shift['id'] as String? ?? '';
      final status = shift['status'] as String? ?? 'scheduled';
      
      final title = shift['title'] as String? ?? 'Unknown';
      final subject = shift['subject'] as String? ?? 'Other';
      final scheduledHours = (shift['duration'] as num?)?.toDouble() ?? 0;
      final workedHours = (shift['workedHours'] as num?)?.toDouble() ?? 
                         ((shift['workedMinutes'] as num?)?.toInt() ?? 0) / 60.0;
      
      final hasForm = shiftFormMap.containsKey(shiftId);
      final linkedFormId = shiftFormMap[shiftId];
      
      final shiftItem = _ShiftItem(
        shiftId: shiftId,
        date: start,
        studentName: _extractStudentNameFromTitle(title),
        subject: subject,
        status: status,
        hasForm: hasForm,
        linkedFormId: linkedFormId,
        scheduledHours: scheduledHours,
        workedHours: workedHours,
      );
      
      (shiftsByDay[day] ??= []).add(shiftItem);
      
      if ((status == 'completed' || status == 'fullyCompleted' || status == 'missed') && !hasForm) {
        orphanShifts.add(shiftItem);
      }
    }
    
    // Group forms by day (sync – use shiftIdToStart, no Firestore)
    final formsByDay = <int, List<_FormItem>>{};
    final unlinkedForms = <_FormItem>[];
    
    for (var form in widget.audit.detailedForms) {
      final formId = form['id'] as String? ?? '';
      final shiftId = form['shiftId'] as String?;
      final submittedAt = (form['submittedAt'] as Timestamp?)?.toDate();
      final responses = form['responses'] as Map<String, dynamic>? ?? {};
      
      final dayOfWeek = _extractDayOfWeekFromFormSync(
        responses,
        shiftId,
        form,
        shiftIdToStart,
      );
      
      DateTime? formDate;
      if (shiftId != null && shiftId.isNotEmpty) {
        final shiftEnd = (form['shiftEnd'] as Timestamp?)?.toDate();
        formDate = shiftEnd ?? submittedAt;
      } else {
        formDate = submittedAt;
      }
      
      final durationHours = (form['durationHours'] as num?)?.toDouble() ?? 0;
      final isLinked = shiftId != null && shiftId.isNotEmpty;
      
      final formItem = _FormItem(
        formId: formId,
        submissionDate: submittedAt,
        dayOfWeek: dayOfWeek,
        isLinked: isLinked,
        linkedShiftId: shiftId,
        linkedShiftTitle: form['shiftTitle'] as String?,
        durationHours: durationHours,
        formDate: formDate,
      );
      
      if (formDate != null) {
        (formsByDay[formDate.day] ??= []).add(formItem);
      }
      
      if (!isLinked) {
        unlinkedForms.add(formItem);
      }
    }
    
    // Create day items (merge shifts and forms by day)
    final dayItems = <_AuditDayItem>[];
    final allDays = <int>{...shiftsByDay.keys, ...formsByDay.keys};
    
    for (var day in allDays) {
      final shifts = shiftsByDay[day] ?? [];
      final forms = formsByDay[day] ?? [];
      if (shifts.isNotEmpty || forms.isNotEmpty) {
        // Determine the month and year from first item
        final firstDate = shifts.isNotEmpty 
            ? shifts.first.date 
            : forms.first.formDate!;
        final fullDate = DateTime(firstDate.year, firstDate.month, day);
        
        dayItems.add(_AuditDayItem(
          date: fullDate,
          shifts: shifts,
          forms: forms,
        ));
      }
    }
    
    // Sort by date
    dayItems.sort((a, b) => a.date.compareTo(b.date));
    
    // Cache results
    if (mounted) {
      setState(() {
    _cachedDayItems = dayItems;
    _cachedOrphanShifts = orphanShifts;
    _cachedUnlinkedForms = unlinkedForms;
        _isLoadingDayData = false;
      });
    }
  }
  
  String _extractStudentNameFromTitle(String title) {
    // Try to extract student name from title like "Aliou Diallo - Quran - Abdoulaye Barry"
    final parts = title.split(' - ');
    if (parts.length >= 3) {
      return parts[2]; // Student name is typically the last part
    }
    if (parts.length == 2) {
      return parts[1];
    }
    return title;
  }
  
  /// Sync version: uses in-memory shiftIdToStart only (no Firestore). Keeps grouping fast.
  String? _extractDayOfWeekFromFormSync(
    Map<String, dynamic> responses,
    String? shiftId,
    Map<String, dynamic> formData,
    Map<String, DateTime> shiftIdToStart,
  ) {
    var dayValue = responses['1754406288023'];
    if (dayValue != null) {
      if (dayValue is List && dayValue.isNotEmpty) {
        return dayValue.first.toString();
      }
      return dayValue.toString();
    }
    for (var value in responses.values) {
      if (value is String || (value is List && value.isNotEmpty)) {
        final str = value is List ? value.first.toString() : value.toString();
        if (_isDayOfWeekString(str)) return str;
      }
    }
    if (shiftId != null && shiftId.isNotEmpty) {
      final start = shiftIdToStart[shiftId];
      if (start != null) return _getDayOfWeekFromDate(start);
    }
    final submittedAt = formData['submittedAt'] as Timestamp?;
    if (submittedAt != null) {
      return _getDayOfWeekFromDate(submittedAt.toDate());
    }
    return null;
  }
  
  Future<String?> _extractDayOfWeekFromForm(Map<String, dynamic> responses, String? shiftId, Map<String, dynamic> formData) async {
    // Method 1: Look for Class Day field (ID: 1754406288023) in old forms
    var dayValue = responses['1754406288023'];
    if (dayValue != null) {
      if (dayValue is List && dayValue.isNotEmpty) {
        return dayValue.first.toString();
      }
      return dayValue.toString();
    }
    
    // Method 2: Search for any field containing day names in responses
      for (var value in responses.values) {
        if (value is String || (value is List && value.isNotEmpty)) {
          final str = value is List ? value.first.toString() : value.toString();
          if (_isDayOfWeekString(str)) {
            return str;
          }
        }
      }
    
    // Method 3: For new template forms, derive day from shift date
    if (shiftId != null && shiftId.isNotEmpty) {
      try {
        final shiftDoc = await FirebaseFirestore.instance
            .collection('teaching_shifts')
            .doc(shiftId)
            .get();
        
        if (shiftDoc.exists) {
          final shiftData = shiftDoc.data();
          final shiftStart = shiftData?['shift_start'] as Timestamp?;
          if (shiftStart != null) {
            final shiftDate = shiftStart.toDate();
            return _getDayOfWeekFromDate(shiftDate);
          }
        }
      } catch (e) {
        // If shift fetch fails, continue to next method
        debugPrint('Error fetching shift for day extraction: $e');
      }
    }
    
    // Method 4: Try to get from timesheet if shiftId not available
    final timesheetId = formData['timesheetId'] as String?;
    if (timesheetId != null && timesheetId.isNotEmpty) {
      try {
        final timesheetDoc = await FirebaseFirestore.instance
            .collection('timesheet_entries')
            .doc(timesheetId)
            .get();
        
        if (timesheetDoc.exists) {
          final timesheetData = timesheetDoc.data();
          final shiftIdFromTimesheet = timesheetData?['shift_id'] as String?;
          if (shiftIdFromTimesheet != null) {
            final shiftDoc = await FirebaseFirestore.instance
                .collection('teaching_shifts')
                .doc(shiftIdFromTimesheet)
                .get();
            
            if (shiftDoc.exists) {
              final shiftData = shiftDoc.data();
              final shiftStart = shiftData?['shift_start'] as Timestamp?;
              if (shiftStart != null) {
                final shiftDate = shiftStart.toDate();
                return _getDayOfWeekFromDate(shiftDate);
              }
            }
          }
        }
      } catch (e) {
        // If timesheet/shift fetch fails, continue to next method
        debugPrint('Error fetching timesheet/shift for day extraction: $e');
      }
    }
    
    // Method 5: Fallback to submission date (less accurate but better than N/A)
    final submittedAt = formData['submittedAt'] as Timestamp?;
    if (submittedAt != null) {
      return _getDayOfWeekFromDate(submittedAt.toDate());
    }
    
      return null;
    }
    
  /// Get day of week string from DateTime (e.g., "Mon/Lundi", "Tue/Mardi")
  String _getDayOfWeekFromDate(DateTime date) {
    final weekday = date.weekday; // 1 = Monday, 7 = Sunday
    switch (weekday) {
      case 1:
        return 'Mon/Lundi';
      case 2:
        return 'Tue/Mardi';
      case 3:
        return 'Wed/Mercredi';
      case 4:
        return 'Thu/Jeudi';
      case 5:
        return 'Fri/Vendredi';
      case 6:
        return 'Sat/Samedi';
      case 7:
        return 'Sun/Dimanche';
      default:
        return 'Unknown';
    }
  }
  
  bool _isDayOfWeekString(String value) {
    final lower = value.toLowerCase();
    return lower.contains('mon') || lower.contains('lundi') ||
           lower.contains('tues') || lower.contains('mardi') ||
           lower.contains('wed') || lower.contains('mercredi') ||
           lower.contains('thur') || lower.contains('jeudi') ||
           lower.contains('fri') || lower.contains('vendredi') ||
           lower.contains('sat') || lower.contains('samedi') ||
           lower.contains('sun') || lower.contains('dimanche');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with close button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
          ),
          child: Row(
            children: [
              // Close button
              IconButton(
                icon: const Icon(Icons.close, size: 22, color: Colors.grey),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: AppLocalizations.of(context)!.commonClose,
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                  radius: 20,
                  backgroundColor: _getTierColor(widget.audit.performanceTier).withOpacity(0.1),
                  child: Text(
                    widget.audit.teacherName.isNotEmpty ? widget.audit.teacherName[0].toUpperCase() : '?',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _getTierColor(widget.audit.performanceTier),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.audit.teacherName,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.audit.teacherEmail} • ${widget.audit.yearMonth}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getTierColor(widget.audit.performanceTier).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getTierColor(widget.audit.performanceTier).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${widget.audit.overallScore.toStringAsFixed(0)}%',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _getTierColor(widget.audit.performanceTier),
                        ),
                      ),
                      Text(
                        widget.audit.performanceTier.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: _getTierColor(widget.audit.performanceTier),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        // Scrollable content
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // ============================================================
              // SECTION 1: ALL STATS FIRST
              // ============================================================
              // **SUMMARY SECTION FIRST** - Schedule, Punctuality, and Form Compliance
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Schedule'),
                        const SizedBox(height: 8),
                        _DetailRow('Scheduled', '${widget.audit.totalClassesScheduled}'),
                        _DetailRow('Completed', '${widget.audit.totalClassesCompleted}'),
                        _DetailRow('Missed', '${widget.audit.totalClassesMissed}'),
                        _DetailRow('Completion Rate', '${widget.audit.completionRate.toStringAsFixed(1)}%'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Punctuality'),
                        const SizedBox(height: 8),
                        _DetailRow('Total Clock-Ins', '${widget.audit.totalClockIns}'),
                        _DetailRow('On-Time', '${widget.audit.onTimeClockIns}'),
                        _DetailRow('Late', '${widget.audit.lateClockIns}'),
                        _DetailRow('Punctuality Rate', '${widget.audit.punctualityRate.toStringAsFixed(1)}%'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Form Compliance'),
                        const SizedBox(height: 8),
                        _DetailRow('Required', '${widget.audit.readinessFormsRequired}'),
                        _DetailRow('Readiness Forms Submitted', '${widget.audit.readinessFormsSubmitted}'),
                        if (widget.audit.detailedFormsNoSchedule.isNotEmpty)
                          _DetailRow('With no schedule', '${widget.audit.detailedFormsNoSchedule.length}'),
                        _DetailRow('Compliance Rate', '${widget.audit.formComplianceRate.toStringAsFixed(1)}%'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Hours by Subject
              _buildSectionHeader('Hours by Subject'),
              const SizedBox(height: 8),
              ...widget.audit.hoursTaughtBySubject.entries.map((e) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          e.key,
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade800),
                        ),
                        Text(
                          '${e.value.toStringAsFixed(1)}h',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 24),
              
              // ============================================================
              // SECTION 2: EDIT CONTROLS
              // ============================================================
              // **NEW: Forms Compliance Summary with Penalty** (moved before Individual Shift Payouts)
              _FormsComplianceSummary(
                audit: widget.audit,
                orphanShifts: _cachedOrphanShifts ?? [],
                unlinkedForms: _cachedUnlinkedForms ?? [],
                onApplyPenalty: _applyFormPenalty,
              ),
              const SizedBox(height: 12),
              
              // ============================================================
              // SECTION 3: FORMS LIST (Shifts & Forms by Day)
              // ============================================================
                _buildSectionHeader('Shifts & Forms by Day'),
                const SizedBox(height: 12),
              if (_isLoadingDayData) ...[
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ] else if (_cachedDayItems != null && _cachedDayItems!.isNotEmpty) ...[
                ..._cachedDayItems!.map((dayItem) => _DaySection(
                  dayItem: dayItem,
                  orphanShifts: _cachedOrphanShifts ?? [],
                  unlinkedForms: _cachedUnlinkedForms ?? [],
                  onLinkFormToShift: _linkFormToShift,
                  parentContext: context,
                )),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.noShiftsOrFormsFoundFor,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              // Forms with no schedule (same total as All Submissions so auditor can decide)
              if (widget.audit.detailedFormsNoSchedule.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSectionHeader('${AppLocalizations.of(context)!.formsWithNoSchedule} (${widget.audit.detailedFormsNoSchedule.length})'),
                const SizedBox(height: 8),
                ...widget.audit.detailedFormsNoSchedule.map((map) {
                  final formId = (map['id'] as String?) ?? '';
                  final submittedAt = (map['submittedAt'] as Timestamp?)?.toDate();
                  final formItem = _FormItem(
                    formId: formId,
                    submissionDate: submittedAt,
                    dayOfWeek: null,
                    isLinked: false,
                    linkedShiftId: null,
                    linkedShiftTitle: null,
                    durationHours: (map['durationHours'] as num?)?.toDouble() ?? 0,
                    formDate: submittedAt,
                  );
                  return _FormRow(
                    form: formItem,
                    formData: map,
                    orphanShifts: const [],
                    onLinkFormToShift: _linkFormToShift,
                    parentContext: context,
                  );
                }),
              ],
              if (widget.audit.issues.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildSectionHeader('Issues'),
                const SizedBox(height: 8),
                ...widget.audit.issues.map((issue) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.shade200, width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, size: 14, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              issue.description,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.red.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade900,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'excellent':
        return Colors.green;
      case 'good':
        return Colors.blue;
      case 'needsImprovement':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }
  
  /// Link a form to a shift manually
  Future<void> _linkFormToShift(String formId, String shiftId) async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text(AppLocalizations.of(context)!.linkingFormAndRecalculatingPayment),
              ],
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
      
      final success = await TeacherAuditService.linkFormToShift(
        formId: formId,
        shiftId: shiftId,
      );
      
      if (success && mounted) {
        // Refresh audit list to show updated payment
        final parentState = context.findAncestorStateOfType<_AdminAuditScreenState>();
        if (parentState != null) {
          await parentState._loadAudits(force: true);
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!.formLinkedToShiftSuccessfullyPayment),
            backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
          ),
        );
        }
        
        // Refresh audit data - invalidate cache
        setState(() {
          _cachedDayItems = null;
          _cachedOrphanShifts = null;
          _cachedUnlinkedForms = null;
          _isLoadingDayData = true;
        });
        _computeGroupedData(); // Fire and forget - async operation
      } else if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedToLinkFormToShift),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorE),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _showAuditDetails(TeacherAuditFull audit) {
    // Helper (e.g. after payment update) – same full-height side panel as main screen
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: AppLocalizations.of(context)?.commonClose ?? 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.25),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 680,
              height: double.infinity,
              margin: const EdgeInsets.only(top: 0, right: 0, bottom: 0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 24,
                    offset: const Offset(-4, 0),
                  ),
                ],
              ),
              child: _AuditDetailFullPanel(audit: audit),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  Future<void> _applyFormPenalty(double penaltyPerMissing) async {
    if (penaltyPerMissing <= 0) return;
    
    final missingForms = widget.audit.readinessFormsRequired - widget.audit.readinessFormsSubmitted;
    final totalPenalty = missingForms * penaltyPerMissing;
    
    try {
      final success = await TeacherAuditService.applyFormPenalty(
        auditId: widget.audit.id,
        penaltyPerMissing: penaltyPerMissing,
        missingFormsCount: missingForms,
      );
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Penalty of \$${totalPenalty.toStringAsFixed(2)} applied'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh audit - reload from Firestore
        Navigator.of(context).pop();
        // Trigger parent refresh will happen when modal closes
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorApplyingPenaltyE),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade900,
            ),
          ),
        ],
      ),
    );
  }
}

/// **Forms Compliance Summary Widget with Penalty Input**
class _FormsComplianceSummary extends StatefulWidget {
  final TeacherAuditFull audit;
  final List<_ShiftItem> orphanShifts;
  final List<_FormItem> unlinkedForms;
  final Function(double) onApplyPenalty;

  const _FormsComplianceSummary({
    required this.audit,
    required this.orphanShifts,
    required this.unlinkedForms,
    required this.onApplyPenalty,
  });

  @override
  State<_FormsComplianceSummary> createState() => _FormsComplianceSummaryState();
}

class _FormsComplianceSummaryState extends State<_FormsComplianceSummary> {
  final TextEditingController _penaltyController = TextEditingController();
  bool _isApplying = false;

  @override
  void dispose() {
    _penaltyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final planned = widget.audit.readinessFormsRequired;
    final submitted = widget.audit.readinessFormsSubmitted;
    final missing = planned - submitted;
    final penaltyPerMissing = double.tryParse(_penaltyController.text) ?? 0.0;
    final totalPenalty = missing * penaltyPerMissing;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_turned_in, size: 18, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.formsCompliance,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stats row
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  label: 'Planned',
                  value: '$planned',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatBox(
                  label: 'Submitted',
                  value: '$submitted',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatBox(
                  label: 'Missing',
                  value: '$missing',
                  color: missing > 0 ? Colors.red : Colors.grey,
                ),
              ),
            ],
          ),
          if (missing > 0) ...[
            const SizedBox(height: 12),
            Divider(color: Colors.blue.shade200),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.penaltyPerMissing,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _penaltyController,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          prefixText: '\$',
                          prefixStyle: GoogleFonts.inter(color: Colors.grey.shade700),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                        ),
                        style: GoogleFonts.inter(fontSize: 13),
                        onChanged: (value) => setState(() {}), // Rebuild to update total
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.totalPenalty,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          '\$${totalPenalty.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: totalPenalty > 0 ? Colors.red.shade700 : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isApplying || penaltyPerMissing <= 0
                    ? null
                    : () async {
                        setState(() => _isApplying = true);
                        await widget.onApplyPenalty(penaltyPerMissing);
                        if (mounted) {
                          setState(() => _isApplying = false);
                          _penaltyController.clear();
                        }
                      },
                icon: _isApplying
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(Icons.attach_money, size: 16),
                label: Text(
                  _isApplying ? 'Applying...' : 'Apply Penalty',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// **Orphan Shifts Penalty Section**
class _OrphanShiftsPenaltySection extends StatefulWidget {
  final List<_ShiftItem> orphanShifts;
  final Function(double) onApplyPenalty;

  const _OrphanShiftsPenaltySection({
    required this.orphanShifts,
    required this.onApplyPenalty,
  });

  @override
  State<_OrphanShiftsPenaltySection> createState() => _OrphanShiftsPenaltySectionState();
}

class _OrphanShiftsPenaltySectionState extends State<_OrphanShiftsPenaltySection> {
  final TextEditingController _penaltyController = TextEditingController();
  bool _isApplying = false;

  @override
  void dispose() {
    _penaltyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.orphanShifts.length;
    final penaltyPerShift = double.tryParse(_penaltyController.text) ?? 0.0;
    final totalPenalty = count * penaltyPerShift;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.shiftsWithoutForms,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  AppLocalizations.of(context)!.count,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.theseShiftsWereCompletedButNo,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.penaltyPerShift,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _penaltyController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        prefixText: '\$',
                        prefixStyle: GoogleFonts.inter(color: Colors.grey.shade700),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.orange.shade400, width: 1.5),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                      ),
                      style: GoogleFonts.inter(fontSize: 13),
                      onChanged: (value) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.totalPenalty,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        '\$${totalPenalty.toStringAsFixed(2)} ($count × \$${penaltyPerShift.toStringAsFixed(2)})',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: totalPenalty > 0 ? Colors.red.shade700 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isApplying || penaltyPerShift <= 0
                  ? null
                  : () async {
                      setState(() => _isApplying = true);
                      await widget.onApplyPenalty(penaltyPerShift);
                      if (mounted) {
                        setState(() => _isApplying = false);
                        _penaltyController.clear();
                      }
                    },
              icon: _isApplying
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(Icons.attach_money, size: 16),
              label: Text(
                _isApplying ? 'Applying...' : 'Apply Penalty',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// **User-friendly Stat Card** - Shows label and value clearly
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final String? badge;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Win11Colors.border.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Win11Colors.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Win11Colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Win11Colors.textMain,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge!,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// **Compact Stat Widget** - Minimal inline stat display for header (kept for backward compatibility)
class _CompactStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color iconColor;
  final String? badge;

  const _CompactStat({
    required this.icon,
    required this.value,
    required this.iconColor,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor), // Very small icon
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badge!,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Admin form card with expandable details
class _AdminFormCard extends StatefulWidget {
  final Map<String, dynamic> form;
  final int index;
  final BuildContext parentContext;

  const _AdminFormCard({
    required this.form,
    required this.index,
    required this.parentContext,
  });

  @override
  State<_AdminFormCard> createState() => _AdminFormCardState();
}

class _AdminFormCardState extends State<_AdminFormCard> {
  @override
  Widget build(BuildContext context) {
    final submittedAt = _parseTimestamp(widget.form['submittedAt']);
    final shiftEnd = _parseTimestamp(widget.form['shiftEnd']);
    final shiftTitle = widget.form['shiftTitle'] ?? 'Not linked';
    final delayHours = (widget.form['delayHours'] as num?)?.toDouble() ?? 0.0;
    final responses = widget.form['responses'] as Map<String, dynamic>? ?? {};
    final formId = widget.form['id'] ?? 'N/A';
    final shiftId = widget.form['shiftId'] ?? 'N/A';

    // Determine delay status
    Color statusColor;
    IconData statusIcon;
    String statusText;
    if (delayHours <= 24) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'On-Time';
    } else if (delayHours <= 48) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
      statusText = 'Late';
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.error;
      statusText = 'Very Late';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _showFormDetailsModal(context, widget.form),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${widget.index}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          shiftTitle,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.grey.shade900,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(statusIcon, size: 11, color: statusColor),
                                  const SizedBox(width: 3),
                                  Text(
                                    statusText,
                                    style: GoogleFonts.inter(
                                      color: statusColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (delayHours > 0)
                              Text(
                                '+${delayHours.toStringAsFixed(1)}h',
                                style: GoogleFonts.inter(
                                  color: Colors.grey.shade600,
                                  fontSize: 10,
                                ),
                              ),
                            Text(
                              _formatDate(submittedAt),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.visibility_outlined, size: 20),
                    color: Colors.grey.shade600,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: AppLocalizations.of(context)!.viewFormDetails,
                    onPressed: () => _showFormDetailsModal(context, widget.form),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is Map && value.containsKey('_seconds')) {
      return DateTime.fromMillisecondsSinceEpoch(value['_seconds'] * 1000);
    }
    return null;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('MMM d, h:mm a').format(date);
  }
  
  /// Show form details using same dialog as Admin All Submissions (Form Details modal)
  void _showFormDetailsModal(BuildContext context, Map<String, dynamic> form) {
    FormDetailsModal.show(
      context,
      formId: (form['id'] ?? '').toString(),
      shiftId: (form['shiftId'] ?? 'N/A').toString(),
      responses: form['responses'] as Map<String, dynamic>? ?? {},
    );
  }
}

class _MetadataRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetadataRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              AppLocalizations.of(context)!.label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// **Day Section Widget** - Displays shifts and forms for a specific day
class _DaySection extends StatelessWidget {
  final _AuditDayItem dayItem;
  final List<_ShiftItem> orphanShifts;
  final List<_FormItem> unlinkedForms;
  final Function(String formId, String shiftId) onLinkFormToShift;
  final BuildContext parentContext;

  const _DaySection({
    required this.dayItem,
    required this.orphanShifts,
    required this.unlinkedForms,
    required this.onLinkFormToShift,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Day ${dayItem.date.day} ${DateFormat('MMMM').format(dayItem.date)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade900,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Shifts for this day
                if (dayItem.shifts.isNotEmpty)
                  ...dayItem.shifts.map((shift) => _ShiftRow(
                        shift: shift,
                        orphanShifts: orphanShifts,
                        unlinkedForms: unlinkedForms,
                        onLinkFormToShift: onLinkFormToShift,
                        parentContext: parentContext,
                      )),
                // Forms for this day
                if (dayItem.forms.isNotEmpty)
                  ...dayItem.forms.map((form) {
                    // Find form data from audit
                    final audit = (parentContext.findAncestorStateOfType<_AuditDetailSheetState>()?.widget as _AuditDetailSheet?)?.audit;
                    final formData = audit?.detailedForms.firstWhere(
                      (f) => f['id'] == form.formId,
                      orElse: () => <String, dynamic>{'id': form.formId},
                    ) ?? {'id': form.formId};
                    return _FormRow(
                      form: form,
                      formData: formData,
                      orphanShifts: orphanShifts,
                      onLinkFormToShift: onLinkFormToShift,
                      parentContext: parentContext,
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// **Shift Row Widget** - Displays a shift with form status
class _ShiftRow extends StatelessWidget {
  final _ShiftItem shift;
  final List<_ShiftItem> orphanShifts;
  final List<_FormItem> unlinkedForms;
  final Function(String formId, String shiftId) onLinkFormToShift;
  final BuildContext parentContext;

  const _ShiftRow({
    required this.shift,
    required this.orphanShifts,
    required this.unlinkedForms,
    required this.onLinkFormToShift,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = '${DateFormat('HH:mm').format(shift.date)}';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: shift.hasForm ? Colors.green.shade200 : Colors.orange.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.school,
                size: 16,
                color: shift.hasForm ? Colors.green.shade700 : Colors.orange.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${shift.studentName} - ${shift.subject}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
                  ),
                ),
              ),
              Text(
                timeStr,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (shift.hasForm)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: shift.status == 'missed'
                    ? Colors.blue.shade50
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    shift.status == 'missed' ? Icons.update : Icons.check_circle,
                    size: 12,
                    color: shift.status == 'missed'
                        ? Colors.blue.shade700
                        : Colors.green.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    shift.status == 'missed'
                        ? AppLocalizations.of(context)!.missedClassFormSubmittedRecovery
                        : AppLocalizations.of(context)!.formSubmitted,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: shift.status == 'missed'
                          ? Colors.blue.shade700
                          : Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 12, color: Colors.orange.shade700),
                  const SizedBox(width: 4),
                  Text(
                    AppLocalizations.of(context)!.noForm,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Link button if unlinked forms available
                  if (unlinkedForms.isNotEmpty)
                    InkWell(
                      onTap: () => _showLinkFormDialog(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.linkForm,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Warning and ban button for orphan shift
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.shade200, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.teacherDidNotSubmitReadinessForm,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: Colors.grey.shade700,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Ban shift button
                  OutlinedButton(
                    onPressed: () => _banShift(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(6),
                      side: BorderSide(color: Colors.red.shade300),
                      foregroundColor: Colors.red.shade700,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.block, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          AppLocalizations.of(context)!.banShift,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  void _showLinkFormDialog(BuildContext context) {
    // Filter unlinked forms by date proximity (within 2 days)
    final nearbyForms = unlinkedForms.where((form) {
      if (form.formDate == null) return false;
      final daysDiff = (form.formDate!.difference(shift.date)).abs().inDays;
      return daysDiff <= 2;
    }).toList();
    
    if (nearbyForms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.noUnlinkedFormsFoundNearby)),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.linkFormToShift),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: nearbyForms.length,
            itemBuilder: (context, index) {
              final form = nearbyForms[index];
              final dateStr = form.submissionDate != null
                  ? DateFormat('MMM d, h:mm a').format(form.submissionDate!)
                  : 'No date';
              return ListTile(
                title: Text('Day: ${form.dayOfWeek ?? "N/A"}'),
                subtitle: Text(AppLocalizations.of(context)!.submittedDatestr),
                trailing: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onLinkFormToShift(form.formId, shift.shiftId);
                  },
                  child: Text(AppLocalizations.of(context)!.link),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
  
  void _banShift(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.banShift),
        content: Text(
          AppLocalizations.of(context)!.confirmBanShiftMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Mark shift as banned in Firestore
              try {
                await FirebaseFirestore.instance.collection('teaching_shifts').doc(shift.shiftId).update({
                  'isBanned': true,
                  'bannedAt': FieldValue.serverTimestamp(),
                  'bannedReason': 'No readiness form submitted',
                });
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!.shiftBannedSuccessfullyRecalculatingAudit),
                      backgroundColor: Colors.green,
                    ),
                  );
                  
                  // Recalculate audit after banning shift
                  final auditSheetState = context.findAncestorStateOfType<_AuditDetailSheetState>();
                  if (auditSheetState != null && context.mounted) {
                    // Trigger recalculation
                    final teacherId = auditSheetState.widget.audit.oderId;
                    final yearMonth = auditSheetState.widget.audit.yearMonth;
                    await TeacherAuditService.computeAuditForTeacher(
                      userId: teacherId,
                      yearMonth: yearMonth,
                    );
                    // Reload by closing detail modal - parent will refresh
                    Navigator.of(context).pop(); // Close audit detail
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!.errorBanningShiftE),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.banShift),
          ),
        ],
      ),
    );
  }
}

/// **Form Row Widget** - Displays a form with link status
class _FormRow extends StatelessWidget {
  final _FormItem form;
  final Map<String, dynamic> formData; // Pass full form data from parent
  final List<_ShiftItem> orphanShifts;
  final Function(String formId, String shiftId) onLinkFormToShift;
  final BuildContext parentContext;

  const _FormRow({
    required this.form,
    required this.formData,
    required this.orphanShifts,
    required this.onLinkFormToShift,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    final form = this.form;
    final formData = this.formData;
    final parentContext = this.parentContext;
    final dateStr = form.submissionDate != null
        ? DateFormat('MMM d, h:mm a').format(form.submissionDate!)
        : '—';
    final l10n = AppLocalizations.of(context)!;
    // Same format as Admin All Submissions list: date left, status badge, chevron; tap opens FormDetailsModal
    final statusLabel = form.isLinked ? l10n.commonDone : l10n.adminSubmissionsPending;
    final statusColor = form.isLinked ? const Color(0xff16A34A) : const Color(0xffF59E0B);
    final statusBgColor = form.isLinked ? const Color(0xffDCFCE7) : const Color(0xffFEF3C7);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: form.isLinked ? Colors.green.shade200 : Colors.blue.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _showFormDetailsModal(context, formData, form.formId, form.linkedShiftId ?? 'N/A', parentContext),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: form.isLinked
                    ? null
                    : const Border(
                        bottom: BorderSide(color: Color(0xffF1F5F9), width: 0.5),
                      ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 150,
                    child: Text(
                      dateStr,
                      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xff475569)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 20, color: Color(0xff94A3B8)),
                ],
              ),
            ),
          ),
          if (!form.isLinked) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.shade300, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.noShiftAssociated,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.thisFormIndicatesTheTeacherConducted,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Link to existing orphan shift
                      if (orphanShifts.isNotEmpty)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showLinkShiftDialog(context),
                            icon: Icon(Icons.link, size: 14),
                            label: Text(AppLocalizations.of(context)!.linkToShift, style: GoogleFonts.inter(fontSize: 10)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              side: BorderSide(color: Colors.blue.shade300),
                              foregroundColor: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      if (orphanShifts.isNotEmpty) const SizedBox(width: 8),
                      // Create new shift
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showCreateShiftDialog(context),
                          icon: Icon(Icons.add, size: 14),
                          label: Text(AppLocalizations.of(context)!.createShift, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Ban form
                      OutlinedButton(
                        onPressed: () => _banForm(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(8),
                          side: BorderSide(color: Colors.red.shade300),
                          foregroundColor: Colors.red.shade700,
                        ),
                        child: Icon(Icons.block, size: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  void _showLinkShiftDialog(BuildContext context) {
    // Filter orphan shifts by date proximity
    final nearbyShifts = orphanShifts.where((shift) {
      if (form.formDate == null) return true;
      final daysDiff = (shift.date.difference(form.formDate!)).abs().inDays;
      return daysDiff <= 2;
    }).toList();
    
    if (nearbyShifts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.noOrphanShiftsFoundNearby)),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.linkFormToShift),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: nearbyShifts.length,
            itemBuilder: (context, index) {
              final shift = nearbyShifts[index];
              final timeStr = DateFormat('MMM d, HH:mm').format(shift.date);
              return ListTile(
                title: Text('${shift.studentName} - ${shift.subject}'),
                subtitle: Text(timeStr),
                trailing: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onLinkFormToShift(form.formId, shift.shiftId);
                  },
                  child: Text(AppLocalizations.of(context)!.link),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
  
  void _showFormDetailsModal(BuildContext context, Map<String, dynamic> formData, String formId, String shiftId, BuildContext parentContext) {
    // If formData doesn't have responses, fetch from Firestore then show same dialog as Admin All Submissions
    if ((formData['responses'] as Map<String, dynamic>?)?.isEmpty ?? true) {
      _fetchFormDataAndShowModal(context, formId, shiftId);
    } else {
      FormDetailsModal.show(
        context,
        formId: formData['id'] ?? formId,
        shiftId: formData['shiftId'] ?? shiftId,
        responses: formData['responses'] as Map<String, dynamic>? ?? {},
      );
    }
  }

  Future<void> _fetchFormDataAndShowModal(BuildContext context, String formId, String shiftId) async {
    try {
      final formDoc = await FirebaseFirestore.instance.collection('form_responses').doc(formId).get();
      if (formDoc.exists) {
        final data = formDoc.data() as Map<String, dynamic>;
        final responses = data['responses'] as Map<String, dynamic>? ?? {};
        if (context.mounted) {
          FormDetailsModal.show(context, formId: formId, shiftId: shiftId, responses: responses);
        }
      } else {
        if (context.mounted) {
          FormDetailsModal.show(context, formId: formId, shiftId: shiftId, responses: {});
        }
      }
    } catch (e) {
      debugPrint('Error fetching form data: $e');
      if (context.mounted) {
        FormDetailsModal.show(context, formId: formId, shiftId: shiftId, responses: {});
      }
    }
  }
  
  void _banForm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.banForm),
        content: Text(AppLocalizations.of(context)!.confirmBanFormMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Mark form as banned in Firestore
              await FirebaseFirestore.instance.collection('form_responses').doc(form.formId).update({
                'isBanned': true,
                'bannedAt': FieldValue.serverTimestamp(),
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context)!.formBannedSuccessfully), backgroundColor: Colors.green),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.ban),
          ),
        ],
      ),
    );
  }
  
  void _showCreateShiftDialog(BuildContext context) async {
    // Extract form data
    final responses = formData['responses'] as Map<String, dynamic>? ?? {};
    
    // Use durationHours from form if available, otherwise parse from responses
    final formDuration = form.durationHours > 0 
        ? form.durationHours 
        : _parseFormDurationFromResponses(responses);
    
    // Get form date (prefer formDate, fallback to submissionDate)
    final formDate = form.formDate ?? form.submissionDate ?? DateTime.now();
    
    // Get teacher ID from audit context
    final auditSheetState = parentContext.findAncestorStateOfType<_AuditDetailSheetState>();
    if (auditSheetState == null) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.unableToFindAuditContext), backgroundColor: Colors.red),
      );
      return;
    }
    
    final teacherId = auditSheetState.widget.audit.oderId;
    final teacherName = auditSheetState.widget.audit.teacherName;
    
    // Extract subject from form responses or use default
    String defaultSubject = 'Quran';
    if (responses.containsKey('subject')) {
      defaultSubject = responses['subject'].toString();
    } else if (responses.containsKey('class_subject')) {
      defaultSubject = responses['class_subject'].toString();
    }
    
    // Create controllers for dialog
    final durationController = TextEditingController(
      text: formDuration > 0 ? formDuration.toStringAsFixed(2) : '1.00',
    );
    final subjectController = TextEditingController(text: defaultSubject);
    bool isProcessing = false;
    
    await showDialog(
      context: context,
      barrierDismissible: !isProcessing,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.add_task, color: Colors.green),
              SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)!.reGularisationAdministrative,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Teacher: $teacherName',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.ceFormulaireNAPasDe,
                  style: GoogleFonts.inter(fontSize: 13),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: subjectController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.sujetDuCours,
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: durationController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.dureEAPayerHeures,
                    suffixText: 'heures',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.lePaiementSeraCalculeDureE,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.blue.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isProcessing ? null : () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.annuler),
            ),
            ElevatedButton(
              onPressed: isProcessing ? null : () async {
                setDialogState(() => isProcessing = true);
                
                final finalDuration = double.tryParse(durationController.text.trim()) ?? formDuration;
                if (finalDuration <= 0) {
                  setDialogState(() => isProcessing = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!.laDureEDoitETre),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                final finalSubject = subjectController.text.trim();
                if (finalSubject.isEmpty) {
                  setDialogState(() => isProcessing = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!.leSujetEstRequis),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                // Call the service method to create shift from form
                final success = await TeacherAuditService.createShiftFromUnlinkedForm(
                  formId: form.formId,
                  teacherId: teacherId,
                  date: formDate,
                  durationHours: finalDuration,
                  subject: finalSubject,
                );
                
                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context)!.shiftCreEEtPaiementSynchronise),
                        backgroundColor: Colors.green,
                      ),
                    );
                    
                    // Refresh audit parent
                    final parentState = parentContext.findAncestorStateOfType<_AdminAuditScreenState>();
                    if (parentState != null) {
                      await parentState._loadAudits(force: true);
                    }
                    
                    // Close detail sheet to show updated audit
                    if (context.mounted) {
                      Navigator.of(parentContext).pop();
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context)!.erreurLorsDeLaCreAtion),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(AppLocalizations.of(context)!.creErPayer),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Parse duration from form responses (using same logic as TeacherAuditService)
  double _parseFormDurationFromResponses(Map<String, dynamic> responses) {
    try {
      // Try known field names first
      var durationValue = responses['actual_duration'] ?? 
                         responses['1754406414139'] ?? 
                         responses['class_duration'];
      
      // Search if not found
      if (durationValue == null && responses.isNotEmpty) {
        for (final entry in responses.entries.take(10)) {
          final value = entry.value;
          if (value is String) {
            final lower = value.toLowerCase();
            if (lower.contains('hour') || lower.contains('duration')) {
              durationValue = value;
              break;
            }
          }
        }
      }
      
      if (durationValue == null) return 0;
      
      String durationStr = durationValue.toString().trim();
      if (durationStr.isEmpty) return 0;
      
      // Try direct parse first
      final directParse = double.tryParse(durationStr);
      if (directParse != null) return directParse;
      
      // Clean and parse
      durationStr = durationStr.replaceAll(RegExp(r'[^\d.]'), ' ').trim();
      if (durationStr.isEmpty) return 0;
      
      final parts = durationStr.split(' ');
      if (parts.isEmpty) return 0;
      
      final mainPart = parts[0];
      if (mainPart.contains('.')) {
        final decimalParts = mainPart.split('.');
        if (decimalParts.length == 2) {
          final hours = double.tryParse(decimalParts[0]) ?? 0;
          final minutes = double.tryParse(decimalParts[1]) ?? 0;
          
          if (minutes >= 60) {
            return hours + (minutes / 100); // "1.75" = 1.75 hours
          } else {
            return hours + (minutes / 60); // "1.30" = 1 hour 30 min
          }
        }
      }
      
      final parsed = double.tryParse(mainPart);
      return parsed ?? 0;
    } catch (e) {
      return 0;
    }
  }
}

/// Export Dialog with teacher filter and global export options
class _ExportDialog extends StatefulWidget {
  final List<TeacherAuditFull> audits;
  final List<TeacherAuditFull> allAudits;
  final String selectedYearMonth;

  const _ExportDialog({
    required this.audits,
    required this.allAudits,
    required this.selectedYearMonth,
  });

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  String? _selectedTeacherId;
  bool _exportAllMonths = false;
  bool _isExporting = false;
  List<String> _availableMonths = [];
  Map<String, List<TeacherAuditFull>> _allMonthsAudits = {};

  @override
  void initState() {
    super.initState();
    _loadAvailableMonths();
  }

  Future<void> _loadAvailableMonths() async {
    try {
      // Get all months with audits
      final snapshot = await FirebaseFirestore.instance
          .collection('teacher_audits')
          .orderBy('yearMonth', descending: true)
          .get();
      
      final months = snapshot.docs
          .map((doc) => doc.data()['yearMonth'] as String?)
          .where((m) => m != null)
          .cast<String>()
          .toSet()
          .toList();
      
      setState(() {
        _availableMonths = months;
      });
    } catch (e) {
      debugPrint('Error loading available months: $e');
    }
  }

  List<TeacherAuditFull> get _filteredAudits {
    var audits = widget.audits;
    if (_selectedTeacherId != null && _selectedTeacherId!.isNotEmpty) {
      audits = audits.where((a) => a.oderId == _selectedTeacherId).toList();
    }
    return audits;
  }

  // Get unique teachers from audits
  List<Map<String, String>> get _teachers {
    final teacherMap = <String, Map<String, String>>{};
    for (var audit in widget.allAudits) {
      if (!teacherMap.containsKey(audit.oderId)) {
        teacherMap[audit.oderId] = {
          'id': audit.oderId,
          'name': audit.teacherName,
          'email': audit.teacherEmail,
        };
      }
    }
    return teacherMap.values.toList()
      ..sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
  }

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);
    
    try {
      if (_exportAllMonths) {
        // Export all months
        await _exportAllMonthsData();
      } else {
        // Export current month with filter
        final auditsToExport = _filteredAudits;
        if (auditsToExport.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.noDataToExportWithCurrent),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() => _isExporting = false);
          return;
        }
        
        await AdvancedExcelExportService.exportToExcel(
          audits: auditsToExport,
          yearMonth: widget.selectedYearMonth,
          locale: Localizations.localeOf(context).languageCode,
        );
      }
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.excelReportExportedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorExportingE),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportAllMonthsData() async {
    // PARALLEL LOADING: Load all months simultaneously for speed
    final List<Future<List<TeacherAuditFull>>> futures = _availableMonths.map(
      (month) => TeacherAuditService.getAuditsForMonth(yearMonth: month)
    ).toList();
    
    // Wait for all months to load in parallel
    final List<List<TeacherAuditFull>> allMonthsResults = await Future.wait(futures);
    
    // Flatten and filter results
    List<TeacherAuditFull> allAudits = [];
    for (var monthAudits in allMonthsResults) {
      if (_selectedTeacherId != null && _selectedTeacherId!.isNotEmpty) {
        allAudits.addAll(monthAudits.where((a) => a.oderId == _selectedTeacherId));
      } else {
        allAudits.addAll(monthAudits);
      }
    }
    
    if (allAudits.isEmpty) {
      throw Exception('No audit data found');
    }
    
    // Export with "all" indicator - includes new pivot tables
    await AdvancedExcelExportService.exportToExcel(
      audits: allAudits,
      yearMonth: 'all_months',
      locale: Localizations.localeOf(context).languageCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600), // Limit dialog height
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xff217346).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.table_chart, color: Color(0xff217346), size: 24),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.exportAuditReport,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      Text(
                        AppLocalizations.of(context)!.excelWithMonthlyPivotTables,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Filter by Teacher
            Text(
              AppLocalizations.of(context)!.filterByTeacher,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxWidth: double.infinity),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonFormField<String?>(
                value: _selectedTeacherId,
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: InputBorder.none,
                  hintText: AppLocalizations.of(context)!.allTeachers,
                ),
                items: [
                   DropdownMenuItem(
                    value: null,
                    child: Text(AppLocalizations.of(context)!.allTeachers, overflow: TextOverflow.ellipsis),
                  ),
                  ..._teachers.map((t) => DropdownMenuItem<String?>(
                    value: t['id'],
                    child: Text(
                      '${t['name']} (${t['email']})',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  )),
                ],
                onChanged: (value) => setState(() => _selectedTeacherId = value),
              ),
            ),
            const SizedBox(height: 16),
            
            // Global Export Toggle with improved description
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _exportAllMonths,
                    onChanged: (value) => setState(() => _exportAllMonths = value ?? false),
                    activeColor: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.exportAllMonthsPivotView,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        Text(
                          _availableMonths.isEmpty 
                              ? 'Loading available months...'
                              : '${_availableMonths.length} months available - Parallel loading',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // New: Preview of sheets included
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF217346).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF217346).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.sheetsIncludedInExport,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF217346),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _buildSheetChip('🎯', 'Dashboard'),
                      _buildSheetChip('📋', 'Activité'),
                      _buildSheetChip('💰', 'Paiement'),
                      _buildSheetChip('📝', 'Evaluation'),
                      _buildSheetChip('✅', 'Reviews'),
                      _buildSheetChip('🏖️', 'Leave Requests'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _exportAllMonths
                          ? 'Export ${_availableMonths.length} months with pivot tables (months as columns, teachers as rows)'
                          : 'Exporting ${_filteredAudits.length} audit(s) for ${widget.selectedYearMonth}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Action Buttons (fixed at bottom)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    AppLocalizations.of(context)!.commonCancel,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isExporting ? null : _handleExport,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.download, size: 18),
                  label: Text(
                    _isExporting ? 'Exporting...' : 'Export Excel',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff217346),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSheetChip(String icon, String description) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        '$icon $description',
        style: GoogleFonts.inter(
          fontSize: 10,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }
}

/// Progress state for audit generation
class _AuditProgressState {
  final double progress;
  final int completed;
  final int total;
  final String currentTeacher;
  final int elapsedSeconds;
  final bool isComplete;

  _AuditProgressState({
    required this.progress,
    required this.completed,
    required this.total,
    this.currentTeacher = '',
    this.elapsedSeconds = 0,
    this.isComplete = false,
  });
}

/// Enhanced progress dialog with animations and fun messages
class _EnhancedProgressDialog extends StatefulWidget {
  final Stream<_AuditProgressState> progressStream;
  final int totalTeachers;
  final List<String> funMessages;
  final DateTime startTime;

  const _EnhancedProgressDialog({
    required this.progressStream,
    required this.totalTeachers,
    required this.funMessages,
    required this.startTime,
  });

  @override
  State<_EnhancedProgressDialog> createState() => _EnhancedProgressDialogState();
}

class _EnhancedProgressDialogState extends State<_EnhancedProgressDialog>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _bounceController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _bounceAnimation;
  
  int _currentMessageIndex = 0;
  Timer? _messageTimer;
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;
  
  _AuditProgressState _currentState = _AuditProgressState(
    progress: 0,
    completed: 0,
    total: 1,
  );

  @override
  void initState() {
    super.initState();
    
    // Pulse animation for the progress ring
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Bounce animation for the icon
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);
    
    _bounceAnimation = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
    
    // Rotate fun messages every 3 seconds
    _messageTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && !_currentState.isComplete) {
        setState(() {
          _currentMessageIndex = (_currentMessageIndex + 1) % widget.funMessages.length;
        });
      }
    });
    
    // Update elapsed time every second
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsedSeconds = DateTime.now().difference(widget.startTime).inSeconds;
        });
      }
    });
    
    // Listen to progress stream
    widget.progressStream.listen((state) {
      if (mounted) {
        setState(() {
          _currentState = state;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bounceController.dispose();
    _messageTimer?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }
  
  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    if (mins > 0) {
      return '${mins}m ${secs}s';
    }
    return '${secs}s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _currentState.progress;
    final isComplete = _currentState.isComplete;
    final completed = _currentState.completed;
    final total = _currentState.total;
    
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated progress indicator
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: isComplete ? 1.0 : _pulseAnimation.value,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background circle
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isComplete 
                                ? Colors.green.shade50 
                                : Colors.blue.shade50,
                          ),
                        ),
                        // Progress ring
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 8,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isComplete ? Colors.green : const Color(0xff0386FF),
                            ),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        // Center icon/text
                        AnimatedBuilder(
                          animation: _bounceAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, isComplete ? 0 : _bounceAnimation.value),
                              child: isComplete
                                  ? Icon(
                                      Icons.check_circle,
                                      size: 48,
                                      color: Colors.green.shade600,
                                    )
                                  : Text(
                                      '${(progress * 100).toStringAsFixed(0)}%',
                                      style: GoogleFonts.inter(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xff0386FF),
                                      ),
                                    ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 24),
              
              // Title
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  isComplete ? '✨ Complete!' : 'Generating Audits',
                  key: ValueKey(isComplete),
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isComplete ? Colors.green.shade700 : Colors.grey.shade900,
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Progress counter with animation
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Container(
                  key: ValueKey(completed),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isComplete ? Colors.green.shade100 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isComplete ? Icons.check : Icons.person,
                        size: 18,
                        color: isComplete ? Colors.green.shade700 : const Color(0xff0386FF),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isComplete 
                            ? '$total teachers processed'
                            : '$completed / $total teachers',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isComplete ? Colors.green.shade700 : const Color(0xff0386FF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Fun rotating message
              if (!isComplete) ...[
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    widget.funMessages[_currentMessageIndex],
                    key: ValueKey(_currentMessageIndex),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              
              // Current teacher being processed
              if (_currentState.currentTeacher.isNotEmpty && !isComplete)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade500),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _currentState.currentTeacher,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 16),
              
              // Elapsed time
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timer_outlined, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Elapsed: ${_formatDuration(_elapsedSeconds)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  if (!isComplete && _elapsedSeconds > 0 && completed > 0) ...[
                    const SizedBox(width: 12),
                    Text(
                      '• ~${_formatDuration(((total - completed) * (_elapsedSeconds / completed)).round())} remaining',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ],
              ),
              
              // Progress bar at bottom
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isComplete ? Colors.green : const Color(0xff0386FF),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
