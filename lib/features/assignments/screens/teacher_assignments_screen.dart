import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:file_picker/file_picker.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:universal_html/html.dart' as html; // for web file handling
import '../services/assignment_file_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class TeacherAssignmentsScreen extends StatefulWidget {
  const TeacherAssignmentsScreen({super.key});

  @override
  State<TeacherAssignmentsScreen> createState() => _TeacherAssignmentsScreenState();
}

class _TeacherAssignmentsScreenState extends State<TeacherAssignmentsScreen> {
  List<Map<String, dynamic>> _assignments = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMyAssignments();
  }

  Future<void> _loadMyAssignments() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        AppLogger.error('No authenticated user found');
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      AppLogger.debug('Loading assignments for teacher: ${user.uid}');

      var query = FirebaseFirestore.instance
          .collection('assignments')
          .where('teacher_id', isEqualTo: user.uid);

      try {
        final assignmentsSnapshot =
            await query.orderBy('created_at', descending: true).get();

        AppLogger.debug('Found ${assignmentsSnapshot.docs.length} assignments with orderBy');

        List<Map<String, dynamic>> assignments = [];
        for (var doc in assignmentsSnapshot.docs) {
          final data = doc.data();
          AppLogger.debug('Assignment: ${doc.id} - ${data['title']}');
          assignments.add({
            'id': doc.id,
            ...data,
          });
        }

        if (mounted) {
          setState(() {
            _assignments = assignments;
            _isLoading = false;
          });
          AppLogger.debug('Loaded ${assignments.length} assignments successfully');
        }
      } catch (orderError) {
        if (orderError is FirebaseException && orderError.code == 'permission-denied') {
          rethrow;
        }
        AppLogger.error('OrderBy failed, trying without order: $orderError');
        
        // Fallback: load without ordering
        final assignmentsSnapshot = await query.get();

        AppLogger.debug('Found ${assignmentsSnapshot.docs.length} assignments without orderBy');

        List<Map<String, dynamic>> assignments = [];
        for (var doc in assignmentsSnapshot.docs) {
          final data = doc.data();
          AppLogger.debug('Assignment: ${doc.id} - ${data['title']}');
          assignments.add({
            'id': doc.id,
            ...data,
          });
        }

        // Sort manually
        assignments.sort((a, b) {
          final aCreated = a['created_at'] as Timestamp?;
          final bCreated = b['created_at'] as Timestamp?;
          if (aCreated == null || bCreated == null) return 0;
          return bCreated.compareTo(aCreated);
        });

        if (mounted) {
          setState(() {
            _assignments = assignments;
            _isLoading = false;
          });
          AppLogger.debug('Loaded ${assignments.length} assignments successfully (fallback)');
        }
      }
    } catch (e) {
      AppLogger.error('Error loading assignments: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        final message = e is FirebaseException && e.code == 'permission-denied'
            ? 'You do not have permission to load assignments.'
            : 'Failed to load assignments: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Open/download file from URL
  Future<void> _openFile(String url, String fileName) async {
    try {
      // Check if URL is a valid HTTP(S) URL
      if (url.isEmpty || 
          (!url.startsWith('http://') && !url.startsWith('https://')) ||
          url.contains('example.com') ||
          url.startsWith('/storage/') ||
          url.startsWith('file://')) {
        // This is a placeholder URL or local path - file hasn't been uploaded to Firebase Storage yet
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(children: [
                  Icon(Icons.info_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.thisFileWasNotUploadedTo,
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      final uri = Uri.parse(url);
      
      // Validate URI
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        throw Exception('Invalid URL format');
      }

      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // Try external application first (better for downloads)
      try {
        final launched = await launchUrl(
          uri, 
          mode: LaunchMode.externalApplication,
        );
        
        if (mounted) Navigator.pop(context); // Close loading
        
        if (!launched && mounted) {
          // Try in-app web view as fallback
          await launchUrl(uri, mode: LaunchMode.inAppWebView);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(AppLocalizations.of(context)!.openingFilename),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (launchError) {
        if (mounted) Navigator.pop(context); // Close loading
        AppLogger.error('Error launching URL: $launchError');
        // Try in-app web view as fallback
        try {
          await launchUrl(uri, mode: LaunchMode.inAppWebView);
        } catch (fallbackError) {
          throw Exception('Could not open URL: $fallbackError');
        }
      }
    } catch (e) {
      if (mounted) {
        // Close loading if still open
        try {
          Navigator.pop(context);
        } catch (_) {}
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(AppLocalizations.of(context)!
                      .assignmentErrorOpeningFile(e.toString())),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      AppLogger.error('Error opening file: $e');
    }
  }

  // Get file icon based on file name
  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
        return Icons.audio_file;
      default:
        return Icons.attach_file;
    }
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatDueDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Tomorrow';
    } else if (difference.inDays < 7 && difference.inDays > 0) {
      return 'In ${difference.inDays} days';
    } else if (difference.inDays < 0) {
      final pastDays = difference.inDays.abs();
      return 'Overdue (${pastDays == 1 ? "1 day" : "$pastDays days"})';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Color _getDueDateColor(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.inDays < 0) return Colors.red;
    if (difference.inDays <= 1) return Colors.orange;
    if (difference.inDays <= 3) return Colors.amber[700]!;
    return const Color(0xff6B7280);
  }

  bool _isOverdue(Timestamp timestamp) {
    return timestamp.toDate().isBefore(DateTime.now());
  }

  void _showCreateEditDialog([Map<String, dynamic>? assignment]) {
    showDialog(
      context: context,
      builder: (context) => _AssignmentDialog(
        existingAssignment: assignment,
        onAssignmentCreated: _loadMyAssignments,
      ),
    );
  }

  void _deleteAssignment(Map<String, dynamic> assignment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteAssignment, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text(AppLocalizations.of(context)!
            .assignmentDeleteConfirm(assignment['title'])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('assignments')
                    .doc(assignment['id'])
                    .delete();
                if (mounted) {
                  Navigator.pop(context);
                  _loadMyAssignments();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.assignmentDeleted), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.errorE), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(AppLocalizations.of(context)!.commonDelete),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context)!.myAssignments,
          style: GoogleFonts.inter(
            color: const Color(0xff1E293B),
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xff64748B)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Color(0xff0386FF)),
            onPressed: () => _showCreateEditDialog(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMyAssignments,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _assignments.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _assignments.length,
                    itemBuilder: (context, index) => _buildAssignmentCard(_assignments[index]),
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateEditDialog(),
        backgroundColor: const Color(0xff0386FF),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.noAssignmentsYet,
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xff6B7280)),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.createYourFirstAssignmentToGet,
            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xff9CA3AF)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateEditDialog(),
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.of(context)!.createAssignment),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff0386FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () async {
              // Debug: Check assignments visible to this teacher
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) {
                  throw Exception('User not authenticated');
                }

                final allAssignments = await FirebaseFirestore.instance
                    .collection('assignments')
                    .where('teacher_id', isEqualTo: user.uid)
                    .limit(10)
                    .get();

                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(AppLocalizations.of(context)!.debugInfo),
                      content: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(AppLocalizations.of(context)!
                                .assignmentLoadedCount(allAssignments.docs.length)),
                            Text(AppLocalizations.of(context)!
                                .assignmentUserId(user.uid)),
                            const SizedBox(height: 16),
                            if (allAssignments.docs.isNotEmpty) ...[
                              Text(AppLocalizations.of(context)!.sampleAssignments, style: TextStyle(fontWeight: FontWeight.bold)),
                              ...allAssignments.docs.take(3).map((doc) {
                                final data = doc.data();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(AppLocalizations.of(context)!
                                          .assignmentDocId(doc.id)),
                                      Text(AppLocalizations.of(context)!
                                          .assignmentTitle(
                                              data['title'] ??
                                                  AppLocalizations.of(context)!
                                                      .commonNotAvailable)),
                                      Text(AppLocalizations.of(context)!
                                          .assignmentTeacherId(
                                              data['teacher_id'] ??
                                                  AppLocalizations.of(context)!
                                                      .commonNotAvailable)),
                                      const Divider(),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(AppLocalizations.of(context)!.commonClose),
                        ),
                      ],
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.debugErrorE), backgroundColor: Colors.red),
                  );
                }
              }
            },
            icon: const Icon(Icons.bug_report, size: 16),
            label: Text(AppLocalizations.of(context)!.debugCheckMyAssignments),
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  void _showAssignmentDetails(Map<String, dynamic> assignment) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        assignment['title'] ?? 'Untitled Assignment',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xff1E293B),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (assignment['description'] != null && (assignment['description'] as String).isNotEmpty) ...[
                  Text(
                    AppLocalizations.of(context)!.description,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    assignment['description'],
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xff374151),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (assignment['due_date'] != null) ...[
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Due: ${_formatDueDate(assignment['due_date'] as Timestamp)}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xff374151),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Icon(Icons.people, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Assigned to: ${(assignment['assigned_to'] as List?)?.length ?? 0} students',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xff374151),
                      ),
                    ),
                  ],
                ),
                if (assignment['attachments'] != null && (assignment['attachments'] as List).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.attachedFiles,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...(assignment['attachments'] as List).map<Widget>((attachment) {
                    final attachmentMap = attachment as Map<String, dynamic>;
                    final fileName = attachmentMap['name'] ??
                        attachmentMap['originalName'] ??
                        AppLocalizations.of(context)!.commonUnknownFile;
                    final downloadUrl = attachmentMap['downloadURL'] ?? attachmentMap['url'] ?? '';
                    // Check if URL is valid (not placeholder or local path)
                    final isValidUrl = downloadUrl.isNotEmpty && 
                        (downloadUrl.startsWith('http://') || downloadUrl.startsWith('https://')) &&
                        !downloadUrl.contains('example.com') &&
                        !downloadUrl.startsWith('/storage/') &&
                        !downloadUrl.startsWith('file://');
                    
                    // Format file size
                    final fileSize = attachmentMap['size'] as int? ?? 0;
                    final sizeText = fileSize > 0 
                        ? (fileSize < 1024 
                            ? '${fileSize}B' 
                            : fileSize < 1024 * 1024 
                                ? '${(fileSize / 1024).toStringAsFixed(1)}KB'
                                : '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB')
                        : '';
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xff3B82F6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(_getFileIcon(fileName), color: const Color(0xff3B82F6), size: 24),
                        ),
                        title: Text(
                          fileName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: sizeText.isNotEmpty
                            ? Text(
                                sizeText,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              )
                            : null,
                        trailing: isValidUrl
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.visibility, color: Color(0xff3B82F6)),
                                    tooltip: AppLocalizations.of(context)!.viewFile,
                                    onPressed: () => _openFile(downloadUrl, fileName),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.download, color: Color(0xff3B82F6)),
                                    tooltip: AppLocalizations.of(context)!.downloadFile,
                                    onPressed: () => _openFile(downloadUrl, fileName),
                                  ),
                                ],
                              )
                            : Tooltip(
                                message: AppLocalizations.of(context)!.fileNotUploadedToStorage,
                                child: Icon(Icons.error_outline, color: Colors.orange.shade700),
                              ),
                        onTap: isValidUrl ? () => _openFile(downloadUrl, fileName) : null,
                      ),
                    );
                  }).toList(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> assignment) {
    final title = assignment['title'] ?? 'Untitled Assignment';
    final description = assignment['description'] ?? '';
    final assignedTo = List<String>.from(assignment['assigned_to'] ?? []);
    final createdAt = assignment['created_at'] as Timestamp?;
    final dueDate = assignment['due_date'] as Timestamp?;
    final isOverdue = dueDate != null && _isOverdue(dueDate);

    return GestureDetector(
      onTap: () => _showAssignmentDetails(assignment),
      child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isOverdue ? Colors.red.withOpacity(0.3) : const Color(0xffE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xff111827)),
                      ),
                    ),
                    if (isOverdue) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                        child: Text(AppLocalizations.of(context)!.overdue, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') _showCreateEditDialog(assignment);
                  if (value == 'delete') _deleteAssignment(assignment);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text(AppLocalizations.of(context)!.commonEdit)])),
                  PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text(AppLocalizations.of(context)!.commonDelete, style: TextStyle(color: Colors.red))])),
                ],
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xff6B7280)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    AppLocalizations.of(context)!
                        .assignmentStudentsCount(assignedTo.length),
                    style: GoogleFonts.inter(
                        fontSize: 11, color: const Color(0xff6B7280)),
                  ),
                ],
              ),
              if (dueDate != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule, size: 14, color: _getDueDateColor(dueDate)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Due: ${_formatDueDate(dueDate)}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: _getDueDateColor(dueDate),
                          fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              if (createdAt != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Created: ${_formatDate(createdAt)}',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xff6B7280)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (assignment['attachments'] != null && (assignment['attachments'] as List).isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xffE5E7EB)),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context)!.attachedFiles, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xff374151))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (assignment['attachments'] as List).map<Widget>((attachment) {
                final attachmentMap = attachment as Map<String, dynamic>;
                final fileName = attachmentMap['name'] ??
                    attachmentMap['originalName'] ??
                    AppLocalizations.of(context)!.commonUnknownFile;
                final downloadUrl = attachmentMap['downloadURL'] ?? attachmentMap['url'] ?? '';
                // Check if URL is valid (not placeholder or local path)
                final isValidUrl = downloadUrl.isNotEmpty && 
                    (downloadUrl.startsWith('http://') || downloadUrl.startsWith('https://')) &&
                    !downloadUrl.contains('example.com') &&
                    !downloadUrl.startsWith('/storage/') &&
                    !downloadUrl.startsWith('file://');
                return InkWell(
                  onTap: isValidUrl ? () => _openFile(downloadUrl, fileName) : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isValidUrl 
                          ? const Color(0xff3B82F6).withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isValidUrl 
                            ? const Color(0xff3B82F6).withOpacity(0.3)
                            : Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getFileIcon(fileName), 
                          size: 16, 
                          color: isValidUrl ? const Color(0xff3B82F6) : Colors.orange.shade700,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            fileName, 
                            style: GoogleFonts.inter(
                              fontSize: 12, 
                              color: const Color(0xff374151), 
                              fontWeight: FontWeight.w500,
                            ), 
                            maxLines: 1, 
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isValidUrl) ...[
                          const SizedBox(width: 4), 
                          const Icon(Icons.download, size: 14, color: Color(0xff3B82F6)),
                        ] else ...[
                          const SizedBox(width: 4),
                          Icon(Icons.error_outline, size: 14, color: Colors.orange.shade700),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
      ),
    );
  }
}

