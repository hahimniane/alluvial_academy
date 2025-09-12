import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../shared/widgets/persistent_app_bar.dart';

class IslamicCoursesPage extends StatefulWidget {
  const IslamicCoursesPage({super.key});

  @override
  State<IslamicCoursesPage> createState() => _IslamicCoursesPageState();
}

class _IslamicCoursesPageState extends State<IslamicCoursesPage>
    with TickerProviderStateMixin {
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
      appBar: const PersistentAppBar(currentPage: 'Courses'),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
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
              '🕌 Islamic Programs',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xff3B82F6),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Immerse in the Profound\nDepths of Islamic Knowledge',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: const Color(0xff111827),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Our Islamic program is meticulously designed to immerse students in the profound depths of Islamic knowledge.\nOffering courses in more than six islamic subjects including: Arabic language, Quran, Hadith, Tawhid, Tafsir and more.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 18,
              color: const Color(0xff6B7280),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Column(
        children: [
          Text(
            'Our Islamic Courses',
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
              crossAxisCount: MediaQuery.of(context).size.width > 768 ? 2 : 1,
              crossAxisSpacing: 32,
              mainAxisSpacing: 32,
              childAspectRatio:
                  MediaQuery.of(context).size.width > 768 ? 1.3 : 1.8,
              children: [
                _buildCourseCard(
                  '📖',
                  'Quran',
                  'Complete Quran learning program including recitation, memorization, and understanding',
                  [
                    'Proper recitation with Tajweed rules',
                    'Memorization techniques for Hifz',
                    'Understanding the meanings',
                    'One-on-one sessions with certified teachers',
                    'Certificate upon completion'
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
                    'Memorization of important Hadiths',
                    'Context and interpretation'
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
                    'Grammar (Nahw) and morphology (Sarf)',
                    'Vocabulary building',
                    'Conversation skills',
                    'Classical Arabic literature'
                  ],
                  'Ages 7+',
                  const Color(0xffF59E0B),
                ),
                _buildCourseCard(
                  '☪️',
                  'Tawhid (Islamic Monotheism)',
                  'Understanding the oneness of Allah and core Islamic beliefs',
                  [
                    'Fundamentals of Islamic faith',
                    'Understanding Allah\'s names and attributes',
                    'Pillars of faith (Iman)',
                    'Protection from misconceptions',
                    'Strengthening belief and conviction'
                  ],
                  'Ages 8+',
                  const Color(0xff8B5CF6),
                ),
                _buildCourseCard(
                  '📜',
                  'Tafsir (Quran Commentary)',
                  'Deep understanding and interpretation of the Holy Quran',
                  [
                    'Verse by verse explanation',
                    'Historical context and revelation',
                    'Classical and modern interpretations',
                    'Practical life applications',
                    'Thematic study of the Quran'
                  ],
                  'Ages 12+',
                  const Color(0xffEF4444),
                ),
                _buildCourseCard(
                  '🕌',
                  'Fiqh (Islamic Jurisprudence)',
                  'Understanding Islamic law and practical worship',
                  [
                    'Rules of prayer, fasting, and zakat',
                    'Halal and Haram guidelines',
                    'Islamic business ethics',
                    'Family law and social interactions',
                    'Contemporary Islamic issues'
                  ],
                  'Ages 10+',
                  const Color(0xff06B6D4),
                ),
              ],
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
              const SizedBox(width: 16),
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
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        ageGroup,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff6B7280),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: features
                .map((feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
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
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showEnrollDialog(title),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Learn More',
                style: GoogleFonts.inter(
                  fontSize: 14,
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

  Widget _buildLearningPathsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      decoration: const BoxDecoration(color: Color(0xffF9FAFB)),
      child: Column(
        children: [
          Text(
            'Structured Learning Paths',
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 48),
          Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Row(
              children: [
                Expanded(
                  child: _buildLearningPath(
                    'Beginner Path',
                    '3-6 months',
                    [
                      'Arabic Alphabet',
                      'Basic Duas',
                      'Short Surahs',
                      'Prayer Basics',
                    ],
                    const Color(0xff10B981),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildLearningPath(
                    'Intermediate Path',
                    '6-12 months',
                    [
                      'Tajweed Rules',
                      'Longer Surahs',
                      'Islamic Stories',
                      'Arabic Vocabulary',
                    ],
                    const Color(0xff3B82F6),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildLearningPath(
                    'Advanced Path',
                    '1-2 years',
                    [
                      'Quran Memorization',
                      'Arabic Grammar',
                      'Islamic Studies',
                      'Hadith Learning',
                    ],
                    const Color(0xff8B5CF6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningPath(
      String title, String duration, List<String> topics, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.school, color: color, size: 30),
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
          const SizedBox(height: 8),
          Text(
            duration,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: topics
                .map((topic) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 16, color: color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              topic,
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
            'Start Your Child\'s Islamic Journey Today',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Join thousands of Muslim families worldwide',
            style: GoogleFonts.inter(
              fontSize: 18,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => _showEnrollDialog('Free Trial'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xff3B82F6),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Book Free Trial Class',
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
        title: Text(
          'Enroll in $courseName',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Thank you for your interest! Please contact us to schedule a consultation and begin your Islamic learning journey.',
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
              // Here you would navigate to contact page or booking system
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff3B82F6),
            ),
            child:
                const Text('Contact Us', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
