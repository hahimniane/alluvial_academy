import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:alluwalacademyadmin/core/constants/surah_data.dart';
import 'package:alluwalacademyadmin/core/services/surah_podcast_service.dart';
import '../utils/duration_detector.dart';

class UploadPodcastDialog extends StatefulWidget {
  final SurahInfo? preselectedSurah;

  const UploadPodcastDialog({super.key, this.preselectedSurah});

  static Future<bool?> show(BuildContext context, {SurahInfo? surah}) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    if (isMobile) {
      return showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.92,
          child: UploadPodcastDialog(preselectedSurah: surah),
        ),
      );
    }
    return showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          width: 540,
          child: UploadPodcastDialog(preselectedSurah: surah),
        ),
      ),
    );
  }

  @override
  State<UploadPodcastDialog> createState() => _UploadPodcastDialogState();
}

class _UploadPodcastDialogState extends State<UploadPodcastDialog> {
  SurahInfo? _selectedSurah;
  String _language = 'en';
  String _mediaType = 'audio';
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _textContentController = TextEditingController();

  PlatformFile? _pickedFile;
  Uint8List? _fileBytes;
  bool _isUploading = false;
  double _uploadProgress = 0;
  String? _error;

  int _detectedDuration = 0;
  bool _isDetectingDuration = false;

  static const _audioExtensions = ['mp3', 'm4a', 'wav'];
  static const _videoExtensions = ['mp4', 'webm', 'mov'];
  static const _pdfExtensions = ['pdf'];
  static const _maxAudioSizeBytes = 100 * 1024 * 1024;
  static const _maxVideoSizeBytes = 500 * 1024 * 1024;
  static const _maxPdfSizeBytes = 50 * 1024 * 1024;

  List<String> get _allowedExtensions {
    if (_mediaType == 'video') return _videoExtensions;
    if (_mediaType == 'pdf') return _pdfExtensions;
    return _audioExtensions;
  }

  int get _maxFileSizeBytes {
    if (_mediaType == 'video') return _maxVideoSizeBytes;
    if (_mediaType == 'pdf') return _maxPdfSizeBytes;
    return _maxAudioSizeBytes;
  }

  String get _maxFileSizeLabel {
    if (_mediaType == 'video') return '500 MB';
    if (_mediaType == 'pdf') return '50 MB';
    return '100 MB';
  }

