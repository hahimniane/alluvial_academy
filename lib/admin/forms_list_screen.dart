import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'form_builder.dart';
import '../core/models/form_template.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Forms List Screen - Google Forms style list view
/// Allows viewing, editing, duplicating, and deleting forms
class FormsListScreen extends StatefulWidget {
  const FormsListScreen({super.key});

  @override
  State<FormsListScreen> createState() => _FormsListScreenState();
}

class _FormsListScreenState extends State<FormsListScreen> {
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _sortBy = 'newest';
  String _collectionType = 'form'; // 'form' or 'form_templates'
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0EBF8),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildFormsList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF673AB7).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.description,
                  color: Color(0xFF673AB7),
                  size: 28,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.formTemplates,
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)!.createAndManageYourFormTemplates,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              // Create new form button
              ElevatedButton.icon(
                onPressed: _createNewForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF673AB7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add, size: 20),
                label: Text(
                  AppLocalizations.of(context)!.createForm,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Collection type selector (tabs)
          Row(
            children: [
              _buildCollectionTab('form', 'Old Forms', Icons.description),
              const SizedBox(width: 8),
              _buildCollectionTab('form_templates', 'New Templates', Icons.dynamic_form),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Search and filters row
          Row(
            children: [
              // Search
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.searchForms,
                      hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                      prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Status filter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    items: [
                      DropdownMenuItem(value: 'all', child: Text(AppLocalizations.of(context)!.allForms)),
                      DropdownMenuItem(value: 'active', child: Text(AppLocalizations.of(context)!.shiftActive)),
                      DropdownMenuItem(value: 'inactive', child: Text(AppLocalizations.of(context)!.userInactive)),
                    ],
                    onChanged: (v) => setState(() => _statusFilter = v!),
                  ),
                ),
              ),
              
              SizedBox(width: 12),
              
              // Sort
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sortBy,
                    items: [
                      DropdownMenuItem(value: 'newest', child: Text(AppLocalizations.of(context)!.newestFirst)),
                      DropdownMenuItem(value: 'oldest', child: Text(AppLocalizations.of(context)!.oldestFirst)),
                      DropdownMenuItem(value: 'name', child: Text(AppLocalizations.of(context)!.nameAZ)),
                    ],
                    onChanged: (v) => setState(() => _sortBy = v!),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionTab(String collectionType, String label, IconData icon) {
    final isSelected = _collectionType == collectionType;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _collectionType = collectionType),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF673AB7) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF673AB7) : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormsList() {
    if (_collectionType == 'form_templates') {
      return _buildFormTemplatesList();
    }
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('form')
          .orderBy('createdAt', descending: _sortBy == 'newest')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        var forms = snapshot.data!.docs;
        
        // Apply filters
        forms = forms.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final title = (data['title'] as String? ?? '').toLowerCase();
          
          // Search filter
          if (_searchQuery.isNotEmpty && !title.contains(_searchQuery)) {
            return false;
          }
          
          // Status filter
          if (_statusFilter != 'all') {
            final status = data['status'] as String? ?? 'active';
            if (status != _statusFilter) return false;
          }
          
          return true;
        }).toList();

        // Sort by name if needed
        if (_sortBy == 'name') {
          forms.sort((a, b) {
            final aTitle = (a.data() as Map)['title'] as String? ?? '';
            final bTitle = (b.data() as Map)['title'] as String? ?? '';
            return aTitle.compareTo(bTitle);
          });
        }

        if (forms.isEmpty) {
          return _buildNoResultsState();
        }

        return GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 300,
            childAspectRatio: 0.85,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: forms.length,
          itemBuilder: (context, index) {
            final doc = forms[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildFormCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildFormTemplatesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('form_templates')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        var templates = snapshot.data!.docs;
        
        // Apply filters
        templates = templates.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] as String? ?? '').toLowerCase();
          final isActive = data['isActive'] as bool? ?? true;
          
          // Search filter
          if (_searchQuery.isNotEmpty && !name.contains(_searchQuery)) {
            return false;
          }
          
          // Status filter
          if (_statusFilter != 'all') {
            if (_statusFilter == 'active' && !isActive) return false;
            if (_statusFilter == 'inactive' && isActive) return false;
          }
          
          return true;
        }).toList();

        // Sort
        templates.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          
          if (_sortBy == 'name') {
            final aName = (aData['name'] as String? ?? '').toLowerCase();
            final bName = (bData['name'] as String? ?? '').toLowerCase();
            return aName.compareTo(bName);
          } else {
            final aCreated = (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
            final bCreated = (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
            return _sortBy == 'newest' 
                ? bCreated.compareTo(aCreated)
                : aCreated.compareTo(bCreated);
          }
        });

        if (templates.isEmpty) {
          return _buildNoResultsState();
        }

        return GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 300,
            childAspectRatio: 0.85,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: templates.length,
          itemBuilder: (context, index) {
            final doc = templates[index];
            try {
              final template = FormTemplate.fromFirestore(doc);
              return _buildTemplateCard(doc.id, template);
            } catch (e) {
              debugPrint('Error parsing template ${doc.id}: $e');
              return Container();
            }
          },
        );
      },
    );
  }

  Widget _buildTemplateCard(String templateId, FormTemplate template) {
    final createdAt = template.createdAt;
    final fieldCount = template.fields.length;
    final isActive = template.isActive;

    return InkWell(
      onTap: () => _editTemplate(templateId, template),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top colored bar
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.dynamic_form,
                      size: 40,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  // More options menu
                  Positioned(
                    top: 4,
                    right: 4,
                    child: PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                      onSelected: (action) => _handleTemplateAction(action, templateId, template),
                      itemBuilder: (context) => [
                        PopupMenuItem(value: 'edit', child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text(AppLocalizations.of(context)!.commonEdit),
                          ],
                        )),
                        PopupMenuItem(value: 'duplicate', child: Row(
                          children: [
                            Icon(Icons.content_copy, size: 18),
                            SizedBox(width: 8),
                            Text(AppLocalizations.of(context)!.duplicate),
                          ],
                        )),
                        PopupMenuItem(
                          value: isActive ? 'deactivate' : 'activate',
                          child: Row(
                            children: [
                              Icon(isActive ? Icons.pause : Icons.play_arrow, size: 18),
                              const SizedBox(width: 8),
                              Text(isActive ? 'Deactivate' : 'Activate'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(value: 'delete', child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text(AppLocalizations.of(context)!.commonDelete, style: TextStyle(color: Colors.red)),
                          ],
                        )),
                      ],
                    ),
                  ),
                  // Status badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green : Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Inactive',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1F2937),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (template.description != null && template.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        template.description!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.help_outline, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          '$fieldCount field${fieldCount != 1 ? 's' : ''}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const Spacer(),
                        if (createdAt != null)
                          Text(
                            DateFormat('MMM d').format(createdAt),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                            ),
                          ),
                      ],
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

  Widget _buildFormCard(String formId, Map<String, dynamic> data) {
    final title = data['title'] as String? ?? 'Untitled Form';
    final description = data['description'] as String? ?? '';
    final status = data['status'] as String? ?? 'active';
    final themeColor = data['themeColor'] as String? ?? '#673AB7';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final fields = data['fields'] as Map<String, dynamic>? ?? {};
    
    final color = Color(int.parse(themeColor.replaceFirst('#', '0xFF')));
    final isActive = status == 'active';

    return InkWell(
      onTap: () => _editForm(formId, data),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top colored bar
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.description,
                      size: 40,
                      color: color,
                    ),
                  ),
                  // More options menu
                  Positioned(
                    top: 4,
                    right: 4,
                    child: PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                      onSelected: (action) => _handleFormAction(action, formId, data),
                      itemBuilder: (context) => [
                        PopupMenuItem(value: 'edit', child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text(AppLocalizations.of(context)!.commonEdit),
                          ],
                        )),
                        PopupMenuItem(value: 'duplicate', child: Row(
                          children: [
                            Icon(Icons.content_copy, size: 18),
                            SizedBox(width: 8),
                            Text(AppLocalizations.of(context)!.duplicate),
                          ],
                        )),
                        PopupMenuItem(
                          value: isActive ? 'deactivate' : 'activate',
                          child: Row(
                            children: [
                              Icon(isActive ? Icons.pause : Icons.play_arrow, size: 18),
                              const SizedBox(width: 8),
                              Text(isActive ? 'Deactivate' : 'Activate'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(value: 'delete', child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text(AppLocalizations.of(context)!.commonDelete, style: TextStyle(color: Colors.red)),
                          ],
                        )),
                      ],
                    ),
                  ),
                  // Status badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green : Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Inactive',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1F2937),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.help_outline, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          '${fields.length} question${fields.length != 1 ? 's' : ''}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const Spacer(),
                        if (createdAt != null)
                          Text(
                            DateFormat('MMM d').format(createdAt),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                            ),
                          ),
                      ],
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.noFormsYet,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.createYourFirstFormToGet,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _createNewForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF673AB7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.of(context)!.createForm),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.noFormsFound,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.tryAdjustingYourSearchOrFilters,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  void _createNewForm() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const FormBuilder(),
      ),
    );
  }

  void _editForm(String formId, Map<String, dynamic> data) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FormBuilder(
          editFormId: formId,
          editFormData: data,
        ),
      ),
    );
  }

  void _editTemplate(String templateId, FormTemplate template) {
    HapticFeedback.lightImpact();
    // Convert FormTemplate to the format expected by FormBuilder
    // For now, we'll create a simple editor dialog
    _showTemplateEditorDialog(templateId, template);
  }
  
  void _showTemplateEditorDialog(String templateId, FormTemplate template) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _TemplateEditorDialog(templateId: templateId, template: template),
    );
  }

  Future<void> _handleFormAction(String action, String formId, Map<String, dynamic> data) async {
    switch (action) {
      case 'edit':
        _editForm(formId, data);
        break;
        
      case 'duplicate':
        await _duplicateForm(formId, data);
        break;
        
      case 'activate':
      case 'deactivate':
        await _toggleFormStatus(formId, action == 'activate');
        break;
        
      case 'delete':
        await _deleteForm(formId, data['title'] as String? ?? 'Untitled Form');
        break;
    }
  }

  Future<void> _duplicateForm(String formId, Map<String, dynamic> data) async {
    try {
      final newData = Map<String, dynamic>.from(data);
      newData['title'] = '${data['title']} (Copy)';
      newData['createdAt'] = FieldValue.serverTimestamp();
      newData['updatedAt'] = FieldValue.serverTimestamp();
      
      await FirebaseFirestore.instance.collection('form').add(newData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.formDuplicatedSuccessfully)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorDuplicatingFormE)),
        );
      }
    }
  }

  Future<void> _toggleFormStatus(String formId, bool activate) async {
    try {
      await FirebaseFirestore.instance
          .collection('form')
          .doc(formId)
          .update({'status': activate ? 'active' : 'inactive'});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Form ${activate ? 'activated' : 'deactivated'}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorE)),
        );
      }
    }
  }

  Future<void> _handleTemplateAction(String action, String templateId, FormTemplate template) async {
    switch (action) {
      case 'edit':
        _editTemplate(templateId, template);
        break;
        
      case 'duplicate':
        await _duplicateTemplate(templateId, template);
        break;
        
      case 'activate':
      case 'deactivate':
        await _toggleTemplateStatus(templateId, action == 'activate');
        break;
        
      case 'delete':
        await _deleteTemplate(templateId, template.name);
        break;
    }
  }

  Future<void> _duplicateTemplate(String templateId, FormTemplate template) async {
    try {
      // Convert to Firestore format using toMap()
      final newData = template.toMap();
      newData['name'] = '${template.name} (Copy)';
      newData['createdAt'] = FieldValue.serverTimestamp();
      newData['updatedAt'] = FieldValue.serverTimestamp();
      
      await FirebaseFirestore.instance.collection('form_templates').add(newData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.templateDuplicatedSuccessfully)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorDuplicatingTemplateE)),
        );
      }
    }
  }

  Future<void> _toggleTemplateStatus(String templateId, bool activate) async {
    try {
      await FirebaseFirestore.instance
          .collection('form_templates')
          .doc(templateId)
          .update({
            'isActive': activate,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Template ${activate ? 'activated' : 'deactivated'}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorE)),
        );
      }
    }
  }

  Future<void> _deleteTemplate(String templateId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteTemplate),
        content: Text(AppLocalizations.of(context)!.areYouSureYouWantTo10),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.commonDelete, style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance.collection('form_templates').doc(templateId).delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.templateDeleted)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorDeletingTemplateE)),
        );
      }
    }
  }

  Future<void> _deleteForm(String formId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteForm),
        content: Text(AppLocalizations.of(context)!.areYouSureYouWantTo11),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.commonDelete, style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance.collection('form').doc(formId).delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.formDeleted)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorDeletingFormE)),
        );
      }
    }
  }
}

