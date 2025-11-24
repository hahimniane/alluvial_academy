import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/modern_header.dart';
import '../shared/widgets/fade_in_slide.dart';
import 'program_selection_page.dart';

class MathPage extends StatefulWidget {
  const MathPage({super.key});

  @override
  State<MathPage> createState() => _MathPageState();
}

class _MathPageState extends State<MathPage> {
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
                  _buildTopicsSection(),
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
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xffEFF6FF), Color(0xffDBEAFE)],
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
                '∑ Mathematics Program',
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
              'Master Mathematics with\nConfidence & Clarity',
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
              constraints: const BoxConstraints(maxWidth: 700),
              child: Text(
                'From basic arithmetic to advanced calculus, our comprehensive math program helps students build a strong foundation and excel in their studies.',
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 900;
            
            return isDesktop
                ? Row(
                    children: [
                      Expanded(child: _buildOverviewContent()),
                      const SizedBox(width: 60),
                      Expanded(child: _buildOverviewImage()),
                    ],
                  )
                : Column(
                    children: [
                      _buildOverviewContent(),
                      const SizedBox(height: 48),
                      _buildOverviewImage(),
                    ],
                  );
          },
        ),
      ),
    );
  }

  Widget _buildOverviewContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Why Choose Our Math Program?',
          style: GoogleFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: const Color(0xff111827),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Mathematics is more than just numbers; it\'s a way of thinking. Our expert tutors use engaging methods to make complex concepts easy to understand, fostering a love for problem-solving.',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: const Color(0xff374151),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),
        _buildFeatureItem(
          Icons.functions_rounded,
          'Concept Mastery',
          'Focus on understanding the "why" behind the math, not just memorizing formulas.',
        ),
        const SizedBox(height: 16),
        _buildFeatureItem(
          Icons.trending_up_rounded,
          'Personalized Pace',
          'Learn at your own speed with customized lesson plans tailored to your level.',
        ),
        const SizedBox(height: 16),
        _buildFeatureItem(
          Icons.assignment_turned_in_rounded,
          'Exam Preparation',
          'Targeted practice for school exams, standardized tests, and competitions.',
        ),
      ],
    );
  }

  Widget _buildOverviewImage() {
    return FadeInSlide(
      delay: 0.4,
      child: Container(
        height: 400,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            colors: [Color(0xff3B82F6), Color(0xff2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xff3B82F6).withOpacity(0.3),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.calculate_rounded,
            color: Colors.white,
            size: 120,
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xff3B82F6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: const Color(0xff3B82F6), size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff111827),
                ),
              ),
              const SizedBox(height: 4),
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
    );
  }

  Widget _buildTopicsSection() {
    final topics = [
      _buildTopicCard('Elementary Math', 'Grades K-5', const Color(0xff10B981), 
          description: 'Building a strong foundation in arithmetic, shapes, and problem-solving.'),
      _buildTopicCard('Pre-Algebra & Algebra', 'Grades 6-9', const Color(0xffF59E0B), 
          description: 'Mastering variables, equations, functions, and graphing.'),
      _buildTopicCard('Geometry', 'Grades 8-10', const Color(0xff8B5CF6), 
          description: 'Exploring shapes, sizes, relative positions, and properties of space.'),
      _buildTopicCard('Trigonometry', 'Grades 10-11', const Color(0xffEF4444), 
          description: 'Understanding relationships between side lengths and angles of triangles.'),
      _buildTopicCard('Calculus', 'Grades 11-12+', const Color(0xff06B6D4), 
          description: 'Diving into limits, derivatives, integrals, and infinite series.'),
      _buildTopicCard('Statistics', 'High School & College', const Color(0xff3B82F6), 
          description: 'Analyzing data, probability, distributions, and inference.'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      decoration: const BoxDecoration(color: Color(0xffF9FAFB)),
      child: Column(
        children: [
          Text(
            'Topics We Cover',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: const Color(0xff111827),
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
                  return Column(
                    children: topics.map((card) => Padding(
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
                  childAspectRatio: isDesktop ? 1.1 : 1.2,
                  children: topics,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicCard(String topic, String level, Color color, {String? description}) {
    return FadeInSlide(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Icon(Icons.functions, color: color, size: 30),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              topic,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xff111827),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              level,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 12),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xff6B7280),
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProgramSelectionPage(initialSubject: 'Maths'),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Enroll Now'),
              ),
            ),
          ],
        ),
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
            'Unlock Your Math Potential Today',
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
            'Join thousands of students excelling in mathematics',
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
                  builder: (context) => const ProgramSelectionPage(initialSubject: 'Maths'),
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
              'Start Learning',
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
}

