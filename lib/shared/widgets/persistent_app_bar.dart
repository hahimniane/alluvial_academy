import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../screens/landing_page.dart';
import '../../screens/islamic_courses_page.dart';
import '../../screens/teachers_page.dart';
import '../../screens/about_page.dart';
import '../../screens/contact_page.dart';
import '../../main.dart';

class PersistentAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String currentPage;

  const PersistentAppBar({
    super.key,
    required this.currentPage,
  });

  @override
  Size get preferredSize => const Size.fromHeight(80);

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
                _buildNavItem(context, 'Home', currentPage == 'Home', () {
                  if (currentPage != 'Home') {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LandingPage()),
                    );
                  }
                }),
                _buildNavItem(
                    context, 'Islamic Courses', currentPage == 'Courses', () {
                  if (currentPage != 'Courses') {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const IslamicCoursesPage()),
                    );
                  }
                }),
                _buildNavItem(
                    context, 'Our Teachers', currentPage == 'Teachers', () {
                  if (currentPage != 'Teachers') {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const TeachersPage()),
                    );
                  }
                }),
                _buildNavItem(context, 'About Us', currentPage == 'About', () {
                  if (currentPage != 'About') {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AboutPage()),
                    );
                  }
                }),
                _buildNavItem(context, 'Contact', currentPage == 'Contact', () {
                  if (currentPage != 'Contact') {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ContactPage()),
                    );
                  }
                }),
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
        if (currentPage != 'Home') {
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
                  isActive ? const Color(0xff3B82F6) : const Color(0xff6B7280),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        if (MediaQuery.of(context).size.width > 640) ...[
          TextButton(
            onPressed: () => _navigateToLogin(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xff6B7280),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'Sign In',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
        ElevatedButton(
          onPressed: () => _navigateToLogin(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xff3B82F6),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Text(
            'Start Trial',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToLogin(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const FirebaseInitializer()),
    );
  }

  void _showMobileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            _buildMobileMenuItem(
                context, Icons.home, 'Home', currentPage == 'Home', () {
              Navigator.pop(context);
              if (currentPage != 'Home') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LandingPage()),
                );
              }
            }),
            _buildMobileMenuItem(context, Icons.book, 'Islamic Courses',
                currentPage == 'Courses', () {
              Navigator.pop(context);
              if (currentPage != 'Courses') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const IslamicCoursesPage()),
                );
              }
            }),
            _buildMobileMenuItem(context, Icons.people, 'Our Teachers',
                currentPage == 'Teachers', () {
              Navigator.pop(context);
              if (currentPage != 'Teachers') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const TeachersPage()),
                );
              }
            }),
            _buildMobileMenuItem(
                context, Icons.info, 'About Us', currentPage == 'About', () {
              Navigator.pop(context);
              if (currentPage != 'About') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutPage()),
                );
              }
            }),
            _buildMobileMenuItem(context, Icons.contact_mail, 'Contact',
                currentPage == 'Contact', () {
              Navigator.pop(context);
              if (currentPage != 'Contact') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const ContactPage()),
                );
              }
            }),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _navigateToLogin(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Start Free Trial',
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

  Widget _buildMobileMenuItem(BuildContext context, IconData icon, String title,
      bool isActive, VoidCallback onTap) {
    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? const Color(0xff3B82F6) : const Color(0xff6B7280),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          color: isActive ? const Color(0xff3B82F6) : const Color(0xff374151),
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      tileColor: isActive ? const Color(0xff3B82F6).withOpacity(0.1) : null,
    );
  }
}
