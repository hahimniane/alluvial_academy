import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sidebar_model.dart';
import '../config/sidebar_config.dart';

class SidebarService {
  static const String _prefsKey = 'admin_sidebar_preferences';

  /// Loads the sidebar structure, applying user preferences if they exist.
  Future<List<SidebarSection>> loadSidebar(String? role) async {
    final defaultSections = SidebarConfig.getStructureForRole(role);

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_prefsKey);

      if (jsonString == null) {
        return defaultSections;
      }

      final preferences = SidebarPreferences.fromJson(jsonDecode(jsonString));
      return _applyPreferences(defaultSections, preferences);
    } catch (e) {
      print('Error loading sidebar preferences: $e');
      return defaultSections;
    }
  }

  /// Saves the current state of the sidebar (order and expansion).
  Future<void> saveSidebarState(List<SidebarSection> sections) async {
    try {
      final preferences = SidebarPreferences(
        sectionOrder: sections.map((s) => s.id).toList(),
        sectionExpansionState: {
          for (var s in sections) s.id: s.isExpanded,
        },
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(preferences.toJson()));
    } catch (e) {
      print('Error saving sidebar preferences: $e');
    }
  }

  /// Resets the sidebar to the default configuration.
  Future<List<SidebarSection>> resetToDefault(String? role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    return SidebarConfig.getStructureForRole(role);
  }

  /// Merges user preferences with the default structure.
  /// This ensures that if new sections are added to the code, they appear even if
  /// the user has old preferences.
  List<SidebarSection> _applyPreferences(
    List<SidebarSection> defaultSections,
    SidebarPreferences preferences,
  ) {
    // Create a map for quick lookup
    final sectionMap = {for (var s in defaultSections) s.id: s};
    final orderedSections = <SidebarSection>[];

    // 1. Add sections in the user's preferred order
    for (var id in preferences.sectionOrder) {
      if (sectionMap.containsKey(id)) {
        final section = sectionMap[id]!;
        // Apply expansion state
        if (preferences.sectionExpansionState.containsKey(id)) {
          section.isExpanded = preferences.sectionExpansionState[id]!;
        }
        orderedSections.add(section);
        sectionMap.remove(id); // Remove so we don't add it again
      }
    }

    // 2. Add any remaining sections (newly added in code) at the end
    // Or insert them at their default index if possible, but appending is safer
    orderedSections.addAll(sectionMap.values);

    return orderedSections;
  }
}
