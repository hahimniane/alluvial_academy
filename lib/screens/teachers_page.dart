import 'package:flutter/material.dart';
import '../core/enums/ui_enums.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/modern_header.dart';
import '../shared/widgets/fade_in_slide.dart';
import 'teacher_application_screen.dart';
import 'leadership_application_screen.dart';
import 'contact_page.dart';
import 'dart:async';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class TeachersPage extends StatefulWidget {
  const TeachersPage({super.key});

  @override
  State<TeachersPage> createState() => _TeachersPageState();
}

class _TeachersPageState extends State<TeachersPage> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  final List<Teacher> _teachers = [
    Teacher(
      name: 'Ibrahim M. Baldee',
      title: AppLocalizations.of(context)!.teacherUstaz,
      bio: 'Ustaz Ibrahim is a Liberian international student currently based in Saudi Arabia. He completed the memorization of the Holy Qur\'an in 2012 and studied Tajweed in depth, memorizing many Tajweed texts. He has been teaching Qur\'an since 2012 and finds teaching among the most pleasant acts. He looks forward to meeting new students. (University of Madinah. Languages: Pular, English, Arabic)',
      specialties: ['Pular', 'English', 'Arabic'],
      imagePath: 'assets/teachers/ibrahim_baldee.jpg',
      color: const Color(0xff3B82F6),
    ),
    Teacher(
      name: 'Elham Shifa',
      title: AppLocalizations.of(context)!.teacherUstaza,
      bio: 'Elham is pursuing a degree in Islamic Psychology at Ankara University (Turkey). Originally from Ethiopia, she has been teaching for several years. Learning and teaching the Qur\'an to understand Allah\'s message has always been her life goal, inspired by the hadith: "The best of you are those who learn the Qur\'an and teach it." (Languages: English, Arabic)',
      specialties: ['English', 'Arabic'],
      imagePath: 'assets/teachers/elham_shifa.jpg',
      color: const Color(0xff10B981),
    ),
    Teacher(
      name: 'Mohammed Kosiah',
      title: AppLocalizations.of(context)!.teacherUstaz,
      bio: 'Brother Kosiah graduated from Kahatain Children Village Islamic Mission (2016) with foundations in Islam and secular education. He has delivered sermons and public talks since 5th grade and is active in youth/community development programs. He recently graduated from the intensive Arabic Institute of the Islamic University of Madinah and studies Economics at the same university. (Languages: Mandingo, French, English, Arabic)',
      specialties: ['Mandingo', 'French', 'English'],
      imagePath: 'assets/teachers/mohammed_kosiah.jpg',
      color: const Color(0xffF59E0B),
    ),
    Teacher(
      name: 'Ustaz Abdul Hadee Balde',
      title: AppLocalizations.of(context)!.teacherUstaz,
      bio: 'Abdul Hadee graduated as valedictorian from Fanima Islamic School System and is a Hafiz from a renowned mission in Conakry, Guinea. Born in Ivory Coast and raised in Liberia, he later moved to Guinea for Islamic studies and earned a diploma. (King Khalid University. Languages: English, Arabic, Pular)',
      specialties: ['English', 'Arabic', 'Pular'],
      imagePath: 'assets/teachers/abdul_hadee_balde.jpg',
      color: const Color(0xff8B5CF6),
    ),
    Teacher(
      name: 'Ousman Cham',
      title: AppLocalizations.of(context)!.roleTeacher,
      bio: 'Ousman is a graduate of Muslim Congress High School (Liberia) and studies at the Islamic University of Madinah (Department of Dawah). His passion for learning and teaching Islam began in childhood while listening to lectures from imams and preachers. He loves teaching Qur\'an for its great reward in this world and the Hereafter. (Languages: Pular, English, Arabic)',
      specialties: ['Pular', 'English', 'Arabic'],
      imagePath: 'assets/teachers/ousman_cham.jpg',
      color: const Color(0xffEF4444),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0, viewportFraction: 0.85);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 50), (Timer timer) {
      if (_currentPage < _teachers.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _teachers.length - 1) {
      _currentPage++;
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      // Loop back to start
       _currentPage = 0;
       _pageController.animateToPage(
         _currentPage,
         duration: const Duration(milliseconds: 500),
         curve: Curves.easeInOut,
       );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _currentPage--;
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
       // Loop to end
       _currentPage = _teachers.length - 1;
       _pageController.animateToPage(
         _currentPage,
         duration: const Duration(milliseconds: 500),
         curve: Curves.easeInOut,
       );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const ModernHeader(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeroSection(),
                  _buildCarouselSection(isDesktop),
                  _buildStatsSection(),
                  _buildJoinTeachersSection(),
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
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xffFAFBFF), Color(0xffF0F7FF)],
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
                AppLocalizations.of(context)!.qualifiedIslamicEducators,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xff3B82F6),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FadeInSlide(
            delay: 0.2,
            child: Text(
              AppLocalizations.of(context)!.learnFromCertifiedNislamicScholars,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: const Color(0xff111827),
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeInSlide(
            delay: 0.3,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Text(
                AppLocalizations.of(context)!.ourTeachersAreCertifiedIslamicScholars,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
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

  Widget _buildCarouselSection(bool isDesktop) {
    return Container(
      height: isDesktop ? 600 : 700,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Stack(
        alignment: Alignment.center,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _teachers.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              return _buildTeacherCard(_teachers[index], isDesktop);
            },
          ),
          
          // Left Arrow
          Positioned(
            left: isDesktop ? 40 : 10,
            child: IconButton(
              onPressed: _previousPage,
              icon: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Color(0xff3B82F6)),
              ),
            ),
          ),

          // Right Arrow
          Positioned(
            right: isDesktop ? 40 : 10,
            child: IconButton(
              onPressed: _nextPage,
              icon: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_forward_rounded, color: Color(0xff3B82F6)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherCard(Teacher teacher, bool isDesktop) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        double value = 1.0;
        if (_pageController.position.haveDimensions) {
          value = _pageController.page! - _teachers.indexOf(teacher);
          value = (1 - (value.abs() * 0.3)).clamp(0.0, 1.0);
        }
        
        return Center(
          child: SizedBox(
            height: Curves.easeOut.transform(value) * (isDesktop ? 550 : 650),
            width: Curves.easeOut.transform(value) * 800,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: teacher.color.withOpacity(0.3), width: 3),
              ),
              child: ClipOval(
                child: Image.asset(
                  teacher.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: teacher.color.withOpacity(0.1),
                      child: Icon(Icons.person, size: 60, color: teacher.color),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              teacher.name,
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: const Color(0xff111827),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              teacher.title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: teacher.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  teacher.bio,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: const Color(0xff6B7280),
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: teacher.specialties.map((specialty) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: teacher.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  specialty,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: teacher.color,
                  ),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
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
            AppLocalizations.of(context)!.whyChooseOurTeachers,
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: const Color(0xff111827),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 600;
                if (isDesktop) {
                  return Row(
                    children: [
                      Expanded(child: _buildQualityCard('🎓', 'Certified Scholars', 'All our teachers are certified Islamic scholars with proper Ijazah and qualifications.')),
                      const SizedBox(width: 24),
                      Expanded(child: _buildQualityCard('🌍', 'Global Experience', 'Our teachers have taught students from over 50 countries worldwide.')),
                      const SizedBox(width: 24),
                      Expanded(child: _buildQualityCard('💯', 'Proven Results', '98% of our students show significant improvement within 3 months.')),
                    ],
                  );
                } else {
                   return Column(
                    children: [
                      _buildQualityCard('🎓', 'Certified Scholars', 'All our teachers are certified Islamic scholars with proper Ijazah and qualifications.'),
                      const SizedBox(height: 24),
                      _buildQualityCard('🌍', 'Global Experience', 'Our teachers have taught students from over 50 countries worldwide.'),
                      const SizedBox(height: 24),
                      _buildQualityCard('💯', 'Proven Results', '98% of our students show significant improvement within 3 months.'),
                    ],
                   );
                }
              }
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
            textAlign: TextAlign.center,
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
            AppLocalizations.of(context)!.teachForUs,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.9),
              letterSpacing: 2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  tabs: const [
                    Tab(text: AppLocalizations.of(context)!.becomeATeacher),
                    Tab(text: AppLocalizations.of(context)!.career),
                  ],
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.7),
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelStyle: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  height: 200,
                  child: TabBarView(
                    children: [
                      // Become a Teacher Tab
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.wantToBecomeATeacher,
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            AppLocalizations.of(context)!.joinOurTeamOfDedicatedIslamic,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const TeacherApplicationScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.person_add_rounded, size: 24),
                            label: Text(AppLocalizations.of(context)!.applyToTeach),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xff3B82F6),
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Career Tab
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.joinOurLeadershipTeam,
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            AppLocalizations.of(context)!.leadInspireAndMakeALasting,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LeadershipApplicationScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.group_add_rounded, size: 24),
                            label: Text(AppLocalizations.of(context)!.applyForLeadership),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xff10B981),
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Teacher {
  final String name;
  final String title;
  final String bio;
  final List<String> specialties;
  final String imagePath;
  final Color color;

  Teacher({
    required this.name,
    required this.title,
    required this.bio,
    required this.specialties,
    required this.imagePath,
    required this.color,
  });
}

