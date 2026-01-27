import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../core/services/onboarding_service.dart';

/// Welcome onboarding slides for new students
class StudentWelcomeScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const StudentWelcomeScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<StudentWelcomeScreen> createState() => _StudentWelcomeScreenState();
}

class _StudentWelcomeScreenState extends State<StudentWelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPage> _pages = [
    _OnboardingPage(
      icon: Icons.school_rounded,
      iconColor: const Color(0xFF0E72ED),
      title: 'Welcome to Alluvial Academy',
      subtitle: 'Your Islamic education journey starts here',
      description:
          'Join live classes with qualified teachers, learn at your own pace, and grow in knowledge.',
    ),
    _OnboardingPage(
      icon: Icons.videocam_rounded,
      iconColor: const Color(0xFF10B981),
      title: 'Join Live Classes',
      subtitle: 'Interactive learning experience',
      description:
          'See your upcoming classes, join with one tap when it\'s time, and learn directly from your teachers.',
    ),
    _OnboardingPage(
      icon: Icons.notifications_active_rounded,
      iconColor: const Color(0xFFF59E0B),
      title: 'Never Miss a Class',
      subtitle: 'Stay on track with reminders',
      description:
          'Get notified before your classes start so you\'re always prepared and ready to learn.',
    ),
    _OnboardingPage(
      icon: Icons.rocket_launch_rounded,
      iconColor: const Color(0xFF8B5CF6),
      title: 'You\'re All Set!',
      subtitle: 'Let\'s get started',
      description:
          'We\'ll show you around the app so you know exactly where everything is. Ready?',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticFeedback.mediumImpact(); // Haptic feedback for kids
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() async {
    HapticFeedback.heavyImpact(); // Stronger feedback for completion
    await OnboardingService.completeOnboarding();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    'Skip',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minHeight: constraints.maxHeight),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Icon with animated background
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.8, end: 1.0),
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.elasticOut,
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: value,
                                    child: child,
                                  );
                                },
                                child: Container(
                                  width: size.width * 0.45,
                                  height: size.width * 0.45,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        page.iconColor.withOpacity(0.15),
                                        page.iconColor.withOpacity(0.05),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: size.width * 0.3,
                                      height: size.width * 0.3,
                                      decoration: BoxDecoration(
                                        color: page.iconColor.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        page.icon,
                                        size: size.width * 0.15,
                                        color: page.iconColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(height: size.height * 0.06),

                              // Title
                              Text(
                                page.title,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF111827),
                                  height: 1.2,
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Subtitle
                              Text(
                                page.subtitle,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: page.iconColor,
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Description
                              Text(
                                page.description,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: const Color(0xFF6B7280),
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Bottom section
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  // Page indicator
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: _pages.length,
                    effect: ExpandingDotsEffect(
                      dotWidth: 8,
                      dotHeight: 8,
                      activeDotColor: const Color(0xFF0E72ED),
                      dotColor: const Color(0xFFE5E7EB),
                      expansionFactor: 3,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Next / Get Started button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0E72ED),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isLastPage ? 'Get Started' : 'Continue',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isLastPage
                                ? Icons.rocket_launch_rounded
                                : Icons.arrow_forward_rounded,
                            size: 20,
                          ),
                        ],
                      ),
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
}

/// Data model for onboarding pages
class _OnboardingPage {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String description;

  const _OnboardingPage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.description,
  });
}
