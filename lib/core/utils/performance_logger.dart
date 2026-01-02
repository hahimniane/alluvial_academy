import 'package:flutter/foundation.dart';
import 'dart:collection';

import 'app_logger.dart';

enum PerfLogLabel {
  start,
  checkpoint,
  end,
}

class PerfLogEntry {
  final DateTime timestamp;
  final PerfLogLabel label;
  final String operationId;
  final String? checkpointName;
  final Duration duration;
  final String speed;
  final Map<String, dynamic> metadata;

  const PerfLogEntry({
    required this.timestamp,
    required this.label,
    required this.operationId,
    required this.checkpointName,
    required this.duration,
    required this.speed,
    required this.metadata,
  });

  String get labelText {
    switch (label) {
      case PerfLogLabel.start:
        return 'START';
      case PerfLogLabel.checkpoint:
        return 'CHECKPOINT';
      case PerfLogLabel.end:
        return 'END';
    }
  }
}

class PerformanceLogger {
  static bool enabled = kDebugMode;
  static bool captureEnabled = true;

  static Duration moderateThreshold = const Duration(milliseconds: 500);
  static Duration slowThreshold = const Duration(milliseconds: 1000);

  static final Map<String, _PerfOperation> _operations = {};

  static int maxLogEntries = 1000;
  static final List<PerfLogEntry> _logEntries = <PerfLogEntry>[];
  static final ValueNotifier<int> logRevision = ValueNotifier<int>(0);

  static UnmodifiableListView<PerfLogEntry> get entries =>
      UnmodifiableListView(_logEntries);

  static void clearLogs() {
    try {
      _logEntries.clear();
      logRevision.value++;
    } catch (e) {
      AppLogger.warning('⏱️ [PERF] Failed to clear logs: $e');
    }
  }

  static String newOperationId(String base) {
    final ts = DateTime.now().microsecondsSinceEpoch;
    return '${base}_$ts';
  }

  static void startTimer(
    String operationId, {
    Map<String, dynamic>? metadata,
  }) {
    if (!enabled) return;
    try {
      final existing = _operations.remove(operationId);
      existing?.stopwatch.stop();

      final op = _PerfOperation(
        id: operationId,
        stopwatch: Stopwatch()..start(),
        lastCheckpointMs: 0,
      );
      _operations[operationId] = op;

      _log(
        label: PerfLogLabel.start,
        operationId: operationId,
        checkpointName: null,
        duration: Duration.zero,
        metadata: metadata,
        forceDebug: true,
      );
    } catch (e) {
      AppLogger.warning('⏱️ [PERF] Failed to start timer: $e');
    }
  }

  static void checkpoint(
    String operationId,
    String checkpointName, {
    Map<String, dynamic>? metadata,
  }) {
    if (!enabled) return;
    try {
      final op = _operations[operationId];
      if (op == null) {
        AppLogger.warning(
            '⏱️ [PERF] CHECKPOINT missing timer: $operationId -> $checkpointName');
        return;
      }

      final elapsedMs = op.stopwatch.elapsedMilliseconds;
      final deltaMs = elapsedMs - op.lastCheckpointMs;
      op.lastCheckpointMs = elapsedMs;

      final merged = <String, dynamic>{
        if (metadata != null) ...metadata,
        'elapsed_ms': elapsedMs,
        'delta_ms': deltaMs,
      };

      _log(
        label: PerfLogLabel.checkpoint,
        operationId: operationId,
        checkpointName: checkpointName,
        duration: Duration(milliseconds: elapsedMs),
        metadata: merged,
        forceDebug: true,
      );
    } catch (e) {
      AppLogger.warning('⏱️ [PERF] Failed checkpoint: $e');
    }
  }

  static void endTimer(
    String operationId, {
    Map<String, dynamic>? metadata,
  }) {
    if (!enabled) return;
    try {
      final op = _operations.remove(operationId);
      if (op == null) {
        AppLogger.warning('⏱️ [PERF] END missing timer: $operationId');
        return;
      }

      op.stopwatch.stop();
      final duration = op.stopwatch.elapsed;

      _log(
        label: PerfLogLabel.end,
        operationId: operationId,
        checkpointName: null,
        duration: duration,
        metadata: metadata,
      );
    } catch (e) {
      AppLogger.warning('⏱️ [PERF] Failed to end timer: $e');
    }
  }

