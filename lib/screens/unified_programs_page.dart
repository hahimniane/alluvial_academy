import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

import '../core/models/program_catalog.dart';
import '../core/services/pricing_quote_service.dart';
import '../core/services/public_site_cms_service.dart';
import '../shared/widgets/fade_in_slide.dart';
import '../widgets/modern_header.dart';
import 'program_selection_page.dart';

/// Fade transition into the catalog (used from landing + header).
class UnifiedProgramsPageRoutes {
  UnifiedProgramsPageRoutes._();

  static Route<void> fade({
    String? initialCategory,
    String? initialProgramId,
  }) {
    return PageRouteBuilder<void>(
      settings: const RouteSettings(name: '/unified-programs'),
      pageBuilder: (_, __, ___) => UnifiedProgramsPage(
        initialCategory: initialCategory,
        initialProgramId: initialProgramId,
      ),
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }
}

class UnifiedProgramsPage extends StatefulWidget {
  const UnifiedProgramsPage({
    super.key,
    this.initialCategory,
    this.initialProgramId,
  });

  final String? initialCategory;
  final String? initialProgramId;

  @override
  State<UnifiedProgramsPage> createState() => _UnifiedProgramsPageState();
}

class _UnifiedProgramsPageState extends State<UnifiedProgramsPage> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {
    for (final id in ProgramCatalog.categoryIds) id: GlobalKey(),
  };

  String? _activeCategoryId;
  /// Stores the selected **category** id (the program), not an individual item.
  String? _selectedCategoryId;
  int _hoursPerWeek = 2;
  Map<String, Map<String, dynamic>> _cmsOverrides = {};
  Timer? _scrollDebounce;
  bool _showScrollTop = false;
  final Set<String> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    _activeCategoryId = ProgramCatalog.categoryIds.first;
    _loadCmsOverrides();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      void applyDeepLink() {
        if (!mounted) return;
        String? targetCat;
        if (widget.initialProgramId != null) {
          targetCat =
              ProgramCatalog.categoryIdForProgram(widget.initialProgramId!) ??
                  widget.initialCategory;
        } else if (widget.initialCategory != null &&
            ProgramCatalog.categoryIds.contains(widget.initialCategory)) {
          targetCat = widget.initialCategory;
        }
        if (targetCat != null) {
          setState(() {
            _activeCategoryId = targetCat;
            _selectedCategoryId = targetCat;
            _expandedCategories.add(targetCat!);
          });
          _scrollToCategory(targetCat);
        }
      }

