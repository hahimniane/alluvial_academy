import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/modern_header.dart';
import '../shared/widgets/fade_in_slide.dart';
import 'program_selection_page.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AfrolingualPage extends StatefulWidget {
  const AfrolingualPage({super.key});

  @override
  State<AfrolingualPage> createState() => _AfrolingualPageState();
}

class _AfrolingualPageState extends State<AfrolingualPage> {
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
                  _buildLanguagesOffered(),
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
          colors: [Color(0xffFFF7ED), Color(0xffFFFBEB)],
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
                AppLocalizations.of(context)!.globalLanguagesProgram,
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
              AppLocalizations.of(context)!.masterEnglishAfricanNindigenousLanguages,
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
                AppLocalizations.of(context)!.fromMasteringEnglishGrammarAndVocabulary,
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
          AppLocalizations.of(context)!.languageExcellence,
          style: GoogleFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: const Color(0xff111827),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          AppLocalizations.of(context)!.ourLanguageProgramsAreDesignedTo,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: const Color(0xff374151),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),
        _buildFeatureItem(
          Icons.school_rounded,
          'English Mastery',
          'Comprehensive support including homework help, reading comprehension, grammar, vocabulary, and exam preparation.',
        ),
        const SizedBox(height: 16),
        _buildFeatureItem(
          Icons.language_rounded,
          'African Languages',
          'Authentic instruction in major African languages from native speakers.',
        ),
        const SizedBox(height: 16),
        _buildFeatureItem(
          Icons.psychology_rounded,
          'Personalized Learning',
          'Tailored curriculum to meet individual student needs and goals.',
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
            Icons.translate_rounded,
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

  Widget _buildLanguagesOffered() {
    final languages = [
      _buildLanguageCard('English', 'Global', const Color(0xff3B82F6), 
          description: 'Complete support for reading, writing, grammar, vocabulary, and exam prep.'),
      _buildLanguageCard('French', 'Global', const Color(0xff6366F1), 
          description: 'Master French language skills including conversation, grammar, and cultural understanding.'),
      _buildLanguageCard('Adlam', 'West Africa', const Color(0xff8B5CF6),
          description: 'Learn the Adlam script for writing Fulani (Fulfulde/Pular), a modern alphabet created to preserve and promote this important West African language.'),
      _buildLanguageCard('Swahili', 'East Africa', const Color(0xff10B981)),
      _buildLanguageCard('Yoruba', 'West Africa', const Color(0xff8B5CF6)),
      _buildLanguageCard('Amharic', 'Horn of Africa', const Color(0xffEF4444)),
      _buildLanguageCard('Wolof', 'West Africa', const Color(0xff06B6D4)),
      _buildLanguageCard('Hausa', 'West & Central Africa', const Color(0xffF59E0B)),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      decoration: const BoxDecoration(color: Color(0xffF9FAFB)),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context)!.languagesWeOffer,
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
                  // Mobile: Column
                  return Column(
                    children: languages.map((card) => Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: card,
                    )).toList(),
                  );
                }

                // Tablet/Desktop: Grid
                final crossAxisCount = isDesktop ? 3 : 2;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 32,
                  mainAxisSpacing: 32,
                  childAspectRatio: isDesktop ? 0.85 : 0.9,
                  children: languages,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageCard(String language, String region, Color color, {String? description}) {
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
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  language[0],
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              language,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xff111827),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              region,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xff6B7280),
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Spacer(),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  // Map language to subject based on new system
                  String subject;
                  bool isLanguageSelection = true;
                  String? selectedLanguage;
                  
                  if (language == 'English' || language == 'French' || language == 'Adlam') {
                    subject = language;
                    selectedLanguage = null;
                  } else {
                    // For other African languages, use "African Languages (Other)" and pre-select the language
                    subject = 'African Languages (Other)';
                    selectedLanguage = language;
                  }
                  
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProgramSelectionPage(
                        initialSubject: 'AfroLanguage: Poular, Mandingo, Swahili',
                      ),
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
            AppLocalizations.of(context)!.beginYourLanguageJourney,
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
            AppLocalizations.of(context)!.connectWithTheWorldThroughLanguage,
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
                  builder: (context) => const ProgramSelectionPage(
                    initialSubject: 'AfroLanguage: Poular, Mandingo, Swahili',
                  ),
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
