import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../screens/landing_page.dart';
import '../../screens/islamic_courses_page.dart';
import '../../screens/tutoring_literacy_page.dart';
import '../../screens/afrolingual_page.dart';
import '../../main.dart';

class PersistentAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String currentPage;

  const PersistentAppBar({
    super.key,
    required this.currentPage,
  });

  @override
  State<PersistentAppBar> createState() => _PersistentAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(80);
}

class _PersistentAppBarState extends State<PersistentAppBar> {
  OverlayEntry? _overlayEntry;
  bool _isProgramsHovered = false;
  final GlobalKey _programsKey = GlobalKey();

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              // Logo Section
              _buildLogo(context),
              const Spacer(),
              // Navigation Items (Desktop)
              if (MediaQuery.of(context).size.width > 1024) ...[
                _buildNavItem(context, 'Home', widget.currentPage == 'Home',
                    () {
                  if (widget.currentPage != 'Home') {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LandingPage()),
                    );
                  }
                }),
                _buildProgramsDropdown(context),
                // Removed links to About, Teachers, Contact as they are deprecated
                const SizedBox(width: 32),
              ],
              // Action Buttons
              _buildActionButtons(context),
              // Mobile Menu (Mobile)
              if (MediaQuery.of(context).size.width <= 1024)
                IconButton(
                  onPressed: () => _showMobileMenu(context),
                  icon: const Icon(Icons.menu, size: 28),
                  color: const Color(0xff374151),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.currentPage != 'Home') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LandingPage()),
          );
        }
      },
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff3B82F6), Color(0xff1E40AF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/Alluwal_Education_Hub_Logo.png',
                width: 50,
                height: 50,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.school,
                    color: Colors.white,
                    size: 28,
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'ALLUWAL',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xff111827),
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'EDUCATION HUB',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff3B82F6),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgramsDropdown(BuildContext context) {
    final isProgramsPage = widget.currentPage == 'Courses' ||
        widget.currentPage == 'Programs' ||
        widget.currentPage == 'Tutoring' ||
        widget.currentPage == 'Afrolingual';

    return MouseRegion(
      onEnter: (_) => _showProgramsDropdown(context),
      onExit: (_) => _hideProgramsDropdown(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Builder(
          builder: (context) => GestureDetector(
            onTap: () => _showProgramsDropdown(context),
            child: AnimatedContainer(
              key: _programsKey,
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isProgramsPage || _isProgramsHovered
                    ? const Color(0xff3B82F6).withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Programs',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: isProgramsPage || _isProgramsHovered
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isProgramsPage || _isProgramsHovered
                          ? const Color(0xff3B82F6)
                          : const Color(0xff374151),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 20,
                    color: isProgramsPage || _isProgramsHovered
                        ? const Color(0xff3B82F6)
                        : const Color(0xff374151),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showProgramsDropdown(BuildContext context) {
    setState(() {
      _isProgramsHovered = true;
    });

    _overlayEntry?.remove();
    _overlayEntry = _createProgramsOverlay(context);
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideProgramsDropdown() {
    setState(() {
      _isProgramsHovered = false;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_isProgramsHovered) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    });
  }

  OverlayEntry _createProgramsOverlay(BuildContext context) {
    final programsRenderBox =
        _programsKey.currentContext?.findRenderObject() as RenderBox?;

    final RenderBox appBar = context.findRenderObject() as RenderBox;
    final appBarSize = appBar.size;
    final appBarOffset = appBar.localToGlobal(Offset.zero);

    double leftPosition;
    if (programsRenderBox != null) {
      final programsOffset = programsRenderBox.localToGlobal(Offset.zero);
      leftPosition = programsOffset.dx;
    } else {
      leftPosition = appBarOffset.dx + 370;
    }

    return OverlayEntry(
      builder: (context) => Positioned(
        left: leftPosition,
        top: appBarOffset.dy + appBarSize.height - 10,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isProgramsHovered = true),
          onExit: (_) => _hideProgramsDropdown(),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 280,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDropdownItem(
                    'Islamic Programs',
                    'Comprehensive Islamic education',
                    Icons.menu_book,
                    const Color(0xff3B82F6),
                    () {
                      _hideProgramsDropdown();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const IslamicCoursesPage(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _buildDropdownItem(
                    'After School & Adult Literacy',
                    'K-12 tutoring and adult education',
                    Icons.school,
                    const Color(0xff10B981),
                    () {
                      _hideProgramsDropdown();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TutoringLiteracyPage(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _buildDropdownItem(
                    'Afrolingual Program',
                    'African language learning',
                    Icons.language,
                    const Color(0xffF59E0B),
                    () {
                      _hideProgramsDropdown();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AfrolingualPage(),
                        ),
                      );
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

  Widget _buildDropdownItem(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff111827),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xff6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
      BuildContext context, String title, bool isActive, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xff3B82F6).withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color:
                  isActive ? const Color(0xff3B82F6) : const Color(0xff374151),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        _buildButton(
          'Login',
          false,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/login'),
              builder: (context) => const AuthenticationWrapper(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        _buildButton(
          'Get Started',
          true,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/signup'),
              builder: (context) => const AuthenticationWrapper(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButton(String text, bool isPrimary, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xff3B82F6) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isPrimary
              ? null
              : Border.all(color: const Color(0xff3B82F6), width: 1.5),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isPrimary ? Colors.white : const Color(0xff3B82F6),
          ),
        ),
      ),
    );
  }

  void _showMobileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Text(
                    'Navigation',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff111827),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _buildMobileNavItem(
                    context,
                    'Home',
                    widget.currentPage == 'Home',
                    () {
                      Navigator.pop(context);
                      if (widget.currentPage != 'Home') {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LandingPage()),
                        );
                      }
                    },
                  ),
                  // Programs Section Header
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'PROGRAMS',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff9CA3AF),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  _buildMobileNavItem(
                    context,
                    'Islamic Programs',
                    widget.currentPage == 'Courses',
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const IslamicCoursesPage()),
                      );
                    },
                  ),
                  _buildMobileNavItem(
                    context,
                    'After School & Adult Literacy',
                    widget.currentPage == 'Tutoring',
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const TutoringLiteracyPage()),
                      );
                    },
                  ),
                  _buildMobileNavItem(
                    context,
                    'Afrolingual Program',
                    widget.currentPage == 'Afrolingual',
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AfrolingualPage()),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  _buildButton(
                    'Login',
                    false,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          settings: const RouteSettings(name: '/login'),
                          builder: (context) => const AuthenticationWrapper(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildButton(
                    'Get Started',
                    true,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          settings: const RouteSettings(name: '/signup'),
                          builder: (context) => const AuthenticationWrapper(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileNavItem(
      BuildContext context, String title, bool isActive, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xff3B82F6).withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? const Color(0xff3B82F6)
                    : const Color(0xff374151),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
