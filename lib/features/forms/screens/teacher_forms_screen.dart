import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/models/form_template.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/enums/shift_enums.dart';
import '../../../core/services/form_template_service.dart';
import '../../../core/services/user_role_service.dart';
import '../../../core/services/shift_form_service.dart';
import '../../../form_screen.dart';
import '../../../core/utils/app_logger.dart';
import '../widgets/form_details_modal.dart';
import '../screens/my_submissions_screen.dart';
import '../../shift_management/widgets/shift_details_dialog.dart';
import '../../time_clock/widgets/edit_timesheet_dialog.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// New Teacher Forms Screen - Shows all form templates organized by category
/// Categories: Teaching (daily/weekly/monthly), Feedback, Student Assessment, Administrative
class TeacherFormsScreen extends StatefulWidget {
  const TeacherFormsScreen({super.key});

  @override
  State<TeacherFormsScreen> createState() => _TeacherFormsScreenState();
}

class _TeacherFormsScreenState extends State<TeacherFormsScreen> {
  bool _isLoading = true;
  String? _userRole;
  
  // Templates organized by category
  Map<FormCategory, List<FormTemplate>> _templatesByCategory = {};
  Map<String, bool> _submittedForms = {};
  String? _errorMessage;

  // Palette de couleurs "Soft"
  static const Map<FormCategory, Color> _categoryColors = {
    FormCategory.teaching: Color(0xFF10B981), // Emerald
    FormCategory.studentAssessment: Color(0xFF3B82F6), // Blue
    FormCategory.feedback: Color(0xFF8B5CF6), // Violet
    FormCategory.administrative: Color(0xFFF59E0B), // Amber
    FormCategory.other: Color(0xFF64748B), // Slate
  };

