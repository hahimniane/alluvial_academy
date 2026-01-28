import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/modern_header.dart';
import '../shared/widgets/fade_in_slide.dart';
import 'program_selection_page.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class EnglishPage extends StatefulWidget {
  const EnglishPage({super.key});

  @override
  State<EnglishPage> createState() => _EnglishPageState();
}

class _EnglishPageState extends State<EnglishPage> {
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
          colors: [Color(0xffFEF3C7), Color(0xffFDE68A)],
        ),
      ),
      child: Column(
        children: [
          FadeInSlide(
            delay: 0.1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xffF59E0B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: const Color(0xffF59E0B).withOpacity(0.2)),
              ),
              child: Text(
                AppLocalizations.of(context)!.englishLanguageProgram,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xffF59E0B),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FadeInSlide(
            delay: 0.2,
            child: Text(
              AppLocalizations.of(context)!.masterEnglishWithNconfidenceFluency,
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
                AppLocalizations.of(context)!.designedForAdultsWhoWantTo,
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
          AppLocalizations.of(context)!.whyChooseOurEnglishProgram,
          style: GoogleFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: const Color(0xff111827),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          AppLocalizations.of(context)!.englishIsTheGlobalLanguageOf,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: const Color(0xff374151),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),
        _buildFeatureItem(
          Icons.book_rounded,
          'Reading Comprehension',
          'Develop critical reading skills and understand complex texts across various genres.',
        ),
        const SizedBox(height: 16),
        _buildFeatureItem(
          Icons.edit_rounded,
          'Writing Excellence',
          'Master essay writing, creative writing, and academic composition with structured guidance.',
        ),
        const SizedBox(height: 16),
        _buildFeatureItem(
          Icons.record_voice_over_rounded,
          'Speaking & Listening',
          'Build confidence in conversation, pronunciation, and public speaking skills.',
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
            colors: [Color(0xffF59E0B), Color(0xffD97706)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xffF59E0B).withOpacity(0.3),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.menu_book_rounded,
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
            color: const Color(0xffF59E0B).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: const Color(0xffF59E0B), size: 24),
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
      _buildTopicCard('Grammar & Vocabulary', 'All Levels', const Color(0xff10B981), 
          description: 'Master English grammar rules, sentence structure, and expand your vocabulary.'),
      _buildTopicCard('Reading Comprehension', 'Elementary to Advanced', const Color(0xff3B82F6), 
          description: 'Develop critical reading skills and analyze texts across various genres.'),
      _buildTopicCard('Creative Writing', 'Grades 3-12', const Color(0xff8B5CF6), 
          description: 'Express yourself through stories, poetry, and creative narratives.'),
      _buildTopicCard('Academic Writing', 'High School & College', const Color(0xffEF4444), 
          description: 'Master essays, research papers, and formal academic composition.'),
      _buildTopicCard('Literature Analysis', 'High School', const Color(0xff06B6D4), 
          description: 'Explore classic and contemporary literature with in-depth analysis.'),
      _buildTopicCard('Test Preparation', 'All Ages', const Color(0xffF59E0B), 
          description: 'Prepare for standardized tests including SAT, ACT, IELTS, and TOEFL.'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      decoration: const BoxDecoration(color: Color(0xffF9FAFB)),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context)!.topicsWeCover,
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
                child: Icon(Icons.menu_book_rounded, color: color, size: 30),
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
                      builder: (context) => const ProgramSelectionPage(initialSubject: 'Adult Literacy'),
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
                child: Text(AppLocalizations.of(context)!.enrollNow),
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
          colors: [Color(0xffF59E0B), Color(0xffD97706)],
        ),
      ),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context)!.adultEnglishLiteracyProgram,
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
            AppLocalizations.of(context)!.learnEnglishReadingWritingSpeakingFor,
            style: GoogleFonts.inter(
              fontSize: 18,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.noteStudentsNeedingEnglishHelpShould,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProgramSelectionPage(initialSubject: 'English'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xffF59E0B),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              AppLocalizations.of(context)!.startLearning,
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

