import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../widgets/modern_header.dart';
import '../shared/widgets/fade_in_slide.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const ModernHeader(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildHeroSection(),
                  _buildMissionVisionSection(),
                  _buildCoreValuesSection(),
                  _buildJourneyTimeline(),
                  _buildTeamSection(),
                  _buildStatsSection(),
                  _buildFooterQuote(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      decoration: const BoxDecoration(
        color: Color(0xff001E4E),
      ),
      child: Column(
        children: [
          FadeInSlide(
            delay: 0.1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                'Learn, Lead & Thrive',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          FadeInSlide(
            delay: 0.2,
            child: Text(
              'Where Education Transcends Boundaries',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 24),
          FadeInSlide(
            delay: 0.3,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Text(
                'We are fostering a world where diverse knowledge—Islamic, African, and Western—comes together to prepare students for a globalized future.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  color: Colors.white.withOpacity(0.8),
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionVisionSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 900;
            return isDesktop
                ? Row(
                    children: [
                      Expanded(child: _buildMissionCard()),
                      const SizedBox(width: 32),
                      Expanded(child: _buildVisionCard()),
                    ],
                  )
                : Column(
                    children: [
                      _buildMissionCard(),
                      const SizedBox(height: 32),
                      _buildVisionCard(),
                    ],
                  );
          },
        ),
      ),
    );
  }

  Widget _buildMissionCard() {
    return _InfoCard(
      icon: Icons.rocket_launch_rounded,
      title: 'Our Mission',
      color: const Color(0xff3B82F6),
      content: 'To integrate Islamic, African, and Western education, offering a holistic curriculum that prepares students to navigate and succeed in a diverse world. We strive to empower learners with the tools to excel globally while staying true to their roots.',
    );
  }

  Widget _buildVisionCard() {
    return _InfoCard(
      icon: Icons.visibility_rounded,
      title: 'Our Vision',
      color: const Color(0xff10B981),
      content: 'To create an inclusive, inspiring environment where students are encouraged to become leaders in their communities. We aspire to celebrate heritage, scholarship, and innovation in equal measure.',
    );
  }

  Widget _buildCoreValuesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      decoration: const BoxDecoration(color: Color(0xffF8FAFC)),
      child: Column(
        children: [
          Text(
            'Core Values',
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 48),
          Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Wrap(
              spacing: 24,
              runSpacing: 24,
              alignment: WrapAlignment.center,
              children: [
                _buildValueCard('Authenticity', 'Rooted in Quran & Sunnah', Icons.verified_rounded),
                _buildValueCard('Compassion', 'Patience & care for all', Icons.volunteer_activism_rounded),
                _buildValueCard('Excellence', 'High standards in education', Icons.star_rounded),
                _buildValueCard('Community', 'Supportive global network', Icons.groups_rounded),
                _buildValueCard('Knowledge', 'Transformative learning', Icons.menu_book_rounded),
                _buildValueCard('Accessibility', 'Available worldwide', Icons.public_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValueCard(String title, String subtitle, IconData icon) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Icon(icon, size: 40, color: const Color(0xff3B82F6)),
          const SizedBox(height: 16),
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
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: const Color(0xff6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyTimeline() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
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
          Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                _buildTimelineItem('2020', 'Vision Founded', 'The seed of Alluwal was planted.'),
                _buildArrow(),
                _buildTimelineItem('2021', 'First Teachers', 'Recruited passionate educators.'),
                _buildArrow(),
                _buildTimelineItem('2022', 'Platform Launch', 'Officially opened our virtual doors.'),
                _buildArrow(),
                _buildTimelineItem('2023', 'Global Expansion', 'Reached students in 20+ countries.'),
                _buildArrow(),
                _buildTimelineItem('2024', 'Growth', 'New courses & 5,000+ students reached.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String year, String title, String desc) {
    return FadeInSlide(
      child: Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xffE5E7EB)),
        ),
        child: Row(
          children: [
            Text(
              year,
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: const Color(0xff3B82F6),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff111827),
                    ),
                  ),
                  Text(
                    desc,
                    style: GoogleFonts.inter(
                      fontSize: 16,
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

  Widget _buildArrow() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xff9CA3AF), size: 32),
    );
  }

  Widget _buildTeamSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      decoration: const BoxDecoration(color: Color(0xffF8FAFC)),
      child: Column(
        children: [
          Text(
            'Our Leadership',
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 48),
          Wrap(
            spacing: 32,
            runSpacing: 32,
            alignment: WrapAlignment.center,
            children: [
              _buildTeamCard(
                'Dr. Abdullah Rahman',
                'Founder & CEO',
                Icons.person,
                const Color(0xff3B82F6),
                'PhD in Islamic Studies from Al-Azhar University. 20+ years in Islamic education.',
              ),
              _buildTeamCard(
                'Sister Maryam Ali',
                'Head of Education',
                Icons.person_2,
                const Color(0xff10B981),
                'Masters in Education. Expert in curriculum development for Islamic studies.',
              ),
              _buildTeamCard(
                'Ustadh Omar Hassan',
                'Lead Islamic Scholar',
                Icons.school,
                const Color(0xffF59E0B),
                'Hafiz with Ijazah in multiple Qira\'at. 15+ years teaching experience.',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(String name, String role, IconData placeholderIcon, Color roleColor, String description) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          CircleAvatar(
            radius: 50,
            backgroundColor: roleColor.withOpacity(0.1),
            child: Icon(placeholderIcon, size: 50, color: roleColor),
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
            role,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: roleColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
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
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Wrap(
        spacing: 48,
        runSpacing: 32,
        alignment: WrapAlignment.center,
        children: [
          _buildStat('5K+', 'Happy Students'),
          _buildStat('200+', 'Qualified Teachers'),
          _buildStat('50+', 'Countries Served'),
          _buildStat('98%', 'Satisfaction Rate'),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 48,
            fontWeight: FontWeight.w900,
            color: const Color(0xff3B82F6),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: const Color(0xff6B7280),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFooterQuote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(60),
      color: const Color(0xff111827),
      child: Column(
        children: [
          const Icon(Icons.format_quote_rounded, color: Colors.white24, size: 48),
          const SizedBox(height: 24),
          Text(
            '"The best of people are those who learn the Quran and teach it to others."',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '- Prophet Muhammad (PBUH)',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final String content;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xffE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
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
          const SizedBox(height: 16),
          Text(
            content,
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
}

