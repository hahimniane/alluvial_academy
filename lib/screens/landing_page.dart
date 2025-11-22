import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/modern_header.dart';
import '../shared/widgets/fade_in_slide.dart';
import 'program_selection_page.dart';
import 'teachers_page.dart';
import 'islamic_courses_page.dart';
import 'math_page.dart';
import 'programming_page.dart';
import 'english_page.dart';
import 'afrolingual_page.dart';
import 'tutoring_literacy_page.dart';
import 'about_page.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<String> _suggestions = [];
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;
  late PageController _testimonialController;
  int _currentTestimonialIndex = 0;
  
  final List<String> _allSubjects = [
    'Maths',
    'Islamic Studies',
    'English',
    'Programming',
    'Arabic',
    'Quran',
    'Science',
    'Physics',
    'Chemistry'
  ];

  final List<Map<String, String>> _testimonials = [
    {
      'name': 'Aisha Muhammad',
      'role': 'Parent of 3 students',
      'text': 'Alhamdulillah, my children have grown so much in their Islamic knowledge since joining. The teachers are patient, knowledgeable, and truly care about each student\'s progress.',
    },
    {
      'name': 'Ibrahim Diallo',
      'role': 'Parent',
      'text': 'The Afrolingual program has been a blessing. My son is now fluent in Mandinka and connected to his heritage. The quality of education here is exceptional.',
    },
    {
      'name': 'Fatima Al-Hassan',
      'role': 'Parent of 2 students',
      'text': 'The tutoring program helped my daughter improve her grades significantly. The Islamic studies classes have strengthened our children\'s faith and character.',
    },
    {
      'name': 'Mahmoud Bakr',
      'role': 'Parent',
      'text': 'Excellent Quran memorization program! My daughter has memorized 5 Juz in just one year. The teachers use modern techniques while maintaining traditional values.',
    },
    {
      'name': 'Khadijah Williams',
      'role': 'Parent of 4 students',
      'text': 'This academy has been a cornerstone for our family. All my children attend different programs and each one is thriving. The community here is warm and supportive.',
    },
    {
      'name': 'Omar Sheikh',
      'role': 'Parent',
      'text': 'The online classes are well-structured and engaging. My sons look forward to their Islamic studies classes. The teachers make learning fun while being thorough.',
    },
  ];

  @override
  void initState() {
    super.initState();
    // Setup floating animation for hero image
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    
    _floatAnimation = Tween<double>(begin: -10.0, end: 10.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );
    
    _testimonialController = PageController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _floatController.dispose();
    _testimonialController.dispose();
    super.dispose();
  }
  
  void _previousTestimonial() {
    if (_currentTestimonialIndex > 0) {
      _testimonialController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Loop to last
      _testimonialController.animateToPage(
        _testimonials.length - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  void _nextTestimonial() {
    if (_currentTestimonialIndex < _testimonials.length - 1) {
      _testimonialController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Loop to first
      _testimonialController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    setState(() {
      _suggestions = _allSubjects
          .where((subject) => subject.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _onSuggestionSelected(String subject) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProgramSelectionPage(initialSubject: subject),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffFAFAFA), // Softer white
      body: Column(
        children: [
          const ModernHeader(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(), // Smoother scroll
              child: Column(
                children: [
                  _buildHeroSection(),
                  _buildProgramsSection(),
                  _buildEnrollSection(),
                  _buildAboutUsSection(),
                  _buildTestimonialSection(),
                  _buildFooterPlaceholder(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    final isDesktop = MediaQuery.of(context).size.width > 1024;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      decoration: const BoxDecoration(
        color: Color(0xff001E4E), // Deep Navy Blue background from image
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: isDesktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 5, child: _buildHeroContent()),
                  const SizedBox(width: 48),
                  Expanded(flex: 5, child: _buildHeroImage()),
                ],
              )
            : Column(
                children: [
                  _buildHeroContent(),
                  const SizedBox(height: 48),
                  _buildHeroImage(),
                ],
              ),
      ),
    );
  }

  Widget _buildHeroContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeInSlide(
          delay: 0.2,
          child: Text(
            'Learn with online tutoring\nfrom anywhere in the world',
            style: GoogleFonts.inter(
              fontSize: 48,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 32),
        
        // Search Bar
        FadeInSlide(
          delay: 0.4,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Our Teachers Button
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const TeachersPage()),
                      );
                    },
                    icon: const Icon(Icons.school_rounded, size: 20),
                    label: Text(
                      'Our Teachers',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xff001E4E),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),

                Container(
                  height: 50, // Smaller, more compact
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onSubmitted: (value) {
                      if (value.isNotEmpty) _onSuggestionSelected(value);
                    },
                    style: GoogleFonts.inter(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'What would you like to learn?',
                      hintStyle: GoogleFonts.inter(
                        color: const Color(0xff9CA3AF),
                        fontSize: 15,
                      ),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Icon(Icons.search, color: const Color(0xff3B82F6), size: 22),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                  ),
                ),
                
                // Suggestions Dropdown
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8, left: 12, right: 12),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: _suggestions.map((subject) => InkWell(
                        onTap: () => _onSuggestionSelected(subject),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.history, size: 18, color: Color(0xff9CA3AF)),
                              const SizedBox(width: 12),
                              Text(
                                subject,
                                style: GoogleFonts.inter(
                                  fontSize: 15, 
                                  color: const Color(0xff374151),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Quick Categories - Simple text links/chips
        FadeInSlide(
          delay: 0.5,
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _TextCategoryLink('Islamic Studies', categoryType: CategoryType.islamicStudies),
              _TextCategoryLink('Maths', categoryType: CategoryType.math),
              _TextCategoryLink('English', categoryType: CategoryType.english),
              _TextCategoryLink('Programming', categoryType: CategoryType.programming),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Checkmarks / Features
        FadeInSlide(
          delay: 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFeatureItem('Meet the tutor. Try for free'),
              const SizedBox(height: 8),
              _buildFeatureItem(' Get help with your quran and islamic studies'),
              const SizedBox(height: 8),
              _buildFeatureItem('Get help from our engineers and programmers'),
            ],
          ),
        ),

        const SizedBox(height: 48),

        // Trustpilot / Rating
        FadeInSlide(
          delay: 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Excellent',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) => Container(
                      margin: const EdgeInsets.only(right: 2),
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xff00B67A), // Trustpilot Green
                        shape: BoxShape.rectangle,
                      ),
                      child: const Icon(Icons.star, color: Colors.white, size: 16),
                    )),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Trusted by Muslim families worldwide',
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(String text) {
    return Row(
      children: [
        const Icon(Icons.check, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroImage() {
    // Using a placeholder composition to mimic the 3-image layout
    // In a real app, you would position actual images here
    return FadeInSlide(
      delay: 0.2,
      beginOffset: const Offset(0.1, 0),
      child: AnimatedBuilder(
        animation: _floatAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _floatAnimation.value),
            child: child,
          );
        },
        child: SizedBox(
          height: 450,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Center Laptop Image (Main)
              Positioned(
                right: 40,
                top: 20,
                bottom: 60,
                width: 400,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(100),
                    ),
                    color: Colors.white,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(36),
                      topRight: Radius.circular(36),
                      bottomLeft: Radius.circular(36),
                      bottomRight: Radius.circular(96),
                    ),
                    child: Image.asset(
                      'assets/background_images/smiling_student.jpg', // Laptop/learning image
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              
              // Left Circle (Woman)
              Positioned(
                left: 0,
                bottom: 80,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xffA5D6A7), // Light green accent
                    border: Border.all(color: const Color(0xff001E4E), width: 4),
                    image: const DecorationImage(
                      image: AssetImage('assets/teachers/elham_shifa.jpg'), // Placeholder woman
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

              // Right Blob (Man)
              Positioned(
                right: 0,
                bottom: 40,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(70),
                      topRight: Radius.circular(70),
                      bottomLeft: Radius.circular(70),
                      bottomRight: Radius.circular(10),
                    ),
                    color: const Color(0xffFFE082), // Amber accent
                    border: Border.all(color: const Color(0xff001E4E), width: 4),
                    image: const DecorationImage(
                      image: AssetImage('assets/teachers/mohammed_kosiah.jpg'), // Placeholder man
                      fit: BoxFit.cover,
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

  Widget _buildProgramsSection() {
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    final isTablet = MediaQuery.of(context).size.width > 600;
    
    final programs = [
      _ProgramCard(
        title: 'Islamic Studies',
        icon: Icons.mosque_rounded,
        color: const Color(0xff3B82F6),
        description: 'Quran, Hadith, Arabic, Tawhid, Tafsir & more',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const IslamicCoursesPage()),
          );
        },
      ),
      _ProgramCard(
        title: 'Languages',
        icon: Icons.language_rounded,
        color: const Color(0xffF59E0B),
        description: 'English, French & African languages',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AfrolingualPage()),
          );
        },
      ),
      _ProgramCard(
        title: 'Math Classes',
        icon: Icons.functions_rounded,
        color: const Color(0xff10B981),
        description: 'From elementary to advanced calculus',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MathPage()),
          );
        },
      ),
      _ProgramCard(
        title: 'Programming',
        icon: Icons.code_rounded,
        color: const Color(0xff8B5CF6),
        description: 'Web, mobile & software development',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProgrammingPage()),
          );
        },
      ),
      _ProgramCard(
        title: 'After School Tutoring',
        icon: Icons.school_rounded,
        color: const Color(0xffEF4444),
        description: 'Academic support & literacy programs',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TutoringLiteracyPage()),
          );
        },
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xffF9FAFB), Color(0xffFFFFFF)],
        ),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          children: [
            FadeInSlide(
              delay: 0.1,
              child: Text(
                'Find Your Program',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: isDesktop ? 42 : 32,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xff111827),
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FadeInSlide(
              delay: 0.2,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Text(
                  'Explore our comprehensive range of educational programs designed to meet your learning goals',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    color: const Color(0xff6B7280),
                    height: 1.6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  // Mobile: Single column
                  return Column(
                    children: programs.map((program) => Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: program,
                    )).toList(),
                  );
                } else if (constraints.maxWidth < 1024) {
                  // Tablet: 2 columns
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: 1.15,
                    children: programs,
                  );
                } else if (constraints.maxWidth < 1400) {
                  // Medium Desktop: 3 columns
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 24,
                    childAspectRatio: 1.0,
                    children: programs,
                  );
                } else {
                  // Large Desktop: 5 columns in a single row
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: programs.map((program) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: program,
                      ),
                    )).toList(),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnrollSection() {
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff001E4E), Color(0xff003399)],
        ),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: isDesktop
            ? Row(
                children: [
                  Expanded(
                    child: FadeInSlide(
                      delay: 0.1,
                      beginOffset: const Offset(-0.2, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ready to Start Learning?',
                            style: GoogleFonts.inter(
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Join thousands of students worldwide who are already benefiting from our comprehensive educational programs. Start your journey today with a free trial class.',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              color: Colors.white.withOpacity(0.9),
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
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
                                  foregroundColor: const Color(0xff001E4E),
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 4,
                                ),
                                child: Text(
                                  'Enroll Now',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              OutlinedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const TeachersPage(),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white, width: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Meet Our Teachers',
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
                    ),
                  ),
                  const SizedBox(width: 60),
                  Expanded(
                    child: FadeInSlide(
                      delay: 0.3,
                      beginOffset: const Offset(0.2, 0),
                      child: Container(
                        height: 300,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/background_images/smiling_student.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.white.withOpacity(0.1),
                                child: const Center(
                                  child: Icon(Icons.school_rounded, size: 100, color: Colors.white70),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  FadeInSlide(
                    delay: 0.1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ready to Start Learning?',
                          style: GoogleFonts.inter(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Join thousands of students worldwide who are already benefiting from our comprehensive educational programs. Start your journey today with a free trial class.',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
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
                              foregroundColor: const Color(0xff001E4E),
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                            child: Text(
                              'Enroll Now',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const TeachersPage(),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white, width: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Meet Our Teachers',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  FadeInSlide(
                    delay: 0.3,
                    child: Container(
                      height: 250,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/background_images/smiling_student.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.white.withOpacity(0.1),
                              child: const Center(
                                child: Icon(Icons.school_rounded, size: 80, color: Colors.white70),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAboutUsSection() {
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          children: [
            FadeInSlide(
              delay: 0.1,
              child: Text(
                'About Alluwal Education Hub',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: isDesktop ? 42 : 32,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xff111827),
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FadeInSlide(
              delay: 0.2,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Text(
                  'We are fostering a world where diverse knowledge—Islamic, African, and Western—comes together to prepare students for a globalized future.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    color: const Color(0xff6B7280),
                    height: 1.6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
            isDesktop
                ? Row(
                    children: [
                      Expanded(
                        child: FadeInSlide(
                          delay: 0.3,
                          beginOffset: const Offset(-0.2, 0),
                          child: _buildAboutCard(
                            Icons.rocket_launch_rounded,
                            'Our Mission',
                            const Color(0xff3B82F6),
                            'To integrate Islamic, African, and Western education, offering a holistic curriculum that prepares students to navigate and succeed in a diverse world.',
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: FadeInSlide(
                          delay: 0.4,
                          beginOffset: const Offset(0.2, 0),
                          child: _buildAboutCard(
                            Icons.visibility_rounded,
                            'Our Vision',
                            const Color(0xff10B981),
                            'To create an inclusive, inspiring environment where students are encouraged to become leaders in their communities.',
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      FadeInSlide(
                        delay: 0.3,
                        child: _buildAboutCard(
                          Icons.rocket_launch_rounded,
                          'Our Mission',
                          const Color(0xff3B82F6),
                          'To integrate Islamic, African, and Western education, offering a holistic curriculum that prepares students to navigate and succeed in a diverse world.',
                        ),
                      ),
                      const SizedBox(height: 24),
                      FadeInSlide(
                        delay: 0.4,
                        child: _buildAboutCard(
                          Icons.visibility_rounded,
                          'Our Vision',
                          const Color(0xff10B981),
                          'To create an inclusive, inspiring environment where students are encouraged to become leaders in their communities.',
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 40),
            FadeInSlide(
              delay: 0.5,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AboutPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff001E4E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  'Learn More About Us',
                  style: GoogleFonts.inter(
                    fontSize: 16,
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

  Widget _buildAboutCard(IconData icon, String title, Color color, String description) {
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
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
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
          const SizedBox(height: 12),
          Text(
            description,
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

  Widget _buildTestimonialSection() {
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      color: const Color(0xff003399), // Darker blue background
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: isDesktop
            ? Row(
                children: [
                  Expanded(child: _buildTestimonialContent()),
                  const SizedBox(width: 64),
                  Expanded(child: _buildTestimonialImage()),
                ],
              )
            : Column(
                children: [
                  _buildTestimonialImage(),
                  const SizedBox(height: 48),
                  _buildTestimonialContent(),
                ],
              ),
      ),
    );
  }

  Widget _buildTestimonialContent() {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: isMobile ? 24 : 32,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Icon(
                Icons.person_rounded,
                size: isMobile ? 30 : 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _testimonials[_currentTestimonialIndex]['name']!,
                    style: GoogleFonts.inter(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _testimonials[_currentTestimonialIndex]['role']!,
                    style: GoogleFonts.inter(
                      fontSize: isMobile ? 12 : 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: isMobile ? 250 : 220,
          child: PageView.builder(
            controller: _testimonialController,
            onPageChanged: (index) {
              setState(() {
                _currentTestimonialIndex = index;
              });
            },
            itemCount: _testimonials.length,
            itemBuilder: (context, index) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Arrow
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: _previousTestimonial,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chevron_left,
                          color: Colors.white,
                          size: isMobile ? 24 : 28,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isMobile ? 4 : 8),
                  // Testimonial Text Bubble
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(isMobile ? 20 : 32),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.zero,
                          topRight: Radius.circular(24),
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          _testimonials[index]['text']!,
                          style: GoogleFonts.inter(
                            fontSize: isMobile ? 16 : 20,
                            height: 1.5,
                            color: const Color(0xff111827),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isMobile ? 4 : 8),
                  // Right Arrow
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: _nextTestimonial,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chevron_right,
                          color: Colors.white,
                          size: isMobile ? 24 : 28,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        // Dots indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _testimonials.length,
            (index) => _buildDot(index == _currentTestimonialIndex),
          ),
        ),
      ],
    );
  }

  Widget _buildTestimonialImage() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 400),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/background_images/zoom_class.jpeg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 300,
                  color: Colors.grey[300],
                  child: const Icon(Icons.image, size: 100, color: Colors.grey),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'With your tutor, you will be able to learn and apply on the go.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: Colors.white,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDot(false),
            const SizedBox(width: 8),
            _buildDot(false),
            const SizedBox(width: 8),
            _buildDot(true),
          ],
        ),
      ],
    );
  }

  Widget _buildDot(bool isActive) {
    return Container(
      width: isActive ? 12 : 8,
      height: isActive ? 12 : 8,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildFooterPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      color: const Color(0xff111827),
      child: Center(
        child: Text(
          '© 2024 Alluwal Education Hub',
          style: GoogleFonts.inter(color: Colors.white54),
        ),
      ),
    );
  }
}

enum CategoryType {
  islamicStudies,
  math,
  programming,
  english,
  general,
}

class _ProgramCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String description;
  final VoidCallback onTap;

  const _ProgramCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FadeInSlide(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xffE5E7EB), width: 1),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
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
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      'Learn more',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, color: color, size: 18),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TextCategoryLink extends StatefulWidget {
  final String label;
  final CategoryType categoryType;

  const _TextCategoryLink(this.label, {this.categoryType = CategoryType.general});

  @override
  State<_TextCategoryLink> createState() => _TextCategoryLinkState();
}

class _TextCategoryLinkState extends State<_TextCategoryLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          switch (widget.categoryType) {
            case CategoryType.islamicStudies:
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const IslamicCoursesPage(),
                ),
              );
              break;
            case CategoryType.math:
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MathPage(),
                ),
              );
              break;
            case CategoryType.programming:
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProgrammingPage(),
                ),
              );
              break;
            case CategoryType.english:
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EnglishPage(),
                ),
              );
              break;
            case CategoryType.general:
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProgramSelectionPage(initialSubject: widget.label),
                ),
              );
              break;
          }
        },
        child: Text(
          widget.label,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _isHovered ? const Color(0xff3B82F6) : Colors.white, // Blue on hover, white otherwise
            decoration: _isHovered ? TextDecoration.underline : TextDecoration.none,
            decorationColor: const Color(0xff3B82F6),
          ),
        ),
      ),
    );
  }
}
