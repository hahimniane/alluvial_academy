import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String? videoId;
  final ValueChanged<String>? onPlayStarted;
  final bool shouldPause;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    required this.title,
    this.videoId,
    this.onPlayStarted,
    this.shouldPause = false,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showControls = true;
  String _errorMessage = 'Failed to load video';

  static const _skipDuration = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldPause && (_controller?.value.isPlaying ?? false)) {
      _controller?.pause();
    }
  }

  Future<void> _initPlayer() async {
    try {
      final ctrl =
          VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      _controller = ctrl;
      await ctrl.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
      ctrl.addListener(_onPlayerUpdate);
    } catch (e) {
      final msg = e.toString();
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = msg.contains('PlatformException')
              ? 'Video player not available. Try rebuilding the app.'
              : 'Failed to load video';
        });
      }
    }
  }

  void _onPlayerUpdate() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onPlayerUpdate);
    _controller?.dispose();
    super.dispose();
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

  void _togglePlay() {
    final ctrl = _controller;
    if (ctrl == null) return;
    if (ctrl.value.isPlaying) {
      ctrl.pause();
    } else {
      widget.onPlayStarted?.call(widget.videoId ?? widget.videoUrl);
      ctrl.play();
    }
  }

  void _seekBackward() {
    final ctrl = _controller;
    if (ctrl == null) return;
    final newPos = ctrl.value.position - _skipDuration;
    ctrl.seekTo(newPos < Duration.zero ? Duration.zero : newPos);
  }

  void _seekForward() {
    final ctrl = _controller;
    if (ctrl == null) return;
    final newPos = ctrl.value.position + _skipDuration;
    final max = ctrl.value.duration;
    ctrl.seekTo(newPos > max ? max : newPos);
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  void _enterFullscreen() {
    final ctrl = _controller;
    if (ctrl == null || !_isInitialized) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => _FullscreenVideoPage(
          controller: ctrl,
          title: widget.title,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 36, color: Color(0xFFEF4444)),
              const SizedBox(height: 8),
              Text(_errorMessage,
                  style: GoogleFonts.inter(
                      fontSize: 14, color: const Color(0xFF6B7280)),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _hasError = false);
                  _initPlayer();
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text('Retry', style: GoogleFonts.inter(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E72ED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ),
      );
    }

    final ctrl = _controller!;
    final value = ctrl.value;
    final progress = value.duration.inMilliseconds > 0
        ? value.position.inMilliseconds / value.duration.inMilliseconds
        : 0.0;

    final maxVideoHeight = kIsWeb ? 360.0 : 300.0;

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: Colors.black,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Video + overlay controls
              GestureDetector(
                onTap: _toggleControls,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxVideoHeight),
                  child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: ctrl.value.aspectRatio > 0
                          ? ctrl.value.aspectRatio
                          : 16 / 9,
                      child: VideoPlayer(ctrl),
                    ),
                    if (_showControls || !value.isPlaying)
                      Container(
                        color: Colors.black38,
                        child: AspectRatio(
                          aspectRatio: ctrl.value.aspectRatio > 0
                              ? ctrl.value.aspectRatio
                              : 16 / 9,
                          child: Stack(
                            children: [
                              // Center: rewind / play / forward
                              Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _overlayButton(
                                      Icons.replay_10_rounded,
                                      _seekBackward,
                                      size: 40,
                                    ),
                                    const SizedBox(width: 24),
                                    _overlayButton(
                                      value.isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      _togglePlay,
                                      size: 56,
                                      iconSize: 34,
                                    ),
                                    const SizedBox(width: 24),
                                    _overlayButton(
                                      Icons.forward_10_rounded,
                                      _seekForward,
                                      size: 40,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                ),
              ),
              // Bottom controls bar
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: const Color(0xFF0F172A),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Scrubber slider
                    SliderTheme(
                      data: const SliderThemeData(
                        trackHeight: 3,
                        thumbShape:
                            RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape:
                            RoundSliderOverlayShape(overlayRadius: 14),
                        activeTrackColor: Color(0xFF0E72ED),
                        inactiveTrackColor: Color(0xFF334155),
                        thumbColor: Colors.white,
                        overlayColor: Color(0x330E72ED),
                      ),
                      child: Slider(
                        value: progress.clamp(0.0, 1.0),
                        onChanged: (v) {
                          final pos = Duration(
                            milliseconds:
                                (v * value.duration.inMilliseconds).round(),
                          );
                          ctrl.seekTo(pos);
                        },
                      ),
                    ),
                    // Time + buttons row
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _togglePlay,
                            child: Icon(
                              value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: _seekBackward,
                            child: const Icon(Icons.replay_10_rounded,
                                color: Colors.white70, size: 20),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _seekForward,
                            child: const Icon(Icons.forward_10_rounded,
                                color: Colors.white70, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _formatDuration(value.position),
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500),
                          ),
                          Text(
                            ' / ',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: Colors.white38),
                          ),
                          Text(
                            _formatDuration(value.duration),
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _enterFullscreen,
                            child: const Icon(Icons.fullscreen_rounded,
                                color: Colors.white70, size: 22),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overlayButton(IconData icon, VoidCallback onTap,
      {double size = 44, double? iconSize}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(size / 2),
        ),
        child: Icon(icon, color: Colors.white, size: iconSize ?? size * 0.55),
      ),
    );
  }
}