/// Dialog for editing form templates
class _TemplateEditorDialog extends StatefulWidget {
  final String templateId;
  final FormTemplate template;

  const _TemplateEditorDialog({
    required this.templateId,
    required this.template,
  });

  @override
  State<_TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<_TemplateEditorDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late List<FormFieldDefinition> _fields;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.template.name);
    _descriptionController = TextEditingController(text: widget.template.description ?? '');
    _fields = List.from(widget.template.fields.map((f) => FormFieldDefinition(
      id: f.id,
      label: f.label,
      type: f.type,
      placeholder: f.placeholder,
      required: f.required,
      order: f.order,
      options: f.options != null ? List.from(f.options!) : null,
      conditionalLogic: f.conditionalLogic != null ? Map.from(f.conditionalLogic!) : null,
      validation: f.validation != null ? Map.from(f.validation!) : null,
    )));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _addNewField() {
    final newField = FormFieldDefinition(
      id: 'field_${DateTime.now().millisecondsSinceEpoch}',
      label: 'New Question',
      type: 'text',
      required: false,
      order: _fields.length,
    );
    setState(() {
      _fields.add(newField);
    });
    // Open edit dialog for the new field
    _editField(newField, _fields.length - 1);
  }

  void _editField(FormFieldDefinition field, int index) {
    showDialog(
      context: context,
      builder: (context) => _FieldEditorDialog(
        field: field,
        onSave: (updatedField) {
      setState(() {
        _fields[index] = FormFieldDefinition(
          id: updatedField.id,
          label: updatedField.label,
          type: updatedField.type,
          placeholder: updatedField.placeholder,
          required: updatedField.required,
          order: index,
          options: updatedField.options,
          conditionalLogic: updatedField.conditionalLogic,
          validation: updatedField.validation,
        );
      });
        },
      ),
    );
  }

  void _deleteField(int index) {
    setState(() {
      _fields.removeAt(index);
      // Reorder remaining fields
      for (var i = 0; i < _fields.length; i++) {
        final oldField = _fields[i];
        _fields[i] = FormFieldDefinition(
          id: oldField.id,
          label: oldField.label,
          type: oldField.type,
          placeholder: oldField.placeholder,
          required: oldField.required,
          order: i,
          options: oldField.options,
          conditionalLogic: oldField.conditionalLogic,
          validation: oldField.validation,
        );
      }
    });
  }

  void _moveField(int index, int direction) {
    if ((direction < 0 && index == 0) || (direction > 0 && index == _fields.length - 1)) {
      return;
    }
    setState(() {
      final newIndex = index + direction;
      final field = _fields.removeAt(index);
      _fields.insert(newIndex, field);
      // Reorder all fields
      for (var i = 0; i < _fields.length; i++) {
        final oldField = _fields[i];
        _fields[i] = FormFieldDefinition(
          id: oldField.id,
          label: oldField.label,
          type: oldField.type,
          placeholder: oldField.placeholder,
          required: oldField.required,
          order: i,
          options: oldField.options,
          conditionalLogic: oldField.conditionalLogic,
          validation: oldField.validation,
        );
      }
    });
  }

  Future<void> _saveTemplate() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.templateNameCannotBeEmpty)),
      );
      return;
    }

    if (_fields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.templateMustHaveAtLeastOne)),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Convert fields to Firestore format: { "field_id": { ... field data ... } }
      final fieldsMap = <String, dynamic>{};
      for (var field in _fields) {
        fieldsMap[field.id] = {
          'label': field.label,
          'type': field.type,
          'placeholder': field.placeholder,
          'required': field.required,
          'order': field.order,
          if (field.options != null) 'options': field.options,
          if (field.conditionalLogic != null) 'conditionalLogic': field.conditionalLogic,
          if (field.validation != null) 'validation': field.validation,
        };
      }

      // Update template in Firestore
      await FirebaseFirestore.instance
          .collection('form_templates')
          .doc(widget.templateId)
          .update({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        'fields': fieldsMap,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.templateUpdatedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorSavingTemplateE),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF673AB7),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.editTemplate,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.templateName,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.enterTemplateName,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      AppLocalizations.of(context)!.description,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.enterTemplateDescription,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Fields Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Form Fields (${_fields.length})',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _addNewField,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF673AB7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(AppLocalizations.of(context)!.addField),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Fields List
                    if (_fields.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.help_outline, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                AppLocalizations.of(context)!.noFieldsYetAddYourFirst,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._fields.asMap().entries.map((entry) {
                        final index = entry.key;
                        final field = entry.value;
                        return _buildFieldCard(field, index);
                      }),
                  ],
                ),
              ),
            ),
            
            // Footer buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    child: Text(AppLocalizations.of(context)!.commonCancel),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveTemplate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF673AB7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(AppLocalizations.of(context)!.timesheetSaveChanges),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldCard(FormFieldDefinition field, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _editField(field, index),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Drag handle / Order
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                // Field info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              field.label,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade900,
                              ),
                            ),
                          ),
                          if (field.required)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.commonRequired,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getFieldTypeLabel(field.type),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                          if (field.options != null && field.options!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${field.options!.length} options',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Actions
                IconButton(
                  icon: Icon(Icons.arrow_upward, size: 18, color: Colors.grey.shade600),
                  onPressed: index > 0 ? () => _moveField(index, -1) : null,
                  tooltip: AppLocalizations.of(context)!.moveUp,
                ),
                IconButton(
                  icon: Icon(Icons.arrow_downward, size: 18, color: Colors.grey.shade600),
                  onPressed: index < _fields.length - 1 ? () => _moveField(index, 1) : null,
                  tooltip: AppLocalizations.of(context)!.moveDown,
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18, color: Color(0xFF673AB7)),
                  onPressed: () => _editField(field, index),
                  tooltip: AppLocalizations.of(context)!.commonEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(AppLocalizations.of(context)!.deleteField),
                        content: Text('Are you sure you want to delete "${field.label}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(AppLocalizations.of(context)!.commonCancel),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _deleteField(index);
                            },
                            child: Text(AppLocalizations.of(context)!.commonDelete, style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  tooltip: AppLocalizations.of(context)!.commonDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getFieldTypeLabel(String type) {
    switch (type) {
      case 'text': return 'Short Text';
      case 'long_text': return 'Long Text';
      case 'number': return 'Number';
      case 'radio': return 'Radio';
      case 'dropdown': return 'Dropdown';
      case 'multi_select': return 'Multi Select';
      case 'date': return 'Date';
      case 'time': return 'Time';
      default: return type;
    }
  }
}

/// Dialog for editing individual form fields
class _FieldEditorDialog extends StatefulWidget {
  final FormFieldDefinition field;
  final Function(FormFieldDefinition) onSave;

  const _FieldEditorDialog({
    required this.field,
    required this.onSave,
  });

  @override
  State<_FieldEditorDialog> createState() => _FieldEditorDialogState();
}

class _FieldEditorDialogState extends State<_FieldEditorDialog> {
  late TextEditingController _labelController;
  late TextEditingController _placeholderController;
  late String _fieldType;
  late bool _required;
  late List<TextEditingController> _optionControllers;

  final List<String> _fieldTypes = [
    'text',
    'long_text',
    'number',
    'radio',
    'dropdown',
    'multi_select',
    'date',
    'time',
  ];

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.field.label);
    _placeholderController = TextEditingController(text: widget.field.placeholder ?? '');
    _fieldType = widget.field.type;
    _required = widget.field.required;
    _optionControllers = (widget.field.options ?? []).map((opt) => TextEditingController(text: opt)).toList();
    if (_optionControllers.isEmpty && _needsOptions(_fieldType)) {
      _optionControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _placeholderController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _needsOptions(String type) {
    return type == 'radio' || type == 'dropdown' || type == 'multi_select';
  }

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
    });
  }

  void _saveField() {
    if (_labelController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.fieldLabelCannotBeEmpty)),
      );
      return;
    }

    final options = _needsOptions(_fieldType)
        ? _optionControllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList()
        : null;

    if (_needsOptions(_fieldType) && (options == null || options.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseProvideAtLeastOneOption)),
      );
      return;
    }

    final updatedField = FormFieldDefinition(
      id: widget.field.id,
      label: _labelController.text.trim(),
      type: _fieldType,
      placeholder: _placeholderController.text.trim().isEmpty ? null : _placeholderController.text.trim(),
      required: _required,
      order: widget.field.order,
      options: options,
      conditionalLogic: widget.field.conditionalLogic,
      validation: widget.field.validation,
    );

    widget.onSave(updatedField);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF673AB7),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.editField,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.questionLabel,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _labelController,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.eGWhatLessonDidYou,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    Text(
                      AppLocalizations.of(context)!.fieldType2,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _fieldType,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: _fieldTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(_getFieldTypeLabel(type)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _fieldType = value!;
                            if (_needsOptions(_fieldType) && _optionControllers.isEmpty) {
                              _optionControllers.add(TextEditingController());
                            } else if (!_needsOptions(_fieldType)) {
                              for (var controller in _optionControllers) {
                                controller.dispose();
                              }
                              _optionControllers.clear();
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    Text(
                      AppLocalizations.of(context)!.placeholderOptional,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _placeholderController,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.eGEnterYourAnswerHere,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Options for radio/dropdown/multi_select
                    if (_needsOptions(_fieldType)) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.options,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addOption,
                            icon: const Icon(Icons.add, size: 16),
                            label: Text(AppLocalizations.of(context)!.addOption2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._optionControllers.asMap().entries.map((entry) {
                        final index = entry.key;
                        final controller = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: controller,
                                  decoration: InputDecoration(
                                    hintText: 'Option ${index + 1}',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              if (_optionControllers.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removeOption(index),
                                ),
                            ],
                          ),
                        );
                      }),
                      SizedBox(height: 20),
                    ],
                    
                    // Required checkbox
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        AppLocalizations.of(context)!.requiredField,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      value: _required,
                      onChanged: (value) => setState(() => _required = value ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
            ),
            
            // Footer buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(AppLocalizations.of(context)!.commonCancel),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _saveField,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF673AB7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text(AppLocalizations.of(context)!.saveField),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFieldTypeLabel(String type) {
    switch (type) {
      case 'text': return 'Short Text';
      case 'long_text': return 'Long Text';
      case 'number': return 'Number';
      case 'radio': return 'Radio (Single Choice)';
      case 'dropdown': return 'Dropdown';
      case 'multi_select': return 'Multi Select (Checkboxes)';
      case 'date': return 'Date';
      case 'time': return 'Time';
      default: return type;
    }
  }
}
