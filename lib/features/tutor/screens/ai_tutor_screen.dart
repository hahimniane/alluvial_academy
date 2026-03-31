import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/teaching_shift.dart';
import 'package:alluwalacademyadmin/features/shift_management/services/location_service.dart';
import 'package:alluwalacademyadmin/features/time_clock/services/shift_timesheet_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/platform_utils.dart';
import '../../../core/utils/timezone_utils.dart';
import '../../livekit/widgets/call_whiteboard.dart';
import '../../../l10n/app_localizations.dart';

/// Interaction mode for AI Tutor
enum TutorInteractionMode { voice, text }

/// Message sender type for chat
enum TutorMessageSender { user, ai }

/// Message type for chat
enum TutorMessageType { text, voiceTranscription }

/// Preferred AI voice profile.
///
/// LiveKit Cartesia Inference documented sample IDs:
/// - Blake: a167e0f3-df7e-4d52-a9c3-f949145efdab
/// - Jacqueline: 9626c31c-bec5-4cca-baa8-f8ba9e84c8bc
/// - Robyn: f31cc6a7-c1e8-4764-980c-60a361443dd1
enum TutorVoicePreference { blake, jacqueline, robyn }

/// Preferred background ambience.
enum TutorBackgroundPreference { none, forest, city, office, holdMusic }

String tutorVoicePreferenceKey(TutorVoicePreference value) {
  switch (value) {
    case TutorVoicePreference.blake:
      return 'blake';
    case TutorVoicePreference.jacqueline:
      return 'jacqueline';
    case TutorVoicePreference.robyn:
      return 'robyn';
  }
}

TutorVoicePreference tutorVoicePreferenceFromKey(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    // Backward compatibility for previously saved/issued keys.
    case 'alluwal':
    case 'kiefer':
    case 'blake':
      return TutorVoicePreference.blake;
    case 'katie':
    case 'jacqueline':
      return TutorVoicePreference.jacqueline;
    case 'robyn':
      return TutorVoicePreference.robyn;
    default:
      return TutorVoicePreference.blake;
  }
}

String tutorVoicePreferenceLabel(TutorVoicePreference value) {
  switch (value) {
    case TutorVoicePreference.blake:
      return 'Blake (Default)';
    case TutorVoicePreference.jacqueline:
      return 'Jacqueline';
    case TutorVoicePreference.robyn:
      return 'Robyn';
  }
}

String tutorBackgroundPreferenceKey(TutorBackgroundPreference value) {
  switch (value) {
    case TutorBackgroundPreference.none:
      return 'none';
    case TutorBackgroundPreference.forest:
      return 'forest';
    case TutorBackgroundPreference.city:
      return 'city';
    case TutorBackgroundPreference.office:
      return 'office';
    case TutorBackgroundPreference.holdMusic:
      return 'hold_music';
  }
}

TutorBackgroundPreference tutorBackgroundPreferenceFromKey(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'none':
      return TutorBackgroundPreference.none;
    case 'city':
      return TutorBackgroundPreference.city;
    case 'office':
      return TutorBackgroundPreference.office;
    case 'hold_music':
      return TutorBackgroundPreference.holdMusic;
    case 'forest':
    default:
      return TutorBackgroundPreference.forest;
  }
}

String tutorBackgroundPreferenceLabel(TutorBackgroundPreference value) {
  switch (value) {
    case TutorBackgroundPreference.none:
      return 'None';
    case TutorBackgroundPreference.forest:
      return 'Forest';
    case TutorBackgroundPreference.city:
      return 'City';
    case TutorBackgroundPreference.office:
      return 'Office';
    case TutorBackgroundPreference.holdMusic:
      return 'Music';
  }
}

/// Chat message model for AI Tutor conversations
class TutorChatMessage {
  final String id;
  final String content;
  final TutorMessageSender sender;
  final TutorMessageType type;
  final DateTime timestamp;

  TutorChatMessage({
    required this.id,
    required this.content,
    required this.sender,
    required this.type,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// AI Tutor Screen - Voice interaction with the AI tutor agent
class AITutorScreen extends StatefulWidget {
  const AITutorScreen({super.key});

  @override
  State<AITutorScreen> createState() => _AITutorScreenState();
}

class _AITutorScreenState extends State<AITutorScreen>
    with SingleTickerProviderStateMixin {
  static const String _tutorWhiteboardTopic = 'ai_tutor_whiteboard';
  static const String _legacyTutorWhiteboardTopic = 'alluwal_whiteboard';
  static const String _tutorTeacherActionTopic = 'ai_tutor_teacher_actions';
  static const String _tutorTeacherActionResultTopic =
      'ai_tutor_teacher_action_results';
  static const String _tutorChatTextTopic = 'ai_tutor_chat_text';
  static const String _tutorTranscriptionTopic = 'ai_tutor_transcription';
  static const String _prefInteractionModeKey = 'ai_tutor.interaction_mode';
  static const String _prefVoicePreferenceKey = 'ai_tutor.voice_preference';
  static const String _prefBackgroundPreferenceKey =
      'ai_tutor.background_preference';
  static const String _teacherActionMessageType = 'teacher_action';
  static const String _teacherActionResultMessageType = 'teacher_action_result';
  static const Set<String> _studentMatchStopwords = {
    'a',
    'all',
    'am',
    'at',
    'change',
    'class',
    'classes',
    'for',
    'future',
    'in',
    'my',
    'of',
    'on',
    'only',
    'pm',
    'shift',
    'student',
    'teacher',
    'the',
    'this',
    'time',
    'to',
    'today',
    'tomorrow',
    'with',
  };
  static const Set<String> _tutorWhiteboardTopics = {
    _tutorWhiteboardTopic,
    _legacyTutorWhiteboardTopic,
  };

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  Room? _room;
  LocalParticipant? _localParticipant;
  EventsListener<RoomEvent>? _listener;

  bool _isLoading = false;
  bool _isMicEnabled = true;
  bool _agentJoined = false;
  String? _error;
  String? _roomName;
  String _sessionUserRole = 'student';
  bool _preferencesLoaded = false;

  // Interaction mode - null means user hasn't selected yet
  TutorInteractionMode? _interactionMode;
  TutorVoicePreference _voicePreference = TutorVoicePreference.blake;
  TutorBackgroundPreference _backgroundPreference =
      TutorBackgroundPreference.forest;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Audio level visualization
  double _remoteAudioLevel = 0.0;
  Timer? _audioLevelTimer;
  final StreamController<Map<String, dynamic>> _whiteboardProjectController =
      StreamController<Map<String, dynamic>>.broadcast();
  Map<String, dynamic>? _lastWhiteboardProject;
  bool _showWhiteboard = false;
  bool _studentDrawingEnabled = true;

  // Whiteboard capture key for sending to AI
  final GlobalKey<CallWhiteboardState> _whiteboardKey =
      GlobalKey<CallWhiteboardState>();
  bool _isSendingWhiteboard = false;

  // Chat view state
  final List<TutorChatMessage> _chatMessages = [];
  final TextEditingController _chatInputController = TextEditingController();
  final FocusNode _chatInputFocusNode = FocusNode();
  final ScrollController _chatScrollController = ScrollController();

  bool get _isTeacherSession => _sessionUserRole == 'teacher';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    unawaited(_initializeTutorPreferences());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioLevelTimer?.cancel();
    _whiteboardProjectController.close();
    _chatInputController.dispose();
    _chatInputFocusNode.dispose();
    _chatScrollController.dispose();
    _disconnectFromRoom();
    super.dispose();
  }

  String _interactionModePreferenceKey(TutorInteractionMode mode) =>
      mode == TutorInteractionMode.text ? 'text' : 'voice';

  TutorInteractionMode? _interactionModeFromPreferenceKey(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'text':
        return TutorInteractionMode.text;
      case 'voice':
        return TutorInteractionMode.voice;
      default:
        return null;
    }
  }

  Future<void> _saveTutorPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_interactionMode != null) {
        await prefs.setString(
          _prefInteractionModeKey,
          _interactionModePreferenceKey(_interactionMode!),
        );
      } else {
        await prefs.remove(_prefInteractionModeKey);
      }

