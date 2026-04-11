import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

/// Result returned when user confirms sending from the preview screen.
class MediaPreviewResult {
  final String? caption;
  MediaPreviewResult({this.caption});
}

/// Full-screen preview for photos/videos before sending (WhatsApp-style).
class MediaPreviewScreen extends StatefulWidget {
  final File file;
  final bool isVideo;
  final String recipientName;

  const MediaPreviewScreen({
    super.key,
    required this.file,
    required this.isVideo,
    required this.recipientName,
  });

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  final TextEditingController _captionController = TextEditingController();
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    _videoController = VideoPlayerController.file(widget.file);
    try {
      await _videoController!.initialize();
      if (mounted) {
        setState(() => _videoInitialized = true);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            _buildTopBar(),

            // Media preview
            Expanded(child: _buildMediaPreview()),

            // Caption + send
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white, size: 26),
          ),
          const Spacer(),
          Text(
            widget.recipientName,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48), // Balance the close button
        ],
      ),
    );
  }

  Widget _buildMediaPreview() {
    if (widget.isVideo) {
      return _buildVideoPreview();
    }
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 3.0,
      child: Center(
        child: Image.file(
          widget.file,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    if (!_videoInitialized || _videoController == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_videoController!.value.isPlaying) {
            _videoController!.pause();
          } else {
            _videoController!.play();
          }
        });
      },
      child: Center(
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_videoController!),
              if (!_videoController!.value.isPlaying)
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Caption input
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 100),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFD1D5DB),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _captionController,
                style: GoogleFonts.inter(
                  color: const Color(0xFF111827),
                  fontSize: 15,
                ),
                cursorColor: const Color(0xff0386FF),
                decoration: InputDecoration(
                  hintText: 'Add a caption...',
                  hintStyle: GoogleFonts.inter(
                    color: const Color(0xFF6B7280),
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Send button
          GestureDetector(
            onTap: () {
              Navigator.pop(
                context,
                MediaPreviewResult(
                  caption: _captionController.text.trim().isNotEmpty
                      ? _captionController.text.trim()
                      : null,
                ),
              );
            },
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xff0386FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
