import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/services/form_draft_service.dart';
import '../core/models/form_draft.dart';
import '../debug_firestore_screen.dart';
import 'form_builder.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

/// Screen for managing form drafts
class DraftManagementScreen extends StatefulWidget {
  const DraftManagementScreen({super.key});

  @override
  State<DraftManagementScreen> createState() => _DraftManagementScreenState();
}

class _DraftManagementScreenState extends State<DraftManagementScreen> {
  final FormDraftService _draftService = FormDraftService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: Text(
          'Draft Forms',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xff111827),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xff374151)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xffE2E8F0),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _buildDraftsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xffE2E8F0), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xff10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.drafts,
              color: Color(0xff10B981),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saved Drafts',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff111827),
                  ),
                ),
                Text(
                  'Resume working on your unfinished forms',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xff6B7280),
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => _testConnection(),
            icon: const Icon(Icons.wifi_find, size: 18),
            label: const Text('Test Connection'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xff3B82F6),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => _cleanupOldDrafts(),
            icon: const Icon(Icons.cleaning_services, size: 18),
            label: const Text('Cleanup Old'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xff6B7280),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const DebugFirestoreScreen(),
                ),
              );
            },
            icon: const Icon(Icons.bug_report, size: 18),
            label: const Text('Debug'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xffEF4444),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftsList() {
    return StreamBuilder<List<FormDraft>>(
      stream: _draftService.getUserDrafts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xff10B981)),
            ),
          );
        }

        if (snapshot.hasError) {
          AppLogger.error('DraftManagementScreen: Error in stream: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading drafts',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xff6B7280),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Error: ${snapshot.error.toString()}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xff9CA3AF),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {}); // Trigger rebuild to retry
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff10B981),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        final drafts = snapshot.data ?? [];

        if (drafts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.drafts_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No saved drafts',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xff6B7280),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your progress will be automatically saved while building forms',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xff9CA3AF),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: drafts.length,
          itemBuilder: (context, index) {
            final draft = drafts[index];
            return _buildDraftCard(draft);
          },
        );
      },
    );
  }

  Widget _buildDraftCard(FormDraft draft) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                        draft.title.isEmpty ? 'Untitled Form' : draft.title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff111827),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (draft.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          draft.description,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xff6B7280),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xff10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'DRAFT',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff10B981),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  'Last modified ${draft.lastModifiedFormatted}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.dynamic_form,
                  size: 16,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  '${draft.fields.length} fields',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                const Spacer(),
                _buildActionButtons(draft),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(FormDraft draft) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: () => _resumeDraft(draft),
          icon: const Icon(Icons.edit, size: 16),
          label: const Text('Resume'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xff3B82F6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () => _deleteDraft(draft),
          icon: const Icon(Icons.delete_outline, size: 16),
          label: const Text('Delete'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xffEF4444),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

  /// Resume editing a draft
  void _resumeDraft(FormDraft draft) {
    Navigator.of(context)
        .pushReplacement(
      MaterialPageRoute(
        builder: (context) => const FormBuilder(),
      ),
    )
        .then((_) {
      // The draft restoration will be handled automatically
      // by the FormBuilder's _checkForExistingDrafts method
    });
  }

  /// Delete a draft with confirmation
  void _deleteDraft(FormDraft draft) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Delete Draft',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          content: Text(
            'Are you sure you want to delete this draft? This action cannot be undone.',
            style: GoogleFonts.inter(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await _draftService.deleteDraft(draft.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Draft deleted successfully',
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to delete draft: $e',
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  }
                }
              },
              child: Text(
                'Delete',
                style: GoogleFonts.inter(
                  color: const Color(0xffEF4444),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Clean up old drafts
  void _cleanupOldDrafts() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Cleanup Old Drafts',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          content: Text(
            'This will delete all drafts older than 30 days. Continue?',
            style: GoogleFonts.inter(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await _draftService.cleanupOldDrafts();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Old drafts cleaned up successfully',
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to cleanup drafts: $e',
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  }
                }
              },
              child: Text(
                'Cleanup',
                style: GoogleFonts.inter(
                  color: const Color(0xffEF4444),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Test Firestore connection
  void _testConnection() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Testing connection...',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );

      final success = await _draftService.testConnection();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Connection successful!'
                  : 'Connection failed - check logs',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: success ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Connection test error: $e',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }
}
