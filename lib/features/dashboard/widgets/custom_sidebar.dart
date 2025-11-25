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
    // If the main sidebar is collapsed (icon-only mode), show a simplified rail
    if (widget.isCollapsed) {
      return _buildCollapsedRail();
    }

    if (_isLoading) {
      return const SizedBox(
        width: 250,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      width: 250,
      color: Colors.white,
      child: Column(
        children: [
          // Header / Toggle
          _buildHeader(),

          // Reorderable List
          Expanded(
            child: ReorderableListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
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

          // Reset Button (Optional, for testing/recovery)
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Menu',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF111827),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.menu_open, color: Color(0xFF6B7280)),
            onPressed: widget.onToggleCollapse,
            tooltip: 'Collapse Sidebar',
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () async {
              final defaultSections =
                  await _sidebarService.resetToDefault(widget.userRole);
              setState(() => _sections = defaultSections);
            },
            icon: const Icon(Icons.restore, size: 16, color: Color(0xFF9CA3AF)),
            label: Text(
              'Reset Layout',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF9CA3AF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(SidebarSection section) {
    return Container(
      key: ValueKey(section.id),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header (Draggable handle + Toggle)
          InkWell(
            onTap: () => _toggleSection(section),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Drag Handle
                  const Icon(Icons.drag_indicator,
                      size: 16, color: Color(0xFFD1D5DB)),
                  const SizedBox(width: 8),

                  // Title
                  Expanded(
                    child: Text(
                      section.title.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700, // Bolder
                        color: const Color(0xFF9CA3AF), // Lighter but distinct
                        letterSpacing: 1.0, // More spacing
                      ),
                    ),
                  ),

                  // Expand/Collapse Icon
                  Icon(
                    section.isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: const Color(0xFF9CA3AF),
                  ),
                ],
              ),
            ),
          ),

          // Items
          if (section.isExpanded)
            ...section.items.map((item) => _buildItem(item)),
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
      onTap: () => widget.onItemSelected(item.screenIndex),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 20,
              color: isSelected ? const Color(0xFF0386FF) : itemColor,
            ),
            const SizedBox(width: 12),
            Text(
              item.label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF0386FF)
                    : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Simplified rail for when the sidebar is collapsed
  Widget _buildCollapsedRail() {
    return Container(
      width: 72,
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 16),
          IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF6B7280)),
            onPressed: widget.onToggleCollapse,
            tooltip: 'Expand Sidebar',
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children:
                  _sections.expand((section) => section.items).map((item) {
                final isSelected = widget.selectedIndex == item.screenIndex;
                final itemColor = item.colorValue != null
                    ? Color(item.colorValue!)
                    : const Color(0xFF4B5563);

                return Tooltip(
                  message: item.label,
                  child: InkWell(
                    onTap: () => widget.onItemSelected(item.screenIndex),
                    child: Container(
                      height: 56,
                      alignment: Alignment.center,
                      child: Icon(
                        item.icon,
                        color: isSelected ? const Color(0xFF0386FF) : itemColor,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
