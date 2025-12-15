import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// In-app Zoom meeting screen that embeds the Zoom web client
/// This allows teachers to join meetings without leaving the app
class InAppZoomMeetingScreen extends StatefulWidget {
  final String meetingUrl;
  final String? meetingId;
  final String? password;
  final String? displayName;

  const InAppZoomMeetingScreen({
    super.key,
    required this.meetingUrl,
    this.meetingId,
    this.password,
    this.displayName,
  });

  @override
  State<InAppZoomMeetingScreen> createState() => _InAppZoomMeetingScreenState();
}

class _InAppZoomMeetingScreenState extends State<InAppZoomMeetingScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  double _loadingProgress = 0.0;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
      )
      ..enableZoom(true)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onProgress: (int progress) {
            setState(() {
              _loadingProgress = progress / 100;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            // Inject CSS to improve mobile experience
            _injectMobileOptimizations();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
            if (error.isForMainFrame ?? false) {
              setState(() {
                _hasError = true;
                _errorMessage = error.description;
                _isLoading = false;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            debugPrint('WebView navigation to: ${request.url}');
            
            // Handle Zoom deep link - launch externally to open Zoom app
            if (request.url.startsWith('zoomus://')) {
              debugPrint('WebView: Launching Zoom app via deep link');
              _launchZoomApp(request.url);
              return NavigationDecision.prevent;
            }
            
            // Allow all Zoom-related URLs
            if (request.url.contains('zoom.us') ||
                request.url.contains('zoom.com') ||
                request.url.contains('zoomgov.com') ||
                request.url.contains('cloudfunctions.net')) {
              return NavigationDecision.navigate;
            }
            // Allow media permissions URLs
            if (request.url.startsWith('blob:') ||
                request.url.startsWith('data:') ||
                request.url.startsWith('https://') ||
                request.url.startsWith('http://')) {
              return NavigationDecision.navigate;
            }
            // Block unsupported protocols
            debugPrint('WebView: Blocking navigation to unsupported URL: ${request.url}');
            return NavigationDecision.prevent;
          },
        ),
      )
      ..setOnConsoleMessage((message) {
        debugPrint('WebView Console: ${message.message}');
      })
      ..loadRequest(Uri.parse(widget.meetingUrl));
  }

  void _injectMobileOptimizations() {
    // Inject CSS and JS to optimize for mobile in-app experience
    const String css = '''
      body { 
        -webkit-user-select: none;
        -webkit-touch-callout: none;
      }
      /* Hide elements that suggest opening in browser */
      .zm-modal-legacy__footer, 
      .zm-modal-legacy__close,
      [data-testid="open-in-browser"] {
        display: none !important;
      }
    ''';

    _controller.runJavaScript('''
      (function() {
        var style = document.createElement('style');
        style.type = 'text/css';
        style.appendChild(document.createTextNode(`$css`));
        document.head.appendChild(style);
      })();
    ''');
  }

  /// Launch the Zoom app via deep link
  Future<void> _launchZoomApp(String url) async {
    final uri = Uri.parse(url);
    
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      
      if (launched && mounted) {
        // Close this screen since user is joining via the Zoom app
        Navigator.of(context).pop();
      } else if (!launched && mounted) {
        // Zoom app not installed, show message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Zoom app not installed. Please install Zoom to join meetings.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error launching Zoom app: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open Zoom app: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });

    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  void _reloadPage() {
    setState(() {
      _hasError = false;
      _isLoading = true;
    });
    _controller.reload();
  }

  @override
  void dispose() {
    // Restore system UI and orientation
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _isFullScreen
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF0E72ED),
              foregroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _showExitConfirmation(),
              ),
              title: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.videocam,
                      color: Color(0xFF0E72ED),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Zoom Meeting',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (widget.meetingId != null)
                          Text(
                            'ID: ${widget.meetingId}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(_isFullScreen
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen),
                  onPressed: _toggleFullScreen,
                  tooltip: _isFullScreen ? 'Exit fullscreen' : 'Fullscreen',
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _reloadPage,
                  tooltip: 'Reload',
                ),
              ],
            ),
      body: Stack(
        children: [
          // WebView
          if (!_hasError)
            WebViewWidget(controller: _controller),

          // Error state
          if (_hasError)
            _buildErrorState(),

          // Loading indicator
          if (_isLoading && !_hasError)
            _buildLoadingOverlay(),

          // Floating fullscreen button when in fullscreen mode
          if (_isFullScreen)
            Positioned(
              top: 40,
              right: 16,
              child: SafeArea(
                child: Row(
                  children: [
                    _buildFloatingButton(
                      icon: Icons.fullscreen_exit,
                      onPressed: _toggleFullScreen,
                      tooltip: 'Exit fullscreen',
                    ),
                    const SizedBox(width: 8),
                    _buildFloatingButton(
                      icon: Icons.close,
                      onPressed: () => _showExitConfirmation(),
                      tooltip: 'Leave meeting',
                      color: Colors.red,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    Color? color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: (color ?? Colors.black).withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF0E72ED),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.videocam,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Connecting to Zoom...',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                value: _loadingProgress > 0 ? _loadingProgress : null,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF0E72ED),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _loadingProgress > 0
                  ? '${(_loadingProgress * 100).toInt()}%'
                  : 'Please wait...',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Connection Error',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage.isNotEmpty
                    ? _errorMessage
                    : 'Unable to load the Zoom meeting. Please check your internet connection.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white60,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _reloadPage,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0E72ED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showExitConfirmation() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Leave Meeting?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to leave this meeting?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Stay',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Leave',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (shouldExit == true && mounted) {
      Navigator.of(context).pop();
    }
  }
}

/// Helper function to launch Zoom meeting in-app
Future<void> launchZoomMeetingInApp(
  BuildContext context, {
  required String meetingUrl,
  String? meetingId,
  String? password,
  String? displayName,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => InAppZoomMeetingScreen(
        meetingUrl: meetingUrl,
        meetingId: meetingId,
        password: password,
        displayName: displayName,
      ),
    ),
  );
}

