import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/modern_header.dart';
import '../shared/widgets/fade_in_slide.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import 'team_page.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  List<StaffMember> _leadership = [];

  @override
  void initState() {
    super.initState();
    _loadLeadership();
  }

  Future<void> _loadLeadership() async {
    try {
      final staff = await loadStaffData();
      if (mounted) {
        setState(() {
          _leadership =
              staff.where((s) => s.category == 'leadership').toList();
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const ModernHeader(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildHeroSection(),
                  _buildMissionVisionSection(),
                  _buildCoreValuesSection(),
                  _buildJourneyTimeline(),
                  _buildTeamSection(),
                  _buildStatsSection(),
                  _buildFooterQuote(),
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
        color: Color(0xff001E4E),
      ),
      child: Column(
        children: [
          FadeInSlide(
            delay: 0.1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                AppLocalizations.of(context)!.learnLeadThrive,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          FadeInSlide(
            delay: 0.2,
            child: Text(
              AppLocalizations.of(context)!.whereEducationTranscendsBoundaries,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 24),
          FadeInSlide(
            delay: 0.3,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Text(
                AppLocalizations.of(context)!.weAreFosteringAWorldWhere,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  color: Colors.white.withOpacity(0.8),
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionVisionSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 900;
            return isDesktop
                ? Row(
                    children: [
                      Expanded(child: _buildMissionCard()),
                      const SizedBox(width: 32),
                      Expanded(child: _buildVisionCard()),
                    ],
                  )
                : Column(
                    children: [
                      _buildMissionCard(),
                      const SizedBox(height: 32),
                      _buildVisionCard(),
                    ],
                  );
          },
        ),
      ),
    );
  }

  Widget _buildMissionCard() {
    return _InfoCard(
      icon: Icons.rocket_launch_rounded,
      title: AppLocalizations.of(context)!.ourMission,
      color: const Color(0xff3B82F6),
      content: AppLocalizations.of(context)!.toIntegrateIslamicAfricanAndWestern,
    );
  }

  Widget _buildVisionCard() {
    return _InfoCard(
      icon: Icons.visibility_rounded,
      title: AppLocalizations.of(context)!.ourVision,
      color: const Color(0xff10B981),
      content: AppLocalizations.of(context)!.toCreateAnInclusiveInspiringEnvironment,
    );
  }

  Widget _buildCoreValuesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      decoration: const BoxDecoration(color: Color(0xffF8FAFC)),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context)!.coreValues,
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 48),
          Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Wrap(
              spacing: 24,
              runSpacing: 24,
              alignment: WrapAlignment.center,
              children: [
                _buildValueCard('Authenticity', 'Rooted in Quran & Sunnah', Icons.verified_rounded),
                _buildValueCard('Compassion', 'Patience & care for all', Icons.volunteer_activism_rounded),
                _buildValueCard('Excellence', 'High standards in education', Icons.star_rounded),
                _buildValueCard('Community', 'Supportive global network', Icons.groups_rounded),
                _buildValueCard('Knowledge', 'Transformative learning', Icons.menu_book_rounded),
                _buildValueCard('Accessibility', 'Available worldwide', Icons.public_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValueCard(String title, String subtitle, IconData icon) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Icon(icon, size: 40, color: const Color(0xff3B82F6)),
          const SizedBox(height: 16),
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
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: const Color(0xff6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyTimeline() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context)!.ourJourney,
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 48),
          Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                _buildTimelineItem('2020', 'Vision Founded', 'The seed of Alluwal was planted.'),
                _buildArrow(),
                _buildTimelineItem('2021', 'First Teachers', 'Recruited passionate educators.'),
                _buildArrow(),
                _buildTimelineItem('2022', 'Platform Launch', 'Officially opened our virtual doors.'),
                _buildArrow(),
                _buildTimelineItem('2023', 'Global Expansion', 'Reached students in 20+ countries.'),
                _buildArrow(),
                _buildTimelineItem('2024', 'Growth', 'New courses & 5,000+ students reached.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String year, String title, String desc) {
    return FadeInSlide(
      child: Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xffE5E7EB)),
        ),
        child: Row(
          children: [
            Text(
              year,
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: const Color(0xff3B82F6),
              ),
            ),
            const SizedBox(width: 24),
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
                  Text(
                    desc,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: const Color(0xff6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArrow() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xff9CA3AF), size: 32),
    );
  }

  Widget _buildTeamSection() {
    final founder =
        _leadership.isNotEmpty ? _leadership.first : null;
    final others =
        _leadership.length > 1 ? _leadership.sublist(1) : <StaffMember>[];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      decoration: const BoxDecoration(color: Color(0xffF8FAFC)),
      child: Column(
        children: [
          // Section label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFC9A84C).withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                  color: const Color(0xFFC9A84C).withOpacity(0.3)),
            ),
            child: Text(
              'OUR LEADERSHIP',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFC9A84C),
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context)!.ourLeadership,
            style: GoogleFonts.inter(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              'Dedicated professionals driving our mission to make quality education accessible worldwide.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: const Color(0xff6B7280),
                height: 1.65,
              ),
            ),
          ),
          const SizedBox(height: 56),
          if (_leadership.isEmpty)
            const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()))
          else ...[
            if (founder != null)
              FadeInSlide(
                delay: 0.1,
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: _buildFounderSpotlightCard(founder),
                  ),
                ),
              ),
            if (others.isNotEmpty) ...[
              const SizedBox(height: 40),
              Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: others
                    .map((member) => FadeInSlide(
                          child: _buildLeadershipCard(member),
                        ))
                    .toList(),
              ),
            ],
          ],
          const SizedBox(height: 48),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TeamPage()),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xff001E4E),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xff001E4E).withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Meet Our Full Team',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 18, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Premium spotlight card for the founder (about page)
  Widget _buildFounderSpotlightCard(StaffMember founder) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xff001024),
            Color(0xff001E4E),
            Color(0xff0D2D6B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff001E4E).withOpacity(0.40),
            blurRadius: 48,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFC9A84C).withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: 100,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0D9488).withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFFC9A84C), Color(0xFF0D9488)]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(36, 44, 36, 44),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 540;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFC9A84C),
                                  Color(0xFFE8C66A),
                                  Color(0xFF0D9488),
                                ],
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xff001E4E)),
                              child: StaffAvatar(staff: founder, size: 120),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC9A84C).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(
                                  color: const Color(0xFFC9A84C).withOpacity(0.5)),
                            ),
                            child: Text(
                              '✦  FOUNDER',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFC9A84C),
                                  letterSpacing: 2.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 40),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              founder.name,
                              style: GoogleFonts.inter(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.1,
                                  letterSpacing: -0.5),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              founder.role.toUpperCase(),
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFC9A84C),
                                  letterSpacing: 2.5),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              width: 52,
                              height: 2,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                    colors: [
                                  Color(0xFFC9A84C),
                                  Color(0xFF0D9488),
                                ]),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '"${founder.bio.length > 200 ? '${founder.bio.substring(0, 200)}…' : founder.bio}"',
                              style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: Colors.white.withOpacity(0.78),
                                  height: 1.75,
                                  fontStyle: FontStyle.italic),
                            ),
                            const SizedBox(height: 22),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                _founderChip(
                                    Icons.location_on_outlined, founder.city),
                                _founderChip(
                                    Icons.school_outlined,
                                    founder.education.length > 30
                                        ? '${founder.education.substring(0, 30)}…'
                                        : founder.education),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFC9A84C),
                              Color(0xFFE8C66A),
                              Color(0xFF0D9488),
                            ],
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xff001E4E)),
                          child: StaffAvatar(staff: founder, size: 100),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC9A84C).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                              color: const Color(0xFFC9A84C).withOpacity(0.5)),
                        ),
                        child: Text(
                          '✦  FOUNDER',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFC9A84C),
                              letterSpacing: 2.5),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        founder.name,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        founder.role.toUpperCase(),
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFC9A84C),
                            letterSpacing: 2),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '"${founder.bio.length > 140 ? '${founder.bio.substring(0, 140)}…' : founder.bio}"',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.78),
                            height: 1.7,
                            fontStyle: FontStyle.italic),
                      ),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _founderChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withOpacity(0.65)),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.inter(
                fontSize: 13, color: Colors.white.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  // Horizontal card for non-founder leadership members
  Widget _buildLeadershipCard(StaffMember member) {
    return Container(
      width: 340,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xffE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StaffAvatar(staff: member, size: 70),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  member.role.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFC9A84C),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 12, color: Color(0xff9CA3AF)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        member.city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xff6B7280)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.school_outlined,
                        size: 12, color: Color(0xff9CA3AF)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        member.education,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xff9CA3AF),
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Wrap(
        spacing: 48,
        runSpacing: 32,
        alignment: WrapAlignment.center,
        children: [
          _buildStat('5K+', 'Happy Students'),
          _buildStat('200+', 'Qualified Teachers'),
          _buildStat('50+', 'Countries Served'),
          _buildStat('98%', 'Satisfaction Rate'),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 48,
            fontWeight: FontWeight.w900,
            color: const Color(0xff3B82F6),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: const Color(0xff6B7280),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFooterQuote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(60),
      color: const Color(0xff111827),
      child: Column(
        children: [
          const Icon(Icons.format_quote_rounded, color: Colors.white24, size: 48),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.theBestOfPeopleAreThose,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.prophetMuhammadPbuh,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final String content;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xffE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
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
          const SizedBox(height: 16),
          Text(
            content,
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
}

