import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../main.dart';
import 'islamic_courses_page.dart';
import 'tutoring_literacy_page.dart';
import 'afrolingual_page.dart';
import '../shared/widgets/persistent_app_bar.dart';
import '../core/models/landing_page_content.dart';
// Removed dynamic fetching of landing page content – using static default

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
  final PageController _carouselController = PageController();
  int _currentCarouselIndex = 0;

  // Dynamic content state
  LandingPageContent? _content;
  bool _isLoadingContent = false;

  @override
  void initState() {
    super.initState();
    // Immediately use static default content without fetching from Firestore/Cloud Function
    _content = LandingPageContent.defaultContent();

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

  // Removed _loadContent – no external fetch required

  @override
  void dispose() {
    _heroAnimationController.dispose();
    _scrollAnimationController.dispose();
    _scrollController.dispose();
    _carouselController.dispose();
    super.dispose();
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
            _buildProgramsCarousel(),
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
                          _isLoadingContent
                              ? '🕌 Nurturing Young Hearts Through Islamic Education'
                              : (_content?.heroSection.badgeText ??
                                  '🕌 Nurturing Young Hearts Through Islamic Education'),
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
                        _isLoadingContent
                            ? 'Quality Islamic Education\nfor Your Children'
                            : (_content?.heroSection.mainHeadline ??
                                'Quality Islamic Education\nfor Your Children'),
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
                        _isLoadingContent
                            ? 'Connect with qualified Islamic teachers for Quran, Arabic, and Islamic Studies.\nTrusted by parents worldwide for authentic Islamic education.'
                            : (_content?.heroSection.subtitle ??
                                'Connect with qualified Islamic teachers for Quran, Arabic, and Islamic Studies.\nTrusted by parents worldwide for authentic Islamic education.'),
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
                              onPressed: () => _navigateToEmployeeHub(),
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
                                Icons.login,
                                color: Colors.white,
                                size: 20,
                              ),
                              label: Text(
                                'Get Started',
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
                            onPressed: () => _scrollToSection('programs'),
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
                            icon: const Icon(Icons.explore, size: 20),
                            label: Text(
                              'Explore Programs',
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

  Widget _buildProgramsCarousel() {
    final programs = [
      {
        'title': 'Islamic Programs',
        'subtitle': 'Comprehensive Islamic Education',
        'description':
            'Our Islamic program is meticulously designed to immerse students in the profound depths of Islamic knowledge. Offering courses in more than six islamic subjects including: Arabic language, Quran, Hadith, Tawhid, Tafsir and more.',
        'icon': Icons.menu_book,
        'color': const Color(0xff3B82F6),
        'page': const IslamicCoursesPage(),
      },
      {
        'title': 'After School Tutoring & Adult Literacy',
        'subtitle': 'Education Beyond Boundaries',
        'description':
            'Discover the transformative power of our After-school Tutoring Program at Alluwal Education Hub, where education extends beyond traditional boundaries to embrace students from kindergarten through 12th grade, alongside a specialized adult program.',
        'icon': Icons.school,
        'color': const Color(0xff10B981),
        'page': const TutoringLiteracyPage(),
      },
      {
        'title': 'Afrolingual Program',
        'subtitle': 'Indigenous African Languages',
        'description':
            'Embark on a captivating journey through our African Indigenous Language Learning Program, tailored for both children and adults. Connect with African heritage through language and culture.',
        'icon': Icons.language,
        'color': const Color(0xffF59E0B),
        'page': const AfrolingualPage(),
      },
    ];

    final bool isCompact = MediaQuery.of(context).size.height < 750;
    final double cardPadding = isCompact ? 24.0 : 48.0;
    final double iconSize = isCompact ? 32.0 : 40.0;
    final double titleFontSize = isCompact ? 24.0 : 28.0;
    final double subtitleFontSize = isCompact ? 14.0 : 16.0;
    final double bodyFontSize = 16.0; // keep readable
    final double gapLarge = isCompact ? 20.0 : 32.0;
    final double gapMedium = isCompact ? 16.0 : 24.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 80),
      decoration: const BoxDecoration(
        color: Color(0xffF9FAFB),
      ),
      child: Column(
        children: [
          Text(
            'Our Programs',
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Comprehensive education embracing Islamic, African, and Western civilizations',
            style: GoogleFonts.inter(
              fontSize: 18,
              color: const Color(0xff6B7280),
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            height: isCompact ? 380 : 460,
            child: PageView.builder(
              controller: _carouselController,
              onPageChanged: (index) {
                setState(() {
                  _currentCarouselIndex = index;
                });
              },
              itemCount: programs.length,
              itemBuilder: (context, index) {
                final program = programs[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(
                          color: (program['color'] as Color).withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => program['page'] as Widget,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Padding(
                          padding: EdgeInsets.all(cardPadding),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: (program['color'] as Color)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  program['icon'] as IconData,
                                  size: iconSize,
                                  color: program['color'] as Color,
                                ),
                              ),
                              SizedBox(height: gapMedium),
                              Text(
                                program['title'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xff111827),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                program['subtitle'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: subtitleFontSize,
                                  fontWeight: FontWeight.w500,
                                  color: program['color'] as Color,
                                ),
                              ),
                              SizedBox(height: gapMedium),
                              Text(
                                program['description'] as String,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: bodyFontSize,
                                  color: const Color(0xff6B7280),
                                  height: 1.6,
                                ),
                              ),
                              SizedBox(height: gapLarge),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          program['page'] as Widget,
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: program['color'] as Color,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.arrow_forward, size: 18),
                                label: Text(
                                  'Learn More',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          // Carousel indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              programs.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: index == _currentCarouselIndex ? 24.0 : 8.0,
                height: 8.0,
                decoration: BoxDecoration(
                  color: index == _currentCarouselIndex
                      ? const Color(0xff3B82F6)
                      : const Color(0xffE5E7EB),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
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
              'Our Commitment to Excellence',
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
                _buildStatItem('3', 'Core Programs'),
                _buildStatItem('6+', 'Islamic Subjects'),
                _buildStatItem('K-12', 'Grade Levels'),
                _buildStatItem('All', 'Age Groups'),
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
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width > 768 ? 24 : 16,
        vertical: MediaQuery.of(context).size.width > 768 ? 120 : 60,
      ),
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
      child: Column(
        children: [
          Text(
            'What Parents Say',
            style: GoogleFonts.inter(
              fontSize: MediaQuery.of(context).size.width > 768 ? 36 : 28,
              fontWeight: FontWeight.w800,
              color: const Color(0xff111827),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Hear from families who trust us with their children\'s education',
            style: GoogleFonts.inter(
              fontSize: MediaQuery.of(context).size.width > 768 ? 18 : 16,
              color: const Color(0xff6B7280),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 64),
          _buildTestimonialCards(),
          const SizedBox(height: 80),
          Text(
            'Our Impact',
            style: GoogleFonts.inter(
              fontSize: MediaQuery.of(context).size.width > 768 ? 36 : 28,
              fontWeight: FontWeight.w800,
              color: const Color(0xff111827),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Transforming lives through comprehensive education',
            style: GoogleFonts.inter(
              fontSize: MediaQuery.of(context).size.width > 768 ? 18 : 16,
              color: const Color(0xff6B7280),
            ),
            textAlign: TextAlign.center,
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
                  MediaQuery.of(context).size.width > 768 ? 1.2 : 1.5,
              children: [
                _buildImpactCard(
                  '📖',
                  'Islamic Studies Excellence',
                  'Students gain deep understanding of Quran, Hadith, Tawhid, Tafsir, and Fiqh through our comprehensive curriculum.',
                  const Color(0xff3B82F6),
                ),
                _buildImpactCard(
                  '📚',
                  'Academic Success',
                  'Our after-school tutoring program helps K-12 students excel in their studies with personalized support.',
                  const Color(0xff10B981),
                ),
                _buildImpactCard(
                  '🌍',
                  'Cultural Heritage',
                  'Preserving African languages and traditions for future generations through our Afrolingual program.',
                  const Color(0xffF59E0B),
                ),
                _buildImpactCard(
                  '👨‍👩‍👧‍👦',
                  'Community Building',
                  'Creating connections between families who value comprehensive education rooted in faith and culture.',
                  const Color(0xff8B5CF6),
                ),
                _buildImpactCard(
                  '🎓',
                  'Adult Empowerment',
                  'Helping adults improve literacy skills and achieve their educational goals through flexible programs.',
                  const Color(0xffEF4444),
                ),
                _buildImpactCard(
                  '🌟',
                  'Holistic Development',
                  'Nurturing students who excel academically while staying grounded in their faith and cultural identity.',
                  const Color(0xff06B6D4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactCard(
    String emoji,
    String title,
    String description,
    Color color,
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
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff374151),
              height: 1.5,
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
            'Ready to Begin Your Educational Journey?',
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
            'Connect with our qualified teachers and discover the perfect learning path for your family',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 18,
              color: Colors.white.withOpacity(0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xff3B82F6), Color(0xff1E40AF)],
                  ),
                ),
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToEmployeeHub(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.school, color: Colors.white, size: 20),
                  label: Text(
                    'Access Dashboard',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const IslamicCoursesPage(),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(
                    color: Colors.white,
                    width: 2,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.info_outline, size: 20),
                label: Text(
                  'Learn More',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
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
          const SizedBox(height: 16),
          // Social and contact links
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _openExternal('https://wa.me/16468728590'),
                icon: const FaIcon(FontAwesomeIcons.whatsapp,
                    color: Colors.white, size: 18),
                label: Text(
                  '+1 646-872-8590',
                  style: GoogleFonts.inter(color: Colors.white),
                ),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'YouTube',
                onPressed: () => _openExternal(
                    'https://www.youtube.com/channel/UCJkZSAm6jVaqk6yy3kMW1zw'),
                icon:
                    const FaIcon(FontAwesomeIcons.youtube, color: Colors.white),
              ),
              IconButton(
                tooltip: 'Instagram',
                onPressed: () => _openExternal(
                    'https://www.instagram.com/alluwal_education_hub/'),
                icon: const FaIcon(FontAwesomeIcons.instagram,
                    color: Colors.white),
              ),
              IconButton(
                tooltip: 'Facebook',
                onPressed: () => _openExternal(
                    'https://www.facebook.com/profile.php?id=100083927322444'),
                icon: const FaIcon(FontAwesomeIcons.facebook,
                    color: Colors.white),
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

  void _navigateToEmployeeHub() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const FirebaseInitializer()),
    );
  }

  void _scrollToSection(String section) {
    // Approximate scroll positions for different sections
    double scrollPosition = 0.0;

    switch (section) {
      case 'programs':
        scrollPosition = 800.0; // Approximate position of programs carousel
        break;
      case 'features':
        scrollPosition = 1400.0; // Approximate position of features section
        break;
      case 'stats':
        scrollPosition = 2200.0; // Approximate position of stats section
        break;
      default:
        scrollPosition = 0.0;
    }

    _scrollController.animateTo(
      scrollPosition,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildTestimonialCards() {
    final testimonials = [
      {
        'name': 'Aisha Muhammad',
        'role': 'Parent of 3 students',
        'image': '👩‍👧‍👦',
        'rating': 5,
        'review':
            'Alhamdulillah, my children have grown so much in their Islamic knowledge since joining. The teachers are patient, knowledgeable, and truly care about each student\'s progress.',
      },
      {
        'name': 'Ibrahim Diallo',
        'role': 'Parent',
        'image': '👨‍👦',
        'rating': 5,
        'review':
            'The Afrolingual program has been a blessing. My son is now fluent in Mandinka and connected to his heritage. The quality of education here is exceptional.',
      },
      {
        'name': 'Fatima Al-Hassan',
        'role': 'Parent of 2 students',
        'image': '👩‍👧‍👦',
        'rating': 5,
        'review':
            'The tutoring program helped my daughter improve her grades significantly. The Islamic studies classes have strengthened our children\'s faith and character.',
      },
      {
        'name': 'Mahmoud Bakr',
        'role': 'Parent',
        'image': '👨‍👧',
        'rating': 5,
        'review':
            'Excellent Quran memorization program! My daughter has memorized 5 Juz in just one year. The teachers use modern techniques while maintaining traditional values.',
      },
      {
        'name': 'Khadijah Williams',
        'role': 'Parent of 4 students',
        'image': '👩‍👧‍👦',
        'rating': 5,
        'review':
            'This academy has been a cornerstone for our family. All my children attend different programs and each one is thriving. The community here is warm and supportive.',
      },
      {
        'name': 'Omar Sheikh',
        'role': 'Parent',
        'image': '👨‍👦‍👦',
        'rating': 5,
        'review':
            'The online classes are well-structured and engaging. My sons look forward to their Islamic studies classes. The teachers make learning fun while being thorough.',
      },
    ];

    return Container(
      constraints: const BoxConstraints(maxWidth: 1200),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 1024;
          final isTablet = constraints.maxWidth > 768;

          if (isDesktop) {
            // Desktop: 3 columns
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
                childAspectRatio: 1.1,
              ),
              itemCount: testimonials.length,
              itemBuilder: (context, index) =>
                  _buildTestimonialCard(testimonials[index]),
            );
          } else if (isTablet) {
            // Tablet: 2 columns
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
              ),
              itemCount: testimonials.length,
              itemBuilder: (context, index) =>
                  _buildTestimonialCard(testimonials[index]),
            );
          } else {
            // Mobile: Horizontal scroll
            return SizedBox(
              height: 320,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: testimonials.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: constraints.maxWidth * 0.85,
                    margin: EdgeInsets.only(
                      right: 16,
                      left: index == 0 ? 0 : 0,
                    ),
                    child: _buildTestimonialCard(testimonials[index]),
                  );
                },
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildTestimonialCard(Map<String, dynamic> testimonial) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xff3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    testimonial['image'],
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      testimonial['name'],
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff111827),
                      ),
                    ),
                    Text(
                      testimonial['role'],
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xff6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Star rating
          Row(
            children: List.generate(
              5,
              (index) => Icon(
                Icons.star,
                size: 16,
                color: index < testimonial['rating']
                    ? const Color(0xffF59E0B)
                    : const Color(0xffE5E7EB),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Text(
              testimonial['review'],
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xff374151),
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
