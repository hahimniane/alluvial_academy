import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/teaching_shift.dart';
import '../utils/app_logger.dart';

/// LiveKit join token response from Cloud Functions
class LiveKitJoinResult {
  final bool success;
  final String? livekitUrl;
  final String? token;
  final String? roomName;
  final String? userRole;
  final String? displayName;
  final int? expiresInSeconds;
  final String? error;

  LiveKitJoinResult({
    required this.success,
    this.livekitUrl,
    this.token,
    this.roomName,
    this.userRole,
    this.displayName,
    this.expiresInSeconds,
    this.error,
  });

  factory LiveKitJoinResult.fromMap(Map<String, dynamic> data) {
    return LiveKitJoinResult(
      success: data['success'] == true,
      livekitUrl: data['livekitUrl']?.toString(),
      token: data['token']?.toString(),
      roomName: data['roomName']?.toString(),
      userRole: data['userRole']?.toString(),
      displayName: data['displayName']?.toString(),
      expiresInSeconds: data['expiresInSeconds'] as int?,
    );
  }

  factory LiveKitJoinResult.error(String message) {
    return LiveKitJoinResult(
      success: false,
      error: message,
    );
  }
}

/// Service for managing LiveKit video calls within the app
/// 
/// This is a beta video provider alternative to Zoom.
/// Shifts with `videoProvider == livekit` will use this service.
class LiveKitService {
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Request necessary permissions for video calls
  /// 
  /// According to LiveKit docs, we need camera, microphone, and Bluetooth permissions
  /// https://docs.livekit.io/reference/client-sdk-flutter/
  static Future<bool> requestPermissions() async {
    if (kIsWeb) return true; // Web handles permissions differently
    
    try {
      // Request camera and microphone
      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();
      
      // On Android, also request Bluetooth for headset support
      if (!kIsWeb && Platform.isAndroid) {
        await Permission.bluetooth.request();
        await Permission.bluetoothConnect.request();
      }
      
      return cameraStatus.isGranted && micStatus.isGranted;
    } catch (e) {
      AppLogger.error('LiveKitService: Error requesting permissions: $e');
      return false;
    }
  }

  /// Check if the user can currently join the class
  /// Class is accessible from 10 minutes before shift start to 10 minutes after shift end
  static bool canJoinClass(TeachingShift shift) {
    final now = DateTime.now().toUtc();
    final shiftStart = shift.shiftStart.toUtc();
    final shiftEnd = shift.shiftEnd.toUtc();

    // Can join 10 minutes before start until 10 minutes after end
    final joinWindowStart = shiftStart.subtract(const Duration(minutes: 10));
    final joinWindowEnd = shiftEnd.add(const Duration(minutes: 10));

    return !now.isBefore(joinWindowStart) && !now.isAfter(joinWindowEnd);
  }

  /// Get the time until the class can be joined
  static Duration? getTimeUntilCanJoin(TeachingShift shift) {
    final now = DateTime.now().toUtc();
    final shiftStart = shift.shiftStart.toUtc();
    final joinWindowStart = shiftStart.subtract(const Duration(minutes: 10));

    if (now.isBefore(joinWindowStart)) {
      return joinWindowStart.difference(now);
    }
    return null;
  }

  /// Get LiveKit join token from backend
  static Future<LiveKitJoinResult> getJoinToken(String shiftId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return LiveKitJoinResult.error('User not logged in');
      }

      final callable = _functions.httpsCallable('getLiveKitJoinToken');
      final result = await callable.call({'shiftId': shiftId});

      final data = Map<String, dynamic>.from(result.data as Map);
      
      // Debug: Log token info (first 50 chars only for security)
      final token = data['token']?.toString();
      if (token != null) {
        AppLogger.debug('LiveKit: Received token (length: ${token.length}, preview: ${token.substring(0, token.length > 50 ? 50 : token.length)}...)');
        AppLogger.debug('LiveKit: URL: ${data['livekitUrl']}, Room: ${data['roomName']}');
      } else {
        AppLogger.error('LiveKit: No token in response! Data: $data');
      }
      
