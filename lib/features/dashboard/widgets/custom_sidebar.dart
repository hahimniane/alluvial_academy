import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/sidebar_model.dart';
import '../services/sidebar_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import '../utils/sidebar_localization.dart';

class CustomSidebar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final String? userRole;
  final Set<int> badgeScreenIndices;
  final Set<String> hiddenSectionIds;

  const CustomSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.isCollapsed,
    required this.onToggleCollapse,
    this.userRole,
    this.badgeScreenIndices = const {},
    this.hiddenSectionIds = const {},
  });

  @override
  State<CustomSidebar> createState() => _CustomSidebarState();
}

class _CustomSidebarState extends State<CustomSidebar> {
  final SidebarService _sidebarService = SidebarService();
  List<SidebarSection> _sections = [];
  bool _isLoading = true;
  bool _isHovered = false;
  bool _isAnimating = false;
  bool _isEditLayout = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Set<String> _favoriteItemIds = <String>{};
  // Tracks which sections were explicitly expanded by the user.
  // Auto-collapse will not collapse these sections.
  Set<String> _manualExpandedSectionIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadSidebar();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CustomSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userRole != widget.userRole ||
        oldWidget.hiddenSectionIds != widget.hiddenSectionIds) {
      _loadSidebar();
      return;
    }

    if (oldWidget.selectedIndex != widget.selectedIndex &&
        !_isLoading &&
        !widget.isCollapsed) {
      _applyAutoCollapseForSelectedIndex(widget.selectedIndex);
    }
  }

  void _applyAutoCollapseForSelectedIndex(int selectedScreenIndex) {
    String? targetSectionId;
    for (final section in _sections) {
      final isInThisSection = section.items
          .any((item) => item.screenIndex == selectedScreenIndex);
      if (isInThisSection) {
        targetSectionId = section.id;
        break;
      }
    }

    if (targetSectionId == null) return;

    setState(() {
      for (final section in _sections) {
        if (section.id == targetSectionId) {
          section.isExpanded = true;
        } else if (_manualExpandedSectionIds.contains(section.id)) {
          section.isExpanded = true;
        } else {
          section.isExpanded = false;
        }
      }
    });
  }

  Future<void> _loadSidebar() async {
    setState(() => _isLoading = true);
    var sections = await _sidebarService.loadSidebar(widget.userRole);
    if (widget.hiddenSectionIds.isNotEmpty) {
      sections = sections
          .where((s) => !widget.hiddenSectionIds.contains(s.id))
          .toList();
    }
    final favoriteIds = await _sidebarService.loadFavoritedItemIds();
    if (mounted) {
      setState(() {
        _sections = sections;
        _favoriteItemIds = Set<String>.from(favoriteIds);
        _manualExpandedSectionIds =
            sections.where((s) => s.isExpanded).map((s) => s.id).toSet();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveState() async {
    await _sidebarService.saveSidebarState(
      _sections,
      favoritedItemIds: _favoriteItemIds,
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final SidebarSection item = _sections.removeAt(oldIndex);
      _sections.insert(newIndex, item);
    });
    _saveState();
  }

  void _toggleSection(SidebarSection section) {
    setState(() {
      section.isExpanded = !section.isExpanded;
      if (section.isExpanded) {
        _manualExpandedSectionIds.add(section.id);
      } else {
        _manualExpandedSectionIds.remove(section.id);
      }
    });
    _saveState();
  }

  void _toggleFavoriteItem(String sidebarItemId) {
    setState(() {
      if (_favoriteItemIds.contains(sidebarItemId)) {
        _favoriteItemIds.remove(sidebarItemId);
      } else {
        _favoriteItemIds.add(sidebarItemId);
      }
    });
    _saveState();
  }

  @override
  Widget build(BuildContext context) {
    // If collapsed, show icon-only rail
    if (widget.isCollapsed) {
      return _buildCollapsedRail();
    }

    if (_isLoading) {
      return const SizedBox(
        width: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      width: 260,
      constraints: const BoxConstraints(
        maxWidth: 260,
        minWidth: 260,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          right: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header / Toggle
          _buildHeader(),

          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _buildSearchBar(),
            ),

          if (_favoriteItemIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              child: _buildFavoritesSection(),
            ),

          Expanded(
            child: _buildSectionsList(),
          ),

          // Reset Button
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildSectionsList() {
    final q = _searchQuery.trim().toLowerCase();

    // Search mode: filter items but keep section expansion logic wired to the real section objects.
    if (q.isNotEmpty) {
      final List<SidebarSection> filteredSections = [];
      final Map<String, List<SidebarItem>> filteredItemsBySectionId = {};

      for (final section in _sections) {
        final sectionTitle = SidebarLocalization.translate(context, section.title).toLowerCase();
        final bool titleMatches = sectionTitle.contains(q);

        final itemMatches = section.items.where((item) {
          final itemLabel = SidebarLocalization.translate(context, item.label).toLowerCase();
          return itemLabel.contains(q);
        }).toList();

        final bool sectionMatches = titleMatches || itemMatches.isNotEmpty;
        if (!sectionMatches) continue;

        filteredSections.add(section);
        // If the section title matches, show all items. Otherwise show only matched items.
        filteredItemsBySectionId[section.id] = titleMatches ? section.items : itemMatches;
      }

      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: filteredSections.length,
        shrinkWrap: false,
        itemBuilder: (context, index) {
          final section = filteredSections[index];
          final overrideItems = filteredItemsBySectionId[section.id];
          return _buildSection(section, itemsOverride: overrideItems);
        },
      );
    }

    // Normal mode: either reorderable (edit mode) or virtualized.
    if (_isEditLayout) {
      return ReorderableListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        shrinkWrap: false,
        onReorder: _onReorder,
        proxyDecorator: (child, index, animation) {
          return Material(
            elevation: 8,
            color: Colors.white,
            shadowColor: Colors.black.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            child: child,
          );
        },
        children: _sections.map((section) => _buildSection(section)).toList(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _sections.length,
      shrinkWrap: false,
      itemBuilder: (context, index) {
        return _buildSection(_sections[index]);
      },
    );
  }

  Widget _buildSearchBar() {
    return SizedBox(
      height: 36,
      child: TextField(
        onChanged: (v) {
          setState(() {
            _searchQuery = v;
          });
        },
        controller: _searchController,
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIcon: _searchQuery.trim().isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _searchController.clear();
                    });
                  },
                )
              : null,
          hintText: 'Search...',
          hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF9CA3AF)),
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(10),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFF0386FF), width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildFavoritesSection() {
    final favoriteItems = <SidebarItem>[];
    for (final section in _sections) {
      for (final item in section.items) {
        if (_favoriteItemIds.contains(item.id)) {
          favoriteItems.add(item);
        }
      }
    }

    if (favoriteItems.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star, size: 16, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Text(
                'Favorites',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6B7280),
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: favoriteItems.length,
              itemBuilder: (context, index) {
                return _buildItem(
                  favoriteItems[index],
                  isFavoriteSection: true,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            AppLocalizations.of(context)!.menu,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
              letterSpacing: -0.5,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _isEditLayout = !_isEditLayout;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      _isEditLayout ? Icons.drag_handle : Icons.edit,
                      color: const Color(0xFF6B7280),
                      size: 22,
                    ),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onToggleCollapse,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: const Icon(
                      Icons.chevron_left,
                      color: Color(0xFF6B7280),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: const Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final defaultSections =
                await _sidebarService.resetToDefault(widget.userRole);
            setState(() => _sections = defaultSections);
            setState(() => _favoriteItemIds = <String>{});
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.restore,
                  size: 16,
                  color: const Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)?.resetLayout ?? 'Reset Layout',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    SidebarSection section, {
    List<SidebarItem>? itemsOverride,
  }) {
    return Container(
      key: ValueKey(section.id),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Section Header with improved design
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _toggleSection(section),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    // Section icon (3x3 grid)
                    Container(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.grid_view,
                        size: 16,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Title
                    Expanded(
                      child: Text(
                        SidebarLocalization.translate(context, section.title).toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF9CA3AF),
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),

                    // Expand/Collapse Icon
                    AnimatedRotation(
                      turns: section.isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: Icon(
                        Icons.keyboard_arrow_up,
                        size: 18,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Items - Animated expansion with constraints.
          // When itemsOverride is set (search mode), always show items
          // regardless of collapse state so search results are visible.
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: (section.isExpanded || itemsOverride != null)
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 0,
                        maxWidth: 220,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: (itemsOverride ?? section.items)
                            .map((item) => _buildItem(item))
                            .toList(),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(
    SidebarItem item, {
    bool isFavoriteSection = false,
  }) {
    final isSelected = widget.selectedIndex == item.screenIndex;
    final isFavorited = _favoriteItemIds.contains(item.id);
    final itemColor = item.colorValue != null
        ? Color(item.colorValue!)
        : const Color(0xFF6B7280);

    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: isFavoriteSection
            ? const EdgeInsets.symmetric(vertical: 2)
            : const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(
                  color: const Color(0xFF0386FF).withOpacity(0.2), width: 1)
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  widget.onItemSelected(item.screenIndex);
                },
                borderRadius: BorderRadius.circular(10),
                child: Row(
                  children: [
                    // Icon with background + optional badge dot
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF0386FF).withOpacity(0.1)
                                : itemColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            item.icon,
                            size: 18,
                            color: isSelected
                                ? const Color(0xFF0386FF)
                                : itemColor,
                          ),
                        ),
                        if (widget.badgeScreenIndices.contains(item.screenIndex))
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        SidebarLocalization.translate(context, item.label),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? const Color(0xFF0386FF)
                              : const Color(0xFF374151),
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    // Visual indicator (double-line icon)
                    if (isSelected)
                      Icon(
                        Icons.more_horiz,
                        size: 16,
                        color: const Color(0xFF0386FF).withOpacity(0.5),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 28,
                minHeight: 28,
              ),
              tooltip: isFavorited ? 'Unpin' : 'Pin',
              icon: Icon(
                isFavorited ? Icons.star : Icons.star_border,
                size: 18,
                color: isFavorited
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF9CA3AF),
              ),
              onPressed: () => _toggleFavoriteItem(item.id),
            ),
          ],
        ),
      ),
    );
  }

  // Icon-only collapsed rail - shows sections organized, not flattened
  Widget _buildCollapsedRail() {
    if (_isLoading) {
      return const SizedBox(
        width: 72,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return MouseRegion(
      onEnter: (_) {
        if (mounted && !_isAnimating) {
          _isAnimating = true;
          setState(() => _isHovered = true);
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              _isAnimating = false;
            }
          });
        }
      },
      onExit: (_) {
        if (mounted && !_isAnimating) {
          _isAnimating = true;
          setState(() => _isHovered = false);
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              _isAnimating = false;
            }
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOutCubic,
        constraints: BoxConstraints(
          minWidth: 72,
          maxWidth: _isHovered ? 200 : 72,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            right: BorderSide(color: Color(0xFFE5E7EB), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(2, 0),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Expand button at top
            Container(
              margin: const EdgeInsets.all(8),
              child: Material(
                color: const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(10),
                elevation: 2,
                child: InkWell(
                  onTap: widget.onToggleCollapse,
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                      horizontal: _isHovered ? 12 : 8,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isHovered ? Icons.chevron_left : Icons.chevron_right,
                          color: Colors.white,
                          size: 18,
                        ),
                        if (_isHovered) ...[
                          const SizedBox(width: 6),
                          Text(
                            AppLocalizations.of(context)?.expand ?? 'Expand',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Sections organized, not flattened
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                shrinkWrap: false,
                children: _sections.map((section) => _buildCollapsedSection(section)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedSection(SidebarSection section) {
    return Container(
      key: ValueKey('collapsed_${section.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Section header (icon only when collapsed, or title when hovered)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _toggleSection(section),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.grid_view,
                      size: 16,
                      color: const Color(0xFF9CA3AF),
                    ),
                    if (_isHovered) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          section.title.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF9CA3AF),
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      AnimatedRotation(
                        turns: section.isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_up,
                          size: 14,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // Section items (only if expanded)
          if (section.isExpanded && _isHovered)
            ...section.items.map((item) => _buildCollapsedIcon(item)),
        ],
      ),
    );
  }

  Widget _buildCollapsedIcon(SidebarItem item) {
    final isSelected = widget.selectedIndex == item.screenIndex;

    return Tooltip(
      message: SidebarLocalization.translate(context, item.label),
      waitDuration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              widget.onItemSelected(item.screenIndex);
            },
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              constraints: BoxConstraints(
                minWidth: 56,
                maxWidth: _isHovered ? double.infinity : 56,
                minHeight: 52,
                maxHeight: 52,
              ),
              padding: _isHovered
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 0)
                  : EdgeInsets.zero,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFEFF6FF)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(color: const Color(0xFF0386FF), width: 2)
                    : Border.all(color: const Color(0xFFE5E7EB), width: 1),
              ),
              child: _isHovered
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF0386FF).withOpacity(0.1)
                                : const Color(0xFF6B7280).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            item.icon,
                            color: isSelected 
                                ? const Color(0xFF0386FF) 
                                : const Color(0xFF6B7280),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            SidebarLocalization.translate(context, item.label),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: isSelected
                                  ? const Color(0xFF0386FF)
                                  : const Color(0xFF374151),
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    )
                  : Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF0386FF).withOpacity(0.1)
                                : const Color(0xFF6B7280).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            item.icon,
                            color: isSelected
                                ? const Color(0xFF0386FF)
                                : const Color(0xFF6B7280),
                            size: 22,
                          ),
                        ),
                        if (widget.badgeScreenIndices.contains(item.screenIndex))
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
