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

  const CustomSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.isCollapsed,
    required this.onToggleCollapse,
    this.userRole,
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

  @override
  void initState() {
    super.initState();
    _loadSidebar();
  }

  @override
  void didUpdateWidget(CustomSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userRole != widget.userRole) {
      _loadSidebar();
    }
  }

  Future<void> _loadSidebar() async {
    setState(() => _isLoading = true);
    final sections = await _sidebarService.loadSidebar(widget.userRole);
    if (mounted) {
      setState(() {
        _sections = sections;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveState() async {
    await _sidebarService.saveSidebarState(_sections);
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

          // Reorderable List - Constrained to prevent overflow
          Expanded(
            child: ReorderableListView(
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
              children: _sections.map((section) {
                return _buildSection(section);
              }).toList(),
            ),
          ),

          // Reset Button
          _buildFooter(),
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

  Widget _buildSection(SidebarSection section) {
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

          // Items - Animated expansion with constraints
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: section.isExpanded
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 0,
                        maxWidth: 220,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: section.items.map((item) => _buildItem(item)).toList(),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(SidebarItem item) {
    final isSelected = widget.selectedIndex == item.screenIndex;
    final itemColor = item.colorValue != null
        ? Color(item.colorValue!)
        : const Color(0xFF6B7280);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          widget.onItemSelected(item.screenIndex);
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: const Color(0xFF0386FF).withOpacity(0.2), width: 1)
                : null,
          ),
          child: Row(
            children: [
              // Icon with background
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
                  color: isSelected ? const Color(0xFF0386FF) : itemColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  SidebarLocalization.translate(context, item.label),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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
            ...section.items.map((item) => _buildCollapsedIcon(item)).toList(),
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
                  : Container(
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
            ),
          ),
        ),
      ),
    );
  }
}
