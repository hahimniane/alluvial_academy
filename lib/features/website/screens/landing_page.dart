import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import '../../../core/widgets/modern_header.dart';
import '../../../core/widgets/fade_in_slide.dart';
import 'program_selection_page.dart';
import 'teacher_application_screen.dart';
import 'team_page.dart';
import '../../../core/constants/pricing_plan_ids.dart'
    show PricingPlanIds;
import '../../../core/models/program_catalog.dart';
import '../../../core/models/public_site_cms_models.dart';
import '../../../core/services/pricing_quote_service.dart';
import '../../../core/services/public_site_cms_service.dart';
import '../../../screens/unified_programs_page.dart';
import 'about_page.dart';

/// Lets [ModernHeader] scroll the landing page when it is already visible.
class LandingSectionScope extends InheritedWidget {
  const LandingSectionScope({
    super.key,
    required this.scrollToSection,
    required super.child,
  });

  final void Function(String? section) scrollToSection;

  static LandingSectionScope? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<LandingSectionScope>();
  }

  @override
  bool updateShouldNotify(LandingSectionScope oldWidget) => false;
}

class LandingPage extends StatefulWidget {
  final String? initialSection;

  const LandingPage({super.key, this.initialSection});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

/// Uniform pricing card height so every tier aligns in the grid.
const double _kLandingPricingCardHeight = 448;

/// Uniform row height for each course link on the landing programs grid.
const double _kLandingCourseRowHeight = 72;

class _LandingPageState extends State<LandingPage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _landingScrollController = ScrollController();
  List<String> _suggestions = [];
  final GlobalKey _programsSectionKey = GlobalKey();
  final GlobalKey _pricingSectionKey = GlobalKey();
  final GlobalKey _aboutSectionKey = GlobalKey();
  final GlobalKey _ctaSectionKey = GlobalKey();
  int _pricingHoursPerWeek = 4;
  /// Firestore public pricing (optional); empty map = use hard-coded defaults.
  PublicSiteCmsPricingDoc _publicPricing = const PublicSiteCmsPricingDoc();
  /// Landing hero background + optional image URLs (fallback to bundled assets).
  PublicSiteLandingDoc _landing = const PublicSiteLandingDoc();
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;
  StreamSubscription<User?>? _authSubscription;

  final List<String> _allSubjects = [
    'Islamic Program (Arabic, Quran, etc...)',
    'AfroLanguages (Pular, Mandingo, Swahili, Wolof, etc...)',
    'After School Tutoring (Math, Science, Physics, etc...)',
    'Adult Literacy (Reading and Writing English & French, etc...)',
    'Coding',
    'Entrepreneurship',
  ];

