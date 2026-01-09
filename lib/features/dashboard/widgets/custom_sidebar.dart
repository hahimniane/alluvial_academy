import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/sidebar_model.dart';
import '../services/sidebar_service.dart';

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
      width: 220,
      constraints: const BoxConstraints(
        maxWidth: 220,
        minWidth: 220,
      ),
      color: const Color(0xFFF9FAFB),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header / Toggle - Compact
          _buildHeader(),

          // Reorderable List - Constrained to prevent overflow
          Expanded(
            child: ReorderableListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              shrinkWrap: false,
              onReorder: _onReorder,
              proxyDecorator: (child, index, animation) {
                return Material(
                  elevation: 4,
                  color: Colors.white,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                  child: child,
                );
              },
              children: _sections.map((section) {
                return _buildSection(section);
              }).toList(),
            ),
          ),

          // Reset Button - Compact
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 48, // Reduced from 60 for compactness
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Reduced padding
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Menu',
            style: GoogleFonts.inter(
              fontSize: 14, // Reduced from 16
              fontWeight: FontWeight.w600,
              color: const Color(0xFF111827),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Color(0xFF6B7280), size: 20),
            onPressed: widget.onToggleCollapse,
            tooltip: 'Collapse Sidebar',
            padding: EdgeInsets.zero, // Remove default padding
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), // Reduced padding
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: TextButton.icon(
        onPressed: () async {
          final defaultSections =
              await _sidebarService.resetToDefault(widget.userRole);
          setState(() => _sections = defaultSections);
        },
        icon: const Icon(Icons.restore, size: 14, color: Color(0xFF9CA3AF)),
        label: Text(
          'Reset Layout',
          style: GoogleFonts.inter(
            fontSize: 11, // Reduced from 12
            color: const Color(0xFF9CA3AF),
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  Widget _buildSection(SidebarSection section) {
    return Container(
      key: ValueKey(section.id),
      margin: const EdgeInsets.only(bottom: 2), // Further reduced
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Section Header (Draggable handle + Toggle) - Compact
          InkWell(
            onTap: () => _toggleSection(section),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // Further reduced
              child: Row(
                children: [
                  // Drag Handle - Smaller
                  const Icon(Icons.drag_indicator,
                      size: 12, color: Color(0xFFD1D5DB)),
                  const SizedBox(width: 4),

                  // Title
                  Expanded(
                    child: Text(
                      section.title.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 9, // Further reduced
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF9CA3AF),
                        letterSpacing: 0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),

                  // Expand/Collapse Icon - Smaller
                  Icon(
                    section.isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 12,
                    color: const Color(0xFF9CA3AF),
                  ),
                ],
              ),
            ),
          ),

          // Items - Animated expansion with constraints
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: section.isExpanded
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 0,
                        maxWidth: 220, // Match sidebar width
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
        : const Color(0xFF4B5563);

    return InkWell(
      onTap: () {
        widget.onItemSelected(item.screenIndex);
        // Auto-collapse after selection (only if expanded)
        if (!widget.isCollapsed) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              widget.onToggleCollapse();
            }
          });
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1), // Reduced margins
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), // Reduced padding
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(6), // Smaller radius
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 18, // Reduced from 20
              color: isSelected ? const Color(0xFF0386FF) : itemColor,
            ),
            const SizedBox(width: 10), // Reduced from 12
            Expanded(
              child: Text(
                item.label,
                style: GoogleFonts.inter(
                  fontSize: 13, // Reduced from 14
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF0386FF)
                      : const Color(0xFF374151),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Icon-only collapsed rail - compact and fluid
  Widget _buildCollapsedRail() {
    if (_isLoading) {
      return const SizedBox(
        width: 64, // Reduced from 72
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Flatten all items from all sections
    final allItems = _sections.expand((section) => section.items).toList();

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
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        constraints: BoxConstraints(
          minWidth: 64,
          maxWidth: _isHovered ? 180 : 64,
        ),
        color: const Color(0xFFF9FAFB),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Expand button at top - compact
            Container(
              margin: const EdgeInsets.all(6),
              child: Material(
                color: const Color(0xFFEC4899),
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  onTap: widget.onToggleCollapse,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 52,
                    height: 36,
                    alignment: Alignment.center,
                    constraints: const BoxConstraints(
                      minWidth: 52,
                      maxWidth: 52,
                      minHeight: 36,
                      maxHeight: 36,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isHovered ? Icons.chevron_left : Icons.chevron_right,
                          color: Colors.white,
                          size: 16,
                        ),
                        if (_isHovered) ...[
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Expand',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.qr_code_scanner,
                            color: Colors.white,
                            size: 12,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            // Icon list - all items flattened with constraints
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                shrinkWrap: false,
                children: allItems.map((item) => _buildCollapsedIcon(item)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedIcon(SidebarItem item) {
    final isSelected = widget.selectedIndex == item.screenIndex;
    final itemColor = item.colorValue != null
        ? Color(item.colorValue!)
        : const Color(0xFF4B5563);

    return Tooltip(
      message: item.label,
      waitDuration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4), // Reduced from 8
        child: Material(
          color: itemColor,
          borderRadius: BorderRadius.circular(10), // Reduced from 12
          child: InkWell(
            onTap: () {
              widget.onItemSelected(item.screenIndex);
            },
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: _isHovered ? null : 52, // Use null instead of double.infinity
              constraints: BoxConstraints(
                minWidth: 52,
                maxWidth: _isHovered ? double.infinity : 52,
                minHeight: 48,
                maxHeight: 48,
              ),
              padding: _isHovered 
                  ? const EdgeInsets.symmetric(horizontal: 10, vertical: 0)
                  : EdgeInsets.zero,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? Border.all(color: const Color(0xFF0386FF), width: 2)
                    : null,
              ),
              child: _isHovered
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          color: Colors.white,
                          size: 18, // Reduced from 20
                        ),
                        const SizedBox(width: 10), // Reduced from 12
                        Flexible(
                          child: Text(
                            item.label,
                            style: GoogleFonts.inter(
                              fontSize: 12, // Reduced from 13
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    )
                  : Icon(
                      item.icon,
                      color: Colors.white,
                      size: 22, // Reduced from 24
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