// ───────────────────── FULLSCREEN VIDEO PAGE ─────────────────────

class _FullscreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;
  final String title;

  const _FullscreenVideoPage({
    required this.controller,
    required this.title,
  });

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  bool _showControls = true;

  static const _skipDuration = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onUpdate);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUpdate);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
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

  void _togglePlay() {
    final ctrl = widget.controller;
    if (ctrl.value.isPlaying) {
      ctrl.pause();
    } else {
      ctrl.play();
    }
  }

  void _seekBackward() {
    final ctrl = widget.controller;
    final newPos = ctrl.value.position - _skipDuration;
    ctrl.seekTo(newPos < Duration.zero ? Duration.zero : newPos);
  }

  void _seekForward() {
    final ctrl = widget.controller;
    final newPos = ctrl.value.position + _skipDuration;
    final max = ctrl.value.duration;
    ctrl.seekTo(newPos > max ? max : newPos);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final value = ctrl.value;
    final progress = value.duration.inMilliseconds > 0
        ? value.position.inMilliseconds / value.duration.inMilliseconds
        : 0.0;

    return Material(
      color: Colors.black,
      child: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: ctrl.value.aspectRatio > 0
                    ? ctrl.value.aspectRatio
                    : 16 / 9,
                child: VideoPlayer(ctrl),
              ),
            ),
            if (_showControls) ...[
              Container(color: Colors.black38),
              // Top bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 28),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Center: rewind / play / forward
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _fsButton(Icons.replay_10_rounded, _seekBackward,
                        size: 48),
                    const SizedBox(width: 32),
                    _fsButton(
                      value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      _togglePlay,
                      size: 64,
                      iconSize: 40,
                    ),
                    const SizedBox(width: 32),
                    _fsButton(Icons.forward_10_rounded, _seekForward,
                        size: 48),
                  ],
                ),
              ),
              // Bottom controls
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SliderTheme(
                          data: const SliderThemeData(
                            trackHeight: 4,
                            thumbShape: RoundSliderThumbShape(
                                enabledThumbRadius: 7),
                            overlayShape: RoundSliderOverlayShape(
                                overlayRadius: 16),
                            activeTrackColor: Color(0xFF0E72ED),
                            inactiveTrackColor: Color(0xFF334155),
                            thumbColor: Colors.white,
                            overlayColor: Color(0x330E72ED),
                          ),
                          child: Slider(
                            value: progress.clamp(0.0, 1.0),
                            onChanged: (v) {
                              final pos = Duration(
                                milliseconds: (v *
                                        value.duration.inMilliseconds)
                                    .round(),
                              );
                              ctrl.seekTo(pos);
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              Text(
                                _formatDuration(value.position),
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500),
                              ),
                              Text(
                                ' / ',
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: Colors.white38),
                              ),
                              Text(
                                _formatDuration(value.duration),
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Icon(
                                    Icons.fullscreen_exit_rounded,
                                    color: Colors.white,
                                    size: 26),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fsButton(IconData icon, VoidCallback onTap,
      {double size = 48, double? iconSize}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(size / 2),
        ),
        child: Icon(icon, color: Colors.white, size: iconSize ?? size * 0.55),
      ),
    );
  }
}