  static Future<T> measure<T>(
    String operationId,
    Future<T> Function() operation, {
    Map<String, dynamic>? metadata,
  }) async {
    if (!enabled) {
      return operation();
    }

    startTimer(operationId, metadata: metadata);
    try {
      final result = await operation();
      endTimer(operationId, metadata: metadata);
      return result;
    } catch (e) {
      endTimer(operationId, metadata: {
        if (metadata != null) ...metadata,
        'error': e.toString(),
      });
      rethrow;
    }
  }

  static Future<T> measureFirestoreQuery<T>(
    String queryName,
    Future<T> Function() query, {
    Map<String, dynamic>? metadata,
  }) {
    final opId = newOperationId('firestore:$queryName');
    return measure<T>(
      opId,
      query,
      metadata: metadata,
    );
  }

  static void _log({
    required PerfLogLabel label,
    required String operationId,
    required String? checkpointName,
    required Duration duration,
    Map<String, dynamic>? metadata,
    bool forceDebug = false,
  }) {
    final speed = _speedLabel(duration);
    final safeMetadata = _safeMetadata(metadata);
    final meta = _formatMetadata(safeMetadata);

    final durationMs = duration.inMilliseconds;
    final durationText = durationMs >= 1000
        ? '${(durationMs / 1000).toStringAsFixed(2)}s'
        : '${durationMs}ms';

    final displayId = (label == PerfLogLabel.checkpoint &&
            checkpointName != null &&
            checkpointName.trim().isNotEmpty)
        ? '$operationId -> $checkpointName'
        : operationId;
    final message =
        '⏱️ [PERF] ${_labelText(label)}: $displayId ${label == PerfLogLabel.start ? '' : 'took $durationText'} [$speed]$meta';

    _capture(
      PerfLogEntry(
        timestamp: DateTime.now(),
        label: label,
        operationId: operationId,
        checkpointName: checkpointName,
        duration: duration,
        speed: speed,
        metadata: safeMetadata,
      ),
    );

    if (forceDebug) {
      AppLogger.debug(message);
      return;
    }

    if (duration >= slowThreshold) {
      AppLogger.error(message);
    } else if (duration >= moderateThreshold) {
      AppLogger.warning(message);
    } else {
      AppLogger.debug(message);
    }
  }

  static String _labelText(PerfLogLabel label) {
    switch (label) {
      case PerfLogLabel.start:
        return 'START';
      case PerfLogLabel.checkpoint:
        return 'CHECKPOINT';
      case PerfLogLabel.end:
        return 'END';
    }
  }

  static String _speedLabel(Duration duration) {
    if (duration >= slowThreshold) return 'SLOW';
    if (duration >= moderateThreshold) return 'MODERATE';
    return 'FAST';
  }

  static Map<String, dynamic> _safeMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null || metadata.isEmpty) return const <String, dynamic>{};
    try {
      return Map<String, dynamic>.unmodifiable(
          Map<String, dynamic>.from(metadata));
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  static String _formatMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null || metadata.isEmpty) return '';
    try {
      final parts = metadata.entries.map((e) {
        final key = e.key;
        final value = e.value;
        final stringValue = value is String ? value : value.toString();
        return '$key=$stringValue';
      }).toList();
      return ' | ${parts.join(', ')}';
    } catch (_) {
      return '';
    }
  }

  static void _capture(PerfLogEntry entry) {
    if (!enabled || !captureEnabled) return;
    try {
      _logEntries.add(entry);
      final overflow = _logEntries.length - maxLogEntries;
      if (overflow > 0) {
        _logEntries.removeRange(0, overflow);
      }
      logRevision.value++;
    } catch (e) {
      AppLogger.warning('⏱️ [PERF] Failed to capture log: $e');
    }
  }
}

class _PerfOperation {
  final String id;
  final Stopwatch stopwatch;
  int lastCheckpointMs;

  _PerfOperation({
    required this.id,
    required this.stopwatch,
    required this.lastCheckpointMs,
  });
}
