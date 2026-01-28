import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../core/models/form_template.dart';
import '../core/services/form_template_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

// --- MODELS ---
enum QuestionType {
  shortAnswer,
  paragraph,
  multipleChoice,
  checkboxes,
  dropdown,
  linearScale,
  date,
  time,
  fileUpload,
  number,
}

extension QuestionTypeExtension on QuestionType {
  String get displayName {
    switch (this) {
      case QuestionType.shortAnswer: return 'Short answer';
      case QuestionType.paragraph: return 'Paragraph';
      case QuestionType.multipleChoice: return 'Multiple choice';
      case QuestionType.checkboxes: return 'Checkboxes';
      case QuestionType.dropdown: return 'Dropdown';
      case QuestionType.linearScale: return 'Linear scale';
      case QuestionType.date: return 'Date';
      case QuestionType.time: return 'Time';
      case QuestionType.fileUpload: return 'File upload';
      case QuestionType.number: return 'Number';
    }
  }
  
  IconData get icon {
    switch (this) {
      case QuestionType.shortAnswer: return Icons.short_text;
      case QuestionType.paragraph: return Icons.notes;
      case QuestionType.multipleChoice: return Icons.radio_button_checked;
      case QuestionType.checkboxes: return Icons.check_box;
      case QuestionType.dropdown: return Icons.arrow_drop_down_circle;
      case QuestionType.linearScale: return Icons.linear_scale;
      case QuestionType.date: return Icons.calendar_today;
      case QuestionType.time: return Icons.access_time;
      case QuestionType.fileUpload: return Icons.cloud_upload;
      case QuestionType.number: return Icons.pin;
    }
  }

  String get firestoreType {
    switch (this) {
      case QuestionType.shortAnswer: return 'text';
      case QuestionType.paragraph: return 'long_text';
      case QuestionType.multipleChoice: return 'radio';
      case QuestionType.checkboxes: return 'multi_select';
      case QuestionType.dropdown: return 'dropdown';
      case QuestionType.linearScale: return 'scale';
      case QuestionType.date: return 'date';
      case QuestionType.time: return 'time';
      case QuestionType.fileUpload: return 'file_upload';
      case QuestionType.number: return 'number';
    }
  }
  
  static QuestionType fromFirestore(String type) {
    switch (type) {
      case 'text': return QuestionType.shortAnswer;
      case 'long_text': return QuestionType.paragraph;
      case 'radio': return QuestionType.multipleChoice;
      case 'multi_select': return QuestionType.checkboxes;
      case 'dropdown': return QuestionType.dropdown;
      case 'scale': return QuestionType.linearScale;
      case 'date': return QuestionType.date;
      case 'time': return QuestionType.time;
      case 'file_upload': return QuestionType.fileUpload;
      case 'number': return QuestionType.number;
      default: return QuestionType.shortAnswer;
    }
  }
}

class FormQuestion {
  String id;
  QuestionType type;
  String title;
  bool required;
  List<String> options;
  int scaleMin;
  int scaleMax;
  String scaleLabelMin;
  String scaleLabelMax;
  int order;

  FormQuestion({
    required this.id,
    required this.type,
    required this.title,
    required this.required,
    this.options = const ['Option 1'],
    this.scaleMin = 1,
    this.scaleMax = 5,
    this.scaleLabelMin = '',
    this.scaleLabelMax = '',
    this.order = 0,
  }) {
    if (options.isEmpty) {
      this.options = ['Option 1'];
    } else {
      this.options = List.from(options);
    }
  }

  Map<String, dynamic> toFirestore(int index) {
    final data = <String, dynamic>{
      'type': type.firestoreType,
      'label': title,
      'required': required,
      'order': index,
    };
    
    if (type == QuestionType.multipleChoice || 
        type == QuestionType.checkboxes || 
        type == QuestionType.dropdown) {
      data['options'] = options;
    }
    
    if (type == QuestionType.linearScale) {
      data['validation'] = {
        'min': scaleMin,
        'max': scaleMax,
      };
      data['scaleLabels'] = {
        'min': scaleLabelMin,
        'max': scaleLabelMax,
      };
    }
    
    return data;
  }

