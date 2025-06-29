import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../features/auth/screens/login_screen.dart';
import '../main.dart';
import 'islamic_courses_page.dart';
import 'teachers_page.dart';
import 'about_page.dart';
import 'contact_page.dart';
import '../shared/widgets/persistent_app_bar.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with TickerProviderStateMixin {
  late AnimationController _heroAnimationController;
  late AnimationController _scrollAnimationController;
  late Animation<double> _heroFadeAnimation;
  late Animation<Offset> _heroSlideAnimation;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _heroAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scrollAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _heroFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _heroAnimationController,
      curve: Curves.easeOut,
    ));

    _heroSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _heroAnimationController,
      curve: Curves.easeOutCubic,
    ));

    // Start hero animation
    _heroAnimationController.forward();
  }

  @override
  void dispose() {
    _heroAnimationController.dispose();
    _scrollAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const PersistentAppBar(currentPage: 'Home'),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            _buildHeroSection(),
            _buildFeaturesSection(),
            _buildStatsSection(),
            _buildCoursesSection(),
            _buildTestimonialsSection(),
            _buildCTASection(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 100,
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
              Row(
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
                    child: const Icon(
                      Icons.school,
                      color: Colors.white,
                      size: 28,
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

              const Spacer(),

              // Navigation Items (Desktop)
              if (MediaQuery.of(context).size.width > 1024) ...[
                _buildNavItem('Home', true),
                _buildNavItem('Islamic Courses', false, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const IslamicCoursesPage()));
                }),
                _buildNavItem('Our Teachers', false, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const TeachersPage()));
                }),
                _buildNavItem('About Us', false, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AboutPage()));
                }),
                _buildNavItem('Contact', false, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ContactPage()));
                }),
                const SizedBox(width: 32),
              ],

              // Action Buttons
              Row(
                children: [
                  if (MediaQuery.of(context).size.width > 640) ...[
                    TextButton(
                      onPressed: () => _navigateToLogin(),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xff6B7280),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        'Sign In',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color(0xff3B82F6), Color(0xff1E40AF)],
                      ),
                    ),
                    child: ElevatedButton(
                      onPressed: () => _showTrialDialog(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Start Free Trial',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (MediaQuery.of(context).size.width <= 1024)
                    IconButton(
                      onPressed: () => _showMobileMenu(),
                      icon: const Icon(Icons.menu),
                      color: const Color(0xff3B82F6),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(String title, bool isActive, [VoidCallback? onTap]) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextButton(
        onPressed: onTap ?? () {},
        style: TextButton.styleFrom(
          foregroundColor:
              isActive ? const Color(0xff3B82F6) : const Color(0xff6B7280),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xffFAFBFF),
            Color(0xffF0F7FF),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 120),
        child: FadeTransition(
          opacity: _heroFadeAnimation,
          child: SlideTransition(
            position: _heroSlideAnimation,
            child: Column(
              children: [
                // Main Hero Content
                Container(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    children: [
                      // Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xff3B82F6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: const Color(0xff3B82F6).withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          '🕌 Nurturing Young Hearts Through Islamic Education',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xff3B82F6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Main Headline
                      Text(
                        'Quality Islamic Education\nfor Your Children',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize:
                              MediaQuery.of(context).size.width > 640 ? 56 : 40,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xff111827),
                          height: 1.1,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Subtitle
                      Text(
                        'Connect with qualified Islamic teachers for Quran, Arabic, and Islamic Studies.\nTrusted by parents worldwide for authentic Islamic education.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          color: const Color(0xff6B7280),
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // CTA Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [Color(0xff3B82F6), Color(0xff1E40AF)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xff3B82F6).withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () => _showTrialDialog(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 20,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(
                                Icons.rocket_launch,
                                color: Colors.white,
                                size: 20,
                              ),
                              label: Text(
                                'Start Free Trial',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton.icon(
                            onPressed: () => _scrollToSection('features'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xff3B82F6),
                              side: const BorderSide(
                                color: Color(0xff3B82F6),
                                width: 2,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 20,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.play_arrow, size: 20),
                            label: Text(
                              'Watch Demo',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 64),

                      // Trust Indicators
                      Column(
                        children: [
                          Text(
                            'Trusted by Muslim families worldwide',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xff9CA3AF),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 48,
                            runSpacing: 24,
                            children: [
                              _buildTrustLogo('🕌 Islamic Centers'),
                              _buildTrustLogo('📖 Madrasas'),
                              _buildTrustLogo('👨‍👩‍👧‍👦 Families'),
                              _buildTrustLogo('🌍 Worldwide'),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrustLogo(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: const Color(0xff6B7280),
        ),
      ),
    );
  }

  Widget _buildFeaturesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 120),
      child: Column(
        children: [
          // Section Header
          Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                Text(
                  'Complete Islamic Learning Platform',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xff111827),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Everything parents and teachers need for comprehensive Islamic education - from Quran memorization to Islamic studies.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    color: const Color(0xff6B7280),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),

          // Features Grid
          Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: MediaQuery.of(context).size.width > 768 ? 3 : 1,
              crossAxisSpacing: 32,
              mainAxisSpacing: 32,
              childAspectRatio:
                  MediaQuery.of(context).size.width > 768 ? 1.1 : 2,
              children: [
                _buildFeatureCard(
                  Icons.menu_book_rounded,
                  'Quran Learning',
                  'Professional Quran teachers for memorization, recitation, and Tajweed with personalized lessons.',
                  const Color(0xff3B82F6),
                ),
                _buildFeatureCard(
                  Icons.language_rounded,
                  'Arabic Language',
                  'Comprehensive Arabic courses from basics to advanced, taught by native speakers.',
                  const Color(0xff10B981),
                ),
                _buildFeatureCard(
                  Icons.school_rounded,
                  'Islamic Studies',
                  'Complete Islamic education covering Fiqh, Aqeedah, Hadith, and Islamic history.',
                  const Color(0xffF59E0B),
                ),
                _buildFeatureCard(
                  Icons.chat_bubble_rounded,
                  'Parent-Teacher Connection',
                  'Direct communication between parents and teachers to track your child\'s progress.',
                  const Color(0xff8B5CF6),
                ),
                _buildFeatureCard(
                  Icons.schedule_rounded,
                  'Flexible Scheduling',
                  'Choose class times that work for your family with our flexible booking system.',
                  const Color(0xffEF4444),
                ),
                _buildFeatureCard(
                  Icons.people_rounded,
                  'Qualified Teachers',
                  'Certified Islamic scholars and teachers with years of experience in Islamic education.',
                  const Color(0xff06B6D4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
      IconData icon, String title, String description, Color color) {
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
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: color,
              size: 32,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 20,
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
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff3B82F6), Color(0xff1E40AF)],
        ),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          children: [
            Text(
              'Trusted by Muslim Families',
              style: GoogleFonts.inter(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem('5K+', 'Happy Students'),
                _buildStatItem('200+', 'Islamic Teachers'),
                _buildStatItem('50+', 'Countries'),
                _buildStatItem('98%', 'Parent Satisfaction'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String number, String label) {
    return Column(
      children: [
        Text(
          number,
          style: GoogleFonts.inter(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildCoursesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 120),
      child: Column(
        children: [
          Text(
            'Islamic Education Programs',
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Structured Islamic learning paths for all ages and levels',
            style: GoogleFonts.inter(
              fontSize: 18,
              color: const Color(0xff6B7280),
            ),
          ),
          const SizedBox(height: 64),
          // Course features would go here
        ],
      ),
    );
  }

  Widget _buildTestimonialsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 120),
      decoration: const BoxDecoration(
        color: Color(0xffF9FAFB),
      ),
      child: Column(
        children: [
          Text(
            'What Our Community Says',
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 64),
          Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: MediaQuery.of(context).size.width > 768 ? 3 : 1,
              crossAxisSpacing: 32,
              mainAxisSpacing: 32,
              childAspectRatio:
                  MediaQuery.of(context).size.width > 768 ? 0.9 : 1.3,
              children: [
                _buildTestimonialCard(
                  'Sarah Ahmad',
                  'Parent from London, UK',
                  'My daughter has been learning Quran with Teacher Fatima for 6 months. Her pronunciation has improved dramatically and she looks forward to every lesson. The teachers are so patient and caring.',
                  '⭐⭐⭐⭐⭐',
                  const Color(0xff3B82F6),
                  '👩‍👧',
                ),
                _buildTestimonialCard(
                  'Omar Hassan',
                  'Father from Toronto, Canada',
                  'Alhamdulillah! Both my sons are now memorizing Quran with Sheikh Ahmad. The structured approach and regular progress reports keep us informed. Highly recommend this platform.',
                  '⭐⭐⭐⭐⭐',
                  const Color(0xff10B981),
                  '👨‍👦‍👦',
                ),
                _buildTestimonialCard(
                  'Ustadha Khadija',
                  'Arabic Teacher',
                  'Teaching on this platform has been a wonderful experience. The students are eager to learn and the support from the administration is excellent. Great environment for Islamic education.',
                  '⭐⭐⭐⭐⭐',
                  const Color(0xffF59E0B),
                  '👩‍🏫',
                ),
                _buildTestimonialCard(
                  'Amina Malik',
                  'Mother from Melbourne, Australia',
                  'The flexibility of online classes has been perfect for our family. My daughter can learn Arabic and Islamic studies from qualified teachers without leaving home. Amazing service!',
                  '⭐⭐⭐⭐⭐',
                  const Color(0xff8B5CF6),
                  '👩‍👧',
                ),
                _buildTestimonialCard(
                  'Sheikh Yusuf',
                  'Quran Teacher',
                  'I\'ve been teaching Quran for 15 years, and this platform provides excellent tools and resources. The students are motivated and the administration is very supportive.',
                  '⭐⭐⭐⭐⭐',
                  const Color(0xffEF4444),
                  '👨‍🏫',
                ),
                _buildTestimonialCard(
                  'Zainab Ali',
                  'Parent from Dubai, UAE',
                  'My son was struggling with Arabic pronunciation. After just 3 months with his teacher here, he\'s reading Quran beautifully. The teachers truly care about each student\'s progress.',
                  '⭐⭐⭐⭐⭐',
                  const Color(0xff06B6D4),
                  '👩‍👦',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestimonialCard(
    String name,
    String title,
    String testimonial,
    String rating,
    Color color,
    String emoji,
  ) {
    return Container(
      padding: const EdgeInsets.all(28),
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
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xff111827),
                      ),
                    ),
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            rating,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 12),
          Text(
            '"$testimonial"',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff374151),
              height: 1.6,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCTASection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 120),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff111827), Color(0xff374151)],
        ),
      ),
      child: Column(
        children: [
          Text(
            'Give Your Child the Gift of Islamic Education',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Join thousands of Muslim families worldwide in providing quality Islamic education',
            style: GoogleFonts.inter(
              fontSize: 18,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 48),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xff3B82F6), Color(0xff1E40AF)],
              ),
            ),
            child: ElevatedButton(
              onPressed: () => _showTrialDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Start Your Free Trial Today',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: const BoxDecoration(
        color: Color(0xff1F2937),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/logo_navigation_bar.PNG',
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xff3B82F6), Color(0xff1E40AF)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.school,
                          color: Colors.white,
                          size: 24,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'ALLUWAL EDUCATION HUB',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            '© 2024 Alluwal Education Hub. All rights reserved.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const FirebaseInitializer()),
    );
  }

  void _navigateToEmployeeHub() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const FirebaseInitializer()),
    );
  }

  void _showTrialDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Start Free Trial',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Ready to give your child quality Islamic education? Connect with our qualified teachers and start your journey today!',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToEmployeeHub();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff3B82F6),
            ),
            child: const Text('Get Started',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showMobileMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.book),
              title: const Text('Islamic Courses'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const IslamicCoursesPage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Our Teachers'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const TeachersPage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('About Us'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => const AboutPage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.contact_mail),
              title: const Text('Contact'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ContactPage()));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToSection(String section) {
    // Implement smooth scrolling to sections
  }
}
