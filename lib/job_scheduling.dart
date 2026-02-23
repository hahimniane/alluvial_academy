import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class JobSchedulingScreen extends StatefulWidget {
  const JobSchedulingScreen({super.key});

  @override
  State<JobSchedulingScreen> createState() => _FormBuilderState();
}

class _FormBuilderState extends State<JobSchedulingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<FormFieldData> fields = [];
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.createForm),
        actions: [
          TextButton(
            onPressed: _saveForm,
            child: _isSaving
                ? const CircularProgressIndicator()
                : Text(AppLocalizations.of(context)!.saveForm),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Form Title
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.formTitle,
                  hintText: AppLocalizations.of(context)!.enterFormTitle,
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Form Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.formDescription,
                  hintText: AppLocalizations.of(context)!.enterFormDescription,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Fields List
              Text(
                AppLocalizations.of(context)!.formFields,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              ...fields.map((field) => _buildFieldEditor(field)),

              // Add Field Button
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: ElevatedButton.icon(
                  onPressed: _addField,
                  icon: const Icon(Icons.add),
                  label: Text(AppLocalizations.of(context)!.addField),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldEditor(FormFieldData field) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: field.label,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.fieldLabel,
                      hintText: AppLocalizations.of(context)!.enterFieldLabel,
                    ),
                    onChanged: (value) {
                      field.label = value;
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _removeField(field),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: field.type,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.fieldType,
                    ),
                    items: [
                      'text',
                      'number',
                      'email',
                      'phone',
                      'multiline',
                      'select',
                      'multi_select',
                      'date',
                    ]
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type.toUpperCase()),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          field.type = value;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: field.placeholder,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.placeholder,
                      hintText: AppLocalizations.of(context)!.enterPlaceholderText,
                    ),
                    onChanged: (value) {
                      field.placeholder = value;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: Text(AppLocalizations.of(context)!.commonRequired),
                    value: field.required,
                    onChanged: (value) {
                      setState(() {
                        field.required = value ?? false;
                      });
                    },
                  ),
                ),
                if (field.type == 'select' || field.type == 'multi_select')
                  Expanded(
                    child: TextFormField(
                      initialValue: field.options.join(', '),
                      decoration: InputDecoration(
                        labelText: field.type == 'multi_select'
                            ? 'Multi-Select Options (comma separated)'
                            : 'Options (comma separated)',
                        hintText: AppLocalizations.of(context)!.optionsCommaSeparatedExample,
                      ),
                      onChanged: (value) {
                        field.options = value
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList();
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addField() {
    setState(() {
      fields.add(FormFieldData(
        id: const Uuid().v4(),
        label: '',
        type: 'text',
        placeholder: '',
        required: false,
        order: fields.length,
      ));
    });
  }

  void _removeField(FormFieldData field) {
    setState(() {
      fields.remove(field);
    });
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (fields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.addAtLeastOneField)),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Must be logged in');

      // Convert fields to map
      final fieldsMap = {};
      for (var field in fields) {
        fieldsMap[field.id] = {
          'type': field.type,
          'label': field.label,
          'placeholder': field.placeholder,
          'required': field.required,
          'order': field.order,
          if (field.type == 'select') 'options': field.options,
        };
      }

      // Create form document
      await FirebaseFirestore.instance.collection('form').add({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
        'status': 'active',
        'fields': fieldsMap,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.formSavedSuccessfully)),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorSavingFormE)),
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

  FormFieldData({
    required this.id,
    required this.label,
    required this.type,
    required this.placeholder,
    required this.required,
    required this.order,
    this.options = const [],
  });
}
