import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/utils/app_logger.dart';
import '../../../l10n/app_localizations.dart';

/// AI Tutor Screen - Voice interaction with the AI tutor agent
class AITutorScreen extends StatefulWidget {
  const AITutorScreen({super.key});

  @override
  State<AITutorScreen> createState() => _AITutorScreenState();
}

class _AITutorScreenState extends State<AITutorScreen> with SingleTickerProviderStateMixin {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  Room? _room;
  LocalParticipant? _localParticipant;
  EventsListener<RoomEvent>? _listener;

  bool _isLoading = true;
  bool _isConnected = false;
  bool _isMicEnabled = true;
  bool _agentJoined = false;
  String? _error;
  String? _roomName;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Audio level visualization
  double _localAudioLevel = 0.0;
  double _remoteAudioLevel = 0.0;
  Timer? _audioLevelTimer;

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
    _startSession();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioLevelTimer?.cancel();
    _disconnectFromRoom();
    super.dispose();
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

    // Request microphone permissions
    final hasPermissions = await _requestPermissions();
    if (!hasPermissions) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = AppLocalizations.of(context)!.tutorMicPermissionRequired;
      });
      return;
    }

    try {
      // Get token from backend
      final callable = _functions.httpsCallable('getAITutorToken');
      final result = await callable.call<Map<String, dynamic>>({});
      final data = result.data;

      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Failed to start AI tutor session');
      }

      final livekitUrl = data['livekitUrl'] as String;
      final token = data['token'] as String;
      _roomName = data['roomName'] as String;

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
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('permission-denied')) {
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
          dtx: true, // Discontinuous transmission - saves bandwidth during silence
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
        _isConnected = true;
        _isLoading = false;
      });

      // Enable microphone
      try {
        await room.localParticipant?.setMicrophoneEnabled(true);
        if (mounted) {
          setState(() => _isMicEnabled = true);
        }
      } catch (e) {
        AppLogger.warning('AI Tutor: Could not enable microphone: $e');
      }

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
        AppLogger.info('AI Tutor: Participant connected: ${event.participant.identity}');
        if (mounted) {
          setState(() => _agentJoined = true);
        }
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        AppLogger.info('AI Tutor: Participant disconnected: ${event.participant.identity}');
        if (mounted) {
          setState(() => _agentJoined = false);
        }
      })
      ..on<RoomDisconnectedEvent>((event) {
        AppLogger.info('AI Tutor: Disconnected from room. Reason: ${event.reason}');
        if (mounted) {
          setState(() {
            _isConnected = false;
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
      });
  }

  void _startAudioLevelMonitoring() {
    _audioLevelTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || _room == null) return;

      // Get local audio level
      double localLevel = 0.0;
      final localPubs = _localParticipant?.audioTrackPublications ?? [];
      for (final pub in localPubs) {
        if (pub.track != null && !pub.muted) {
          // Approximate level from track
          localLevel = 0.3; // Placeholder - actual level would come from track
        }
      }

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
          _localAudioLevel = localLevel;
          _remoteAudioLevel = remoteLevel;
        });
      }
    });
  }

  Future<void> _toggleMicrophone() async {
    final localP = _localParticipant;
    if (localP == null) return;

    try {
      final newState = !_isMicEnabled;
      await localP.setMicrophoneEnabled(newState);
      if (mounted) {
        setState(() => _isMicEnabled = newState);
      }
    } catch (e) {
      AppLogger.error('AI Tutor: Failed to toggle microphone: $e');
    }
  }

  Future<void> _disconnectFromRoom() async {
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

    // Notify backend that session ended
    if (_roomName != null) {
      try {
        final callable = _functions.httpsCallable('endAITutorSession');
        await callable.call<Map<String, dynamic>>({'roomName': _roomName});
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
      backgroundColor: isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF8FAFC),
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
        child: _isLoading
            ? _buildLoadingView(l10n)
            : _error != null
                ? _buildErrorView(l10n)
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
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // AI Tutor Avatar with pulse animation
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _agentJoined && _remoteAudioLevel > 0
                          ? _pulseAnimation.value
                          : 1.0,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF0E72ED),
                          const Color(0xFF6366F1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(80),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0E72ED).withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        _agentJoined
                            ? Icons.record_voice_over_rounded
                            : Icons.smart_toy_rounded,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Status text
                Text(
                  _agentJoined
                      ? l10n.tutorListening
                      : l10n.tutorWaitingForAgent,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _agentJoined
                      ? l10n.tutorSpeakNow
                      : l10n.tutorAgentConnecting,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 48),
                // Audio wave visualization placeholder
                if (_agentJoined)
                  Container(
                    height: 60,
                    width: 200,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(7, (index) {
                        final delay = index * 100;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
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
        ),
        // Bottom controls
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.white.withOpacity(0.8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Row(
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
        ),
      ],
    );
  }
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

class _AudioWaveBarState extends State<_AudioWaveBar> with SingleTickerProviderStateMixin {
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
    final color = isEndCall ? inactiveColor : (isActive ? activeColor : inactiveColor);

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
                  color: color.withOpacity(0.4),
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
