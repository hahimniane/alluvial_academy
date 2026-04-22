import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/landing_page.dart';
import '../screens/program_selection_page.dart';
import '../screens/unified_programs_page.dart';
import '../screens/teacher_application_screen.dart';
import '../screens/contact_page.dart';
import '../screens/team_page.dart';
import '../core/models/program_catalog.dart';
import '../core/models/public_site_cms_models.dart';
import '../core/services/public_site_cms_service.dart';
import '../main.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class ModernHeader extends StatefulWidget {
  const ModernHeader({super.key});

  @override
  State<ModernHeader> createState() => _ModernHeaderState();
}

class _ModernHeaderState extends State<ModernHeader> {
  OverlayEntry? _overlayEntry;
  bool _isProgramsHovered = false;
  final GlobalKey _programsKey = GlobalKey();
  _MegaMenuOverlayState? _megaMenuOverlayState;
  Timer? _megaMenuCloseTimer;

  @override
  void dispose() {
    _megaMenuCloseTimer?.cancel();
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isDesktop = screenWidth > 1024;
        final useCompactHeader = !isDesktop;
        final showTagline = isDesktop && screenWidth >= 1180;

        return Material(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildUtilityBar(
                      useCompactHeader: useCompactHeader,
                      showTagline: showTagline,
                    ),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border:
                            Border(bottom: BorderSide(color: Colors.grey.shade100)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: useCompactHeader ? 12 : 20,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          _buildLogo(compact: useCompactHeader),
                          if (isDesktop)
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.only(left: 12),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildNavLink(
                                      AppLocalizations.of(context)!.navHome,
                                      () => _goToLandingSection(
                                        section: null,
                                        replace: true,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _buildProgramsButton(),
                                    const SizedBox(width: 12),
                                    _buildNavLink(
                                      AppLocalizations.of(context)!.navPricing,
                                      () => _goToLandingSection(
                                        section: 'pricing',
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _buildNavLink(
                                      AppLocalizations.of(context)!.navAbout,
                                      () => _goToLandingSection(
                                        section: 'about',
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _buildNavLink(
                                      AppLocalizations.of(context)!.navOurTeam,
                                      () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const TeamPage(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _buildNavLink(
                                      AppLocalizations.of(context)!.contactUs,
                                      () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const ContactPage(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _buildHeaderLoginButton(),
                                  ],
                                ),
                              ),
                            )
                          else ...[
                            const Spacer(),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      settings: const RouteSettings(
                                        name: '/login',
                                      ),
                                      builder: (context) =>
                                          const AuthenticationWrapper(),
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xff111827),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    AppLocalizations.of(context)!.logIn,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.menu_rounded, size: 26),
                                  onPressed: () => _showMobileMenu(context),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchSocialUri(Uri uri) async {
    final l = AppLocalizations.of(context)!;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.headerSocialOpenError)),
      );
    }
  }

  Widget _buildUtilityBar({
    required bool useCompactHeader,
    required bool showTagline,
  }) {
    final l = AppLocalizations.of(context)!;
    const barColor = Color(0xff1d4ed8);

    return ColoredBox(
      color: barColor,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: useCompactHeader ? 12 : 20,
          vertical: 5,
        ),
        child: Row(
          children: [
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    settings: const RouteSettings(name: '/enroll'),
                    builder: (context) => const ProgramSelectionPage(),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: useCompactHeader ? 10 : 14,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: const BorderSide(color: Colors.white, width: 1),
                ),
              ),
              child: Text(
                l.signUpForNewClass,
                style: GoogleFonts.inter(
                  fontSize: useCompactHeader ? 10.5 : 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const Spacer(),
            if (showTagline)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.headerTaglineLine1,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                    Text(
                      l.headerTaglineLine2,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
            StreamBuilder<PublicSiteSocialDoc>(
              stream: PublicSiteCmsService.socialDocStream(),
              builder: (context, snapshot) {
                final doc = snapshot.data ?? const PublicSiteSocialDoc();
                final children = <Widget>[];
                void addIcon(Uri? uri, IconData brandIcon, String tooltip) {
                  if (uri == null) return;
                  children.add(
                    IconButton(
                      onPressed: () => _launchSocialUri(uri),
                      tooltip: tooltip,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      visualDensity: VisualDensity.compact,
                      icon: FaIcon(
                        brandIcon,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                  );
                }

                addIcon(
                  doc.instagram.validUri,
                  FontAwesomeIcons.instagram,
                  l.headerInstagramTooltip,
                );
                addIcon(
                  doc.facebook.validUri,
                  FontAwesomeIcons.facebookF,
                  l.headerFacebookTooltip,
                );
                addIcon(
                  doc.tiktok.validUri,
                  FontAwesomeIcons.tiktok,
                  l.headerTiktokTooltip,
                );
                if (children.isEmpty) return const SizedBox.shrink();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo({bool compact = false}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          _goToLandingSection(section: null, replace: true);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/Alluwal_Education_Hub_Logo.png',
              height: compact ? 32 : 36,
              width: compact ? 124 : 158,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.school_rounded,
                  size: 40,
                  color: Color(0xff3B82F6)),
            ),
            if (!compact) ...[
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.alluwal,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: const Color(0xff111827),
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.educationHub,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 9,
                      color: const Color(0xff3B82F6),
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgramsButton() {
    return MouseRegion(
      onEnter: (_) => _showMegaMenu(),
      onExit: (_) => _scheduleMegaMenuClose(),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: _programsKey,
        onTap: () => _showMegaMenu(),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          color: Colors.transparent,
          child: Row(
            children: [
              Text(
                AppLocalizations.of(context)!.findPrograms,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  color: const Color(0xff111827),
                ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                duration: const Duration(milliseconds: 200),
                turns: _isProgramsHovered ? 0.5 : 0, // Rotate arrow
                child: const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 17, color: Color(0xff111827)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goToLandingSection({String? section, bool replace = false}) {
    final hub = LandingSectionScope.maybeOf(context);
    if (hub != null) {
      hub.scrollToSection(section);
      return;
    }

    final route = MaterialPageRoute(
      builder: (context) => LandingPage(initialSection: section),
    );

    if (replace) {
      Navigator.pushReplacement(context, route);
    } else {
      Navigator.push(context, route);
    }
  }

  Widget _buildHeaderLoginButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/login'),
              builder: (context) => const AuthenticationWrapper(),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xff111827),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ).copyWith(
          overlayColor: MaterialStateProperty.resolveWith(
            (states) => Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          AppLocalizations.of(context)!.logIn,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _cancelMegaMenuCloseTimer() {
    _megaMenuCloseTimer?.cancel();
    _megaMenuCloseTimer = null;
  }

  void _scheduleMegaMenuClose() {
    _megaMenuCloseTimer?.cancel();
    _megaMenuCloseTimer = Timer(const Duration(milliseconds: 260), () {
      _megaMenuCloseTimer = null;
      if (!mounted) return;
      _megaMenuOverlayState?.dismiss();
    });
  }

  void _showMegaMenu() {
    _cancelMegaMenuCloseTimer();
    if (!mounted) return;
    setState(() => _isProgramsHovered = true);
    if (_overlayEntry == null) {
      _overlayEntry = _createMegaMenuOverlay();
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _tearDownMegaMenu() {
    _cancelMegaMenuCloseTimer();
    _overlayEntry?.remove();
    _overlayEntry = null;
    _megaMenuOverlayState = null;
    if (mounted) setState(() => _isProgramsHovered = false);
  }

  void _onMegaMenuDismissed() {
    _cancelMegaMenuCloseTimer();
    _overlayEntry?.remove();
    _overlayEntry = null;
    _megaMenuOverlayState = null;
    if (mounted) setState(() => _isProgramsHovered = false);
  }

  OverlayEntry _createMegaMenuOverlay() {
    final renderBox =
        _programsKey.currentContext?.findRenderObject() as RenderBox?;
    final offset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    final top = offset.dy + (renderBox?.size.height ?? 50) - 28;
    final safe = MediaQuery.paddingOf(context);
    final l = AppLocalizations.of(context)!;

    return OverlayEntry(
      builder: (overlayContext) {
        return _MegaMenuOverlay(
          top: top,
          horizontalPadding: EdgeInsets.only(
            left: safe.left + 16,
            right: safe.right + 16,
          ),
          onStateCreated: (s) => _megaMenuOverlayState = s,
          onDismissed: _onMegaMenuDismissed,
          panel: MouseRegion(
            onEnter: (_) {
              _cancelMegaMenuCloseTimer();
              if (mounted) setState(() => _isProgramsHovered = true);
            },
            onExit: (_) => _scheduleMegaMenuClose(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    Positioned(
                      top: -22,
                      left: 20,
                      right: 20,
                      height: 22,
                      child: MouseRegion(
                        opaque: true,
                        onEnter: (_) => _cancelMegaMenuCloseTimer(),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    Material(
                      elevation: 16,
                      shadowColor: Colors.black.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: _megaMenuDesktopThreeTracks(context, l),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static const _megaTitleColor = Color(0xff111827);

  Widget _megaMenuDesktopThreeTracks(
    BuildContext context,
    AppLocalizations l,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 720;
        final cards = [
          _megaDesktopProgramTile(
            title: l.navMegaColIslamicAfro,
            subtitle:
                '${l.navMegaLinkIslamicStudies} · ${l.navMegaLinkAfroLanguages}',
            icon: Icons.mosque_rounded,
            tint: const Color(0xff1D4ED8),
            onTap: () {
              _tearDownMegaMenu();
              Navigator.push(
                context,
                UnifiedProgramsPageRoutes.fade(
                  initialCategory: ProgramCatalog.catIslamic,
                ),
              );
            },
          ),
          _megaDesktopProgramTile(
            title: l.navMegaColAcademic,
            subtitle:
                '${l.navMegaLinkMath} · ${l.navMegaLinkProgramming} · ${l.navMegaLinkAfterSchool}',
            icon: Icons.school_rounded,
            tint: const Color(0xff059669),
            onTap: () {
              _tearDownMegaMenu();
              Navigator.push(
                context,
                UnifiedProgramsPageRoutes.fade(
                  initialCategory: ProgramCatalog.catMath,
                ),
              );
            },
          ),
          _megaDesktopProgramTile(
            title: l.navMegaColAdults,
            subtitle: l.navMegaLinkAdultLiteracy,
            icon: Icons.menu_book_rounded,
            tint: const Color(0xffD97706),
            onTap: () {
              _tearDownMegaMenu();
              Navigator.push(
                context,
                UnifiedProgramsPageRoutes.fade(
                  initialCategory: ProgramCatalog.catEnglish,
                ),
              );
            },
          ),
        ];
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (narrow)
              ...cards.map(
                (w) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: w,
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[1]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[2]),
                ],
              ),
            const SizedBox(height: 14),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xff4F46E5),
                  ),
                  onPressed: () {
                    _tearDownMegaMenu();
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const TeamPage(initialCategory: 'teacher'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.groups_2_outlined, size: 20),
                  label: Text(
                    l.ourTeachers,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xff4F46E5),
                  ),
                  onPressed: () {
                    _tearDownMegaMenu();
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const TeacherApplicationScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                  label: Text(
                    l.becomeATutor,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _megaDesktopProgramTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color tint,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        hoverColor: const Color(0xfff3f4f6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _megaTitleColor,
                        letterSpacing: -0.2,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xff64748B),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: tint.withValues(alpha: 0.85),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavLink(String title, VoidCallback onTap) {
    return _AnimatedNavLink(title: title, onTap: onTap);
  }

  void _closeMobileMenuThen(
    BuildContext menuContext,
    VoidCallback action,
  ) {
    Navigator.pop(menuContext);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) action();
    });
  }

  void _showMobileMenu(BuildContext outerContext) {
    final l = AppLocalizations.of(outerContext)!;
    showModalBottomSheet<void>(
      context: outerContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.38,
        maxChildSize: 0.94,
        expand: false,
        builder: (context, scrollController) {
          return DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 28,
                  offset: Offset(0, -6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
              child: Column(
                children: [
                  Expanded(
                    child: CustomScrollView(
                      controller: scrollController,
                      physics: const ClampingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 10),
                              Center(
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: const Color(0xffE2E8F0),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    20, 18, 8, 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            l.menu,
                                            style: GoogleFonts.inter(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xff0F172A),
                                              letterSpacing: -0.4,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            l.findPrograms,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              height: 1.35,
                                              color: const Color(0xff64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      style: IconButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xffF1F5F9),
                                        foregroundColor:
                                            const Color(0xff475569),
                                      ),
                                      onPressed: () =>
                                          Navigator.pop(sheetContext),
                                      icon: const Icon(Icons.close_rounded,
                                          size: 22),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          sliver: SliverToBoxAdapter(
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xffF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xffE2E8F0),
                                ),
                              ),
                              child: Column(
                                children: [
                                  _mobileMenuTile(
                                    label: l.navHome,
                                    icon: Icons.home_rounded,
                                    onTap: () => _closeMobileMenuThen(
                                      sheetContext,
                                      () => _goToLandingSection(
                                        replace: true,
                                      ),
                                    ),
                                  ),
                                  _mobileMenuTile(
                                    label: l.navPricing,
                                    icon: Icons.payments_outlined,
                                    onTap: () => _closeMobileMenuThen(
                                      sheetContext,
                                      () => _goToLandingSection(
                                        section: 'pricing',
                                      ),
                                    ),
                                  ),
                                  _mobileMenuTile(
                                    label: l.navAbout,
                                    icon: Icons.info_outline_rounded,
                                    onTap: () => _closeMobileMenuThen(
                                      sheetContext,
                                      () => _goToLandingSection(
                                        section: 'about',
                                      ),
                                    ),
                                  ),
                                  _mobileMenuTile(
                                    label: l.navOurTeam,
                                    icon: Icons.groups_2_outlined,
                                    onTap: () => _closeMobileMenuThen(
                                      sheetContext,
                                      () {
                                        Navigator.push(
                                          outerContext,
                                          MaterialPageRoute(
                                            builder: (_) => const TeamPage(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  _mobileMenuTile(
                                    label: l.contactUs,
                                    icon: Icons.mail_outline_rounded,
                                    onTap: () => _closeMobileMenuThen(
                                      sheetContext,
                                      () {
                                        Navigator.push(
                                          outerContext,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const ContactPage(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                          sliver: SliverToBoxAdapter(
                            child: Theme(
                              data: Theme.of(sheetContext).copyWith(
                                dividerColor: Colors.transparent,
                                splashColor: const Color(0xffE0E7FF)
                                    .withValues(alpha: 0.5),
                                highlightColor: const Color(0xffEEF2FF)
                                    .withValues(alpha: 0.6),
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xffEFF6FF),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: _mobileMenuTile(
                                        label: l.unifiedProgramsTitle,
                                        icon: Icons.grid_view_rounded,
                                        onTap: () => _closeMobileMenuThen(
                                          sheetContext,
                                          () {
                                            Navigator.push(
                                              outerContext,
                                              UnifiedProgramsPageRoutes.fade(),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _mobileProgramsExpansion(
                                    sheetContext: context,
                                    title: l.navMegaColIslamicAfro,
                                    headerIcon: Icons.mosque_rounded,
                                    accentColor: const Color(0xff1D4ED8),
                                    initiallyExpanded: true,
                                    children: [
                                      _mobileMenuChildTile(
                                        label: l.navMegaLinkIslamicStudies,
                                        onTap: () => _closeMobileMenuThen(
                                          sheetContext,
                                          () {
                                            Navigator.push(
                                              outerContext,
                                              UnifiedProgramsPageRoutes.fade(
                                                initialCategory:
                                                    ProgramCatalog.catIslamic,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      _mobileMenuChildTile(
                                        label: l.navMegaLinkAfroLanguages,
                                        onTap: () => _closeMobileMenuThen(
                                          sheetContext,
                                          () {
                                            Navigator.push(
                                              outerContext,
                                              UnifiedProgramsPageRoutes.fade(
                                                initialCategory:
                                                    ProgramCatalog.catLanguages,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _mobileProgramsExpansion(
                                    sheetContext: context,
                                    title: l.navMegaColAcademic,
                                    headerIcon: Icons.school_rounded,
                                    accentColor: const Color(0xff059669),
                                    initiallyExpanded: false,
                                    children: [
                                      _mobileMenuChildTile(
                                        label: l.navMegaLinkMath,
                                        onTap: () => _closeMobileMenuThen(
                                          sheetContext,
                                          () {
                                            Navigator.push(
                                              outerContext,
                                              UnifiedProgramsPageRoutes.fade(
                                                initialCategory:
                                                    ProgramCatalog.catMath,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      _mobileMenuChildTile(
                                        label: l.navMegaLinkProgramming,
                                        onTap: () => _closeMobileMenuThen(
                                          sheetContext,
                                          () {
                                            Navigator.push(
                                              outerContext,
                                              UnifiedProgramsPageRoutes.fade(
                                                initialCategory:
                                                    ProgramCatalog.catProgramming,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      _mobileMenuChildTile(
                                        label: l.navMegaLinkAfterSchool,
                                        onTap: () => _closeMobileMenuThen(
                                          sheetContext,
                                          () {
                                            Navigator.push(
                                              outerContext,
                                              UnifiedProgramsPageRoutes.fade(
                                                initialCategory:
                                                    ProgramCatalog.catAfterSchool,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _mobileProgramsExpansion(
                                    sheetContext: context,
                                    title: l.navMegaColAdults,
                                    headerIcon: Icons.menu_book_rounded,
                                    accentColor: const Color(0xffD97706),
                                    initiallyExpanded: false,
                                    children: [
                                      _mobileMenuChildTile(
                                        label: l.navMegaLinkAdultLiteracy,
                                        onTap: () => _closeMobileMenuThen(
                                          sheetContext,
                                          () {
                                            Navigator.push(
                                              outerContext,
                                              UnifiedProgramsPageRoutes.fade(
                                                initialCategory:
                                                    ProgramCatalog.catEnglish,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _mobileProgramsExpansion(
                                    sheetContext: context,
                                    title: l.navMegaColTeam,
                                    headerIcon: Icons.groups_2_outlined,
                                    accentColor: const Color(0xff6366F1),
                                    initiallyExpanded: false,
                                    children: [
                                      _mobileMenuChildTile(
                                        label: l.ourTeachers,
                                        onTap: () => _closeMobileMenuThen(
                                          sheetContext,
                                          () {
                                            Navigator.push(
                                              outerContext,
                                              MaterialPageRoute(
                                                builder: (_) => const TeamPage(
                                                  initialCategory: 'teacher',
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      _mobileMenuChildTile(
                                        label: l.becomeATutor,
                                        onTap: () => _closeMobileMenuThen(
                                          sheetContext,
                                          () {
                                            Navigator.push(
                                              outerContext,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const TeacherApplicationScreen(),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Material(
                      elevation: 8,
                      shadowColor: Colors.black26,
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.pop(sheetContext);
                                  Navigator.push(
                                    outerContext,
                                    MaterialPageRoute(
                                      settings: const RouteSettings(
                                        name: '/enroll',
                                      ),
                                      builder: (_) =>
                                          const ProgramSelectionPage(),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xff1d4ed8),
                                  side: const BorderSide(
                                    color: Color(0xffBFDBFE),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  l.signUpForNewClass,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: () {
                                  Navigator.pop(sheetContext);
                                  Navigator.push(
                                    outerContext,
                                    MaterialPageRoute(
                                      settings: const RouteSettings(
                                        name: '/login',
                                      ),
                                      builder: (_) =>
                                          const AuthenticationWrapper(),
                                    ),
                                  );
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xff111827),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  l.logIn,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _mobileMenuTile({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xffEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: const Color(0xff2563EB)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff1E293B),
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xffCBD5E1),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileMenuChildTile({
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 4, bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xff334155),
                      height: 1.3,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: Color(0xffCBD5E1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mobileProgramsExpansion({
    required BuildContext sheetContext,
    required String title,
    required IconData headerIcon,
    required Color accentColor,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: Theme(
        data: Theme.of(sheetContext).copyWith(
          dividerColor: Colors.transparent,
          splashColor: accentColor.withValues(alpha: 0.12),
          highlightColor: accentColor.withValues(alpha: 0.08),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xffF8FAFC),
            borderRadius: BorderRadius.circular(14),
          ),
          child: ExpansionTile(
            key: PageStorageKey<String>(title),
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            shape: shape,
            collapsedShape: shape,
            initiallyExpanded: initiallyExpanded,
            backgroundColor: accentColor.withValues(alpha: 0.08),
            collapsedBackgroundColor: const Color(0xffF8FAFC),
            iconColor: accentColor,
            collapsedIconColor: const Color(0xff64748B),
            leading: Icon(headerIcon, color: accentColor, size: 22),
            title: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xff0F172A),
                letterSpacing: -0.2,
              ),
            ),
            children: _interleaveWithDividers(children),
          ),
        ),
      ),
    );
  }

  List<Widget> _interleaveWithDividers(List<Widget> items) {
    if (items.length <= 1) return items;
    final result = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i < items.length - 1) {
        result.add(const Divider(
          height: 1,
          indent: 12,
          endIndent: 12,
          color: Color(0xffE2E8F0),
        ));
      }
    }
    return result;
  }
}

class _MegaMenuOverlay extends StatefulWidget {
  const _MegaMenuOverlay({
    required this.top,
    required this.horizontalPadding,
    required this.panel,
    required this.onStateCreated,
    required this.onDismissed,
  });

  final double top;
  final EdgeInsets horizontalPadding;
  final Widget panel;
  final ValueChanged<_MegaMenuOverlayState> onStateCreated;
  final VoidCallback onDismissed;

  @override
  State<_MegaMenuOverlay> createState() => _MegaMenuOverlayState();
}

class _MegaMenuOverlayState extends State<_MegaMenuOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    widget.onStateCreated(this);
    _controller.forward();
  }

  Future<void> dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = Tween<Offset>(
      begin: const Offset(0, -0.03),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: dismiss,
            child: FadeTransition(
              opacity: _controller,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.07),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: widget.top,
          left: 0,
          right: 0,
          child: Padding(
            padding: widget.horizontalPadding,
            child: SlideTransition(
              position: slide,
              child: FadeTransition(
                opacity: _controller,
                child: widget.panel,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnimatedNavLink extends StatefulWidget {
  final String title;
  final VoidCallback onTap;

  const _AnimatedNavLink({required this.title, required this.onTap});

  @override
  State<_AnimatedNavLink> createState() => _AnimatedNavLinkState();
}

class _AnimatedNavLinkState extends State<_AnimatedNavLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _isHovered
                    ? const Color(0xff111827)
                    : const Color(0xff374151),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2,
              width: _isHovered ? 18 : 0,
              color: const Color(0xff3B82F6),
            ),
          ],
        ),
      ),
    );
  }
}