  static const Map<FormCategory, IconData> _categoryIcons = {
    FormCategory.teaching: Icons.school_rounded,
    FormCategory.studentAssessment: Icons.analytics_rounded,
    FormCategory.feedback: Icons.rate_review_rounded,
    FormCategory.administrative: Icons.admin_panel_settings_rounded,
    FormCategory.other: Icons.folder_open_rounded,
  };

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await _loadUserRole();
    await _loadTemplates();
    await _loadSubmissionStatus();
  }

  Future<void> _loadUserRole() async {
    final role = await UserRoleService.getCurrentUserRole();
    if (mounted) setState(() => _userRole = role);
  }

  Future<void> _loadTemplates({bool forceRefresh = true}) async {
    setState(() => _isLoading = true);
    
    try {
      // Load templates from Firestore form_templates collection
      // Force refresh from server to ensure latest version (bypasses cache)
      final allTemplates = await FormTemplateService.getAllTemplates(forceRefresh: forceRefresh);
      
      
      // Filter to keep only the latest version of each template by name
      // Normalize names (trim, lowercase, remove extra spaces) to catch duplicates
      final Map<String, FormTemplate> latestTemplatesByName = {};
      for (var template in allTemplates) {
        if (!template.isActive) continue;
        
        // Normalize template name for comparison
        final normalizedName = template.name
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), ' ');
        
        if (!latestTemplatesByName.containsKey(normalizedName)) {
          latestTemplatesByName[normalizedName] = template;
        } else {
          final existing = latestTemplatesByName[normalizedName]!;
          // Keep the one with higher version, or if same version, keep the one with later updatedAt
          if (template.version > existing.version) {
            latestTemplatesByName[normalizedName] = template;
          } else if (template.version == existing.version) {
            // If same version, prefer the one with later updatedAt
            if (template.updatedAt.isAfter(existing.updatedAt)) {
              latestTemplatesByName[normalizedName] = template;
            }
          }
        }
      }
      
      
      // Organize templates by category
      _templatesByCategory = {};
      
      for (var template in latestTemplatesByName.values) {
        
        // Map category: if frequency is perSession/weekly/monthly, treat as teaching category
        // This fixes templates in Firestore with category "other" but frequency "perSession"
        FormCategory displayCategory = template.category;
        if ((template.frequency == FormFrequency.perSession || 
             template.frequency == FormFrequency.weekly || 
             template.frequency == FormFrequency.monthly) &&
            template.category == FormCategory.other) {
          displayCategory = FormCategory.teaching;
        }
        
        // Check role access - strict filtering for teachers
        if (_userRole != null) {
          final userRoleLower = _userRole!.toLowerCase();
          
          // Admins and coaches can see all forms
          if (userRoleLower == 'admin' || userRoleLower == 'coach') {
            // Admins and coaches see everything, no filtering needed
          } else if (userRoleLower == 'teacher') {
            // Teachers can only see forms that:
            // 1. Have allowedRoles that explicitly include "teacher"
            // 2. Have no allowedRoles AND are in teaching/feedback/administrative categories (default teacher forms)
            // 3. Have frequency perSession/weekly/monthly (teaching reports)
            final hasAllowedRoles = template.allowedRoles != null && template.allowedRoles!.isNotEmpty;
            
            if (hasAllowedRoles) {
              // If allowedRoles is set, teacher must be in the list
              if (!template.allowedRoles!.contains('teacher')) {
                continue; // Skip this form - it's not for teachers
              }
            } else {
              // If no allowedRoles, only show if it's a teacher-relevant category OR teaching frequency
              // Teaching, feedback, and administrative forms are for teachers
              // Daily/weekly/monthly reports are always for teachers
              final isTeacherCategory = displayCategory == FormCategory.teaching ||
                  displayCategory == FormCategory.feedback ||
                  displayCategory == FormCategory.administrative ||
                  template.frequency == FormFrequency.perSession ||
                  template.frequency == FormFrequency.weekly ||
                  template.frequency == FormFrequency.monthly;
              
              if (!isTeacherCategory) {
                continue; // Skip forms in other categories without explicit teacher access
              }
            }
          } else {
            // For other roles (students, parents, etc.), apply strict filtering
            if (template.allowedRoles != null && template.allowedRoles!.isNotEmpty) {
              if (!template.allowedRoles!.contains(userRoleLower)) {
                continue;
              }
            } else {
              // If no allowedRoles, only show teaching/feedback/administrative to teachers
              // For other roles, hide forms without explicit access
              continue;
            }
          }
        }
        
        // Use displayCategory (may be mapped from "other" to "teaching")
        _templatesByCategory.putIfAbsent(displayCategory, () => []);
        _templatesByCategory[displayCategory]!.add(template);
        
      }
      
      
      // Add default templates if none found for teaching category
      if (!_templatesByCategory.containsKey(FormCategory.teaching) ||
          _templatesByCategory[FormCategory.teaching]!.isEmpty) {
        _templatesByCategory[FormCategory.teaching] = [
          FormTemplateService.defaultDailyClassReport,
          FormTemplateService.defaultWeeklySummary,
          FormTemplateService.defaultMonthlyReview,
        ];
      }
      
      // Add default feedback templates if none found
      if (!_templatesByCategory.containsKey(FormCategory.feedback) ||
          _templatesByCategory[FormCategory.feedback]!.isEmpty) {
        _templatesByCategory[FormCategory.feedback] = [
          FormTemplateService.defaultTeacherFeedback,
          FormTemplateService.defaultLeadershipFeedback,
        ];
      }
      
      // Add default student assessment if none found
      if (!_templatesByCategory.containsKey(FormCategory.studentAssessment) ||
          _templatesByCategory[FormCategory.studentAssessment]!.isEmpty) {
        _templatesByCategory[FormCategory.studentAssessment] = [
          FormTemplateService.defaultStudentAssessment,
        ];
      }
      
      // Add default administrative templates
      if (!_templatesByCategory.containsKey(FormCategory.administrative) ||
          _templatesByCategory[FormCategory.administrative]!.isEmpty) {
        _templatesByCategory[FormCategory.administrative] = [
          FormTemplateService.defaultLeaveRequest,
          FormTemplateService.defaultIncidentReport,
        ];
      }
      
      // For admins/coaches, add additional forms
      if (_userRole?.toLowerCase() == 'admin' || _userRole?.toLowerCase() == 'coach') {
        // Add admin self-assessment
        _templatesByCategory[FormCategory.feedback]!.add(
          FormTemplateService.defaultAdminSelfAssessment,
        );
        
        // Add parent feedback form for admins
        _templatesByCategory.putIfAbsent(FormCategory.studentAssessment, () => []);
        _templatesByCategory[FormCategory.studentAssessment]!.add(
          FormTemplateService.defaultParentFeedback,
        );
      }
      
      // Admin-only: Coach Performance Review
      if (_userRole?.toLowerCase() == 'admin') {
        _templatesByCategory[FormCategory.feedback]!.add(
          FormTemplateService.defaultCoachPerformanceReview,
        );
      }
      
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading templates: $e');
      // On error, use defaults for all categories
      _templatesByCategory = {
        FormCategory.teaching: [
          FormTemplateService.defaultDailyClassReport,
          FormTemplateService.defaultWeeklySummary,
          FormTemplateService.defaultMonthlyReview,
        ],
        FormCategory.feedback: [
          FormTemplateService.defaultTeacherFeedback,
          FormTemplateService.defaultLeadershipFeedback,
        ],
        FormCategory.studentAssessment: [
          FormTemplateService.defaultStudentAssessment,
        ],
        FormCategory.administrative: [
          FormTemplateService.defaultLeaveRequest,
          FormTemplateService.defaultIncidentReport,
        ],
      };
      
      // Add role-specific forms on error too
      if (_userRole?.toLowerCase() == 'admin' || _userRole?.toLowerCase() == 'coach') {
        _templatesByCategory[FormCategory.feedback]!.add(
          FormTemplateService.defaultAdminSelfAssessment,
        );
        _templatesByCategory[FormCategory.studentAssessment]!.add(
          FormTemplateService.defaultParentFeedback,
        );
      }
      if (_userRole?.toLowerCase() == 'admin') {
        _templatesByCategory[FormCategory.feedback]!.add(
          FormTemplateService.defaultCoachPerformanceReview,
        );
      }
      
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSubmissionStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);
      final yearMonth = DateFormat('yyyy-MM').format(now);
      
      // Get week start (Sunday)
      final weekStart = now.subtract(Duration(days: now.weekday % 7));
      final weekStartStr = DateFormat('yyyy-MM-dd').format(weekStart);
      
      // Check daily submissions for today
      // Note: Order of where clauses must match index: formType, userId, submittedAt
      final todayTimestamp = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
      final dailySubmissions = await FirebaseFirestore.instance
          .collection('form_responses')
          .where('formType', isEqualTo: 'daily') // First field in index
          .where('userId', isEqualTo: user.uid) // Second field in index
          .where('submittedAt', isGreaterThanOrEqualTo: todayTimestamp) // Third field in index
          .orderBy('submittedAt', descending: true)
          .limit(1)
          .get();
      
      // Check weekly submissions for this week
      final weekStartTimestamp = Timestamp.fromDate(weekStart);
      final weeklySubmissions = await FirebaseFirestore.instance
          .collection('form_responses')
          .where('formType', isEqualTo: 'weekly') // First field in index
          .where('userId', isEqualTo: user.uid) // Second field in index
          .where('submittedAt', isGreaterThanOrEqualTo: weekStartTimestamp) // Third field in index
          .orderBy('submittedAt', descending: true)
          .limit(1)
          .get();
      
      // Check monthly submissions for this month
      final monthlySubmissions = await FirebaseFirestore.instance
          .collection('form_responses')
          .where('userId', isEqualTo: user.uid)
          .where('formType', isEqualTo: 'monthly')
          .where('yearMonth', isEqualTo: yearMonth)
          .get();
      
      if (mounted) {
        setState(() {
          _submittedForms = {
            'daily': dailySubmissions.docs.isNotEmpty,
            'weekly': weeklySubmissions.docs.isNotEmpty,
            'monthly': monthlySubmissions.docs.isNotEmpty,
          };
        });
      }
    } catch (e) {
      debugPrint('Error loading submission status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // On utilise CustomScrollView pour l'effet fluide du header
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate-100, très doux
      body: _isLoading 
        ? _buildLoadingState() 
        : RefreshIndicator(
            onRefresh: _loadAllData,
            color: const Color(0xFF6366F1),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildSliverAppBar(),
                if (_errorMessage != null) 
                  SliverFillRemaining(child: _buildErrorState())
                else 
                  _buildSliverList(),
                // Padding final pour éviter que le dernier item soit caché par la navigation
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
          ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200.0, // Hauteur étendue
      floating: false,
      pinned: true, // L'AppBar reste visible en haut
      backgroundColor: const Color(0xFF6366F1),
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax, // Effet parallaxe
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.submitReportsFeedback,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Stats row dans un SingleChildScrollView pour éviter l'overflow sur petits écrans
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildQuickStatPill(
                          'Daily', 
                          _submittedForms['daily'] == true ? 'Done' : 'Due',
                          _submittedForms['daily'] == true,
                        ),
                        const SizedBox(width: 12),
                        _buildQuickStatPill(
                          'Weekly',
                          FormFrequency.weekly.isAvailableToday
                             ? (_submittedForms['weekly'] == true ? 'Done' : 'Due')
                             : 'Sun-Tue',
                          _submittedForms['weekly'] == true,
                          isAvailable: FormFrequency.weekly.isAvailableToday,
                        ),
                        const SizedBox(width: 12),
                        _buildQuickStatPill(
                          'Monthly',
                          FormFrequency.monthly.isAvailableToday
                             ? (_submittedForms['monthly'] == true ? 'Done' : 'Due')
                             : 'End/Start',
                          _submittedForms['monthly'] == true,
                          isAvailable: FormFrequency.monthly.isAvailableToday,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        title: Text(
          AppLocalizations.of(context)!.formsReports,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
      ),
    );
  }

  Widget _buildQuickStatPill(String label, String status, bool isComplete, {bool isAvailable = true}) {
    Color bg = Colors.white.withOpacity(0.15);
    Color text = Colors.white;
    IconData icon = Icons.pending_actions_rounded;

    if (isComplete) {
      bg = Colors.greenAccent.withOpacity(0.2);
      text = Colors.greenAccent.shade100;
      icon = Icons.check_circle_rounded;
    } else if (!isAvailable) {
      bg = Colors.black.withOpacity(0.2);
      text = Colors.white54;
      icon = Icons.lock_clock_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20), // Pill shape
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: text, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              Text(
                status,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFF6366F1),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 64, color: Colors.blueGrey.shade200),
          SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.errorSomethingWentWrong,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade700,
            ),
          ),
          TextButton(
            onPressed: _loadAllData,
            child: Text(AppLocalizations.of(context)!.errorTryAgain),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverList() {
    const categoryOrder = [
      FormCategory.teaching,
      FormCategory.feedback,
      FormCategory.studentAssessment,
      FormCategory.administrative,
      FormCategory.other,
    ];

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= categoryOrder.length) return null;
          final category = categoryOrder[index];
          final templates = _templatesByCategory[category];

          if (templates == null || templates.isEmpty) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: _buildCategorySection(category, templates),
          );
        },
        childCount: categoryOrder.length,
      ),
    );
  }

  Widget _buildCategorySection(FormCategory category, List<FormTemplate> templates) {
    final color = _categoryColors[category] ?? Colors.grey;
    
    // Sort logic
    if (category == FormCategory.teaching) {
      templates.sort((a, b) {
        const order = {FormFrequency.perSession: 0, FormFrequency.weekly: 1, FormFrequency.monthly: 2};
        return (order[a.frequency] ?? 3).compareTo(order[b.frequency] ?? 3);
      });
    } else {
      templates.sort((a, b) => a.name.compareTo(b.name));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Text(
                category.displayName.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.blueGrey.shade400,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Divider(color: Colors.blueGrey.shade100, thickness: 1)),
            ],
          ),
        ),
        ...templates.map((t) => _buildFormCard(t, color)),
      ],
    );
  }

  Widget _buildFormCard(FormTemplate template, Color accentColor) {
    final formType = switch (template.frequency) {
      FormFrequency.perSession => 'daily',
      FormFrequency.weekly => 'weekly',
      FormFrequency.monthly => 'monthly',
      FormFrequency.onDemand => 'onDemand',
    };
    
    final isSubmitted = _submittedForms[formType] == true && template.category == FormCategory.teaching;
    final isAvailable = template.frequency.isAvailableToday;

    return Container(
      margin: const EdgeInsets.only(bottom: 16), // Espace entre les cartes
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        // Ombre douce et moderne
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withOpacity(0.08),
            offset: const Offset(0, 4),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: isAvailable ? () => _openForm(template, formType) : null,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Container
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isSubmitted 
                        ? Colors.green.shade50 
                        : (isAvailable ? accentColor.withOpacity(0.1) : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Icon(
                      isSubmitted ? Icons.check_rounded : _getFrequencyIcon(template.frequency),
                      color: isSubmitted 
                          ? Colors.green 
                          : (isAvailable ? accentColor : Colors.grey.shade400),
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row with Wrap to prevent overflow
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            template.name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isAvailable ? const Color(0xFF1E293B) : Colors.grey.shade400,
                              height: 1.2,
                            ),
                          ),
                          if (isSubmitted)
                            _buildStatusBadge('Completed', Colors.green),
                          if (!isAvailable && template.category == FormCategory.teaching)
                            _buildStatusBadge(
                              _getAvailabilityLabel(template.frequency),
                              Colors.orange,
                              icon: Icons.lock_outline_rounded,
                            ),
                        ],
                      ),
                      
                      const SizedBox(height: 6),
                      
                      if (template.description != null && template.description!.isNotEmpty)
                        Text(
                          template.description!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.blueGrey.shade400,
                            height: 1.4, // Meilleure lisibilité
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      
                      const SizedBox(height: 12),
                      
                      // Footer Info
                      Row(
                        children: [
                          _buildSmallInfo(Icons.format_list_bulleted_rounded, '${template.visibleFieldCount} items'),
                          const SizedBox(width: 12),
                          _buildSmallInfo(Icons.schedule_rounded, _getFrequencyLabel(template.frequency)),
                        ],
                      ),
                    ],
                  ),
                ),
                // Arrow (centrée verticalement si possible, ou top)
                if (isAvailable)
                   Padding(
                     padding: const EdgeInsets.only(left: 8, top: 12),
                     child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Colors.blueGrey.shade200,
                                     ),
                   ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String text, MaterialColor color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color.shade700),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallInfo(IconData icon, String text) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.blueGrey.shade300),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.blueGrey.shade400,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFrequencyIcon(FormFrequency frequency) {
    switch (frequency) {
      case FormFrequency.perSession: return Icons.calendar_today_rounded;
      case FormFrequency.weekly: return Icons.date_range_rounded;
      case FormFrequency.monthly: return Icons.calendar_month_rounded;
      case FormFrequency.onDemand: return Icons.touch_app_rounded;
    }
  }

  String _getFrequencyLabel(FormFrequency frequency) {
    switch (frequency) {
      case FormFrequency.perSession: return 'Daily';
      case FormFrequency.weekly: return 'Weekly';
      case FormFrequency.monthly: return 'Monthly';
      case FormFrequency.onDemand: return 'Anytime';
    }
  }

  String _getAvailabilityLabel(FormFrequency frequency) {
    switch (frequency) {
      case FormFrequency.weekly:
        return 'Sun-Tue';
      case FormFrequency.monthly:
        return 'End/Start';
      default:
        return 'Locked';
    }
  }

  void _openForm(FormTemplate template, String formType) {
    HapticFeedback.mediumImpact(); // Meilleur feedback tactile
    if (template.frequency == FormFrequency.perSession) {
      _showShiftSelectionDialog(template);
      return;
    }
    _navigateToForm(template);
  }

  Future<void> _handleShiftSelection(FormTemplate template, String shiftId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check if ANY form is already submitted for this shift (regardless of template)
    try {
      // First check for ANY form response with this shiftId (regardless of template)
      final anyExistingResponse = await FirebaseFirestore.instance
          .collection('form_responses')
          .where('shiftId', isEqualTo: shiftId)
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (anyExistingResponse.docs.isNotEmpty) {
        // Form already submitted - show read-only view with actual data
        if (!mounted) return;
        _showOldFormSubmission(anyExistingResponse.docs.first.id, anyExistingResponse.docs.first.data());
        return;
      }

      // Also check readiness_responses for old format forms
      final readinessResponse = await FirebaseFirestore.instance
          .collection('readiness_responses')
          .where('shiftId', isEqualTo: shiftId)
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (readinessResponse.docs.isNotEmpty) {
        // Old readiness form found - show it
        if (!mounted) return;
        _showOldFormSubmission(readinessResponse.docs.first.id, readinessResponse.docs.first.data(), isReadinessForm: true);
        return;
      }
    } catch (e) {
      AppLogger.error('Error checking existing submission: $e');
    }

    // No existing submission - navigate to fill form with new template
    _navigateToForm(template, shiftId: shiftId);
  }

  /// Show old format form submission in read-only view
  void _showOldFormSubmission(String submissionId, Map<String, dynamic> data, {bool isReadinessForm = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          final responses = data['responses'] as Map<String, dynamic>? ?? data;
          final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate() ?? 
                             (data['submitted_at'] as Timestamp?)?.toDate();
          final formTitle = data['formTitle'] as String? ?? 
                           data['formName'] as String? ?? 
                           (isReadinessForm ? 'Readiness Form' : 'Daily Report');
          
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xffE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xffE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    formTitle,
                                    style: GoogleFonts.inter(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xff1E293B),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xffEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.visibility_outlined, size: 14, color: Color(0xff0386FF)),
                                      const SizedBox(width: 4),
                                      Text(
                                        isReadinessForm ? 'Old Format' : 'Submitted',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xff0386FF),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              submittedAt != null
                                  ? 'Submitted on ${DateFormat('MMMM d, yyyy at h:mm a').format(submittedAt)}'
                                  : 'Submission date unknown',
                              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xff64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        color: const Color(0xff64748B),
                      ),
                    ],
                  ),
                ),
                // Content - show all fields from the submission
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount: responses.entries.length,
                    itemBuilder: (context, index) {
                      final entry = responses.entries.elementAt(index);
                      final fieldId = entry.key;
                      final value = entry.value;
                      
                      // Skip internal fields
                      if (fieldId.startsWith('_') || 
                          fieldId == 'userId' || 
                          fieldId == 'shiftId' ||
                          fieldId == 'formId' ||
                          fieldId == 'formTemplateId' ||
                          fieldId == 'submittedAt' ||
                          fieldId == 'submitted_at' ||
                          fieldId == 'formTitle' ||
                          fieldId == 'formName' ||
                          fieldId == 'yearMonth' ||
                          fieldId == 'formType') {
                        return const SizedBox.shrink();
                      }
                      
                      // Format field label from camelCase to Title Case
                      final label = _formatFieldLabel(fieldId);
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xffE2E8F0)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xff64748B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatFieldValue(value),
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: const Color(0xff1E293B),
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
          );
        },
      ),
    );
  }

  String _formatFieldLabel(String fieldId) {
    // Convert camelCase or snake_case to Title Case
    final words = fieldId
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .replaceAll('_', ' ')
        .trim()
        .split(' ');
    return words.map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '').join(' ');
  }

  String _formatFieldValue(dynamic value) {
    if (value == null) return 'Not provided';
    if (value is Timestamp) {
      return DateFormat('MMMM d, yyyy at h:mm a').format(value.toDate());
    }
    if (value is List) {
      return value.join(', ');
    }
    if (value is bool) {
      return value ? 'Yes' : 'No';
    }
    return value.toString();
  }

  Future<void> _showSubmittedFormView(String submissionId, FormTemplate template) async {
    // Fetch the submission data and show it directly in read-only view
    try {
      final submissionDoc = await FirebaseFirestore.instance
          .collection('form_responses')
          .doc(submissionId)
          .get();

      if (!submissionDoc.exists || !mounted) {
        return;
      }

      final submissionData = submissionDoc.data() as Map<String, dynamic>;
      
      // Show the submission details directly in a modal bottom sheet using the same pattern as MySubmissionsScreen
      if (!mounted) return;
      
      // Navigate to MySubmissionsScreen - it will handle showing the submission details
      // For now, we'll create a simple inline view since _SubmissionDetailView is private
      _showSubmissionDetailSheet(submissionId, template.name, submissionData, template);
    } catch (e) {
      AppLogger.error('Error loading submission: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorLoadingSubmissionE)),
      );
    }
  }

  void _showSubmissionDetailSheet(String submissionId, String formTitle, Map<String, dynamic> data, FormTemplate template) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          final responses = data['responses'] as Map<String, dynamic>? ?? {};
          final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
          final templateFields = template.fields;
          
          // Build field labels from template
          final fieldLabels = <String, String>{};
          for (var field in templateFields) {
            fieldLabels[field.id] = field.label;
          }
          
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xffE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xffE2E8F0)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formTitle,
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xff1E293B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              submittedAt != null
                                  ? 'Submitted on ${DateFormat('MMMM d, yyyy at h:mm a').format(submittedAt)}'
                                  : 'Submission date unknown',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: const Color(0xff64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        color: const Color(0xff64748B),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: responses.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.inbox_outlined,
                                size: 64,
                                color: Color(0xff94A3B8),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                AppLocalizations.of(context)!.noResponsesFound,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: const Color(0xff64748B),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(20),
                          itemCount: responses.length,
                          itemBuilder: (context, index) {
                            final entry = responses.entries.elementAt(index);
                            final fieldId = entry.key;
                            final value = entry.value;
                            final label = fieldLabels[fieldId] ?? fieldId;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xffE2E8F0)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xff64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    value.toString(),
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      color: const Color(0xff1E293B),
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
          );
        },
      ),
    );
  }

  Future<void> _navigateToForm(FormTemplate template, {String? shiftId}) async {
    // For weekly and monthly forms, fetch the latest version (same as daily forms)
    // This ensures users always get the latest version, not a cached old one
    FormTemplate? latestTemplate = template;
    
    if (template.frequency == FormFrequency.weekly) {
      // Fetch latest weekly template
      latestTemplate = await FormTemplateService.getActiveWeeklyTemplate(forceRefresh: true);
      if (latestTemplate == null) {
        // Fallback to the template we have if fetch fails
        latestTemplate = template;
      }
    } else if (template.frequency == FormFrequency.monthly) {
      // Fetch latest monthly template
      latestTemplate = await FormTemplateService.getActiveMonthlyTemplate(forceRefresh: true);
      if (latestTemplate == null) {
        // Fallback to the template we have if fetch fails
        latestTemplate = template;
      }
    }
    // For daily (perSession) and onDemand forms, use the template directly
    // (daily forms already fetch latest in _handleShiftSelection via getActiveDailyTemplate)
    
    if (!mounted) return;
    
    // Navigate to form screen with the latest template
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormScreen(
          template: latestTemplate, // Use latest version for weekly/monthly
          shiftId: shiftId, 
        ),
      ),
    ).then((_) {
      // Refresh submission status when returning
      if (mounted) {
        _loadSubmissionStatus();
      }
    });
  }

  Future<void> _showShiftSelectionDialog(FormTemplate template) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch shifts for the whole current month - show ALL statuses including missed
      // Use existing index pattern: query by teacher_id only, then filter/sort in memory
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      
      final shiftsSnapshot = await FirebaseFirestore.instance
          .collection('teaching_shifts')
          .where('teacher_id', isEqualTo: user.uid)
          .get();
      
      // Filter and sort in memory (matches pattern used in ShiftService.getTeacherShifts)
      final allShifts = shiftsSnapshot.docs.map((doc) {
        final data = doc.data();
        DateTime? shiftStart;
        final shiftStartValue = data['shift_start'];
        if (shiftStartValue is Timestamp) {
          shiftStart = shiftStartValue.toDate();
        } else if (shiftStartValue is DateTime) {
          shiftStart = shiftStartValue;
        }
        return {
          'doc': doc,
          'shiftStart': shiftStart,
        };
      }).toList();
      
      // Filter: only completed or missed shifts that have ended (not future, not scheduled)
      
      
      final recentShifts = allShifts
          .where((item) {
            final doc = item['doc'] as QueryDocumentSnapshot;
            final data = doc.data() as Map<String, dynamic>;
            final shiftStart = item['shiftStart'] as DateTime?;
            final shiftId = doc.id;
            
            if (shiftStart == null) return false;
            
            // Get shift end time
            DateTime? shiftEnd;
            final endValue = data['shift_end'];
            if (endValue is Timestamp) {
              shiftEnd = endValue.toDate();
            } else if (endValue is DateTime) {
              shiftEnd = endValue;
            }
            
            if (shiftEnd == null) return false;
            
            // Convert to local time for comparison
            final startLocal = shiftStart.toLocal();
            final endLocal = shiftEnd.toLocal();
            
            // Get status from Firestore
            final statusStr = data['status'] as String? ?? 'scheduled';
            
            
            // FIRST CHECK: Explicitly exclude scheduled, active, cancelled
            if (statusStr == 'scheduled' || statusStr == 'active' || statusStr == 'cancelled') {
              return false;
            }
            
            // SECOND CHECK: Must be in a completed/missed state
            final isCompletedOrMissed = statusStr == 'completed' || 
                                       statusStr == 'fullyCompleted' ||
                                       statusStr == 'partiallyCompleted' ||
                                       statusStr == 'missed';
            
            if (!isCompletedOrMissed) {
              return false;
            }
            
            // THIRD CHECK: Must have started AND ended (both must be in the past)
            if (!startLocal.isBefore(now)) {
              return false; // Has not started yet
            }
            
            // FOURTH CHECK: Shift must be within the current month (so teachers see the whole month)
            if (startLocal.isBefore(startOfMonth)) {
              return false; // Before current month
            }
            
            // Shift must have ended (end time is in the past, at least 1 second ago)
            final timeSinceEnd = now.difference(endLocal);
            if (timeSinceEnd.inSeconds <= 0) {
              return false; // Has not ended yet
            }
            
            // All checks passed - include this shift
            return true;
          })
          .toList()
          ..sort((a, b) {
            final aStart = a['shiftStart'] as DateTime?;
            final bStart = b['shiftStart'] as DateTime?;
            if (aStart == null && bStart == null) return 0;
            if (aStart == null) return 1;
            if (bStart == null) return -1;
            return bStart.compareTo(aStart); // Descending (most recent first)
          });
      
      // Show all shifts in the month (up to 100 to cover busy schedules)
      final shiftsToShow = recentShifts.take(100).map((item) => item['doc'] as QueryDocumentSnapshot).toList();
      

      // Check for existing forms for each shift
      final shiftsWithFormStatus = <Map<String, dynamic>>[];
      for (final doc in shiftsToShow) {
        final shiftId = doc.id;
        final formResponseId = await ShiftFormService.getFormResponseForShift(shiftId);
        final hasForm = formResponseId != null;
        
        shiftsWithFormStatus.add({
          'doc': doc,
          'shiftId': shiftId,
          'hasForm': hasForm,
          'formResponseId': formResponseId,
        });
      }

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (shiftsWithFormStatus.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.noRecentShiftsFoundToReport)),
        );
        return;
      }
      
      if (!mounted) return;
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent, // Important pour le design
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  AppLocalizations.of(context)!.selectAShift,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: shiftsWithFormStatus.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final shiftInfo = shiftsWithFormStatus[index];
                      final doc = shiftInfo['doc'] as QueryDocumentSnapshot;
                      final shiftData = doc.data() as Map<String, dynamic>;
                      final shiftId = shiftInfo['shiftId'] as String;
                      final hasForm = shiftInfo['hasForm'] as bool;
                      final formResponseId = shiftInfo['formResponseId'] as String?;
                      
                      // Handle both Timestamp and DateTime types
                      DateTime startTime;
                      final startValue = shiftData['shift_start'];
                      if (startValue is Timestamp) {
                        startTime = startValue.toDate();
                      } else if (startValue is DateTime) {
                        startTime = startValue;
                      } else {
                        startTime = DateTime.now(); // Fallback
                      }
                      
                      DateTime endTime;
                      final endValue = shiftData['shift_end'];
                      if (endValue is Timestamp) {
                        endTime = endValue.toDate();
                      } else if (endValue is DateTime) {
                        endTime = endValue;
                      } else {
                        endTime = DateTime.now(); // Fallback
                      }
                      
                      final status = shiftData['status'] ?? 'scheduled';
                      
                      // Get student names - prefer student_names array, fallback to studentNames
                      final studentNamesList = shiftData['student_names'] ?? shiftData['studentNames'] ?? [];
                      final studentNames = studentNamesList is List
                          ? (studentNamesList as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
                          : [];
                      
                      // Display student names, or subject if no student names available
                      final displayName = studentNames.isNotEmpty
                          ? studentNames.join(', ')
                          : (shiftData['subject']?.toString() ??
                              AppLocalizations.of(context)!.commonUnknownSubject);
                      
                      Color statusColor = Colors.grey;
                      if (status == 'completed' || status == 'fullyCompleted') statusColor = Colors.green;
                      else if (status == 'active') statusColor = Colors.blue;
                      else if (status == 'missed') statusColor = Colors.red;
                      else if (status == 'partiallyCompleted') statusColor = Colors.orange;
                      
                      return Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      displayName,
                                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: statusColor, width: 1),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                '${DateFormat('MMM d').format(startTime)} • ${DateFormat('h:mm a').format(startTime)} - ${DateFormat('h:mm a').format(endTime)}',
                                style: GoogleFonts.inter(fontSize: 13),
                              ),
                              onTap: hasForm
                                  ? null // Disable tap if form exists (use eye icon)
                                  : () async {
                                      Navigator.pop(context);
                                      await _handleShiftSelection(template, shiftId);
                                    },
                              trailing: hasForm
                                  ? IconButton(
                                      icon: const Icon(Icons.visibility, color: Color(0xff10B981)),
                                      tooltip: AppLocalizations.of(context)!.viewForm,
                                      onPressed: () async {
                                        try {
                                          final formDoc = await FirebaseFirestore.instance
                                              .collection('form_responses')
                                              .doc(formResponseId!)
                                              .get();
                                          
                                          if (formDoc.exists && mounted) {
                                            final data = formDoc.data() ?? {};
                                            final responses = data['responses'] as Map<String, dynamic>? ?? {};
                                            
                                            Navigator.pop(context); // Close shift selection
                                            
                                            FormDetailsModal.show(
                                              context,
                                              formId: formResponseId!,
                                              shiftId: shiftId,
                                              responses: responses,
                                            );
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(AppLocalizations.of(context)!
                                                    .formsErrorLoadingForm(e.toString())),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    )
                                  : null,
                            ),
                            // Action buttons row
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              child: Row(
                                children: [
                                  // View Form button (only show if form doesn't exist)
                                  if (!hasForm)
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          await _handleShiftSelection(template, shiftId);
                                        },
                                        icon: const Icon(Icons.description_outlined, size: 16),
                                        label: Text(AppLocalizations.of(context)!.form, style: GoogleFonts.inter(fontSize: 12)),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          side: BorderSide(color: Colors.blue.shade300),
                                          foregroundColor: Colors.blue,
                                        ),
                                      ),
                                    ),
                                  if (!hasForm) const SizedBox(width: 8),
                                  // Timesheet button
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _showTimesheetForShift(shiftId, shiftData);
                                      },
                                      icon: const Icon(Icons.access_time, size: 16),
                                      label: Text(AppLocalizations.of(context)!.timesheetTitle, style: GoogleFonts.inter(fontSize: 12)),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        side: BorderSide(color: Colors.green.shade300),
                                        foregroundColor: Colors.green,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Shift Details button
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _showShiftDetails(shiftId, shiftData);
                                      },
                                      icon: const Icon(Icons.info_outline, size: 16),
                                      label: Text(AppLocalizations.of(context)!.details, style: GoogleFonts.inter(fontSize: 12)),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        side: BorderSide(color: Colors.orange.shade300),
                                        foregroundColor: Colors.orange,
                                      ),
                                    ),
                                  ),
                                ],
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
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading if error
      debugPrint('Error fetching shifts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorLoadingShiftsE)),
        );
      }
    }
  }

  /// Show timesheet for a specific shift
  Future<void> _showTimesheetForShift(String shiftId, Map<String, dynamic> shiftData) async {
    try {
      // Query timesheet for this shift
      final timesheetSnapshot = await FirebaseFirestore.instance
          .collection('timesheet_entries')
          .where('shift_id', isEqualTo: shiftId)
          .limit(1)
          .get();

      if (!mounted) return;

      if (timesheetSnapshot.docs.isEmpty) {
        // No timesheet found - show message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.noTimesheetFoundForThisShift)),
        );
        return;
      }

      final timesheetDoc = timesheetSnapshot.docs.first;
      final timesheetData = timesheetDoc.data();

      // Show edit timesheet dialog
      showDialog(
        context: context,
        builder: (context) => EditTimesheetDialog(
          timesheetId: timesheetDoc.id,
          timesheetData: timesheetData,
          onUpdated: () {
            // Refresh if needed
          },
        ),
      );
    } catch (e) {
      AppLogger.error('Error loading timesheet: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorLoadingTimesheetE)),
      );
    }
  }

  /// Show shift details dialog
  void _showShiftDetails(String shiftId, Map<String, dynamic> shiftData) {
    // Convert to TeachingShift model
    try {
      // Handle both Timestamp and DateTime types for shift times
      DateTime shiftStart;
      final startValue = shiftData['shift_start'];
      if (startValue is Timestamp) {
        shiftStart = startValue.toDate();
      } else if (startValue is DateTime) {
        shiftStart = startValue;
      } else {
        shiftStart = DateTime.now(); // Fallback
      }
      
      DateTime shiftEnd;
      final endValue = shiftData['shift_end'];
      if (endValue is Timestamp) {
        shiftEnd = endValue.toDate();
      } else if (endValue is DateTime) {
        shiftEnd = endValue;
      } else {
        shiftEnd = DateTime.now(); // Fallback
      }
      
      DateTime createdAt;
      final createdAtValue = shiftData['created_at'];
      if (createdAtValue is Timestamp) {
        createdAt = createdAtValue.toDate();
      } else if (createdAtValue is DateTime) {
        createdAt = createdAtValue;
      } else {
        createdAt = DateTime.now(); // Fallback
      }
      
      // Create a fake DocumentSnapshot-like structure for TeachingShift.fromFirestore
      final shift = TeachingShift(
        id: shiftId,
        teacherId: shiftData['teacher_id'] ?? '',
        teacherName: shiftData['teacher_name'] ?? AppLocalizations.of(context)!.commonUnknown,
        studentIds: List<String>.from(shiftData['student_ids'] ?? []),
        studentNames: List<String>.from(shiftData['student_names'] ?? []),
        shiftStart: shiftStart,
        shiftEnd: shiftEnd,
        status: _parseShiftStatus(shiftData['status']),
        subject: _parseSubject(shiftData['subject']),
        hourlyRate: (shiftData['hourly_rate'] as num?)?.toDouble() ?? 0.0,
        createdAt: createdAt,
        notes: shiftData['notes'],
        adminTimezone: shiftData['admin_timezone'] ?? 'UTC',
        teacherTimezone: shiftData['teacher_timezone'] ?? 'UTC',
        autoGeneratedName: shiftData['auto_generated_name'] ?? shiftData['subject'] ?? 'Shift',
        createdByAdminId: shiftData['created_by_admin_id'] ?? shiftData['teacher_id'] ?? '',
      );

      showDialog(
        context: context,
        builder: (context) => ShiftDetailsDialog(
          shift: shift,
          onRefresh: () {
            // Refresh if needed
          },
        ),
      );
    } catch (e) {
      AppLogger.error('Error showing shift details: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorLoadingShiftDetailsE)),
      );
    }
  }

  ShiftStatus _parseShiftStatus(String? status) {
    switch (status) {
      case 'scheduled': return ShiftStatus.scheduled;
      case 'active': return ShiftStatus.active;
      case 'completed': return ShiftStatus.completed;
      case 'partiallyCompleted': return ShiftStatus.partiallyCompleted;
      case 'fullyCompleted': return ShiftStatus.fullyCompleted;
      case 'missed': return ShiftStatus.missed;
      case 'cancelled': return ShiftStatus.cancelled;
      default: return ShiftStatus.scheduled;
    }
  }

  /// Parse subject from shift data (Firestore may store String; TeachingShift requires IslamicSubject).
  IslamicSubject _parseSubject(dynamic value) {
    if (value == null) return IslamicSubject.quranStudies;
    if (value is IslamicSubject) return value;
    final s = value.toString().trim();
    if (s.isEmpty) return IslamicSubject.quranStudies;
    // Try enum name (e.g. "quranStudies")
    for (final e in IslamicSubject.values) {
      if (e.name == s) return e;
    }
    // Try normalized display/snake_case (e.g. "quran_studies", "Quran Studies")
    final normalized = s.toLowerCase().replaceAll(' ', '_');
    switch (normalized) {
      case 'quran_studies':
      case 'quran':
        return IslamicSubject.quranStudies;
      case 'hadith_studies':
      case 'hadith':
        return IslamicSubject.hadithStudies;
      case 'fiqh':
        return IslamicSubject.fiqh;
      case 'arabic_language':
      case 'arabic':
        return IslamicSubject.arabicLanguage;
      case 'islamic_history':
        return IslamicSubject.islamicHistory;
      case 'aqeedah':
        return IslamicSubject.aqeedah;
      case 'tafseer':
        return IslamicSubject.tafseer;
      case 'seerah':
        return IslamicSubject.seerah;
      default:
        return IslamicSubject.quranStudies;
    }
  }
}