  @override
  void initState() {
    super.initState();
    // Setup floating animation for hero image
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    
    _floatAnimation = Tween<double>(begin: -10.0, end: 10.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = widget.initialSection?.trim();
      if (s != null && s.isNotEmpty) {
        _scrollToSection(s);
      }
    });
    // Reload CMS whenever auth changes (e.g. after sign-out) and drop cached
    // Firestore broadcast streams so [ModernHeader] social icons get a fresh listener.
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((_) {
      PublicSiteCmsService.invalidatePublicCmsFirestoreBroadcastCaches();
      _loadPublicCms();
    });
  }

  Color get _heroBgColor =>
      Color(PublicSiteLandingDoc.parseHeroBackgroundArgb(_landing.heroBackgroundColorHex));

  /// Navy-style border on hero collage; matches background when using default.
  Color get _heroBorderAccent => _heroBgColor;

  bool get _heroUseLightForeground => _heroBgColor.computeLuminance() < 0.45;

  Color get _heroPrimaryTextColor =>
      _heroUseLightForeground ? Colors.white : const Color(0xff111827);

  Color get _heroSecondaryTextColor => _heroUseLightForeground
      ? Colors.white.withValues(alpha: 0.88)
      : const Color(0xff4B5563);

  Future<void> _loadPublicCms() async {
    final results = await Future.wait<Object>([
      PublicSiteCmsService.getPricingDoc(),
      PublicSiteCmsService.getLandingDoc(),
    ]);
    if (!mounted) return;
    setState(() {
      _publicPricing = results[0] as PublicSiteCmsPricingDoc;
      _landing = results[1] as PublicSiteLandingDoc;
    });
  }

  Widget _heroSlotImage({
    required String networkUrlField,
    required String assetPath,
    BoxFit fit = BoxFit.cover,
  }) {
    final uri = PublicSiteLandingDoc.heroImageUri(networkUrlField);
    if (uri != null) {
      return Image.network(
        uri.toString(),
        fit: fit,
        // Many CDNs (e.g. stock sites) omit CORP headers; default web decode fails
        // with statusCode 0. Prefer <img> on web so the browser loads like a normal page.
        webHtmlElementStrategy:
            kIsWeb ? WebHtmlElementStrategy.prefer : WebHtmlElementStrategy.never,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (_, __, ___) => Image.asset(assetPath, fit: fit),
      );
    }
    return Image.asset(assetPath, fit: fit);
  }

  String _fmtUsd(double v) => '\$${v.toStringAsFixed(2)}';

  PublicSitePlanPricing? _cmsPlan(String planId) => _publicPricing.plans[planId];

  List<String> _pricingBullets(String planId, List<String> defaults) {
    final b = _cmsPlan(planId)?.bullets;
    if (b != null && b.isNotEmpty) return b;
    return defaults;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _searchController.dispose();
    _landingScrollController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    setState(() {
      _suggestions = _allSubjects
          .where((subject) => subject.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _onSuggestionSelected(String subject) {
    final nav = ProgramCatalog.landingSearchRoute(subject);
    if (nav != null) {
      Navigator.push(
        context,
        UnifiedProgramsPageRoutes.fade(
          initialCategory: nav.categoryId,
          initialProgramId: nav.programId,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProgramSelectionPage(initialSubject: subject),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LandingSectionScope(
      scrollToSection: _scrollToSection,
      child: Scaffold(
        backgroundColor: const Color(0xffFAFAFA), // Softer white
        body: Column(
          children: [
            const ModernHeader(),
            Expanded(
              child: SingleChildScrollView(
                controller: _landingScrollController,
                physics: const BouncingScrollPhysics(), // Smoother scroll
                child: Column(
                  children: [
                    _buildHeroSection(),
                    _buildProgramsSection(key: _programsSectionKey),
                    _buildPricingSection(key: _pricingSectionKey),
                    _buildAboutUsSection(key: _aboutSectionKey),
                    _buildEnrollSection(key: _ctaSectionKey),
                    _buildFooterPlaceholder(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToTop() {
    if (!_landingScrollController.hasClients) return;
    _landingScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  void _scrollToSection(String? raw) {
    final section = raw?.trim().toLowerCase();
    if (section == null || section.isEmpty) {
      _scrollToTop();
      return;
    }

    final GlobalKey? key = section == 'programs'
        ? _programsSectionKey
        : section == 'pricing'
            ? _pricingSectionKey
            : section == 'about'
                ? _aboutSectionKey
                : (section == 'contact' ||
                        section == 'enroll' ||
                        section == 'cta')
                    ? _ctaSectionKey
                    : null;

    void ensure() {
      final ctx = key?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
          alignment: 0.06,
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => ensure());
  }

  Widget _buildHeroSection() {
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    final topPad = isDesktop ? 48.0 : 56.0;
    final bottomPad = isDesktop ? 48.0 : 40.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, topPad, 24, bottomPad),
      decoration: BoxDecoration(
        color: _heroBgColor,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: isDesktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 5, child: _buildHeroContent()),
                  const SizedBox(width: 48),
                  Expanded(flex: 5, child: _buildHeroImage()),
                ],
              )
            : Column(
                children: [
                  _buildHeroContent(),
                  const SizedBox(height: 48),
                  _buildHeroImage(),
                ],
              ),
      ),
    );
  }

  Widget _buildHeroContent() {
    final loc = AppLocalizations.of(context)!;
    final w = MediaQuery.sizeOf(context).width;
    final isNarrow = w < 640;
    final headlineSize = isNarrow ? 30.0 : 48.0;
    final searchHeight = isNarrow ? 46.0 : 50.0;
    final searchFontSize = isNarrow ? 14.0 : 15.0;
    final searchShadow = isNarrow
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeInSlide(
          delay: 0.2,
          child:           Text(
            loc.landingHeroHeadline,
            style: GoogleFonts.inter(
              fontSize: headlineSize,
              fontWeight: FontWeight.w700,
              color: _heroPrimaryTextColor,
              height: isNarrow ? 1.22 : 1.2,
            ),
          ),
        ),
        SizedBox(height: isNarrow ? 14 : 18),
        FadeInSlide(
          delay: 0.26,
          child: Text(
            loc.landingHeroSubtitle,
            style: GoogleFonts.inter(
              fontSize: isNarrow ? 15 : 16,
              fontWeight: FontWeight.w400,
              height: 1.45,
              color: _heroSecondaryTextColor,
            ),
          ),
        ),
        SizedBox(height: isNarrow ? 22 : 28),

        // Primary CTA — Explore Our Programs (stronger visual weight than search)
        FadeInSlide(
          delay: 0.35,
          child: Padding(
            padding: EdgeInsets.only(bottom: isNarrow ? 20 : 16),
            child: SizedBox(
              width: isNarrow ? double.infinity : null,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    UnifiedProgramsPageRoutes.fade(),
                  );
                },
                icon: Icon(Icons.apps_rounded, size: isNarrow ? 22 : 20),
                label: Text(
                  loc.heroExplorePrograms,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _heroUseLightForeground
                      ? _heroBgColor
                      : const Color(0xff111827),
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 28 : 36,
                    vertical: isNarrow ? 16 : 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 3,
                  shadowColor: Colors.black.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
        ),

        // Search Bar — secondary path: lighter presence on small screens
        FadeInSlide(
          delay: 0.4,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: searchHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(searchHeight / 2),
                    border: isNarrow
                        ? Border.all(
                            color: Colors.white.withValues(alpha: 0.45),
                            width: 1,
                          )
                        : null,
                    boxShadow: searchShadow,
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onSubmitted: (value) {
                      if (value.isNotEmpty) _onSuggestionSelected(value);
                    },
                    style: GoogleFonts.inter(fontSize: searchFontSize),
                    decoration: InputDecoration(
                      hintText: loc.landingHeroSearchHint,
                      hintStyle: GoogleFonts.inter(
                        color: const Color(0xff9CA3AF),
                        fontSize: searchFontSize,
                      ),
                      suffixIcon: Padding(
                        padding: EdgeInsets.only(right: isNarrow ? 12 : 16),
                        child: Icon(
                          Icons.search,
                          color: const Color(0xff3B82F6),
                          size: isNarrow ? 20 : 22,
                        ),
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isNarrow ? 20 : 24,
                        vertical: isNarrow ? 12 : 14,
                      ),
                    ),
                  ),
                ),

                // Suggestions Dropdown
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8, left: 12, right: 12),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: _suggestions.map((subject) => InkWell(
                        onTap: () => _onSuggestionSelected(subject),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.history, size: 18, color: Color(0xff9CA3AF)),
                              const SizedBox(width: 12),
                              Text(
                                subject,
                                style: GoogleFonts.inter(
                                  fontSize: 15, 
                                  color: const Color(0xff374151),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Our Teachers — secondary CTA
        FadeInSlide(
          delay: 0.45,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TeamPage(
                    initialCategory: 'teacher',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.school_rounded, size: 18),
            label: Text(
              loc.ourTeachers,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _heroPrimaryTextColor.withValues(alpha: 0.95),
              side: BorderSide(
                  color: _heroPrimaryTextColor.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ),

        SizedBox(height: isNarrow ? 22 : 24),

        // Quick Categories - Simple text links/chips
        FadeInSlide(
          delay: 0.5,
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _TextCategoryLink('Islamic Studies',
                  categoryType: CategoryType.islamicStudies, idleTextColor: _heroPrimaryTextColor),
              _TextCategoryLink('Languages',
                  categoryType: CategoryType.languages, idleTextColor: _heroPrimaryTextColor),
              _TextCategoryLink('Adult Literacy',
                  categoryType: CategoryType.adultLiteracy, idleTextColor: _heroPrimaryTextColor),
              _TextCategoryLink('After School Tutoring',
                  categoryType: CategoryType.afterSchoolTutoring, idleTextColor: _heroPrimaryTextColor),
              _TextCategoryLink('Maths', categoryType: CategoryType.math, idleTextColor: _heroPrimaryTextColor),
              _TextCategoryLink('Programming',
                  categoryType: CategoryType.programming, idleTextColor: _heroPrimaryTextColor),
              _TextCategoryLink('English (Students)',
                  categoryType: CategoryType.english, idleTextColor: _heroPrimaryTextColor),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Checkmarks / Features
        FadeInSlide(
          delay: 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFeatureItem('Meet the tutor. Try for free'),
              const SizedBox(height: 8),
              _buildFeatureItem(' Get help with your quran and islamic studies'),
              const SizedBox(height: 8),
              _buildFeatureItem('Get help from our engineers and programmers'),
            ],
          ),
        ),

        const SizedBox(height: 48),

        // Trustpilot / Rating
        FadeInSlide(
          delay: 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Excellent',
                    style: GoogleFonts.inter(
                      color: _heroPrimaryTextColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) => Container(
                      margin: const EdgeInsets.only(right: 2),
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xff00B67A), // Trustpilot Green
                        shape: BoxShape.rectangle,
                      ),
                      child: const Icon(Icons.star, color: Colors.white, size: 16),
                    )),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Trusted by Muslim families worldwide',
                style: GoogleFonts.inter(
                  color: _heroSecondaryTextColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(String text) {
    return Row(
      children: [
        Icon(Icons.check, color: _heroPrimaryTextColor, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: _heroPrimaryTextColor,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroImage() {
    // Using a placeholder composition to mimic the 3-image layout
    // In a real app, you would position actual images here
    return FadeInSlide(
      delay: 0.2,
      beginOffset: const Offset(0.1, 0),
      child: AnimatedBuilder(
        animation: _floatAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _floatAnimation.value),
            child: child,
          );
        },
        child: SizedBox(
          height: 450,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Center Laptop Image (Main)
              Positioned(
                right: 40,
                top: 20,
                bottom: 60,
                width: 400,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(100),
                    ),
                    color: Colors.white,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(36),
                      topRight: Radius.circular(36),
                      bottomLeft: Radius.circular(36),
                      bottomRight: Radius.circular(96),
                    ),
                    child: _heroSlotImage(
                      networkUrlField: _landing.heroMainImageUrl,
                      assetPath: 'assets/background_images/smiling_student.jpg',
                    ),
                  ),
                ),
              ),
              
              // Left Circle (Woman)
              Positioned(
                left: 0,
                bottom: 80,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xffA5D6A7), // Light green accent
                    border: Border.all(color: _heroBorderAccent, width: 4),
                  ),
                  child: ClipOval(
                    child: _heroSlotImage(
                      networkUrlField: _landing.heroLeftImageUrl,
                      assetPath: 'assets/teachers/elham_shifa.jpg',
                    ),
                  ),
                ),
              ),

              // Right Blob (Man)
              Positioned(
                right: 0,
                bottom: 40,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(70),
                      topRight: Radius.circular(70),
                      bottomLeft: Radius.circular(70),
                      bottomRight: Radius.circular(10),
                    ),
                    color: const Color(0xffFFE082), // Amber accent
                    border: Border.all(color: _heroBorderAccent, width: 4),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(66),
                      topRight: Radius.circular(66),
                      bottomLeft: Radius.circular(66),
                      bottomRight: Radius.circular(6),
                    ),
                    child: _heroSlotImage(
                      networkUrlField: _landing.heroRightImageUrl,
                      assetPath: 'assets/teachers/mohammed_kosiah.jpg',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgramsSection({Key? key}) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    final loc = AppLocalizations.of(context)!;

    return Container(
      key: key,
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: isDesktop ? 52 : 44),
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              FadeInSlide(
                delay: 0.1,
                child: Text(
                  loc.landingExploreMainCourses,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: isDesktop ? 32 : 26,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff1e3a5f),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FadeInSlide(
                delay: 0.2,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Text(
                    loc.landingProgramsDescription,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 16, color: const Color(0xff6b7280), height: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              isDesktop
                  ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildCategoryColumn(
                              stretchBody: true,
                              title: loc.navMegaColIslamicAfro,
                              color: const Color(0xff1e88e5),
                              items: [
                                _CourseItem(loc.navMegaLinkIslamicStudies, loc.landingCourseBlurbIslamic, Icons.mosque_rounded, () => Navigator.push(context, UnifiedProgramsPageRoutes.fade(initialCategory: ProgramCatalog.catIslamic))),
                                _CourseItem(loc.navMegaLinkAfroLanguages, loc.landingCourseBlurbAfro, Icons.language_rounded, () => Navigator.push(context, UnifiedProgramsPageRoutes.fade(initialCategory: ProgramCatalog.catLanguages))),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildCategoryColumn(
                              stretchBody: true,
                              title: loc.navMegaColAcademic,
                              color: const Color(0xff43a047),
                              items: [
                                _CourseItem(loc.navMegaLinkMath, loc.landingCourseBlurbMath, Icons.functions_rounded, () => Navigator.push(context, UnifiedProgramsPageRoutes.fade(initialCategory: ProgramCatalog.catMath))),
                                _CourseItem(loc.navMegaLinkProgramming, loc.landingCourseBlurbProgramming, Icons.code_rounded, () => Navigator.push(context, UnifiedProgramsPageRoutes.fade(initialCategory: ProgramCatalog.catProgramming))),
                                _CourseItem(loc.navMegaLinkAdultLiteracy, loc.landingCourseBlurbAdultLiteracy, Icons.menu_book_rounded, () => Navigator.push(context, UnifiedProgramsPageRoutes.fade(initialCategory: ProgramCatalog.catEnglish))),
                                _CourseItem(loc.navMegaLinkAfterSchool, loc.landingCourseBlurbAfterSchool, Icons.school_rounded, () => Navigator.push(context, UnifiedProgramsPageRoutes.fade(initialCategory: ProgramCatalog.catAfterSchool))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        _buildCategoryColumn(
                          stretchBody: false,
                          title: loc.navMegaColIslamicAfro,
                          color: const Color(0xff1e88e5),
                          items: [
                            _CourseItem(loc.navMegaLinkIslamicStudies, loc.landingCourseBlurbIslamic, Icons.mosque_rounded, () => Navigator.push(context, UnifiedProgramsPageRoutes.fade(initialCategory: ProgramCatalog.catIslamic))),
                            _CourseItem(loc.navMegaLinkAfroLanguages, loc.landingCourseBlurbAfro, Icons.language_rounded, () => Navigator.push(context, UnifiedProgramsPageRoutes.fade(initialCategory: ProgramCatalog.catLanguages))),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildCategoryColumn(
                          stretchBody: false,
                          title: loc.navMegaColAcademic,
                          color: const Color(0xff43a047),
                          items: [
                            _CourseItem(loc.navMegaLinkMath, loc.landingCourseBlurbMath, Icons.functions_rounded, () => Navigator.push(context, UnifiedProgramsPageRoutes.fade(initialCategory: ProgramCatalog.catMath))),
                            _CourseItem(loc.navMegaLinkProgramming, loc.landingCourseBlurbProgramming, Icons.code_rounded, () => Navigator.push(context, UnifiedProgramsPageRoutes.fade(initialCategory: ProgramCatalog.catProgramming))),
                            _CourseItem(loc.navMegaLinkAdultLiteracy, loc.landingCourseBlurbAdultLiteracy, Icons.menu_book_rounded, () => Navigator.push(context, UnifiedProgramsPageRoutes.fade(initialCategory: ProgramCatalog.catEnglish))),
                            _CourseItem(loc.navMegaLinkAfterSchool, loc.landingCourseBlurbAfterSchool, Icons.school_rounded, () => Navigator.push(context, UnifiedProgramsPageRoutes.fade(initialCategory: ProgramCatalog.catAfterSchool))),
                          ],
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryColumn({
    required String title,
    required Color color,
    required List<_CourseItem> items,
    bool stretchBody = false,
  }) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++)
          _buildCourseRowTile(
            items[i],
            color,
            showDivider: i < items.length - 1,
          ),
        if (stretchBody) const Spacer(),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe5e7eb)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: stretchBody ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
            ),
            child: Text(
              title,
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
          if (stretchBody)
            Expanded(child: body)
          else
            body,
        ],
      ),
    );
  }

  Widget _buildCourseRowTile(_CourseItem item, Color color, {required bool showDivider}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        hoverColor: const Color(0xfff9fafb),
        splashColor: color.withValues(alpha: 0.08),
        child: Container(
          height: _kLandingCourseRowHeight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            border: showDivider
                ? Border(bottom: BorderSide(color: Colors.grey.shade100))
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(item.icon, size: 22, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff1f2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.35,
                        color: const Color(0xff6b7280),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPricingPlanCard({
    required String trackId,
    required IconData planIcon,
    required String title,
    required String subtitle,
    required Color accent,
    required List<String> features,
    required double cardWidth,
  }) {
    final loc = AppLocalizations.of(context)!;
    final snapshot = PricingQuoteService.buildSnapshotV2(
      trackId: trackId,
      hoursPerWeek: _pricingHoursPerWeek,
      cmsOverrides: _publicPricing.planOverridesForQuotes(),
    );
    final hourly = (snapshot?['hourlyRateUsd'] as num?)?.toDouble() ?? 0;
    final monthly = (snapshot?['monthlyEstimateUsd'] as num?)?.toDouble() ?? 0;
    final discounted = snapshot?['discountApplied'] == true;

    return SizedBox(
      width: cardWidth,
      height: _kLandingPricingCardHeight,
      child: Material(
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xffebe8e3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(17),
                    topRight: Radius.circular(17),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(planIcon, size: 24, color: accent),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        style: GoogleFonts.lora(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xff111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xff6b7280),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${_fmtUsd(hourly)}/${loc.pricingPerHour}',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (trackId != PricingPlanIds.group)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: discounted
                                ? const Color(0xffecfdf3)
                                : const Color(0xfff3f4f6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            loc.pricingDiscountBadge,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: discounted
                                  ? const Color(0xff15803d)
                                  : const Color(0xff6b7280),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      for (final ex in features) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.check_circle, size: 16, color: accent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  ex,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xff4b5563),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        '${_pricingHoursPerWeek} hrs × ${_fmtUsd(hourly)}/hr × ${trackId == PricingPlanIds.group ? '4.33' : '4'} weeks ≈ \$${monthly.toStringAsFixed(0)}/mo',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff374151),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProgramSelectionPage(
                            initialTrackId: trackId,
                            initialPricingPlanSummary: title,
                            initialHoursPerWeek: _pricingHoursPerWeek,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      loc.landingPricingContinueWithPlan,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pricingCardsWrap(double w, AppLocalizations loc) {
    const gap = 16.0;
    final count = 3;
    int cols;
    if (w > 1024) {
      cols = count;
    } else if (w > 640) {
      cols = 2;
    } else {
      cols = 1;
    }
    if (cols > count) cols = count;
    final cardW = (w - gap * (cols - 1)) / cols;

    Widget wrapCard(Widget inner) {
      return SizedBox(
        width: cardW,
        child: _HoverScaleCard(child: inner),
      );
    }

    final children = <Widget>[
      wrapCard(
        _buildPricingPlanCard(
          trackId: PricingPlanIds.islamic,
          planIcon: Icons.mosque_rounded,
          title: loc.pricingTrackIslamicTitle,
          subtitle: loc.pricingTrackIslamicDesc,
          accent: const Color(0xff2563eb),
          features: _pricingBullets(PricingPlanIds.islamic, const [
            '1-on-1 Quran, Arabic, and AdLam',
            'Flexible weekday scheduling',
            'Discount at 4+ hours/week',
          ]),
          cardWidth: cardW,
        ),
      ),
      wrapCard(
        _buildPricingPlanCard(
          trackId: PricingPlanIds.tutoring,
          planIcon: Icons.school_outlined,
          title: loc.pricingTrackTutoringTitle,
          subtitle: loc.pricingTrackTutoringDesc,
          accent: const Color(0xff16a34a),
          features: _pricingBullets(PricingPlanIds.tutoring, const [
            'Math, science, literacy support',
            'Personalized one-on-one coaching',
            'Discount at 4+ hours/week',
          ]),
          cardWidth: cardW,
        ),
      ),
      wrapCard(
        _buildPricingPlanCard(
          trackId: PricingPlanIds.group,
          planIcon: Icons.groups_rounded,
          title: loc.pricingTrackGroupTitle,
          subtitle: loc.pricingTrackGroupDesc,
          accent: const Color(0xff7c3aed),
          features: _pricingBullets(PricingPlanIds.group, const [
            'Weekend group classes',
            'Flat hourly rate',
            'Community learning setting',
          ]),
          cardWidth: cardW,
        ),
      ),
    ];

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: children,
    );
  }

  Widget _buildPricingSection({Key? key}) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    final loc = AppLocalizations.of(context)!;

    return Container(
      key: key,
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: isDesktop ? 52 : 44),
      color: const Color(0xFFF7F5F2),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              FadeInSlide(
                delay: 0.08,
                duration: const Duration(milliseconds: 520),
                beginOffset: const Offset(0, 0.12),
                child: Text(
                  loc.landingTransparentRates,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: isDesktop ? 32 : 26,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff1a1a1a),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FadeInSlide(
                delay: 0.14,
                duration: const Duration(milliseconds: 520),
                beginOffset: const Offset(0, 0.1),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Text(
                    loc.landingPricingDescription,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 16, color: const Color(0xff6b6560), height: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FadeInSlide(
                delay: 0.2,
                duration: const Duration(milliseconds: 480),
                beginOffset: const Offset(0, 0.08),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(8, (i) {
                    final h = i + 1;
                    final selected = h == _pricingHoursPerWeek;
                    return ChoiceChip(
                      label: Text('$h ${loc.pricingHoursPerWeek}'),
                      selected: selected,
                      onSelected: (_) => setState(() => _pricingHoursPerWeek = h),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 28),
              LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  return _pricingCardsWrap(w, loc);
                },
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xfffff3cd),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffffc107)),
                ),
                child: Column(
                  children: [
                    Text(
                      loc.landingPaymentPolicyText1,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xffc62828)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      loc.landingPaymentPolicyText2,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xff374151), height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xffdbeafe),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  loc.landingContactInfo,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xff1e40af)),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: isDesktop ? 300 : double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProgramSelectionPage())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff1e88e5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(loc.landingEnrollNow, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TeacherApplicationScreen()),
                      );
                    },
                    icon: const Icon(Icons.school_outlined, size: 18, color: Color(0xff2563EB)),
                    label: Text(
                      loc.applyToTeach,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff2563EB),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProgramSelectionPage(initialAdditionalStudents: 1),
                        ),
                      );
                    },
                    icon: const Icon(Icons.groups_2_outlined, size: 18, color: Color(0xff2563EB)),
                    label: Text(
                      loc.landingPricingEnrollMultipleStudents,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff2563EB),
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

  Widget _buildEnrollSection({Key? key}) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff001E4E), Color(0xff003399)],
        ),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: isDesktop
            ? Row(
                children: [
                  Expanded(
                    child: FadeInSlide(
                      delay: 0.1,
                      beginOffset: const Offset(-0.2, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.landingCtaTitle,
                            style: GoogleFonts.inter(
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            AppLocalizations.of(context)!.landingCtaBody,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              color: Colors.white.withOpacity(0.9),
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const ProgramSelectionPage(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xff001E4E),
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 4,
                                ),
                                child: Text(
                                  AppLocalizations.of(context)!.landingEnrollNow,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              OutlinedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const TeamPage(
                                        initialCategory: 'teacher',
                                      ),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white, width: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  AppLocalizations.of(context)!.ourTeachers,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 60),
                  Expanded(
                    child: FadeInSlide(
                      delay: 0.3,
                      beginOffset: const Offset(0.2, 0),
                      child: Container(
                        height: 300,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/background_images/smiling_student.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.white.withOpacity(0.1),
                                child: const Center(
                                  child: Icon(Icons.school_rounded, size: 100, color: Colors.white70),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  FadeInSlide(
                    delay: 0.1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.landingCtaTitle,
                          style: GoogleFonts.inter(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)!.landingCtaBody,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ProgramSelectionPage(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xff001E4E),
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.landingEnrollNow,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const TeamPage(
                                    initialCategory: 'teacher',
                                  ),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white, width: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.ourTeachers,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  FadeInSlide(
                    delay: 0.3,
                    child: Container(
                      height: 250,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/background_images/smiling_student.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.white.withOpacity(0.1),
                              child: const Center(
                                child: Icon(Icons.school_rounded, size: 80, color: Colors.white70),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAboutUsSection({Key? key}) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          children: [
            FadeInSlide(
              delay: 0.1,
              child: Text(
                'About Alluwal Education Hub',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: isDesktop ? 42 : 32,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xff111827),
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FadeInSlide(
              delay: 0.2,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Text(
                  'We are fostering a world where diverse knowledge—Islamic, African, and Western—comes together to prepare students for a globalized future.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    color: const Color(0xff6B7280),
                    height: 1.6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
            isDesktop
                ? Row(
                    children: [
                      Expanded(
                        child: FadeInSlide(
                          delay: 0.3,
                          beginOffset: const Offset(-0.2, 0),
                          child: _buildAboutCard(
                            Icons.rocket_launch_rounded,
                            'Our Mission',
                            const Color(0xff3B82F6),
                            'To integrate Islamic, African, and Western education, offering a holistic curriculum that prepares students to navigate and succeed in a diverse world.',
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: FadeInSlide(
                          delay: 0.4,
                          beginOffset: const Offset(0.2, 0),
                          child: _buildAboutCard(
                            Icons.visibility_rounded,
                            'Our Vision',
                            const Color(0xff10B981),
                            'To create an inclusive, inspiring environment where students are encouraged to become leaders in their communities.',
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      FadeInSlide(
                        delay: 0.3,
                        child: _buildAboutCard(
                          Icons.rocket_launch_rounded,
                          'Our Mission',
                          const Color(0xff3B82F6),
                          'To integrate Islamic, African, and Western education, offering a holistic curriculum that prepares students to navigate and succeed in a diverse world.',
                        ),
                      ),
                      const SizedBox(height: 24),
                      FadeInSlide(
                        delay: 0.4,
                        child: _buildAboutCard(
                          Icons.visibility_rounded,
                          'Our Vision',
                          const Color(0xff10B981),
                          'To create an inclusive, inspiring environment where students are encouraged to become leaders in their communities.',
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 40),
            FadeInSlide(
              delay: 0.5,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AboutPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff001E4E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  'Learn More About Us',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCard(IconData icon, String title, Color color, String description) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xffE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: const Color(0xff6B7280),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      color: const Color(0xff111827),
      child: Center(
        child: Text(
          '© 2024 Alluwal Education Hub',
          style: GoogleFonts.inter(color: Colors.white54),
        ),
      ),
    );
  }
}

/// Subtle hover feedback on pricing cards (web/desktop); no-op feel on touch.
class _HoverScaleCard extends StatefulWidget {
  final Widget child;

  const _HoverScaleCard({required this.child});

  @override
  State<_HoverScaleCard> createState() => _HoverScaleCardState();
}

class _HoverScaleCardState extends State<_HoverScaleCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.012 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

enum CategoryType {
  islamicStudies,
  math,
  programming,
  english,
  adultLiteracy,
  languages,
  afterSchoolTutoring,
  general,
}

class _CourseItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _CourseItem(this.title, this.subtitle, this.icon, this.onTap);
}

class _TextCategoryLink extends StatefulWidget {
  final String label;
  final CategoryType categoryType;
  /// Base text color when not hovered (hero uses CMS-driven contrast).
  final Color idleTextColor;

  const _TextCategoryLink(
    this.label, {
    this.categoryType = CategoryType.general,
    this.idleTextColor = Colors.white,
  });

  @override
  State<_TextCategoryLink> createState() => _TextCategoryLinkState();
}

class _TextCategoryLinkState extends State<_TextCategoryLink> {
  bool _isHovered = false;

  String _getTooltipMessage(CategoryType categoryType) {
    switch (categoryType) {
      case CategoryType.islamicStudies:
        return 'Quran, Hadith, Arabic, Tawhid, Tafsir & more';
      case CategoryType.languages:
        return 'English, French & African languages (Yoruba, Hausa, Swahili, Adlam, Wolof, Amharic) - Authentic instruction from native speakers';
      case CategoryType.adultLiteracy:
        return 'English learning for adults - Reading, writing & speaking for everyday and professional use';
      case CategoryType.afterSchoolTutoring:
        return 'Math, Science, Programming, History & English support for students';
      case CategoryType.math:
        return 'Math support for students - From elementary to advanced calculus';
      case CategoryType.programming:
        return 'Programming for students - Web, mobile & software development';
      case CategoryType.english:
        return 'English support for students - Part of After School Tutoring';
      case CategoryType.general:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          switch (widget.categoryType) {
            case CategoryType.islamicStudies:
              Navigator.push(
                context,
                UnifiedProgramsPageRoutes.fade(
                  initialCategory: ProgramCatalog.catIslamic,
                ),
              );
              break;
            case CategoryType.math:
              Navigator.push(
                context,
                UnifiedProgramsPageRoutes.fade(
                  initialCategory: ProgramCatalog.catMath,
                ),
              );
              break;
            case CategoryType.programming:
              Navigator.push(
                context,
                UnifiedProgramsPageRoutes.fade(
                  initialCategory: ProgramCatalog.catProgramming,
                ),
              );
              break;
            case CategoryType.english:
              Navigator.push(
                context,
                UnifiedProgramsPageRoutes.fade(
                  initialCategory: ProgramCatalog.catAfterSchool,
                ),
              );
              break;
            case CategoryType.adultLiteracy:
              Navigator.push(
                context,
                UnifiedProgramsPageRoutes.fade(
                  initialCategory: ProgramCatalog.catEnglish,
                ),
              );
              break;
            case CategoryType.languages:
              Navigator.push(
                context,
                UnifiedProgramsPageRoutes.fade(
                  initialCategory: ProgramCatalog.catLanguages,
                ),
              );
              break;
            case CategoryType.afterSchoolTutoring:
              Navigator.push(
                context,
                UnifiedProgramsPageRoutes.fade(
                  initialCategory: ProgramCatalog.catAfterSchool,
                ),
              );
              break;
            case CategoryType.general:
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProgramSelectionPage(initialSubject: widget.label),
                ),
              );
              break;
          }
        },
        child: Tooltip(
          message: _getTooltipMessage(widget.categoryType),
          child: Text(
            widget.label,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _isHovered ? const Color(0xff3B82F6) : Colors.white, // Blue on hover, white otherwise
              decoration: _isHovered ? TextDecoration.underline : TextDecoration.none,
              decorationColor: const Color(0xff3B82F6),
            ),
          ),
        ),
      ),
    );
  }
}