      await prefs.setString(
        _prefVoicePreferenceKey,
        tutorVoicePreferenceKey(_voicePreference),
      );
      await prefs.setString(
        _prefBackgroundPreferenceKey,
        tutorBackgroundPreferenceKey(_backgroundPreference),
      );
    } catch (e) {
      AppLogger.warning('AI Tutor: Failed to save preferences: $e');
    }
  }

  Future<void> _loadTutorPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeRaw = prefs.getString(_prefInteractionModeKey);
      final voiceRaw = prefs.getString(_prefVoicePreferenceKey);
      final backgroundRaw = prefs.getString(_prefBackgroundPreferenceKey);

      _interactionMode = _interactionModeFromPreferenceKey(modeRaw);
      _voicePreference = tutorVoicePreferenceFromKey(voiceRaw);
      _backgroundPreference = tutorBackgroundPreferenceFromKey(backgroundRaw);
      _isMicEnabled = _interactionMode != TutorInteractionMode.text;
    } catch (e) {
      AppLogger.warning('AI Tutor: Failed to load preferences: $e');
      _interactionMode = null;
      _isMicEnabled = true;
      _voicePreference = TutorVoicePreference.blake;
      _backgroundPreference = TutorBackgroundPreference.forest;
    }
  }

  Future<void> _initializeTutorPreferences() async {
    await _loadTutorPreferences();
    if (!mounted) return;
    setState(() {
      _preferencesLoaded = true;
    });

    if (_interactionMode != null) {
      await _startSession();
    }
  }

  Future<void> _restartSessionWithCurrentPreferences() async {
    if (_isLoading) return;
    setState(() {
      _error = null;
      _agentJoined = false;
      _showWhiteboard = false;
    });
    await _disconnectFromRoom();
    if (!mounted) return;
    await _startSession();
  }

  Future<bool> _checkAITutorAccess() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        // Try email-based lookup
        final query = await FirebaseFirestore.instance
            .collection('users')
            .where('e-mail', isEqualTo: user.email)
            .limit(1)
            .get();
        if (query.docs.isEmpty) return false;
        return query.docs.first.data()['ai_tutor_enabled'] as bool? ?? false;
      }

      return userDoc.data()?['ai_tutor_enabled'] as bool? ?? false;
    } catch (e) {
      AppLogger.error('AI Tutor: Error checking access: $e');
      return false;
    }
  }

  Future<bool> _requestPermissions() async {
    if (kIsWeb) return true;

    try {
      final micStatus = await Permission.microphone.request();

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await Permission.bluetooth.request();
        await Permission.bluetoothConnect.request();
      }

      return micStatus.isGranted;
    } catch (e) {
      AppLogger.error('AI Tutor: Error requesting permissions: $e');
      return false;
    }
  }

  Future<void> _startSession() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Check if AI Tutor is enabled for this user
    final hasAccess = await _checkAITutorAccess();
    if (!hasAccess) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error =
            'AI Tutor access has not been enabled for your account. Please contact an administrator.';
      });
      return;
    }

    // Request microphone permissions only in voice mode
    final requiresMicrophone = _interactionMode != TutorInteractionMode.text;
    if (requiresMicrophone) {
      final hasPermissions = await _requestPermissions();
      if (!hasPermissions) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _error = AppLocalizations.of(context)!.tutorMicPermissionRequired;
        });
        return;
      }
    }

    try {
      // Get token from backend
      final callable = _functions.httpsCallable('getAITutorToken');
      final interactionMode =
          _interactionMode == TutorInteractionMode.text ? 'text' : 'voice';
      String? clientTimezone;
      try {
        final detectedTimezone = await TimezoneUtils.detectUserTimezone();
        final normalizedTimezone = detectedTimezone.trim();
        if (normalizedTimezone.isNotEmpty) {
          clientTimezone = normalizedTimezone;
        }
      } catch (timezoneError) {
        AppLogger.warning(
          'AI Tutor: Failed to detect client timezone for token request: '
          '$timezoneError',
        );
      }

      final clientNow = DateTime.now();
      final result = await callable.call<Map<String, dynamic>>({
        'interactionMode': interactionMode,
        'aiVoice': tutorVoicePreferenceKey(_voicePreference),
        'aiBackground': tutorBackgroundPreferenceKey(_backgroundPreference),
        if (clientTimezone != null) 'clientTimezone': clientTimezone,
        'clientLocalIso': clientNow.toIso8601String(),
        'clientNowEpochMs': clientNow.millisecondsSinceEpoch,
      });
      final data = result.data;

      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Failed to start AI tutor session');
      }

      final livekitUrl = data['livekitUrl'] as String;
      final token = data['token'] as String;
      _roomName = data['roomName'] as String;
      final role = data['userRole']?.toString().trim().toLowerCase() ?? '';
      final teacherActionsEnabledRaw = data['teacherActionsEnabled'];
      final teacherActionsEnabled = teacherActionsEnabledRaw is bool
          ? teacherActionsEnabledRaw
          : role == 'teacher';
      _sessionUserRole =
          (role == 'teacher' && teacherActionsEnabled) ? 'teacher' : 'student';
      final backendModeRaw =
          data['interactionMode']?.toString().trim().toLowerCase() ??
              interactionMode;
      final resolvedMode = backendModeRaw == 'text'
          ? TutorInteractionMode.text
          : TutorInteractionMode.voice;
      final resolvedVoice = tutorVoicePreferenceFromKey(
        data['voicePreference']?.toString(),
      );
      final resolvedBackground = tutorBackgroundPreferenceFromKey(
        data['backgroundPreference']?.toString(),
      );

      if (mounted) {
        setState(() {
          _interactionMode = resolvedMode;
          _isMicEnabled = resolvedMode == TutorInteractionMode.voice;
          _voicePreference = resolvedVoice;
          _backgroundPreference = resolvedBackground;
        });
      } else {
        _interactionMode = resolvedMode;
        _isMicEnabled = resolvedMode == TutorInteractionMode.voice;
        _voicePreference = resolvedVoice;
        _backgroundPreference = resolvedBackground;
      }

      unawaited(_saveTutorPreferences());

      // Connect to LiveKit room
      await _connectToRoom(livekitUrl, token);
    } catch (e) {
      AppLogger.error('AI Tutor: Failed to start session: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = _getErrorMessage(e);
        });
      }
    }
  }

  String _getErrorMessage(dynamic error) {
    final rawError = error.toString();
    final errorStr = rawError.toLowerCase();
    if (errorStr.contains('permission-denied')) {
      final messageMatch = RegExp(r'\]\s*(.+)$').firstMatch(rawError);
      final backendMessage = messageMatch?.group(1)?.trim() ?? '';
      if (backendMessage.isNotEmpty) {
        return backendMessage;
      }
      return AppLocalizations.of(context)!.tutorNotAvailableForRole;
    }
    if (errorStr.contains('unavailable')) {
      return AppLocalizations.of(context)!.tutorServiceUnavailable;
    }
    return AppLocalizations.of(context)!.tutorConnectionFailed;
  }

  Future<void> _connectToRoom(String url, String token) async {
    try {
      final roomOptions = RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultAudioCaptureOptions: const AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        ),
        defaultAudioPublishOptions: const AudioPublishOptions(
          dtx:
              true, // Discontinuous transmission - saves bandwidth during silence
        ),
      );

      final room = Room(roomOptions: roomOptions);

      _listener = room.createListener();
      _setupRoomListeners(_listener!);

      await room.connect(url, token);

      if (!mounted) return;

      setState(() {
        _room = room;
        _localParticipant = room.localParticipant;
        _isLoading = false;
        _isMicEnabled = _interactionMode == TutorInteractionMode.voice;
      });

      // Apply microphone state for the selected interaction mode.
      final shouldEnableMic = _interactionMode == TutorInteractionMode.voice;
      await _setMicrophoneEnabled(shouldEnableMic);

      // Start audio level monitoring
      _startAudioLevelMonitoring();

      AppLogger.info('AI Tutor: Connected to room $_roomName');
    } catch (e) {
      AppLogger.error('AI Tutor: Failed to connect to room: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = AppLocalizations.of(context)!.tutorConnectionFailed;
        });
      }
    }
  }

  void _setupRoomListeners(EventsListener<RoomEvent> listener) {
    listener
      ..on<ParticipantConnectedEvent>((event) {
        AppLogger.info(
            'AI Tutor: Participant connected: ${event.participant.identity}');
        if (mounted) {
          setState(() => _agentJoined = true);
        }
        final identity = event.participant.identity;
        if (identity.isNotEmpty) {
          final projectToSync = _lastWhiteboardProject ??
              <String, dynamic>{'strokes': const <dynamic>[], 'version': 2};
          unawaited(
            _sendTutorWhiteboardProject(
              projectToSync,
              destinationIdentities: [identity],
            ),
          );
        }
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        AppLogger.info(
            'AI Tutor: Participant disconnected: ${event.participant.identity}');
        if (mounted) {
          setState(() => _agentJoined = false);
        }
      })
      ..on<RoomDisconnectedEvent>((event) {
        AppLogger.info(
            'AI Tutor: Disconnected from room. Reason: ${event.reason}');
        if (mounted) {
          setState(() {
            _agentJoined = false;
          });
        }
      })
      ..on<AudioPlaybackStatusChanged>((event) {
        AppLogger.debug('AI Tutor: Audio playback status changed');
      })
      ..on<TrackSubscribedEvent>((event) {
        AppLogger.info('AI Tutor: Track subscribed: ${event.track.kind}');
        if (event.track is AudioTrack) {
          // Agent's audio track is available
          if (mounted) {
            setState(() => _agentJoined = true);
          }
        }
      })
      ..on<DataReceivedEvent>(_handleTutorDataReceived);
  }

  void _handleTutorDataReceived(DataReceivedEvent event) {
    final topic = event.topic;
    if (topic == _tutorTeacherActionTopic) {
      unawaited(_handleTutorTeacherActionDataReceived(event));
      return;
    }

    if (topic == _tutorTranscriptionTopic) {
      _handleTranscriptionReceived(event);
      return;
    }

    if (!_tutorWhiteboardTopics.contains(topic)) return;
    _handleTutorWhiteboardDataReceived(event);
  }

  void _handleTutorWhiteboardDataReceived(DataReceivedEvent event) {
    final topic = event.topic;

    final senderIdentity = event.participant?.identity ?? 'unknown';
    final localIdentity = _localParticipant?.identity;
    if (senderIdentity == localIdentity) {
      AppLogger.debug(
          'AI Tutor Whiteboard: Ignoring local echo from $senderIdentity on topic "$topic"');
      return;
    }

    try {
      final text = utf8.decode(event.data, allowMalformed: true);
      final message = WhiteboardMessage.decode(text);
      if (message == null) {
        AppLogger.debug(
            'AI Tutor Whiteboard: Ignoring undecodable message from $senderIdentity');
        return;
      }

      if (message.type != WhiteboardMessage.typeProject &&
          message.type != WhiteboardMessage.typeStudentDrawingPermission) {
        AppLogger.debug(
            'AI Tutor Whiteboard: Ignoring unsupported message type "${message.type}" from $senderIdentity');
        return;
      }

      if (message.type == WhiteboardMessage.typeProject) {
        if (message.payload == null) return;
        final strokeCount = (message.payload!['strokes'] as List?)?.length ?? 0;
        AppLogger.debug(
            'AI Tutor Whiteboard: Received project with $strokeCount strokes from $senderIdentity on topic "$topic"');

        _lastWhiteboardProject = message.payload;
        if (!mounted || _whiteboardProjectController.isClosed) return;
        _whiteboardProjectController.add(message.payload!);
        return;
      }

      if (message.type == WhiteboardMessage.typeStudentDrawingPermission) {
        if (message.payload == null) return;
        final enabled = message.payload!['enabled'] == true;
        AppLogger.debug(
            'AI Tutor Whiteboard: Received drawing permission enabled=$enabled from $senderIdentity on topic "$topic"');
        if (mounted) {
          setState(() => _studentDrawingEnabled = enabled);
        }
      }
    } catch (e) {
      AppLogger.debug(
          'AI Tutor Whiteboard: Failed to process data from $senderIdentity: $e');
    }
  }

  Future<void> _handleTutorTeacherActionDataReceived(
    DataReceivedEvent event,
  ) async {
    final senderIdentity = event.participant?.identity ?? 'unknown';
    final localIdentity = _localParticipant?.identity;
    if (senderIdentity == localIdentity) {
      AppLogger.debug(
          'AI Tutor Teacher Actions: Ignoring local echo from $senderIdentity');
      return;
    }

    try {
      final text = utf8.decode(event.data, allowMalformed: true);
      final message = WhiteboardMessage.decode(text);
      if (message == null ||
          message.type != _teacherActionMessageType ||
          message.payload == null) {
        AppLogger.debug(
            'AI Tutor Teacher Actions: Ignoring unsupported payload from $senderIdentity');
        return;
      }

      final payload = message.payload!;
      final requestId = payload['requestId']?.toString().trim() ?? '';
      final action = payload['action']?.toString().trim().toLowerCase() ?? '';
      final argsRaw = payload['args'];
      final args = argsRaw is Map
          ? Map<String, dynamic>.from(argsRaw as Map<Object?, Object?>)
          : <String, dynamic>{};

      if (requestId.isEmpty || action.isEmpty) {
        AppLogger.debug(
            'AI Tutor Teacher Actions: Missing requestId/action in payload from $senderIdentity');
        return;
      }

      if (!_isTeacherSession) {
        await _sendTutorTeacherActionResult(
          requestId: requestId,
          action: action,
          success: false,
          message:
              'Schedule changes and clock-in are disabled in student sessions. Please ask the teacher to make this change.',
        );
        return;
      }

      AppLogger.info(
          'AI Tutor Teacher Actions: Executing action "$action" requestId="$requestId"');

      Map<String, dynamic> result;
      switch (action) {
        case 'clock_in':
          result = await _executeTeacherClockIn(args);
          break;
        case 'reschedule_shift':
          result = await _executeTeacherReschedule(args);
          break;
        case 'reschedule_shift_future':
          result = await _executeTeacherReschedule(args);
          break;
        default:
          result = {
            'success': false,
            'message': 'Unsupported teacher action: $action',
          };
      }

      final success = result['success'] == true;
      final resultMessage = result['message']?.toString() ??
          (success ? 'Action completed.' : 'Action failed.');
      final resultDataRaw = result['data'];
      final resultData = resultDataRaw is Map
          ? Map<String, dynamic>.from(resultDataRaw as Map<Object?, Object?>)
          : null;

      await _sendTutorTeacherActionResult(
        requestId: requestId,
        action: action,
        success: success,
        message: resultMessage,
        data: resultData,
      );

      if (mounted) {
        _showTeacherActionSnackBar(resultMessage, success: success);
      }
    } catch (e) {
      AppLogger.error('AI Tutor Teacher Actions: Failed to process action: $e');
    }
  }

  Future<Map<String, dynamic>> _executeTeacherClockIn(
    Map<String, dynamic> args,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {
        'success': false,
        'message': 'Unable to clock in because the user is not authenticated.',
      };
    }

    final requestedShiftId = _extractArg(
      args,
      const ['shiftId', 'shift_id'],
    );

    if (requestedShiftId.isNotEmpty) {
      final requestedShift = await _loadTeacherShiftById(
        teacherId: user.uid,
        shiftId: requestedShiftId,
      );
      if (requestedShift == null) {
        return {
          'success': false,
          'message':
              'Unable to find the requested shift for this teacher account.',
        };
      }

      final location = await _resolveClockInLocation();
      if (location == null) {
        return {
          'success': false,
          'message':
              'Unable to get your location for clock in. Please enable location and try again.',
        };
      }

      final platform = PlatformUtils.detectPlatform();
      final result = await ShiftTimesheetService.clockInToShift(
        user.uid,
        requestedShift.id,
        location: location,
        platform: platform,
      );
      final success = result['success'] == true;
      return {
        'success': success,
        'message': (result['message'] ??
                (success
                    ? 'Clocked in successfully.'
                    : 'Unable to clock in to the requested shift.'))
            .toString(),
        'data': _sanitizeActionData(result),
      };
    }

    final validShift = await ShiftTimesheetService.getValidShiftForClockIn(
      user.uid,
    );
    final canClockIn = validShift['canClockIn'] == true;
    final canProgramClockIn = validShift['canProgramClockIn'] == true;
    final canClockOut = validShift['canClockOut'] == true;
    final shift = validShift['shift'];
    final shiftId = shift is TeachingShift ? shift.id : null;

    if (canClockOut) {
      return {
        'success': false,
        'message': (validShift['message'] ??
                'You are already clocked in to an active shift.')
            .toString(),
        'data': _sanitizeActionData(validShift),
      };
    }

    if (shiftId == null || shiftId.isEmpty) {
      return {
        'success': false,
        'message': (validShift['message'] ??
                'No valid shift is available to clock in right now.')
            .toString(),
        'data': _sanitizeActionData(validShift),
      };
    }

    final location = await _resolveClockInLocation();
    if (location == null) {
      return {
        'success': false,
        'message':
            'Unable to get your location for clock in. Please enable location and try again.',
      };
    }

    final platform = PlatformUtils.detectPlatform();

    if (!canClockIn && canProgramClockIn) {
      final result = await ShiftTimesheetService.programClockIn(
        user.uid,
        shiftId,
        location: location,
        platform: platform,
      );
      final success = result['success'] == true;
      return {
        'success': success,
        'message': (result['message'] ??
                (success
                    ? 'Clock in has been programmed and will run automatically at class start.'
                    : 'Unable to program clock in.'))
            .toString(),
        'data': _sanitizeActionData(result),
      };
    }

    final result = await ShiftTimesheetService.clockInToShift(
      user.uid,
      shiftId,
      location: location,
      platform: platform,
    );
    final success = result['success'] == true;
    return {
      'success': success,
      'message': (result['message'] ??
              (success ? 'Clocked in successfully.' : 'Unable to clock in.'))
          .toString(),
      'data': _sanitizeActionData(result),
    };
  }

  Future<Map<String, dynamic>> _executeTeacherReschedule(
    Map<String, dynamic> args,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {
        'success': false,
        'message':
            'Unable to reschedule because the user is not authenticated.',
      };
    }

    final confirmed = _extractBoolArg(args, const [
      'confirmed',
      'confirm',
      'isConfirmed',
    ]);
    if (confirmed != true) {
      return {
        'success': false,
        'message':
            'Please confirm the change explicitly before I update your schedule.',
      };
    }

    final scopeRaw = _extractArg(args, const [
      'scope',
      'rescheduleScope',
      'reschedule_scope',
    ]);
    final scope = _normalizeRescheduleScope(scopeRaw);
    if (scope == null) {
      return {
        'success': false,
        'message':
            'Please confirm if this change is for today only or for all future classes.',
      };
    }

    final newStartRaw = _extractArg(args, const [
      'newStartTime',
      'new_start_time',
      'newStartIso',
      'new_start_iso',
    ]);
    final newEndRaw = _extractArg(args, const [
      'newEndTime',
      'new_end_time',
      'newEndIso',
      'new_end_iso',
    ]);
    final newStartLocalRaw = _extractArg(args, const [
      'newStartLocal',
      'new_start_local',
      'newStartLocalIso',
      'new_start_local_iso',
    ]);
    final newEndLocalRaw = _extractArg(args, const [
      'newEndLocal',
      'new_end_local',
      'newEndLocalIso',
      'new_end_local_iso',
    ]);
    final timezone = _extractArg(args, const [
      'timezone',
      'teacherTimezone',
      'teacher_timezone',
      'userTimezone',
      'user_timezone',
    ]);
    final reason = _extractArg(args, const ['reason']);
    final studentId = _extractArg(args, const ['studentId', 'student_id']);
    final studentName =
        _extractArg(args, const ['studentName', 'student_name']);
    final applyFromDate = _extractArg(args, const [
      'applyFromDate',
      'apply_from_date',
      'targetDateLocal',
      'target_date_local',
      'classDate',
      'class_date',
      'date',
    ]);

    final hasIsoWindow = newStartRaw.isNotEmpty && newEndRaw.isNotEmpty;
    final hasLocalWindow =
        newStartLocalRaw.isNotEmpty && newEndLocalRaw.isNotEmpty;
    if (!hasIsoWindow && !hasLocalWindow) {
      return {
        'success': false,
        'message':
            'Missing new class time. Please provide a complete start and end time.',
      };
    }
    if ((newStartRaw.isNotEmpty && newEndRaw.isEmpty) ||
        (newEndRaw.isNotEmpty && newStartRaw.isEmpty)) {
      return {
        'success': false,
        'message':
            'Please provide both new start and end times before I reschedule.',
      };
    }
    if ((newStartLocalRaw.isNotEmpty && newEndLocalRaw.isEmpty) ||
        (newEndLocalRaw.isNotEmpty && newStartLocalRaw.isEmpty)) {
      return {
        'success': false,
        'message':
            'Please provide both local start and end times before I reschedule.',
      };
    }

    final localDateHint = _tryParseDateArg(applyFromDate) ??
        _tryParseDateArg(newStartLocalRaw) ??
        _tryParseDateArg(newStartRaw);

    var shiftId = _extractArg(args, const ['shiftId', 'shift_id']);
    if (shiftId.isEmpty && scope == 'single') {
      final nextShift = await _findNextUpcomingTeacherShift(
        user.uid,
        studentId: studentId.isEmpty ? null : studentId,
        studentName: studentName.isEmpty ? null : studentName,
        targetDateLocal: localDateHint,
      );
      if (nextShift == null) {
        return {
          'success': false,
          'message':
              'Unable to find the class to reschedule. Please specify the student or class.',
        };
      }
      shiftId = nextShift.id;
    } else if (shiftId.isNotEmpty) {
      final requestedShift = await _loadTeacherShiftById(
        teacherId: user.uid,
        shiftId: shiftId,
      );
      if (requestedShift == null) {
        return {
          'success': false,
          'message':
              'Unable to find the requested shift for this teacher account.',
        };
      }
      shiftId = requestedShift.id;
    }

    try {
      final callableName = scope == 'future'
          ? 'teacherRescheduleFutureShifts'
          : 'teacherRescheduleShift';
      final callable = _functions.httpsCallable(callableName);
      final payload = <String, dynamic>{
        if (shiftId.isNotEmpty) 'shiftId': shiftId,
        'confirm': true,
        'scope': scope,
        if (timezone.isNotEmpty) 'timezone': timezone,
        if (reason.isNotEmpty) 'reason': reason,
        if (studentId.isNotEmpty) 'studentId': studentId,
        if (studentName.isNotEmpty) 'studentName': studentName,
        if (applyFromDate.isNotEmpty) 'applyFromDate': applyFromDate,
      };
      if (hasLocalWindow) {
        payload['newStartLocal'] = newStartLocalRaw;
        payload['newEndLocal'] = newEndLocalRaw;
      } else {
        payload['newStartTime'] = newStartRaw;
        payload['newEndTime'] = newEndRaw;
      }

      final response = await callable.call<Map<String, dynamic>>(payload);

      final data = response.data;
      final success = data['success'] == true;

      return {
        'success': success,
        'message': (data['message'] ??
                (success
                    ? 'Shift rescheduled successfully.'
                    : 'Unable to reschedule shift.'))
            .toString(),
        'data': {
          'scope': scope,
          'shiftId': shiftId,
          ..._sanitizeActionData(data),
        },
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Unable to reschedule class: ${_extractCallableError(e)}',
      };
    }
  }

  Future<LocationData?> _resolveClockInLocation() async {
    try {
      return await LocationService.getCurrentLocation()
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      AppLogger.warning('AI Tutor Teacher Actions: Location lookup failed: $e');
      return null;
    }
  }

  Future<TeachingShift?> _findNextUpcomingTeacherShift(
    String teacherId, {
    String? studentId,
    String? studentName,
    DateTime? targetDateLocal,
  }) async {
    try {
      QuerySnapshot<Map<String, dynamic>>? snapshot;
      final now = DateTime.now().toUtc();
      final nowTs = Timestamp.fromDate(now);
      final shiftsRef =
          FirebaseFirestore.instance.collection('teaching_shifts');

      try {
        snapshot = await shiftsRef
            .where('teacher_id', isEqualTo: teacherId)
            .where('shift_start', isGreaterThanOrEqualTo: nowTs)
            .orderBy('shift_start')
            .limit(200)
            .get();
      } catch (queryError) {
        AppLogger.warning(
          'AI Tutor Teacher Actions: Indexed upcoming shift query failed, '
          'falling back to broad query: $queryError',
        );
      }

      snapshot ??= await shiftsRef
          .where('teacher_id', isEqualTo: teacherId)
          .limit(600)
          .get();

      TeachingShift? nextShiftAnyDate;
      TeachingShift? nextShiftOnTargetDate;
      for (final doc in snapshot.docs) {
        try {
          final rawData = doc.data();
          final shift = TeachingShift.fromFirestore(doc);
          final status = shift.status.name;
          if (status == 'completed' ||
              status == 'cancelled' ||
              status == 'missed') {
            continue;
          }

          final studentIds = _extractShiftStudentIds(rawData, shift);
          final studentNames = _extractShiftStudentNames(rawData, shift);
          if (studentId != null &&
              studentId.isNotEmpty &&
              !studentIds.contains(studentId.trim())) {
            continue;
          }
          if (studentName != null && studentName.isNotEmpty) {
            if (!_matchesStudentNameQuery(studentNames, studentName)) continue;
          }

          final shiftStartUtc = shift.shiftStart.toUtc();
          if (!shiftStartUtc.isAfter(now)) continue;

          if (nextShiftAnyDate == null ||
              shiftStartUtc.isBefore(nextShiftAnyDate.shiftStart.toUtc())) {
            nextShiftAnyDate = shift;
          }

          if (targetDateLocal != null) {
            final localStart = shift.shiftStart.toLocal();
            final sameDay = localStart.year == targetDateLocal.year &&
                localStart.month == targetDateLocal.month &&
                localStart.day == targetDateLocal.day;
            if (!sameDay) continue;
            if (nextShiftOnTargetDate == null ||
                shiftStartUtc
                    .isBefore(nextShiftOnTargetDate.shiftStart.toUtc())) {
              nextShiftOnTargetDate = shift;
            }
          }
        } catch (_) {
          // Skip malformed docs.
        }
      }

      if (targetDateLocal != null &&
          nextShiftOnTargetDate == null &&
          nextShiftAnyDate != null) {
        AppLogger.warning(
          'AI Tutor Teacher Actions: No shift found on requested local date '
          '$targetDateLocal. Falling back to nearest upcoming shift.',
        );
      }

      return targetDateLocal != null
          ? (nextShiftOnTargetDate ?? nextShiftAnyDate)
          : nextShiftAnyDate;
    } catch (e) {
      AppLogger.warning(
          'AI Tutor Teacher Actions: Failed to find upcoming shift: $e');
      return null;
    }
  }

  Future<TeachingShift?> _loadTeacherShiftById({
    required String teacherId,
    required String shiftId,
  }) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('teaching_shifts')
          .doc(shiftId)
          .get();
      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null || data['teacher_id']?.toString() != teacherId) {
        return null;
      }

      return TeachingShift.fromFirestore(doc);
    } catch (e) {
      AppLogger.warning(
          'AI Tutor Teacher Actions: Failed to load shift "$shiftId": $e');
      return null;
    }
  }

  List<String> _extractShiftStudentIds(
    Map<String, dynamic> data,
    TeachingShift shift,
  ) {
    final ids = <String>{
      ...shift.studentIds.map((id) => id.toString().trim()),
      ..._extractStringValues(data, const [
        'student_ids',
        'studentIds',
        'student_id',
        'studentId',
      ]),
    };
    return ids.where((id) => id.isNotEmpty).toList();
  }

  List<String> _extractShiftStudentNames(
    Map<String, dynamic> data,
    TeachingShift shift,
  ) {
    final names = <String>{
      ...shift.studentNames.map((name) => name.toString().trim()),
      ..._extractStringValues(data, const [
        'student_names',
        'studentNames',
        'student_name',
        'studentName',
        'auto_generated_name',
        'custom_name',
      ]),
    };
    return names.where((name) => name.isNotEmpty).toList();
  }

  List<String> _extractStringValues(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    final values = <String>[];
    for (final key in keys) {
      final raw = data[key];
      if (raw == null) continue;
      if (raw is Iterable) {
        for (final value in raw) {
          final text = value.toString().trim();
          if (text.isNotEmpty) values.add(text);
        }
        continue;
      }
      final text = raw.toString().trim();
      if (text.isNotEmpty) values.add(text);
    }
    return values;
  }

  String _normalizeStudentMatchText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _matchesStudentNameQuery(List<String> candidateNames, String rawQuery) {
    final query = _normalizeStudentMatchText(rawQuery);
    if (query.isEmpty) return true;

    final queryTokens = query
        .split(' ')
        .map((token) => token.trim())
        .where((token) => token.length >= 3)
        .where((token) => !_studentMatchStopwords.contains(token))
        .toList(growable: false);

    for (final candidate in candidateNames) {
      final normalizedCandidate = _normalizeStudentMatchText(candidate);
      if (normalizedCandidate.isEmpty) continue;
      if (normalizedCandidate.contains(query) ||
          query.contains(normalizedCandidate)) {
        return true;
      }
      if (queryTokens.isNotEmpty &&
          queryTokens.any((token) => normalizedCandidate.contains(token))) {
        return true;
      }
    }
    return false;
  }

  String _extractArg(Map<String, dynamic> args, List<String> keys) {
    for (final key in keys) {
      final value = args[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  bool? _extractBoolArg(Map<String, dynamic> args, List<String> keys) {
    for (final key in keys) {
      final value = args[key];
      if (value == null) continue;
      if (value is bool) return value;
      final raw = value.toString().trim().toLowerCase();
      if (raw.isEmpty) continue;
      if (raw == 'true' || raw == 'yes' || raw == 'y' || raw == '1') {
        return true;
      }
      if (raw == 'false' || raw == 'no' || raw == 'n' || raw == '0') {
        return false;
      }
    }
    return null;
  }

  String? _normalizeRescheduleScope(String rawScope) {
    final raw = rawScope.trim().toLowerCase();
    if (raw.isEmpty) return null;
    if (raw == 'single' ||
        raw == 'today' ||
        raw == 'today_only' ||
        raw == 'today-only' ||
        raw == 'one_time' ||
        raw == 'one-time') {
      return 'single';
    }
    if (raw == 'future' ||
        raw == 'all_future' ||
        raw == 'all-future' ||
        raw == 'series' ||
        raw == 'recurring') {
      return 'future';
    }
    return null;
  }

  DateTime? _tryParseDateArg(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;

    final dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (dateOnly == null) return null;
    final year = int.tryParse(dateOnly.group(1)!);
    final month = int.tryParse(dateOnly.group(2)!);
    final day = int.tryParse(dateOnly.group(3)!);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  String _extractCallableError(Object error) {
    if (error is FirebaseFunctionsException) {
      return error.message ?? error.code;
    }
    return error.toString();
  }

  Map<String, dynamic> _sanitizeActionData(Map<String, dynamic> source) {
    final sanitized = <String, dynamic>{};
    source.forEach((key, value) {
      final normalized = _normalizeActionValue(value);
      if (normalized != null) {
        sanitized[key] = normalized;
      }
    });
    return sanitized;
  }

  dynamic _normalizeActionValue(dynamic value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is DateTime) return value.toIso8601String();
    if (value is TeachingShift) {
      return {
        'id': value.id,
        'displayName': value.displayName,
        'shiftStart': value.shiftStart.toIso8601String(),
        'shiftEnd': value.shiftEnd.toIso8601String(),
        'status': value.status.name,
      };
    }
    if (value is Iterable) {
      return value
          .map(_normalizeActionValue)
          .where((item) => item != null)
          .toList();
    }
    if (value is Map) {
      final map = <String, dynamic>{};
      value.forEach((key, val) {
        final normalized = _normalizeActionValue(val);
        if (normalized != null) {
          map[key.toString()] = normalized;
        }
      });
      return map;
    }
    return value.toString();
  }

  Future<void> _sendTutorTeacherActionResult({
    required String requestId,
    required String action,
    required bool success,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    final local = _localParticipant;
    if (local == null) {
      AppLogger.debug(
          'AI Tutor Teacher Actions: Cannot send action result - no local participant');
      return;
    }

    final payload = <String, dynamic>{
      'requestId': requestId,
      'action': action,
      'success': success,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
      if (data != null) 'data': data,
    };

    final resultMessage = WhiteboardMessage(
      type: _teacherActionResultMessageType,
      payload: payload,
    );

    try {
      await local.publishData(
        utf8.encode(resultMessage.encode()),
        reliable: true,
        topic: _tutorTeacherActionResultTopic,
      );
      AppLogger.debug(
          'AI Tutor Teacher Actions: Sent result requestId="$requestId" success=$success');
    } catch (e) {
      AppLogger.error(
          'AI Tutor Teacher Actions: Failed to send action result: $e');
    }
  }

  void _showTeacherActionSnackBar(
    String message, {
    required bool success,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        backgroundColor: success ? const Color(0xFF10B981) : Colors.red,
      ),
    );
  }

  void _startAudioLevelMonitoring() {
    _audioLevelTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || _room == null) return;

      // Get remote audio level (from agent)
      double remoteLevel = 0.0;
      for (final participant in _room!.remoteParticipants.values) {
        for (final pub in participant.audioTrackPublications) {
          if (pub.track != null && !pub.muted) {
            remoteLevel = 0.5; // Placeholder
          }
        }
      }

      if (mounted) {
        setState(() {
          _remoteAudioLevel = remoteLevel;
        });
      }
    });
  }

  Future<void> _setMicrophoneEnabled(bool enabled) async {
    final localP = _localParticipant;
    if (localP == null) {
      if (mounted) {
        setState(() => _isMicEnabled = enabled);
      }
      return;
    }

    try {
      await localP.setMicrophoneEnabled(enabled);
      if (mounted) {
        setState(() => _isMicEnabled = enabled);
      }
    } catch (e) {
      AppLogger.error('AI Tutor: Failed to set microphone ($enabled): $e');
      if (mounted) {
        setState(() => _isMicEnabled = enabled);
      }
    }
  }

  Future<void> _toggleMicrophone() async {
    await _setMicrophoneEnabled(!_isMicEnabled);
  }

  bool get _hasRemoteParticipants =>
      _room?.remoteParticipants.isNotEmpty ?? false;

  bool _isLikelyTimeoutError(Object error) {
    final raw = error.toString().toLowerCase();
    return raw.contains('timeoutexception') || raw.contains('timeout');
  }

  Future<bool> _waitForAgentAvailability({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_localParticipant == null || _room == null) return false;
      if (_agentJoined || _hasRemoteParticipants) return true;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return _agentJoined || _hasRemoteParticipants;
  }

  Future<void> _publishChatPayload({
    required LocalParticipant local,
    required String payload,
    required bool reliable,
  }) async {
    final destinationIdentities =
        _room?.remoteParticipants.keys.toList(growable: false) ??
            const <String>[];
    await local.publishData(
      utf8.encode(payload),
      reliable: reliable,
      destinationIdentities:
          destinationIdentities.isEmpty ? null : destinationIdentities,
      topic: _tutorChatTextTopic,
    );
  }

  Future<void> _sendTutorWhiteboardProject(
    Map<String, dynamic> projectData, {
    List<String>? destinationIdentities,
  }) async {
    final local = _localParticipant;
    if (local == null) {
      AppLogger.debug(
          'AI Tutor Whiteboard: Cannot send project - no local participant');
      return;
    }

    final message = WhiteboardMessage(
      type: WhiteboardMessage.typeProject,
      payload: projectData,
    );

    final strokeCount = (projectData['strokes'] as List?)?.length ?? 0;
    AppLogger.debug(
        'AI Tutor Whiteboard: Sending project with $strokeCount strokes');

    _lastWhiteboardProject = projectData;

    try {
      for (final topic in _tutorWhiteboardTopics) {
        await local.publishData(
          utf8.encode(message.encode()),
          reliable: true,
          destinationIdentities: destinationIdentities,
          topic: topic,
        );
      }
      AppLogger.debug('AI Tutor Whiteboard: Project sent successfully');
    } catch (e) {
      AppLogger.error('AI Tutor Whiteboard: Failed to send project: $e');
    }
  }

  /// Capture the whiteboard and send it to the AI tutor as an image
  Future<void> _sendWhiteboardToAI() async {
    if (_isSendingWhiteboard) return;

    final local = _localParticipant;
    if (local == null) {
      AppLogger.debug(
          'AI Tutor: Cannot send whiteboard - no local participant');
      return;
    }

    setState(() => _isSendingWhiteboard = true);

    try {
      // Always push latest project state first so the agent has canonical stroke data.
      final projectForAgent = _lastWhiteboardProject ??
          <String, dynamic>{'strokes': const <dynamic>[], 'version': 2};
      await _sendTutorWhiteboardProject(projectForAgent);

      // Capture a smaller whiteboard image for "Show AI".
      final imageBytes =
          await _whiteboardKey.currentState?.captureWhiteboard(pixelRatio: 1.0);

      // LiveKit data packets have size limits; send image only when compact enough,
      // otherwise send a lightweight analysis request and let the agent use project data.
      const maxPacketBytes = 14 * 1024;
      late final Map<String, dynamic> whiteboardMessage;
      if (imageBytes != null) {
        final imagePayload = {
          'image_base64': base64Encode(imageBytes),
          'mime_type': 'image/png',
          'timestamp': DateTime.now().toIso8601String(),
          'source': 'ai_tutor_show_ai',
          'stroke_count': (projectForAgent['strokes'] as List?)?.length ?? 0,
        };
        final payloadBytes = utf8.encode(json.encode(imagePayload));
        if (payloadBytes.length <= maxPacketBytes) {
          whiteboardMessage = imagePayload;
          AppLogger.info(
              'AI Tutor: Sending whiteboard image payload (${payloadBytes.length} bytes)');
        } else {
          whiteboardMessage = {
            'request': 'analyze_whiteboard',
            'timestamp': DateTime.now().toIso8601String(),
            'source': 'ai_tutor_show_ai',
            'stroke_count': (projectForAgent['strokes'] as List?)?.length ?? 0,
            'reason': 'image_payload_too_large',
          };
          AppLogger.warning(
              'AI Tutor: Whiteboard image payload too large (${payloadBytes.length} bytes), sending analysis request only');
        }
      } else {
        whiteboardMessage = {
          'request': 'analyze_whiteboard',
          'timestamp': DateTime.now().toIso8601String(),
          'source': 'ai_tutor_show_ai',
          'stroke_count': (projectForAgent['strokes'] as List?)?.length ?? 0,
          'reason': 'capture_failed',
        };
        AppLogger.warning(
            'AI Tutor: Whiteboard capture failed, sending analysis request only');
      }

      await local.publishData(
        utf8.encode(json.encode(whiteboardMessage)),
        reliable: true,
        topic: 'whiteboard_image',
      );

      AppLogger.info('AI Tutor: Whiteboard request sent to AI');

      // Show feedback to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.tutorWhiteboardSent),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('AI Tutor: Failed to send whiteboard to AI: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.tutorWhiteboardFailed),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingWhiteboard = false);
      }
    }
  }

  Future<void> _disconnectFromRoom() async {
    final roomToEnd = _roomName;

    _audioLevelTimer?.cancel();
    _listener?.dispose();

    try {
      await _localParticipant?.setMicrophoneEnabled(false);
    } catch (_) {}

    try {
      await _room?.disconnect();
    } catch (_) {}

    _room?.dispose();
    _room = null;
    _localParticipant = null;
    _listener = null;
    _roomName = null;
    _agentJoined = false;

    // Notify backend that session ended
    if (roomToEnd != null) {
      try {
        final callable = _functions.httpsCallable('endAITutorSession');
        await callable.call<Map<String, dynamic>>({'roomName': roomToEnd});
      } catch (e) {
        AppLogger.warning('AI Tutor: Failed to end session: $e');
      }
    }
  }

  Future<void> _endSession() async {
    await _disconnectFromRoom();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: _endSession,
        ),
        actions: [
          if (_preferencesLoaded)
            IconButton(
              icon: Icon(
                Icons.tune_rounded,
                color: isDark ? Colors.white : Colors.black87,
              ),
              tooltip: 'Tutor preferences',
              onPressed: () => unawaited(_openTutorPreferences()),
            ),
        ],
        title: Text(
          l10n.tutorTitle,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: !_preferencesLoaded
            ? _buildLoadingView(l10n)
            : _isLoading
                ? _buildLoadingView(l10n)
                : _error != null
                    ? _buildErrorView(l10n)
                    : _interactionMode == null
                        ? _buildModeSelectionView(l10n, isDark)
                        : _buildConnectedView(l10n, isDark),
      ),
    );
  }

  Widget _buildLoadingView(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0E72ED)),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.tutorConnecting,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelectionView(AppLocalizations l10n, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0E72ED), Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'How would you like to interact?',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose your preferred way to communicate with Alluwal',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            _buildTutorPreferenceSummary(isDark),
            const SizedBox(height: 28),
            // Voice mode button
            _buildModeButton(
              icon: Icons.mic_rounded,
              title: 'Voice',
              subtitle: 'Speak and listen to Alluwal',
              color: const Color(0xFF10B981),
              onTap: () =>
                  unawaited(_selectInteractionMode(TutorInteractionMode.voice)),
              isDark: isDark,
            ),
            const SizedBox(height: 16),
            // Text mode button
            _buildModeButton(
              icon: Icons.chat_rounded,
              title: 'Text',
              subtitle: 'Type messages to Alluwal',
              color: const Color(0xFF0E72ED),
              onTap: () =>
                  unawaited(_selectInteractionMode(TutorInteractionMode.text)),
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.grey.shade400,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTutorPreferenceSummary(bool isDark) {
    final textColor = isDark ? Colors.white70 : Colors.grey.shade700;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;
    final tileColor =
        isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tutor preferences',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.record_voice_over_rounded, size: 16),
              const SizedBox(width: 8),
              Text(
                tutorVoicePreferenceLabel(_voicePreference),
                style: GoogleFonts.inter(fontSize: 13, color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.surround_sound_rounded, size: 16),
              const SizedBox(width: 8),
              Text(
                tutorBackgroundPreferenceLabel(_backgroundPreference),
                style: GoogleFonts.inter(fontSize: 13, color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => unawaited(_openTutorPreferences()),
              icon: const Icon(Icons.tune_rounded, size: 16),
              label: const Text('Change'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0E72ED),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeChoiceChip({
    required bool isDark,
    required bool selected,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF0E72ED)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? const Color(0xFF0E72ED)
                  : (isDark ? Colors.white12 : Colors.grey.shade300),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.grey.shade700),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openTutorPreferences() async {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final initialMode = _interactionMode ?? TutorInteractionMode.voice;
    var draftMode = initialMode;
    var draftVoice = _voicePreference;
    var draftBackground = _backgroundPreference;

    final result = await showModalBottomSheet<_TutorPreferenceSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF17171E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tutor preferences',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Interaction mode',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildModeChoiceChip(
                          isDark: isDark,
                          selected: draftMode == TutorInteractionMode.voice,
                          label: 'Voice',
                          onTap: () => setSheetState(
                            () => draftMode = TutorInteractionMode.voice,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _buildModeChoiceChip(
                          isDark: isDark,
                          selected: draftMode == TutorInteractionMode.text,
                          label: 'Text',
                          onTap: () => setSheetState(
                            () => draftMode = TutorInteractionMode.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Tutor voice',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<TutorVoicePreference>(
                      key: ValueKey<TutorVoicePreference>(draftVoice),
                      initialValue: draftVoice,
                      items: TutorVoicePreference.values
                          .map(
                            (value) => DropdownMenuItem<TutorVoicePreference>(
                              value: value,
                              child: Text(tutorVoicePreferenceLabel(value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => draftVoice = value);
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color:
                                isDark ? Colors.white12 : Colors.grey.shade300,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color:
                                isDark ? Colors.white12 : Colors.grey.shade300,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Background sound',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<TutorBackgroundPreference>(
                      key: ValueKey<TutorBackgroundPreference>(draftBackground),
                      initialValue: draftBackground,
                      items: TutorBackgroundPreference.values
                          .map(
                            (value) =>
                                DropdownMenuItem<TutorBackgroundPreference>(
                              value: value,
                              child:
                                  Text(tutorBackgroundPreferenceLabel(value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => draftBackground = value);
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color:
                                isDark ? Colors.white12 : Colors.grey.shade300,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color:
                                isDark ? Colors.white12 : Colors.grey.shade300,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop(
                            _TutorPreferenceSelection(
                              mode: draftMode,
                              voicePreference: draftVoice,
                              backgroundPreference: draftBackground,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0E72ED),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Apply preferences',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) return;

    final modeChanged = _interactionMode != result.mode;
    final voiceChanged = _voicePreference != result.voicePreference;
    final backgroundChanged =
        _backgroundPreference != result.backgroundPreference;

    setState(() {
      _interactionMode = result.mode;
      _voicePreference = result.voicePreference;
      _backgroundPreference = result.backgroundPreference;
      _isMicEnabled = result.mode == TutorInteractionMode.voice;
    });
    await _saveTutorPreferences();

    if (_room != null && (modeChanged || voiceChanged || backgroundChanged)) {
      await _restartSessionWithCurrentPreferences();
      return;
    }

    if (_room == null && !_isLoading && _interactionMode != null) {
      await _startSession();
    }
  }

  Future<void> _selectInteractionMode(TutorInteractionMode mode) async {
    if (_isLoading) return;

    final previousMode = _interactionMode;

    setState(() {
      _interactionMode = mode;
      _isMicEnabled = mode == TutorInteractionMode.voice;
    });
    await _saveTutorPreferences();

    if (_room == null) {
      await _startSession();
      return;
    }

    if (previousMode == mode) return;
    await _restartSessionWithCurrentPreferences();
  }

  Widget _buildErrorView(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 60,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.tutorConnectionError,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _startSession,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.commonRetry),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E72ED),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedView(AppLocalizations l10n, bool isDark) {
    final isTextMode = _interactionMode == TutorInteractionMode.text;

    return Column(
      children: [
        // Status bar (more compact in text mode)
        if (!isTextMode) _buildTutorStatusBar(l10n, isDark),
        // Main content area
        Expanded(
          child: Stack(
            children: [
              // Chat view (always visible)
              _buildChatView(l10n, isDark),
              // Whiteboard overlay (shown when toggled)
              if (_showWhiteboard)
                Positioned.fill(
                  child: Container(
                    color: isDark ? Colors.black87 : Colors.white,
                    child: Column(
                      children: [
                        // Whiteboard header with close button
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : const Color(0xFFF1F5F9),
                            border: Border(
                              bottom: BorderSide(
                                color: isDark
                                    ? Colors.white12
                                    : Colors.grey.shade200,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.draw_rounded,
                                size: 20,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.grey.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Whiteboard',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              // Show AI button
                              if (_agentJoined)
                                TextButton.icon(
                                  onPressed: _isSendingWhiteboard
                                      ? null
                                      : _sendWhiteboardToAI,
                                  icon: Icon(
                                    _isSendingWhiteboard
                                        ? Icons.hourglass_top_rounded
                                        : Icons.visibility_rounded,
                                    size: 18,
                                  ),
                                  label: Text(l10n.tutorShowAI),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF0E72ED),
                                  ),
                                ),
                              IconButton(
                                onPressed: () =>
                                    setState(() => _showWhiteboard = false),
                                icon: const Icon(Icons.close_rounded),
                                color: isDark
                                    ? Colors.white70
                                    : Colors.grey.shade700,
                              ),
                            ],
                          ),
                        ),
                        // Whiteboard content
                        Expanded(child: _buildWhiteboardView(isDark)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Bottom controls
        _buildBottomControls(l10n, isDark, isTextMode),
      ],
    );
  }

  Widget _buildBottomControls(
      AppLocalizations l10n, bool isDark, bool isTextMode) {
    if (isTextMode) {
      // Text mode: show just whiteboard toggle and end button
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
            ),
          ),
        ),
        child: Row(
          children: [
            // Whiteboard toggle
            IconButton(
              onPressed: () =>
                  setState(() => _showWhiteboard = !_showWhiteboard),
              icon: Icon(
                _showWhiteboard ? Icons.draw_rounded : Icons.draw_outlined,
                color: _showWhiteboard
                    ? const Color(0xFF0E72ED)
                    : (isDark ? Colors.white70 : Colors.grey.shade600),
              ),
              tooltip: 'Whiteboard',
            ),
            const SizedBox(width: 8),
            // Text input (expanded)
            Expanded(
              child: TextField(
                controller: _chatInputController,
                focusNode: _chatInputFocusNode,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: const Color(0xff111827),
                ),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 16,
                    color: const Color(0xff9CA3AF),
                  ),
                  filled: true,
                  fillColor: const Color(0xffF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                      color: Color(0xffE5E7EB),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                      color: Color(0xffE5E7EB),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                      color: Color(0xff0386FF),
                      width: 1.2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendTextMessage(),
              ),
            ),
            const SizedBox(width: 8),
            // Send button
            IconButton(
              onPressed: _sendTextMessage,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(12),
              ),
              icon: const Icon(
                Icons.send,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            // End session button
            GestureDetector(
              onTap: _endSession,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.red.shade400,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.call_end_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Voice mode: show chat composer + call controls
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chat composer (available in voice mode for students and teachers)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatInputController,
                  focusNode: _chatInputFocusNode,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: const Color(0xff111827),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 16,
                      color: const Color(0xff9CA3AF),
                    ),
                    filled: true,
                    fillColor: const Color(0xffF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(
                        color: Color(0xffE5E7EB),
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(
                        color: Color(0xffE5E7EB),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(
                        color: Color(0xff0386FF),
                        width: 1.2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendTextMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _sendTextMessage,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xff0386FF),
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(12),
                ),
                icon: const Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Microphone toggle
              _ControlButton(
                icon: _isMicEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                label: _isMicEnabled ? l10n.tutorMicOn : l10n.tutorMicOff,
                isActive: _isMicEnabled,
                onPressed: _toggleMicrophone,
                activeColor: const Color(0xFF10B981),
                inactiveColor: Colors.red.shade400,
              ),
              // Whiteboard toggle
              _ControlButton(
                icon: _showWhiteboard ? Icons.draw_rounded : Icons.draw_outlined,
                label: 'Board',
                isActive: _showWhiteboard,
                onPressed: () =>
                    setState(() => _showWhiteboard = !_showWhiteboard),
                activeColor: const Color(0xFF0E72ED),
                inactiveColor: Colors.grey.shade500,
              ),
              // End call button
              _ControlButton(
                icon: Icons.call_end_rounded,
                label: l10n.tutorEndSession,
                isActive: false,
                onPressed: _endSession,
                activeColor: Colors.red.shade400,
                inactiveColor: Colors.red.shade400,
                isEndCall: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWhiteboardView(bool isDark) {
    if (!_showWhiteboard) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CallWhiteboard(
          key: _whiteboardKey,
          isTeacher: false,
          studentDrawingEnabled: _studentDrawingEnabled,
          onSendProject: _sendTutorWhiteboardProject,
          projectStream: _whiteboardProjectController.stream,
          onClose: null,
          initialStrokes: null,
        ),
      ),
    );
  }

  Widget _buildChatView(AppLocalizations l10n, bool isDark) {
    // Message list only - input is now in bottom controls
    return _chatMessages.isEmpty
        ? _buildEmptyChatPlaceholder(isDark)
        : ListView.builder(
            controller: _chatScrollController,
            reverse: true,
            padding: const EdgeInsets.all(12),
            itemCount: _chatMessages.length,
            itemBuilder: (context, index) {
              final message = _chatMessages[_chatMessages.length - 1 - index];
              return _buildChatMessageBubble(message, isDark);
            },
          );
  }

  Widget _buildEmptyChatPlaceholder(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Start a conversation',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Type a message or speak to Alluwal',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessageBubble(TutorChatMessage message, bool isDark) {
    final isUser = message.sender == TutorMessageSender.user;

    return Container(
      margin: EdgeInsets.only(
        top: 4,
        bottom: 4,
        left: isUser ? 48 : 12,
        right: isUser ? 12 : 48,
      ),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) _buildAIAvatar(),
          if (!isUser) const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xff0386FF) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color:
                          isUser ? Colors.white : const Color(0xff2D3748),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatMessageTime(message.timestamp),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isUser
                          ? Colors.white.withValues(alpha: 0.7)
                          : const Color(0xff6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xff0386FF).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xff0386FF).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          'AI',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xff0386FF),
          ),
        ),
      ),
    );
  }

  String _formatMessageTime(DateTime timestamp) {
    final hour = timestamp.hour;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate =
        DateTime(timestamp.year, timestamp.month, timestamp.day);
    if (messageDate == today) {
      return '${hour.toString().padLeft(2, '0')}:$minute';
    }
    if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${hour.toString().padLeft(2, '0')}:$minute';
    }
    return '${timestamp.day}/${timestamp.month} ${hour.toString().padLeft(2, '0')}:$minute';
  }

  Future<void> _sendTextMessage() async {
    final text = _chatInputController.text.trim();
    if (text.isEmpty) return;

    // Guard against accidental voice capture while in text mode.
    if (_interactionMode == TutorInteractionMode.text && _isMicEnabled) {
      await _setMicrophoneEnabled(false);
    }

    final local = _localParticipant;
    if (local == null) {
      _showTeacherActionSnackBar('Not connected to session', success: false);
      return;
    }

    if (!_agentJoined && !_hasRemoteParticipants) {
      final ready = await _waitForAgentAvailability();
      if (!ready) {
        _showTeacherActionSnackBar(
          'AI is still connecting. Please try again in a moment.',
          success: false,
        );
        return;
      }
    }

    // Add to local chat history
    final message = TutorChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_user',
      content: text,
      sender: TutorMessageSender.user,
      type: TutorMessageType.text,
    );

    setState(() {
      _chatMessages.add(message);
      _chatInputController.clear();
    });

    // Send via data channel to agent
    // Include response_mode so agent knows whether to respond with voice or text
    final responseMode =
        _interactionMode == TutorInteractionMode.text ? 'text' : 'voice';
    final payload = json.encode({
      'type': 'user_text_message',
      'message_id': message.id,
      'content': text,
      'response_mode': responseMode,
      'timestamp': DateTime.now().toIso8601String(),
    });

    try {
      await _publishChatPayload(
        local: local,
        payload: payload,
        reliable: true,
      );
      AppLogger.info('AI Tutor: Sent text message to agent');
    } catch (e) {
      if (_isLikelyTimeoutError(e)) {
        AppLogger.warning(
          'AI Tutor: Reliable chat send timed out, retrying unreliable: $e',
        );
        try {
          await _publishChatPayload(
            local: local,
            payload: payload,
            reliable: false,
          );
          AppLogger.info('AI Tutor: Sent text message to agent (unreliable)');
          return;
        } catch (retryError) {
          AppLogger.error(
            'AI Tutor: Retry failed to send text message: $retryError',
          );
        }
      } else {
        AppLogger.error('AI Tutor: Failed to send text message: $e');
      }

      if (mounted) {
        setState(() {
          _chatMessages.removeWhere((m) => m.id == message.id);
        });
      }

      if (_chatInputController.text.trim().isEmpty) {
        _chatInputController.text = text;
        _chatInputController.selection = TextSelection.fromPosition(
          TextPosition(offset: _chatInputController.text.length),
        );
      }
      _showTeacherActionSnackBar(
        'Failed to send message. Please try again.',
        success: false,
      );
    }
  }

  void _handleTranscriptionReceived(DataReceivedEvent event) {
    try {
      final text = utf8.decode(event.data, allowMalformed: true);
      final data = json.decode(text) as Map<String, dynamic>;

      final content = data['content']?.toString() ?? '';
      final sender = data['sender']?.toString() ?? '';

      if (content.isEmpty) return;

      final messageType = _interactionMode == TutorInteractionMode.text
          ? TutorMessageType.text
          : TutorMessageType.voiceTranscription;

      final message = TutorChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_$sender',
        content: content,
        sender:
            sender == 'user' ? TutorMessageSender.user : TutorMessageSender.ai,
        type: messageType,
      );

      if (mounted) {
        setState(() {
          _chatMessages.add(message);
        });
      }
    } catch (e) {
      AppLogger.error('AI Tutor: Failed to process transcription: $e');
    }
  }

  Widget _buildTutorStatusBar(AppLocalizations l10n, bool isDark) {
    final title =
        _agentJoined ? l10n.tutorListening : l10n.tutorWaitingForAgent;
    final subtitle = !_studentDrawingEnabled
        ? 'AI is writing on the board...'
        : (_agentJoined ? l10n.tutorSpeakNow : l10n.tutorAgentConnecting);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) => Transform.scale(
                scale: _agentJoined && _remoteAudioLevel > 0
                    ? _pulseAnimation.value
                    : 1.0,
                child: child,
              ),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0E72ED), Color(0xFF6366F1)],
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Icon(
                  _agentJoined
                      ? Icons.record_voice_over_rounded
                      : Icons.smart_toy_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            if (_agentJoined)
              SizedBox(
                height: 24,
                width: 78,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: List.generate(5, (index) {
                    final delay = index * 80;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _AudioWaveBar(
                        delay: delay,
                        isActive: _isMicEnabled,
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TutorPreferenceSelection {
  final TutorInteractionMode mode;
  final TutorVoicePreference voicePreference;
  final TutorBackgroundPreference backgroundPreference;

  const _TutorPreferenceSelection({
    required this.mode,
    required this.voicePreference,
    required this.backgroundPreference,
  });
}

/// Audio wave bar animation widget
class _AudioWaveBar extends StatefulWidget {
  final int delay;
  final bool isActive;

  const _AudioWaveBar({
    required this.delay,
    required this.isActive,
  });

  @override
  State<_AudioWaveBar> createState() => _AudioWaveBarState();
}

class _AudioWaveBarState extends State<_AudioWaveBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted && widget.isActive) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _AudioWaveBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 6,
          height: 40 * (widget.isActive ? _animation.value : 0.3),
          decoration: BoxDecoration(
            color: const Color(0xFF0E72ED),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      },
    );
  }
}

/// Control button widget
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onPressed;
  final Color activeColor;
  final Color inactiveColor;
  final bool isEndCall;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onPressed,
    required this.activeColor,
    required this.inactiveColor,
    this.isEndCall = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isEndCall ? inactiveColor : (isActive ? activeColor : inactiveColor);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: isEndCall ? 70 : 60,
            height: isEndCall ? 70 : 60,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(isEndCall ? 35 : 30),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: isEndCall ? 32 : 28,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
