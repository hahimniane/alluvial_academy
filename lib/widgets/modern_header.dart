import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/landing_page.dart';
import '../screens/program_selection_page.dart';
import '../screens/islamic_courses_page.dart';
import '../screens/afrolingual_page.dart';
import '../screens/tutoring_literacy_page.dart';
import '../screens/teacher_application_screen.dart';
import '../screens/about_page.dart';
import '../screens/contact_page.dart';
import '../screens/math_page.dart';
import '../screens/programming_page.dart';
import '../screens/teachers_page.dart';
import '../main.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ModernHeader extends StatefulWidget {
  const ModernHeader({super.key});

  @override
  State<ModernHeader> createState() => _ModernHeaderState();
}

class _ModernHeaderState extends State<ModernHeader> {
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
    final isDesktop = MediaQuery.of(context).size.width > 1024;

    return SafeArea( // Added SafeArea
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            // 1. Logo
            _buildLogo(),
            
            if (isDesktop) const SizedBox(width: 40),

            // 2. Navigation (Desktop)
            if (isDesktop) ...[
              _buildProgramsButton(),
              const SizedBox(width: 24),
              _buildNavLink('About', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage()))),
              const SizedBox(width: 24),
              _buildNavLink('Contact', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactPage()))),
            ],

            const Spacer(),

            // 3. Auth & Actions (Desktop)
            if (isDesktop) ...[
              _buildNavLink('Sign up for new class', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProgramSelectionPage()),
                );
              }),
              const SizedBox(width: 24),
              _buildNavLink('Log in', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    settings: const RouteSettings(name: '/login'),
                    builder: (context) => const AuthenticationWrapper(),
                  ),
                );
              }),
              const SizedBox(width: 16),
              _buildSignUpButton(),
            ] else
              // Mobile Menu Trigger & Quick Actions
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.app_registration_rounded, color: Color(0xff3B82F6)),
                    tooltip: AppLocalizations.of(context)!.signUpForNewClass,
                    onPressed: () => Navigator.push(
                      context, 
                      MaterialPageRoute(
                        settings: const RouteSettings(name: '/enroll'),
                        builder: (context) => const ProgramSelectionPage(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.login_rounded, color: Color(0xff111827)),
                    tooltip: AppLocalizations.of(context)!.logIn,
                    onPressed: () => Navigator.push(
                      context, 
                      MaterialPageRoute(
                        settings: const RouteSettings(name: '/login'),
                        builder: (context) => const AuthenticationWrapper(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.menu_rounded, size: 28),
                    onPressed: () => _showMobileMenu(context),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LandingPage()),
          );
        },
        child: Row(
          children: [
            Image.asset(
              'assets/Alluwal_Education_Hub_Logo.png',
              height: 40,
              errorBuilder: (context, error, stackTrace) => 
                  const Icon(Icons.school_rounded, size: 40, color: Color(0xff3B82F6)),
            ),
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
        ),
      ),
    );
  }

  Widget _buildProgramsButton() {
    return MouseRegion(
      onEnter: (_) => _showMegaMenu(),
      onExit: (_) => _hideMegaMenu(),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: _programsKey,
        onTap: () => _showMegaMenu(),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24), // Hit area
          color: Colors.transparent,
          child: Row(
            children: [
              Text(
                AppLocalizations.of(context)!.findPrograms,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: const Color(0xff111827),
                ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                duration: const Duration(milliseconds: 200),
                turns: _isProgramsHovered ? 0.5 : 0, // Rotate arrow
                child: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xff111827)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/signup'),
              builder: (context) => const AuthenticationWrapper(),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xff111827),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ).copyWith(
          overlayColor: MaterialStateProperty.resolveWith(
            (states) => Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          AppLocalizations.of(context)!.signUp,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _showMegaMenu() {
    setState(() => _isProgramsHovered = true);
    _overlayEntry?.remove();
    _overlayEntry = _createMegaMenuOverlay();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideMegaMenu() {
    setState(() => _isProgramsHovered = false);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!_isProgramsHovered) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    });
  }

  OverlayEntry _createMegaMenuOverlay() {
    final renderBox = _programsKey.currentContext?.findRenderObject() as RenderBox?;
    final offset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;

    return OverlayEntry(
      builder: (context) => Positioned(
        top: offset.dy + (renderBox?.size.height ?? 50) - 10, // Slight overlap
        left: offset.dx - 20,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isProgramsHovered = true),
          onExit: (_) => _hideMegaMenu(),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 10 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: Material(
              elevation: 20,
              shadowColor: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 650,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Program List
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.chooseYourProgram,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xff9CA3AF),
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildMegaMenuItem('Islamic Studies', Icons.mosque_rounded, () {
                            _hideMegaMenu();
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const IslamicCoursesPage()));
                          }),
                          _buildMegaMenuItem('Languages', Icons.language_rounded, () {
                            _hideMegaMenu();
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const AfrolingualPage()));
                          }),
                          _buildMegaMenuItem('After School Tutoring', Icons.school_rounded, () {
                            _hideMegaMenu();
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const TutoringLiteracyPage()));
                          }),
                          _buildMegaMenuItem('Math Classes', Icons.functions_rounded, () {
                            _hideMegaMenu();
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const MathPage()));
                          }),
                          _buildMegaMenuItem('Programming Classes', Icons.code_rounded, () {
                            _hideMegaMenu();
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const ProgrammingPage()));
                          }),
                          const SizedBox(height: 24),
                          Container(
                            height: 1,
                            color: Colors.grey.shade100,
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: () {
                              _hideMegaMenu();
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const TeachersPage()));
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                              child: Row(
                                children: [
                                  Text(
                                    AppLocalizations.of(context)!.ourTeachers,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xff3B82F6),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xff3B82F6)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () {
                              _hideMegaMenu();
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const TeacherApplicationScreen()));
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                              child: Row(
                                children: [
                                  Text(
                                    AppLocalizations.of(context)!.becomeATutor,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xff3B82F6),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xff3B82F6)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Vertical Divider
                    Container(
                      width: 1,
                      height: 240,
                      color: Colors.grey.shade100,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                    ),

                    // Right Column: Description/Details
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xffEFF6FF),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.school_rounded, color: Color(0xff3B82F6), size: 28),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            AppLocalizations.of(context)!.worldClassEducation,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xff111827),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            AppLocalizations.of(context)!.joinThousandsOfStudentsLearningFrom,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xff6B7280),
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMegaMenuItem(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      hoverColor: const Color(0xffF3F4F6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xff6B7280)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xff374151),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xff9CA3AF)),
          ],
        ),
      ),
    );
  }

  Widget _buildNavLink(String title, VoidCallback onTap) {
    return _AnimatedNavLink(title: title, onTap: onTap);
  }

  void _showMobileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
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
                    AppLocalizations.of(context)!.menu,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff111827),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _buildMobileNavItem('Home', () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LandingPage()));
                  }),
                  _buildMobileNavItem('About Us', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutPage()));
                  }),
                  _buildMobileNavItem('Contact Us', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ContactPage()));
                  }),
                  const SizedBox(height: 24),
                  Text(
                    AppLocalizations.of(context)!.programs2,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff9CA3AF),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMobileNavItem('Islamic Studies', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const IslamicCoursesPage()));
                  }),
                  _buildMobileNavItem('Languages', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AfrolingualPage()));
                  }),
                  _buildMobileNavItem('After School Tutoring', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const TutoringLiteracyPage()));
                  }),
                  _buildMobileNavItem('Math Classes', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const MathPage()));
                  }),
                  _buildMobileNavItem('Programming', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ProgrammingPage()));
                  }),
                  const SizedBox(height: 24),
                  Container(height: 1, color: Colors.grey.shade100),
                  const SizedBox(height: 24),
                  _buildMobileNavItem('Our Teachers', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const TeachersPage()));
                  }),
                  _buildMobileNavItem('Become a Tutor', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const TeacherApplicationScreen()));
                  }),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
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
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(AppLocalizations.of(context)!.logInSignUp),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileNavItem(String title, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: const Color(0xff111827),
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xff9CA3AF)),
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
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: _isHovered ? const Color(0xff111827) : const Color(0xff374151),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2,
              width: _isHovered ? 20 : 0,
              color: const Color(0xff3B82F6),
            ),
          ],
        ),
      ),
    );
  }
}