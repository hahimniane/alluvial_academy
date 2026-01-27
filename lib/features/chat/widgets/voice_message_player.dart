import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';

class VoiceMessagePlayer extends StatefulWidget {
  final String audioUrl;
  final int durationSeconds;
  final bool isFromMe;

  const VoiceMessagePlayer({
    super.key,
    required this.audioUrl,
    required this.durationSeconds,
    required this.isFromMe,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _duration = Duration(seconds: widget.durationSeconds);
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          _isLoading = state == PlayerState.playing && _position == Duration.zero;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
          _isLoading = false;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      setState(() => _isLoading = true);
      await _audioPlayer.play(UrlSource(widget.audioUrl));
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    final primaryColor = widget.isFromMe 
        ? Colors.white 
        : const Color(0xff0386FF);
    final secondaryColor = widget.isFromMe 
        ? Colors.white.withOpacity(0.5) 
        : const Color(0xff0386FF).withOpacity(0.3);

    return Container(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: widget.isFromMe 
                    ? Colors.white.withOpacity(0.2) 
                    : const Color(0xff0386FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(22),
              ),
              child: _isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primaryColor,
                      ),
                    )
                  : Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: primaryColor,
                      size: 28,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Waveform and progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Waveform visualization
                SizedBox(
                  height: 28,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(20, (index) {
                      // Create a pseudo-random waveform pattern
                      final heights = [0.4, 0.7, 0.5, 0.9, 0.6, 0.8, 0.4, 0.7, 0.5, 0.9,
                                       0.6, 0.8, 0.4, 0.7, 0.5, 0.9, 0.6, 0.8, 0.4, 0.7];
                      final height = heights[index] * 24;
                      final isPlayed = index / 20 <= progress;
                      
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          height: height,
                          decoration: BoxDecoration(
                            color: isPlayed ? primaryColor : secondaryColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 4),
                
                // Duration text
                Text(
                  _isPlaying || _position > Duration.zero
                      ? _formatDuration(_position)
                      : _formatDuration(_duration),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: widget.isFromMe 
                        ? Colors.white.withOpacity(0.8) 
                        : const Color(0xff64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // Microphone icon
          const SizedBox(width: 8),
          Icon(
            Icons.mic,
            size: 18,
            color: widget.isFromMe 
                ? Colors.white.withOpacity(0.6) 
                : const Color(0xff94A3B8),
          ),
        ],
      ),
    );
  }
}
