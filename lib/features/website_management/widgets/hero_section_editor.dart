import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/landing_page_content.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class HeroSectionEditor extends StatefulWidget {
  final HeroSectionContent content;
  final Function(HeroSectionContent) onChanged;

  const HeroSectionEditor({
    super.key,
    required this.content,
    required this.onChanged,
  });

  @override
  State<HeroSectionEditor> createState() => _HeroSectionEditorState();
}

class _HeroSectionEditorState extends State<HeroSectionEditor> {
  late TextEditingController _badgeController;
  late TextEditingController _headlineController;
  late TextEditingController _subtitleController;
  late TextEditingController _primaryButtonController;
  late TextEditingController _secondaryButtonController;
  late TextEditingController _trustIndicatorController;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _badgeController = TextEditingController(text: widget.content.badgeText);
    _headlineController = TextEditingController(text: widget.content.mainHeadline);
    _subtitleController = TextEditingController(text: widget.content.subtitle);
    _primaryButtonController = TextEditingController(text: widget.content.primaryButtonText);
    _secondaryButtonController = TextEditingController(text: widget.content.secondaryButtonText);
    _trustIndicatorController = TextEditingController(text: widget.content.trustIndicatorText);

    // Add listeners to update content when text changes
    _badgeController.addListener(_onContentChanged);
    _headlineController.addListener(_onContentChanged);
    _subtitleController.addListener(_onContentChanged);
    _primaryButtonController.addListener(_onContentChanged);
    _secondaryButtonController.addListener(_onContentChanged);
    _trustIndicatorController.addListener(_onContentChanged);
  }

  @override
  void dispose() {
    _badgeController.dispose();
    _headlineController.dispose();
    _subtitleController.dispose();
    _primaryButtonController.dispose();
    _secondaryButtonController.dispose();
    _trustIndicatorController.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    final updatedContent = widget.content.copyWith(
      badgeText: _badgeController.text,
      mainHeadline: _headlineController.text,
      subtitle: _subtitleController.text,
      primaryButtonText: _primaryButtonController.text,
      secondaryButtonText: _secondaryButtonController.text,
      trustIndicatorText: _trustIndicatorController.text,
    );
    widget.onChanged(updatedContent);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Editor Panel
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.heroSectionEditor,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.editTheMainLandingPageHero,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xff6B7280),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildFieldSection(
                    title: AppLocalizations.of(context)!.badgeText,
                    description: 'The small badge text at the top of the hero section',
                    controller: _badgeController,
                    maxLines: 2,
                    placeholder: 'Enter badge text...',
                  ),
                  const SizedBox(height: 24),
                  _buildFieldSection(
                    title: AppLocalizations.of(context)!.mainHeadline,
                    description: 'The primary headline that grabs attention',
                    controller: _headlineController,
                    maxLines: 3,
                    placeholder: 'Enter main headline...',
                    isLarge: true,
                  ),
                  const SizedBox(height: 24),
                  _buildFieldSection(
                    title: AppLocalizations.of(context)!.subtitle,
                    description: 'Supporting text that explains your value proposition',
                    controller: _subtitleController,
                    maxLines: 4,
                    placeholder: 'Enter subtitle...',
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFieldSection(
                          title: AppLocalizations.of(context)!.primaryButton,
                          description: 'Main call-to-action button text',
                          controller: _primaryButtonController,
                          maxLines: 1,
                          placeholder: 'Button text...',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildFieldSection(
                          title: AppLocalizations.of(context)!.secondaryButton,
                          description: 'Secondary action button text',
                          controller: _secondaryButtonController,
                          maxLines: 1,
                          placeholder: 'Button text...',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildFieldSection(
                    title: AppLocalizations.of(context)!.trustIndicator,
                    description: 'Text that builds trust and credibility',
                    controller: _trustIndicatorController,
                    maxLines: 2,
                    placeholder: 'Enter trust indicator...',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          // Preview Panel
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.livePreview,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff111827),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPreview(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldSection({
    required String title,
    required String description,
    required TextEditingController controller,
    required int maxLines,
    required String placeholder,
    bool isLarge = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xff374151),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xff6B7280),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.inter(
            fontSize: isLarge ? 16 : 14,
            fontWeight: isLarge ? FontWeight.w600 : FontWeight.w400,
            color: const Color(0xff111827),
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: GoogleFonts.inter(
              fontSize: isLarge ? 16 : 14,
              color: const Color(0xff9CA3AF),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xff3B82F6), width: 2),
            ),
            filled: true,
            fillColor: const Color(0xffF9FAFB),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xffFAFBFF),
            Color(0xffF0F7FF),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffE5E7EB)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Badge
          if (_badgeController.text.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xff3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: const Color(0xff3B82F6).withOpacity(0.2),
                ),
              ),
              child: Text(
                _badgeController.text,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xff3B82F6),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          if (_badgeController.text.isNotEmpty) const SizedBox(height: 16),
          
          // Main Headline
          if (_headlineController.text.isNotEmpty)
            Text(
              _headlineController.text,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: const Color(0xff111827),
                height: 1.1,
              ),
              textAlign: TextAlign.center,
            ),
          if (_headlineController.text.isNotEmpty) const SizedBox(height: 12),
          
          // Subtitle
          if (_subtitleController.text.isNotEmpty)
            Text(
              _subtitleController.text,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xff6B7280),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          if (_subtitleController.text.isNotEmpty) const SizedBox(height: 20),
          
          // CTA Buttons
          if (_primaryButtonController.text.isNotEmpty || _secondaryButtonController.text.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_primaryButtonController.text.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: const LinearGradient(
                        colors: [Color(0xff3B82F6), Color(0xff1E40AF)],
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        _primaryButtonController.text,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                if (_primaryButtonController.text.isNotEmpty && _secondaryButtonController.text.isNotEmpty)
                  const SizedBox(width: 8),
                if (_secondaryButtonController.text.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xff3B82F6)),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      _secondaryButtonController.text,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff3B82F6),
                      ),
                    ),
                  ),
              ],
            ),
          if ((_primaryButtonController.text.isNotEmpty || _secondaryButtonController.text.isNotEmpty) && _trustIndicatorController.text.isNotEmpty)
            const SizedBox(height: 16),
          
          // Trust Indicator
          if (_trustIndicatorController.text.isNotEmpty)
            Text(
              _trustIndicatorController.text,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: const Color(0xff9CA3AF),
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
} 