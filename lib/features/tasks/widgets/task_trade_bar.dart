import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/app_logger.dart';
import '../models/task_trade_offer.dart';
import '../services/task_trade_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

const Color _tradeColor = Color(0xFF7C3AED);

/// The small "Offered" tag shown on a task that is on offer.
class TaskOfferedChip extends StatelessWidget {
  const TaskOfferedChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _tradeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.swap_horiz, size: 12, color: _tradeColor),
          const SizedBox(width: 3),
          Text(
            AppLocalizations.of(context)!.taskTradeOfferedChip,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: _tradeColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// What a failed hand-over says to the person, in their language.
String taskTradeFailureMessage(AppLocalizations l10n, Object error) {
  if (error is TaskTradeException) {
    switch (error.failure) {
      case TaskTradeFailure.noLongerOffered:
        return l10n.taskTradeNoLongerOffered;
      case TaskTradeFailure.notOpen:
        return l10n.taskTradeNotOpen;
      case TaskTradeFailure.notAssigned:
        return l10n.taskTradeNotAssigned;
      case TaskTradeFailure.notFound:
        return l10n.taskTradeNotFound;
    }
  }
  return l10n.taskTradeFailed;
}

/// Asks before a leader takes over someone else's task. True when they agree.
Future<bool> confirmTakeTask(
  BuildContext context, {
  required String taskTitle,
  required String offererName,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        l10n.taskTradeTake,
        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      content: Text(
        offererName.isEmpty
            ? l10n.taskTradeTakeConfirm(taskTitle)
            : l10n.taskTradeTakeConfirmFrom(taskTitle, offererName),
        style: GoogleFonts.inter(fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.commonCancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: _tradeColor,
            foregroundColor: Colors.white,
          ),
          child: Text(l10n.taskTradeTake),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// The trading strip under a task's details. Everyone who can open the task
/// sees that it is offered and by whom; a leader also gets the action that
/// fits: offer it, take the offer back, or take the task.
class TaskTradeBar extends StatefulWidget {
  final String taskId;
  final String taskTitle;

  /// Only leaders (admins) can write tasks, so only they get the actions.
  final bool isLeader;

  /// Called once the task has changed hands, so the caller can close the
  /// details it was showing.
  final VoidCallback? onTaken;

  const TaskTradeBar({
    super.key,
    required this.taskId,
    required this.taskTitle,
    required this.isLeader,
    this.onTaken,
  });

  @override
  State<TaskTradeBar> createState() => _TaskTradeBarState();
}

class _TaskTradeBarState extends State<TaskTradeBar> {
  late final Stream<TaskTradeState?> _stream =
      TaskTradeService.watchTask(widget.taskId);
  bool _busy = false;

  Future<void> _run(
    Future<void> Function() action, {
    required String Function(AppLocalizations l10n) success,
    bool taken = false,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      messenger.showSnackBar(
        SnackBar(
          content: Text(success(l10n)),
          backgroundColor: Colors.green,
        ),
      );
      // If the details were closed meanwhile there is nothing left to close.
      if (taken && mounted) widget.onTaken?.call();
    } catch (e) {
      AppLogger.error('TaskTradeBar: $e');
      messenger.showSnackBar(
        SnackBar(
          content: Text(taskTradeFailureMessage(l10n, e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _take(TaskTradeOffer offer) async {
    final l10n = AppLocalizations.of(context)!;
    final agreed = await confirmTakeTask(
      context,
      taskTitle: widget.taskTitle,
      offererName: offer.offeredByName,
    );
    if (!agreed || !mounted) return;
    await _run(
      () => TaskTradeService.takeTask(
        widget.taskId,
        commentFor: l10n.taskTradeTookComment,
      ),
      success: (l10n) => l10n.taskTradeTaken,
      taken: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<TaskTradeState?>(
      stream: _stream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state == null) return const SizedBox.shrink();

        final offer = state.offer;
        final canOffer = state.canOffer(uid: uid, isLeader: widget.isLeader);
        if (offer == null && !canOffer) return const SizedBox.shrink();

        Widget? action;
        if (canOffer) {
          action = TextButton.icon(
            onPressed: _busy
                ? null
                : () => _run(
                      () => TaskTradeService.offerTask(widget.taskId),
                      success: (l10n) => l10n.taskTradeOfferPosted,
                    ),
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: Text(l10n.taskTradeOffer),
            style: TextButton.styleFrom(foregroundColor: _tradeColor),
          );
        } else if (state.canWithdraw(uid: uid, isLeader: widget.isLeader)) {
          action = TextButton(
            onPressed: _busy
                ? null
                : () => _run(
                      () => TaskTradeService.withdrawOffer(widget.taskId),
                      success: (l10n) => l10n.taskTradeOfferTakenBack,
                    ),
            style: TextButton.styleFrom(foregroundColor: _tradeColor),
            child: Text(l10n.taskTradeTakeBack),
          );
        } else if (offer != null &&
            state.canTake(uid: uid, isLeader: widget.isLeader)) {
          action = ElevatedButton(
            onPressed: _busy ? null : () => _take(offer),
            style: ElevatedButton.styleFrom(
              backgroundColor: _tradeColor,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(l10n.taskTradeTake),
          );
        }

        final String? caption;
        if (offer == null) {
          caption = null;
        } else if (offer.offeredBy == uid) {
          caption = l10n.taskTradeOfferedByYou;
        } else if (offer.offeredByName.isNotEmpty) {
          caption = l10n.taskTradeOfferedBy(offer.offeredByName);
        } else {
          caption = l10n.taskTradeOfferedToLeaders;
        }

        return Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              if (offer != null) ...[
                const TaskOfferedChip(),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: caption == null
                    ? const SizedBox.shrink()
                    : Text(
                        caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF475569),
                        ),
                      ),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (action != null)
                action,
            ],
          ),
        );
      },
    );
  }
}
