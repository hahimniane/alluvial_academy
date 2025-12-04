import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class ZoomScreen extends StatefulWidget {
  const ZoomScreen({super.key});

  @override
  State<ZoomScreen> createState() => _ZoomScreenState();
}

class _ZoomScreenState extends State<ZoomScreen> {
  final TextEditingController _meetingIdController = TextEditingController();
  final TextEditingController _meetingPasswordController = TextEditingController();

  // Default Alluvial Academy Zoom meeting ID
  static const String _defaultMeetingId = '92753792146';

  @override
  void initState() {
    super.initState();
    // Pre-fill with default meeting ID
    _meetingIdController.text = _defaultMeetingId;
  }

  /// Joins the default Alluvial Academy room
  /// Tries Zoom app first, falls back to browser
  Future<void> _joinDefaultRoom() async {
    const defaultRoomUrl = 'https://rochester.zoom.us/j/92753792146';
    const meetingId = '92753792146';
    
    try {
      final httpsUri = Uri.parse(defaultRoomUrl);
      
      // Primary strategy: Open HTTPS URL - Android will show chooser if multiple apps available
      // This works because browsers can handle https:// URLs
      if (await canLaunchUrl(httpsUri)) {
        try {
          // Use externalApplication to open in browser or Zoom app (if installed)
          await launchUrl(
            httpsUri,
            mode: LaunchMode.externalApplication,
          );
          debugPrint('✅ Successfully launched Zoom URL');
          return;
        } catch (e) {
          debugPrint('❌ Launch failed: $e');
        }
      }
      
      // Fallback: Try Zoom app protocol directly
      try {
        final zoomUri = Uri.parse('zoommtg://zoom.us/join?confno=$meetingId');
        if (await canLaunchUrl(zoomUri)) {
          await launchUrl(zoomUri, mode: LaunchMode.externalApplication);
          debugPrint('✅ Opened Zoom app directly');
          return;
        }
      } catch (e) {
        debugPrint('Zoom app protocol not available: $e');
      }
      
      // If all strategies failed, show dialog with link
      if (mounted) {
        _showZoomLinkDialog(defaultRoomUrl);
      }
    } catch (e) {
      debugPrint('❌ Error opening Zoom room: $e');
      if (mounted) {
        _showZoomLinkDialog(defaultRoomUrl);
      }
    }
  }
  
  /// Shows a dialog with the Zoom link that user can copy or open manually
  void _showZoomLinkDialog(String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.videocam, color: Color(0xFF0386FF)),
            const SizedBox(width: 12),
            Text(
              'Open Zoom Meeting',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unable to open Zoom automatically. Please use one of these options:',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: SelectableText(
                url,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF0386FF),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              // Try one more time
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
              if (mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.open_in_browser, size: 18),
            label: Text(
              'Open in Browser',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0386FF),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _meetingIdController.dispose();
    _meetingPasswordController.dispose();
    super.dispose();
  }

  Future<void> _startNewMeeting() async {
    // Always join the default Alluvial Academy room
    await _joinDefaultRoom();
  }

  Future<void> _joinMeeting() async {
    // Always join the default Alluvial Academy room
    await _joinDefaultRoom();
  }

  Future<void> _openZoomWeb() async {
    try {
      final url = Uri.parse('https://zoom.us/');
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening Zoom: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: Text(
          'Zoom Meetings',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xff111827),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xff6B7280)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Start New Meeting Card
            _buildActionCard(
              icon: Icons.videocam,
              title: 'Start New Meeting',
              subtitle: 'Create and host a new Zoom meeting',
              color: const Color(0xFF0386FF),
              onTap: _startNewMeeting,
            ),
            const SizedBox(height: 20),
            
            // Join Meeting Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.login,
                          color: Color(0xFF10B981),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Join Meeting',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              'Enter meeting ID to join',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _meetingIdController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Meeting ID',
                      hintText: 'Enter meeting ID',
                      prefixIcon: const Icon(Icons.numbers),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _meetingPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password (Optional)',
                      hintText: 'Enter meeting password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _joinMeeting,
                      icon: const Icon(Icons.login, size: 20),
                      label: Text(
                        'Join Meeting',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Open Zoom Web Card
            _buildActionCard(
              icon: Icons.open_in_browser,
              title: 'Open Zoom Website',
              subtitle: 'Access Zoom in your browser',
              color: const Color(0xFF64748B),
              onTap: _openZoomWeb,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
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
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}
