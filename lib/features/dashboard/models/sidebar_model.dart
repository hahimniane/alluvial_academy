import 'package:flutter/material.dart';

/// Represents a single navigation item in the sidebar
class SidebarItem {
  final String id;
  final String label;
  final IconData icon;
  final int screenIndex; // Index in the DashboardPage's _screens list
  final int? colorValue; // Color value (0xAARRGGBB)

  static final Map<int, IconData> _knownMaterialIconsByCodePoint = {
    Icons.assignment_ind.codePoint: Icons.assignment_ind,
    Icons.bug_report.codePoint: Icons.bug_report,
    Icons.build.codePoint: Icons.build,
    Icons.chat.codePoint: Icons.chat,
    Icons.dashboard.codePoint: Icons.dashboard,
    Icons.description.codePoint: Icons.description,
    Icons.list_alt.codePoint: Icons.list_alt,
    Icons.menu_book.codePoint: Icons.menu_book,
    Icons.notifications.codePoint: Icons.notifications,
    Icons.payments.codePoint: Icons.payments,
    Icons.people.codePoint: Icons.people,
    Icons.person.codePoint: Icons.person,
    Icons.receipt_long.codePoint: Icons.receipt_long,
    Icons.schedule.codePoint: Icons.schedule,
    Icons.school.codePoint: Icons.school,
    Icons.security.codePoint: Icons.security,
    Icons.settings.codePoint: Icons.settings,
    Icons.task_alt.codePoint: Icons.task_alt,
    Icons.timer.codePoint: Icons.timer,
    Icons.videocam.codePoint: Icons.videocam,
    Icons.web.codePoint: Icons.web,
  };

  const SidebarItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.screenIndex,
    this.colorValue,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'iconCode': icon.codePoint,
        'screenIndex': screenIndex,
        'colorValue': colorValue,
      };

  factory SidebarItem.fromJson(Map<String, dynamic> json) {
    final rawIconCode = json['iconCode'];
    final iconCode = rawIconCode is int ? rawIconCode : int.tryParse('$rawIconCode');

    return SidebarItem(
      id: json['id'],
      label: json['label'],
      // Avoid dynamic IconData construction because it breaks icon tree shaking
      // on web release builds. We only support icons used by SidebarConfig.
      icon: iconCode != null
          ? (_knownMaterialIconsByCodePoint[iconCode] ?? Icons.help_outline)
          : Icons.help_outline,
      screenIndex: json['screenIndex'],
      colorValue: json['colorValue'],
    );
  }
}

/// Represents a collapsible section in the sidebar
class SidebarSection {
  final String id;
  final String title;
  final List<SidebarItem> items;
  bool isExpanded;

  SidebarSection({
    required this.id,
    required this.title,
    required this.items,
    this.isExpanded = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'items': items.map((i) => i.toJson()).toList(),
        'isExpanded': isExpanded,
      };

  factory SidebarSection.fromJson(Map<String, dynamic> json) {
    return SidebarSection(
      id: json['id'],
      title: json['title'],
      items:
          (json['items'] as List).map((i) => SidebarItem.fromJson(i)).toList(),
      isExpanded: json['isExpanded'] ?? true,
    );
  }
}

/// Represents user preferences for the sidebar layout
class SidebarPreferences {
  final List<String> sectionOrder; // List of section IDs in order
  final Map<String, bool>
      sectionExpansionState; // Map of section ID to isExpanded

  SidebarPreferences({
    required this.sectionOrder,
    required this.sectionExpansionState,
  });

  Map<String, dynamic> toJson() => {
        'sectionOrder': sectionOrder,
        'sectionExpansionState': sectionExpansionState,
      };

  factory SidebarPreferences.fromJson(Map<String, dynamic> json) {
    return SidebarPreferences(
      sectionOrder: List<String>.from(json['sectionOrder'] ?? []),
      sectionExpansionState:
          Map<String, bool>.from(json['sectionExpansionState'] ?? {}),
    );
  }
}
