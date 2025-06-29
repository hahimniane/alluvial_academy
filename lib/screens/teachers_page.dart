import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../shared/widgets/persistent_app_bar.dart';

class TeachersPage extends StatefulWidget {
  const TeachersPage({super.key});

  @override
  State<TeachersPage> createState() => _TeachersPageState();
}

class _TeachersPageState extends State<TeachersPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String selectedFilter = 'All';

  final List<String> filterOptions = [
    'All',
    'Quran Teachers',
    'Arabic Teachers',
    'Islamic Studies',
    'Male Teachers',
    'Female Teachers'
  ];

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
      appBar: const PersistentAppBar(currentPage: 'Teachers'),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeroSection(),
              _buildFiltersSection(),
              _buildTeachersSection(),
              _buildStatsSection(),
              _buildJoinTeachersSection(),
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
              '👨‍🏫 Qualified Islamic Educators',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xff3B82F6),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Learn from Certified\nIslamic Scholars',
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
            'Our teachers are certified Islamic scholars with years of experience\nin teaching Quran, Arabic, and Islamic studies to students worldwide.',
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

  Widget _buildFiltersSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xffE5E7EB), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter Teachers',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: filterOptions.map((filter) {
              final isSelected = selectedFilter == filter;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedFilter = filter;
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xff3B82F6) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xff3B82F6)
                          : const Color(0xffE5E7EB),
                    ),
                  ),
                  child: Text(
                    filter,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color:
                          isSelected ? Colors.white : const Color(0xff6B7280),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTeachersSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      child: Column(
        children: [
          Text(
            'Meet Our Dedicated Teachers',
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
                  MediaQuery.of(context).size.width > 768 ? 0.85 : 1.2,
              children: [
                _buildTeacherCard(
                  'Sheikh Ahmad Al-Mahmoud',
                  'Quran & Tajweed Specialist',
                  'Hafiz with 15+ years of teaching experience. Graduated from Al-Azhar University.',
                  ['Quran Memorization', 'Tajweed', 'Qira\'at'],
                  '15+ years',
                  '4.9',
                  '500+',
                  'assets/teacher1.jpg', // You can add actual images later
                  const Color(0xff3B82F6),
                ),
                _buildTeacherCard(
                  'Dr. Fatima Al-Zahra',
                  'Islamic Studies & Arabic',
                  'PhD in Islamic Theology. Expert in teaching Islamic history and Arabic grammar.',
                  ['Islamic Studies', 'Arabic Grammar', 'Islamic History'],
                  '12+ years',
                  '4.8',
                  '350+',
                  'assets/teacher2.jpg',
                  const Color(0xff10B981),
                ),
                _buildTeacherCard(
                  'Ustadh Yusuf Ibrahim',
                  'Hadith & Fiqh Scholar',
                  'Master\'s in Islamic Studies. Specializes in Hadith sciences and Islamic jurisprudence.',
                  ['Hadith Studies', 'Fiqh', 'Islamic Ethics'],
                  '10+ years',
                  '4.9',
                  '280+',
                  'assets/teacher3.jpg',
                  const Color(0xffF59E0B),
                ),
                _buildTeacherCard(
                  'Sister Aisha Khan',
                  'Children\'s Quran Teacher',
                  'Specialized in teaching children. Expert in making Quran learning fun and engaging.',
                  ['Children\'s Quran', 'Basic Arabic', 'Islamic Stories'],
                  '8+ years',
                  '4.9',
                  '400+',
                  'assets/teacher4.jpg',
                  const Color(0xff8B5CF6),
                ),
                _buildTeacherCard(
                  'Sheikh Omar Hassan',
                  'Advanced Arabic Teacher',
                  'Native Arabic speaker with expertise in classical Arabic literature and poetry.',
                  ['Advanced Arabic', 'Arabic Literature', 'Classical Texts'],
                  '18+ years',
                  '4.8',
                  '220+',
                  'assets/teacher5.jpg',
                  const Color(0xffEF4444),
                ),
                _buildTeacherCard(
                  'Dr. Khadija Salim',
                  'Islamic Psychology & Ethics',
                  'PhD in Islamic Psychology. Focuses on character building and Islamic lifestyle.',
                  ['Islamic Psychology', 'Character Building', 'Family Ethics'],
                  '14+ years',
                  '4.9',
                  '180+',
                  'assets/teacher6.jpg',
                  const Color(0xff06B6D4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherCard(
    String name,
    String title,
    String bio,
    List<String> specialties,
    String experience,
    String rating,
    String students,
    String imagePath,
    Color color,
  ) {
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
          // Teacher Avatar
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

          // Teacher Name & Title
          Text(
            name,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          const SizedBox(height: 16),

          // Bio
          Text(
            bio,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xff6B7280),
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),

          // Specialties
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: specialties
                .take(2)
                .map((specialty) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        specialty,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),

          // Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem('⭐', rating),
              _buildStatItem('👥', students),
              _buildStatItem('📅', experience.split('+')[0]),
            ],
          ),
          const SizedBox(height: 20),

          // Book Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showBookingDialog(name),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Book Lesson',
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

  Widget _buildStatItem(String icon, String value) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xff374151),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      decoration: const BoxDecoration(color: Color(0xffF9FAFB)),
      child: Column(
        children: [
          Text(
            'Why Choose Our Teachers?',
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
                  child: _buildQualityCard(
                    '🎓',
                    'Certified Scholars',
                    'All our teachers are certified Islamic scholars with proper Ijazah and qualifications.',
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildQualityCard(
                    '🌍',
                    'Global Experience',
                    'Our teachers have taught students from over 50 countries worldwide.',
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildQualityCard(
                    '💯',
                    'Proven Results',
                    '98% of our students show significant improvement within 3 months.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityCard(String emoji, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffE5E7EB)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 16),
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
            textAlign: TextAlign.center,
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

  Widget _buildJoinTeachersSection() {
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
            'Want to Become a Teacher?',
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Join our team of dedicated Islamic educators and help spread knowledge',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 18,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => _showApplicationDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xff3B82F6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Apply to Teach',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Learn More',
                  style: GoogleFonts.inter(
                    fontSize: 16,
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

  void _showBookingDialog(String teacherName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Book Lesson with $teacherName',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Great choice! $teacherName is an excellent teacher. Would you like to schedule a free trial lesson?',
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
              _showScheduleDialog(teacherName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff3B82F6),
            ),
            child: const Text('Schedule Trial',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showScheduleDialog(String teacherName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Schedule Free Trial',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Please contact us to schedule your free trial lesson with $teacherName.',
              style: GoogleFonts.inter(),
            ),
            const SizedBox(height: 16),
            Text(
              'We\'ll help you find the perfect time that works for you and your child.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to contact page
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

  void _showApplicationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Apply to Teach',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'We\'re always looking for qualified Islamic teachers. Please send us your qualifications and we\'ll get back to you.',
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
              // Navigate to application form
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff3B82F6),
            ),
            child: const Text('Submit Application',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