      return LiveKitJoinResult.fromMap(data);
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error('LiveKitService: Firebase function error: ${e.code} - ${e.message}');
      return LiveKitJoinResult.error(e.message ?? 'Failed to get join token');
    } catch (e) {
      AppLogger.error('LiveKitService: Error getting join token: $e');
      return LiveKitJoinResult.error('Failed to connect to class');
    }
  }

  /// Join a LiveKit class
  /// 
  /// This method:
  /// 1. Gets a join token from the backend
  /// 2. Connects to the LiveKit room
  /// 3. Opens the LiveKit call UI
  static Future<void> joinClass(
    BuildContext context,
    TeachingShift shift, {
    bool isTeacher = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      _showError(context, 'You must be logged in to join the class');
      return;
    }

    // Check if class is joinable
    if (!canJoinClass(shift)) {
      final timeUntil = getTimeUntilCanJoin(shift);
      if (timeUntil != null) {
        final minutes = timeUntil.inMinutes;
        _showInfo(
          context,
          'Class opens in $minutes minute${minutes == 1 ? '' : 's'}',
        );
      } else {
        _showError(context, 'This class has ended');
      }
      return;
    }

    // Request permissions before joining
    final hasPermissions = await requestPermissions();
    if (!hasPermissions && context.mounted) {
      _showError(context, 'Camera and microphone permissions are required');
      return;
    }

    // Show loading indicator
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Expanded(child: Text('Connecting to class...')),
              ],
            ),
          ),
        ),
      );
    }

    try {
      // Get join token from backend
      final joinResult = await getJoinToken(shift.id);

      // Dismiss loading dialog
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (!joinResult.success) {
        if (context.mounted) {
          _showError(context, joinResult.error ?? 'Failed to connect');
        }
        return;
      }

      // Navigate to the LiveKit call screen
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LiveKitCallScreen(
              livekitUrl: joinResult.livekitUrl!,
              token: joinResult.token!,
              roomName: joinResult.roomName!,
              displayName: joinResult.displayName ?? 'Participant',
              isTeacher: isTeacher || joinResult.userRole == 'teacher',
              shiftId: shift.id,
              shiftName: shift.displayName,
            ),
          ),
        );
      }
    } catch (e) {
      // Dismiss loading dialog if still showing
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showError(context, 'Failed to join class: $e');
      }
      AppLogger.error('LiveKitService: Error joining class: $e');
    }
  }

  static void _showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void _showInfo(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// LiveKit call screen - provides the video call UI
class LiveKitCallScreen extends StatefulWidget {
  final String livekitUrl;
  final String token;
  final String roomName;
  final String displayName;
  final bool isTeacher;
  final String shiftId;
  final String shiftName;

  const LiveKitCallScreen({
    super.key,
    required this.livekitUrl,
    required this.token,
    required this.roomName,
    required this.displayName,
    required this.isTeacher,
    required this.shiftId,
    required this.shiftName,
  });

  @override
  State<LiveKitCallScreen> createState() => _LiveKitCallScreenState();
}

class _LiveKitCallScreenState extends State<LiveKitCallScreen> {
  Room? _room;
  LocalParticipant? _localParticipant;
  EventsListener<RoomEvent>? _listener;

  bool _connecting = true;
  bool _micEnabled = true;
  bool _cameraEnabled = true;
  bool _screenShareEnabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _connectToRoom();
  }

  Future<void> _connectToRoom() async {
    try {
      setState(() {
        _connecting = true;
        _error = null;
      });

      // Create room options
      final roomOptions = RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultCameraCaptureOptions: const CameraCaptureOptions(
          maxFrameRate: 30,
          params: VideoParametersPresets.h720_169,
        ),
        defaultAudioCaptureOptions: const AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        ),
        defaultVideoPublishOptions: const VideoPublishOptions(
          simulcast: true,
          videoCodec: 'VP8',
        ),
        defaultAudioPublishOptions: const AudioPublishOptions(
          dtx: true,
        ),
        defaultScreenShareCaptureOptions: const ScreenShareCaptureOptions(
          useiOSBroadcastExtension: true,
          params: VideoParametersPresets.screenShareH1080FPS15,
        ),
      );

      // Create and connect to room
      final room = Room(roomOptions: roomOptions);

      // Set up room event listener
      _listener = room.createListener();
      _setupRoomListeners(_listener!);

      // Debug: Log connection details
      AppLogger.debug('LiveKit: Connecting to ${widget.livekitUrl}');
      AppLogger.debug('LiveKit: Room: ${widget.roomName}');
      AppLogger.debug('LiveKit: Token length: ${widget.token.length}');
      AppLogger.debug('LiveKit: Token preview: ${widget.token.substring(0, widget.token.length > 50 ? 50 : widget.token.length)}...');

      // Connect to the room
      // Try without fastConnectOptions first to see if that's the issue
      try {
        AppLogger.debug('LiveKit: Attempting connection without fastConnectOptions...');
        await room.connect(
          widget.livekitUrl,
          widget.token,
        );
        AppLogger.info('LiveKit: Connected successfully without fastConnectOptions');
      } on LiveKitException catch (e) {
        AppLogger.error('LiveKit: Connection exception - Message: ${e.message}');
        AppLogger.error('LiveKit: Exception details: $e');
        AppLogger.error('LiveKit: Full exception: ${e.toString()}');
        
        // Check if it's a token-related error
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('token') || errorStr.contains('invalid') || errorStr.contains('unauthorized')) {
          AppLogger.error('LiveKit: Token validation failed - this suggests API key/secret mismatch');
          AppLogger.error('LiveKit: Please verify credentials match LiveKit Cloud dashboard');
        }
        rethrow;
      } catch (e) {
        AppLogger.error('LiveKit: Unexpected connection error: $e');
        AppLogger.error('LiveKit: Error type: ${e.runtimeType}');
        rethrow;
      }

      setState(() {
        _room = room;
        _localParticipant = room.localParticipant;
        _connecting = false;
      });

      AppLogger.info('LiveKit: Connected to room ${widget.roomName}');
    } catch (e) {
      AppLogger.error('LiveKit: Failed to connect: $e');
      setState(() {
        _connecting = false;
        _error = 'Failed to connect: $e';
      });
    }
  }

  void _setupRoomListeners(EventsListener<RoomEvent> listener) {
    listener
      ..on<RoomDisconnectedEvent>((event) {
        AppLogger.info('LiveKit: Disconnected from room. Reason: ${event.reason}');
        if (mounted) {
          Navigator.of(context).pop();
        }
      })
      ..on<ParticipantConnectedEvent>((event) {
        AppLogger.info('LiveKit: Participant connected: ${event.participant.identity}');
        setState(() {});
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        AppLogger.info('LiveKit: Participant disconnected: ${event.participant.identity}');
        setState(() {});
      })
      ..on<TrackPublishedEvent>((event) {
        setState(() {});
      })
      ..on<TrackUnpublishedEvent>((event) {
        setState(() {});
      })
      ..on<TrackSubscribedEvent>((event) {
        setState(() {});
      })
      ..on<TrackUnsubscribedEvent>((event) {
        setState(() {});
      })
      ..on<LocalTrackPublishedEvent>((event) {
        setState(() {});
      })
      ..on<LocalTrackUnpublishedEvent>((event) {
        setState(() {});
      });
  }

  Future<void> _toggleMicrophone() async {
    if (_localParticipant == null) return;

    try {
      await _localParticipant!.setMicrophoneEnabled(!_micEnabled);
      setState(() {
        _micEnabled = !_micEnabled;
      });
    } catch (e) {
      AppLogger.error('LiveKit: Failed to toggle mic: $e');
    }
  }

  Future<void> _toggleCamera() async {
    if (_localParticipant == null) return;

    try {
      await _localParticipant!.setCameraEnabled(!_cameraEnabled);
      setState(() {
        _cameraEnabled = !_cameraEnabled;
      });
    } catch (e) {
      AppLogger.error('LiveKit: Failed to toggle camera: $e');
    }
  }

  Future<void> _toggleScreenShare() async {
    if (_localParticipant == null) return;
    if (!widget.isTeacher) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only teachers can share their screen'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      // Call screen share immediately in user gesture handler
      // Note: On web, getDisplayMedia must be called in response to user gesture
      // The LiveKit SDK handles this internally, but we ensure it's called synchronously here
      await _localParticipant!.setScreenShareEnabled(!_screenShareEnabled);
      
      setState(() {
        _screenShareEnabled = !_screenShareEnabled;
      });
    } catch (e) {
      AppLogger.error('LiveKit: Failed to toggle screen share: $e');
      AppLogger.error('LiveKit: Error type: ${e.runtimeType}');
      AppLogger.error('LiveKit: Error details: ${e.toString()}');
      
      if (mounted) {
        String errorMessage = 'Failed to share screen';
        final errorStr = e.toString().toLowerCase();
        
        if (errorStr.contains('notallowed') || errorStr.contains('permission denied')) {
          errorMessage = 'Screen sharing was denied. Please:\n'
              '• Select a screen/window/tab in the browser dialog\n'
              '• Click "Share" (not Cancel)\n'
              '• If using Chrome, check that screen capture is allowed in site settings';
        } else if (errorStr.contains('notreadable') || errorStr.contains('could not start')) {
          errorMessage = 'Could not access screen. Try:\n'
              '• Closing other apps using your screen\n'
              '• Refreshing the page\n'
              '• Stopping your camera first, then sharing screen';
        } else if (errorStr.contains('abort') || errorStr.contains('canceled')) {
          errorMessage = 'Screen sharing was canceled. Click "Share Screen" again and select a source.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Future<void> _leaveCall() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Class?'),
        content: const Text('Are you sure you want to leave this class?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (shouldLeave == true) {
      await _disconnect();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _disconnect() async {
    try {
      _listener?.dispose();
      await _room?.disconnect();
      await _room?.dispose();
    } catch (e) {
      AppLogger.error('LiveKit: Error disconnecting: $e');
    }
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: Text(
          widget.shiftName,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _leaveCall,
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade400),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: _connecting ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 6),
                Text(
                  _connecting ? 'Connecting...' : 'Live',
                  style: TextStyle(
                    color: _connecting ? Colors.orange : Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildControls(),
    );
  }

  Widget _buildBody() {
    if (_connecting) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text(
              'Connecting to class...',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _connectToRoom,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_room == null) {
      return const Center(
        child: Text(
          'Not connected',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return _buildParticipantGrid();
  }

  Widget _buildParticipantGrid() {
    final participants = <Participant>[];

    // Add local participant first
    if (_localParticipant != null) {
      participants.add(_localParticipant!);
    }

    // Add remote participants
    if (_room != null) {
      participants.addAll(_room!.remoteParticipants.values);
    }

    if (participants.isEmpty) {
      return const Center(
        child: Text(
          'Waiting for others to join...',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: participants.length == 1 ? 1 : 2,
        childAspectRatio: 16 / 9,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        return _ParticipantTile(participant: participants[index]);
      },
    );
  }

  Widget _buildControls() {
    return Container(
      color: const Color(0xFF16213E),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ControlButton(
              icon: _micEnabled ? Icons.mic : Icons.mic_off,
              label: _micEnabled ? 'Mute' : 'Unmute',
              isActive: _micEnabled,
              onPressed: _toggleMicrophone,
            ),
            _ControlButton(
              icon: _cameraEnabled ? Icons.videocam : Icons.videocam_off,
              label: _cameraEnabled ? 'Stop Video' : 'Start Video',
              isActive: _cameraEnabled,
              onPressed: _toggleCamera,
            ),
            if (widget.isTeacher)
              _ControlButton(
                icon: _screenShareEnabled
                    ? Icons.stop_screen_share
                    : Icons.screen_share,
                label: _screenShareEnabled ? 'Stop Share' : 'Share Screen',
                isActive: _screenShareEnabled,
                activeColor: Colors.blue,
                onPressed: _toggleScreenShare,
              ),
            _ControlButton(
              icon: Icons.call_end,
              label: 'Leave',
              isActive: true,
              activeColor: Colors.red,
              backgroundColor: Colors.red,
              onPressed: _leaveCall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final Participant participant;

  const _ParticipantTile({required this.participant});

  @override
  Widget build(BuildContext context) {
    // Get video track - prioritize screen share over camera
    VideoTrack? videoTrack;
    VideoTrack? screenShareTrack;
    VideoTrack? cameraTrack;
    
    // Debug: Log all video track publications
    AppLogger.debug('LiveKit: Checking video tracks for participant ${participant.identity}');
    for (final trackPublication in participant.videoTrackPublications) {
      AppLogger.debug('LiveKit: Track publication - name: ${trackPublication.name}, '
          'source: ${trackPublication.source}, subscribed: ${trackPublication.subscribed}, '
          'muted: ${trackPublication.muted}');
      
      if (trackPublication.track != null &&
          trackPublication.subscribed &&
          !trackPublication.muted) {
        final track = trackPublication.track;
        if (track is VideoTrack) {
          // Check if this is a screen share track by examining the source
          // Screen share tracks have a source that indicates screen sharing
          final sourceStr = trackPublication.source.toString().toLowerCase();
          final publicationName = trackPublication.name.toLowerCase();
          
          AppLogger.debug('LiveKit: Found video track - source: $sourceStr, name: $publicationName');
          
          // Check if source or name indicates screen sharing
          if (sourceStr.contains('screen') || publicationName.contains('screen')) {
            AppLogger.info('LiveKit: Detected screen share track for ${participant.identity}');
            screenShareTrack = track;
          } else {
            AppLogger.debug('LiveKit: Detected camera track for ${participant.identity}');
            cameraTrack = track;
          }
        }
      }
    }
    
    // Prioritize screen share over camera
    videoTrack = screenShareTrack ?? cameraTrack;
    
    final isScreenSharing = screenShareTrack != null;
    
    // Debug logging for screen share
    if (isScreenSharing) {
      AppLogger.debug('LiveKit: Participant ${participant.identity} is screen sharing');
    }

    // Check if audio is enabled
    bool audioEnabled = false;
    for (final trackPublication in participant.audioTrackPublications) {
      if (!trackPublication.muted) {
        audioEnabled = true;
        break;
      }
    }

    final isLocal = participant is LocalParticipant;
    final displayName = participant.name.isNotEmpty ? participant.name : participant.identity;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F3460),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isScreenSharing
              ? Colors.orange.shade400
              : (isLocal ? Colors.blue.shade400 : Colors.white24),
          width: isScreenSharing ? 3 : (isLocal ? 2 : 1),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Video view or placeholder
          if (videoTrack != null)
            VideoTrackRenderer(
              videoTrack,
            )
          else
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Colors.blueGrey.shade700,
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // Name overlay at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  if (isScreenSharing)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade600,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.screen_share,
                            size: 12,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Sharing',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Text(
                      isLocal ? '$displayName (You)' : displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!audioEnabled)
                    const Icon(
                      Icons.mic_off,
                      color: Colors.red,
                      size: 16,
                    ),
                ],
              ),
            ),
          ),

          // Speaking indicator
          if (participant.isSpeaking)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: Colors.green, width: 3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color? activeColor;
  final Color? backgroundColor;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    this.activeColor,
    this.backgroundColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ??
        (isActive ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.05));
    final iconColor = activeColor ??
        (isActive ? Colors.white : Colors.white54);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: iconColor),
            onPressed: onPressed,
            padding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: iconColor,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

