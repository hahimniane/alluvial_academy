import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:livekit_client/livekit_client.dart';

import 'package:alluwalacademyadmin/core/constants/build_info.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/core/utils/web_runtime_info.dart'
    as web_runtime;

/// Canonical category keys for in-call issue reports. Stored verbatim in
/// Firestore and used to look up localized labels at the UI layer.
class CallIssueCategory {
  static const String audioCantHearOthers = 'audio_cant_hear_others';
  static const String audioOthersCantHearMe = 'audio_others_cant_hear_me';
  static const String audioChoppyOrEcho = 'audio_choppy_or_echo';
  static const String videoCantSeeOthers = 'video_cant_see_others';
  static const String videoOthersCantSeeMe = 'video_others_cant_see_me';
  static const String videoFrozenOrLaggy = 'video_frozen_or_laggy';
  static const String gotDisconnected = 'got_disconnected';
  static const String screenShareIssue = 'screen_share_issue';
  static const String whiteboardOrChatIssue = 'whiteboard_or_chat_issue';
  static const String other = 'other';

  static const List<String> all = [
    audioCantHearOthers,
    audioOthersCantHearMe,
    audioChoppyOrEcho,
    videoCantSeeOthers,
    videoOthersCantSeeMe,
    videoFrozenOrLaggy,
    gotDisconnected,
    screenShareIssue,
    whiteboardOrChatIssue,
    other,
  ];
}

/// Payload broadcast over the LiveKit data channel when a participant
/// submits a report so peers can be prompted to confirm.
class CallIssueBroadcast {
  final String reportId;
  final List<String> categories;
  final String reporterIdentity;
  final String reporterName;

  const CallIssueBroadcast({
    required this.reportId,
    required this.categories,
    required this.reporterIdentity,
    required this.reporterName,
  });

  Map<String, dynamic> toJson() => {
        'type': 'issue_report_broadcast',
        'reportId': reportId,
        'categories': categories,
        'reporterIdentity': reporterIdentity,
        'reporterName': reporterName,
      };

  static CallIssueBroadcast? tryParse(Map<dynamic, dynamic> json) {
    if (json['type'] != 'issue_report_broadcast') return null;
    final reportId = json['reportId']?.toString();
    final reporterIdentity = json['reporterIdentity']?.toString();
    final reporterName = json['reporterName']?.toString();
    final rawCategories = json['categories'];
    List<String>? categories;
    if (rawCategories is List) {
      categories = rawCategories.map((e) => e.toString()).toList();
    }
    if (reportId == null ||
        reporterIdentity == null ||
        reporterName == null ||
        categories == null ||
        categories.isEmpty) {
      return null;
    }
    return CallIssueBroadcast(
      reportId: reportId,
      categories: categories,
      reporterIdentity: reporterIdentity,
      reporterName: reporterName,
    );
  }
}

class CallDiagnosticsService {
  static const String collection = 'call_diagnostics';
  static const String diagnosticsTopic = 'alluwal_diagnostics';

  /// Captures a snapshot of the current call state and writes it to
  /// Firestore. Returns the new document ID, or null on failure.
  ///
  /// [categories] must contain at least one canonical key from
  /// [CallIssueCategory]. [respondingToReportId] links a confirmation
  /// report back to the original peer's report.
  static Future<String?> submitReport({
    required Room room,
    required String shiftId,
    required String roomName,
    required String reporterName,
    required String reporterRole,
    required bool isTeacher,
    required List<String> categories,
    String? note,
    String? respondingToReportId,
  }) async {
    if (categories.isEmpty) {
      AppLogger.error(
          'CallDiagnostics: submitReport called with empty categories');
      return null;
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      final snapshot = await _captureSnapshot(room);
      final doc = FirebaseFirestore.instance.collection(collection).doc();

      final payload = <String, dynamic>{
        'reportId': doc.id,
        'shiftId': shiftId,
        'roomName': roomName,
        'reporterId': user?.uid,
        'reporterEmail': user?.email,
        'reporterName': reporterName,
        'reporterRole': reporterRole,
        'reporterIsTeacher': isTeacher,
        'categories': categories,
        'note': (note != null && note.trim().isNotEmpty) ? note.trim() : null,
        'respondingToReportId': respondingToReportId,
        'reportedAt': FieldValue.serverTimestamp(),
        'clientReportedAt': DateTime.now().toUtc().toIso8601String(),
        ...snapshot,
      };

      await doc.set(payload);
      AppLogger.info(
          'CallDiagnostics: report ${doc.id} submitted (categories=${categories.join(",")}, shift=$shiftId)');
      return doc.id;
    } catch (e, st) {
      AppLogger.error('CallDiagnostics: failed to submit report: $e\n$st');
      return null;
    }
  }

