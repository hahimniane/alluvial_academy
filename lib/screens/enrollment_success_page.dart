import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../shared/widgets/fade_in_slide.dart';
import 'landing_page.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class EnrollmentSuccessPage extends StatelessWidget {
  const EnrollmentSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeInSlide(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xff10B981).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xff10B981),
                    size: 80,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FadeInSlide(
                delay: 0.2,
                child: Text(
                  AppLocalizations.of(context)!.requestReceived,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xff111827),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FadeInSlide(
                delay: 0.3,
                child: Text(
                  AppLocalizations.of(context)!.thankYouForYourInterestIn,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    color: const Color(0xff6B7280),
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              FadeInSlide(
                delay: 0.4,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LandingPage()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.backToHome,
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
      ),
    );
  }
}

