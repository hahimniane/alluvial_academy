import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'core/services/user_role_service.dart';
import 'core/services/shift_form_service.dart';
import 'core/services/shift_service.dart';
import 'core/enums/shift_enums.dart';
import 'features/forms/widgets/form_details_modal.dart';
import 'features/forms/utils/form_localization.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/core/models/form_template.dart';
import 'package:alluwalacademyadmin/core/services/form_template_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class FormScreen extends StatefulWidget {
  final String? timesheetId;
  final String? shiftId;
  final String? autoSelectFormId; // Auto-select and open a specific form by ID (can be from 'form' or 'form_templates')
  final FormTemplate? template; // Direct template object (preferred for new templates)

  const FormScreen({
    super.key,
    this.timesheetId,
    this.shiftId,
    this.autoSelectFormId,
    this.template,
  });

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  String? selectedFormId;
  Map<String, dynamic>? selectedFormData;
  Map<String, TextEditingController> fieldControllers = {};
  Map<String, dynamic> fieldValues =
      {}; // For non-text values like images, booleans
  String searchQuery = '';
  bool _isSubmitting = false;
  bool _isAutoSelecting = false; // New state to track auto-selection
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final Map<String, bool> _userFormSubmissions = {}; // Track user form submissions
  String? _currentUserRole;
  String? _currentUserId;
  Map<String, dynamic>? _currentUserData;
  
  // Google Forms style: Track focused field for visual feedback
  String? _focusedFieldKey;

  // Google Forms colors
  final Color _primaryColor = const Color(0xff673AB7); // Google Forms Purple
  final Color _accentColor = const Color(0xff0386FF);
  final Color _backgroundColor = const Color(0xffF0F4F8);
  
  // Platform detection for responsive layouts
  bool get _isMobile {
    if (kIsWeb) return false;
    final platform = defaultTargetPlatform;
    return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Add debugging for production
    AppLogger.debug(
        'FormScreen: Initializing in ${kDebugMode ? 'debug' : 'production'} mode');
    AppLogger.debug('FormScreen: Auth state - ${FirebaseAuth.instance.currentUser?.uid}');

    _loadUserFormSubmissions();
    _loadCurrentUserData();
    
    // If template is provided directly, use it IMMEDIATELY (no delay)
    if (widget.template != null) {
      _isAutoSelecting = true;
      final formData = _convertTemplateToFormData(widget.template!);
      // Set form data immediately to avoid showing the list screen
      selectedFormId = widget.template!.id;
      selectedFormData = formData;
      // Don't initialize controllers here - let _handleFormSelection do it with auto-fill
      // Load form data asynchronously (for auto-fill, etc.)
      _handleFormSelection(widget.template!.id, formData).then((_) {
        if (mounted) {
          setState(() => _isAutoSelecting = false);
        }
      });
    } else if (widget.autoSelectFormId != null) {
      // Auto-select form if specified
      _isAutoSelecting = true;
      _autoSelectForm(widget.autoSelectFormId!);
    }
  }
  
  /// Auto-select a form by ID (used when navigating from clock-out)
  /// First tries form_templates, then falls back to form collection
  Future<void> _autoSelectForm(String formId) async {
    try {
      
      AppLogger.debug('FormScreen: Auto-selecting form: $formId');
      debugPrint('📋 FormScreen: Auto-selecting form with ID: $formId');
      debugPrint('📋 FormScreen: timesheetId=${widget.timesheetId}, shiftId=${widget.shiftId}');
      
      // First, try to find in form_templates (new system) - force refresh from server
      final templateDoc = await FirebaseFirestore.instance
          .collection('form_templates')
          .doc(formId)
          .get(const GetOptions(source: Source.server));
      
      
      if (templateDoc.exists && mounted) {
        // Convert template to form format
        final template = FormTemplate.fromFirestore(templateDoc);
        final formData = _convertTemplateToFormData(template);
        
        
        debugPrint('✅ FormScreen: Template found - "${template.name}"');
        
        // Call _handleFormSelection directly (no delay needed - it's async)
        if (mounted) {
          _handleFormSelection(formId, formData).then((_) {
            if (mounted) {
              setState(() => _isAutoSelecting = false);
              debugPrint('✅ FormScreen: Template selected and displayed');
            }
          });
        }
        return;
      }
      
      // Fallback to old form collection - force refresh from server
      final formDoc = await FirebaseFirestore.instance
          .collection('form')
          .doc(formId)
          .get(const GetOptions(source: Source.server));
      
      if (formDoc.exists && mounted) {
        final formData = formDoc.data()!;
        debugPrint('✅ FormScreen: Form found - "${formData['title'] ?? 'Untitled'}"');
        
        // Call _handleFormSelection directly (no delay needed - it's async)
        if (mounted) {
          _handleFormSelection(formId, formData).then((_) {
            if (mounted) {
              setState(() => _isAutoSelecting = false);
              debugPrint('✅ FormScreen: Form selected and displayed');
            }
          });
        }
      } else {
        AppLogger.error('FormScreen: Form not found for auto-select: $formId');
        debugPrint('❌ FormScreen: Form with ID $formId NOT FOUND in database!');
        
        // Show error message to user
        if (mounted) {
          setState(() => _isAutoSelecting = false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.formNotFoundIdFormidPlease),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          });
        }
      }
    } catch (e) {
      AppLogger.error('FormScreen: Error auto-selecting form: $e');
      debugPrint('❌ FormScreen: Error auto-selecting form: $e');
      if (mounted) setState(() => _isAutoSelecting = false);
    }
  }
  
  /// Convert FormTemplate to the format expected by FormScreen (legacy form format)
  Map<String, dynamic> _convertTemplateToFormData(FormTemplate template) {
    // Convert fields from List<FormFieldDefinition> to Map<String, dynamic>
    final fieldsMap = <String, dynamic>{};
    for (var field in template.fields) {
      fieldsMap[field.id] = {
        'label': field.label,
        'type': field.type,
        'placeholder': field.placeholder,
        'required': field.required,
        'order': field.order,
        if (field.options != null) 'options': field.options,
        if (field.validation != null) 'validation': field.validation,
        if (field.conditionalLogic != null) 'conditionalLogic': field.conditionalLogic,
      };
    }
    
    // Convert autoFillRules to list of maps
    final autoFillRulesList = template.autoFillRules.map((rule) => {
      'fieldId': rule.fieldId,
      'sourceField': rule.sourceFieldString,
      'editable': rule.editable,
    }).toList();
    
    return {
      'title': template.name, // Use name as title
      'description': template.description ?? '',
      'fields': fieldsMap,
      'autoFillRules': autoFillRulesList, // Include auto-fill rules
      'status': template.isActive ? 'active' : 'inactive',
      'frequency': template.frequency.name,
      'category': template.category.name,
      'version': template.version,
      'createdAt': Timestamp.fromDate(template.createdAt),
      'updatedAt': Timestamp.fromDate(template.updatedAt),
      'isTemplate': true, // Flag to indicate this is from form_templates
      'templateId': template.id, // Keep reference to original template ID
    };
  }

  Future<void> _loadUserFormSubmissions() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final submissions = await FirebaseFirestore.instance
          .collection('form_responses')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      if (mounted) {
        setState(() {
          _userFormSubmissions.clear();
          for (var doc in submissions.docs) {
            final formId = doc.data()['formId'] as String?;
            if (formId != null) {
              _userFormSubmissions[formId] = true;
            }
          }
        });
      }
    } catch (e) {
      AppLogger.error('Error loading user form submissions: $e');
    }
  }

  Future<void> _loadCurrentUserData() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        AppLogger.debug('FormScreen: No authenticated user found');
        if (mounted) {
          setState(() {
            _currentUserId = null;
            _currentUserRole = null;
            _currentUserData = null;
          });
        }
        return;
      }

      AppLogger.debug('FormScreen: Loading data for user: ${currentUser.uid}');

      // Get user role and data with timeout and retry logic
      String? userRole;
      Map<String, dynamic>? userData;

      try {
        // Try to get user role with timeout
        userRole = await UserRoleService.getCurrentUserRole()
            .timeout(const Duration(seconds: 15));
        AppLogger.info('FormScreen: User role loaded: $userRole');
      } catch (e) {
        AppLogger.error('FormScreen: Error getting user role: $e');
        userRole = 'student'; // Safe fallback
      }

      try {
        // Try to get user data with timeout
        userData = await UserRoleService.getCurrentUserData()
            .timeout(const Duration(seconds: 15));
        AppLogger.info('FormScreen: User data loaded: ${userData?.keys}');
      } catch (e) {
        AppLogger.error('FormScreen: Error getting user data: $e');
        // Continue without user data
      }

      if (mounted) {
        setState(() {
          _currentUserId = currentUser.uid;
          _currentUserRole = userRole;
          _currentUserData = userData;
        });
      }

      AppLogger.info('FormScreen: Current user loaded successfully:');
      AppLogger.debug('- User ID: $_currentUserId');
      AppLogger.debug('- User Role: $_currentUserRole');
      AppLogger.debug('- User Data keys: ${_currentUserData?.keys}');
    } catch (e) {
      AppLogger.error('FormScreen: Critical error loading current user data: $e');
      // Set safe fallback state
      if (mounted) {
        setState(() {
          _currentUserId = FirebaseAuth.instance.currentUser?.uid;
          _currentUserRole = 'student'; // Safe fallback
          _currentUserData = null;
        });
      }
    }
  }

  /// Helper method to check if roles match (handles both singular and plural forms)
  bool _roleMatches(String allowedRole, String? userRole) {
    if (userRole == null) return false;

    // Direct match
    if (allowedRole == userRole) return true;

    // Handle plural to singular conversion
    Map<String, String> pluralToSingular = {
      'admins': 'admin',
      'teachers': 'teacher',
      'students': 'student',
      'parents': 'parent',
    };

    String singularAllowedRole = pluralToSingular[allowedRole] ?? allowedRole;
    return singularAllowedRole == userRole;
  }

  /// Check if the current user can access a specific form
  bool _canAccessForm(Map<String, dynamic> formData) {
    // If user data is not loaded yet, don't show any forms
    if (_currentUserId == null || _currentUserRole == null) {
      return false;
    }

    final formTitle = (formData['title'] ?? 'Untitled Form').toString().toLowerCase();
    final isTeacher = _currentUserRole?.toLowerCase() == 'teacher';
    
    // Admin-only form keywords (teachers should NOT see these)
    const adminOnlyKeywords = [
      'admin',
      'coach',
      'leadership',
      'management',
      'ceo',
      'director',
      'supervisor',
      'payroll',
      'paycheck',
      'salary',
      'audit',
      'performance review',
      'staff evaluation',
    ];
    
    // Teacher-allowed form keywords
    const teacherAllowedKeywords = [
      'teacher',
      'excuse',
      'student',
      'class',
      'lesson',
      'feedback',
      'complaint',
      'assessment',
      'grade',
    ];
    
    // If teacher, check if form title contains admin-only keywords
    if (isTeacher) {
      for (final keyword in adminOnlyKeywords) {
        if (formTitle.contains(keyword)) {
          // Exception: if it also contains teacher-allowed keywords
          bool hasTeacherKeyword = false;
          for (final tk in teacherAllowedKeywords) {
            if (formTitle.contains(tk)) {
              hasTeacherKeyword = true;
              break;
            }
          }
          if (!hasTeacherKeyword) {
            AppLogger.debug('Form "$formTitle": Hidden from teacher (admin-only keyword: $keyword)');
            return false;
          }
        }
      }
    }

    // Get form permissions
    final permissions = formData['permissions'] as Map<String, dynamic>?;

    // If no permissions are set or permissions is null, it's a public form
    if (permissions == null || permissions.isEmpty) {
      AppLogger.debug('Form "$formTitle": Public access (no permissions set)');
      return true;
    }

    final permissionType = permissions['type'] as String?;

    // Public forms are accessible to everyone
    if (permissionType == null || permissionType == 'public') {
      AppLogger.debug('Form "$formTitle": Public access');
      return true;
    }

    // For restricted forms, check access
    if (permissionType == 'restricted') {
      final allowedRole = permissions['role'] as String?;
      final allowedUsers = permissions['users'] as List<dynamic>?;

      AppLogger.debug('Form "$formTitle": Restricted access - checking permissions');
      AppLogger.debug('- User role: $_currentUserRole, Required role: $allowedRole');
      AppLogger.debug('- User ID: $_currentUserId, Allowed users: $allowedUsers');

      // Check if user's role matches the allowed role
      if (allowedRole != null && _roleMatches(allowedRole, _currentUserRole)) {
        AppLogger.debug('Form "$formTitle": Access granted by role match');
        return true;
      }

      // Check if user is specifically allowed
      if (allowedUsers != null && allowedUsers.contains(_currentUserId)) {
        AppLogger.debug('Form "$formTitle": Access granted by user ID match');
        return true;
      }

      // If neither role nor specific user access matches, deny access
      AppLogger.debug('Form "$formTitle": Access denied - no role or user match');
      return false;
    }

    // Unknown permission type, deny access by default
    AppLogger.debug(
        'Form "$formTitle": Access denied - unknown permission type: $permissionType');
    return false;
  }

  /// Build a small permission indicator widget for admin users
  Widget _buildPermissionIndicator(Map<String, dynamic> formData) {
    final permissions = formData['permissions'] as Map<String, dynamic>?;

    if (permissions == null ||
        permissions.isEmpty ||
        permissions['type'] == 'public') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xff10B981).withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          AppLocalizations.of(context)!.public,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: const Color(0xff10B981),
          ),
        ),
      );
    }

    if (permissions['type'] == 'restricted') {
      final role = permissions['role'] as String?;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xffF59E0B).withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          role != null
              ? '${role[0].toUpperCase()}${role.substring(1)}'
              : 'Restricted',
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: const Color(0xffF59E0B),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    if (_isMobile) {
      return _buildMobileLayout();
    }
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: Row(
        children: [
          // Left sidebar with form list - HIDE if template is provided or form is selected
          if (widget.template == null && selectedFormData == null)
            Container(
              width: 320,
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0F000000),
                    offset: Offset(2, 0),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xff0386FF),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.description,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context)!.activeForms,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Search bar
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.searchActiveForms,
                            hintStyle: GoogleFonts.inter(
                              color: const Color(0xff6B7280),
                              fontSize: 14,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Color(0xff6B7280),
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          style: GoogleFonts.inter(fontSize: 14),
                          onChanged: (value) {
                            if (mounted) {
                              setState(() {
                                searchQuery = value.toLowerCase();
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Forms list
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('form')
                        .snapshots(),
                    builder: (context, snapshot) {
                      // Enhanced error handling
                      if (snapshot.hasError) {
                        AppLogger.error('FormScreen: Firestore error: ${snapshot.error}');
                        return _buildErrorState(AppLocalizations.of(context)!
                            .formsErrorLoading(snapshot.error.toString()));
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildLoadingState();
                      }

                      if (!snapshot.hasData) {
                        AppLogger.debug('FormScreen: No snapshot data received');
                        return _buildErrorState(AppLocalizations.of(context)!
                            .formsNoDataReceived);
                      }

                      // Show loading state if user data is not loaded yet
                      if (_currentUserId == null || _currentUserRole == null) {
                        AppLogger.info(
                            'FormScreen: User data not loaded yet - userId: $_currentUserId, role: $_currentUserRole');
                        return _buildLoadingState();
                      }

                      AppLogger.debug(
                          'FormScreen: Processing ${snapshot.data!.docs.length} forms from Firestore');

                      final allForms = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;

                        // First check if the form is active
                        final status = data['status'] ?? 'active';
                        if (status != 'active') {
                          return false;
                        }

                        // Then check if user can access this form
                        if (!_canAccessForm(data)) {
                          return false;
                        }

                        // Finally check if it matches the search query
                        return data['title']
                            .toString()
                            .toLowerCase()
                            .contains(searchQuery);
                      }).toList();

                      // Filter to show only latest version of each form
                      // Group by title (normalized) and keep only the one with latest updatedAt or createdAt
                      final Map<String, QueryDocumentSnapshot> latestForms = {};
                      for (var doc in allForms) {
                        final data = doc.data() as Map<String, dynamic>;
                        // Normalize title: trim, lowercase, remove extra spaces
                        final title = (data['title'] ?? '').toString()
                            .trim()
                            .toLowerCase()
                            .replaceAll(RegExp(r'\s+'), ' ');
                        
                        // Get update time (prefer updatedAt, fallback to createdAt)
                        Timestamp? updateTime;
                        if (data['updatedAt'] != null) {
                          final updatedAtValue = data['updatedAt'];
                          if (updatedAtValue is Timestamp) {
                            updateTime = updatedAtValue;
                          } else if (updatedAtValue is DateTime) {
                            updateTime = Timestamp.fromDate(updatedAtValue);
                          }
                        } else if (data['createdAt'] != null) {
                          final createdAtValue = data['createdAt'];
                          if (createdAtValue is Timestamp) {
                            updateTime = createdAtValue;
                          } else if (createdAtValue is DateTime) {
                            updateTime = Timestamp.fromDate(createdAtValue);
                          }
                        }
                        
                        if (!latestForms.containsKey(title)) {
                          latestForms[title] = doc;
                        } else {
                          final existingDoc = latestForms[title]!;
                          final existingData = existingDoc.data() as Map<String, dynamic>;
                          Timestamp? existingTime;
                          if (existingData['updatedAt'] != null) {
                            final existingUpdatedAt = existingData['updatedAt'];
                            if (existingUpdatedAt is Timestamp) {
                              existingTime = existingUpdatedAt;
                            } else if (existingUpdatedAt is DateTime) {
                              existingTime = Timestamp.fromDate(existingUpdatedAt);
                            }
                          } else if (existingData['createdAt'] != null) {
                            final existingCreatedAt = existingData['createdAt'];
                            if (existingCreatedAt is Timestamp) {
                              existingTime = existingCreatedAt;
                            } else if (existingCreatedAt is DateTime) {
                              existingTime = Timestamp.fromDate(existingCreatedAt);
                            }
                          }
                          
                          // Keep the one with the latest timestamp
                          if (updateTime != null && existingTime != null) {
                            if (updateTime.compareTo(existingTime) > 0) {
                              latestForms[title] = doc;
                            }
                          } else if (updateTime != null) {
                            latestForms[title] = doc;
                          }
                        }
                      }
                      
                      final forms = latestForms.values.toList();

                      if (forms.isEmpty) {
                        return _buildEmptyState();
                      }

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('form_responses')
                            .where('userId',
                                isEqualTo:
                                    FirebaseAuth.instance.currentUser?.uid)
                            .snapshots(),
                        builder: (context, responsesSnapshot) {
                          // Check auth state before processing
                          if (FirebaseAuth.instance.currentUser == null) {
                            return Center(
                              child: Text(AppLocalizations.of(context)!.pleaseSignInToViewForms),
                            );
                          }

                          if (responsesSnapshot.hasError) {
                            // Handle permission errors gracefully
                            if (responsesSnapshot.error
                                .toString()
                                .contains('permission-denied')) {
                              return Center(
                                child: Text(AppLocalizations.of(context)!.pleaseSignInToAccessForms),
                              );
                            }
                            return Center(
                              child: Text(AppLocalizations.of(context)!.commonErrorWithDetails(
                                responsesSnapshot.error.toString(),
                              )),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: forms.length,
                            itemBuilder: (context, index) {
                              final form =
                                  forms[index].data() as Map<String, dynamic>;
                              final isSelected =
                                  forms[index].id == selectedFormId;
                              final formId = forms[index].id;

                              // Check if user has submitted this form
                              final hasSubmitted =
                                  _userFormSubmissions[formId] ?? false;

                              return _buildFormCard(
                                  form, formId, isSelected, hasSubmitted);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Main content area
          Expanded(
            child: _buildMainContent(),
          ),
        ],
      ),
    );
  }

  /// Build main content - never show list if template is provided
  Widget _buildMainContent() {
    // If template is provided, NEVER show the list - always show form or loading
    if (widget.template != null) {
      if (_isAutoSelecting || selectedFormData == null) {
        return _buildLoadingState();
      }
      return _buildFormView();
    }
    
    // No template provided - show list or form based on selection
    if (_isAutoSelecting) {
      return _buildLoadingState();
    }
    
    if (selectedFormData == null) {
      return _buildWelcomeScreen(); // Show form list
    }
    
    return _buildFormView(); // Show selected form
  }
  
  Widget _buildMobileLayout() {
    // On mobile, show either the form list OR the selected form
    if (selectedFormData != null || widget.template != null) {
      // Show the form content with a back button
      return Scaffold(
        backgroundColor: const Color(0xffF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xff0386FF),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              // If template was provided, pop back to previous screen
              // Otherwise, go back to form list
              if (widget.template != null) {
                Navigator.of(context).pop();
              } else {
                setState(() {
                  selectedFormId = null;
                  selectedFormData = null;
                  fieldControllers.clear();
                  fieldValues.clear();
                });
              }
            },
          ),
          title: Text(
            selectedFormData!['title'] ?? 'Form',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        body: _buildFormView(),
      );
    }
    
    // Show the form list
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xff0386FF),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.description,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.availableForms,
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.searchForms,
                        hintStyle: GoogleFonts.inter(
                          color: const Color(0xff6B7280),
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xff6B7280),
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      style: GoogleFonts.inter(fontSize: 14),
                      onChanged: (value) {
                        if (mounted) {
                          setState(() {
                            searchQuery = value.toLowerCase();
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Forms list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('form')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _buildErrorState(AppLocalizations.of(context)!
                        .formsErrorLoading(snapshot.error.toString()));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingState();
                  }

                  if (!snapshot.hasData) {
                    return _buildErrorState(AppLocalizations.of(context)!
                        .formsNoDataReceived);
                  }

                  if (_currentUserId == null || _currentUserRole == null) {
                    return _buildLoadingState();
                  }

                  final allForms = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'] ?? 'active';
                    if (status != 'active') return false;
                    if (!_canAccessForm(data)) return false;
                    
                    // Hide old readiness forms - teachers should use new template system
                    final title = (data['title'] ?? '').toString().toLowerCase();
                    final isLegacyReadinessForm = title.contains('readiness') ||
                        title.contains('class readiness') ||
                        title.contains('formulaire de préparation');
                    
                    // Only admins can see legacy readiness forms (for management)
                    if (isLegacyReadinessForm && _currentUserRole?.toLowerCase() != 'admin') {
                      return false;
                    }
                    
                    return title.contains(searchQuery);
                  }).toList();

                  // Filter to show only latest version of each form
                  // Group by title (normalized) and keep only the one with latest updatedAt or createdAt
                  final Map<String, QueryDocumentSnapshot> latestForms = {};
                  for (var doc in allForms) {
                    final data = doc.data() as Map<String, dynamic>;
                    // Normalize title: trim, lowercase, remove extra spaces
                    final title = (data['title'] ?? '').toString()
                        .trim()
                        .toLowerCase()
                        .replaceAll(RegExp(r'\s+'), ' ');
                    
                    // Get update time (prefer updatedAt, fallback to createdAt)
                    Timestamp? updateTime;
                    if (data['updatedAt'] != null) {
                      final updatedAtValue = data['updatedAt'];
                      if (updatedAtValue is Timestamp) {
                        updateTime = updatedAtValue;
                      } else if (updatedAtValue is DateTime) {
                        updateTime = Timestamp.fromDate(updatedAtValue);
                      }
                    } else if (data['createdAt'] != null) {
                      final createdAtValue = data['createdAt'];
                      if (createdAtValue is Timestamp) {
                        updateTime = createdAtValue;
                      } else if (createdAtValue is DateTime) {
                        updateTime = Timestamp.fromDate(createdAtValue);
                      }
                    }
                    
                    if (!latestForms.containsKey(title)) {
                      latestForms[title] = doc;
                    } else {
                      final existingDoc = latestForms[title]!;
                      final existingData = existingDoc.data() as Map<String, dynamic>;
                      Timestamp? existingTime;
                      if (existingData['updatedAt'] != null) {
                        final existingUpdatedAt = existingData['updatedAt'];
                        if (existingUpdatedAt is Timestamp) {
                          existingTime = existingUpdatedAt;
                        } else if (existingUpdatedAt is DateTime) {
                          existingTime = Timestamp.fromDate(existingUpdatedAt);
                        }
                      } else if (existingData['createdAt'] != null) {
                        final existingCreatedAt = existingData['createdAt'];
                        if (existingCreatedAt is Timestamp) {
                          existingTime = existingCreatedAt;
                        } else if (existingCreatedAt is DateTime) {
                          existingTime = Timestamp.fromDate(existingCreatedAt);
                        }
                      }
                      
                      // Keep the one with the latest timestamp
                      if (updateTime != null && existingTime != null) {
                        if (updateTime.compareTo(existingTime) > 0) {
                          latestForms[title] = doc;
                        }
                      } else if (updateTime != null) {
                        latestForms[title] = doc;
                      }
                    }
                  }
                  
                  final forms = latestForms.values.toList();

                  if (forms.isEmpty) {
                    return _buildEmptyState();
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('form_responses')
                        .where('userId',
                            isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                        .snapshots(),
                    builder: (context, responsesSnapshot) {
                      if (FirebaseAuth.instance.currentUser == null) {
                        return Center(
                          child: Text(AppLocalizations.of(context)!.pleaseSignInToViewForms),
                        );
                      }

                      if (responsesSnapshot.hasError) {
                        if (responsesSnapshot.error
                            .toString()
                            .contains('permission-denied')) {
                          return Center(
                            child: Text(AppLocalizations.of(context)!.pleaseSignInToAccessForms),
                          );
                        }
                        return Center(
                          child: Text(AppLocalizations.of(context)!.commonErrorWithDetails(
                            responsesSnapshot.error.toString(),
                          )),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: forms.length,
                        itemBuilder: (context, index) {
                          final form = forms[index].data() as Map<String, dynamic>;
                          final formId = forms[index].id;
                          final hasSubmitted = _userFormSubmissions[formId] ?? false;

                          return _buildFormCard(form, formId, false, hasSubmitted);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard(
      Map<String, dynamic> form, String formId, bool isSelected,
      [bool hasSubmitted = false]) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleFormSelection(formId, form),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xff0386FF).withOpacity(0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xff0386FF)
                    : const Color(0xffE5E7EB),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xff0386FF).withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xff0386FF)
                            : hasSubmitted
                                ? const Color(0xff10B981)
                                : const Color(0xffF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        hasSubmitted ? Icons.check : Icons.description,
                        size: 16,
                        color: isSelected || hasSubmitted
                            ? Colors.white
                            : const Color(0xff6B7280),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            FormLocalization.translate(
                              context,
                              form['title'] ??
                                  AppLocalizations.of(context)!
                                      .formsUntitledForm,
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? const Color(0xff0386FF)
                                  : const Color(0xff111827),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (hasSubmitted) ...[
                            const SizedBox(height: 2),
                            Text(
                              AppLocalizations.of(context)!.submitted,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xff10B981),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (hasSubmitted) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xff10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xff10B981).withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.formCompleted,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xff10B981),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (form['description'] != null &&
                    form['description'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    FormLocalization.translate(
                      context,
                      form['description'],
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xff6B7280),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 12,
                      color: Color(0xff6B7280),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getFormFieldCount(form),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xff6B7280),
                      ),
                    ),
                    const Spacer(),
                    // Show permission indicator for admin users
                    if (_currentUserRole == 'admin')
                      _buildPermissionIndicator(form),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return Container(
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xff0386FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.description_outlined,
                size: 64,
                color: Color(0xff0386FF),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.selectAFormToGetStarted,
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: const Color(0xff111827),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.chooseAFormFromTheSidebar,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: const Color(0xff6B7280),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                // Form header card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xff0386FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.description,
                              color: Color(0xff0386FF),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedFormData!['title'] ?? 'Untitled Form',
                                  style: GoogleFonts.inter(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xff111827),
                                  ),
                                ),
                                if (selectedFormData!['description'] != null &&
                                    selectedFormData!['description']
                                        .toString()
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    selectedFormData!['description'],
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      color: const Color(0xff6B7280),
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Submission status banner (if already submitted)
                if (_userFormSubmissions[selectedFormId] ?? false) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xff10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xff10B981).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xff10B981),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.formAlreadySubmitted,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xff047857),
                                ),
                              ),
                              Text(
                                AppLocalizations.of(context)!.youHaveAlreadySubmittedThisForm,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xff059669),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Form fields - each field is now a separate card (Google Forms style)
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        // Debug: Check if fields exist
                        if (_getVisibleFields().isEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xffFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xffF59E0B)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.info,
                                        color: Color(0xffF59E0B)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        AppLocalizations.of(context)!.noFormFieldsAreCurrentlyVisible,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xffB45309),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  AppLocalizations.of(context)!.possibleCausesN +
                                      '\n• This form may not have any fields configured\n'
                                      '• There may be a network connection issue\n'
                                      '• Your user permissions may have changed\n'
                                      '• The form data may be corrupted',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xffB45309),
                                  ),
                                ),
                                if (kDebugMode) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    AppLocalizations.of(context)!.debugInfoN +
                                        '\nForm ID: $selectedFormId\n'
                                        'User ID: $_currentUserId\n'
                                        'User Role: $_currentUserRole\n'
                                        'Form has data: ${selectedFormData != null}\n'
                                        'Form keys: ${selectedFormData?.keys.join(", ") ?? "null"}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xffB45309),
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ] else ...[
                          ..._getVisibleFields().map((fieldEntry) {
                            try {
                              final fieldKey = fieldEntry.key;
                              final controller = fieldControllers[fieldKey];

                              // Safety check: if controller doesn't exist, create one
                              if (controller == null) {
                                AppLogger.debug(
                                    'FormScreen: Missing controller for field $fieldKey, creating one');
                                fieldControllers[fieldKey] =
                                    TextEditingController();
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildModernFormField(
                                  FormLocalization.translate(
                                      context,
                                      fieldEntry.value['label'] ??
                                          AppLocalizations.of(context)!
                                              .formsUntitledField),
                                  fieldEntry.value['placeholder'] ??
                                      AppLocalizations.of(context)!
                                          .formsEnterValue,
                                  fieldControllers[fieldKey]!,
                                  fieldEntry.value['required'] ?? false,
                                  fieldEntry.value['type'] ?? 'text',
                                  fieldKey,
                                  options:
                                      (fieldEntry.value['type'] == 'select' ||
                                              fieldEntry.value['type'] ==
                                                  'dropdown' ||
                                              fieldEntry.value['type'] ==
                                                  'multi_select' ||
                                              fieldEntry.value['type'] ==
                                                  'radio')
                                          ? (fieldEntry.value['options']
                                                  is List)
                                              ? List<String>.from(
                                                  fieldEntry.value['options'])
                                              : (fieldEntry.value['options']
                                                      is String)
                                                  ? (fieldEntry.value['options']
                                                          as String)
                                                      .split(',')
                                                      .map((e) => e.trim())
                                                      .toList()
                                                  : []
                                          : null,
                                ),
                              );
                            } catch (e) {
                              // Fallback for any field rendering errors
                              AppLogger.error(
                                  'FormScreen: Error rendering field ${fieldEntry.key}: $e');
                              return Container(
                                padding: const EdgeInsets.all(16),
                                margin: const EdgeInsets.only(bottom: 24),
                                decoration: BoxDecoration(
                                  color: const Color(0xffFEF2F2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xffEF4444)),
                                ),
                                child: Text(
                                  'Error rendering field: ${fieldEntry.key}. Error: $e',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: const Color(0xffDC2626),
                                  ),
                                ),
                              );
                            }
                          }),
                        ],
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // Action buttons
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Use column layout on small screens, row on larger screens
                      final isSmallScreen = constraints.maxWidth < 400;
                      
                      if (isSmallScreen) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _submitForm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isSubmitting
                                    ? Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Flexible(
                                            child: Text(
                                              AppLocalizations.of(context)!.submitting,
                                              style: GoogleFonts.inter(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.send, size: 20),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              AppLocalizations.of(context)!.submitForm,
                                              style: GoogleFonts.inter(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _isSubmitting ? null : _resetForm,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xff6B7280),
                                  side: const BorderSide(color: Color(0xffE5E7EB)),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16, horizontal: 24),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.refresh, size: 20),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        AppLocalizations.of(context)!.commonReset,
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                      
                      // Row layout for larger screens
                      return Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isSubmitting
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Flexible(
                                          child: Text(
                                            AppLocalizations.of(context)!.submitting,
                                            style: GoogleFonts.inter(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.send, size: 20),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            AppLocalizations.of(context)!.submitForm,
                                            style: GoogleFonts.inter(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Flexible(
                            child: OutlinedButton(
                              onPressed: _isSubmitting ? null : _resetForm,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xff6B7280),
                                side: const BorderSide(color: Color(0xffE5E7EB)),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.refresh, size: 20),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      AppLocalizations.of(context)!.commonReset,
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
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
  }

  Widget _buildModernFormField(
    String label,
    String hintText,
    TextEditingController controller,
    bool required,
    String type,
    String fieldKey, {
    List<String>? options,
  }) {
    final bool isFocused = _focusedFieldKey == fieldKey;
    final localizedLabel = FormLocalization.translate(context, label);
    final localizedHint = FormLocalization.translate(context, hintText);
    final localizedOptions = options
        ?.map((option) => FormLocalization.translate(context, option))
        .toList();
    
    return GestureDetector(
      onTapDown: (_) => setState(() => _focusedFieldKey = fieldKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  )
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The colored focus indicator on the left (Google Forms style)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isFocused ? 6 : 0,
                  color: _primaryColor,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Question Label
                        RichText(
                          text: TextSpan(
                            text: localizedLabel,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                            children: [
                              if (required)
                                 TextSpan(
                                  text: AppLocalizations.of(context)!.text,
                                  style: TextStyle(color: Colors.red),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Render specific input based on type
                        _renderInputByType(
                          fieldKey,
                          type,
                          controller,
                          localizedHint,
                          localizedOptions,
                          required,
                          localizedLabel,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _renderInputByType(
    String fieldKey,
    String type,
    TextEditingController controller,
    String hintText,
    dynamic options,
    bool required,
    String label,
  ) {
    if (type == 'select' || type == 'dropdown') {
      return _buildDropdownField(controller, hintText, options, required, label, fieldKey);
    } else if (type == 'multi_select') {
      return _buildMultiSelectField(controller, hintText, options, required, label, fieldKey);
    } else if (type == 'multiline' || type == 'long_text' || type == 'description') {
      return _buildTextAreaField(controller, hintText, required, label, fieldKey);
    } else if (type == 'date') {
      return _buildDateField(controller, hintText, required, label, fieldKey);
    } else if (type == 'radio') {
      // Radio buttons: if options exist, render as radio buttons with options
      // Otherwise, render as boolean (Yes/No)
      if (options != null && (options is List) && (options as List).isNotEmpty) {
        return _buildRadioField(controller, options, required, label, fieldKey);
      } else {
        // No options provided, treat as boolean Yes/No
        return _buildBooleanField(controller, label, fieldKey);
      }
    } else if (type == 'boolean' || type == 'yes_no' || type == 'yesNo') {
      return _buildBooleanField(controller, label, fieldKey);
    } else if (type == 'number') {
      return _buildNumberField(controller, hintText, required, label, fieldKey);
    } else if (type == 'image_upload' || type == 'imageUpload') {
      return _buildImageField(controller, hintText, required, label, fieldKey);
    } else if (type == 'signature') {
      return _buildSignatureField(controller, hintText, required, label, fieldKey);
    } else {
      return _buildTextInputField(controller, hintText, required, label, type, fieldKey);
    }
  }

  Widget _buildTextInputField(
    TextEditingController controller,
    String hintText,
    bool required,
    String label,
    String type,
    String fieldKey,
  ) {
    return TextFormField(
      controller: controller,
      maxLines: type == 'text' ? null : 1,
      minLines: 1,
      onTap: () => setState(() => _focusedFieldKey = fieldKey),
      decoration: InputDecoration(
        hintText: hintText.isEmpty ? 'Your answer' : hintText,
        hintStyle: TextStyle(color: Colors.grey[400]),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE0E0E0))),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primaryColor, width: 2)),
        errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.red)),
        focusedErrorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2)),
      ),
      style: GoogleFonts.inter(
        fontSize: 14,
        color: const Color(0xff111827),
      ),
      keyboardType: _getKeyboardType(type),
      textInputAction: TextInputAction.done,
      validator: (value) {
        if (required && (value == null || value.isEmpty)) {
          return 'Please enter $label';
        }
        if (type == 'email' && value != null && value.isNotEmpty) {
          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)) {
            return 'Please enter a valid email address';
          }
        }
        if (type == 'phone' && value != null && value.isNotEmpty) {
          if (!RegExp(r'^\+?[\d\s-]+$').hasMatch(value)) {
            return 'Please enter a valid phone number';
          }
        }
        return null;
      },
    );
  }

  Widget _buildDropdownField(
    TextEditingController controller,
    String hintText,
    List<String>? options,
    bool required,
    String label,
    String fieldKey,
  ) {
    // Ensure initialValue exists in options list to avoid assertion errors
    final currentValue = controller.text;
    final validInitialValue = (currentValue.isNotEmpty && 
        options != null && 
        options.contains(currentValue)) 
        ? currentValue 
        : null;
    
    return DropdownButtonFormField<String>(
      value: validInitialValue,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(
          color: const Color(0xff9CA3AF),
          fontSize: 14,
        ),
        filled: true,
        fillColor: const Color(0xffF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xff0386FF), width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
        prefixIcon: const Icon(
          Icons.arrow_drop_down_circle_outlined,
          color: Color(0xff6B7280),
        ),
      ),
      style: GoogleFonts.inter(
        fontSize: 14,
        color: const Color(0xff111827),
      ),
      dropdownColor: Colors.white,
      isExpanded: true, // Allow dropdown to expand to full width
      items: options
              ?.map((option) => DropdownMenuItem(
                    value: option,
                    child: Text(
                      option,
                      style: GoogleFonts.inter(fontSize: 14),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                  ))
              .toList() ??
          [],
      onChanged: (value) {
        if (value != null) {
          setState(() {
            controller.text = value;
          });
        }
      },
      validator: required
          ? (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a $label';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildMultiSelectField(
    TextEditingController controller,
    String hintText,
    List<String>? options,
    bool required,
    String label,
    String fieldKey,
  ) {
    // Parse selected values from controller text (stored as comma-separated string)
    List<String> selectedValues = controller.text.isEmpty
        ? []
        : controller.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hidden TextFormField for validation
        SizedBox(
          height: 0,
          child: TextFormField(
            controller: controller,
            validator: required
                ? (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select at least one option for $label';
                    }
                    return null;
                  }
                : null,
            style: const TextStyle(height: 0),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xffE5E7EB)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xffF9FAFB),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.checklist,
                      color: Color(0xff6B7280),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedValues.isEmpty
                            ? hintText.isEmpty
                                ? AppLocalizations.of(context)!.formSelectMultipleOptions
                                : hintText
                            : '${selectedValues.length} option(s) selected: ${selectedValues.join(', ')}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: selectedValues.isEmpty
                              ? const Color(0xff9CA3AF)
                              : const Color(0xff111827),
                          fontWeight: selectedValues.isEmpty
                              ? FontWeight.w400
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (options != null && options.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Column(
                      children: options.map((option) {
                        final isSelected = selectedValues.contains(option);
                        return CheckboxListTile(
                          title: Text(
                            option,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xff111827),
                            ),
                          ),
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                if (!selectedValues.contains(option)) {
                                  selectedValues.add(option);
                                }
                              } else {
                                selectedValues.remove(option);
                              }
                              // Update controller with comma-separated values
                              controller.text = selectedValues.join(', ');
                              // Store as list for conditional logic evaluation
                              fieldValues[fieldKey] = selectedValues.toList();
                            });
                          },
                          activeColor: const Color(0xff0386FF),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16),
                        );
                      }).toList(),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xff6B7280),
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)!.noOptionsAvailable,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xff6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(context)!.theFormCreatorHasNotAdded,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xff9CA3AF),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (required && selectedValues.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xffEF4444),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.pleaseSelectAtLeastOneOption,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xffEF4444),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTextAreaField(
    TextEditingController controller,
    String hintText,
    bool required,
    String label,
    String fieldKey,
  ) {
    return TextFormField(
      controller: controller,
      maxLines: null,
      minLines: 3,
      onTap: () => setState(() => _focusedFieldKey = fieldKey),
      decoration: InputDecoration(
        hintText: hintText.isEmpty ? 'Your answer' : hintText,
        hintStyle: TextStyle(color: Colors.grey[400]),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE0E0E0))),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primaryColor, width: 2)),
        errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.red)),
        focusedErrorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2)),
      ),
      style: GoogleFonts.inter(
        fontSize: 14,
        color: const Color(0xff111827),
        height: 1.5, // Better line spacing for readability
      ),
      textInputAction: TextInputAction.newline,
      validator: required
          ? (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter $label';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildDateField(
    TextEditingController controller,
    String hintText,
    bool required,
    String label,
    String fieldKey,
  ) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(
          color: const Color(0xff9CA3AF),
          fontSize: 14,
        ),
        filled: true,
        fillColor: const Color(0xffF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xff0386FF), width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
        prefixIcon: const Icon(
          Icons.calendar_today,
          color: Color(0xff6B7280),
        ),
        suffixIcon: const Icon(
          Icons.arrow_drop_down,
          color: Color(0xff6B7280),
        ),
      ),
      style: GoogleFonts.inter(
        fontSize: 14,
        color: const Color(0xff111827),
      ),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xff0386FF),
                ),
              ),
              child: child!,
            );
          },
        );
        if (date != null) {
          controller.text = "${date.day}/${date.month}/${date.year}";
        }
      },
      validator: required
          ? (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a date';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildBooleanField(
      TextEditingController controller, String label, String fieldKey) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xffF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffE5E7EB)),
      ),
      child: Row(
        children: [
          Radio<String>(
            value: 'Yes',
            groupValue: controller.text,
            onChanged: (value) {
              setState(() {
                controller.text = value ?? '';
                // Store as boolean for conditional logic evaluation
                fieldValues[fieldKey] = value == 'Yes';
              });
            },
            activeColor: const Color(0xff0386FF),
          ),
          Text(
            AppLocalizations.of(context)!.commonYes,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(width: 24),
          Radio<String>(
            value: 'No',
            groupValue: controller.text,
            onChanged: (value) {
              setState(() {
                controller.text = value ?? '';
                // Store as boolean for conditional logic evaluation
                fieldValues[fieldKey] = value == 'Yes';
              });
            },
            activeColor: const Color(0xff0386FF),
          ),
          Text(
            AppLocalizations.of(context)!.commonNo,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioField(
    TextEditingController controller,
    dynamic options,
    bool required,
    String label,
    String fieldKey,
  ) {
    // Parse options from various formats
    List<String> optionList = [];
    if (options is List) {
      optionList = options.map((e) => e.toString()).toList();
    } else if (options is String) {
      optionList = options.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hidden TextFormField for validation
        SizedBox(
          height: 0,
          child: TextFormField(
            controller: controller,
            validator: required
                ? (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select an option for $label';
                    }
                    return null;
                  }
                : null,
            style: const TextStyle(height: 0),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xffF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xffE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: optionList.map((option) {
              return RadioListTile<String>(
                title: Text(
                  option,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xff111827),
                  ),
                ),
                value: option,
                groupValue: controller.text.isEmpty ? null : controller.text,
                onChanged: (value) {
                  setState(() {
                    controller.text = value ?? '';
                    fieldValues[fieldKey] = value;
                  });
                },
                activeColor: const Color(0xff0386FF),
                contentPadding: EdgeInsets.zero,
                dense: true,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberField(
    TextEditingController controller,
    String hintText,
    bool required,
    String label,
    String fieldKey,
  ) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(
          color: const Color(0xff9CA3AF),
          fontSize: 14,
        ),
        filled: true,
        fillColor: const Color(0xffF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xff0386FF), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffEF4444), width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
        prefixIcon: const Icon(
          Icons.numbers_outlined,
          color: Color(0xff6B7280),
        ),
      ),
      style: GoogleFonts.inter(
        fontSize: 14,
        color: const Color(0xff111827),
      ),
      validator: (value) {
        if (required && (value == null || value.isEmpty)) {
          return 'Please enter $label';
        }
        if (value != null && value.isNotEmpty) {
          if (double.tryParse(value) == null) {
            return 'Please enter a valid number';
          }
        }
        return null;
      },
    );
  }

  Widget _buildImageField(
    TextEditingController controller,
    String hintText,
    bool required,
    String label,
    String fieldKey,
  ) {
    final fieldKey = selectedFormData!['fields'].keys.firstWhere(
          (key) => selectedFormData!['fields'][key]['label'] == label,
          orElse: () => '',
        );

    final hasImage = fieldValues[fieldKey] != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasImage) ...[
          // Image preview
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xff0386FF), width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Image.memory(
                    Uint8List.fromList(fieldValues[fieldKey]['bytes']),
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                  // Delete button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          fieldValues.remove(fieldKey);
                          controller.text = '';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xffEF4444),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // File info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xff10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: const Color(0xff10B981).withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xff10B981),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fieldValues[fieldKey]['fileName'],
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff111827),
                        ),
                      ),
                      Text(
                        _formatFileSize(fieldValues[fieldKey]['size']),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xff6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _pickImage(fieldKey, controller),
                  child: Text(
                    AppLocalizations.of(context)!.change,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff0386FF),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // Upload button
          GestureDetector(
            onTap: () => _pickImage(fieldKey, controller),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xffF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xffE5E7EB),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xff0386FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.cloud_upload_outlined,
                      size: 32,
                      color: Color(0xff0386FF),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.clickToUploadImage,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context)!.jpgPngGifUpTo10mb,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xff6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (required && !hasImage) ...[
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.loginFieldRequired,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xffEF4444),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSignatureField(
    TextEditingController controller,
    String hintText,
    bool required,
    String label,
    String fieldKey,
  ) {
    final fieldKey = selectedFormData!['fields'].keys.firstWhere(
          (key) => selectedFormData!['fields'][key]['label'] == label,
          orElse: () => '',
        );

    final hasSignature = fieldValues[fieldKey] != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasSignature) ...[
          // Signature preview
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xff0386FF), width: 2),
              color: Colors.white,
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    Uint8List.fromList(fieldValues[fieldKey]['bytes']),
                    fit: BoxFit.contain,
                    width: double.infinity,
                  ),
                ),
                // Delete button
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        fieldValues.remove(fieldKey);
                        controller.text = '';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xffEF4444),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xff10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xff10B981).withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xff10B981),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.signatureCaptured,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff111827),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => _pickSignature(fieldKey, controller),
                child: Text(
                  AppLocalizations.of(context)!.change,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff0386FF),
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          // Signature upload button
          GestureDetector(
            onTap: () => _pickSignature(fieldKey, controller),
            child: Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xffF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xffE5E7EB),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xff9b51e0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.draw_outlined,
                      size: 24,
                      color: Color(0xff9b51e0),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.clickToAddSignature,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff111827),
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.uploadImageOrUseSignaturePad,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xff6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (required && !hasSignature) ...[
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.loginFieldRequired,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xffEF4444),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xff0386FF)),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.loadingForms,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: Color(0xffEF4444),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff6B7280),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xff6B7280).withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 48,
              color: Color(0xff6B7280),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.noActiveFormsFound,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              searchQuery.isNotEmpty
                  ? AppLocalizations.of(context)!.formsNoActiveMatching
                  : AppLocalizations.of(context)!.formsNoActiveForRole(
                      UserRoleService.getRoleDisplayName(_currentUserRole)),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xff6B7280),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (searchQuery.isNotEmpty) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  searchQuery = '';
                });
              },
              icon: const Icon(Icons.clear, size: 16),
              label: Text(
                AppLocalizations.of(context)!.clearSearch,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xff0386FF),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Icon? _getFieldIcon(String type) {
    switch (type) {
      case 'email':
        return const Icon(Icons.email_outlined, color: Color(0xff6B7280));
      case 'phone':
        return const Icon(Icons.phone_outlined, color: Color(0xff6B7280));
      case 'number':
        return const Icon(Icons.numbers_outlined, color: Color(0xff6B7280));
      default:
        return const Icon(Icons.text_fields_outlined, color: Color(0xff6B7280));
    }
  }

  String _getFormFieldCount(Map<String, dynamic> form) {
    final fields = form['fields'] as Map<String, dynamic>? ?? {};
    final count = fields.length;
    return AppLocalizations.of(context)!.formsFieldCount(count);
  }

  Future<void> _handleFormSelection(String formId, Map<String, dynamic> formData) async {
    
    // SECURITY CHECK: Orphan Prevention
    // If this is the Readiness Form but we don't have a shiftId (context),
    // we MUST force the user to select which class they are reporting for.
    final readinessFormId = await ShiftFormService.getReadinessFormId();
    
    if (formId == readinessFormId && widget.shiftId == null) {
      if (mounted) {
        final selectedShift = await _showShiftSelectionDialog();
        if (selectedShift != null) {
          // User selected a shift - inject context and proceed
          if (mounted) {
            // We need to reload the screen with the new context
            // Easier to push a new instance of FormScreen with the context
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => FormScreen(
                  timesheetId: selectedShift['timesheetId'],
                  shiftId: selectedShift['shiftId'],
                  autoSelectFormId: formId,
                ),
              ),
            );
            return;
          }
        } else {
          // User cancelled selection - do not open the form
          return;
        }
      }
    }

    // Fetch shift data if shiftId is provided (for auto-fill)
    Map<String, dynamic>? shiftData;
    if (widget.shiftId != null) {
      try {
        final shiftDoc = await FirebaseFirestore.instance
            .collection('teaching_shifts')
            .doc(widget.shiftId)
            .get();
        if (shiftDoc.exists) {
          shiftData = shiftDoc.data();
          debugPrint('✅ Shift data loaded for auto-fill: ${shiftData?.keys}');
          
          // If student_names is missing but student_ids exists, fetch student names
          if ((shiftData?['student_names'] == null || 
               (shiftData?['student_names'] as List).isEmpty) &&
              shiftData?['student_ids'] != null) {
            final studentIds = shiftData!['student_ids'] as List<dynamic>?;
            if (studentIds != null && studentIds.isNotEmpty) {
              final studentNames = <String>[];
              for (var studentId in studentIds) {
                try {
                  final studentDoc = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(studentId.toString())
                      .get();
                  if (studentDoc.exists) {
                    final studentData = studentDoc.data() as Map<String, dynamic>;
                    final firstName = studentData['first_name'] ?? studentData['firstName'] ?? '';
                    final lastName = studentData['last_name'] ?? studentData['lastName'] ?? '';
                    if (firstName.isNotEmpty || lastName.isNotEmpty) {
                      studentNames.add('$firstName $lastName'.trim());
                    }
                  }
                } catch (e) {
                }
              }
              if (studentNames.isNotEmpty) {
                shiftData!['student_names'] = studentNames;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error fetching shift data for auto-fill: $e');
      }
    }

    if (mounted) {
      setState(() {
        selectedFormId = formId;
        selectedFormData = formData;

        // Clear existing controllers and values
        for (var controller in fieldControllers.values) {
          controller.dispose();
        }
        fieldControllers.clear();
        fieldValues.clear();

        // Get autoFillRules if present
        final autoFillRules = formData['autoFillRules'] as List<dynamic>? ?? [];
        

        // Create new controllers for form fields with auto-fill support
        final fields = formData['fields'] as Map<String, dynamic>?;
        if (fields != null) {
          AppLogger.debug('FormScreen: Creating controllers for ${fields.length} fields');
          AppLogger.debug('FormScreen: Field IDs: ${fields.keys.toList()}');
          fields.forEach((fieldId, fieldData) {
            AppLogger.debug(
                'FormScreen: Creating controller for field: $fieldId (type: ${fieldId.runtimeType})');
            
            // Check if this field has an autoFillRule
            String? autoFilledValue;
            for (var rule in autoFillRules) {
              if (rule is Map<String, dynamic> && rule['fieldId'] == fieldId) {
                final sourceField = rule['sourceField'] as String?;
                final editable = rule['editable'] as bool? ?? false;
                
                
                // Apply auto-fill from shift data if available
                if (shiftData != null && sourceField != null) {
                  autoFilledValue = _getAutoFillValue(shiftData, sourceField);
                  debugPrint('✅ Auto-filled $fieldId = $autoFilledValue (editable: $editable)');
                } else {
                }
                break;
              }
            }
            
            // Initialize controller with auto-filled value if available
            fieldControllers[fieldId] = TextEditingController(text: autoFilledValue ?? '');
            
            // Store auto-filled values in fieldValues for non-text fields
            if (autoFilledValue != null) {
              fieldValues[fieldId] = autoFilledValue;
            }
          });
          AppLogger.debug(
              'FormScreen: Controllers created for keys: ${fieldControllers.keys.toList()}');
        } else {
          AppLogger.debug(
              'FormScreen: No fields found in form data for controller creation');
        }
      });
    }

    _animationController.forward();
  }

  /// Initialize controllers for form data (used when template is provided directly)
  void _initializeControllersForFormData(Map<String, dynamic> formData) {
    // Clear existing controllers
    for (var controller in fieldControllers.values) {
      controller.dispose();
    }
    fieldControllers.clear();
    fieldValues.clear();

    // Create controllers for all fields
    final fields = formData['fields'] as Map<String, dynamic>?;
    if (fields != null) {
      fields.forEach((fieldId, fieldData) {
        fieldControllers[fieldId] = TextEditingController(text: AppLocalizations.of(context)!.text2);
      });
    }
  }
  
  /// Get day of week string from DateTime (e.g., "Mon/Lundi", "Tue/Mardi")
  String _getDayOfWeekString(DateTime date) {
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

  /// Get auto-fill value from shift data based on sourceField
  String? _getAutoFillValue(Map<String, dynamic> shiftData, String sourceField) {
    
    switch (sourceField) {
      case 'shiftId':
        return widget.shiftId;
      case 'shift.subjectDisplayName':
      case 'subject':
        return shiftData['subject'] as String?;
      case 'shift.studentNames':
      case 'students':
      case 'studentName':
      case 'student':
      case 'shift.students':
        // Try multiple field names to find student names
        // Firestore uses 'student_names' (snake_case), but also check camelCase variants
        final students = shiftData['student_names'] as List<dynamic>? ??
                        shiftData['studentNames'] as List<dynamic>? ??
                        shiftData['students'] as List<dynamic>?;
        
        
        return students?.map((s) => s.toString()).join(', ');
      case 'shift.duration':
      case 'duration':
        final start = (shiftData['shift_start'] as Timestamp?)?.toDate();
        final end = (shiftData['shift_end'] as Timestamp?)?.toDate();
        if (start != null && end != null) {
          final duration = end.difference(start).inMinutes / 60;
          return duration.toStringAsFixed(2);
        }
        return null;
      case 'shift.classType':
      case 'classType':
        return shiftData['type'] as String?;
      case 'shift.clockInTime':
      case 'clockInTime':
        final clockIn = (shiftData['clock_in'] as Timestamp?)?.toDate();
        return clockIn != null ? DateFormat('h:mm a').format(clockIn) : null;
      case 'shift.clockOutTime':
      case 'clockOutTime':
        final clockOut = (shiftData['clock_out'] as Timestamp?)?.toDate();
        return clockOut != null ? DateFormat('h:mm a').format(clockOut) : null;
      case 'teacherName':
        return _currentUserData?['firstName'] != null && _currentUserData?['lastName'] != null
            ? '${_currentUserData!['firstName']} ${_currentUserData!['lastName']}'
            : null;
      case 'teacherEmail':
        return FirebaseAuth.instance.currentUser?.email;
      case 'shift.dayOfWeek':
      case 'dayOfWeek':
      case 'classDay':
      case 'class_day':
      case 'day':
        // Extract day of week from shift_start date
        final shiftStart = (shiftData['shift_start'] as Timestamp?)?.toDate();
        if (shiftStart != null) {
          return _getDayOfWeekString(shiftStart);
        }
        return null;
      default:
        // For unknown fields, try direct lookup in shift data
        final value = shiftData[sourceField];
        if (value is List) {
          // If it's a list, join it
          return value.map((v) => v.toString()).join(', ');
        }
        return value?.toString();
    }
  }

  /// Show dialog to select a shift for linkage
  Future<Map<String, dynamic>?> _showShiftSelectionDialog() async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Get all eligible shifts (completed/missed, not future) with form status
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) Navigator.pop(context);
        return null;
      }

      final now = DateTime.now();
      final allShifts = await ShiftService.getShiftsForTeacher(user.uid);
      
      
      AppLogger.debug('FormScreen: Total shifts loaded: ${allShifts.length}');
      
      // Filter: only completed or missed shifts that have ended (not future)
      // Strictly exclude any shifts that haven't started yet, haven't ended yet, or are scheduled
      final eligibleShifts = allShifts.where((shift) {
        final status = shift.status;
        final shiftStart = shift.shiftStart.toLocal();
        final shiftEnd = shift.shiftEnd.toLocal();
        
        
        // FIRST CHECK: Explicitly exclude scheduled, active, cancelled - return immediately
        if (status == ShiftStatus.scheduled) {
          AppLogger.debug('FormScreen: Excluding SCHEDULED shift ${shift.id}');
          return false;
        }
        if (status == ShiftStatus.active) {
          AppLogger.debug('FormScreen: Excluding ACTIVE shift ${shift.id}');
          return false;
        }
        if (status == ShiftStatus.cancelled) {
          AppLogger.debug('FormScreen: Excluding CANCELLED shift ${shift.id}');
          return false;
        }
        
        // SECOND CHECK: Must be in a completed/missed state
        final isCompletedOrMissed = status == ShiftStatus.completed || 
                                    status == ShiftStatus.fullyCompleted ||
                                    status == ShiftStatus.partiallyCompleted ||
                                    status == ShiftStatus.missed;
        
        if (!isCompletedOrMissed) {
          AppLogger.debug('FormScreen: Excluding shift ${shift.id} - not completed/missed, status=$status');
          return false;
        }
        
        // THIRD CHECK: Must have started AND ended (both must be in the past)
        // Shift must have started (start time is in the past)
        if (!shiftStart.isBefore(now)) {
          AppLogger.debug('FormScreen: Excluding shift ${shift.id} - has not started yet (start=$shiftStart, now=$now)');
          return false;
        }
        
        // Shift must have ended (end time is in the past, at least 1 second ago)
        final timeSinceEnd = now.difference(shiftEnd);
        if (timeSinceEnd.inSeconds <= 0) {
          AppLogger.debug('FormScreen: Excluding shift ${shift.id} - has not ended yet (end=$shiftEnd, now=$now, diff=${timeSinceEnd.inSeconds}s)');
          return false;
        }
        
        // All checks passed
        AppLogger.debug('FormScreen: Including eligible shift ${shift.id}: status=$status, ended ${timeSinceEnd.inSeconds}s ago');
        return true;
      }).toList();
      
      
      AppLogger.debug('FormScreen: Eligible shifts after filtering: ${eligibleShifts.length}');

      // Sort by date (most recent first)
      eligibleShifts.sort((a, b) => b.shiftEnd.compareTo(a.shiftEnd));

      // Build shift list with form status
      final shiftsWithStatus = <Map<String, dynamic>>[];
      for (final shift in eligibleShifts) {
        final formResponseId = await ShiftFormService.getFormResponseForShift(shift.id);
        final hasForm = formResponseId != null;
        
        // Get timesheet if exists
        final timesheetQuery = await FirebaseFirestore.instance
            .collection('timesheet_entries')
            .where('shift_id', isEqualTo: shift.id)
            .where('teacher_id', isEqualTo: user.uid)
            .limit(1)
            .get();
        
        final timesheetId = timesheetQuery.docs.isNotEmpty ? timesheetQuery.docs.first.id : null;
        
        final shiftData = {
          'shiftId': shift.id,
          'timesheetId': timesheetId,
          'shiftTitle': shift.displayName,
          'shiftStart': shift.shiftStart,
          'shiftEnd': shift.shiftEnd,
          'type': shift.status == ShiftStatus.missed ? 'missed' : 'completed',
          'hasForm': hasForm,
          'formResponseId': formResponseId,
        };
        
        
        shiftsWithStatus.add(shiftData);
      }
      
      
      if (!mounted) return null;
      Navigator.pop(context); // Close loading

      if (shiftsWithStatus.isEmpty) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.noClassesAvailable),
            content: Text(
              AppLocalizations.of(context)!.youHaveNoCompletedOrMissed,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.commonOk),
              ),
            ],
          ),
        );
        return null;
      }

      return await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.selectClass),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.pleaseSelectWhichClassThisReport,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: shiftsWithStatus.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final shift = shiftsWithStatus[index];
                      final title = shift['shiftTitle'] ?? 'Unknown Class';
                      final type = shift['type'] == 'missed' ? 'Missed Clock-in' : 'Completed';
                      final date = shift['shiftStart'] as DateTime;
                      final dateStr = DateFormat('MMM d, h:mm a').format(date);
                      final hasForm = shift['hasForm'] as bool;
                      final formResponseId = shift['formResponseId'] as String?;

                      return ListTile(
                        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(AppLocalizations.of(context)!.datestrType),
                        trailing: hasForm
                            ? IconButton(
                                icon: const Icon(Icons.visibility, color: Color(0xff10B981)),
                                tooltip: AppLocalizations.of(context)!.viewForm,
                                onPressed: () async {
                                  // Load form details and show modal
                                  try {
                                    final formDoc = await FirebaseFirestore.instance
                                        .collection('form_responses')
                                        .doc(formResponseId!)
                                        .get();
                                    
                                    if (formDoc.exists && mounted) {
                                      final data = formDoc.data() ?? {};
                                      final responses = data['responses'] as Map<String, dynamic>? ?? {};
                                      
                                      Navigator.pop(context, null); // Close shift selection
                                      
                                      FormDetailsModal.show(
                                        context,
                                        formId: formResponseId!,
                                        shiftId: shift['shiftId'] as String,
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
                            : const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: hasForm
                            ? null // Disable tap if form exists (use eye icon)
                            : () => Navigator.pop(context, shift),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(AppLocalizations.of(context)!.commonCancel),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading if error
      AppLogger.error('Error fetching shifts: $e');
      return null;
    }
  }

  // Get fields that should be visible based on conditional logic
  List<MapEntry<String, dynamic>> _getVisibleFields() {
    if (selectedFormData == null) {
      AppLogger.debug('FormScreen: No form data selected');
      return [];
    }

    AppLogger.debug('FormScreen: Selected form data keys: ${selectedFormData!.keys}');

    final fields = selectedFormData!['fields'];
    if (fields == null) {
      AppLogger.debug('FormScreen: No fields found in form data');
      AppLogger.debug('FormScreen: Form data structure: $selectedFormData');
      return [];
    }

    if (fields is! Map<String, dynamic>) {
      AppLogger.debug(
          'FormScreen: Fields is not a Map<String, dynamic>, type: ${fields.runtimeType}');
      AppLogger.debug('FormScreen: Fields content: $fields');
      return [];
    }

    final fieldsMap = fields;
    final visibleFields = <MapEntry<String, dynamic>>[];

    AppLogger.debug('FormScreen: Found ${fieldsMap.length} total fields');
    AppLogger.debug('FormScreen: Field keys: ${fieldsMap.keys.toList()}');

    // Sort fields by order first
    final sortedEntries = fieldsMap.entries.toList()
      ..sort((a, b) {
        final aOrder = (a.value as Map<String, dynamic>)['order'] as int? ?? 0;
        final bOrder = (b.value as Map<String, dynamic>)['order'] as int? ?? 0;
        AppLogger.debug(
            'FormScreen: Field ${a.key} has order $aOrder, Field ${b.key} has order $bOrder');
        return aOrder.compareTo(bOrder);
      });

    AppLogger.debug('FormScreen: Final field order after sorting:');
    for (var i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      final order = (entry.value as Map<String, dynamic>)['order'] as int? ?? 0;
      final label =
          (entry.value as Map<String, dynamic>)['label'] ?? 'No label';
      AppLogger.debug('  ${i + 1}. ${entry.key}: "$label" (order: $order)');
    }

    for (var fieldEntry in sortedEntries) {
      try {
        if (_shouldShowField(fieldEntry.key, fieldEntry.value)) {
          visibleFields.add(fieldEntry);
          AppLogger.debug('FormScreen: Field ${fieldEntry.key} is visible');
        } else {
          AppLogger.debug(
              'FormScreen: Field ${fieldEntry.key} is hidden by conditional logic');
        }
      } catch (e) {
        AppLogger.error('FormScreen: Error processing field ${fieldEntry.key}: $e');
      }
    }

    AppLogger.debug('FormScreen: ${visibleFields.length} fields are visible');
    return visibleFields;
  }

  // Check if a field should be visible based on its conditional logic
  bool _shouldShowField(String fieldId, Map<String, dynamic> fieldData) {
    final conditionalLogic = fieldData['conditionalLogic'];

    // If no conditional logic, always show
    if (conditionalLogic == null) {
      // AppLogger.debug('FormScreen: Field $fieldId has no conditional logic, showing');
      return true;
    }

    final dependsOnFieldId = conditionalLogic['dependsOnFieldId'];
    final condition = conditionalLogic['condition'];
    final expectedValue = conditionalLogic['expectedValue'];
    final expectedValues = conditionalLogic['expectedValues'];
    final isVisible = conditionalLogic['isVisible'] ?? true;

    // If no dependency set up yet, show the field
    if (dependsOnFieldId == null || condition == null) return true;

    // Get the current value of the dependent field
    final dependentValue = _getCurrentFieldValue(dependsOnFieldId);

    // Check the condition
    bool conditionMet = false;
    switch (condition) {
      case 'equals':
        conditionMet = dependentValue == expectedValue;
        break;
      case 'not_equals':
        conditionMet = dependentValue != expectedValue;
        break;
      case 'contains':
        if (expectedValues != null && expectedValues.isNotEmpty) {
          // Check if dependent value contains ANY of the expected values
          if (dependentValue is List) {
            conditionMet = expectedValues
                .any((expectedVal) => dependentValue.contains(expectedVal));
          }
        } else {
          // Fallback to single value check for backwards compatibility
          if (dependentValue is List) {
            conditionMet = dependentValue.contains(expectedValue);
          } else if (dependentValue is String) {
            conditionMet =
                dependentValue.contains(expectedValue?.toString() ?? '');
          }
        }
        break;
      case 'contains_all':
        if (expectedValues != null && expectedValues.isNotEmpty) {
          // Check if dependent value contains ALL of the expected values
          if (dependentValue is List) {
            conditionMet = expectedValues
                .every((expectedVal) => dependentValue.contains(expectedVal));
          }
        }
        break;
      case 'contains_exactly':
        if (expectedValues != null && expectedValues.isNotEmpty) {
          // Check if dependent value contains EXACTLY the expected values (same set)
          if (dependentValue is List) {
            final dependentSet = Set.from(dependentValue);
            final expectedSet = Set.from(expectedValues);
            conditionMet = dependentSet.length == expectedSet.length &&
                dependentSet.containsAll(expectedSet);
          }
        }
        break;
      case 'is_empty':
        conditionMet = dependentValue == null ||
            dependentValue == '' ||
            (dependentValue is List && dependentValue.isEmpty);
        break;
      case 'is_not_empty':
        conditionMet = dependentValue != null &&
            dependentValue != '' &&
            !(dependentValue is List && dependentValue.isEmpty);
        break;
      default:
        conditionMet = false;
    }

    // Return whether field should be visible based on condition and isVisible setting
    return isVisible ? conditionMet : !conditionMet;
  }

  // Get the current value of a field (from controller or fieldValues)
  dynamic _getCurrentFieldValue(String fieldId) {
    // Check if it's stored in fieldValues (for multi-select, boolean, etc.)
    if (fieldValues.containsKey(fieldId)) {
      return fieldValues[fieldId];
    }

    // Check text controller
    if (fieldControllers.containsKey(fieldId)) {
      final text = fieldControllers[fieldId]!.text.trim();
      return text.isEmpty ? null : text;
    }

    return null;
  }

  Future<String?> _uploadImageToStorage(
      Uint8List imageBytes, String fileName) async {
    const maxRetries = 3;

    // Test basic Firebase Storage connectivity
    try {
      AppLogger.debug('=== Testing Firebase Storage Connectivity ===');
      final storage = FirebaseStorage.instance;
      AppLogger.debug('Storage bucket: ${storage.bucket}');

      // Test with a tiny file first
      final testData = Uint8List.fromList([1, 2, 3, 4, 5]); // 5 bytes
      final testRef = storage
          .ref()
          .child('test_${DateTime.now().millisecondsSinceEpoch}.txt');

      AppLogger.debug('Attempting small test upload...');
      final uploadTask = testRef.putData(testData);

      // Monitor the upload task state
      uploadTask.snapshotEvents.listen((snapshot) {
        AppLogger.debug('Test upload state: ${snapshot.state}');
        AppLogger.debug(
            'Test upload progress: ${snapshot.bytesTransferred}/${snapshot.totalBytes}');
      });

      final testUpload = await uploadTask.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.debug('Test upload task final state: ${uploadTask.snapshot.state}');
          AppLogger.debug(
              'Test upload bytes transferred: ${uploadTask.snapshot.bytesTransferred}');
          throw Exception('Test upload timeout');
        },
      );

      AppLogger.info('Test upload successful! Cleaning up...');
      await testRef.delete().catchError((e) => AppLogger.error('Cleanup error: $e'));
      AppLogger.debug('=== Storage connectivity test PASSED ===');
    } catch (e) {
      AppLogger.error('=== Storage connectivity test FAILED ===');
      AppLogger.error('Error: $e');
      AppLogger.error('Error type: ${e.runtimeType}');
      if (e.toString().contains('XMLHttpRequest')) {
        AppLogger.debug(
            'CORS/Network issue detected - this is common in web development');
      } else if (e.toString().contains('permission')) {
        AppLogger.debug('Permission issue detected');
      } else if (e.toString().contains('network')) {
        AppLogger.debug('Network connectivity issue detected');
      }
      AppLogger.debug('This indicates a fundamental connectivity issue');
      AppLogger.debug('Possible solutions:');
      AppLogger.debug('1. Check Firebase Storage is enabled in Firebase Console');
      AppLogger.debug('2. Check network/firewall settings');
      AppLogger.debug('3. Try from a different network');
      AppLogger.debug('4. Check CORS configuration');
      return null;
    }

    // Verify authentication status
    final currentUser = FirebaseAuth.instance.currentUser;
    AppLogger.debug('=== Authentication Status ===');
    AppLogger.debug('User logged in: ${currentUser != null}');
    AppLogger.debug('User ID: ${currentUser?.uid}');
    AppLogger.debug('User email: ${currentUser?.email}');
    AppLogger.debug(
        'Auth token: ${currentUser?.refreshToken != null ? "Available" : "Missing"}');
    AppLogger.debug('=============================');

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        AppLogger.debug(
            'Starting image upload for: $fileName (attempt $attempt/$maxRetries)');

        final User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          AppLogger.error('Error: User not logged in');
          throw Exception('User not logged in');
        }

        AppLogger.debug('User ID: ${currentUser.uid}');
        AppLogger.debug(
            'Original image size: ${imageBytes.length} bytes (${(imageBytes.length / (1024 * 1024)).toStringAsFixed(2)}MB)');

        // Compress image if it's larger than 500KB
        Uint8List finalImageBytes = imageBytes;
        if (imageBytes.length > 500 * 1024) {
          AppLogger.debug('Compressing image...');
          finalImageBytes = await _compressImage(imageBytes, fileName);
          AppLogger.debug(
              'Compressed image size: ${finalImageBytes.length} bytes (${(finalImageBytes.length / (1024 * 1024)).toStringAsFixed(2)}MB)');
        }

        // Create a unique filename with timestamp
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('form_images')
            .child(currentUser.uid)
            .child('${timestamp}_$fileName');

        AppLogger.debug('Storage path: ${storageRef.fullPath}');

        // Set metadata to improve upload reliability
        final metadata = SettableMetadata(
          contentType: _getContentType(fileName),
          customMetadata: {
            'uploadedBy': currentUser.uid,
            'originalFileName': fileName,
            'attempt': attempt.toString(),
          },
        );

        // Upload the file with reduced timeout and metadata
        final uploadTask = storageRef.putData(finalImageBytes, metadata);

        // Dynamic timeout based on final file size (minimum 60 seconds, +30 seconds per MB)
        final timeoutSeconds =
            60 + (finalImageBytes.length / (1024 * 1024) * 30).ceil();
        AppLogger.debug(
            'Setting timeout to $timeoutSeconds seconds for ${(finalImageBytes.length / (1024 * 1024)).toStringAsFixed(1)}MB file');

        final snapshot = await uploadTask.timeout(
          Duration(seconds: timeoutSeconds),
          onTimeout: () {
            AppLogger.debug(
                'Upload timeout after $timeoutSeconds seconds (attempt $attempt)');
            throw Exception('Upload timeout on attempt $attempt');
          },
        );

        AppLogger.debug('Upload completed, getting download URL...');

        // Get the download URL
        final downloadURL = await snapshot.ref.getDownloadURL();
        AppLogger.debug('Download URL obtained: $downloadURL');

        return downloadURL;
      } catch (e) {
        AppLogger.error('Error uploading image (attempt $attempt): $e');

        if (attempt == maxRetries) {
          AppLogger.error('All upload attempts failed');
          return null;
        }

        // Wait before retrying
        await Future.delayed(Duration(seconds: attempt * 2));
        AppLogger.debug('Retrying upload...');
      }
    }

    return null;
  }

  String _getContentType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Future<Uint8List> _compressImage(
      Uint8List imageBytes, String fileName) async {
    try {
      // For web, we'll use a simple quality reduction approach
      // This is a basic implementation - in production you might want to use image package

      // If the image is very large, we'll reduce quality significantly
      if (imageBytes.length > 2 * 1024 * 1024) {
        // > 2MB
        AppLogger.debug(
            'Image is very large (${(imageBytes.length / (1024 * 1024)).toStringAsFixed(2)}MB), applying maximum compression');
        // For very large images, we'll return a significantly reduced version
        // This is a simplified approach - you might want to integrate image compression library
        return _reduceImageSize(imageBytes, 0.3); // 30% quality
      } else if (imageBytes.length > 1024 * 1024) {
        // > 1MB
        AppLogger.debug(
            'Image is large (${(imageBytes.length / (1024 * 1024)).toStringAsFixed(2)}MB), applying medium compression');
        return _reduceImageSize(imageBytes, 0.6); // 60% quality
      } else {
        AppLogger.debug('Image size is acceptable, applying light compression');
        return _reduceImageSize(imageBytes, 0.8); // 80% quality
      }
    } catch (e) {
      AppLogger.error('Error compressing image: $e');
      AppLogger.debug('Returning original image');
      return imageBytes;
    }
  }

  Uint8List _reduceImageSize(Uint8List imageBytes, double quality) {
    // This is a simplified size reduction
    // In a real implementation, you would use image processing libraries
    // For now, we'll just return the original bytes with a warning
    AppLogger.debug(
        'Note: Image compression not fully implemented. Consider using image processing library.');
    AppLogger.debug('Returning original image bytes for now.');
    return imageBytes;
  }

  Future<void> _pickImage(
      String fieldKey, TextEditingController controller) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null && file.size <= 10 * 1024 * 1024) {
          // 10MB limit
          setState(() {
            fieldValues[fieldKey] = {
              'fileName': file.name,
              'bytes': file.bytes!,
              'size': file.size,
              'isUploaded': false, // Track upload status
            };
            controller.text = file.name;
          });
        } else {
          _showSnackBar('File size must be less than 10MB', isError: true);
        }
      }
    } catch (e) {
      _showSnackBar('Error picking image: $e', isError: true);
    }
  }

  Future<void> _pickSignature(
      String fieldKey, TextEditingController controller) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null && file.size <= 5 * 1024 * 1024) {
          // 5MB limit for signatures
          setState(() {
            fieldValues[fieldKey] = {
              'fileName': file.name,
              'bytes': file.bytes!,
              'size': file.size,
              'isUploaded': false, // Track upload status
            };
            controller.text = file.name;
          });
        } else {
          _showSnackBar('Signature file size must be less than 5MB',
              isError: true);
        }
      }
    } catch (e) {
      _showSnackBar('Error picking signature: $e', isError: true);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  TextInputType _getKeyboardType(String type) {
    switch (type) {
      case 'email':
        return TextInputType.emailAddress;
      case 'phone':
        return TextInputType.phone;
      case 'number':
        return TextInputType.number;
      case 'multiline':
        return TextInputType.multiline;
      default:
        return TextInputType.text;
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    for (var controller in fieldControllers.values) {
      controller.clear();
    }
    setState(() {
      fieldValues.clear();
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      AppLogger.error('Form validation failed');
      return;
    }

    // Check if user has already submitted this form
    final hasAlreadySubmitted = _userFormSubmissions[selectedFormId] ?? false;
    if (hasAlreadySubmitted) {
      final shouldResubmit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            AppLocalizations.of(context)!.formAlreadySubmitted,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: const Color(0xff111827),
            ),
          ),
          content: Text(
            AppLocalizations.of(context)!.youHaveAlreadySubmittedThisForm2,
            style: GoogleFonts.inter(
              color: const Color(0xff6B7280),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                AppLocalizations.of(context)!.commonCancel,
                style: GoogleFonts.inter(
                  color: const Color(0xff6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                foregroundColor: Colors.white,
              ),
              child: Text(
                AppLocalizations.of(context)!.submitAgain,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );

      if (shouldResubmit != true) {
        AppLogger.debug('User cancelled resubmission');
        return;
      }
    }

    AppLogger.debug('Starting form submission...');
    if (mounted) {
      setState(() => _isSubmitting = true);
    }

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        _showSnackBar('You must be logged in to submit forms', isError: true);
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
        return;
      }

      final responses = <String, dynamic>{};

      AppLogger.debug('Processing form fields...');
      AppLogger.debug('Field controllers: ${fieldControllers.keys.toList()}');
      AppLogger.debug('Field values: ${fieldValues.keys.toList()}');

      // Process each field and upload images to Firebase Storage
      for (var entry in fieldControllers.entries) {
        final fieldId = entry.key;
        final controller = entry.value;

        AppLogger.debug('Processing field: $fieldId');

        if (fieldValues.containsKey(fieldId)) {
          final fieldValue = fieldValues[fieldId];

          // Handle non-map values (like booleans from conditional logic)
          if (fieldValue is! Map<String, dynamic>) {
            responses[fieldId] = fieldValue;
            continue;
          }

          final fieldData = fieldValue;
          AppLogger.debug('Field $fieldId has data: ${fieldData.keys.toList()}');

          // Check if this is an image/signature field with bytes
          if (fieldData.containsKey('bytes') && fieldData['bytes'] != null) {
            AppLogger.debug('Uploading image for field: $fieldId');
            _showSnackBar(
                'Uploading ${fieldData['fileName']} (${(fieldData['size'] / (1024 * 1024)).toStringAsFixed(1)}MB)...',
                isError: false);

            // Upload image to Firebase Storage
            final downloadURL = await _uploadImageToStorage(
              Uint8List.fromList(fieldData['bytes']),
              fieldData['fileName'],
            );

            if (downloadURL != null) {
              AppLogger.info('Image uploaded successfully for field: $fieldId');
              responses[fieldId] = {
                'fileName': fieldData['fileName'],
                'downloadURL': downloadURL,
                'size': fieldData['size'],
                'type': 'image',
                'uploadedAt': FieldValue.serverTimestamp(),
              };
            } else {
              AppLogger.error('Failed to upload image for field: $fieldId');

              // Show dialog asking user what to do
              if (mounted) {
                final shouldContinue = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      AppLocalizations.of(context)!.imageUploadFailed,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff111827),
                      ),
                    ),
                    content: Text(
                      'Failed to upload "${fieldData['fileName']}". Would you like to submit the form without this image or try again?',
                      style: GoogleFonts.inter(
                        color: const Color(0xff6B7280),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(
                          AppLocalizations.of(context)!.errorTryAgain,
                          style: GoogleFonts.inter(
                            color: const Color(0xff6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff0386FF),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.submitWithoutImage,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );

                if (shouldContinue == true) {
                  // Submit without the image
                  AppLogger.debug(
                      'User chose to submit without image for field: $fieldId');
                  responses[fieldId] = {
                    'fileName': fieldData['fileName'],
                    'uploadFailed': true,
                    'size': fieldData['size'],
                    'type': 'image',
                    'failureReason': 'Upload timeout/retry limit exceeded',
                  };
                } else {
                  // User wants to try again, cancel submission
                  if (mounted) {
                    setState(() => _isSubmitting = false);
                  }
                  return;
                }
              } else {
                if (mounted) {
                  setState(() => _isSubmitting = false);
                }
                return;
              }
            }
          } else {
            // For other field values
            AppLogger.debug('Field $fieldId: storing non-image data');
            responses[fieldId] = fieldData;
          }
        } else {
          // For text fields, store the text value
          // Check if this is a multi-select field and convert to array
          final fieldData = selectedFormData!['fields'] as Map<String, dynamic>;
          final fieldInfo = fieldData[fieldId];

          if (fieldInfo != null &&
              fieldInfo['type'] == 'multi_select' &&
              controller.text.isNotEmpty) {
            // Convert comma-separated values to array for multi-select fields
            final selectedValues = controller.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
            AppLogger.debug(
                'Field $fieldId: storing multi-select values: $selectedValues');
            responses[fieldId] = selectedValues;
          } else {
            AppLogger.debug('Field $fieldId: storing text value: ${controller.text}');
            responses[fieldId] = controller.text;
          }
        }
      }

      AppLogger.debug('All fields processed, submitting to Firestore...');
      AppLogger.debug('Form data to submit:');
      AppLogger.debug('- FormId: $selectedFormId');
      AppLogger.debug('- UserId: ${currentUser.uid}');
      AppLogger.debug('- UserEmail: ${currentUser.email}');
      AppLogger.debug('- Responses: ${responses.keys.toList()}');
      AppLogger.debug('- Response data: $responses');

      // Get user data for names
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final userFirstName = userData.data()?['first_name'] as String? ?? '';
      final userLastName = userData.data()?['last_name'] as String? ?? '';

      // Generate yearMonth for monthly grouping/audits based on SHIFT date, not submission date
      String yearMonth;
      if (widget.timesheetId != null) {
        // Get yearMonth from timesheet (which has shift info)
        final timesheetDoc = await FirebaseFirestore.instance
            .collection('timesheet_entries')
            .doc(widget.timesheetId)
            .get();
        if (timesheetDoc.exists) {
          final tsData = timesheetDoc.data()!;
          final shiftId = tsData['shift_id'] as String?;
          if (shiftId != null) {
            final shiftDoc = await FirebaseFirestore.instance
                .collection('teaching_shifts')
                .doc(shiftId)
                .get();
            if (shiftDoc.exists) {
              final shiftData = shiftDoc.data()!;
              final shiftStart = (shiftData['shift_start'] as Timestamp).toDate();
              yearMonth = '${shiftStart.year}-${shiftStart.month.toString().padLeft(2, '0')}';
            } else {
              // Fallback to current month if shift not found
              final now = DateTime.now();
              yearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
            }
          } else {
            // Fallback to current month if shift_id not found
            final now = DateTime.now();
            yearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
          }
        } else {
          // Fallback to current month if timesheet not found
          final now = DateTime.now();
          yearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
        }
      } else if (widget.shiftId != null) {
        // Get yearMonth directly from shift
        final shiftDoc = await FirebaseFirestore.instance
            .collection('teaching_shifts')
            .doc(widget.shiftId)
            .get();
        if (shiftDoc.exists) {
          final shiftData = shiftDoc.data()!;
          final shiftStart = (shiftData['shift_start'] as Timestamp).toDate();
          yearMonth = '${shiftStart.year}-${shiftStart.month.toString().padLeft(2, '0')}';
        } else {
          // Fallback to current month if shift not found
          final now = DateTime.now();
          yearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
        }
      } else {
        // Fallback to current month if no shift/timesheet info
        final now = DateTime.now();
        yearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      }
      
      // Determine if this is a template-based form
      final isTemplate = selectedFormData?['isTemplate'] == true;
      final templateId = selectedFormData?['templateId'] as String?;
      
      // Get form name/title for better identification
      final formName = selectedFormData?['title'] as String? ?? 
                      selectedFormData?['name'] as String? ?? 
                      'Untitled Form';
      
      // Get form type for audit system (daily, weekly, monthly, onDemand)
      final frequency = selectedFormData?['frequency'] as String?;
      String formType = 'legacy'; // Default for old forms
      if (frequency != null) {
        switch (frequency) {
          case 'perSession':
            formType = 'daily';
            break;
          case 'weekly':
            formType = 'weekly';
            break;
          case 'monthly':
            formType = 'monthly';
            break;
          case 'onDemand':
            formType = 'onDemand';
            break;
        }
      }
      
      final Map<String, dynamic> submissionData = {
        'formId': selectedFormId,
        'formName': formName, // Store form name for easier identification
        'formType': formType, // Store form type for audit system
        if (isTemplate && templateId != null) 'templateId': templateId, // Store template ID for new system
        if (frequency != null) 'frequency': frequency, // Store frequency for filtering
        'userId': currentUser.uid,
        'userEmail': currentUser.email,
        'userFirstName': userFirstName,
        'userLastName': userLastName,
        'responses': responses,
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'completed',
        'lastUpdated': FieldValue.serverTimestamp(),
        'yearMonth': yearMonth, // For monthly grouping and audits
      };

      // Add linkage IDs if present
      if (widget.timesheetId != null) submissionData['timesheetId'] = widget.timesheetId;
      if (widget.shiftId != null) submissionData['shiftId'] = widget.shiftId;

      final docRef = await FirebaseFirestore.instance
          .collection('form_responses')
          .add(submissionData)
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          AppLogger.debug('Firestore submission timeout after 30 seconds');
          throw Exception('Firestore submission timeout');
        },
      );

      // CRITICAL: Update Timesheet Entry or Shift (Linkage)
      // This ensures that when viewing a shift's details, the form will appear there
      if (widget.timesheetId != null) {
        // Link to timesheet entry (normal case - teacher clocked in)
        await ShiftFormService.linkFormToTimesheet(
          timesheetId: widget.timesheetId!,
          formResponseId: docRef.id,
          reportedHours: null, // Can be extracted from form responses if needed
        );
      } else if (widget.shiftId != null) {
        // Link directly to shift (missed shift case - no timesheet entry)
        await ShiftFormService.linkFormToShift(
          shiftId: widget.shiftId!,
          formResponseId: docRef.id,
          reportedHours: null, // Can be extracted from form responses if needed
        );
      }

      AppLogger.info(
          'Form submitted to Firestore successfully! Document ID: ${docRef.id}');
      _showSnackBar('Form submitted successfully!', isError: false);

      // Update the submissions tracker
      if (mounted) {
        setState(() {
          _userFormSubmissions[selectedFormId!] = true;
        });
      }

      AppLogger.debug('Clearing form...');
      // Clear form
      _resetForm();
      AppLogger.info('Form cleared successfully!');
    } catch (e) {
      AppLogger.error('Error in form submission: $e');
      AppLogger.debug('Stack trace: ${StackTrace.current}');
      _showSnackBar('Error submitting form: ${e.toString()}', isError: true);
    } finally {
      AppLogger.debug('Resetting submission state...');
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
      AppLogger.debug('Submission state reset complete');
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    // Check if widget is still mounted before showing snackbar
    if (!mounted) {
      AppLogger.debug('Widget not mounted, skipping snackbar: $message');
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor:
              isError ? const Color(0xffEF4444) : const Color(0xff10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      AppLogger.error('Error showing snackbar: $e');
      AppLogger.debug('Message was: $message');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (var controller in fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
