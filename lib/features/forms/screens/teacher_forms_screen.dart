import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/models/form_template.dart';
import '../../../core/services/form_template_service.dart';
import '../../../core/services/user_role_service.dart';
import '../../../form_screen.dart';

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

  // Category colors for visual distinction
  static const Map<FormCategory, Color> _categoryColors = {
    FormCategory.teaching: Color(0xFF10B981),
    FormCategory.studentAssessment: Color(0xFF3B82F6),
    FormCategory.feedback: Color(0xFF8B5CF6),
    FormCategory.administrative: Color(0xFFF59E0B),
    FormCategory.other: Color(0xFF6B7280),
  };

  // Category icons
  static const Map<FormCategory, IconData> _categoryIcons = {
    FormCategory.teaching: Icons.school_outlined,
    FormCategory.studentAssessment: Icons.assessment_outlined,
    FormCategory.feedback: Icons.feedback_outlined,
    FormCategory.administrative: Icons.admin_panel_settings_outlined,
    FormCategory.other: Icons.description_outlined,
  };

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadTemplates();
    _loadSubmissionStatus();
  }

  Future<void> _loadUserRole() async {
    final role = await UserRoleService.getCurrentUserRole();
    if (mounted) setState(() => _userRole = role);
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);
    
    try {
      // Load templates from Firestore form_templates collection
      final allTemplates = await FormTemplateService.getAllTemplates();
      
      // Organize templates by category
      _templatesByCategory = {};
      
      for (var template in allTemplates) {
        if (!template.isActive) continue;
        
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
            final hasAllowedRoles = template.allowedRoles != null && template.allowedRoles!.isNotEmpty;
            
            if (hasAllowedRoles) {
              // If allowedRoles is set, teacher must be in the list
              if (!template.allowedRoles!.contains('teacher')) {
                continue; // Skip this form - it's not for teachers
              }
            } else {
              // If no allowedRoles, only show if it's a teacher-relevant category
              // Teaching, feedback, and administrative forms are for teachers
              // Student assessment and other forms without roles are hidden from teachers
              final isTeacherCategory = template.category == FormCategory.teaching ||
                  template.category == FormCategory.feedback ||
                  template.category == FormCategory.administrative;
              
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
        
        _templatesByCategory.putIfAbsent(template.category, () => []);
        _templatesByCategory[template.category]!.add(template);
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _errorMessage != null
                      ? _buildErrorState()
                      : _buildFormsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6366F1),
            const Color(0xFF8B5CF6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Forms & Reports',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Submit reports, feedback, and assessments',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Quick stats for teaching forms
          Row(
            children: [
              _buildQuickStat(
                'Daily',
                _submittedForms['daily'] == true ? 'Done' : 'Due',
                _submittedForms['daily'] == true,
              ),
              const SizedBox(width: 12),
              _buildQuickStat(
                'Weekly',
                FormFrequency.weekly.isAvailableToday
                    ? (_submittedForms['weekly'] == true ? 'Done' : 'Due')
                    : 'Sun-Tue',
                _submittedForms['weekly'] == true,
                isAvailable: FormFrequency.weekly.isAvailableToday,
              ),
              const SizedBox(width: 12),
              _buildQuickStat(
                'Monthly',
                FormFrequency.monthly.isAvailableToday
                    ? (_submittedForms['monthly'] == true ? 'Done' : 'Due')
                    : 'End/Start',
                _submittedForms['monthly'] == true,
                isAvailable: FormFrequency.monthly.isAvailableToday,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String status, bool isComplete, {bool isAvailable = true}) {
    final Color bgColor;
    final Color textColor;
    final IconData icon;
    
    if (isComplete) {
      bgColor = Colors.green.withOpacity(0.2);
      textColor = Colors.green.shade100;
      icon = Icons.check_circle;
    } else if (!isAvailable) {
      bgColor = Colors.grey.withOpacity(0.2);
      textColor = Colors.white70;
      icon = Icons.schedule;
    } else {
      bgColor = Colors.orange.withOpacity(0.2);
      textColor = Colors.orange.shade100;
      icon = Icons.pending_actions;
    }
    
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: textColor, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    status,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Color(0xFF6366F1)),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading forms...',
            style: GoogleFonts.inter(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'An error occurred',
              style: GoogleFonts.inter(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadTemplates,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormsList() {
    // Define category order for display
    const categoryOrder = [
      FormCategory.teaching,
      FormCategory.feedback,
      FormCategory.studentAssessment,
      FormCategory.administrative,
      FormCategory.other,
    ];
    
    return RefreshIndicator(
      onRefresh: () async {
        await _loadTemplates();
        await _loadSubmissionStatus();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (var category in categoryOrder)
            if (_templatesByCategory.containsKey(category) &&
                _templatesByCategory[category]!.isNotEmpty)
              ...[
                _buildCategorySection(category, _templatesByCategory[category]!),
                const SizedBox(height: 24),
              ],
        ],
      ),
    );
  }

  Widget _buildCategorySection(FormCategory category, List<FormTemplate> templates) {
    final color = _categoryColors[category] ?? Colors.grey;
    final icon = _categoryIcons[category] ?? Icons.description;
    
    // Sort templates: teaching forms by frequency order, others by name
    if (category == FormCategory.teaching) {
      templates.sort((a, b) {
        const order = {
          FormFrequency.perSession: 0,
          FormFrequency.weekly: 1,
          FormFrequency.monthly: 2,
          FormFrequency.onDemand: 3,
        };
        return (order[a.frequency] ?? 3).compareTo(order[b.frequency] ?? 3);
      });
    } else {
      templates.sort((a, b) => a.name.compareTo(b.name));
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.displayName,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  Text(
                    '${templates.length} form${templates.length > 1 ? 's' : ''} available',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Form Cards
        ...templates.map((t) => _buildFormCard(t, color)),
      ],
    );
  }

  Widget _buildFormCard(FormTemplate template, Color accentColor) {
    // Determine form type for submission status
    final formType = switch (template.frequency) {
      FormFrequency.perSession => 'daily',
      FormFrequency.weekly => 'weekly',
      FormFrequency.monthly => 'monthly',
      FormFrequency.onDemand => 'onDemand',
    };
    
    final isSubmitted = _submittedForms[formType] == true && 
        template.category == FormCategory.teaching;
    final isAvailable = template.frequency.isAvailableToday;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSubmitted ? Colors.green.shade200 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isAvailable ? () => _openForm(template, formType) : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSubmitted 
                        ? Colors.green.shade50 
                        : (isAvailable ? accentColor.withOpacity(0.1) : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isSubmitted 
                        ? Icons.check_circle 
                        : _getFrequencyIcon(template.frequency),
                    color: isSubmitted 
                        ? Colors.green 
                        : (isAvailable ? accentColor : Colors.grey),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              template.name,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isAvailable ? const Color(0xFF1F2937) : Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSubmitted)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Done',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ),
                          if (!isAvailable && template.category == FormCategory.teaching)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.lock_outline, size: 12, color: Colors.orange.shade700),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        _getAvailabilityLabel(template.frequency),
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.orange.shade700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (template.description != null && template.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          template.description!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.list_alt, size: 14, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${template.visibleFieldCount} questions',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(_getFrequencyIcon(template.frequency), size: 14, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _getFrequencyLabel(template.frequency),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Arrow
                if (isAvailable)
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getFrequencyIcon(FormFrequency frequency) {
    switch (frequency) {
      case FormFrequency.perSession:
        return Icons.today;
      case FormFrequency.weekly:
        return Icons.date_range;
      case FormFrequency.monthly:
        return Icons.calendar_month;
      case FormFrequency.onDemand:
        return Icons.touch_app;
    }
  }

  String _getFrequencyLabel(FormFrequency frequency) {
    switch (frequency) {
      case FormFrequency.perSession:
        return 'After each class';
      case FormFrequency.weekly:
        return 'Weekly (Sun-Tue)';
      case FormFrequency.monthly:
        return 'Monthly';
      case FormFrequency.onDemand:
        return 'Anytime';
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
    HapticFeedback.lightImpact();
    
    // For perSession forms (Daily Class Report), require a shift
    if (template.frequency == FormFrequency.perSession) {
      // TODO: Show shift selection dialog or navigate to shift screen
      // For now, let's try to find the most recent unsubmitted shift
      _showShiftSelectionDialog(template);
      return;
    }
    
    _navigateToForm(template);
  }

  void _navigateToForm(FormTemplate template, {String? shiftId}) {
    // Navigate to form screen with the template directly
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormScreen(
          template: template, // Pass template directly instead of ID
          shiftId: shiftId, 
        ),
      ),
    ).then((_) {
      // Refresh submission status when returning
      _loadSubmissionStatus();
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
      // Fetch recent shifts (last 7 days)
      final now = DateTime.now();
      final lastWeek = now.subtract(const Duration(days: 7));
      
      final shiftsSnapshot = await FirebaseFirestore.instance
          .collection('teaching_shifts')
          .where('teacherId', isEqualTo: user.uid)
          .where('shift_start', isGreaterThanOrEqualTo: Timestamp.fromDate(lastWeek))
          .orderBy('shift_start', descending: true)
          .limit(20)
          .get();

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (shiftsSnapshot.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No recent shifts found to report on.')),
        );
        return;
      }

      // Filter out shifts that already have a daily report
      // Ideally this should be done by checking form_responses, but for now let's just show the list
      // and let the user pick. The form screen will handle linking.
      
      if (!mounted) return;
      
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Select a Shift',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: shiftsSnapshot.docs.length,
                  itemBuilder: (context, index) {
                    final shift = shiftsSnapshot.docs[index].data();
                    final shiftId = shiftsSnapshot.docs[index].id;
                    final startTime = (shift['shift_start'] as Timestamp).toDate();
                    final endTime = (shift['shift_end'] as Timestamp).toDate();
                    final subject = shift['subject'] ?? 'Unknown Subject';
                    
                    return ListTile(
                      title: Text(subject),
                      subtitle: Text(
                        '${DateFormat('MMM d').format(startTime)} • ${DateFormat('h:mm a').format(startTime)} - ${DateFormat('h:mm a').format(endTime)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(context); // Close sheet
                        _navigateToForm(template, shiftId: shiftId);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading if error
      debugPrint('Error fetching shifts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading shifts: $e')),
        );
      }
    }
  }
}