// Dialog for creating/editing assignments
class _AssignmentDialog extends StatefulWidget {
  final VoidCallback? onAssignmentCreated;
  final Map<String, dynamic>? existingAssignment;

  const _AssignmentDialog({this.onAssignmentCreated, this.existingAssignment});

  @override
  _AssignmentDialogState createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<_AssignmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dueDateController = TextEditingController();

  List<String> _selectedStudents = [];
  List<Map<String, dynamic>> _myStudents = [];
  List<Map<String, dynamic>> _attachments = [];
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isUploadingFile = false;
  DateTime? _selectedDueDate;

  @override
  void initState() {
    super.initState();
    _loadMyStudents();
    _loadExistingAssignment();
  }

  void _loadExistingAssignment() {
    if (widget.existingAssignment != null) {
      final assignment = widget.existingAssignment!;
      _titleController.text = assignment['title'] ?? '';
      _descriptionController.text = assignment['description'] ?? '';
      if (assignment['due_date'] != null) {
        final dueDate = (assignment['due_date'] as Timestamp).toDate();
        _selectedDueDate = dueDate;
        _dueDateController.text = '${dueDate.day}/${dueDate.month}/${dueDate.year}';
      }
      _selectedStudents = List<String>.from(assignment['assigned_to'] ?? []);
      if (assignment['attachments'] != null) {
        _attachments = List<Map<String, dynamic>>.from(assignment['attachments']);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  Future<void> _loadMyStudents() async {
    setState(() => _isLoading = true);
    try {
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').where('user_type', isEqualTo: 'student').get();
      List<Map<String, dynamic>> students = [];
      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        String displayName = AppLocalizations.of(context)!.commonUnknown;
        if (data['first_name'] != null && data['last_name'] != null) {
          displayName = '${data['first_name']} ${data['last_name']}';
        } else if (data['name'] != null) {
          displayName = data['name'];
        }
        students.add({'id': doc.id, 'name': displayName});
      }
      students.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
      setState(() {
        _myStudents = students;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addAttachment() async {
    setState(() => _isUploadingFile = true);

    try {
      // Generate a temporary assignment ID for new assignments
      // If editing, use existing assignment ID
      final tempAssignmentId = widget.existingAssignment?['id'] ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
      
      if (kIsWeb) {
        // Create a file input element for web
        final html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
        uploadInput.multiple = false;
        uploadInput.accept = '.pdf,.doc,.docx,.txt,.jpg,.jpeg,.png,.gif,.mp4,.mp3,.ppt,.pptx,.xls,.xlsx';

        // Trigger file picker
        uploadInput.click();

        // Wait for file selection
        await uploadInput.onChange.first;

        if (uploadInput.files!.isNotEmpty) {
          final file = uploadInput.files!.first;
          
          // Show upload progress
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(AppLocalizations.of(context)!
                          .assignmentUploadingFile(file.name)),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xff0386FF),
                duration: const Duration(seconds: 30),
              ),
            );
          }

          // Upload to Firebase Storage
          final attachment = await AssignmentFileService.uploadFile(file, tempAssignmentId);

          setState(() {
            _attachments.add(attachment);
          });

          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(AppLocalizations.of(context)!
                          .assignmentUploadSuccess(file.name)),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xff10B981),
              ),
            );
          }
        }
      } else {
        // Mobile: Use file_picker package
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png', 'gif', 'mp4', 'mp3', 'ppt', 'pptx', 'xls', 'xlsx'],
          allowMultiple: false,
          withData: true, // Get file bytes for upload
        );

