import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';

typedef OnPlayStarted = void Function(String podcastId);

class PodcastPlayerWidget extends StatefulWidget {
  final String podcastId;
  final String audioUrl;
  final int durationSeconds;
  final OnPlayStarted? onPlayStarted;
  final bool shouldPause;

  const PodcastPlayerWidget({
    super.key,
    required this.podcastId,
    required this.audioUrl,
    required this.durationSeconds,
    this.onPlayStarted,
    this.shouldPause = false,
  });

  @override
  State<PodcastPlayerWidget> createState() => _PodcastPlayerWidgetState();
}

class _PodcastPlayerWidgetState extends State<PodcastPlayerWidget> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackSpeed = 1.0;

  static const _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _duration = Duration(seconds: widget.durationSeconds);
    _setupPlayer();
  }

  @override
  void didUpdateWidget(covariant PodcastPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldPause && _isPlaying) {
      _player.pause();
    }
  }

  void _setupPlayer() {
    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state == PlayerState.playing);
    });

    _player.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d);
    });

    _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() {
        _position = p;
        _isLoading = false;
        _hasError = false;
      });
    });

    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  bool get _isWebFormatIssue {
    if (!kIsWeb) return false;
    final url = widget.audioUrl.toLowerCase();
    return url.contains('.m4a') || url.contains('.wav');
  }

  Future<void> _togglePlay() async {
    if (_hasError) {
      setState(() {
        _hasError = false;
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        setState(() => _isLoading = true);
        widget.onPlayStarted?.call(widget.podcastId);
        await _playWithMimeFallback(widget.audioUrl);
        await _player.setPlaybackRate(_playbackSpeed);
      }
    } catch (e) {
      if (mounted) {
        final isFormatError = e.toString().contains('Format error') ||
            e.toString().contains('MEDIA_ELEMENT_ERROR');
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = (kIsWeb && isFormatError)
              ? 'This audio format is not supported on web. Try MP3 format or use the mobile app.'
              : 'Failed to play audio';
        });
      }
    }
  }

  Future<void> _playWithMimeFallback(String sourceUrl) async {
    final mimeCandidates = _buildMimeCandidates(sourceUrl);
    Object? lastError;

    for (final mimeType in mimeCandidates) {
      try {
        await _player.play(UrlSource(sourceUrl, mimeType: mimeType));
        return;
      } catch (e) {
        lastError = e;
      }
    }

    if (lastError != null) {
      throw lastError;
    }
  }

  List<String?> _buildMimeCandidates(String sourceUrl) {
    final candidates = <String?>[];

    void addCandidate(String? mime) {
      final normalized = mime?.trim();
      if (normalized == null || normalized.isEmpty) {
        if (!candidates.contains(null)) {
          candidates.add(null);
        }
        return;
      }
      if (!candidates.contains(normalized)) {
        candidates.add(normalized);
      }
    }

    final lower = sourceUrl.toLowerCase();
    if (lower.contains('.m4a') || lower.contains('.mp4')) {
      addCandidate('audio/mp4');
      addCandidate('audio/x-m4a');
      addCandidate('audio/m4a');
    } else if (lower.contains('.mp3')) {
      addCandidate('audio/mpeg');
    } else if (lower.contains('.wav')) {
      addCandidate('audio/wav');
      addCandidate('audio/x-wav');
    } else if (lower.contains('.webm')) {
      addCandidate('audio/webm');
    } else if (lower.contains('.ogg') || lower.contains('.opus')) {
      addCandidate('audio/ogg');
      addCandidate('audio/opus');
    } else if (lower.contains('.aac')) {
      addCandidate('audio/aac');
    }

    // Some browsers handle type sniffing better with no explicit mime type.
    addCandidate(null);

    return candidates;
  }

  void _cycleSpeed() {
    final currentIndex = _speeds.indexOf(_playbackSpeed);
    final nextIndex = (currentIndex + 1) % _speeds.length;
    setState(() => _playbackSpeed = _speeds[nextIndex]);
    _player.setPlaybackRate(_playbackSpeed);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError && _errorMessage.isNotEmpty) {
      return Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFEF4444), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _errorMessage,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: const Color(0xFFB91C1C)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.refresh_rounded,
                      color: Color(0xFFEF4444), size: 18),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isWebFormatIssue &&
        !_isPlaying &&
        _position == Duration.zero &&
        !_isLoading) {
      return Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: Color(0xFFD97706), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'M4A/WAV may not play on web. Use the mobile app or upload MP3.',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: const Color(0xFF92400E)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E72ED).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Color(0xFF0E72ED), size: 22),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: _togglePlay,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _hasError
                      ? const Color(0xFFEF4444).withOpacity(0.1)
                      : const Color(0xFF0E72ED).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF0E72ED),
                        ),
                      )
                    : _hasError
                        ? const Icon(Icons.refresh_rounded,
                            color: Color(0xFFEF4444), size: 26)
                        : Icon(
                            _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: const Color(0xFF0E72ED),
                            size: 28,
                          ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: const Color(0xFF0E72ED),
                      inactiveTrackColor:
                          const Color(0xFF0E72ED).withOpacity(0.15),
                      thumbColor: const Color(0xFF0E72ED),
                      overlayColor: const Color(0xFF0E72ED).withOpacity(0.12),
                    ),
                    child: Slider(
                      value: progress.clamp(0.0, 1.0),
                      onChanged: (value) {
                        final newPosition = Duration(
                          milliseconds:
                              (value * _duration.inMilliseconds).round(),
                        );
                        _player.seek(newPosition);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: _cycleSpeed,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E72ED).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_playbackSpeed}x',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0E72ED),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
