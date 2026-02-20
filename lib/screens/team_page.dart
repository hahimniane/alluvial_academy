import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import '../widgets/modern_header.dart';
import '../shared/widgets/fade_in_slide.dart';
import 'teacher_application_screen.dart';
import 'contact_page.dart';

// ──────────────────────────────────────────────────────────────────────────────
// BRAND COLORS
// ──────────────────────────────────────────────────────────────────────────────
const Color _kGold = Color(0xFFC9A84C);
const Color _kTeal = Color(0xFF0D9488);
const Color _kNavy = Color(0xff001E4E);
const Color _kTextPrimary = Color(0xff111827);
const Color _kTextSecondary = Color(0xff6B7280);
const Color _kBgLight = Color(0xffF8FAFC);

// ──────────────────────────────────────────────────────────────────────────────
// CATEGORY THEME
// ──────────────────────────────────────────────────────────────────────────────
class _CatTheme {
  final Color accent;
  final Color accentLight;
  final IconData icon;
  final String label;
  final String tagline;
  final String description;
  const _CatTheme({
    required this.accent,
    required this.accentLight,
    required this.icon,
    required this.label,
    required this.tagline,
    required this.description,
  });
}

_CatTheme _getCatTheme(BuildContext context, String key) {
  final l = AppLocalizations.of(context)!;
  switch (key) {
    case 'leadership':
      return _CatTheme(
        accent: const Color(0xFFC9A84C),
        accentLight: const Color(0xFFFBF4E3),
        icon: Icons.star_rounded,
        label: l.teamLeadership,
        tagline: l.teamLeadershipTagline,
        description: l.teamLeadershipDescription,
      );
    case 'teacher':
      return _CatTheme(
        accent: const Color(0xFF6366F1),
        accentLight: const Color(0xFFEEEEFD),
        icon: Icons.auto_stories_rounded,
        label: l.teamTeachers,
        tagline: l.teamTeachersTagline,
        description: l.teamTeachersDescription,
      );
    case 'all':
    default:
      return _CatTheme(
        accent: _kNavy,
        accentLight: const Color(0xffE8EEF7),
        icon: Icons.groups_rounded,
        label: l.teamAllTeam,
        tagline: l.teamAllTeamTagline,
        description: l.teamAllTeamDescription,
      );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// GRADIENT PALETTE FOR INITIALS AVATARS
// ──────────────────────────────────────────────────────────────────────────────
const List<List<Color>> kAvatarGradients = [
  [Color(0xFF667eea), Color(0xFF764ba2)],
  [Color(0xFFf093fb), Color(0xFFf5576c)],
  [Color(0xFF4facfe), Color(0xFF00f2fe)],
  [Color(0xFF43e97b), Color(0xFF38f9d7)],
  [Color(0xFFfa709a), Color(0xFFfee140)],
  [Color(0xFFa18cd1), Color(0xFFfbc2eb)],
];

// ──────────────────────────────────────────────────────────────────────────────
// MODEL
// ──────────────────────────────────────────────────────────────────────────────
class StaffMember {
  final String id;
  final String name;
  final String role;
  final String city;
  final String education;
  final String bio;
  final List<String> languages;
  final String whyAlluwal;
  final String? photoAsset;
  final String category;
  final int sortOrder;

  const StaffMember({
    required this.id,
    required this.name,
    required this.role,
    required this.city,
    required this.education,
    required this.bio,
    required this.languages,
    required this.whyAlluwal,
    this.photoAsset,
    required this.category,
    required this.sortOrder,
  });

  factory StaffMember.fromJson(Map<String, dynamic> json) => StaffMember(
        id: json['id'] as String,
        name: json['name'] as String,
        role: json['role'] as String,
        city: json['city'] as String,
        education: json['education'] as String,
        bio: json['bio'] as String,
        languages: List<String>.from(json['languages'] as List),
        whyAlluwal: json['whyAlluwal'] as String,
        photoAsset: json['photoAsset'] as String?,
        category: json['category'] as String,
        sortOrder: json['sortOrder'] as int,
      );

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  /// Short snippet shown on the card.
  String get cardSnippet {
    final src = bio.isNotEmpty ? bio : whyAlluwal;
    if (src.length > 90) return '${src.substring(0, 90)}…';
    if (src.isNotEmpty) return src;
    return 'Spreading knowledge and light through Alluwal Education Hub.';
  }

  /// Full bio with fallback.
  String get fullBio {
    if (bio.isNotEmpty) return bio;
    return 'A dedicated member of the Alluwal team, committed to delivering quality '
        'Islamic and academic education to learners across the globe.';
  }

  /// Why Alluwal with fallback.
  String get fullWhyAlluwal {
    if (whyAlluwal.isNotEmpty) return whyAlluwal;
    return 'I believe in Alluwal\'s mission to make education accessible, empowering '
        'every student to grow spiritually and academically — wherever they are.';
  }
}

/// Helper to load all staff from the bundled JSON.
Future<List<StaffMember>> loadStaffData() async {
  final jsonString = await rootBundle.loadString('assets/data/staff.json');
  final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
  return jsonList
      .map((e) => StaffMember.fromJson(e as Map<String, dynamic>))
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
}

// ──────────────────────────────────────────────────────────────────────────────
// STAFF AVATAR WIDGET (public — reused by about_page)
// ──────────────────────────────────────────────────────────────────────────────
class StaffAvatar extends StatelessWidget {
  final StaffMember staff;
  final double size;

  const StaffAvatar({super.key, required this.staff, required this.size});

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'staff_avatar_${staff.id}',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _kGold, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: _kGold.withOpacity(0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: staff.photoAsset != null
              ? Image.asset(
                  staff.photoAsset!,
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  errorBuilder: (_, __, ___) => _buildInitialsAvatar(),
                )
              : _buildInitialsAvatar(),
        ),
      ),
    );
  }

  Widget _buildInitialsAvatar() {
    final idx = staff.name.codeUnits.fold<int>(0, (a, b) => a + b) % 6;
    final colors = kAvatarGradients[idx];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          staff.initials,
          style: GoogleFonts.inter(
            fontSize: size * 0.35,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// TEAM PAGE
// ──────────────────────────────────────────────────────────────────────────────
class TeamPage extends StatefulWidget {
  const TeamPage({super.key});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  List<StaffMember> _allStaff = [];
  String _selectedCategory = 'all';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final staff = await loadStaffData();
      if (mounted) {
        setState(() {
          _allStaff = staff;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<StaffMember> get _filteredStaff {
    if (_selectedCategory == 'all') return _allStaff;
    return _allStaff.where((s) => s.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const ModernHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        _buildHeroSection(),
                        _buildFilterBar(),
                        _buildCategoryContext(),
                        _buildStaffGrid(),
                        _buildJoinCTA(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── HERO SECTION ─────────────────────────────────────────────────────────
  Widget _buildHeroSection() {
    final teamPreview = _allStaff.take(12).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      decoration: const BoxDecoration(color: _kNavy),
      child: Column(
        children: [
          FadeInSlide(
            delay: 0.1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _kGold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: _kGold.withOpacity(0.3)),
              ),
              child: Text(
                AppLocalizations.of(context)!.teamOurGlobalTeam,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kGold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          FadeInSlide(
            delay: 0.2,
            child: Text(
              AppLocalizations.of(context)!.teamMeetThePeopleBehindAlluwal,
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
              constraints: const BoxConstraints(maxWidth: 700),
              child: Text(
                AppLocalizations.of(context)!.teamHeroSubtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  color: Colors.white.withOpacity(0.8),
                  height: 1.6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 36),
          FadeInSlide(
            delay: 0.4,
            child: _buildHeroTeamAvatars(teamPreview),
          ),
        ],
      ),
    );
  }

  /// Small group of avatars + "plus" circle for hero.
  Widget _buildHeroTeamAvatars(List<StaffMember> members) {
    if (members.isEmpty) return const SizedBox.shrink();
    const double size = 40.0;
    const int showCount = 5;
    final display = members.take(showCount).toList();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...display.map((member) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _heroSmallAvatar(member, size),
            )),
        const SizedBox(width: 6),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kGold.withOpacity(0.2),
            border: Border.all(color: _kGold, width: 1.5),
          ),
          child: Center(
            child: Text(
              '+',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _kGold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _heroSmallAvatar(StaffMember member, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _kNavy, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipOval(
        child: member.photoAsset != null
            ? Image.asset(
                member.photoAsset!,
                fit: BoxFit.cover,
                width: size,
                height: size,
                errorBuilder: (_, __, ___) => _heroInitialsAvatar(member, size),
              )
            : _heroInitialsAvatar(member, size),
      ),
    );
  }

  Widget _heroInitialsAvatar(StaffMember member, double size) {
    final idx = member.name.codeUnits.fold<int>(0, (a, b) => a + b) % 6;
    final colors = kAvatarGradients[idx];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          member.initials,
          style: GoogleFonts.inter(
            fontSize: size * 0.36,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ─── FILTER BAR ─────────────────────────────────────────────────────────
  Widget _buildFilterBar() {
    final cats = ['all', 'leadership', 'teacher'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 0),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: cats.map((key) {
              final theme = _getCatTheme(context, key);
              final isSelected = _selectedCategory == key;
              final count = key == 'all'
                  ? _allStaff.length
                  : _allStaff.where((s) => s.category == key).length;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedCategory = key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 230),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? theme.accent : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? theme.accent
                              : const Color(0xffE5E7EB),
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: theme.accent.withOpacity(0.25),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                )
                              ]
                            : [],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withOpacity(0.2)
                                  : theme.accentLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(theme.icon,
                                size: 15,
                                color: isSelected ? Colors.white : theme.accent),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                theme.label,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? Colors.white
                                      : _kTextPrimary,
                                ),
                              ),
                              Text(
                                theme.tagline,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: isSelected
                                      ? Colors.white.withOpacity(0.75)
                                      : _kTextSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withOpacity(0.22)
                                  : theme.accentLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$count',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? Colors.white
                                    : theme.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ─── CATEGORY CONTEXT STRIP ─────────────────────────────────────────────
  Widget _buildCategoryContext() {
    final theme = _getCatTheme(context, _selectedCategory);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(0, 0.08), end: Offset.zero)
              .animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey<String>(_selectedCategory),
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: theme.accentLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.accent.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(theme.icon, color: theme.accent, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    theme.label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    theme.description,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: _kTextSecondary,
                      height: 1.5,
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

  // ─── STAFF GRID ───────────────────────────────────────────────────────────
  Widget _buildStaffGrid() {
    final filtered = _filteredStaff;
    final showCategories = _selectedCategory == 'all';

    if (showCategories) {
      final groups = <String, List<StaffMember>>{};
      for (final member in filtered) {
        groups.putIfAbsent(member.category, () => []).add(member);
      }

      const categoryOrder = ['leadership', 'teacher'];

      // Extract founder (first sortOrder in leadership)
      final leadershipAll = groups['leadership'] ?? [];
      final StaffMember? founder =
          leadershipAll.isNotEmpty ? leadershipAll.first : null;
      final nonFounderLeadership =
          leadershipAll.length > 1 ? leadershipAll.sublist(1) : <StaffMember>[];
      final adjustedGroups = Map<String, List<StaffMember>>.from(groups);
      if (nonFounderLeadership.isNotEmpty) {
        adjustedGroups['leadership'] = nonFounderLeadership;
      } else {
        adjustedGroups.remove('leadership');
      }

      int globalIndex = founder != null ? 1 : 0;

      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1400),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (founder != null) _buildFounderSpotlight(founder),
              ...categoryOrder
                  .where((c) => adjustedGroups.containsKey(c))
                  .map((category) {
                final members = adjustedGroups[category]!;
                final startIdx = globalIndex;
                globalIndex += members.length;

                final theme = _getCatTheme(context, category);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 40, bottom: 20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.accentLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(theme.icon,
                                size: 16, color: theme.accent),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            theme.label,
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: _kTextPrimary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.accentLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${members.length}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: theme.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildResponsiveGrid(members, startIdx, category),
                  ],
                );
              }).toList(),
            ],
          ),
        ),
      );
    } else {
      if (_selectedCategory == 'leadership' && filtered.isNotEmpty) {
        final founder = filtered.first;
        final rest =
            filtered.length > 1 ? filtered.sublist(1) : <StaffMember>[];
        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1400),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFounderSpotlight(founder),
                if (rest.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  _buildResponsiveGrid(rest, 1, 'leadership'),
                ],
              ],
            ),
          ),
        );
      }
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1400),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: _buildResponsiveGrid(
              filtered, 0, _selectedCategory),
        ),
      );
    }
  }

  // ─── FOUNDER SPOTLIGHT ────────────────────────────────────────────────────
  Widget _buildFounderSpotlight(StaffMember founder) {
    return FadeInSlide(
      delay: 0.05,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _showStaffDetail(founder),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 48),
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
                  color: const Color(0xff001E4E).withOpacity(0.45),
                  blurRadius: 50,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Decorative orbs
                Positioned(
                  top: -50,
                  right: -50,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kGold.withOpacity(0.06),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -70,
                  right: 120,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kTeal.withOpacity(0.07),
                    ),
                  ),
                ),
                Positioned(
                  top: 20,
                  left: -30,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kTeal.withOpacity(0.04),
                    ),
                  ),
                ),
                // Gold accent top line
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [_kGold, _kTeal]),
                    ),
                  ),
                ),
                // Main content
                Padding(
                  padding: const EdgeInsets.fromLTRB(36, 44, 36, 44),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 560;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Avatar column
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        _kGold,
                                        Color(0xFFE8C66A),
                                        _kTeal,
                                      ],
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xff001E4E),
                                    ),
                                    child: StaffAvatar(
                                        staff: founder, size: 128),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: _kGold.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(50),
                                    border: Border.all(
                                        color: _kGold.withOpacity(0.5)),
                                  ),
                                  child: Text(
                                    AppLocalizations.of(context)!.teamFounderBadge,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: _kGold,
                                      letterSpacing: 2.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 44),
                            // Text column
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    founder.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 38,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      height: 1.1,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    founder.role.toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _kGold,
                                      letterSpacing: 2.5,
                                    ),
                                  ),
                                  const SizedBox(height: 22),
                                  Container(
                                    width: 56,
                                    height: 2,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                          colors: [_kGold, _kTeal]),
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                  const SizedBox(height: 22),
                                  Text(
                                    '"${founder.bio.length > 200 ? '${founder.bio.substring(0, 200)}…' : founder.bio}"',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      color: Colors.white.withOpacity(0.78),
                                      height: 1.75,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(height: 26),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 8,
                                    children: [
                                      _buildFounderChip(
                                          Icons.location_on_outlined,
                                          founder.city),
                                      _buildFounderChip(
                                          Icons.school_outlined,
                                          founder.education.length > 32
                                              ? '${founder.education.substring(0, 32)}…'
                                              : founder.education),
                                    ],
                                  ),
                                  const SizedBox(height: 28),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 26, vertical: 13),
                                    decoration: BoxDecoration(
                                      color: _kGold,
                                      borderRadius:
                                          BorderRadius.circular(50),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _kGold.withOpacity(0.4),
                                          blurRadius: 18,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          AppLocalizations.of(context)!.teamViewFullProfile,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xff001E4E),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 16,
                                            color: Color(0xff001E4E)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      } else {
                        // Mobile stacked
                        return Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                    colors: [
                                  _kGold,
                                  Color(0xFFE8C66A),
                                  _kTeal,
                                ]),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xff001E4E)),
                                child: StaffAvatar(
                                    staff: founder, size: 104),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: _kGold.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(50),
                                border:
                                    Border.all(color: _kGold.withOpacity(0.5)),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.teamFounderBadge,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _kGold,
                                  letterSpacing: 2.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              founder.name,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              founder.role.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _kGold,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '"${founder.bio.length > 150 ? '${founder.bio.substring(0, 150)}…' : founder.bio}"',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.78),
                                height: 1.7,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 22),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 26, vertical: 13),
                              decoration: BoxDecoration(
                                color: _kGold,
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.teamViewFullProfile,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xff001E4E),
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFounderChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
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
              fontSize: 13,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveGrid(
      List<StaffMember> members, int startIndex, String category) {
    if (category == 'teacher') {
      return _buildTeacherRoster(members, startIndex);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        int cols;
        if (constraints.maxWidth >= 1200) {
          cols = 5;
        } else if (constraints.maxWidth >= 900) {
          cols = 4;
        } else if (constraints.maxWidth >= 600) {
          cols = 3;
        } else if (constraints.maxWidth >= 380) {
          cols = 2;
        } else {
          cols = 1;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.68,
          ),
          itemCount: members.length,
          itemBuilder: (context, index) {
            return FadeInSlide(
              delay: ((startIndex + index) * 0.06).clamp(0.0, 1.5),
              duration: const Duration(milliseconds: 500),
              beginOffset: const Offset(0, 0.12),
              curve: Curves.easeOutCubic,
              child: _StaffCard(
                staff: members[index],
                category: category,
                onTap: () => _showStaffDetail(members[index]),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTeacherRoster(List<StaffMember> members, int startIndex) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 700;
        if (isWide) {
          final rows = (members.length / 2).ceil();
          return Column(
            children: List.generate(rows, (row) {
              final left = row * 2;
              final right = row * 2 + 1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: FadeInSlide(
                        delay: ((startIndex + left) * 0.05).clamp(0.0, 1.2),
                        duration: const Duration(milliseconds: 460),
                        beginOffset: const Offset(0, 0.1),
                        curve: Curves.easeOutCubic,
                        child: _TeacherRosterCard(
                          staff: members[left],
                          onTap: () => _showStaffDetail(members[left]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (right < members.length)
                      Expanded(
                        child: FadeInSlide(
                          delay: ((startIndex + right) * 0.05).clamp(0.0, 1.2),
                          duration: const Duration(milliseconds: 460),
                          beginOffset: const Offset(0, 0.1),
                          curve: Curves.easeOutCubic,
                          child: _TeacherRosterCard(
                            staff: members[right],
                            onTap: () => _showStaffDetail(members[right]),
                          ),
                        ),
                      )
                    else
                      const Expanded(child: SizedBox.shrink()),
                  ],
                ),
              );
            }),
          );
        }
        return Column(
          children: List.generate(members.length, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FadeInSlide(
              delay: ((startIndex + i) * 0.05).clamp(0.0, 1.2),
              duration: const Duration(milliseconds: 460),
              beginOffset: const Offset(0, 0.1),
              curve: Curves.easeOutCubic,
              child: _TeacherRosterCard(
                staff: members[i],
                onTap: () => _showStaffDetail(members[i]),
              ),
            ),
          )),
        );
      },
    );
  }

  // ─── STAFF DETAIL BOTTOM SHEET ────────────────────────────────────────────
  void _showStaffDetail(StaffMember staff) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StaffDetailSheet(staff: staff),
    );
  }

  // ─── JOIN CTA ─────────────────────────────────────────────────────────────
  Widget _buildJoinCTA() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 48),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff3B82F6), Color(0xff1E40AF)],
        ),
      ),
      child: Column(
        children: [
          FadeInSlide(
            child: Text(
              AppLocalizations.of(context)!.teamWantToJoinOurTeam,
              style: GoogleFonts.inter(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Text(
              AppLocalizations.of(context)!.teamJoinSubtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TeacherApplicationScreen()),
                  );
                },
                icon: const Icon(Icons.person_add_rounded),
                label: Text(
                  AppLocalizations.of(context)!.applyToTeach,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xff3B82F6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ContactPage()),
                  );
                },
                icon: const Icon(Icons.mail_outline_rounded),
                label: Text(
                  AppLocalizations.of(context)!.contactUs,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// STAFF CARD — with bio snippet, category color accent, hover state
// ──────────────────────────────────────────────────────────────────────────────
class _StaffCard extends StatefulWidget {
  final StaffMember staff;
  final String category;
  final VoidCallback onTap;

  const _StaffCard(
      {required this.staff, required this.category, required this.onTap});

  @override
  State<_StaffCard> createState() => _StaffCardState();
}

class _StaffCardState extends State<_StaffCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _getCatTheme(context, widget.category);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: ScaleTransition(
          scale: _scaleAnim,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _hovered
                    ? theme.accent.withOpacity(0.35)
                    : Colors.transparent,
              ),
              boxShadow: [
                BoxShadow(
                  color: _hovered
                      ? theme.accent.withOpacity(0.13)
                      : Colors.black.withOpacity(0.06),
                  blurRadius: _hovered ? 26 : 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.accent,
                        theme.accent.withOpacity(0.45),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
                    child: Column(
                      children: [
                        StaffAvatar(staff: widget.staff, size: 66),
                        const SizedBox(height: 10),
                        Text(
                          widget.staff.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _kTextPrimary,
                              height: 1.2),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: theme.accentLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.staff.role.toUpperCase(),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: theme.accent,
                                letterSpacing: 0.6),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 11, color: _kTextSecondary),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                widget.staff.city,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: _kTextSecondary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: _hovered
                                  ? theme.accentLight
                                  : _kBgLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              (widget.staff.bio.isNotEmpty || widget.staff.whyAlluwal.isNotEmpty)
                                  ? widget.staff.cardSnippet
                                  : AppLocalizations.of(context)!.teamStaffFallbackSnippet,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  color: _kTextSecondary,
                                  height: 1.55),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 3,
                          runSpacing: 3,
                          alignment: WrapAlignment.center,
                          children: widget.staff.languages
                              .take(3)
                              .map((lang) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: const Color(0xffE5E7EB)),
                                    ),
                                    child: Text(
                                      lang,
                                      style: GoogleFonts.inter(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: _kTextSecondary),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 30,
                  color: _hovered
                      ? theme.accent.withOpacity(0.07)
                      : Colors.transparent,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.teamViewProfile,
                          style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: _hovered
                                  ? theme.accent
                                  : _kTextSecondary.withOpacity(0.4)),
                        ),
                        const SizedBox(width: 3),
                        Icon(Icons.arrow_forward_rounded,
                            size: 10,
                            color: _hovered
                                ? theme.accent
                                : _kTextSecondary.withOpacity(0.35)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// TEACHER ROSTER CARD — Horizontal card with global-educator identity
// ──────────────────────────────────────────────────────────────────────────────
class _TeacherRosterCard extends StatefulWidget {
  final StaffMember staff;
  final VoidCallback onTap;

  const _TeacherRosterCard({required this.staff, required this.onTap});

  @override
  State<_TeacherRosterCard> createState() => _TeacherRosterCardState();
}

class _TeacherRosterCardState extends State<_TeacherRosterCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF6366F1);
    const accentLight = Color(0xFFEEEEFD);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFFF5F5FE) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _hovered ? accent.withOpacity(0.4) : const Color(0xFFE8E8F8),
              width: _hovered ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _hovered
                    ? accent.withOpacity(0.12)
                    : Colors.black.withOpacity(0.05),
                blurRadius: _hovered ? 22 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _hovered
                        ? [accent, accent.withOpacity(0.5)]
                        : [const Color(0xFFE8E8F8), const Color(0xFFDDDDF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: StaffAvatar(staff: widget.staff, size: 56),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.staff.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: _kTextPrimary,
                                    height: 1.2),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: accentLight,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  widget.staff.role,
                                  style: GoogleFonts.inter(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: accent,
                                      letterSpacing: 0.3),
                                ),
                              ),
                              if (widget.staff.id == 'aliou_diallo') ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.code_rounded,
                                        size: 9, color: accent.withOpacity(0.8)),
                                    const SizedBox(width: 4),
                                    Text(
                                      AppLocalizations.of(context)!.teamPartOfTeamBuildsPlatform,
                                      style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w500,
                                          color: _kTextSecondary,
                                          height: 1.2),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: _hovered ? accent : accentLight,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 11,
                            color: _hovered ? Colors.white : accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 11, color: accent.withOpacity(0.7)),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            widget.staff.city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 10.5,
                                color: _kTextSecondary,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (widget.staff.education.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: const Color(0xFF86EFAC), width: 0.8),
                              ),
                              child: Text(
                                widget.staff.education.split('—').first.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF16A34A)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (widget.staff.bio.isNotEmpty || widget.staff.whyAlluwal.isNotEmpty)
                          ? widget.staff.cardSnippet
                          : AppLocalizations.of(context)!.teamStaffFallbackSnippet,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: widget.staff.languages
                          .take(4)
                          .map((lang) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: _hovered
                                          ? accent.withOpacity(0.3)
                                          : const Color(0xFFE5E7EB)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.translate_rounded,
                                        size: 9,
                                        color: _hovered
                                            ? accent
                                            : _kTextSecondary),
                                    const SizedBox(width: 3),
                                    Text(
                                      lang,
                                      style: GoogleFonts.inter(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: _hovered
                                              ? accent
                                              : _kTextSecondary),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// DETAIL BOTTOM SHEET — Sequential animated reveal (7 sections)
// ──────────────────────────────────────────────────────────────────────────────
class _StaffDetailSheet extends StatefulWidget {
  final StaffMember staff;

  const _StaffDetailSheet({required this.staff});

  @override
  State<_StaffDetailSheet> createState() => _StaffDetailSheetState();
}

class _StaffDetailSheetState extends State<_StaffDetailSheet>
    with TickerProviderStateMixin {
  static const int _n = 7;
  static const List<int> _delays = [0, 70, 150, 220, 300, 380, 460];

  late final List<AnimationController> _cs;
  late final List<Animation<double>> _fades;
  late final List<Animation<Offset>> _slides;

  @override
  void initState() {
    super.initState();
    _cs = List.generate(
      _n,
      (i) => AnimationController(
          vsync: this, duration: const Duration(milliseconds: 380)),
    );
    _fades = _cs
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOut))
        .toList();
    _slides = _cs
        .map((c) => Tween<Offset>(begin: const Offset(0, 0.16), end: Offset.zero)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic)))
        .toList();
    _runSequence();
  }

  Future<void> _runSequence() async {
    for (int i = 0; i < _n; i++) {
      await Future.delayed(Duration(milliseconds: _delays[i]));
      if (mounted) _cs[i].forward();
    }
  }

  @override
  void dispose() {
    for (final c in _cs) c.dispose();
    super.dispose();
  }

  Widget _a(int i, Widget child) => FadeTransition(
        opacity: _fades[i],
        child: SlideTransition(position: _slides[i], child: child),
      );

  @override
  Widget build(BuildContext context) {
    final s = widget.staff;
    final theme = _getCatTheme(context, s.category);

    return DraggableScrollableSheet(
      initialChildSize: 0.96,
      minChildSize: 0.5,
      maxChildSize: 0.98,
      builder: (context, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: ctrl,
          padding: EdgeInsets.zero,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            _a(0, _buildHeader(s, theme)),
            const SizedBox(height: 12),
            _a(
                1,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Text(
                        s.name,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: _kTextPrimary,
                            height: 1.1),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: theme.accentLight,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(theme.icon, size: 13, color: theme.accent),
                            const SizedBox(width: 7),
                            Text(
                              s.role.toUpperCase(),
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: theme.accent,
                                  letterSpacing: 1.8),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 12),
            _a(
                2,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _chip(Icons.location_on_outlined, s.city),
                      _chip(Icons.school_outlined, s.education),
                    ],
                  ),
                )),
            const SizedBox(height: 14),
            _a(
                3,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                          child: Container(
                              height: 1, color: const Color(0xffF3F4F6))),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: theme.accentLight,
                            shape: BoxShape.circle),
                        child: Icon(Icons.auto_awesome_rounded,
                            size: 12, color: theme.accent),
                      ),
                      Expanded(
                          child: Container(
                              height: 1, color: const Color(0xffF3F4F6))),
                    ],
                  ),
                )),
            const SizedBox(height: 14),
            _a(
                4,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _section(
                    icon: Icons.person_outline_rounded,
                    title: AppLocalizations.of(context)!.teamAboutName(s.name.split(' ').first),
                    content: s.bio.isNotEmpty ? s.bio : AppLocalizations.of(context)!.teamStaffFallbackBio,
                    accent: theme.accent,
                    light: theme.accentLight,
                  ),
                )),
            const SizedBox(height: 12),
            _a(
                5,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _section(
                    icon: Icons.favorite_outline_rounded,
                    title: AppLocalizations.of(context)!.teamWhyAlluwal,
                    content: s.whyAlluwal.isNotEmpty ? s.whyAlluwal : AppLocalizations.of(context)!.teamStaffFallbackWhyAlluwal,
                    accent: _kTeal,
                    light: const Color(0xFFE6F6F5),
                    isQuote: true,
                  ),
                )),
            const SizedBox(height: 14),
            _a(
                6,
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.translate_rounded,
                              size: 15, color: _kTextSecondary),
                          const SizedBox(width: 6),
                          Text(
                            AppLocalizations.of(context)!.teamLanguages,
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _kTextPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: s.languages
                            .map((lang) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: theme.accentLight,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: theme.accent.withOpacity(0.2)),
                                  ),
                                    child: Text(
                                    lang,
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: theme.accent),
                                  ),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            final subj = Uri.encodeComponent(
                                AppLocalizations.of(context)!.teamMessageForName(s.name));
                            launchUrl(Uri.parse(
                                'mailto:support@alluwaleducationhub.org?subject=$subj'));
                          },
                          icon: const Icon(Icons.mail_outline_rounded),
                          label: Text(
                            AppLocalizations.of(context)!.teamContactName(s.name.split(' ').first),
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(StaffMember s, _CatTheme theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.accent.withOpacity(0.13),
            theme.accent.withOpacity(0.03),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: theme.accentLight,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: theme.accent.withOpacity(0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(theme.icon, size: 11, color: theme.accent),
                const SizedBox(width: 5),
                Text(
                  theme.label.toUpperCase(),
                  style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: theme.accent,
                      letterSpacing: 1.2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          StaffAvatar(staff: s, size: 86),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: _kBgLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xffE5E7EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: _kTextSecondary),
            const SizedBox(width: 6),
            Flexible(
                child: Text(text,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: _kTextSecondary))),
          ],
        ),
      );

  Widget _section({
    required IconData icon,
    required String title,
    required String content,
    required Color accent,
    required Color light,
    bool isQuote = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: light.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: light, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 12, color: accent),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kTextPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isQuote)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: Text(
                    '"',
                    style: GoogleFonts.inter(
                        fontSize: 28,
                        height: 0.75,
                        color: accent.withOpacity(0.28),
                        fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    content,
                    style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: _kTextSecondary,
                        height: 1.6,
                        fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            )
          else
            Text(
              content,
              style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: _kTextSecondary,
                  height: 1.6),
            ),
        ],
      ),
    );
  }
}