        if (result != null && result.files.isNotEmpty) {
          final file = result.files.first;
          
          // Show upload progress
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(AppLocalizations.of(context)!
                          .assignmentUploadingFile(file.name)),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xff0386FF),
                duration: const Duration(seconds: 30),
              ),
            );
          }

          // Upload to Firebase Storage
          final attachment = await AssignmentFileService.uploadFile(file, tempAssignmentId);

          setState(() {
            _attachments.add(attachment);
          });

          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(AppLocalizations.of(context)!
                          .assignmentUploadSuccess(file.name)),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xff10B981),
              ),
            );
          }
        } else {
          // User cancelled file picker
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.fileSelectionCancelled),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      AppLogger.error('Error adding attachment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(AppLocalizations.of(context)!
                      .assignmentUploadError(e.toString())),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingFile = false);
      }
    }
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'doc': case 'docx': return Icons.description;
      case 'jpg': case 'png': return Icons.image;
      default: return Icons.attach_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _saveAssignment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.pleaseSelectAtLeastOneStudent), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final assignmentData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'due_date': _selectedDueDate != null ? Timestamp.fromDate(_selectedDueDate!) : null,
        'assigned_to': _selectedStudents,
        'teacher_id': user.uid,
        'teacher_email': user.email,
        'attachments': _attachments,
        'status': 'active',
        'type': 'assignment',
        'updated_at': FieldValue.serverTimestamp(),
      };

      DocumentReference? docRef;
      
      if (widget.existingAssignment != null) {
        AppLogger.debug('Updating assignment: ${widget.existingAssignment!['id']}');
        await FirebaseFirestore.instance
            .collection('assignments')
            .doc(widget.existingAssignment!['id'])
            .update(assignmentData);
        AppLogger.debug('Assignment updated successfully');
      } else {
        assignmentData['created_at'] = FieldValue.serverTimestamp();
        AppLogger.debug('Creating new assignment...');
        docRef = await FirebaseFirestore.instance
            .collection('assignments')
            .add(assignmentData);
        AppLogger.debug('Assignment created with ID: ${docRef.id}');
      }

      if (mounted) {
        Navigator.pop(context);
        
        // Call the callback to refresh the list
        if (widget.onAssignmentCreated != null) {
          AppLogger.debug('Calling onAssignmentCreated callback');
          widget.onAssignmentCreated!();
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  widget.existingAssignment != null
                      ? 'Assignment updated successfully!'
                      : 'Assignment created successfully!',
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorE), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.existingAssignment != null ? 'Edit Assignment' : 'Create Assignment',
                  style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.profileTitle, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.description, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dueDateController,
                  readOnly: true,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.dueDate, suffixIcon: Icon(Icons.calendar_today), border: OutlineInputBorder()),
                  onTap: () async {
                    final date = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 7)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (date != null) {
                      setState(() {
                        _selectedDueDate = date;
                        _dueDateController.text = '${date.day}/${date.month}/${date.year}';
                      });
                    }
                  },
                ),
                SizedBox(height: 16),
                Text(AppLocalizations.of(context)!.assignTo, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                if (_isLoading) const CircularProgressIndicator() else Container(
                  height: 150,
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                  child: ListView(
                    children: _myStudents.map((s) => CheckboxListTile(
                      title: Text(s['name']),
                      value: _selectedStudents.contains(s['name']),
                      onChanged: (v) => setState(() => v! ? _selectedStudents.add(s['name']) : _selectedStudents.remove(s['name'])),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(AppLocalizations.of(context)!.attachments),
                    const Spacer(),
                    TextButton.icon(onPressed: _isUploadingFile ? null : _addAttachment, icon: const Icon(Icons.attach_file), label: Text(_isUploadingFile ? 'Uploading...' : 'Add File')),
                  ],
                ),
                if (_attachments.isNotEmpty) ..._attachments.map((a) => ListTile(
                  leading: Icon(_getFileIcon(a['name'])),
                  title: Text(a['name']),
                  subtitle: Text(_formatFileSize(a['size'])),
                  trailing: IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => _attachments.remove(a))),
                )),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context)!.commonCancel)),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveAssignment,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff06B6D4), foregroundColor: Colors.white),
                      child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : Text(widget.existingAssignment != null ? 'Update' : 'Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