  /// Broadcasts the report metadata to other participants over the LiveKit
  /// data channel so they can be prompted to confirm.
  static Future<void> broadcastReport({
    required Room room,
    required CallIssueBroadcast broadcast,
  }) async {
    try {
      final local = room.localParticipant;
      if (local == null) return;
      final bytes = utf8.encode(jsonEncode(broadcast.toJson()));
      await local.publishData(
        bytes,
        reliable: true,
        topic: diagnosticsTopic,
      );
    } catch (e) {
      AppLogger.error('CallDiagnostics: failed to broadcast report: $e');
    }
  }

  static Future<Map<String, dynamic>> _captureSnapshot(Room room) async {
    final result = <String, dynamic>{};
    try {
      result['roomState'] = _captureRoomState(room);
    } catch (e) {
      result['roomState'] = {'error': e.toString()};
    }
    try {
      result['localParticipant'] = _captureLocalParticipant(room);
    } catch (e) {
      result['localParticipant'] = {'error': e.toString()};
    }
    try {
      result['remoteParticipants'] = _captureRemoteParticipants(room);
    } catch (e) {
      result['remoteParticipants'] = [
        {'error': e.toString()}
      ];
    }
    try {
      result['environment'] = _captureEnvironment();
    } catch (e) {
      result['environment'] = {'error': e.toString()};
    }
    try {
      result['stats'] = await _captureTrackStats(room);
    } catch (e) {
      result['stats'] = {'error': e.toString()};
    }
    try {
      result['network'] = await _captureNetwork();
    } catch (e) {
      result['network'] = {'error': e.toString()};
    }
    try {
      final ctx = await _captureServerContext();
      // The Cloud Function call may have returned caller IP/geo. Merge those
      // into `network` so all network signals live in one map, and keep the
      // load metrics under `serverContext`.
      final caller = ctx.remove('caller');
      if (caller is Map) {
        final net = result['network'];
        if (net is Map<String, dynamic>) {
          net.addAll(Map<String, dynamic>.from(caller));
        }
      }
      result['serverContext'] = ctx;
    } catch (e) {
      result['serverContext'] = {'error': e.toString()};
    }
    return result;
  }

  /// Captures browser-only connection signals (effective type, downlink,
  /// rtt, saveData, online). Public IP / country / ISP are resolved
  /// server-side via getLiveKitRoomStats and merged in
  /// [_captureServerContext], so this method only handles what the client
  /// can observe locally.
  static Future<Map<String, dynamic>> _captureNetwork() async {
    final result = <String, dynamic>{};
    if (kIsWeb) {
      try {
        result.addAll(web_runtime.buildNetworkDiagnostic());
      } catch (e) {
        result['webError'] = e.toString();
      }
    }
    return result;
  }