  @override
  void initState() {
    super.initState();
    if (widget.preselectedSurah != null) {
      _selectedSurah = widget.preselectedSurah;
      _titleController.text =
          'Introduction to Surah ${widget.preselectedSurah!.nameEn}';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _textContentController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    // On mobile + video: show a source picker (Photos or Files)
    if (!kIsWeb && _mediaType == 'video') {
      _showVideoSourcePicker();
      return;
    }
    await _pickFromFiles();
  }

  void _showVideoSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text('Select video from',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B))),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded,
                      color: Color(0xFF7C3AED), size: 22),
                ),
                title: Text('Photos Library',
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                subtitle: Text('Pick a video from your camera roll',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: const Color(0xFF64748B))),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickVideoFromPhotos();
                },
              ),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E72ED).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.folder_rounded,
                      color: Color(0xFF0E72ED), size: 22),
                ),
                title: Text('Files',
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                subtitle: Text('Browse files on your device',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: const Color(0xFF64748B))),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromFiles();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickVideoFromPhotos() async {
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickVideo(source: ImageSource.gallery);
      if (xFile == null) return;

      final bytes = await xFile.readAsBytes();
      final fileSize = bytes.length;

      if (fileSize > _maxFileSizeBytes) {
        setState(() =>
            _error = 'File is too large. Maximum size is $_maxFileSizeLabel.');
        return;
      }

      final fileName = xFile.name;
      final ext = fileName.split('.').last.toLowerCase();

      setState(() {
        _pickedFile = PlatformFile(
          name: fileName,
          size: fileSize,
          path: xFile.path,
          bytes: bytes,
        );
        _fileBytes = bytes;
        _error = null;
        _detectedDuration = 0;
      });

      await _detectDuration(bytes, 'video/$ext');
    } catch (e) {
      setState(() => _error = 'Failed to pick video: $e');
    }
  }

  Future<void> _pickFromFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;

      if (file.size > _maxFileSizeBytes) {
        setState(() =>
            _error = 'File is too large. Maximum size is $_maxFileSizeLabel.');
        return;
      }

      Uint8List? bytes = file.bytes;
      // On mobile, bytes may be null -- read from path
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }

      setState(() {
        _pickedFile = file;
        _fileBytes = bytes;
        _error = null;
        _detectedDuration = 0;
      });

      if (bytes != null && _mediaType != 'pdf') {
        final ext = file.extension?.toLowerCase() ?? '';
        final mimeType =
            _mediaType == 'video' ? 'video/$ext' : 'audio/$ext';
        await _detectDuration(bytes, mimeType);
      }
    } catch (e) {
      setState(() => _error = 'Failed to pick file: $e');
    }
  }

  Future<void> _detectDuration(Uint8List bytes, String mimeType) async {
    setState(() => _isDetectingDuration = true);
    final dur = await detectMediaDurationFromBytes(bytes, mimeType);
    if (mounted) {
      setState(() {
        _detectedDuration = dur;
        _isDetectingDuration = false;
      });
    }
  }

  bool get _canUpload {
    if (_selectedSurah == null || _titleController.text.trim().isEmpty) {
      return false;
    }
    if (_isUploading) return false;
    if (_mediaType == 'text') {
      return _textContentController.text.trim().isNotEmpty;
    }
    return _pickedFile != null;
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _upload() async {
    if (!_canUpload) return;
    final surah = _selectedSurah!;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _error = null;
    });

    try {
      if (_mediaType == 'text') {
        await SurahPodcastService.saveTextContent(
          surahNumber: surah.number,
          surahNameEn: surah.nameEn,
          surahNameAr: surah.nameAr,
          language: _language,
          title: _titleController.text.trim(),
          textContent: _textContentController.text.trim(),
          description: _descriptionController.text.trim(),
        );
      } else {
        await SurahPodcastService.uploadPodcast(
          fileBytes: _fileBytes,
          filePath: _pickedFile!.path,
          fileName: _pickedFile!.name,
          surahNumber: surah.number,
          surahNameEn: surah.nameEn,
          surahNameAr: surah.nameAr,
          language: _language,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          durationSeconds: _detectedDuration,
          fileSizeBytes: _pickedFile!.size,
          mediaType: _mediaType,
          onProgress: (p) {
            if (mounted) setState(() => _uploadProgress = p);
          },
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _error = 'Upload failed: $e';
        });
      }
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle:
          GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0E72ED), width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E72ED).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Color(0xFF0E72ED), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add Surah Content',
                          style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B))),
                      Text('Audio, video, PDF, or text content',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF64748B))),
                    ],
                  ),
                ),
                IconButton(
                  onPressed:
                      _isUploading ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded,
                      color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Media type tabs
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _mediaTab('audio', Icons.headphones_rounded, 'Audio'),
                  const SizedBox(width: 4),
                  _mediaTab('video', Icons.videocam_rounded, 'Video'),
                  const SizedBox(width: 4),
                  _mediaTab('pdf', Icons.picture_as_pdf_rounded, 'PDF'),
                  const SizedBox(width: 4),
                  _mediaTab('text', Icons.edit_note_rounded, 'Text'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Surah picker
            DropdownButtonFormField<SurahInfo>(
              value: _selectedSurah,
              isExpanded: true,
              decoration: _inputDecoration('Select Surah'),
              items: allSurahs
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                            '${s.number}. ${s.nameEn} (${s.nameAr})',
                            style: GoogleFonts.inter(fontSize: 14)),
                      ))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedSurah = val;
                  if (val != null && _titleController.text.isEmpty) {
                    _titleController.text =
                        'Introduction to Surah ${val.nameEn}';
                  }
                });
              },
            ),
            const SizedBox(height: 16),

            // Language
            DropdownButtonFormField<String>(
              value: _language,
              decoration: _inputDecoration('Language'),
              items: [
                DropdownMenuItem(
                    value: 'en',
                    child: Text('English', style: GoogleFonts.inter())),
                DropdownMenuItem(
                    value: 'fr',
                    child: Text('French', style: GoogleFonts.inter())),
                DropdownMenuItem(
                    value: 'ar',
                    child: Text('Arabic', style: GoogleFonts.inter())),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _language = val);
              },
            ),
            const SizedBox(height: 16),

            // Title
            TextFormField(
              controller: _titleController,
              decoration: _inputDecoration('Title'),
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: _inputDecoration('Description (optional)'),
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Content area depends on media type
            if (_mediaType == 'text') ...[
              TextFormField(
                controller: _textContentController,
                maxLines: 8,
                decoration: _inputDecoration('Enter text content...'),
                style: GoogleFonts.inter(fontSize: 14, height: 1.5),
              ),
            ] else ...[
              // File picker
              InkWell(
                onTap: _isUploading ? null : _pickFile,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _pickedFile != null
                        ? const Color(0xFF10B981).withOpacity(0.05)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _pickedFile != null
                          ? const Color(0xFF10B981).withOpacity(0.4)
                          : const Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _pickedFile != null
                            ? Icons.check_circle_rounded
                            : _mediaType == 'video'
                                ? Icons.video_file_rounded
                                : _mediaType == 'pdf'
                                    ? Icons.picture_as_pdf_rounded
                                    : Icons.audio_file_rounded,
                        size: 36,
                        color: _pickedFile != null
                            ? const Color(0xFF10B981)
                            : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _pickedFile != null
                            ? _pickedFile!.name
                            : 'Tap to select $_mediaType file',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _pickedFile != null
                              ? const Color(0xFF10B981)
                              : const Color(0xFF475569),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _pickedFile != null
                            ? '${(_pickedFile!.size / (1024 * 1024)).toStringAsFixed(1)} MB'
                            : '${_allowedExtensions.map((e) => e.toUpperCase()).join(', ')} · Max $_maxFileSizeLabel',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ),

              // Duration info (auto-detected)
              if (_pickedFile != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 18, color: Color(0xFF64748B)),
                      const SizedBox(width: 10),
                      if (_isDetectingDuration)
                        Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF0E72ED)),
                            ),
                            const SizedBox(width: 8),
                            Text('Detecting duration...',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: const Color(0xFF64748B))),
                          ],
                        )
                      else if (_detectedDuration > 0)
                        Text(
                          'Duration: ${_formatDuration(_detectedDuration)}',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B)),
                        )
                      else
                        Text(
                          'Duration could not be detected',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF94A3B8)),
                        ),
                    ],
                  ),
                ),
              ],
            ],

            const SizedBox(height: 16),

            // Upload progress
            if (_isUploading && _mediaType != 'text') ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _uploadProgress,
                  backgroundColor:
                      const Color(0xFF0E72ED).withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF0E72ED)),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Uploading... ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.inter(
                    fontSize: 13, color: const Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],

            // Error
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFEF4444).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 18, color: Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFFEF4444))),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _isUploading ? null : () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                  child: Text('Cancel',
                      style: GoogleFonts.inter(
                          color: const Color(0xFF6B7280),
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _canUpload ? _upload : null,
                  icon: Icon(
                    _mediaType == 'text'
                        ? Icons.save_rounded
                        : Icons.cloud_upload_rounded,
                    size: 20,
                  ),
                  label: Text(
                    _isUploading
                        ? 'Saving...'
                        : (_mediaType == 'text' ? 'Save' : 'Upload'),
                    style:
                        GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0E72ED),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        const Color(0xFF0E72ED).withOpacity(0.4),
                    disabledForegroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mediaTab(String type, IconData icon, String label) {
    final isSelected = _mediaType == type;
    return Expanded(
      child: GestureDetector(
        onTap: _isUploading
            ? null
            : () {
                setState(() {
                  _mediaType = type;
                  _pickedFile = null;
                  _fileBytes = null;
                  _error = null;
                  _detectedDuration = 0;
                });
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: isSelected
                      ? const Color(0xFF0E72ED)
                      : const Color(0xFF94A3B8)),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF0E72ED)
                      : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
