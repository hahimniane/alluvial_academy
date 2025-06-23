import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

class FormBuilder extends StatefulWidget {
  const FormBuilder({super.key});

  @override
  State<FormBuilder> createState() => _FormBuilderState();
}

class _FormBuilderState extends State<FormBuilder>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<FormFieldData> fields = [];
  bool _isSaving = false;
  bool _showPreview = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Map to store preview field values
  Map<String, dynamic> _previewValues = {};

  // Field type templates with icons and descriptions
  final List<FieldTemplate> fieldTemplates = [
    FieldTemplate(
      type: 'openEnded',
      title: 'Text Input',
      description: 'Single line text field',
      icon: Icons.text_fields,
      color: const Color(0xff3B82F6),
    ),
    FieldTemplate(
      type: 'description',
      title: 'Long Text',
      description: 'Multi-line text area',
      icon: Icons.notes,
      color: const Color(0xff10B981),
    ),
    FieldTemplate(
      type: 'dropdown',
      title: 'Dropdown',
      description: 'Select from options',
      icon: Icons.arrow_drop_down_circle,
      color: const Color(0xff8B5CF6),
    ),
    FieldTemplate(
      type: 'yesNo',
      title: 'Yes/No',
      description: 'Boolean choice',
      icon: Icons.toggle_on,
      color: const Color(0xffF59E0B),
    ),
    FieldTemplate(
      type: 'number',
      title: 'Number',
      description: 'Numeric input',
      icon: Icons.pin,
      color: const Color(0xffEF4444),
    ),
    FieldTemplate(
      type: 'date',
      title: 'Date',
      description: 'Date picker',
      icon: Icons.calendar_today,
      color: const Color(0xff06B6D4),
    ),
    FieldTemplate(
      type: 'imageUpload',
      title: 'Image Upload',
      description: 'Upload photos',
      icon: Icons.image,
      color: const Color(0xffEC4899),
    ),
    FieldTemplate(
      type: 'signature',
      title: 'Signature',
      description: 'Digital signature',
      icon: Icons.draw,
      color: const Color(0xff84CC16),
    ),
  ];

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
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Row(
                children: [
                  // Left Panel - Field Palette & Form Settings
                  Container(
                    width: 350,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        right: BorderSide(color: Color(0xffE2E8F0), width: 1),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildFormSettings(),
                        const Divider(height: 1, color: Color(0xffE2E8F0)),
                        _buildFieldPalette(),
                      ],
                    ),
                  ),
                  // Right Panel - Form Builder & Preview
                  Expanded(
                    child: _showPreview ? _buildPreview() : _buildFormBuilder(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xffE2E8F0), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xff3B82F6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.dynamic_form,
              color: Color(0xff3B82F6),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Form Builder',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff111827),
                ),
              ),
              Text(
                'Create dynamic forms with drag & drop',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xff6B7280),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _showPreview = !_showPreview;
                  });
                },
                icon: Icon(
                  _showPreview ? Icons.edit : Icons.preview,
                  size: 18,
                ),
                label: Text(_showPreview ? 'Edit' : 'Preview'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xff6B7280),
                  side: const BorderSide(color: Color(0xffE2E8F0)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveForm,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save, size: 18),
                label: Text(_isSaving ? 'Saving...' : 'Save Form'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff3B82F6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormSettings() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Form Settings',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 20),
          _buildStyledTextField(
            controller: _titleController,
            label: 'Form Title',
            hint: 'Enter form title',
            icon: Icons.title,
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Title is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildStyledTextField(
            controller: _descriptionController,
            label: 'Description',
            hint: 'Describe your form',
            icon: Icons.description,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xff374151),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          onChanged: onChanged,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xff111827),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: const Color(0xff9CA3AF),
              fontSize: 14,
            ),
            prefixIcon: Icon(
              icon,
              color: const Color(0xff6B7280),
              size: 20,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xff3B82F6), width: 2),
            ),
            filled: true,
            fillColor: const Color(0xffF9FAFB),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldPalette() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Field Types',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xff111827),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: fieldTemplates.length,
                itemBuilder: (context, index) {
                  final template = fieldTemplates[index];
                  return _buildFieldTemplateCard(template);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldTemplateCard(FieldTemplate template) {
    return GestureDetector(
      onTap: () => _addFieldFromTemplate(template),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xffE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: template.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  template.icon,
                  color: template.color,
                  size: 20,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  template.title,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff111827),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  template.description,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: const Color(0xff6B7280),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormBuilder() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Form Fields',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff111827),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xff3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${fields.length} fields',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xff3B82F6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (fields.isEmpty) _buildEmptyState(),
          if (fields.isNotEmpty)
            Expanded(
              child: ReorderableListView.builder(
                itemCount: fields.length,
                onReorder: _reorderFields,
                itemBuilder: (context, index) {
                  final field = fields[index];
                  return _buildFieldEditor(field, index);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xffF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xffE2E8F0)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.dynamic_form,
                    size: 64,
                    color: const Color(0xff9CA3AF),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No fields yet',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff374151),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add fields from the palette to start building your form',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xff6B7280),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldEditor(FormFieldData field, int index) {
    final template = fieldTemplates.firstWhere(
      (t) => t.type == field.type,
      orElse: () => fieldTemplates.first,
    );

    return Container(
      key: ValueKey(field.id),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: template.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            template.icon,
            color: template.color,
            size: 20,
          ),
        ),
        title: Text(
          field.label.isEmpty ? 'Untitled Field' : field.label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xff111827),
          ),
        ),
        subtitle: Text(
          template.title,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xff6B7280),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (field.required)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xffFEF3C7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Required',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xffD97706),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.drag_handle,
              color: const Color(0xff9CA3AF),
              size: 20,
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildFieldConfiguration(field),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldConfiguration(FormFieldData field) {
    // Create persistent controllers for each field
    final labelController = TextEditingController(text: field.label);
    final placeholderController =
        TextEditingController(text: field.placeholder);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStyledTextField(
                controller: labelController,
                label: 'Field Label',
                hint: 'Enter field label',
                icon: Icons.label,
                onChanged: (value) {
                  field.label = value;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStyledTextField(
                controller: placeholderController,
                label: 'Placeholder',
                hint: 'Enter placeholder text',
                icon: Icons.text_format,
                onChanged: (value) {
                  field.placeholder = value;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (field.type == 'dropdown') _buildDropdownOptions(field),
        if (field.type == 'numbersSlider') _buildSliderOptions(field),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                title: Text(
                  'Required Field',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                value: field.required,
                onChanged: (value) {
                  setState(() {
                    field.required = value ?? false;
                  });
                },
                activeColor: const Color(0xff3B82F6),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
            IconButton(
              onPressed: () => _removeField(field),
              icon: const Icon(Icons.delete_outline),
              color: const Color(0xffEF4444),
              tooltip: 'Delete field',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdownOptions(FormFieldData field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dropdown Options',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xff374151),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: field.options.join(', '),
          decoration: InputDecoration(
            hintText: 'Option 1, Option 2, Option 3',
            hintStyle: GoogleFonts.inter(
              color: const Color(0xff9CA3AF),
              fontSize: 14,
            ),
            prefixIcon: const Icon(
              Icons.list,
              color: Color(0xff6B7280),
              size: 20,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xff3B82F6), width: 2),
            ),
            filled: true,
            fillColor: const Color(0xffF9FAFB),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: (value) {
            field.options = value
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
          },
        ),
      ],
    );
  }

  Widget _buildSliderOptions(FormFieldData field) {
    return Row(
      children: [
        Expanded(
          child: _buildStyledTextField(
            controller:
                TextEditingController(text: field.minValue?.toString() ?? '0'),
            label: 'Min Value',
            hint: '0',
            icon: Icons.remove,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStyledTextField(
            controller: TextEditingController(
                text: field.maxValue?.toString() ?? '100'),
            label: 'Max Value',
            hint: '100',
            icon: Icons.add,
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Form Preview',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xffE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_titleController.text.isNotEmpty) ...[
                      Text(
                        _titleController.text,
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xff111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_descriptionController.text.isNotEmpty) ...[
                      Text(
                        _descriptionController.text,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: const Color(0xff6B7280),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                    ...fields.map((field) => _buildPreviewField(field)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewField(FormFieldData field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                field.label.isEmpty ? 'Untitled Field' : field.label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xff374151),
                ),
              ),
              if (field.required) ...[
                const SizedBox(width: 4),
                const Text(
                  '*',
                  style: TextStyle(color: Color(0xffEF4444)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          _buildPreviewFieldWidget(field),
        ],
      ),
    );
  }

  Widget _buildPreviewFieldWidget(FormFieldData field) {
    switch (field.type) {
      case 'dropdown':
        return DropdownButtonFormField<String>(
          decoration: _previewInputDecoration(field.placeholder),
          value: _previewValues[field.id] as String?,
          items: field.options.isEmpty
              ? [
                  const DropdownMenuItem(
                      value: 'Option 1', child: Text('Option 1'))
                ]
              : field.options
                  .map((option) =>
                      DropdownMenuItem(value: option, child: Text(option)))
                  .toList(),
          onChanged: (value) {
            setState(() {
              _previewValues[field.id] = value;
            });
          },
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xff111827),
          ),
          dropdownColor: Colors.white,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: Color(0xff3B82F6),
          ),
        );
      case 'yesNo':
        return Row(
          children: [
            Radio<bool>(
              value: true,
              groupValue: _previewValues[field.id] as bool?,
              onChanged: (value) {
                setState(() {
                  _previewValues[field.id] = value;
                });
              },
              activeColor: const Color(0xff3B82F6),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _previewValues[field.id] = true;
                });
              },
              child: Text(
                'Yes',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xff374151),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 24),
            Radio<bool>(
              value: false,
              groupValue: _previewValues[field.id] as bool?,
              onChanged: (value) {
                setState(() {
                  _previewValues[field.id] = value;
                });
              },
              activeColor: const Color(0xff3B82F6),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _previewValues[field.id] = false;
                });
              },
              child: Text(
                'No',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xff374151),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      case 'date':
        return GestureDetector(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _previewValues[field.id] != null
                  ? DateTime.parse(_previewValues[field.id])
                  : DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: const Color(0xff3B82F6),
                      onPrimary: Colors.white,
                      secondary: const Color(0xff3B82F6).withOpacity(0.1),
                      onSecondary: const Color(0xff3B82F6),
                      surface: Colors.white,
                      onSurface: const Color(0xff111827),
                      background: Colors.white,
                      onBackground: const Color(0xff111827),
                      surfaceVariant: const Color(0xffF8FAFC),
                      onSurfaceVariant: const Color(0xff6B7280),
                    ),
                    dialogTheme: DialogThemeData(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 24,
                      backgroundColor: Colors.white,
                    ),
                    datePickerTheme: DatePickerThemeData(
                      backgroundColor: Colors.white,
                      headerBackgroundColor: const Color(0xff3B82F6),
                      headerForegroundColor: Colors.white,
                      weekdayStyle: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xff6B7280),
                      ),
                      dayStyle: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xff111827),
                      ),
                      yearStyle: GoogleFonts.inter(
                        fontSize: 16,
                        color: const Color(0xff111827),
                      ),
                      headerHeadlineStyle: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      headerHelpStyle: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    textButtonTheme: TextButtonThemeData(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xff3B82F6),
                        textStyle: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) {
              setState(() {
                _previewValues[field.id] = date.toIso8601String().split('T')[0];
              });
            }
          },
          child: AbsorbPointer(
            child: TextFormField(
              decoration: _previewInputDecoration(field.placeholder).copyWith(
                suffixIcon: Container(
                  padding: const EdgeInsets.all(12),
                  child: const Icon(Icons.calendar_today,
                      size: 20, color: Color(0xff3B82F6)),
                ),
              ),
              controller: TextEditingController(
                text: _previewValues[field.id] != null
                    ? _formatDate(_previewValues[field.id])
                    : field.placeholder.isEmpty
                        ? 'Select date...'
                        : field.placeholder,
              ),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _previewValues[field.id] != null
                    ? const Color(0xff111827)
                    : const Color(0xff9CA3AF),
                fontWeight: _previewValues[field.id] != null
                    ? FontWeight.w500
                    : FontWeight.w400,
              ),
            ),
          ),
        );
      case 'imageUpload':
        final hasImage = _previewValues[field.id] != null;

        return GestureDetector(
          onTap: () async {
            try {
              FilePickerResult? result = await FilePicker.platform.pickFiles(
                type: FileType.image,
                allowMultiple: false,
              );

              if (result != null && result.files.isNotEmpty) {
                final file = result.files.first;
                setState(() {
                  _previewValues[field.id] = {
                    'fileName': file.name,
                    'bytes': file.bytes,
                    'size': file.size,
                  };
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Image uploaded: ${file.name}'),
                    backgroundColor: const Color(0xff10B981),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error selecting image: $e'),
                  backgroundColor: const Color(0xffEF4444),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
          child: Container(
            height: hasImage ? 160 : 120,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                  color: hasImage
                      ? const Color(0xff3B82F6)
                      : const Color(0xffE2E8F0),
                  width: hasImage ? 2 : 2),
              borderRadius: BorderRadius.circular(8),
              color: hasImage ? Colors.white : const Color(0xffF9FAFB),
            ),
            child: hasImage
                ? _buildImagePreview(field)
                : _buildImageUploadPlaceholder(),
          ),
        );
      case 'signature':
        return GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(
                  'Digital Signature',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                content: const Text(
                    'In the actual form, users would be able to draw their signature using touch or mouse.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          },
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xffE2E8F0), width: 2),
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xffF9FAFB),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.draw,
                  size: 32,
                  color: Color(0xff6B7280),
                ),
                const SizedBox(height: 8),
                Text(
                  'Click to sign',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xff6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      case 'description':
        return TextFormField(
          decoration: _previewInputDecoration(field.placeholder),
          maxLines: 3,
          onChanged: (value) {
            // Handle text input in preview
          },
        );
      case 'number':
        return TextFormField(
          decoration: _previewInputDecoration(field.placeholder).copyWith(
            suffixIcon:
                const Icon(Icons.numbers, size: 20, color: Color(0xff3B82F6)),
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            // Handle number input in preview
          },
        );
      case 'openEnded':
      default:
        return TextFormField(
          decoration: _previewInputDecoration(field.placeholder),
          onChanged: (value) {
            // Handle text input in preview
          },
        );
    }
  }

  InputDecoration _previewInputDecoration(String placeholder) {
    return InputDecoration(
      hintText: placeholder.isEmpty ? 'Enter value...' : placeholder,
      hintStyle: GoogleFonts.inter(
        color: const Color(0xff9CA3AF),
        fontSize: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xffE2E8F0)),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xffE2E8F0)),
      ),
      filled: true,
      fillColor: const Color(0xffF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  void _addFieldFromTemplate(FieldTemplate template) {
    setState(() {
      fields.add(FormFieldData(
        id: const Uuid().v4(),
        label: template.title,
        type: template.type,
        placeholder: 'Enter ${template.title.toLowerCase()}...',
        required: false,
        order: fields.length,
      ));
    });
  }

  void _reorderFields(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final field = fields.removeAt(oldIndex);
      fields.insert(newIndex, field);

      // Update order
      for (int i = 0; i < fields.length; i++) {
        fields[i].order = i;
      }
    });
  }

  void _removeField(FormFieldData field) {
    setState(() {
      fields.remove(field);
    });
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return isoDate;
    }
  }

  Widget _buildImagePreview(FormFieldData field) {
    final imageData = _previewValues[field.id] as Map<String, dynamic>;
    final fileName = imageData['fileName'] as String;
    final bytes = imageData['bytes'] as List<int>?;
    final size = imageData['size'] as int;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image thumbnail with delete button
          Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xff3B82F6),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: bytes != null
                      ? Image.memory(
                          Uint8List.fromList(bytes!),
                          fit: BoxFit.cover,
                          width: 80,
                          height: 80,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildImageFallback();
                          },
                        )
                      : _buildImageFallback(),
                ),
              ),
              // Delete button
              Positioned(
                top: -4,
                right: -4,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _previewValues.remove(field.id);
                    });
                  },
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xffEF4444),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // File information
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Color(0xff10B981),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Image uploaded',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff10B981),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  fileName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xff111827),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatFileSize(size),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xff6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                // Change button (inline)
                InkWell(
                  onTap: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.image,
                      allowMultiple: false,
                    );

                    if (result != null && result.files.isNotEmpty) {
                      final file = result.files.first;
                      if (file.bytes != null) {
                        setState(() {
                          _previewValues[field.id] = {
                            'fileName': file.name,
                            'bytes': file.bytes!,
                            'size': file.size,
                          };
                        });
                      }
                    }
                  },
                  child: Text(
                    'Change image',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xff3B82F6),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularImageFallback() {
    return Container(
      width: 80,
      height: 80,
      decoration: const BoxDecoration(
        color: Color(0xffF8FAFC),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.image,
        size: 32,
        color: Color(0xff3B82F6),
      ),
    );
  }

  Widget _buildImageFallback() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(
        Icons.image,
        size: 28,
        color: Color(0xff3B82F6),
      ),
    );
  }

  Widget _buildFileInfoDisplay(String fileName, int size) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xffE2E8F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.image,
            size: 40,
            color: Color(0xff3B82F6),
          ),
          const SizedBox(height: 8),
          Text(
            'Image Preview',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'File uploaded successfully',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xff6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageUploadPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.cloud_upload_outlined,
          size: 32,
          color: Color(0xff6B7280),
        ),
        const SizedBox(height: 8),
        Text(
          'Click to upload image',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xff6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'JPG, PNG up to 10MB',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xff9CA3AF),
          ),
        ),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _getFieldTypeForFirestore(String internalType) {
    switch (internalType) {
      case 'openEnded':
        return 'text';
      case 'description':
        return 'long_text';
      case 'dropdown':
        return 'dropdown';
      case 'yesNo':
        return 'radio';
      case 'number':
        return 'number';
      case 'date':
        return 'date';
      case 'imageUpload':
        return 'image_upload';
      case 'signature':
        return 'signature';
      default:
        return internalType;
    }
  }

  Future<void> _saveForm() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Form title is required'),
          backgroundColor: const Color(0xffEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    if (fields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Add at least one field to the form'),
          backgroundColor: const Color(0xffEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    // Validate that all fields have labels
    for (var field in fields) {
      if (field.label.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Field #${field.order + 1} is missing a label'),
            backgroundColor: const Color(0xffEF4444),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        return;
      }

      // Validate dropdown fields have options
      if (field.type == 'dropdown' && field.options.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Dropdown field "${field.label}" needs at least one option'),
            backgroundColor: const Color(0xffEF4444),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Must be logged in');

      // Convert fields to map with correct field type names
      final fieldsMap = <String, dynamic>{};
      for (var field in fields) {
        // Map internal field types to the expected types in forms page
        String fieldType = _getFieldTypeForFirestore(field.type);

        fieldsMap[field.id] = {
          'type': fieldType,
          'label': field.label,
          'placeholder': field.placeholder,
          'required': field.required,
          'order': field.order,
          if (field.options.isNotEmpty) 'options': field.options,
          if (field.minValue != null) 'minValue': field.minValue,
          if (field.maxValue != null) 'maxValue': field.maxValue,
          if (field.additionalConfig != null) ...field.additionalConfig!,
        };
      }

      // Get user info for creator details
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();
      final creatorName = userData != null
          ? '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
              .trim()
          : 'Unknown User';

      // Create form document with proper structure
      await FirebaseFirestore.instance.collection('form').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
        'createdByName': creatorName,
        'status': 'active',
        'isPublished': true,
        'fieldCount': fields.length,
        'fields': fieldsMap,
        'responses': {}, // Initialize empty responses object
        'responseCount': 0,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                  'Form "${_titleController.text.trim()}" saved successfully!'),
            ],
          ),
          backgroundColor: const Color(0xff10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 3),
        ),
      );

      // Clear form after successful save
      _titleController.clear();
      _descriptionController.clear();
      setState(() {
        fields.clear();
      });

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving form: $e'),
          backgroundColor: const Color(0xffEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }
}

class FormFieldData {
  String id;
  String label;
  String type;
  String placeholder;
  bool required;
  int order;
  List<String> options;
  double? minValue;
  double? maxValue;
  Map<String, dynamic>? additionalConfig;

  FormFieldData({
    required this.id,
    required this.label,
    required this.type,
    required this.placeholder,
    required this.required,
    required this.order,
    this.options = const [],
    this.minValue,
    this.maxValue,
    this.additionalConfig,
  });
}

class FieldTemplate {
  final String type;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  FieldTemplate({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
