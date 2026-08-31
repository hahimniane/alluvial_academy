import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../config/quiz_competition_divisions.dart';
import '../models/quiz_category.dart';
import '../models/quiz_competition.dart';
import '../services/quiz_competition_service.dart';
import 'quiz_play_screen.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

const quizCategoryGridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 164,
  mainAxisExtent: 128,
  mainAxisSpacing: 12,
  crossAxisSpacing: 12,
);

/// Main quiz hub screen showing all available categories
class QuizHomeScreen extends StatefulWidget {
  const QuizHomeScreen({super.key});

  @override
  State<QuizHomeScreen> createState() => _QuizHomeScreenState();
}

class _QuizHomeScreenState extends State<QuizHomeScreen> {
  final List<QuizCategory> _categories = QuizCategory.defaultCategories;
  final QuizCompetitionService _competitionService = QuizCompetitionService();
  late Future<QuizCompetitionSnapshot> _competitionFuture;
  bool _agePromptShown = false;

  @override
  void initState() {
    super.initState();
    _competitionFuture = _competitionService.loadLeaderboard();
  }

  void _refreshCompetition() {
    setState(() {
      _competitionFuture = _competitionService.loadLeaderboard();
    });
  }

  Future<void> _showAgeSetup() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    int? birthMonth;
    int? birthYear;
    String? validationMessage;
    final now = DateTime.now();
    final result = await showDialog<Map<String, int>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.quizCompetitionAgeSetupTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.quizCompetitionAgeSetupBody),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: birthMonth,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.quizCompetitionBirthMonth,
                    border: const OutlineInputBorder(),
                  ),
                  items: List.generate(12, (index) {
                    final month = index + 1;
                    return DropdownMenuItem(
                      value: month,
                      child: Text(
                        DateFormat.MMMM(locale).format(DateTime(2000, month)),
                      ),
                    );
                  }),
                  onChanged: (value) => setDialogState(() {
                    birthMonth = value;
                    validationMessage = null;
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: birthYear,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.quizCompetitionBirthYear,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (var year = now.year; year >= now.year - 121; year--)
                      DropdownMenuItem(value: year, child: Text('$year')),
                  ],
                  onChanged: (value) => setDialogState(() {
                    birthYear = value;
                    validationMessage = null;
                  }),
                ),
                if (validationMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    validationMessage!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.quizCompetitionAgeSetupLater),
            ),
            FilledButton(
              onPressed: () {
                if (birthMonth == null || birthYear == null) {
                  setDialogState(() {
                    validationMessage = l10n.quizCompetitionAgeSetupRequired;
                  });
                  return;
                }
                Navigator.pop(dialogContext, {
                  'birthMonth': birthMonth!,
                  'birthYear': birthYear!,
                });
              },
              child: Text(l10n.quizCompetitionAgeSetupSave),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    try {
      await _competitionService.setOwnAge(
        birthMonth: result['birthMonth']!,
        birthYear: result['birthYear']!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.quizCompetitionAgeSetupSaved)),
      );
      _refreshCompetition();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.quizReviewActionFailed(error.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: ScrollNotificationObserver(
        child: SelectionArea(
          child: SafeArea(
            child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: _buildHeader(l10n),
            ),

            SliverToBoxAdapter(
              child: _buildCompetitionCard(l10n),
            ),

            // Category Grid
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverGrid(
                gridDelegate: quizCategoryGridDelegate,
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildCategoryCard(_categories[index]),
                  childCount: _categories.length,
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

  Widget _buildCompetitionCard(AppLocalizations l10n) {
    return FutureBuilder<QuizCompetitionSnapshot>(
      future: _competitionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: LinearProgressIndicator(),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: OutlinedButton.icon(
              onPressed: _refreshCompetition,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.quizCompetitionRetry),
            ),
          );
        }

        final competition = snapshot.data!;
        if (competition.requiresDivision && !_agePromptShown) {
          _agePromptShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _showAgeSetup());
        }
        final self = competition.self;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF312E81), Color(0xFF7C3AED)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: Color(0xFFFDE68A), size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.quizCompetitionStudentTitle,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          l10n.quizCompetitionMonth(competition.monthKey),
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          l10n.quizCompetitionCountingWindow(
                            competition.countingStartDate,
                            competition.countingEndDate,
                          ),
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!competition.requiresDivision) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.quizCompetitionLifetimeWins(competition.lifetimeWins),
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFDE68A),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                l10n.quizCompetitionDivision(
                  quizCompetitionDivisionLabel(l10n, competition.divisionId),
                ),
                style: GoogleFonts.inter(
                  color: const Color(0xFFFDE68A),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.quizCompetitionFairRules(
                  competition.minimumQuestions,
                  competition.minimumActiveDays,
                  (competition.minimumAccuracy * 100).round(),
                  competition.minimumEligibleParticipants,
                ),
                style: GoogleFonts.inter(color: Colors.white, height: 1.4),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.quizCompetitionCategoryProgress(
                  self?.categoriesAttemptedCount ?? 0,
                  competition.requiredCategoryCount,
                ),
                style: GoogleFonts.inter(
                  color: const Color(0xFFFDE68A),
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              if (competition.requiresDivision) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.quizCompetitionDivisionNeeded,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFDE68A),
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _competitionStat(
                      l10n.quizCompetitionQuestions,
                      '${self?.answeredCount ?? 0}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _competitionStat(
                      l10n.quizCompetitionActiveDays,
                      '${self?.activeDays ?? 0}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _competitionStat(
                      l10n.quizCompetitionRank,
                      self == null || competition.requiresDivision
                          ? '—'
                          : '#${self.rank}',
                    ),
                  ),
                ],
              ),
              if (!competition.requiresDivision &&
                  self != null &&
                  (competition.nearbyAbove != null ||
                      competition.nearbyBelow != null)) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.quizCompetitionNearbyRanks,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (competition.nearbyAbove != null)
                  Text(
                    l10n.quizCompetitionNearbyAhead(
                      competition.nearbyAbove!.rank,
                      competition.nearbyAbove!.displayName,
                    ),
                    style:
                        GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                  ),
                if (competition.nearbyBelow != null)
                  Text(
                    l10n.quizCompetitionNearbyBehind(
                      competition.nearbyBelow!.rank,
                      competition.nearbyBelow!.displayName,
                    ),
                    style:
                        GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                  ),
              ],
              if (competition.categoryInsights.isNotEmpty) ...[
                const SizedBox(height: 6),
                Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                    iconTheme: const IconThemeData(color: Colors.white),
                  ),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    title: Text(
                      l10n.quizCompetitionCategoryGuidance,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    children: competition.categoryInsights.map((insight) {
                      final category = _categories.where(
                        (item) => item.id == insight.categoryId,
                      );
                      final categoryName = category.isEmpty
                          ? insight.categoryId
                          : category.first.name;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                categoryName,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Text(
                              l10n.quizCompetitionCategoryInsight(
                                insight.correctCount,
                                insight.answeredCount,
                              ),
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _categoryGuidance(l10n, insight),
                              style: GoogleFonts.inter(
                                color: const Color(0xFFFDE68A),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
              if (competition.isFinalized) ...[
                const SizedBox(height: 12),
                Text(
                  competition.winners.isEmpty
                      ? l10n.quizCompetitionNoWinner
                      : competition.winners.length == 1
                          ? l10n.quizCompetitionWinner(
                              competition.winners.first.displayName)
                          : l10n.quizCompetitionCoWinners(competition.winners
                              .map((winner) => winner.displayName)
                              .join(', ')),
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFDE68A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _competitionStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }

  String _categoryGuidance(
    AppLocalizations l10n,
    QuizCompetitionCategoryInsight insight,
  ) {
    if (insight.answeredCount == 0) {
      return l10n.quizCompetitionCategoryStart;
    }
    if (insight.accuracy < 0.5) {
      return l10n.quizCompetitionCategoryPractice;
    }
    return l10n.quizCompetitionCategoryStrong;
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.quiz_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Islamic Quiz',
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Test your knowledge!',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Stats Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.stars_rounded, color: Colors.white, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose a Category',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.quizCategoryCount(_categories.length, 350),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.9),
                        ),
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

  Widget _buildCategoryCard(QuizCategory category) {
    return GestureDetector(
      onTap: () => _openCategory(category),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: category.color.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon Container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: category.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                category.icon,
                size: 24,
                color: category.color,
              ),
            ),
            const SizedBox(height: 6),
            // Category Name
            Text(
              category.name,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            // Arabic Name
            Text(
              category.nameAr,
              style: GoogleFonts.amiri(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: category.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            // Play Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: category.color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 14),
                  const SizedBox(width: 2),
                  Text(
                    'Play',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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

  Future<void> _openCategory(QuizCategory category) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizPlayScreen(category: category),
      ),
    );
    if (mounted) _refreshCompetition();
  }
}
