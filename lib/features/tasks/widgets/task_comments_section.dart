import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/task_comment.dart';
import '../models/task.dart';
import '../services/task_comment_service.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class TaskCommentsSection extends StatefulWidget {
  final Task task;

  const TaskCommentsSection({
    super.key,
    required this.task,
  });

  @override
  State<TaskCommentsSection> createState() => _TaskCommentsSectionState();
}

class _TaskCommentsSectionState extends State<TaskCommentsSection> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  bool _isSubmitting = false;
  String? _editingCommentId;

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      if (_editingCommentId != null) {
        // Update existing comment
        await TaskCommentService.updateComment(
          commentId: _editingCommentId!,
          newComment: _commentController.text.trim(),
        );
        setState(() => _editingCommentId = null);
      } else {
        // Add new comment
        await TaskCommentService.addComment(
          taskId: widget.task.id,
          comment: _commentController.text.trim(),
          task: widget.task,
        );
      }

      _commentController.clear();
      _commentFocusNode.unfocus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editingCommentId != null 
                ? 'Comment updated successfully' 
                : 'Comment added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Log error to console for debugging
      AppLogger.error('🚨 TaskCommentsSection._submitComment() Error: $e');
      if (e is Exception) {
        AppLogger.error('🚨 Exception details: ${e.toString()}');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.commonErrorWithDetails(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _startEditing(TaskComment comment) {
    setState(() {
      _editingCommentId = comment.id;
      _commentController.text = comment.comment;
    });
    _commentFocusNode.requestFocus();
  }

  void _cancelEditing() {
    setState(() {
      _editingCommentId = null;
      _commentController.clear();
    });
    _commentFocusNode.unfocus();
  }

  Future<void> _deleteComment(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteComment),
        content: Text(AppLocalizations.of(context)!.confirmDeleteCommentMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.commonDelete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await TaskCommentService.deleteComment(commentId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.commentDeletedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        // Log error to console for debugging
        AppLogger.error('🚨 TaskCommentsSection._deleteComment() Error: $e');
        if (e is Exception) {
          AppLogger.error('🚨 Exception details: ${e.toString()}');
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!
                  .taskDeleteCommentError(e.toString())),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildCommentItem(TaskComment comment) {
    final isAuthor = FirebaseAuth.instance.currentUser?.uid == comment.authorId;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with author info and actions
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xff0386FF).withOpacity(0.1),
                child: Text(
                  comment.authorName.isNotEmpty 
                      ? comment.authorName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    color: Color(0xff0386FF),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.authorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      DateFormat('MMM dd, yyyy • hh:mm a').format(comment.createdAt),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    if (comment.isEdited)
                      Text(
                        AppLocalizations.of(context)!.edited,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              if (isAuthor) ...[
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _startEditing(comment);
                    } else if (value == 'delete') {
                      _deleteComment(comment.id);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text(AppLocalizations.of(context)!.commonEdit),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text(AppLocalizations.of(context)!.commonDelete, style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  child: Icon(
                    Icons.more_vert,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // Comment text
          Text(
            comment.comment,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
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
          if (_editingCommentId != null) ...[
            Row(
              children: [
                Icon(Icons.edit, size: 16, color: Colors.orange[600]),
                SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.editingComment,
                  style: TextStyle(
                    color: Colors.orange[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _cancelEditing,
                  child: Text(AppLocalizations.of(context)!.commonCancel),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _commentController,
            focusNode: _commentFocusNode,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: _editingCommentId != null 
                  ? 'Edit your comment...'
                  : 'Leave a comment...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xff0386FF), width: 2),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitComment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff0386FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(_editingCommentId != null ? 'Update' : 'Post Comment'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            const Icon(
              Icons.comment_outlined,
              size: 20,
              color: Color(0xff0386FF),
            ),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)!.comments,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A202C),
              ),
            ),
            const Spacer(),
            StreamBuilder<List<TaskComment>>(
              stream: TaskCommentService.getTaskComments(widget.task.id),
              builder: (context, snapshot) {
                final commentCount = snapshot.data?.length ?? 0;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xff0386FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    commentCount.toString(),
                    style: const TextStyle(
                      color: Color(0xff0386FF),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Comment input
        _buildCommentInput(),
        const SizedBox(height: 20),
        
        // Comments list
        StreamBuilder<List<TaskComment>>(
          stream: TaskCommentService.getTaskComments(widget.task.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              // Log error to console for debugging
              AppLogger.error('🚨 TaskCommentsSection StreamBuilder Error: ${snapshot.error}');
              if (snapshot.error is Exception) {
                AppLogger.error('🚨 Exception details: ${snapshot.error.toString()}');
              }
              if (snapshot.stackTrace != null) {
                AppLogger.debug('🚨 Stack trace: ${snapshot.stackTrace}');
              }
              
              return Center(
                child: Text(
                  'Error loading comments: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            final comments = snapshot.data ?? [];

            if (comments.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.comment_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.noCommentsYet,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.beTheFirstToLeaveA,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: comments.map(_buildCommentItem).toList(),
            );
          },
        ),
      ],
    );
  }
}