      applyDeepLink();
      WidgetsBinding.instance.addPostFrameCallback((_) => applyDeepLink());
    });
  }

  void _onScroll() {
    final show = _scrollController.hasClients && _scrollController.offset > 220;
    if (show != _showScrollTop) setState(() => _showScrollTop = show);
    _onScrollDebounced();
  }

  Future<void> _loadCmsOverrides() async {
    final map = await PublicSiteCmsService.getPlanOverridesForQuotes();
    if (mounted) setState(() => _cmsOverrides = map);
  }

  void _onScrollDebounced() {
    _scrollDebounce?.cancel();
    _scrollDebounce =
        Timer(const Duration(milliseconds: 120), _updateActiveCategory);
  }

  void _updateActiveCategory() {
    if (!mounted) return;
    final media = MediaQuery.of(context);
    final anchor = media.padding.top + kToolbarHeight + 100;

    String? bestId;
    double bestTop = -double.infinity;

    for (final id in ProgramCatalog.categoryIds) {
      final box =
          _sectionKeys[id]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top <= anchor && top > bestTop) {
        bestTop = top;
        bestId = id;
      }
    }

    bestId ??= ProgramCatalog.categoryIds.first;
    if (bestId != _activeCategoryId) {
      setState(() => _activeCategoryId = bestId);
    }
  }

  void _scrollToCategory(String categoryId) {
    final key = _sectionKeys[categoryId];
    final c = key?.currentContext;
    if (c == null) return;
    // Align the scroll target so it lands right below the sticky header
    // (status bar + toolbar + category pills area), mirroring the anchor used
    // by `_updateActiveCategory`. Without this the section title would get
    // hidden behind the header when deep-linked from the landing page.
    final media = MediaQuery.of(context);
    final viewportHeight = media.size.height;
    final anchor = media.padding.top + kToolbarHeight + 100;
    final alignment = viewportHeight > 0
        ? (anchor / viewportHeight).clamp(0.0, 0.4)
        : 0.08;
    Scrollable.ensureVisible(
      c,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      alignment: alignment,
    );
  }

  @override
  void dispose() {
    _scrollDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final categories = ProgramCatalog.categories(loc);
    final screenW = MediaQuery.sizeOf(context).width;
    /// Cap content width on laptop/desktop so cards and hero do not stretch edge-to-edge.
    final catalogMaxWidth =
        screenW > 720 ? (screenW - 48).clamp(320.0, 780.0) : screenW;

    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: Column(
        children: [
          const ModernHeader(),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: (_) {
                    _onScrollDebounced();
                    return false;
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: catalogMaxWidth),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            visualDensity: screenW > 720
                                ? VisualDensity.compact
                                : VisualDensity.standard,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHero(loc),
                              _buildCategoryPills(loc, categories),
                              const SizedBox(height: 12),
                              for (var i = 0; i < categories.length; i++) ...[
                                if (i > 0) _buildSectionDivider(),
                                _buildCategoryAccordion(loc, categories[i], i),
                              ],
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Scroll-to-top FAB
                Positioned(
                  right: 20,
                  bottom: 24,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: _showScrollTop ? 1 : 0,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 220),
                      offset:
                          _showScrollTop ? Offset.zero : const Offset(0, 0.5),
                      child: IgnorePointer(
                        ignoring: !_showScrollTop,
                        child: Material(
                          elevation: 6,
                          shadowColor: Colors.black26,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          color: Colors.white,
                          child: IconButton(
                            tooltip: loc.unifiedProgramsScrollToTop,
                            onPressed: () {
                              _scrollController.animateTo(
                                0,
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOutCubic,
                              );
                            },
                            icon: const Icon(Icons.arrow_upward_rounded,
                                color: Color(0xff1E40AF)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Divider ─────────────────────────────────────────────────────────────

  Widget _buildSectionDivider() {
    final tight = MediaQuery.sizeOf(context).width > 720;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tight ? 12 : 24,
        vertical: tight ? 6 : 8,
      ),
      child: Container(
        height: 1,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [
            Color(0x00CBD5E1),
            Color(0xffCBD5E1),
            Color(0x00CBD5E1),
          ]),
        ),
      ),
    );
  }

  // ── Hero ────────────────────────────────────────────────────────────────

  Widget _buildHero(AppLocalizations loc) {
    final w = MediaQuery.sizeOf(context).width;
    final tight = w > 720;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        tight ? 20 : 24,
        tight ? 26 : 36,
        tight ? 20 : 24,
        tight ? 22 : 28,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xffF0F9FF), Color(0xffE0F2FE), Color(0xffDBEAFE)],
        ),
      ),
      child: Column(
        children: [
          FadeInSlide(
            delay: 0.1,
            duration: const Duration(milliseconds: 520),
            beginOffset: const Offset(0, 0.12),
            child: Text(
              loc.unifiedProgramsTitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: w > 720 ? 32 : (w > 600 ? 38 : 28),
                fontWeight: FontWeight.w900,
                color: const Color(0xff111827),
                height: 1.12,
                letterSpacing: -0.5,
              ),
            ),
          ),
          SizedBox(height: tight ? 10 : 14),
          FadeInSlide(
            delay: 0.2,
            duration: const Duration(milliseconds: 520),
            beginOffset: const Offset(0, 0.1),
            child: Text(
              loc.unifiedProgramsSubtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: tight ? 14.5 : 16,
                color: const Color(0xff64748B),
                height: tight ? 1.45 : 1.55,
              ),
            ),
          ),
          SizedBox(height: tight ? 16 : 20),
          FadeInSlide(
            delay: 0.3,
            duration: const Duration(milliseconds: 520),
            beginOffset: const Offset(0, 0.1),
            child: SizedBox(
              width: w <= 600 ? double.infinity : null,
              child: ElevatedButton.icon(
                onPressed: () =>
                    _scrollToCategory(ProgramCatalog.categoryIds.first),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                label: Text(
                  loc.unifiedProgramsBrowse,
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: tight ? 14 : 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff2563EB),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: tight ? 22 : 28,
                    vertical: tight ? 12 : 14,
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
              ),
            ),
          ),
          SizedBox(height: tight ? 14 : 18),
          FadeInSlide(
            delay: 0.4,
            duration: const Duration(milliseconds: 520),
            beginOffset: const Offset(0, 0.08),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: tight ? 6 : 8,
              runSpacing: tight ? 6 : 8,
              children: [
                _buildTrustItem(
                    Icons.school_rounded, loc.unifiedProgramsTrust35),
                _buildTrustDot(),
                _buildTrustItem(
                    Icons.schedule_rounded, loc.unifiedProgramsTrustFlexible),
                _buildTrustDot(),
                _buildTrustItem(
                    Icons.people_rounded, loc.unifiedProgramsTrustExperts),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustItem(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xff94A3B8)),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xff64748B))),
        ],
      );

  Widget _buildTrustDot() => Text('\u00B7',
      style: GoogleFonts.inter(
          fontSize: 18,
          color: const Color(0xffCBD5E1),
          fontWeight: FontWeight.w700));

  // ── Category pills ──────────────────────────────────────────────────────

  Widget _buildCategoryPills(
      AppLocalizations loc, List<ProgramCategory> categories) {
    final tight = MediaQuery.sizeOf(context).width > 720;
    const bg = Color(0xffF8FAFC);
    return FadeInSlide(
      delay: 0.3,
      duration: const Duration(milliseconds: 480),
      beginOffset: const Offset(0, 0.08),
      child: ColoredBox(
        color: bg,
        child: SizedBox(
          height: tight ? 46 : 52,
          child: ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0x00F8FAFC),
                Color(0xffF8FAFC),
                Color(0xffF8FAFC),
                Color(0x00F8FAFC),
              ],
              stops: [0.0, 0.06, 0.94, 1.0],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: tight ? 14 : 20),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => SizedBox(width: tight ? 8 : 10),
              itemBuilder: (_, i) {
                final c = categories[i];
                return _CategoryPill(
                  category: c,
                  selected: c.id == _activeCategoryId,
                  onTap: () {
                    setState(() {
                      _activeCategoryId = c.id;
                      _expandedCategories.add(c.id);
                    });
                    _scrollToCategory(c.id);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── Accordion card per category ─────────────────────────────────────────

  Widget _buildCategoryAccordion(
      AppLocalizations loc, ProgramCategory cat, int sectionIndex) {
    final isExpanded = _expandedCategories.contains(cat.id);
    final isSelected = _selectedCategoryId == cat.id;

    return FadeInSlide(
      delay: 0.35 + sectionIndex * 0.04,
      duration: const Duration(milliseconds: 450),
      beginOffset: const Offset(0, 0.06),
      child: Padding(
        key: _sectionKeys[cat.id],
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width > 720 ? 10 : 16,
          vertical: MediaQuery.sizeOf(context).width > 720 ? 4 : 6,
        ),
        child: _ProgramCategoryCard(
          category: cat,
          loc: loc,
          expanded: isExpanded,
          selected: isSelected,
          enrollHoursPerWeek: _hoursPerWeek,
          enrollCmsOverrides: _cmsOverrides,
          onEnrollHoursChanged: (h) =>
              setState(() => _hoursPerWeek = h.clamp(1, 8)),
          onEnrollClear: () => setState(() {
            if (_selectedCategoryId == cat.id) _selectedCategoryId = null;
            _expandedCategories.remove(cat.id);
          }),
          onExpandFromCollapsed: () {
            setState(() {
              _expandedCategories.add(cat.id);
              _selectedCategoryId = cat.id;
            });
          },
          onToggleExpand: () {
            setState(() {
              if (_expandedCategories.contains(cat.id)) {
                _expandedCategories.remove(cat.id);
              } else {
                _expandedCategories.add(cat.id);
              }
            });
          },
          onSelect: () {
            setState(() {
              _expandedCategories.add(cat.id);
              if (_selectedCategoryId == cat.id) {
                _selectedCategoryId = null;
              } else {
                _selectedCategoryId = cat.id;
              }
            });
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Category pill
// ═══════════════════════════════════════════════════════════════════════════════

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final ProgramCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tight = MediaQuery.sizeOf(context).width > 720;
    final c = category.color;
    return Semantics(
      button: true,
      selected: selected,
      label: category.title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: tight ? 12 : 14,
              vertical: tight ? 8 : 10,
            ),
            decoration: BoxDecoration(
              color: selected ? c : Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: selected ? c : const Color(0xffE2E8F0),
                width: selected ? 1.5 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color: c.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ]
                  : [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(category.icon,
                    size: 18, color: selected ? Colors.white : c),
                const SizedBox(width: 8),
                Text(category.title,
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: tight ? 12.5 : 13,
                        color: selected
                            ? Colors.white
                            : const Color(0xff334155))),
                const SizedBox(width: 4),
                Text('(${category.programs.length})',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: selected
                            ? Colors.white.withValues(alpha: 0.75)
                            : const Color(0xff94A3B8))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Category card — one per program, selectable as a whole
// ═══════════════════════════════════════════════════════════════════════════════

class _ProgramCategoryCard extends StatefulWidget {
  const _ProgramCategoryCard({
    required this.category,
    required this.loc,
    required this.expanded,
    required this.selected,
    required this.enrollHoursPerWeek,
    required this.enrollCmsOverrides,
    required this.onEnrollHoursChanged,
    required this.onEnrollClear,
    required this.onExpandFromCollapsed,
    required this.onToggleExpand,
    required this.onSelect,
  });

  final ProgramCategory category;
  final AppLocalizations loc;
  final bool expanded;
  final bool selected;
  final int enrollHoursPerWeek;
  final Map<String, Map<String, dynamic>> enrollCmsOverrides;
  final ValueChanged<int> onEnrollHoursChanged;
  final VoidCallback onEnrollClear;
  /// One tap on the whole collapsed card (strip + header + chevron) opens details + pricing.
  final VoidCallback onExpandFromCollapsed;
  final VoidCallback onToggleExpand;
  final VoidCallback onSelect;

  @override
  State<_ProgramCategoryCard> createState() => _ProgramCategoryCardState();
}

class _ProgramCategoryCardState extends State<_ProgramCategoryCard>
    with SingleTickerProviderStateMixin {
  bool _hover = false;
  late AnimationController _chevronCtrl;
  late Animation<double> _chevronTurns;

  @override
  void initState() {
    super.initState();
    _chevronCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: widget.expanded ? 1 : 0,
    );
    _chevronTurns =
        Tween<double>(begin: 0, end: 0.5).animate(CurvedAnimation(
      parent: _chevronCtrl,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void didUpdateWidget(covariant _ProgramCategoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != oldWidget.expanded) {
      widget.expanded ? _chevronCtrl.forward() : _chevronCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _chevronCtrl.dispose();
    super.dispose();
  }

  Widget _buildHeaderRow() {
    final tight = MediaQuery.sizeOf(context).width > 720;
    final cat = widget.category;
    final c = cat.color;
    final sel = widget.selected;
    final chevronBlock = Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.loc.unifiedCatSubjectCount(cat.programs.length),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: c,
              ),
            ),
          ),
          const SizedBox(height: 2),
          RotationTransition(
            turns: _chevronTurns,
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: widget.expanded ? c : const Color(0xffCBD5E1),
              size: 20,
            ),
          ),
        ],
      ),
    );

    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(tight ? 8 : 10),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(cat.emoji, style: TextStyle(fontSize: tight ? 20 : 24)),
        ),
        SizedBox(width: tight ? 10 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      cat.title,
                      style: GoogleFonts.inter(
                        fontSize: tight ? 15 : 17,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xff0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  if (sel) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.check_circle_rounded, color: c, size: 18),
                  ],
                ],
              ),
              SizedBox(height: tight ? 2 : 3),
              Text(
                cat.description,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: tight ? 11.5 : 12,
                  color: const Color(0xff64748B),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 2),
        if (widget.expanded)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onToggleExpand,
            child: chevronBlock,
          )
        else
          chevronBlock,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    final c = cat.color;
    final sel = widget.selected;
    final tight = MediaQuery.sizeOf(context).width > 720;
    final headerPad =
        EdgeInsets.fromLTRB(tight ? 12 : 16, tight ? 12 : 16, tight ? 8 : 10, tight ? 12 : 16);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: sel ? c.withValues(alpha: 0.03) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sel
                ? c
                : _hover
                    ? c.withValues(alpha: 0.3)
                    : const Color(0xffEEF2F7),
            width: sel ? 2 : 1,
          ),
          boxShadow: [
            if (sel)
              BoxShadow(
                  color: c.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 4))
            else
              BoxShadow(
                  color: _hover
                      ? c.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  blurRadius: _hover ? 18 : 10,
                  offset: const Offset(0, 4)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.expanded)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(19),
                  ),
                  onTap: widget.onExpandFromCollapsed,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(height: 4, color: c),
                      Padding(
                        padding: headerPad,
                        child: _buildHeaderRow(),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(height: 4, color: c),
                  Material(
                    color: Colors.transparent,
                      child: InkWell(
                      onTap: widget.onSelect,
                      child: Padding(
                        padding: headerPad,
                        child: _buildHeaderRow(),
                      ),
                    ),
                  ),
                ],
              ),
            // Expanded: feature list, then pricing/CTA at the end (no program tap required)
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: widget.expanded
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildFeatureList(cat, c),
                        Container(
                          height: 1,
                          margin: EdgeInsets.symmetric(horizontal: tight ? 10 : 12),
                          color: c.withValues(alpha: 0.25),
                        ),
                        ColoredBox(
                          color: c.withValues(alpha: 0.06),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              tight ? 10 : 12,
                              tight ? 8 : 10,
                              tight ? 10 : 12,
                              tight ? 10 : 12,
                            ),
                            child: _CategoryEnrollPanel(
                              loc: widget.loc,
                              category: cat,
                              hoursPerWeek: widget.enrollHoursPerWeek,
                              cmsOverrides: widget.enrollCmsOverrides,
                              onHoursChanged: widget.onEnrollHoursChanged,
                              onClear: widget.onEnrollClear,
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureList(ProgramCategory cat, Color c) {
    final tight = MediaQuery.sizeOf(context).width > 720;
    return Column(
      children: [
        Divider(
            height: 1,
            indent: tight ? 14 : 18,
            endIndent: tight ? 14 : 18),
        Padding(
          padding: EdgeInsets.fromLTRB(
            tight ? 10 : 12,
            tight ? 8 : 10,
            tight ? 10 : 12,
            tight ? 8 : 10,
          ),
          child: Column(
            children: [
              for (var i = 0; i < cat.programs.length; i++) ...[
                _FeatureRow(program: cat.programs[i], index: i),
                if (i < cat.programs.length - 1)
                  const Divider(
                      height: 1,
                      indent: 40,
                      endIndent: 8,
                      color: Color(0xffF1F5F9)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Feature row — informational only (not selectable)
// ═══════════════════════════════════════════════════════════════════════════════

class _FeatureRow extends StatefulWidget {
  const _FeatureRow({required this.program, required this.index});

  final ProgramItem program;
  final int index;

  @override
  State<_FeatureRow> createState() => _FeatureRowState();
}

class _FeatureRowState extends State<_FeatureRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _entrance;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic);
    Future.delayed(Duration(milliseconds: (widget.index * 35).clamp(0, 280)),
        () {
      if (mounted) _entrance.forward();
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.program;
    final c = p.accentColor;

    return FadeTransition(
      opacity: _fade,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emoji badge
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                  child: Text(p.emoji, style: const TextStyle(fontSize: 14))),
            ),
            const SizedBox(width: 10),
            // Title + age + description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          p.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xff1E293B),
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        p.ageGroupLabel,
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: c),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.description,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: const Color(0xff64748B),
                        height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Inline enroll panel (bottom of expanded category card; not an overlay)
// ═══════════════════════════════════════════════════════════════════════════════

class _CategoryEnrollPanel extends StatelessWidget {
  const _CategoryEnrollPanel({
    required this.loc,
    required this.category,
    required this.hoursPerWeek,
    required this.cmsOverrides,
    required this.onHoursChanged,
    required this.onClear,
  });

  final AppLocalizations loc;
  final ProgramCategory category;
  final int hoursPerWeek;
  final Map<String, Map<String, dynamic>> cmsOverrides;
  final ValueChanged<int> onHoursChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final snap = PricingQuoteService.buildSnapshotV2(
      trackId: category.trackId,
      hoursPerWeek: hoursPerWeek,
      cmsOverrides: cmsOverrides,
    );
    final hourly = (snap?['hourlyRateUsd'] as num?)?.toDouble();
    final monthly = (snap?['monthlyEstimateUsd'] as num?)?.toDouble();
    final baseHourly = (snap?['baseHourlyRateUsd'] as num?)?.toDouble();
    final hasDiscount = snap?['discountApplied'] == true;
    final accent = category.color;

    final priceKey =
        '${hoursPerWeek}_${hourly?.toStringAsFixed(2)}_${monthly?.toStringAsFixed(0)}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.unifiedProgramsHoursPerWeek,
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: hoursPerWeek > 1
                            ? () => onHoursChanged(hoursPerWeek - 1)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                      ),
                      const SizedBox(width: 6),
                      Text('$hoursPerWeek',
                          style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 6),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: hoursPerWeek < 8
                            ? () => onHoursChanged(hoursPerWeek + 1)
                            : null,
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (hourly != null && monthly != null)
              Expanded(
                flex: 3,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOut,
                  child: Column(
                    key: ValueKey(priceKey),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (hasDiscount && baseHourly != null) ...[
                            Text(
                              '\$${baseHourly.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  decoration: TextDecoration.lineThrough,
                                  color: const Color(0xff94A3B8)),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            '\$${hourly.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xff0F172A)),
                          ),
                          const SizedBox(width: 4),
                          Text(loc.unifiedProgramsPerHour,
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: const Color(0xff94A3B8))),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        loc.unifiedProgramsPriceLine(
                          hoursPerWeek.toString(),
                          hourly.toStringAsFixed(2),
                          monthly.toStringAsFixed(0),
                        ),
                        style: GoogleFonts.inter(
                            fontSize: 11, color: const Color(0xff64748B)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: _onAccent(accent),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProgramSelectionPage(
                    initialSubject: category.enrollSubject,
                    initialTrackId: category.trackId,
                    initialPricingPlanSummary: category.title,
                    isLanguageSelection: category.isLanguageSelection,
                    initialHoursPerWeek: hoursPerWeek,
                  ),
                ),
              );
            },
            child: Text(loc.unifiedProgramsEnroll,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ),
      ],
    );
  }

  static Color _onAccent(Color bg) =>
      bg.computeLuminance() > 0.55 ? const Color(0xff0F172A) : Colors.white;
}
