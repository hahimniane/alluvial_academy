import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CurriculumBooksScreen extends StatelessWidget {
  const CurriculumBooksScreen({super.key});

  static const _baseUrl =
      'https://storage.googleapis.com/alluwal-academy.firebasestorage.app/curriculum';

  static const List<_CurriculumBook> _books = [
    _CurriculumBook(
      title: 'الحُرُوفُ الهِجَائِيَّةُ وَالمَفْتُوحَةُ',
      subtitle: 'Alphabet and open-vowel practice',
      description:
          'Foundational Arabic letters material used for early reading and pronunciation lessons.',
      pdfUrl: '$_baseUrl/alphabet_and_fatha.pdf',
      downloadUrl: '$_baseUrl/alphabet_and_fatha.pptx',
      fileName: 'alphabet_and_fatha.pptx',
      accentColor: Color(0xff0F766E),
    ),
    _CurriculumBook(
      title: 'الحُرُوفُ المَضْمُومَةُ',
      subtitle: 'Damma lessons',
      description:
          'Curriculum slides for Arabic letters with damma reading and repetition practice.',
      pdfUrl: '$_baseUrl/damma_lessons.pdf',
      downloadUrl: '$_baseUrl/damma_lessons.pptx',
      fileName: 'damma_lessons.pptx',
      accentColor: Color(0xff2563EB),
    ),
    _CurriculumBook(
      title: 'الحروف المفتوحة',
      subtitle: 'Open-vowel reading practice',
      description:
          'Practice deck for reading and recognizing Arabic letters with fatha.',
      pdfUrl: '$_baseUrl/open_letters_practice.pdf',
      downloadUrl: '$_baseUrl/open_letters_practice.pptx',
      fileName: 'open_letters_practice.pptx',
      accentColor: Color(0xffD97706),
    ),
    _CurriculumBook(
      title: 'الحروف المكسورة',
      subtitle: 'Kasra lessons',
      description:
          'Curriculum slides for kasra reading drills used by teachers and students.',
      pdfUrl: '$_baseUrl/kasra_lessons.pdf',
      downloadUrl: '$_baseUrl/kasra_lessons.pptx',
      fileName: 'kasra_lessons.pptx',
      accentColor: Color(0xff7C3AED),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1100;
    final isTablet = MediaQuery.of(context).size.width >= 700;

    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHero(context),
                  const SizedBox(height: 24),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _books.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isWide ? 2 : 1,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      childAspectRatio: isWide
                          ? 1.55
                          : isTablet
                              ? 1.85
                              : 1.1,
                    ),
                    itemBuilder: (context, index) {
                      return _BookCard(book: _books[index]);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xffECFEFF), Color(0xffEFF6FF)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xffD9F0FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Shared Learning Materials',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xff0369A1),
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Curriculum Books',
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: const Color(0xff0F172A),
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'These are the Arabic curriculum PowerPoints used across classes. Teachers, students, parents, and administrators can open or download them from here.',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: const Color(0xff475569),
              height: 1.6,
            ),
          ),
          if (!kIsWeb) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xffFFF7ED),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xffFED7AA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xffC2410C)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'On phones and tablets, these PowerPoint books open in your browser or presentation app.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff9A3412),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildMetaChip(Icons.people_alt_outlined, 'All roles'),
              _buildMetaChip(Icons.slideshow_outlined, 'PowerPoint files'),
              _buildMetaChip(Icons.menu_book_outlined, 'Arabic curriculum'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xffE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xff475569)),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xff334155),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final _CurriculumBook book;

  const _BookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xffE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: book.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.slideshow_rounded,
                  color: book.accentColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: GoogleFonts.cairo(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xff0F172A),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      book.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: book.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            book.description,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff475569),
              height: 1.6,
            ),
          ),
          const Spacer(),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildActionButton(
                context,
                label: 'Open',
                icon: Icons.open_in_new_rounded,
                filled: true,
                onPressed: () => _openBook(context, book),
              ),
              _buildActionButton(
                context,
                label: AppLocalizations.of(context)!.download,
                icon: Icons.download_rounded,
                filled: false,
                onPressed: () => _downloadBook(context, book),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool filled,
    required VoidCallback onPressed,
  }) {
    final background = filled ? book.accentColor : Colors.transparent;
    final foreground = filled ? Colors.white : book.accentColor;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: book.accentColor.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _openBook(BuildContext context, _CurriculumBook book) async {
    if (kIsWeb) {
      final launched = await launchUrl(
        Uri.parse('${book.pdfUrl}#view=Fit'),
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      );
      if (!launched && context.mounted) {
        _showLaunchFailedSnack(context);
      }
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _CurriculumViewerScreen(book: book),
        ),
      );
    }
  }

  Future<void> _downloadBook(BuildContext context, _CurriculumBook book) async {
    final launched = await launchUrl(
      Uri.parse(book.downloadUrl),
      mode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      webOnlyWindowName: kIsWeb ? '_blank' : null,
    );

    if (!launched && context.mounted) {
      _showLaunchFailedSnack(context);
    }
  }

  void _showLaunchFailedSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Unable to open this curriculum book right now.',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _CurriculumViewerScreen extends StatefulWidget {
  final _CurriculumBook book;
  const _CurriculumViewerScreen({required this.book});

  @override
  State<_CurriculumViewerScreen> createState() =>
      _CurriculumViewerScreenState();
}

class _CurriculumViewerScreenState extends State<_CurriculumViewerScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(
          'https://docs.google.com/gview?embedded=true&url=${Uri.encodeComponent(widget.book.pdfUrl)}'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.book.subtitle,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: () => launchUrl(
              Uri.parse(widget.book.downloadUrl),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

class _CurriculumBook {
  final String title;
  final String subtitle;
  final String description;
  final String pdfUrl;
  final String downloadUrl;
  final String fileName;
  final Color accentColor;

  const _CurriculumBook({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.pdfUrl,
    required this.downloadUrl,
    required this.fileName,
    required this.accentColor,
  });
}
