import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

// Conditional imports - use actual libraries on web, stubs on other platforms
import '../../../utility_functions/html_stub.dart' if (dart.library.html) 'dart:html' as html;
import '../../../utility_functions/ui_web_stub.dart' if (dart.library.html) 'dart:ui_web' as ui;

class ZoomScreen extends StatefulWidget {
  const ZoomScreen({super.key});

  @override
  State<ZoomScreen> createState() => _ZoomScreenState();
}

class _ZoomScreenState extends State<ZoomScreen> {
  static const String _viewType = 'zoom-embed-view';
  bool _iframeRegistered = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _registerIFrame();
    }
  }

  void _registerIFrame() {
    if (_iframeRegistered) return;
    try {
      ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
        final iframe = html.IFrameElement()
          ..src = 'https://zoom.us/'
          ..style.border = '0'
          ..style.height = '100%'
          ..style.width = '100%'
          ..allow = 'camera; microphone; fullscreen; display-capture';
        return iframe;
      });
      _iframeRegistered = true;
    } catch (_) {
      // no-op; will fall back to open-in-new-tab
    }
  }

  void _openZoomNewTab() {
    if (kIsWeb) {
      html.window.open('https://zoom.us/', '_blank');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xffE2E8F0))),
            ),
            child: Row(
              children: [
                const Icon(Icons.video_call, color: Color(0xff1E293B)),
                const SizedBox(width: 8),
                const Text(
                  'Zoom',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff1E293B),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _openZoomNewTab,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open in new tab'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff0386FF),
                    foregroundColor: Colors.white,
                  ),
                )
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffE2E8F0)),
                ),
                child: kIsWeb && _iframeRegistered
                    ? const HtmlElementView(viewType: _viewType)
                    : _FallbackPanel(onOpen: _openZoomNewTab),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FallbackPanel extends StatelessWidget {
  final VoidCallback onOpen;
  const _FallbackPanel({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.open_in_browser, size: 48, color: Color(0xff64748B)),
          const SizedBox(height: 12),
          const Text(
            'Embedding Zoom may be blocked by the site. Use the button above to open it in a new tab.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xff6B7280)),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Zoom'),
          ),
        ],
      ),
    );
  }
}

