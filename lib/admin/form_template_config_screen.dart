import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/models/form_template.dart';
import '../core/services/form_template_service.dart';
import '../core/utils/app_logger.dart';

/// Admin screen for managing form templates
/// Allows viewing, creating, and setting active templates for each frequency type
class FormTemplateConfigScreen extends StatefulWidget {
  const FormTemplateConfigScreen({super.key});

  @override
  State<FormTemplateConfigScreen> createState() => _FormTemplateConfigScreenState();
}

class _FormTemplateConfigScreenState extends State<FormTemplateConfigScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<FormTemplate> _templates = [];
  String? _activeDailyId;
  String? _activeWeeklyId;
  String? _activeMonthlyId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTemplates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);
    try {
      final templates = await FormTemplateService.getAllTemplates();
      
      // If no templates exist, create defaults
      if (templates.isEmpty) {
        await FormTemplateService.ensureDefaultTemplatesExist();
        final newTemplates = await FormTemplateService.getAllTemplates();
        setState(() {
          _templates = newTemplates;
          _isLoading = false;
        });
      } else {
        setState(() {
          _templates = templates;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('Error loading templates: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading templates: $e')),
        );
      }
    }
  }

  List<FormTemplate> _getTemplatesByFrequency(FormFrequency frequency) {
    return _templates.where((t) => t.frequency == frequency && t.isActive).toList();
  }

  Future<void> _setActiveTemplate(FormFrequency frequency, String templateId) async {
    try {
      await FormTemplateService.setActiveTemplate(frequency, templateId);
      
      setState(() {
        switch (frequency) {
          case FormFrequency.perSession:
            _activeDailyId = templateId;
            break;
          case FormFrequency.weekly:
            _activeWeeklyId = templateId;
            break;
          case FormFrequency.monthly:
            _activeMonthlyId = templateId;
            break;
          case FormFrequency.onDemand:
            // On-demand forms don't have a single active template
            break;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Active template updated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _createDefaultTemplates() async {
    setState(() => _isLoading = true);
    try {
      await FormTemplateService.ensureDefaultTemplatesExist();
      await _loadTemplates();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Default templates created!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Form Templates',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xff1E293B),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xff64748B)),
            onPressed: _loadTemplates,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xff0386FF)),
            onPressed: _createDefaultTemplates,
            tooltip: 'Create Default Templates',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xff0386FF),
          unselectedLabelColor: const Color(0xff64748B),
          indicatorColor: const Color(0xff0386FF),
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Daily Reports'),
            Tab(text: 'Weekly'),
            Tab(text: 'Monthly'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTemplateList(FormFrequency.perSession),
                _buildTemplateList(FormFrequency.weekly),
                _buildTemplateList(FormFrequency.monthly),
              ],
            ),
    );
  }

  Widget _buildTemplateList(FormFrequency frequency) {
    final templates = _getTemplatesByFrequency(frequency);
    final activeId = switch (frequency) {
      FormFrequency.perSession => _activeDailyId,
      FormFrequency.weekly => _activeWeeklyId,
      FormFrequency.monthly => _activeMonthlyId,
      FormFrequency.onDemand => null,
    };

    if (templates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No templates for this frequency',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: const Color(0xff64748B),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _createDefaultTemplates,
              icon: const Icon(Icons.add),
              label: const Text('Create Default Templates'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        final isActive = template.id == activeId;

        return _buildTemplateCard(template, isActive, frequency);
      },
    );
  }

  Widget _buildTemplateCard(
      FormTemplate template, bool isActive, FormFrequency frequency) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? const Color(0xff0386FF) : const Color(0xffE2E8F0),
          width: isActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xff0386FF).withOpacity(0.05)
                  : Colors.transparent,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xff0386FF)
                        : const Color(0xffF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getFrequencyIcon(template.frequency),
                    size: 20,
                    color: isActive ? Colors.white : const Color(0xff64748B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            template.name,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xff1E293B),
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xff10B981),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'ACTIVE',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (template.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          template.description!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xff64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  'v${template.version}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xff94A3B8),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Fields Preview
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fields (${template.fields.length})',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: template.fields.map((field) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: field.required
                            ? const Color(0xffFEF3C7)
                            : const Color(0xffF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: field.required
                              ? const Color(0xffF59E0B)
                              : const Color(0xffE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getFieldTypeIcon(field.type),
                            size: 12,
                            color: field.required
                                ? const Color(0xffD97706)
                                : const Color(0xff64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            field.label.length > 25
                                ? '${field.label.substring(0, 25)}...'
                                : field.label,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: field.required
                                  ? const Color(0xffD97706)
                                  : const Color(0xff475569),
                            ),
                          ),
                          if (field.required) ...[
                            const SizedBox(width: 4),
                            const Text(
                              '*',
                              style: TextStyle(
                                color: Color(0xffEF4444),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Auto-fill info
          if (template.autoFillRules.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xffF0FDF4),
                border: Border(
                  top: BorderSide(color: Color(0xffD1FAE5)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_fix_high,
                    size: 14,
                    color: Color(0xff10B981),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${template.autoFillRules.length} fields auto-filled (teacher name, date, etc.)',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xff059669),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Actions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xffE2E8F0)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isActive)
                  TextButton.icon(
                    onPressed: () => _setActiveTemplate(frequency, template.id),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Set as Active'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xff0386FF),
                    ),
                  ),
                TextButton.icon(
                  onPressed: () => _showTemplateDetails(template),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('View Details'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xff64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFrequencyIcon(FormFrequency frequency) {
    return switch (frequency) {
      FormFrequency.perSession => Icons.event_note,
      FormFrequency.weekly => Icons.date_range,
      FormFrequency.monthly => Icons.calendar_month,
      FormFrequency.onDemand => Icons.touch_app,
    };
  }

  IconData _getFieldTypeIcon(String type) {
    return switch (type) {
      'text' => Icons.short_text,
      'long_text' => Icons.notes,
      'number' => Icons.tag,
      'radio' => Icons.radio_button_checked,
      'dropdown' => Icons.arrow_drop_down_circle,
      'date' => Icons.calendar_today,
      _ => Icons.text_fields,
    };
  }

  void _showTemplateDetails(FormTemplate template) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.name,
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Version ${template.version} • ${_getFrequencyLabel(template.frequency)}',
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
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Fields List
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: template.fields.length,
                itemBuilder: (context, index) {
                  final field = template.fields[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xffF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xffE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xff0386FF).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                _getFieldTypeIcon(field.type),
                                size: 14,
                                color: const Color(0xff0386FF),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                field.label,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (field.required)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
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
                          ],
                        ),
                        if (field.placeholder != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Placeholder: ${field.placeholder}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xff94A3B8),
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          'Type: ${field.type}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xff64748B),
                          ),
                        ),
                        if (field.options != null &&
                            field.options!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Options: ${field.options!.join(", ")}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xff64748B),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFrequencyLabel(FormFrequency frequency) {
    return switch (frequency) {
      FormFrequency.perSession => 'Daily (per session)',
      FormFrequency.weekly => 'Weekly',
      FormFrequency.monthly => 'Monthly',
      FormFrequency.onDemand => 'On Demand',
    };
  }
}

