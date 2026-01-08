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
import 'coach_evaluation_screen.dart';

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
      AppLogger.debug('Loading audits for month: $_selectedYearMonth');
      // Use optimized parallel loading
      final audits = await OptimizedAuditLoader.loadAuditsOptimized(
        yearMonth: _selectedYearMonth,
      );
      AppLogger.debug('Loaded ${audits.length} audits for month: $_selectedYearMonth');
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

  void _selectMonth() async {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    final months = List.generate(12, (i) {
      final date = DateTime(now.year, now.month - i);
      return DateFormat('yyyy-MM').format(date);
    });

    final selected = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 350, // Largeur fixe pour éviter l'effet "trop grand"
            constraints: const BoxConstraints(maxHeight: 500),
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
                        'Select Period',
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
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: months.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (context, index) {
                      final m = months[index];
                      final date = DateTime.parse('$m-01');
                      final isSelected = m == _selectedYearMonth;
                      return InkWell(
                        onTap: () => Navigator.pop(context, m),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? Win11Colors.accent.withOpacity(0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected
                                ? Border.all(color: Win11Colors.accent, width: 1.5)
                                : null,
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
                              if (isSelected)
                                Icon(Icons.check_circle, color: Win11Colors.accent, size: 20)
                              else
                                Icon(Icons.chevron_right, size: 16, color: Win11Colors.textSecondary),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );

    if (selected != null && selected != _selectedYearMonth) {
      // Same behavior as clicking refresh button
      HapticFeedback.lightImpact();
      // Update state first
      setState(() {
        _selectedYearMonth = selected;
        // Clear current audits and set loading state immediately
        _audits = [];
        _isLoading = true;
        _isRefreshing = false; // Reset refresh state
      });
      // Force reload after state update completes
      // Use Future.microtask to ensure setState completes first
      Future.microtask(() => _loadAudits(force: true));
    }
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
                'Loading teachers...',
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
          const SnackBar(
            content: Text('No teachers found. Make sure teachers are created with role="teacher" or user_type="teacher"'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    } catch (e) {
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching teachers: $e')),
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

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                const Icon(Icons.calculate, color: Color(0xff0386FF)),
                const SizedBox(width: 12),
                Text(
                  'Generate Audits',
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
                          'Select teachers to generate/regenerate audit metrics for $_selectedYearMonth. You can select all teachers, including those who already have audits.',
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        // Select all teachers (including those with existing audits for regeneration)
                        final allTeacherIds = teachers.map((t) => t['id'] as String).toList();
                        setDialogState(() {
                          selectedTeachers.clear();
                          selectedTeachers.addAll(allTeacherIds);
                        });
                      },
                      child: const Text('Select All'),
                    ),
                    TextButton(
                      onPressed: () {
                        // Select only teachers without audits
                        final newTeachers = teachers
                            .where((t) => !existingAuditIds.contains(t['id']))
                            .map((t) => t['id'] as String)
                            .toList();
                        setDialogState(() {
                          selectedTeachers.clear();
                          if (newTeachers.isNotEmpty) {
                            selectedTeachers.addAll(newTeachers);
                          }
                        });
                      },
                      child: const Text('Select New Only'),
                    ),
                    TextButton(
                      onPressed: () {
                        setDialogState(() => selectedTeachers.clear());
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: teachers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_off, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                'No teachers found',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: teachers.length,
                          itemBuilder: (context, index) {
                      final teacher = teachers[index];
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
                                  'Has Audit',
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
              child: const Text('Cancel'),
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
        ),
      ),
    );
  }

  /// Generate audits for selected teachers efficiently
  Future<void> _generateAuditsForTeachers(
    List<String> teacherIds,
    List<Map<String, dynamic>> allTeachers,
  ) async {
    // Show smooth progress dialog
    final progressController = StreamController<double>();
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) => StreamBuilder<double>(
        stream: progressController.stream,
        initialData: 0.0,
        builder: (context, snapshot) {
          final progress = snapshot.data ?? 0.0;
          return Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: progress > 0 ? progress : null,
                      strokeWidth: 6,
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Generating Audits',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}% Complete',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xff0386FF),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Processing ${teacherIds.length} teachers...',
                    style: GoogleFonts.inter(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    setState(() => _isGenerating = true);

    // Use the optimized batch processing
    final results = await OptimizedAuditGenerator.generateAuditsBatch(
      teacherIds: teacherIds,
      yearMonth: _selectedYearMonth,
      onProgress: (completed, total) {
        if (!progressController.isClosed) {
          progressController.add(completed / total);
        }
      },
    );
    
    // Close progress dialog first - show 100% then close
    if (!progressController.isClosed) {
      progressController.add(1.0); // Show 100%
      await Future.delayed(const Duration(milliseconds: 300));
      progressController.close();
    }
    
    if (!mounted) {
      setState(() => _isGenerating = false);
      return;
    }
    
    Navigator.pop(context); // Close progress dialog

    final successCount = results.values.where((v) => v).length;
    final errorCount = results.values.where((v) => !v).length;
    final skippedCount = teacherIds.length - results.length; // Teachers with no data

    if (mounted) {
      setState(() => _isGenerating = false);
      await _loadAudits();

      // Build informative message
      String message = 'Generated $successCount audit(s)';
      if (skippedCount > 0) {
        message += '. $skippedCount teacher(s) with no data available';
      }
      if (errorCount > 0) {
        message += '. $errorCount error(s) occurred';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: errorCount > 0 ? Colors.orange : (skippedCount > 0 ? Colors.blue : Colors.green),
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
                  'Audit Management',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Win11Colors.textMain,
                  ),
                ),
                Text(
                  'Manage teacher performance and payments',
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
            label: DateFormat('MMM yyyy').format(DateTime.parse('$_selectedYearMonth-01')),
            onTap: _selectMonth,
          ),
          const SizedBox(width: 8),
          _buildHeaderAction(
            icon: Icons.refresh_rounded,
            label: 'Refresh',
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
                hintText: 'Search teacher...',
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
              'All Departments',
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
            'CSV',
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
            'Export',
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
                    'Status',
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
                    'Actions',
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
          tooltip: 'View audit details',
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
              'Evaluate',
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
              'Review',
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
            tooltip: 'Edit evaluation',
          ),
        ] else if (isCompleted) ...[
          // Completed, can view and optionally edit
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 18, color: Colors.grey.shade600),
            onPressed: () => _openCoachEvaluation(audit),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Edit evaluation',
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
              'Review',
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
            'Showing $start-$end of $total results',
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
                child: Text('Previous', style: GoogleFonts.inter(fontSize: 13)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _currentPage < _totalPages - 1
                    ? () => setState(() => _currentPage++)
                    : null,
                child: Text('Next', style: GoogleFonts.inter(fontSize: 13)),
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
          const SnackBar(
            content: Text('Generating CSV...'),
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
          const SnackBar(
            content: Text('CSV exported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting CSV: $e'),
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
          const SnackBar(
            content: Text('Generating Excel report...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Use advanced Excel export with colors and formatting
      await AdvancedExcelExportService.exportToExcel(
        audits: _filteredAudits,
        yearMonth: _selectedYearMonth,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Excel report exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting Excel: $e'),
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
                'Loading audits for $_selectedYearMonth...',
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
          const SizedBox(height: 24),
          Text('No audits found', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          Text('Try changing the month or generating new ones', style: GoogleFonts.inter(color: Colors.grey[500])),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: _showGenerateAuditDialog,
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide(color: _primaryColor),
            ),
            child: Text('Generate Now', style: TextStyle(color: _primaryColor)),
          ),
        ],
      ),
    );
  }

  void _showAuditDetails(TeacherAuditFull audit) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => _DraggableFullScreenDialog(
        child: _AuditDetailSheet(
          audit: audit,
          scrollController: ScrollController(),
        ),
      ),
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
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Adjust Payment',
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
                      const Text('Current Payment:'),
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
                  decoration: const InputDecoration(
                    labelText: 'Adjustment Amount',
                    hintText: 'e.g., 0.21 or -5.00',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Reason (required)',
                    hintText: 'Rounding adjustment, penalty, bonus, etc.',
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
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final adjustment = double.tryParse(adjustmentController.text);
                      if (adjustment == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid number')),
                        );
                        return;
                      }
                      if (reasonController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please provide a reason')),
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
                            const SnackBar(
                              content: Text('Payment adjusted successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
                  : const Text('Apply Adjustment'),
            ),
          ],
        ),
      ),
    );
  }

  /// CEO/Founder review dialog
  void _showReviewDialog(TeacherAuditFull audit) {
    final notesController = TextEditingController(text: 'reviewed'); // Default comment
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
              const SizedBox(width: 12),
              Text(
                'Admin Review',
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
                Text('Review As:', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('CEO'),
                        value: 'ceo',
                        groupValue: selectedRole,
                        onChanged: (v) => setDialogState(() => selectedRole = v!),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Founder'),
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
                Text('Decision:', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'approved', child: Text('✅ Approve')),
                    DropdownMenuItem(value: 'needs_revision', child: Text('📝 Needs Revision')),
                    DropdownMenuItem(value: 'rejected', child: Text('❌ Reject')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedStatus = v!),
                ),
                const SizedBox(height: 12),

                // Notes (Required - default "reviewed")
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Review Comment *',
                    hintText: 'Add any comments or corrections...',
                    border: const OutlineInputBorder(),
                    helperText: 'Required field. Default: "reviewed"',
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
              child: const Text('Cancel'),
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
                            const SnackBar(
                              content: Text('Review submitted'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
                            'Drag to move • Click to close',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.grey.shade700),
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: 'Close',
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
  
  @override
  void initState() {
    super.initState();
    // Preload all form labels in background for instant display
    _preloadFormLabels();
    // Pre-compute grouped data once
    _computeGroupedData();
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
  
  /// **OPTIMIZATION: Compute grouped data once and cache it**
  void _computeGroupedData() {
    if (_cachedDayItems != null) return; // Already computed
    
    // Build lookup maps for O(1) access
    final shiftFormMap = <String, String>{}; // shiftId -> formId
    final formShiftMap = <String, String>{}; // formId -> shiftId
    
    for (var form in widget.audit.detailedForms) {
      final formId = form['id'] as String? ?? '';
      final shiftId = form['shiftId'] as String?;
      if (formId.isNotEmpty && shiftId != null && shiftId.isNotEmpty) {
        shiftFormMap[shiftId] = formId;
        formShiftMap[formId] = shiftId;
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
      
      // Get student names from shift (need to parse from title or get from detailed data)
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
      
      // Track orphan shifts (completed/missed without form)
      if ((status == 'completed' || status == 'fullyCompleted' || status == 'missed') && !hasForm) {
        orphanShifts.add(shiftItem);
      }
    }
    
    // Group forms by day
    final formsByDay = <int, List<_FormItem>>{};
    final unlinkedForms = <_FormItem>[];
    
    for (var form in widget.audit.detailedForms) {
      final formId = form['id'] as String? ?? '';
      final shiftId = form['shiftId'] as String?;
      final submittedAt = (form['submittedAt'] as Timestamp?)?.toDate();
      final responses = form['responses'] as Map<String, dynamic>? ?? {};
      
      // Extract day of week from form responses
      final dayOfWeek = _extractDayOfWeekFromForm(responses);
      
      // Determine date - use shift end if linked, otherwise submission date
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
    _cachedDayItems = dayItems;
    _cachedOrphanShifts = orphanShifts;
    _cachedUnlinkedForms = unlinkedForms;
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
  
  String? _extractDayOfWeekFromForm(Map<String, dynamic> responses) {
    // Look for Class Day field (ID: 1754406288023)
    var dayValue = responses['1754406288023'];
    if (dayValue == null) {
      // Search for any field containing day names
      for (var value in responses.values) {
        if (value is String || (value is List && value.isNotEmpty)) {
          final str = value is List ? value.first.toString() : value.toString();
          if (_isDayOfWeekString(str)) {
            return str;
          }
        }
      }
      return null;
    }
    
    if (dayValue is List && dayValue.isNotEmpty) {
      return dayValue.first.toString();
    }
    return dayValue.toString();
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
                tooltip: 'Close',
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
              const SizedBox(height: 12),
              
              // **NEW: Individual Shift Payouts with Adjustment**
              _buildSectionHeader('Individual Shift Payouts'),
              const SizedBox(height: 8),
              _IndividualShiftPaymentsSection(
                audit: widget.audit,
                onUpdatePayment: _updateShiftPayment,
              ),
              const SizedBox(height: 12),
              
              // **NEW: Forms Compliance Summary with Penalty**
              _FormsComplianceSummary(
                audit: widget.audit,
                orphanShifts: _cachedOrphanShifts ?? [],
                unlinkedForms: _cachedUnlinkedForms ?? [],
                onApplyPenalty: _applyFormPenalty,
              ),
              const SizedBox(height: 12),
              // **NEW: Shifts & Forms by Day (Unified View)**
              if (_cachedDayItems != null && _cachedDayItems!.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildSectionHeader('Shifts & Forms by Day'),
                const SizedBox(height: 12),
                ..._cachedDayItems!.map((dayItem) => _DaySection(
                  dayItem: dayItem,
                  orphanShifts: _cachedOrphanShifts ?? [],
                  unlinkedForms: _cachedUnlinkedForms ?? [],
                  onLinkFormToShift: _linkFormToShift,
                  parentContext: context,
                )),
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
                Text('Linking form and recalculating payment...'),
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
              content: Text('Form linked to shift successfully. Payment updated.'),
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
        });
        _computeGroupedData();
      } else if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to link form to shift'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Apply penalty for missing forms
  Future<void> _updateShiftPayment(String shiftId, double newAmount) async {
    try {
      final success = await TeacherAuditService.updateShiftPayment(
        auditId: widget.audit.id,
        shiftId: shiftId,
        adjustedAmount: newAmount,
        reason: 'Admin adjustment',
      );
      
      if (success && mounted) {
        // Reload audit to show updated payment
        final updatedAudit = await TeacherAuditService.getAudit(
          oderId: widget.audit.oderId,
          yearMonth: widget.audit.yearMonth,
        );
        
        if (updatedAudit != null) {
          // Update widget's audit
          setState(() {
            // Update the audit in the widget
            // Note: We can't directly modify widget.audit, so we need to reload the parent
          });
          
          // Update parent screen's audit list
          final parentState = context.findAncestorStateOfType<_AdminAuditScreenState>();
          if (parentState != null) {
            await parentState._loadAudits(force: true);
          }
          
          // Close and reopen detail sheet with updated audit
          Navigator.of(context).pop(); // Close current detail sheet
          if (parentState != null && mounted) {
            Future.delayed(Duration(milliseconds: 100), () {
              // Reopen with updated audit
              parentState._showAuditDetails(updatedAudit);
            });
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment updated to \$${newAmount.toStringAsFixed(2)}. Total payment recalculated.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update payment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _showAuditDetails(TeacherAuditFull audit) {
    // Helper to show audit details (used after payment update)
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => _DraggableFullScreenDialog(
        child: _AuditDetailSheet(
          audit: audit,
          scrollController: ScrollController(),
        ),
      ),
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
            content: Text('Error applying penalty: $e'),
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
                'Forms Compliance',
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
                        'Penalty per missing',
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
                        'Total penalty',
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
                  'Shifts Without Forms',
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
                  '$count',
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
            'These shifts were completed but no readiness form was submitted. Apply a penalty for missing forms.',
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
                      'Penalty per shift',
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
                      'Total penalty',
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

/// **Individual Shift Payments Section** - Shows all shift payouts with edit capability
class _IndividualShiftPaymentsSection extends StatefulWidget {
  final TeacherAuditFull audit;
  final Function(String shiftId, double newAmount) onUpdatePayment;

  const _IndividualShiftPaymentsSection({
    required this.audit,
    required this.onUpdatePayment,
  });

  @override
  State<_IndividualShiftPaymentsSection> createState() => _IndividualShiftPaymentsSectionState();
}

class _IndividualShiftPaymentsSectionState extends State<_IndividualShiftPaymentsSection> {
  // Map of shiftId -> editing state
  final Map<String, bool> _editingStates = {};
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get shifts with forms (only these have payouts)
    final shiftsWithForms = <Map<String, dynamic>>[];
    final shiftFormMap = <String, String>{};
    
    for (var form in widget.audit.detailedForms) {
      final shiftId = form['shiftId'] as String?;
      if (shiftId != null && shiftId.isNotEmpty) {
        shiftFormMap[shiftId] = form['id'] as String? ?? '';
      }
    }
    
    for (var shift in widget.audit.detailedShifts) {
      final shiftId = shift['id'] as String? ?? '';
      final status = shift['status'] as String? ?? 'scheduled';
      
      // Only show completed/partially completed shifts with forms
      if ((status == 'fullyCompleted' || status == 'completed' || status == 'partiallyCompleted') &&
          shiftFormMap.containsKey(shiftId)) {
        shiftsWithForms.add(shift);
      }
    }
    
    if (shiftsWithForms.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'No shifts with forms found. Link forms to shifts to see payouts.',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    
    return Column(
      children: shiftsWithForms.map((shift) {
        final shiftId = shift['id'] as String? ?? '';
        final title = shift['title'] as String? ?? 'Unknown';
        final subject = shift['subject'] as String? ?? 'Other';
        final start = (shift['start'] as Timestamp).toDate();
        final end = (shift['end'] as Timestamp).toDate();
        final hours = end.difference(start).inMinutes / 60.0;
        final hourlyRate = (shift['hourlyRate'] as num?)?.toDouble() ?? 0;
        final originalPayment = hours * hourlyRate;
        
        // Get adjusted payment if exists
        final adjustments = widget.audit.paymentSummary?.shiftPaymentAdjustments ?? {};
        final adjustedPayment = adjustments[shiftId] ?? originalPayment;
        final maxPayment = PaymentSummary.getMaxShiftPayment(subject, hours);
        
        // Initialize controller if not exists
        if (!_controllers.containsKey(shiftId)) {
          _controllers[shiftId] = TextEditingController(
            text: adjustedPayment.toStringAsFixed(2),
          );
        }
        
        final isEditing = _editingStates[shiftId] ?? false;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade900,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                subject,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${hours.toStringAsFixed(2)}h',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('MMM d').format(start),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isEditing) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${adjustedPayment.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: adjustedPayment != originalPayment 
                                ? Colors.orange.shade700 
                                : Colors.green.shade700,
                          ),
                        ),
                        if (adjustedPayment != originalPayment)
                          Text(
                            'was \$${originalPayment.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.edit, size: 18, color: Colors.blue.shade700),
                      onPressed: () {
                        setState(() {
                          _editingStates[shiftId] = true;
                        });
                      },
                      tooltip: 'Adjust payment',
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ] else ...[
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _controllers[shiftId],
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          prefixText: '\$',
                          prefixStyle: GoogleFonts.inter(color: Colors.grey.shade700),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: Colors.blue.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.blue.shade50,
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.check, size: 18, color: Colors.green.shade700),
                      onPressed: () async {
                        final newAmount = double.tryParse(_controllers[shiftId]!.text) ?? adjustedPayment;
                        
                        // Validate max limit
                        if (newAmount > maxPayment) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Maximum payment for $subject is \$${maxPayment.toStringAsFixed(2)} (max \$${PaymentSummary.getMaxHourlyRate(subject).toStringAsFixed(0)}/hour)'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        
                        await widget.onUpdatePayment(shiftId, newAmount);
                        setState(() {
                          _editingStates[shiftId] = false;
                        });
                      },
                      tooltip: 'Save',
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
                      onPressed: () {
                        _controllers[shiftId]!.text = adjustedPayment.toStringAsFixed(2);
                        setState(() {
                          _editingStates[shiftId] = false;
                        });
                      },
                      tooltip: 'Cancel',
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ],
              ),
              if (isEditing) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.blue.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Max: \$${maxPayment.toStringAsFixed(2)} (\$${PaymentSummary.getMaxHourlyRate(subject).toStringAsFixed(0)}/hour × ${hours.toStringAsFixed(2)}h)',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
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
                    tooltip: 'View Form Details',
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
  
  /// Show form details in a fluid modal
  void _showFormDetailsModal(BuildContext context, Map<String, dynamic> form) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => _DraggableFullScreenDialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: _FormDetailsContent(
            formId: form['id'] ?? '',
            shiftId: form['shiftId'] ?? 'N/A',
            responses: form['responses'] as Map<String, dynamic>? ?? {},
            parentContext: widget.parentContext,
          ),
        ),
      ),
    );
  }
}

class _FormDetailsContent extends StatefulWidget {
  final String formId;
  final String shiftId;
  final Map<String, dynamic> responses;
  final BuildContext parentContext;

  const _FormDetailsContent({
    required this.formId,
    required this.shiftId,
    required this.responses,
    required this.parentContext,
  });

  @override
  State<_FormDetailsContent> createState() => _FormDetailsContentState();
}

class _FormDetailsContentState extends State<_FormDetailsContent> {
  Map<String, String>? _fieldLabels;
  bool _isLoadingLabels = true;

  @override
  void initState() {
    super.initState();
    _loadFieldLabels();
  }

  Future<void> _loadFieldLabels() async {
    try {
      // Use cache service for fast retrieval
      final labels = await FormLabelsCacheService().getLabelsForFormResponse(widget.formId);
      
      if (labels.isNotEmpty) {
        setState(() {
          _fieldLabels = labels;
          _isLoadingLabels = false;
        });
      } else {
        setState(() {
          _isLoadingLabels = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading field labels: $e');
      setState(() {
        _isLoadingLabels = false;
      });
    }
  }

  void _navigateToShift() async {
    if (widget.shiftId == 'N/A' || widget.shiftId.isEmpty) return;
    
    try {
      final shiftDoc = await FirebaseFirestore.instance
          .collection('teaching_shifts')
          .doc(widget.shiftId)
          .get();

      if (!shiftDoc.exists) {
        if (widget.parentContext.mounted) {
          ScaffoldMessenger.of(widget.parentContext).showSnackBar(
            const SnackBar(content: Text('Shift not found')),
          );
        }
        return;
      }

      final shift = TeachingShift.fromFirestore(shiftDoc);
      
      if (widget.parentContext.mounted) {
        Navigator.of(widget.parentContext).pop(); // Close audit details first
        showDialog(
          context: widget.parentContext,
          builder: (context) => ShiftDetailsDialog(shift: shift),
        );
      }
    } catch (e) {
      if (widget.parentContext.mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(content: Text('Error loading shift: $e')),
        );
      }
    }
  }

  String _getFieldLabel(String fieldId) {
    if (_fieldLabels != null && _fieldLabels!.containsKey(fieldId)) {
      return _fieldLabels![fieldId]!;
    }
    
    // Try to find by numeric match (in case ID is stored differently)
    if (_fieldLabels != null) {
      for (var entry in _fieldLabels!.entries) {
        if (entry.key.toString() == fieldId.toString()) {
          return entry.value;
        }
      }
    }
    
    // Fallback: if it's a numeric ID, try to find similar patterns
    // Otherwise return a generic label
    if (RegExp(r'^\d+$').hasMatch(fieldId)) {
      return 'Question $fieldId';
    }
    
    // Format text IDs nicely
    return fieldId
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Wrap in SingleChildScrollView to prevent overflow
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minimal header with view shift button
          if (widget.shiftId != 'N/A' && widget.shiftId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: _navigateToShift,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue.shade200),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_in_new, size: 14, color: Colors.blue.shade700),
                      const SizedBox(width: 6),
                      Text(
                        'View Shift',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Responses - Modern minimal design
          if (_isLoadingLabels)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          if (!_isLoadingLabels && widget.responses.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'No responses',
                style: GoogleFonts.inter(
                  color: Colors.grey.shade400,
                  fontSize: 11,
                ),
              ),
            ),
          if (!_isLoadingLabels && widget.responses.isNotEmpty)
            ...widget.responses.entries.map((entry) {
              final label = _getFieldLabel(entry.key);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: Colors.grey.shade900,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _formatResponseValue(entry.value),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _formatResponseValue(dynamic value) {
    if (value == null) {
      return Text(
        '—',
        style: GoogleFonts.inter(
          fontSize: 12,
          color: Colors.grey.shade400,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    if (value is String) {
      if (value.isEmpty) {
        return Text(
          '—',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey.shade400,
            fontStyle: FontStyle.italic,
          ),
        );
      }
      return Text(
        value,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: Colors.grey.shade800,
          height: 1.4,
        ),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      );
    }
    if (value is bool) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: value ? Colors.green.shade50 : Colors.red.shade50,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          value ? 'Yes' : 'No',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: value ? Colors.green.shade700 : Colors.red.shade700,
          ),
        ),
      );
    }
    if (value is num) {
      return Text(
        value.toString(),
        style: GoogleFonts.inter(
          fontSize: 12,
          color: Colors.grey.shade800,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    if (value is Map) {
      if (value.containsKey('downloadURL')) {
        return InkWell(
          onTap: () {
            // TODO: Open image
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image, size: 14, color: Colors.blue.shade700),
                const SizedBox(width: 6),
                Text(
                  'View attachment',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return Text(
        value.toString(),
        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
      );
    }
    if (value is List) {
      if (value.isEmpty) {
        return Text(
          '—',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey.shade400,
            fontStyle: FontStyle.italic,
          ),
        );
      }
      return Wrap(
        spacing: 4,
        runSpacing: 4,
        children: value.map((item) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item.toString(),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.blue.shade900,
              ),
            ),
          );
        }).toList(),
      );
    }
    return Text(
      value.toString(),
      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade800),
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
              '$label:',
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
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 12, color: Colors.green.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'Form submitted',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.green.shade700,
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
                    'NO FORM',
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
                          'Link Form',
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
                      'Teacher did not submit readiness form. This shift will be excluded from payment calculation.',
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
                          'Ban Shift',
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
        SnackBar(content: Text('No unlinked forms found nearby')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Link Form to Shift'),
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
                subtitle: Text('Submitted: $dateStr'),
                trailing: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onLinkFormToShift(form.formId, shift.shiftId);
                  },
                  child: Text('Link'),
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
        title: Text('Ban Shift'),
        content: Text(
          'Are you sure you want to ban this shift? This will mark it as invalid and exclude it from all audit calculations, payment calculations, and statistics. This action cannot be undone easily.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
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
                      content: Text('Shift banned successfully. Recalculating audit...'),
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
                      content: Text('Error banning shift: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Ban Shift'),
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
        : 'No date';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
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
        children: [
          Row(
            children: [
              Icon(
                Icons.assignment,
                size: 16,
                color: form.isLinked ? Colors.green.shade700 : Colors.blue.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Day: ${form.dayOfWeek ?? "N/A"}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
                  ),
                ),
              ),
              // Eye icon to view form details
              IconButton(
                icon: Icon(Icons.visibility_outlined, size: 18),
                color: Colors.grey.shade600,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  _showFormDetailsModal(context, formData, form.formId, form.linkedShiftId ?? 'N/A', parentContext);
                },
                tooltip: 'View Details',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Submitted: $dateStr',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.grey.shade600,
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
                          'NO SHIFT ASSOCIATED',
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
                    'This form indicates the teacher conducted a class without a scheduled shift. Please verify why this happened and take appropriate action.',
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
                            label: Text('Link to Shift', style: GoogleFonts.inter(fontSize: 10)),
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
                          label: Text('Create Shift', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600)),
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
        SnackBar(content: Text('No orphan shifts found nearby')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Link Form to Shift'),
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
                  child: Text('Link'),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
  
  void _showFormDetailsModal(BuildContext context, Map<String, dynamic> formData, String formId, String shiftId, BuildContext parentContext) {
    // If formData doesn't have responses, try to fetch from Firestore directly
    if ((formData['responses'] as Map<String, dynamic>?)?.isEmpty ?? true) {
      _fetchFormDataAndShowModal(context, formId, shiftId, parentContext);
    } else {
      showDialog(
        context: context,
        barrierColor: Colors.black.withOpacity(0.5),
        builder: (context) => _DraggableFullScreenDialog(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: _FormDetailsContent(
              formId: formData['id'] ?? formId,
              shiftId: formData['shiftId'] ?? shiftId,
              responses: formData['responses'] as Map<String, dynamic>? ?? {},
              parentContext: parentContext,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _fetchFormDataAndShowModal(BuildContext context, String formId, String shiftId, BuildContext parentContext) async {
    try {
      final formDoc = await FirebaseFirestore.instance.collection('form_responses').doc(formId).get();
      if (formDoc.exists) {
        final data = formDoc.data() as Map<String, dynamic>;
        final responses = data['responses'] as Map<String, dynamic>? ?? {};

        if (context.mounted) {
          showDialog(
            context: context,
            barrierColor: Colors.black.withOpacity(0.5),
            builder: (context) => _DraggableFullScreenDialog(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: _FormDetailsContent(
                  formId: formId,
                  shiftId: shiftId,
                  responses: responses,
                  parentContext: parentContext,
                ),
              ),
            ),
          );
        }
      } else {
        // Form not found, show empty modal
        if (context.mounted) {
          showDialog(
            context: context,
            barrierColor: Colors.black.withOpacity(0.5),
            builder: (context) => _DraggableFullScreenDialog(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: _FormDetailsContent(
                  formId: formId,
                  shiftId: shiftId,
                  responses: {},
                  parentContext: parentContext,
                ),
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error fetching form data: $e');
      // Show empty modal on error
      if (context.mounted) {
        showDialog(
          context: context,
          barrierColor: Colors.black.withOpacity(0.5),
          builder: (context) => _DraggableFullScreenDialog(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: _FormDetailsContent(
                formId: formId,
                shiftId: shiftId,
                responses: {},
                parentContext: parentContext,
              ),
            ),
          ),
        );
      }
    }
  }
  
  void _banForm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ban Form'),
        content: Text('Are you sure you want to ban this form? This will mark it as invalid and exclude it from audit calculations.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
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
                  SnackBar(content: Text('Form banned successfully'), backgroundColor: Colors.green),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Ban'),
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
        const SnackBar(content: Text('Unable to find audit context'), backgroundColor: Colors.red),
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
              const SizedBox(width: 12),
              Text(
                'Régularisation Administrative',
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
                  'Enseignant: $teacherName',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Ce formulaire n\'a pas de shift associé. Créez un shift "Completed" basé sur les déclarations du professeur.',
                  style: GoogleFonts.inter(fontSize: 13),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Sujet du cours',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: durationController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Durée à payer (Heures)',
                    suffixText: 'heures',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Le paiement sera calculé : Durée × Taux horaire du sujet.',
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
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: isProcessing ? null : () async {
                setDialogState(() => isProcessing = true);
                
                final finalDuration = double.tryParse(durationController.text.trim()) ?? formDuration;
                if (finalDuration <= 0) {
                  setDialogState(() => isProcessing = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('La durée doit être supérieure à 0'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                final finalSubject = subjectController.text.trim();
                if (finalSubject.isEmpty) {
                  setDialogState(() => isProcessing = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Le sujet est requis'),
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
                      const SnackBar(
                        content: Text('Shift créé et paiement synchronisé !'),
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
                      const SnackBar(
                        content: Text('Erreur lors de la création du shift.'),
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
                  : const Text('Créer & Payer'),
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
            const SnackBar(
              content: Text('No data to export with current filters'),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() => _isExporting = false);
          return;
        }
        
        await AdvancedExcelExportService.exportToExcel(
          audits: auditsToExport,
          yearMonth: widget.selectedYearMonth,
        );
      }
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Excel report exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting: $e'),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Export Audit Report',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      Text(
                        'Excel with monthly pivot tables',
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
              'Filter by Teacher',
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
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: InputBorder.none,
                  hintText: 'All Teachers',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All Teachers', overflow: TextOverflow.ellipsis),
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
                          'Export All Months (Pivot View)',
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
                    'Sheets included in export:',
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
                      _buildSheetChip('📊 Monthly View', 'Pivot 6 metrics'),
                      _buildSheetChip('📊 Complete View', 'All metrics'),
                      _buildSheetChip('📈 Scores by Month', 'Evolution'),
                      _buildSheetChip('⏰ Hours by Month', 'Time worked'),
                      _buildSheetChip('💰 Payments by Month', 'Finances'),
                      _buildSheetChip('📋 Forms by Month', 'Compliance'),
                      _buildSheetChip('⏰ Punctuality by Month', 'Lateness'),
                      _buildSheetChip('📚 Classes by Month', 'Completion'),
                      _buildSheetChip('📖 Academic by Month', 'Quizzes/Assignments'),
                      _buildSheetChip('📝 Evaluation', 'Coach'),
                      _buildSheetChip('🏆 Leaderboard', 'Ranking'),
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
            const SizedBox(height: 24),
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
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
