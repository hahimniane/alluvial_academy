import 'dart:async';

import 'package:flutter/material.dart';

import 'package:alluwalacademyadmin/core/services/class_video_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// How often to try again while there is no estimate to count down to.
const Duration _blindRetryInterval = Duration(seconds: 15);

/// How long to keep promising a quick return before admitting we were wrong.
const Duration _overdueGrace = Duration(seconds: 20);

/// The waiting room for a class whose hub is coming back.
///
/// Two rules shape this. The countdown only ever runs toward a time the bot
/// actually published, because a number invented to look reassuring is a
/// promise nobody made. And it never sits at zero: once the moment passes this
/// says so plainly and keeps trying, rather than leaving a teacher watching
/// 0:00 and wondering whether anything is still happening.
///
/// Returns the join information once the class is reachable, or null if the
/// person stopped waiting. A refusal that is not a reconnect is returned as-is
/// so the caller can report it the way it always did.
Future<ZoomClassJoinInfo?> showClassroomReconnectingDialog({
  required BuildContext context,
  required DateTime? expectedBackAt,
  required Future<ZoomClassJoinInfo> Function() retry,
}) {
  return showDialog<ZoomClassJoinInfo>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ClassroomReconnectingDialog(
      initialExpectedBackAt: expectedBackAt,
      retry: retry,
    ),
  );
}

class _ClassroomReconnectingDialog extends StatefulWidget {
  const _ClassroomReconnectingDialog({
    required this.initialExpectedBackAt,
    required this.retry,
  });

  final DateTime? initialExpectedBackAt;
  final Future<ZoomClassJoinInfo> Function() retry;

  @override
  State<_ClassroomReconnectingDialog> createState() =>
      _ClassroomReconnectingDialogState();
}

class _ClassroomReconnectingDialogState
    extends State<_ClassroomReconnectingDialog> {
  Timer? _ticker;
  DateTime? _expectedBackAt;
  DateTime _lastAttempt = DateTime.now();
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _expectedBackAt = widget.initialExpectedBackAt;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    setState(() {});
    if (_retrying) return;
    final sinceLast = DateTime.now().difference(_lastAttempt);
    final deadline = _expectedBackAt;
    final due = deadline != null
        ? !DateTime.now().isBefore(deadline) && sinceLast.inSeconds >= 5
        : sinceLast >= _blindRetryInterval;
    if (due) _attempt();
  }

  Future<void> _attempt() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    _lastAttempt = DateTime.now();
    try {
      final result = await widget.retry();
      if (!mounted) return;
      if (result.isReconnecting) {
        // Still away — but the bot may have worked out a return time since.
        setState(() => _expectedBackAt = result.reconnectExpectedAt);
        return;
      }
      // Anything else is an answer: a class to join, or a refusal the caller
      // should show. Either way the waiting is over.
      Navigator.of(context).pop(result);
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Duration? get _remaining {
    final deadline = _expectedBackAt;
    if (deadline == null) return null;
    final left = deadline.difference(DateTime.now());
    return left.isNegative ? null : left;
  }

  bool get _overdue {
    final deadline = _expectedBackAt;
    return deadline != null &&
        DateTime.now().isAfter(deadline.add(_overdueGrace));
  }

  String _formatted(Duration remaining) {
    final seconds = remaining.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final remaining = _remaining;

    final detail = remaining != null
        ? l10n.classroomReconnectingSoon
        : _overdue
            ? l10n.classroomReconnectingOverdue
            : l10n.classroomReconnectingWaiting;

    return AlertDialog(
      title: Text(l10n.classroomReconnectingTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 4),
          if (remaining != null)
            Text(
              _formatted(remaining),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            )
          else
            const SizedBox(
              height: 36,
              width: 36,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          const SizedBox(height: 16),
          Text(detail, textAlign: TextAlign.center),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
        FilledButton(
          onPressed: _retrying ? null : _attempt,
          child: Text(l10n.tryAgain),
        ),
      ],
    );
  }
}