  /// Captures server-side context that may help correlate this report with
  /// platform-wide issues: number of scheduled classes whose join window
  /// is open right now, plus the count of other reports submitted in the
  /// last 5 minutes.
  ///
  /// `scheduledClassesActiveAtReport` measures *scheduled* shifts only —
  /// it is **not** a measure of LiveKit server load. A future Cloud
  /// Function call can fill in `livekitActiveRooms` for that signal.
  static Future<Map<String, dynamic>> _captureServerContext() async {
    final result = <String, dynamic>{};
    final now = DateTime.now();
    final firestore = FirebaseFirestore.instance;

    try {
      final nowTs = Timestamp.fromDate(now);
      final upperTs = Timestamp.fromDate(now.add(const Duration(hours: 6)));
      final snap = await firestore
          .collection('teaching_shifts')
          .where('shift_end', isGreaterThan: nowTs)
          .where('shift_end', isLessThan: upperTs)
          .limit(200)
          .get()
          .timeout(const Duration(seconds: 3));
      final active = snap.docs.where((d) {
        final start = d.data()['shift_start'];
        if (start is! Timestamp) return false;
        return !start.toDate().isAfter(now);
      }).length;
      result['scheduledClassesActiveAtReport'] = active;
      result['scheduledClassesQueriedDocs'] = snap.docs.length;
    } catch (e) {
      result['scheduledClassesError'] = e.toString();
    }

    try {
      final since = Timestamp.fromDate(
          now.subtract(const Duration(minutes: 5)));
      final agg = await firestore
          .collection(collection)
          .where('reportedAt', isGreaterThan: since)
          .count()
          .get()
          .timeout(const Duration(seconds: 3));
      result['recentReportsLast5Min'] = agg.count;
    } catch (e) {
      result['recentReportsError'] = e.toString();
    }

    // Ground-truth LiveKit server load + caller IP/geo, fetched via
    // authenticated Cloud Function (LiveKit API key is server-only, and
    // resolving caller IP server-side avoids a fragile third-party call
    // from the client). Best-effort; failure is non-blocking.
    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('getLiveKitRoomStats');
      final response =
          await callable.call().timeout(const Duration(seconds: 4));
      final data = response.data;
      if (data is Map) {
        result['livekitActiveRooms'] = data['activeRooms'];
        result['livekitTotalParticipants'] = data['totalParticipants'];
        result['livekitTotalPublishers'] = data['totalPublishers'];
        result['livekitRecordingRooms'] = data['recordingRooms'];
        result['livekitStatsAtIso'] = data['generatedAtIso'];
        if (data['caller'] is Map) {
          result['caller'] = Map<String, dynamic>.from(data['caller']);
        }
      }
    } catch (e) {
      result['livekitStatsError'] = e.toString();
    }

