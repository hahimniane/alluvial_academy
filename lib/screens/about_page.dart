import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../shared/widgets/persistent_app_bar.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const PersistentAppBar(currentPage: 'About'),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeroSection(),
              _buildMissionSection(),
              _buildValuesSection(),
              _buildStorySection(),
              _buildTeamSection(),
              _buildAchievementsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xffFAFBFF), Color(0xffF0F7FF)],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xff3B82F6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
              border:
                  Border.all(color: const Color(0xff3B82F6).withOpacity(0.2)),
            ),
            child: Text(
              '🕌 Our Story & Mission',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xff3B82F6),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Nurturing Faith Through\nAuthentic Islamic Education',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: const Color(0xff111827),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Text(
              'At Alluwal Education Hub, we bridge the gap between traditional Islamic knowledge and modern learning methods, making quality Islamic education accessible to Muslim families worldwide.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                color: const Color(0xff6B7280),
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Our Mission',
                    style: GoogleFonts.inter(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xff111827),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'To provide authentic, comprehensive Islamic education that nurtures the spiritual, intellectual, and moral development of Muslim children and adults, connecting them with qualified Islamic scholars and teachers from around the world.',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      color: const Color(0xff374151),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xff3B82F6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.school,
                          color: Color(0xff3B82F6),
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quality Education',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xff111827),
                              ),
                            ),
                            Text(
                              'Authentic Islamic knowledge delivered through modern teaching methods',
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
                ],
              ),
            ),
            const SizedBox(width: 60),
            Expanded(
              child: Container(
                height: 400,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xff3B82F6), Color(0xff1E40AF)],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.menu_book,
                    color: Colors.white,
                    size: 120,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValuesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      decoration: const BoxDecoration(color: Color(0xffF9FAFB)),
      child: Column(
        children: [
          Text(
            'Our Core Values',
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 48),
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
                _buildValueCard(
                  '🤲',
                  'Authenticity',
                  'We ensure all our teachings are rooted in authentic Islamic sources - the Quran and Sunnah.',
                  const Color(0xff3B82F6),
                ),
                _buildValueCard(
                  '💝',
                  'Compassion',
                  'We approach every student with patience, understanding, and genuine care for their learning journey.',
                  const Color(0xff10B981),
                ),
                _buildValueCard(
                  '🌟',
                  'Excellence',
                  'We strive for the highest standards in Islamic education and teaching methodologies.',
                  const Color(0xffF59E0B),
                ),
                _buildValueCard(
                  '🤝',
                  'Community',
                  'We foster a supportive global community of learners, teachers, and families.',
                  const Color(0xff8B5CF6),
                ),
                _buildValueCard(
                  '📚',
                  'Knowledge',
                  'We believe in the transformative power of authentic Islamic knowledge.',
                  const Color(0xffEF4444),
                ),
                _buildValueCard(
                  '🌍',
                  'Accessibility',
                  'We make quality Islamic education accessible to Muslims worldwide, regardless of location.',
                  const Color(0xff06B6D4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValueCard(
      String emoji, String title, String description, Color color) {
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
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff6B7280),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          children: [
            Text(
              'Our Journey',
              style: GoogleFonts.inter(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: const Color(0xff111827),
              ),
            ),
            const SizedBox(height: 48),
            Column(
              children: [
                _buildTimelineItem(
                  '2020',
                  'The Vision',
                  'Founded with the vision to make authentic Islamic education accessible to Muslim families worldwide through technology.',
                  true,
                ),
                _buildTimelineItem(
                  '2021',
                  'First Teachers',
                  'Recruited our first certified Islamic scholars and began offering Quran and Arabic lessons to students across the globe.',
                  false,
                ),
                _buildTimelineItem(
                  '2022',
                  'Platform Launch',
                  'Officially launched our comprehensive learning platform with advanced features for students, teachers, and parents.',
                  true,
                ),
                _buildTimelineItem(
                  '2023',
                  'Global Expansion',
                  'Expanded to serve students in over 50 countries with a team of 200+ qualified Islamic teachers.',
                  false,
                ),
                _buildTimelineItem(
                  '2024',
                  'Innovation Continues',
                  'Introduced new courses in Islamic studies, enhanced our platform features, and reached 5,000+ happy students.',
                  true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(
      String year, String title, String description, bool isLeft) {
    return Container(
      margin: const EdgeInsets.only(bottom: 40),
      child: Row(
        children: [
          if (isLeft) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xff6B7280),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
          ],
          Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xff3B82F6),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text(
                    year,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              if (year != '2024')
                Container(
                  width: 2,
                  height: 60,
                  color: const Color(0xffE5E7EB),
                ),
            ],
          ),
          if (!isLeft) ...[
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xff6B7280),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTeamSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      decoration: const BoxDecoration(color: Color(0xffF9FAFB)),
      child: Column(
        children: [
          Text(
            'Leadership Team',
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 48),
          Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: MediaQuery.of(context).size.width > 768 ? 3 : 1,
              crossAxisSpacing: 32,
              mainAxisSpacing: 32,
              childAspectRatio:
                  MediaQuery.of(context).size.width > 768 ? 0.9 : 1.5,
              children: [
                _buildTeamCard(
                  'Dr. Abdullah Rahman',
                  'Founder & CEO',
                  'PhD in Islamic Studies from Al-Azhar University. 20+ years in Islamic education.',
                  const Color(0xff3B82F6),
                ),
                _buildTeamCard(
                  'Sister Maryam Ali',
                  'Head of Education',
                  'Masters in Education. Expert in curriculum development for Islamic studies.',
                  const Color(0xff10B981),
                ),
                _buildTeamCard(
                  'Ustadh Omar Hassan',
                  'Lead Islamic Scholar',
                  'Hafiz with Ijazah in multiple Qira\'at. 15+ years teaching experience.',
                  const Color(0xffF59E0B),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(String name, String position, String bio, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
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
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            position,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            bio,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xff6B7280),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff3B82F6), Color(0xff1E40AF)],
        ),
      ),
      child: Column(
        children: [
          Text(
            'Our Achievements',
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 48),
          Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: MediaQuery.of(context).size.width > 768 ? 4 : 2,
              crossAxisSpacing: 32,
              mainAxisSpacing: 32,
              childAspectRatio: 1.2,
              children: [
                _buildAchievementCard('5K+', 'Happy Students'),
                _buildAchievementCard('200+', 'Qualified Teachers'),
                _buildAchievementCard('50+', 'Countries Served'),
                _buildAchievementCard('98%', 'Satisfaction Rate'),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Text(
              '"The best of people are those who learn the Quran and teach it to others." - Prophet Muhammad (PBUH)',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontStyle: FontStyle.italic,
                color: Colors.white.withOpacity(0.9),
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(String number, String label) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            number,
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}