  factory FormQuestion.fromFirestore(String id, Map<String, dynamic> data) {
    final type = QuestionTypeExtension.fromFirestore(data['type'] as String? ?? 'text');
    
    return FormQuestion(
      id: id,
      type: type,
      title: data['label'] as String? ?? '',
      required: data['required'] as bool? ?? false,
      options: (data['options'] as List<dynamic>?)?.cast<String>() ?? ['Option 1'],
      scaleMin: (data['validation']?['min'] as int?) ?? 1,
      scaleMax: (data['validation']?['max'] as int?) ?? 5,
      scaleLabelMin: (data['scaleLabels']?['min'] as String?) ?? '',
      scaleLabelMax: (data['scaleLabels']?['max'] as String?) ?? '',
      order: data['order'] as int? ?? 0,
    );
  }
}

// --- WIDGET PRINCIPAL ---

class FormBuilder extends StatefulWidget {
  final String? editFormId;
  final Map<String, dynamic>? editFormData;

  const FormBuilder({super.key, this.editFormId, this.editFormData});

  @override
  State<FormBuilder> createState() => _FormBuilderState();
}

class _FormBuilderState extends State<FormBuilder> {
  // Data
  late final TextEditingController _titleController;
  final TextEditingController _descriptionController = TextEditingController();
  List<FormQuestion> _questions = [];
  String _selectedThemeColor = '#673AB7';
  
  // New Fields for Template System
  FormFrequency _frequency = FormFrequency.onDemand;
  FormCategory _category = FormCategory.other;
  final Map<String, bool> _allowedRoles = {
    'teacher': true,
    'admin': false,
    'coach': false,
    'student': false,
    'parent': false,
  };

  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  
  // UX State
  int? _focusedQuestionIndex; // Null signifie qu'aucune question n'est en mode édition