    return result;
  }

  static Map<String, dynamic> _captureRoomState(Room room) {
    return {
      'connectionState': room.connectionState.name,
      'name': room.name,
      'metadata': _safe(() => room.metadata),
      'numParticipants': room.remoteParticipants.length + 1,
      'isRecording': _safe(() => room.isRecording),
    };
  }

  static Map<String, dynamic> _captureLocalParticipant(Room room) {
    final p = room.localParticipant;
    if (p == null) return {'present': false};
    return {
      'identity': p.identity,
      'name': p.name,
      'sid': _safe(() => p.sid),
      'connectionQuality': p.connectionQuality.name,
      'audioTracks': p.audioTrackPublications.map(_publicationSummary).toList(),
      'videoTracks': p.videoTrackPublications.map(_publicationSummary).toList(),
      'isMicrophoneEnabled': _safe(() => p.isMicrophoneEnabled()),
      'isCameraEnabled': _safe(() => p.isCameraEnabled()),
      'isScreenShareEnabled': _safe(() => p.isScreenShareEnabled()),
      'permissions': _safe(() => {
            'canPublish': p.permissions.canPublish,
            'canSubscribe': p.permissions.canSubscribe,
            'canPublishData': p.permissions.canPublishData,
          }),
    };
  }

  static List<Map<String, dynamic>> _captureRemoteParticipants(Room room) {
    return room.remoteParticipants.values.map((p) {
      return {
        'identity': p.identity,
        'name': p.name,
        'sid': _safe(() => p.sid),
        'connectionQuality': p.connectionQuality.name,
        'audioLevel': _safe(() => p.audioLevel),
        'isSpeaking': _safe(() => p.isSpeaking),
        'audioTracks':
            p.audioTrackPublications.map(_publicationSummary).toList(),
        'videoTracks':
            p.videoTrackPublications.map(_publicationSummary).toList(),
      };
    }).toList();
  }

  static Map<String, dynamic> _publicationSummary(TrackPublication pub) {
    return {
      'sid': pub.sid,
      'name': pub.name,
      'kind': pub.kind.name,
      'source': pub.source.name,
      'muted': pub.muted,
      'subscribed': _safe(() => pub.subscribed) ?? false,
      'hasTrack': pub.track != null,
      'isScreenShare': pub.isScreenShare,
      'simulcasted': _safe(() => pub.simulcasted) ?? false,
      'mimeType': _safe(() => pub.mimeType),
    };
  }

  static Future<Map<String, dynamic>> _captureTrackStats(Room room) async {
    final outgoing = <Map<String, dynamic>>[];
    final incoming = <Map<String, dynamic>>[];

    final local = room.localParticipant;
    if (local != null) {
      for (final pub in local.audioTrackPublications) {
        final track = pub.track;
        if (track is! LocalAudioTrack) continue;
        try {
          final stats = await track.getSenderStats();
          outgoing.add({
            'trackSid': pub.sid,
            'kind': 'audio',
            'source': pub.source.name,
            'stats': _audioSenderStatsToMap(stats),
          });
        } catch (e) {
          outgoing.add({
            'trackSid': pub.sid,
            'kind': 'audio',
            'error': e.toString(),
          });
        }
      }
      for (final pub in local.videoTrackPublications) {
        final track = pub.track;
        if (track is! LocalVideoTrack) continue;
        try {
          final layers = await track.getSenderStats();
          outgoing.add({
            'trackSid': pub.sid,
            'kind': 'video',
            'source': pub.source.name,
            'layers': layers.map(_videoSenderStatsToMap).toList(),
          });
        } catch (e) {
          outgoing.add({
            'trackSid': pub.sid,
            'kind': 'video',
            'error': e.toString(),
          });
        }
      }
    }

    for (final remote in room.remoteParticipants.values) {
      for (final pub in remote.audioTrackPublications) {
        final track = pub.track;
        if (track is! RemoteAudioTrack) continue;
        try {
          final stats = await track.getReceiverStats();
          incoming.add({
            'participantIdentity': remote.identity,
            'trackSid': pub.sid,
            'kind': 'audio',
            'source': pub.source.name,
            'stats': _audioReceiverStatsToMap(stats),
          });
        } catch (e) {
          incoming.add({
            'participantIdentity': remote.identity,
            'trackSid': pub.sid,
            'kind': 'audio',
            'error': e.toString(),
          });
        }
      }
      for (final pub in remote.videoTrackPublications) {
        final track = pub.track;
        if (track is! RemoteVideoTrack) continue;
        try {
          final stats = await track.getReceiverStats();
          incoming.add({
            'participantIdentity': remote.identity,
            'trackSid': pub.sid,
            'kind': 'video',
            'source': pub.source.name,
            'stats': _videoReceiverStatsToMap(stats),
          });
        } catch (e) {
          incoming.add({
            'participantIdentity': remote.identity,
            'trackSid': pub.sid,
            'kind': 'video',
            'error': e.toString(),
          });
        }
      }
    }

    return {'outgoing': outgoing, 'incoming': incoming};
  }

  // Stats classes are not part of livekit_client's public exports, so we use
  // dynamic dispatch to read fields and rely on _safe to swallow API drift.
  static Map<String, dynamic>? _audioSenderStatsToMap(dynamic s) {
    if (s == null) return null;
    return {
      'streamId': _safe(() => s.streamId),
      'timestamp': _safe(() => s.timestamp),
      'mimeType': _safe(() => s.mimeType),
      'packetsSent': _safe(() => s.packetsSent),
      'bytesSent': _safe(() => s.bytesSent),
      'packetsLost': _safe(() => s.packetsLost),
      'jitter': _safe(() => s.jitter),
      'roundTripTime': _safe(() => s.roundTripTime),
    };
  }

  static Map<String, dynamic> _videoSenderStatsToMap(dynamic s) {
    return {
      'streamId': _safe(() => s.streamId),
      'timestamp': _safe(() => s.timestamp),
      'mimeType': _safe(() => s.mimeType),
      'rid': _safe(() => s.rid),
      'packetsSent': _safe(() => s.packetsSent),
      'bytesSent': _safe(() => s.bytesSent),
      'packetsLost': _safe(() => s.packetsLost),
      'jitter': _safe(() => s.jitter),
      'roundTripTime': _safe(() => s.roundTripTime),
      'frameWidth': _safe(() => s.frameWidth),
      'frameHeight': _safe(() => s.frameHeight),
      'framesSent': _safe(() => s.framesSent),
      'framesPerSecond': _safe(() => s.framesPerSecond),
      'qualityLimitationReason': _safe(() => s.qualityLimitationReason),
      'firCount': _safe(() => s.firCount),
      'pliCount': _safe(() => s.pliCount),
      'nackCount': _safe(() => s.nackCount),
    };
  }

  static Map<String, dynamic>? _audioReceiverStatsToMap(dynamic s) {
    if (s == null) return null;
    return {
      'streamId': _safe(() => s.streamId),
      'timestamp': _safe(() => s.timestamp),
      'mimeType': _safe(() => s.mimeType),
      'packetsReceived': _safe(() => s.packetsReceived),
      'packetsLost': _safe(() => s.packetsLost),
      'bytesReceived': _safe(() => s.bytesReceived),
      'jitter': _safe(() => s.jitter),
      'jitterBufferDelay': _safe(() => s.jitterBufferDelay),
      'concealedSamples': _safe(() => s.concealedSamples),
      'concealmentEvents': _safe(() => s.concealmentEvents),
      'totalAudioEnergy': _safe(() => s.totalAudioEnergy),
      'totalSamplesDuration': _safe(() => s.totalSamplesDuration),
    };
  }

  static Map<String, dynamic>? _videoReceiverStatsToMap(dynamic s) {
    if (s == null) return null;
    return {
      'streamId': _safe(() => s.streamId),
      'timestamp': _safe(() => s.timestamp),
      'mimeType': _safe(() => s.mimeType),
      'packetsReceived': _safe(() => s.packetsReceived),
      'packetsLost': _safe(() => s.packetsLost),
      'bytesReceived': _safe(() => s.bytesReceived),
      'jitter': _safe(() => s.jitter),
      'jitterBufferDelay': _safe(() => s.jitterBufferDelay),
      'framesDecoded': _safe(() => s.framesDecoded),
      'framesDropped': _safe(() => s.framesDropped),
      'framesReceived': _safe(() => s.framesReceived),
      'framesPerSecond': _safe(() => s.framesPerSecond),
      'frameWidth': _safe(() => s.frameWidth),
      'frameHeight': _safe(() => s.frameHeight),
      'firCount': _safe(() => s.firCount),
      'pliCount': _safe(() => s.pliCount),
      'nackCount': _safe(() => s.nackCount),
    };
  }

  static Map<String, dynamic> _captureEnvironment() {
    return {
      'platform': _platformName(),
      'isWeb': kIsWeb,
      'webBuildVersion':
          BuildInfo.hasWebBuildVersion ? BuildInfo.webBuildVersion : null,
      'webRuntime': kIsWeb ? web_runtime.buildRuntimeDiagnostic() : null,
    };
  }

  static String _platformName() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  static T? _safe<T>(T Function() fn) {
    try {
      return fn();
    } catch (_) {
      return null;
    }
  }
}
