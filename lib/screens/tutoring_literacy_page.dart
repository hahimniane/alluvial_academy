import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/modern_header.dart';
import '../shared/widgets/fade_in_slide.dart';
import 'program_selection_page.dart';

class TutoringLiteracyPage extends StatefulWidget {
  const TutoringLiteracyPage({super.key});

  @override
  State<TutoringLiteracyPage> createState() => _TutoringLiteracyPageState();
}

class _TutoringLiteracyPageState extends State<TutoringLiteracyPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffFAFAFA),
      body: Column(
        children: [
          const ModernHeader(),
          Expanded(
        child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              _buildHeroSection(),
              _buildProgramOverview(),
              _buildGradeLevelsSection(),
              _buildCTASection(),
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xffECFDF5), Color(0xffD1FAE5)],
        ),
      ),
      child: Column(
        children: [
          FadeInSlide(
            delay: 0.1,
            child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xff10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
                border: Border.all(color: const Color(0xff10B981).withOpacity(0.2)),
            ),
            child: Text(
                '📚 After School Tutoring',
              style: GoogleFonts.inter(
                fontSize: 14,
                  fontWeight: FontWeight.w600,
                color: const Color(0xff10B981),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FadeInSlide(
            delay: 0.2,
            child: Text(
            'Transformative Education\nBeyond Traditional Boundaries',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: MediaQuery.of(context).size.width > 600 ? 48 : 32,
              fontWeight: FontWeight.w900,
              color: const Color(0xff111827),
              height: 1.1,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeInSlide(
            delay: 0.3,
            child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Text(
                'Discover the transformative power of our After-school Tutoring Program at Alluwal Education Hub, embracing students from kindergarten through 12th grade with personalized class schedules.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                color: const Color(0xff6B7280),
                height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramOverview() {
    final cards = [
      _buildOverviewCard(
        Icons.auto_fix_high_rounded,
        'Personalized Learning',
        'Customized learning plans tailored to specific needs.',
        const Color(0xff3B82F6),
      ),
      _buildOverviewCard(
        Icons.access_time_filled_rounded,
        'Flexible Scheduling',
        'Classes scheduled to accommodate busy routines.',
        const Color(0xff10B981),
      ),
      _buildOverviewCard(
        Icons.verified_user_rounded,
        'Expert Tutors',
        'Qualified educators specializing in various subjects.',
        const Color(0xffF59E0B),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
        child: Column(
          children: [
          FadeInSlide(
            delay: 0.4,
            child: Text(
              'Program Overview',
              style: GoogleFonts.inter(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: const Color(0xff111827),
              ),
              ),
            ),
            const SizedBox(height: 48),
          Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 900;
                final isTablet = constraints.maxWidth > 600;
                
                if (!isTablet) {
                  // Mobile: Column
                  return Column(
                    children: cards.map((card) => Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: card,
                    )).toList(),
                  );
                }

                final crossAxisCount = isDesktop ? 3 : 2;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 32,
                  mainAxisSpacing: 32,
                  childAspectRatio: 1.3,
                  children: cards,
                );
              },
                  ),
                ),
              ],
      ),
    );
  }

  Widget _buildOverviewCard(IconData icon, String title, String description, Color color) {
    return FadeInSlide(
      child: Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              width: 56,
              height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
              child: Icon(icon, color: color, size: 28),
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
              color: const Color(0xff6B7280),
              height: 1.5,
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildGradeLevelsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      decoration: const BoxDecoration(color: Color(0xffF9FAFB)),
      child: Column(
        children: [
          Text(
            'K-12 Support',
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 48),
          Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 768) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                      Expanded(child: _buildGradeLevel('Elementary (K-5)', const Color(0xff10B981))),
                      const SizedBox(width: 24),
                      Expanded(child: _buildGradeLevel('Middle School (6-8)', const Color(0xff3B82F6))),
                      const SizedBox(width: 24),
                      Expanded(child: _buildGradeLevel('High School (9-12)', const Color(0xff8B5CF6))),
                    ],
                  );
                } else {
                  return Column(
        children: [
                      _buildGradeLevel('Elementary (K-5)', const Color(0xff10B981)),
                      const SizedBox(height: 24),
                      _buildGradeLevel('Middle School (6-8)', const Color(0xff3B82F6)),
                      const SizedBox(height: 24),
                      _buildGradeLevel('High School (9-12)', const Color(0xff8B5CF6)),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeLevel(String title, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCTASection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff10B981), Color(0xff059669)],
        ),
      ),
      child: Column(
        children: [
          Text(
            'Start Your Learning Journey Today',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Unlock your full potential with expert guidance',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 18,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProgramSelectionPage(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xff10B981),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Enroll Now',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEnrollDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Enroll in Tutoring',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Thank you for your interest! Please contact us to discuss your specific needs.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Contact Us', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
