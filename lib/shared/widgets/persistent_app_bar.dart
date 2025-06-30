import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
                    Navigator.pushReplacementNamed(context, '/');
                  }
                }),
                _buildNavItem(
                    context, 'Islamic Courses', currentPage == 'Courses', () {
                  if (currentPage != 'Courses') {
                    Navigator.pushReplacementNamed(context, '/courses');
                  }
                }),
                _buildNavItem(
                    context, 'Our Teachers', currentPage == 'Teachers', () {
                  if (currentPage != 'Teachers') {
                    Navigator.pushReplacementNamed(context, '/teachers');
                  }
                }),
                _buildNavItem(context, 'About Us', currentPage == 'About', () {
                  if (currentPage != 'About') {
                    Navigator.pushReplacementNamed(context, '/about');
                  }
                }),
                _buildNavItem(context, 'Contact', currentPage == 'Contact', () {
                  if (currentPage != 'Contact') {
                    Navigator.pushReplacementNamed(context, '/contact');
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
          Navigator.pushReplacementNamed(context, '/');
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
          () => Navigator.pushReplacementNamed(context, '/login'),
        ),
        const SizedBox(width: 16),
        _buildButton(
          'Get Started',
          true,
          () => Navigator.pushReplacementNamed(context, '/login'),
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
                    currentPage == 'Home',
                    () {
                      Navigator.pop(context);
                      if (currentPage != 'Home') {
                        Navigator.pushReplacementNamed(context, '/');
                      }
                    },
                  ),
                  _buildMobileNavItem(
                    context,
                    'Islamic Courses',
                    currentPage == 'Courses',
                    () {
                      Navigator.pop(context);
                      if (currentPage != 'Courses') {
                        Navigator.pushReplacementNamed(context, '/courses');
                      }
                    },
                  ),
                  _buildMobileNavItem(
                    context,
                    'Our Teachers',
                    currentPage == 'Teachers',
                    () {
                      Navigator.pop(context);
                      if (currentPage != 'Teachers') {
                        Navigator.pushReplacementNamed(context, '/teachers');
                      }
                    },
                  ),
                  _buildMobileNavItem(
                    context,
                    'About Us',
                    currentPage == 'About',
                    () {
                      Navigator.pop(context);
                      if (currentPage != 'About') {
                        Navigator.pushReplacementNamed(context, '/about');
                      }
                    },
                  ),
                  _buildMobileNavItem(
                    context,
                    'Contact',
                    currentPage == 'Contact',
                    () {
                      Navigator.pop(context);
                      if (currentPage != 'Contact') {
                        Navigator.pushReplacementNamed(context, '/contact');
                      }
                    },
                  ),
                  const SizedBox(height: 32),
                  _buildButton(
                    'Login',
                    false,
                    () {
                      Navigator.pop(context);
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildButton(
                    'Get Started',
                    true,
                    () {
                      Navigator.pop(context);
                      Navigator.pushReplacementNamed(context, '/login');
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