  final List<String> _themeColors = [
    '#673AB7', '#1A73E8', '#0F9D58', '#F4B400', 
    '#DB4437', '#FF6D00', '#00ACC1', '#AB47BC'
  ];

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    if (widget.editFormId != null && widget.editFormData != null) {
      _loadExistingForm();
    }
    _titleController.addListener(_markUnsaved);
    _descriptionController.addListener(_markUnsaved);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      if (_titleController.text.isEmpty && widget.editFormId == null) {
        _titleController.text = AppLocalizations.of(context)!.untitledForm;
      }
      if (_questions.isEmpty && widget.editFormId == null) {
        _questions = [
          FormQuestion(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: QuestionType.shortAnswer,
            title: AppLocalizations.of(context)!.text2,
            required: false,
          ),
        ];
      }
    }
  }

  void _loadExistingForm() {
    final data = widget.editFormData!;
    _titleController.text = data['title'] ?? data['name'] ?? 'Untitled Form'; // Support both keys
    _descriptionController.text = data['description'] ?? '';
    _selectedThemeColor = data['themeColor'] ?? '#673AB7';
    
    // Load new fields if available
    if (data['frequency'] != null) {
      try {
        _frequency = FormFrequency.values.firstWhere(
          (e) => e.name == data['frequency'],
          orElse: () => FormFrequency.onDemand,
        );
      } catch (_) {}
    }
    
    if (data['category'] != null) {
      try {
        _category = FormCategory.values.firstWhere(
          (e) => e.name == data['category'],
          orElse: () => FormCategory.other,
        );
      } catch (_) {}
    }
    
    if (data['allowedRoles'] != null) {
      final roles = List<String>.from(data['allowedRoles']);
      for (var role in _allowedRoles.keys) {
        _allowedRoles[role] = roles.contains(role);
      }
    }
    
    // Handle fields loading (support both map and list formats)
    if (data['fields'] is List) {
      // New format (List of FormFieldDefinition)
      final fieldsList = data['fields'] as List;
      _questions = fieldsList.map((f) {
        final fieldData = f is Map ? f : (f as FormFieldDefinition).toMap();
        // Convert FormFieldDefinition to FormQuestion
        // This is a rough mapping
        return FormQuestion(
          id: fieldData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          type: QuestionTypeExtension.fromFirestore(fieldData['type'] ?? 'text'),
          title: fieldData['label'] ?? '',
          required: fieldData['required'] ?? false,
          options: (fieldData['options'] as List?)?.cast<String>() ?? ['Option 1'],
          scaleMin: fieldData['validation']?['min'] ?? 1,
          scaleMax: fieldData['validation']?['max'] ?? 5,
          order: fieldData['order'] ?? 0,
        );
      }).toList();
    } else {
      // Old format (Map<String, dynamic>)
      final fields = data['fields'] as Map<String, dynamic>? ?? {};
      _questions = fields.entries.map((e) => 
        FormQuestion.fromFirestore(e.key, e.value as Map<String, dynamic>)
      ).toList();
    }
    
    _questions.sort((a, b) => a.order.compareTo(b.order));
    
    if (_questions.isEmpty) {
      _questions.add(FormQuestion(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: QuestionType.shortAnswer,
        title: AppLocalizations.of(context)!.text2,
        required: false,
      ));
    }
  }

  void _markUnsaved() {
    if (!_hasUnsavedChanges) setState(() => _hasUnsavedChanges = true);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Color(int.parse(_selectedThemeColor.replaceFirst('#', '0xFF')));

    return Scaffold(
      backgroundColor: const Color(0xFFF0EBF8), // Google Forms Background
      body: GestureDetector(
        // Cliquer dans le vide désélectionne la question active
        onTap: () {
          if (_focusedQuestionIndex != null) {
            setState(() => _focusedQuestionIndex = null);
            FocusScope.of(context).unfocus();
          }
        },
                    child: Column(
                      children: [
            _buildTopBar(themeColor),
                Expanded(
                  child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 100),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 770), // Largeur standard Google Forms
      child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                        Expanded(
                          child: Column(
                children: [
                              const SizedBox(height: 12),
                              _buildFormHeaderCard(themeColor),
                              const SizedBox(height: 12),
                              _buildQuestionsList(themeColor),
                            ],
                          ),
                        ),
                        // Barre latérale flottante (Sidebar)
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 12),
                          child: _buildRightSidebar(themeColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(Color themeColor) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
            children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.grey),
            onPressed: () => _handleBack(),
          ),
          const SizedBox(width: 8),
          Icon(Icons.description, color: themeColor, size: 32),
          const SizedBox(width: 16),
          Expanded(
                child: Text(
              _titleController.text.isEmpty ? 'Untitled Form' : _titleController.text,
              style: GoogleFonts.roboto(fontSize: 18, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          // Indicateur de sauvegarde
          if (_hasUnsavedChanges)
            Padding(
              padding: const EdgeInsets.only(right: 16),
                child: Text(
                AppLocalizations.of(context)!.unsavedChanges,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          // Theme Picker
          CircleAvatar(
            backgroundColor: themeColor,
            radius: 14,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.palette_outlined, color: Colors.white, size: 16),
              itemBuilder: (context) => _themeColors.map((c) {
                final color = Color(int.parse(c.replaceFirst('#', '0xFF')));
                return PopupMenuItem(
                  value: c,
                  child: Row(
        children: [
              Container(
                        width: 20,
                        height: 20,
                decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: c == _selectedThemeColor
                              ? Border.all(color: Colors.black, width: 2)
                              : null,
                        ),
                      ),
                      if (c == _selectedThemeColor) ...[
                        const SizedBox(width: 8),
                        Text(AppLocalizations.of(context)!.selected),
                      ],
        ],
      ),
    );
              }).toList(),
              onSelected: (v) => setState(() {
                _selectedThemeColor = v;
                _hasUnsavedChanges = true;
              }),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _isSaving ? null : _saveForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: _isSaving 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(AppLocalizations.of(context)!.commonSave),
          ),
        ],
      ),
    );
  }

  Widget _buildFormHeaderCard(Color themeColor) {
    return GestureDetector(
      // Empêcher la désélection quand on clique sur le header
      onTap: () {}, 
      child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
          ),
        ],
      ),
        child: Column(
          children: [
              Container(
              height: 10,
                decoration: BoxDecoration(
                color: themeColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
            ),
          Padding(
              padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                  TextField(
                    controller: _titleController,
                    style: GoogleFonts.roboto(fontSize: 32, fontWeight: FontWeight.w400),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: AppLocalizations.of(context)!.untitledForm2,
                      isDense: true,
                    ),
                    onTap: () => setState(() => _focusedQuestionIndex = null),
          ),
          const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    style: GoogleFonts.roboto(fontSize: 14),
                    maxLines: null,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: AppLocalizations.of(context)!.formDescription2,
                      isDense: true,
                    ),
                    onTap: () => setState(() => _focusedQuestionIndex = null),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  // SETTINGS SECTION
                  Text(AppLocalizations.of(context)!.formSettings, style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                  const SizedBox(height: 16),
                  
                  // Frequency & Category Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppLocalizations.of(context)!.frequency, style: GoogleFonts.roboto(fontSize: 12, color: Colors.grey[600])),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<FormFrequency>(
                                  value: _frequency,
                                  isExpanded: true,
                                  items: FormFrequency.values.map((f) => DropdownMenuItem(
                                    value: f,
                                    child: Text(f.name.substring(0, 1).toUpperCase() + f.name.substring(1)),
                                  )).toList(),
                                  onChanged: (v) {
                                    if (v != null) setState(() {
                                      _frequency = v;
                                      _hasUnsavedChanges = true;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppLocalizations.of(context)!.category, style: GoogleFonts.roboto(fontSize: 12, color: Colors.grey[600])),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<FormCategory>(
                                  value: _category,
                                  isExpanded: true,
                                  items: FormCategory.values.map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c.name.substring(0, 1).toUpperCase() + c.name.substring(1)),
                                  )).toList(),
                                  onChanged: (v) {
                                    if (v != null) setState(() {
                                      _category = v;
                                      _hasUnsavedChanges = true;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context)!.targetAudienceAllowedRoles, style: GoogleFonts.roboto(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: _allowedRoles.entries.map((entry) {
                      return FilterChip(
                        label: Text(entry.key.substring(0, 1).toUpperCase() + entry.key.substring(1)),
                        selected: entry.value,
                        selectedColor: themeColor.withOpacity(0.2),
                        checkmarkColor: themeColor,
                        labelStyle: TextStyle(
                          color: entry.value ? themeColor : Colors.black87,
                          fontWeight: entry.value ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (selected) => setState(() {
                          _allowedRoles[entry.key] = selected;
                          _hasUnsavedChanges = true;
                        }),
                      );
                    }).toList(),
                  ),
                ],
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildQuestionsList(Color themeColor) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false, // On utilise nos propres poignées
      proxyDecorator: (child, index, animation) {
        // Style de l'élément pendant le drag (ombre portée pour effet de levage)
        return Material(
          elevation: 10,
          color: Colors.transparent,
          shadowColor: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          child: child,
        );
      },
      itemCount: _questions.length,
      onReorder: (oldIndex, newIndex) {
          setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = _questions.removeAt(oldIndex);
          _questions.insert(newIndex, item);
          _hasUnsavedChanges = true;
          // Mise à jour de l'index focus si nécessaire
          if (_focusedQuestionIndex == oldIndex) {
            _focusedQuestionIndex = newIndex;
          } else if (_focusedQuestionIndex != null && 
                     _focusedQuestionIndex! > oldIndex && 
                     _focusedQuestionIndex! <= newIndex) {
            _focusedQuestionIndex = _focusedQuestionIndex! - 1;
          } else if (_focusedQuestionIndex != null && 
                     _focusedQuestionIndex! < oldIndex && 
                     _focusedQuestionIndex! >= newIndex) {
            _focusedQuestionIndex = _focusedQuestionIndex! + 1;
          }
        });
        HapticFeedback.lightImpact();
      },
      itemBuilder: (context, index) {
        final isActive = _focusedQuestionIndex == index;
        return _QuestionCard(
          key: ValueKey(_questions[index].id),
          question: _questions[index],
          index: index,
          themeColor: themeColor,
          isActive: isActive,
          onTap: () {
            setState(() => _focusedQuestionIndex = index);
            HapticFeedback.lightImpact();
          },
          onChanged: () => setState(() => _hasUnsavedChanges = true),
          onDelete: () => _deleteQuestion(index),
          onDuplicate: () => _duplicateQuestion(index),
        );
      },
    );
  }

  Widget _buildRightSidebar(Color themeColor) {
    // Styles flottants
    return Container(
      width: 50,
              decoration: BoxDecoration(
                color: Colors.white,
        borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
          _SidebarItem(
            icon: Icons.add_circle_outline,
            tooltip: AppLocalizations.of(context)!.addQuestion,
            onTap: () => _addQuestion(),
            color: Colors.grey[700]!,
          ),
          const Divider(height: 1, indent: 10, endIndent: 10),
          _SidebarItem(
            icon: Icons.text_fields,
            tooltip: AppLocalizations.of(context)!.addTitle,
            onTap: () {},
            color: Colors.grey[700]!,
          ),
          _SidebarItem(
            icon: Icons.image_outlined,
            tooltip: AppLocalizations.of(context)!.addImage,
            onTap: () {},
            color: Colors.grey[700]!,
          ),
          _SidebarItem(
            icon: Icons.smart_display_outlined,
            tooltip: AppLocalizations.of(context)!.addVideo,
            onTap: () {},
            color: Colors.grey[700]!,
          ),
          const Divider(height: 1, indent: 10, endIndent: 10),
          _SidebarItem(
            icon: Icons.view_stream_outlined,
            tooltip: AppLocalizations.of(context)!.addSection,
            onTap: () {},
            color: Colors.grey[700]!,
          ),
        ],
      ),
    );
  }

  // --- ACTIONS ---

  void _addQuestion() {
              setState(() {
      final newQ = FormQuestion(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: QuestionType.shortAnswer,
        title: AppLocalizations.of(context)!.text2,
        required: false,
      );
      if (_focusedQuestionIndex != null) {
        _questions.insert(_focusedQuestionIndex! + 1, newQ);
        _focusedQuestionIndex = _focusedQuestionIndex! + 1;
                } else {
        _questions.add(newQ);
        _focusedQuestionIndex = _questions.length - 1;
      }
      _hasUnsavedChanges = true;
    });
    HapticFeedback.lightImpact();
  }

  void _duplicateQuestion(int index) {
            setState(() {
      final original = _questions[index];
      final copy = FormQuestion(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: original.type,
        title: '${original.title} (copy)',
        required: original.required,
        options: List.from(original.options),
        scaleMin: original.scaleMin,
        scaleMax: original.scaleMax,
        scaleLabelMin: original.scaleLabelMin,
        scaleLabelMax: original.scaleLabelMax,
      );
      _questions.insert(index + 1, copy);
      _focusedQuestionIndex = index + 1;
      _hasUnsavedChanges = true;
    });
    HapticFeedback.lightImpact();
  }

  void _deleteQuestion(int index) {
    if (_questions.length <= 1) return;
    setState(() {
      _questions.removeAt(index);
      if (_focusedQuestionIndex != null && _focusedQuestionIndex! >= _questions.length) {
        _focusedQuestionIndex = _questions.length - 1;
      }
      _hasUnsavedChanges = true;
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _saveForm() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseEnterAFormTitle)),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      // 1. Build List<FormFieldDefinition> for the new system
      final fieldsList = <FormFieldDefinition>[];
      for (var i = 0; i < _questions.length; i++) {
        final q = _questions[i];
        
        // Map UI type to Firestore type string
        String typeString = q.type.firestoreType;
        
        // Build validation map
        Map<String, dynamic>? validation;
        if (q.type == QuestionType.linearScale || q.type == QuestionType.number) {
          validation = {'min': q.scaleMin, 'max': q.scaleMax};
        }
        
        fieldsList.add(FormFieldDefinition(
          id: q.id,
          label: q.title,
          type: typeString,
          required: q.required,
          order: i + 1, // 1-based order
          options: (q.type == QuestionType.multipleChoice || 
                   q.type == QuestionType.checkboxes || 
                   q.type == QuestionType.dropdown) ? q.options : null,
          validation: validation,
          placeholder: q.title, // Use label as placeholder for now
        ));
      }

      // 2. Collect allowed roles
      final activeRoles = _allowedRoles.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();
          
      if (activeRoles.isEmpty) {
        // Default to teacher if none selected
        activeRoles.add('teacher');
      }

      // 3. Create FormTemplate object
      final template = FormTemplate(
        id: widget.editFormId ?? '', // Empty ID means new form creation (or handled by versioning)
        name: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        frequency: _frequency,
        category: _category,
        version: 1, // Will be overwritten by versioning logic
        allowedRoles: activeRoles,
        fields: fieldsList,
        autoFillRules: [], // No autofill builder in UI yet
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        themeColor: _selectedThemeColor, // Custom field, added to FormTemplate or extra map
      );

      // 4. Save using FormTemplateService with Versioning
      // This disables all old versions with the same name and creates a new active version
      await FormTemplateService.saveTemplateWithVersioning(template);

      setState(() {
        _isSaving = false;
        _hasUnsavedChanges = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.formSavedSuccessfullyPreviousVersionsDeactivated),
            backgroundColor: Colors.green,
          ),
        );
        
        // Go back to forms list
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorSavingFormE),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleBack() async {
    if (_hasUnsavedChanges) {
      final shouldLeave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.unsavedChanges),
          content: Text(AppLocalizations.of(context)!.youHaveUnsavedChangesAreYou),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context)!.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppLocalizations.of(context)!.leave),
            ),
          ],
        ),
      );
      
      if (shouldLeave != true) return;
    }
    
    if (mounted) Navigator.of(context).pop();
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  const _SidebarItem({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 50,
          height: 50,
          alignment: Alignment.center,
          child: Icon(icon, size: 24, color: color),
        ),
      ),
    );
  }
}

