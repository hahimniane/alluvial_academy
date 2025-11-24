import 'package:flutter/material.dart';
import '../core/enums/ui_enums.dart';
import 'package:google_fonts/google_fonts.dart';
import '../shared/widgets/persistent_app_bar.dart';
import '../shared/widgets/responsive_builder.dart';
import 'teacher_application_screen.dart';

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
    return ResponsiveBuilder(
      builder: (context, constraints, deviceType) {
        final isDesktop = deviceType == DeviceType.desktop;
        final isTablet = deviceType == DeviceType.tablet;

        return Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24 : 16,
              vertical: isDesktop
                  ? 80
                  : isTablet
                      ? 60
                      : 40,
            ),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xff3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                        color: const Color(0xff3B82F6).withOpacity(0.2)),
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
                    fontSize: isDesktop
                        ? 48
                        : isTablet
                            ? 36
                            : 28,
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
                    fontSize: isDesktop ? 18 : 16,
                    color: const Color(0xff6B7280),
                    height: 1.6,
                  ),
                ),
              ],
            ));
      },
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
          ResponsiveBuilder(
            builder: (context, constraints, deviceType) {
              return Container(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: deviceType == DeviceType.desktop
                      ? 3
                      : deviceType == DeviceType.tablet
                          ? 2
                          : 1,
                  crossAxisSpacing: deviceType == DeviceType.desktop ? 32 : 16,
                  mainAxisSpacing: deviceType == DeviceType.desktop ? 32 : 16,
                  childAspectRatio: deviceType == DeviceType.desktop
                      ? 0.85
                      : deviceType == DeviceType.tablet
                          ? 0.9
                          : 1.2,
                  children: [
                    _buildTeacherCard(
                      'Ibrahim M. Baldee',
                      'Teacher / Ustaz',
                      'Ustaz Ibrahim is a Liberian international student currently based in Saudi Arabia. He completed the memorization of the Holy Qur\'an in 2012 and studied Tajweed in depth, memorizing many Tajweed texts. He has been teaching Qur\'an since 2012 and finds teaching among the most pleasant acts. He looks forward to meeting new students. (University of Madinah. Languages: Pular, English, Arabic)',
                      ['Pular', 'English', 'Arabic'],
                      '—',
                      '—',
                      '—',
                      'assets/teachers/ibrahim_baldee.jpg',
                      const Color(0xff3B82F6),
                    ),
                    _buildTeacherCard(
                      'Elham Shifa',
                      'Teacher / Ustaza',
                      'Elham is pursuing a degree in Islamic Psychology at Ankara University (Turkey). Originally from Ethiopia, she has been teaching for several years. Learning and teaching the Qur\'an to understand Allah\'s message has always been her life goal, inspired by the hadith: “The best of you are those who learn the Qur\'an and teach it.” (Languages: English, Arabic)',
                      ['English', 'Arabic'],
                      '—',
                      '—',
                      '—',
                      'assets/teachers/elham_shifa.jpg',
                      const Color(0xff10B981),
                    ),
                    _buildTeacherCard(
                      'Mohammed Kosiah',
                      'Teacher / Ustaz',
                      'Brother Kosiah graduated from Kahatain Children Village Islamic Mission (2016) with foundations in Islam and secular education. He has delivered sermons and public talks since 5th grade and is active in youth/community development programs. He recently graduated from the intensive Arabic Institute of the Islamic University of Madinah and studies Economics at the same university. (Languages: Mandingo, French, English, Arabic)',
                      ['Mandingo', 'French', 'English'],
                      '—',
                      '—',
                      '—',
                      'assets/teachers/mohammed_kosiah.jpg',
                      const Color(0xffF59E0B),
                    ),
                    _buildTeacherCard(
                      'Ustaz Abdul Hadee Balde',
                      'Teacher / Ustaz',
                      'Abdul Hadee graduated as valedictorian from Fanima Islamic School System and is a Hafiz from a renowned mission in Conakry, Guinea. Born in Ivory Coast and raised in Liberia, he later moved to Guinea for Islamic studies and earned a diploma. (King Khalid University. Languages: English, Arabic, Pular)',
                      ['English', 'Arabic', 'Pular'],
                      '—',
                      '—',
                      '—',
                      'assets/teachers/abdul_hadee_balde.jpg',
                      const Color(0xff8B5CF6),
                    ),
                    _buildTeacherCard(
                      'Ousman Cham',
                      'Teacher',
                      'Ousman is a graduate of Muslim Congress High School (Liberia) and studies at the Islamic University of Madinah (Department of Dawah). His passion for learning and teaching Islam began in childhood while listening to lectures from imams and preachers. He loves teaching Qur\'an for its great reward in this world and the Hereafter. (Languages: Pular, English, Arabic)',
                      ['Pular', 'English', 'Arabic'],
                      '—',
                      '—',
                      '—',
                      'assets/teachers/ousman_cham.jpg',
                      const Color(0xffEF4444),
                    ),
                  ],
                ),
              );
            },
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
    return GestureDetector(
      onTap: () => _showTeacherBioDialog(
          name, title, bio, specialties, imagePath, color),
      child: Container(
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
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.3), width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  imagePath,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color, color.withOpacity(0.7)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 40,
                      ),
                    );
                  },
                ),
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
            const SizedBox(height: 16),

            // Click to read more indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                'Tap to read full biography',
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

  void _showTeacherBioDialog(String name, String title, String bio,
      List<String> specialties, String imagePath, Color color) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width > 600
              ? 500
              : MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Close button
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Teacher Photo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(60),
                  border: Border.all(color: color.withOpacity(0.3), width: 3),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(57),
                  child: Image.asset(
                    imagePath,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color, color.withOpacity(0.7)],
                          ),
                          borderRadius: BorderRadius.circular(57),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 60,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Name and Title
              Text(
                name,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
              const SizedBox(height: 20),

              // Languages/Specialties
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: specialties
                    .map((specialty) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: color.withOpacity(0.3)),
                          ),
                          child: Text(
                            specialty,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: color,
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 24),

              // Full Biography
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Text(
                    bio,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xff6B7280),
                      height: 1.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Contact button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Navigate to contact page
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Contact Us for More Information',
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
        ),
      ),
    );
  }

  void _showApplicationDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TeacherApplicationScreen(),
      ),
    );
  }
}
