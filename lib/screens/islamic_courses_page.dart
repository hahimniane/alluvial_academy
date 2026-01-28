import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/modern_header.dart';
import '../shared/widgets/fade_in_slide.dart';
import 'program_selection_page.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class IslamicCoursesPage extends StatefulWidget {
  const IslamicCoursesPage({super.key});

  @override
  State<IslamicCoursesPage> createState() => _IslamicCoursesPageState();
}

class _IslamicCoursesPageState extends State<IslamicCoursesPage> {
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
                  _buildCoursesSection(),
                  _buildLearningPathsSection(),
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
          colors: [Color(0xffF0F9FF), Color(0xffE0F2FE)],
        ),
      ),
      child: Column(
        children: [
          FadeInSlide(
            delay: 0.1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xff3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: const Color(0xff3B82F6).withOpacity(0.2)),
              ),
              child: Text(
                AppLocalizations.of(context)!.islamicPrograms,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff3B82F6),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FadeInSlide(
            delay: 0.2,
            child: Text(
              AppLocalizations.of(context)!.immerseInTheProfoundNdepthsOf,
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
                AppLocalizations.of(context)!.ourIslamicProgramIsMeticulouslyDesigned,
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

  Widget _buildCoursesSection() {
    final courses = [
      _buildCourseCard(
        '📖',
        'Quran',
        'Complete Quran learning program including recitation, memorization, and understanding',
        [
          'Proper recitation with Tajweed rules',
          'Memorization techniques for Hifz',
          'Understanding the meanings',
        ],
        'All Ages',
        const Color(0xff3B82F6),
      ),
      _buildCourseCard(
        '📚',
        'Hadith',
        'Study the sayings and teachings of Prophet Muhammad (PBUH)',
        [
          'Authentic Hadith collections',
          'Understanding Hadith sciences',
          'Practical application in daily life',
        ],
        'Ages 10+',
        const Color(0xff10B981),
      ),
      _buildCourseCard(
        '🇸🇦',
        'Arabic Language',
        'Learn the language of the Quran from basics to fluency',
        [
          'Arabic alphabet and writing',
          'Grammar (Nahw) and morphology',
          'Vocabulary building',
        ],
        'Ages 7+',
        const Color(0xffF59E0B),
      ),
      _buildCourseCard(
        '☪️',
        'Tawhid',
        'Understanding the oneness of Allah and core Islamic beliefs',
        [
          'Fundamentals of Islamic faith',
          'Understanding Allah\'s attributes',
          'Pillars of faith (Iman)',
        ],
        'Ages 8+',
        const Color(0xff8B5CF6),
      ),
      _buildCourseCard(
        '📜',
        'Tafsir',
        'Deep understanding and interpretation of the Holy Quran',
        [
          'Verse by verse explanation',
          'Historical context',
          'Practical life applications',
        ],
        'Ages 12+',
        const Color(0xffEF4444),
      ),
      _buildCourseCard(
        '🕌',
        'Fiqh',
        'Understanding Islamic law and practical worship',
        [
          'Rules of prayer and fasting',
          'Halal and Haram guidelines',
          'Islamic business ethics',
        ],
        'Ages 10+',
        const Color(0xff06B6D4),
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
              AppLocalizations.of(context)!.ourIslamicCourses,
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
                  // Mobile: Column Layout
                  return Column(
                    children: courses.map((card) => Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: card,
                    )).toList(),
                  );
                }

                // Desktop/Tablet: Grid Layout
                final crossAxisCount = isDesktop ? 3 : 2;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 32,
                  mainAxisSpacing: 32,
                  childAspectRatio: isDesktop ? 0.8 : 0.75,
                  children: courses,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(
    String emoji,
    String title,
    String description,
    List<String> features,
    String ageGroup,
    Color color,
  ) {
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
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 56,
                  height: 56,
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ageGroup,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
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
            const SizedBox(height: 20),
            // Use Column for features so it takes natural height
            Column(
              children: features
                  .map((feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 16, color: color),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                feature,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xff374151),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // All Islamic courses map to the same enrollment subject
                  // The mapping function in ProgramSelectionPage will handle it
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProgramSelectionPage(initialSubject: title),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  AppLocalizations.of(context)!.enrollNow,
                  style: GoogleFonts.inter(
                    fontSize: 14,
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

  Widget _buildLearningPathsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      decoration: const BoxDecoration(color: Color(0xffF9FAFB)),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context)!.structuredLearningPaths,
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
                      Expanded(child: _buildLearningPath('Beginner', '3-6 months', const Color(0xff10B981))),
                      const SizedBox(width: 24),
                      Expanded(child: _buildLearningPath('Intermediate', '6-12 months', const Color(0xff3B82F6))),
                      const SizedBox(width: 24),
                      Expanded(child: _buildLearningPath('Advanced', '1-2 years', const Color(0xff8B5CF6))),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildLearningPath('Beginner', '3-6 months', const Color(0xff10B981)),
                      const SizedBox(height: 24),
                      _buildLearningPath('Intermediate', '6-12 months', const Color(0xff3B82F6)),
                      const SizedBox(height: 24),
                      _buildLearningPath('Advanced', '1-2 years', const Color(0xff8B5CF6)),
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

  Widget _buildLearningPath(String title, String duration, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(Icons.school_rounded, color: color, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            duration,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
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
          colors: [Color(0xff3B82F6), Color(0xff1E40AF)],
        ),
      ),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context)!.startYourChildSIslamicJourney,
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
            AppLocalizations.of(context)!.joinThousandsOfMuslimFamiliesWorldwide,
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
                  builder: (context) => ProgramSelectionPage(initialSubject: 'Islamic Studies'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xff3B82F6),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              AppLocalizations.of(context)!.bookFreeTrialClass,
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

  void _showEnrollDialog(String courseName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          AppLocalizations.of(context)!.enrollInCoursename,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          AppLocalizations.of(context)!.thankYouForYourInterestPlease2,
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.commonClose),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff3B82F6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(AppLocalizations.of(context)!.contactUs, style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