// --- COMPOSANT CARTE DE QUESTION (Le cœur de la logique UI) ---

class _QuestionCard extends StatefulWidget {
  final FormQuestion question;
  final int index;
  final Color themeColor;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;

  const _QuestionCard({
    required Key key,
    required this.question,
    required this.index,
    required this.themeColor,
    required this.isActive,
    required this.onTap,
    required this.onChanged,
    required this.onDelete,
    required this.onDuplicate,
  }) : super(key: key);

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  late TextEditingController _titleController;
  
  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.question.title);
  }

  @override
  void didUpdateWidget(_QuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.question.title != _titleController.text) {
      _titleController.text = widget.question.title;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Utilisation d'AnimatedContainer pour la bordure bleue latérale
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
        borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
            color: Colors.black.withOpacity(widget.isActive ? 0.2 : 0.05),
            blurRadius: widget.isActive ? 5 : 2,
            offset: const Offset(0, 1),
            ),
          ],
        ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
              // La barre latérale colorée (Active Indicator)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: widget.isActive ? 6 : 0,
                color: widget.themeColor,
              ),
              
              // Contenu principal
              Expanded(
                child: GestureDetector(
                  onTap: widget.onTap, // Active le mode édition
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: Padding(
      padding: const EdgeInsets.all(24),
                      child: widget.isActive 
                        ? _buildEditMode() 
                        : _buildViewMode(),
                    ),
                  ),
                  ),
                ),
              ],
            ),
          ),
      ),
    );
  }

  // --- MODE VUE (Semblable au formulaire final) ---
  Widget _buildViewMode() {
    return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.question.title.isEmpty ? 'Question' : widget.question.title,
                style: GoogleFonts.roboto(
                  fontSize: 16, 
                  color: Colors.black87,
                  fontWeight: FontWeight.w400,
          ),
        ),
      ),
            if (widget.question.required)
              Text(AppLocalizations.of(context)!.text, style: TextStyle(color: Colors.red, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 16),
        // Aperçu statique du champ
        IgnorePointer(
          child: _buildInputPreview(),
        ),
      ],
    );
  }

  // --- MODE ÉDITION (Tous les contrôles) ---
  Widget _buildEditMode() {
    return Column(
      children: [
        // Handle de drag & drop centré
        ReorderableDragStartListener(
          index: widget.index,
          child: Center(
            child: Container(
              width: 40,
              height: 20,
      decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    shape: BoxShape.circle,
                  ),
                )),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        
        // Ligne Titre + Type Selector
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(12),
                color: const Color(0xFFF8F9FA), // Fond gris clair input Google
                child: TextField(
                  controller: _titleController,
                  style: GoogleFonts.roboto(fontSize: 16),
                  decoration: InputDecoration.collapsed(
                    hintText: AppLocalizations.of(context)!.formQuestion,
                  ),
                  onChanged: (v) {
                    widget.question.title = v;
                    widget.onChanged();
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<QuestionType>(
                    value: widget.question.type,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down),
                    items: QuestionType.values.map((type) => DropdownMenuItem(
                      value: type,
                      child: Row(
                children: [
                          Icon(type.icon, size: 20, color: Colors.grey[700]),
                          const SizedBox(width: 12),
                  Text(
                            type.displayName,
                            style: GoogleFonts.roboto(fontSize: 13),
                          ),
                        ],
                      ),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) {
                          setState(() {
                          widget.question.type = val;
                          widget.onChanged();
                        });
                      }
                    },
                  ),
                          ),
                        ),
                      ),
                    ],
                  ),

        const SizedBox(height: 16),

        // Zone de contenu dynamique selon le type
        _buildEditorContent(),

        const SizedBox(height: 24),
        const Divider(height: 1),
        const SizedBox(height: 8),

        // Toolbar du bas
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
                    children: [
            IconButton(
              icon: const Icon(Icons.content_copy),
              tooltip: AppLocalizations.of(context)!.duplicate,
              onPressed: widget.onDuplicate,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: AppLocalizations.of(context)!.commonDelete,
              onPressed: widget.onDelete,
            ),
            Container(
              height: 24,
              width: 1,
              color: Colors.grey.shade300,
              margin: const EdgeInsets.symmetric(horizontal: 8),
            ),
            Text(AppLocalizations.of(context)!.commonRequired, style: TextStyle(fontSize: 13)),
            Switch(
              value: widget.question.required,
              activeColor: widget.themeColor,
              onChanged: (v) => setState(() {
                widget.question.required = v;
                widget.onChanged();
              }),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.more_vert, color: Colors.grey),
                    ],
                  ),
                ],
    );
  }

  // --- CONTENU SPECIFIQUE (OPTIONS, ETC) ---
  Widget _buildEditorContent() {
    switch (widget.question.type) {
      case QuestionType.multipleChoice:
      case QuestionType.checkboxes:
      case QuestionType.dropdown:
        return _buildOptionsList();
      case QuestionType.linearScale:
        return _buildLinearScaleEditor();
      case QuestionType.shortAnswer:
      case QuestionType.paragraph:
      case QuestionType.date:
      case QuestionType.time:
      case QuestionType.number:
      case QuestionType.fileUpload:
        return Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: _buildInputPreview(isEditing: true),
        );
    }
  }

  Widget _buildOptionsList() {
    final isRadio = widget.question.type == QuestionType.multipleChoice;
    final isCheckbox = widget.question.type == QuestionType.checkboxes;

    return Column(
      children: [
        ...widget.question.options.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = TextEditingController(text: entry.value);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                if (isRadio)
                  const Icon(Icons.radio_button_unchecked, color: Colors.grey, size: 20)
                else if (isCheckbox)
                  const Icon(Icons.check_box_outline_blank, color: Colors.grey, size: 20)
                else
                  Text('${index + 1}.', style: const TextStyle(color: Colors.grey)),
                
                const SizedBox(width: 12),
                
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      border: UnderlineInputBorder(),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.transparent),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                    ),
                    onChanged: (v) {
                      widget.question.options[index] = v;
                      widget.onChanged();
                    },
                  ),
                ),
                if (widget.question.options.length > 1)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() {
                      widget.question.options.removeAt(index);
                      widget.onChanged();
                    }),
                  ),
              ],
            ),
          );
        }),
        // Bouton Ajouter une option
        InkWell(
          onTap: () => setState(() {
            widget.question.options.add('Option ${widget.question.options.length + 1}');
            widget.onChanged();
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                if (isRadio)
                  const Icon(Icons.radio_button_unchecked, color: Colors.transparent, size: 20)
                else if (isCheckbox)
                  const Icon(Icons.check_box_outline_blank, color: Colors.transparent, size: 20)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 12),
                    Text(
                  AppLocalizations.of(context)!.addOption,
                  style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildLinearScaleEditor() {
    return Column(
      children: [
        Row(
          children: [
            // Min value
            SizedBox(
              width: 60,
              child: DropdownButton<int>(
                value: widget.question.scaleMin,
                isExpanded: true,
                items: [0, 1].map((v) => DropdownMenuItem(
                  value: v,
                  child: Text(AppLocalizations.of(context)!.v),
                )).toList(),
                onChanged: (v) {
                  if (v != null) {
                setState(() {
                      widget.question.scaleMin = v;
                      widget.onChanged();
                    });
                  }
                },
              ),
            ),
            SizedBox(width: 16),
            Text(AppLocalizations.of(context)!.to),
            const SizedBox(width: 16),
            // Max value
            SizedBox(
              width: 60,
              child: DropdownButton<int>(
                value: widget.question.scaleMax,
                isExpanded: true,
                items: List.generate(9, (i) => i + 2)
                    .map((v) => DropdownMenuItem(
                      value: v,
                      child: Text(AppLocalizations.of(context)!.v),
                    ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                  setState(() {
                      widget.question.scaleMax = v;
                      widget.onChanged();
                    });
                  }
            },
          ),
        ),
      ],
        ),
        const SizedBox(height: 12),
        // Labels
        Row(
        children: [
            Expanded(
              child: TextField(
                controller: TextEditingController(text: widget.question.scaleLabelMin),
                onChanged: (v) {
                  widget.question.scaleLabelMin = v;
                  widget.onChanged();
                },
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.labelOptional,
                  hintStyle: GoogleFonts.roboto(fontSize: 12, color: Colors.grey),
                  border: const UnderlineInputBorder(),
                  prefix: Text(
                    '${widget.question.scaleMin} ',
                    style: GoogleFonts.roboto(color: Colors.grey),
              ),
            ),
          ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: TextField(
                controller: TextEditingController(text: widget.question.scaleLabelMax),
                onChanged: (v) {
                  widget.question.scaleLabelMax = v;
                  widget.onChanged();
                },
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.labelOptional,
                  hintStyle: GoogleFonts.roboto(fontSize: 12, color: Colors.grey),
                  border: const UnderlineInputBorder(),
                  prefix: Text(
                    '${widget.question.scaleMax} ',
                    style: GoogleFonts.roboto(color: Colors.grey),
                  ),
              ),
            ),
          ),
        ],
      ),
      ],
    );
  }

  // --- VISUELS DES INPUTS (Preview et Edit) ---
  Widget _buildInputPreview({bool isEditing = false}) {
    switch (widget.question.type) {
      case QuestionType.shortAnswer:
        return TextField(
          enabled: false,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.shortAnswerText,
            hintStyle: TextStyle(color: Colors.grey[500]),
            border: isEditing
                ? const UnderlineInputBorder(
                    borderSide: BorderSide(style: BorderStyle.solid),
                  )
                : const UnderlineInputBorder(
                    borderSide: BorderSide(style: BorderStyle.none),
                  ),
          ),
        );
      case QuestionType.paragraph:
        return TextField(
          enabled: false,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.longAnswerText,
            hintStyle: TextStyle(color: Colors.grey[500]),
            border: isEditing
                ? const UnderlineInputBorder()
                : const UnderlineInputBorder(borderSide: BorderSide.none),
          ),
        );
      case QuestionType.multipleChoice:
    return Column(
          children: widget.question.options.map((o) => RadioListTile<String>(
            title: Text(o, style: const TextStyle(color: Colors.black87)),
            value: o,
            groupValue: null,
            onChanged: null,
            dense: true,
            contentPadding: EdgeInsets.zero,
          )).toList(),
        );
      case QuestionType.checkboxes:
        return Column(
          children: widget.question.options.map((o) => CheckboxListTile(
            title: Text(o),
            value: false,
            onChanged: null,
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          )).toList(),
        );
      case QuestionType.dropdown:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.of(context)!.select),
              Icon(Icons.arrow_drop_down),
            ],
          ),
        );
      case QuestionType.linearScale:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            widget.question.scaleMax - widget.question.scaleMin + 1,
            (i) => CircleAvatar(
              radius: 12,
              backgroundColor: Colors.grey.shade100,
              child: Text(
                '${widget.question.scaleMin + i}',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
          ),
        );
      case QuestionType.date:
        return Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.grey.shade400),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.datePicker, style: GoogleFonts.roboto(color: Colors.grey.shade400)),
          ],
        );
      case QuestionType.time:
        return Row(
          children: [
            Icon(Icons.access_time, color: Colors.grey.shade400),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.timePicker, style: GoogleFonts.roboto(color: Colors.grey.shade400)),
          ],
        );
      case QuestionType.fileUpload:
    return Container(
          padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
                      children: [
              Icon(Icons.cloud_upload_outlined, color: Colors.grey.shade400),
                        const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.fileUpload, style: GoogleFonts.roboto(color: Colors.grey.shade400)),
            ],
          ),
        );
      case QuestionType.number:
        return TextField(
          enabled: false,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.number,
            hintStyle: TextStyle(color: Colors.grey[500]),
            border: isEditing
                ? const UnderlineInputBorder()
                : const UnderlineInputBorder(borderSide: BorderSide.none),
      ),
    );
  }
  }
}
