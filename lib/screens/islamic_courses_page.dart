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
              _buildPricingSection(),
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
              '📚 Comprehensive Islamic Education',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xff3B82F6),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Islamic Learning Programs\nfor Every Age',
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
            'From Quran memorization to Islamic studies, discover the perfect\neducational path for your child\'s spiritual and academic growth.',
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
                  'Quran Memorization (Hifz)',
                  'Complete Quran memorization program with expert guidance',
                  [
                    'One-on-one sessions with certified Huffaz',
                    'Progressive memorization techniques',
                    'Regular revision schedules',
                    'Tajweed rules and proper pronunciation',
                    'Certificate upon completion'
                  ],
                  'Ages 5-18',
                  const Color(0xff3B82F6),
                ),
                _buildCourseCard(
                  '🎵',
                  'Quran Recitation & Tajweed',
                  'Master the beautiful art of Quranic recitation',
                  [
                    'Proper pronunciation (Makharij)',
                    'Tajweed rules and application',
                    'Different Qira\'at styles',
                    'Voice modulation techniques',
                    'Melodious recitation training'
                  ],
                  'Ages 6+',
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
                  '🕌',
                  'Islamic Studies',
                  'Comprehensive Islamic knowledge and values',
                  [
                    'Aqeedah (Islamic beliefs)',
                    'Fiqh (Islamic jurisprudence)',
                    'Hadith studies',
                    'Islamic history and biography',
                    'Islamic manners and ethics'
                  ],
                  'Ages 8+',
                  const Color(0xff8B5CF6),
                ),
                _buildCourseCard(
                  '🤲',
                  'Islamic Duas & Prayers',
                  'Essential prayers and supplications for daily life',
                  [
                    'Daily prayers (Salah) training',
                    'Important duas from Quran and Sunnah',
                    'Prayer timings and methods',
                    'Wudu and purification',
                    'Special occasion prayers'
                  ],
                  'Ages 5+',
                  const Color(0xffEF4444),
                ),
                _buildCourseCard(
                  '🌙',
                  'Islamic Lifestyle',
                  'Living according to Islamic principles',
                  [
                    'Islamic manners and etiquette',
                    'Halal and Haram guidelines',
                    'Social interactions in Islam',
                    'Family values in Islam',
                    'Character building'
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

  Widget _buildPricingSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Column(
        children: [
          Text(
            'Flexible Pricing Plans',
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 48),
          Container(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Row(
              children: [
                Expanded(
                  child: _buildPricingCard(
                    'Basic Plan',
                    '\$25',
                    'per month',
                    [
                      '2 classes per week',
                      '30-minute sessions',
                      'Basic course materials',
                      'Progress tracking',
                    ],
                    false,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildPricingCard(
                    'Premium Plan',
                    '\$45',
                    'per month',
                    [
                      '3 classes per week',
                      '45-minute sessions',
                      'All course materials',
                      'Priority teacher selection',
                      'Monthly progress reports',
                    ],
                    true,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildPricingCard(
                    'Family Plan',
                    '\$80',
                    'per month',
                    [
                      'Up to 3 children',
                      'Flexible scheduling',
                      'All premium features',
                      'Family progress dashboard',
                    ],
                    false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard(String title, String price, String period,
      List<String> features, bool isPopular) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPopular ? const Color(0xff3B82F6) : const Color(0xffE5E7EB),
          width: isPopular ? 2 : 1,
        ),
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
          if (isPopular)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xff3B82F6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Most Popular',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          if (isPopular) const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: GoogleFonts.inter(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xff3B82F6),
                ),
              ),
              Text(
                '/$period',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xff6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Column(
            children: features
                .map((feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.check,
                              size: 20, color: Color(0xff10B981)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              feature,
                              style: GoogleFonts.inter(
                                fontSize: 14,
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
              onPressed: () => _showEnrollDialog(title),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isPopular ? const Color(0xff3B82F6) : Colors.white,
                foregroundColor:
                    isPopular ? Colors.white : const Color(0xff3B82F6),
                side: BorderSide(
                  color: const Color(0xff3B82F6),
                  width: isPopular ? 0 : 1,
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Get Started',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
