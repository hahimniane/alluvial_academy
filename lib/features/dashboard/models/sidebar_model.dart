import 'package:flutter/material.dart';

/// Represents a single navigation item in the sidebar
class SidebarItem {
  final String id;
  final String label;
  final IconData icon;
  final int screenIndex; // Index in the DashboardPage's _screens list
  final int? colorValue; // Color value (0xAARRGGBB)

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
    return SidebarItem(
      id: json['id'],
      label: json['label'],
      icon: IconData(json['iconCode'], fontFamily: 'MaterialIcons'),
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
