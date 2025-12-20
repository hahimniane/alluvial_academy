import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alluwalacademyadmin/features/dashboard/config/sidebar_config.dart';
import 'package:alluwalacademyadmin/features/dashboard/services/sidebar_service.dart';

void main() {
  group('SidebarConfig', () {
    test('getStructureForRole returns admin structure for admin role', () {
      final sections = SidebarConfig.getStructureForRole('admin');
      expect(sections.any((s) => s.id == 'people'), isTrue);
      expect(sections.any((s) => s.id == 'system'), isTrue);
    });

    test('getStructureForRole returns teacher structure for teacher role', () {
      final sections = SidebarConfig.getStructureForRole('teacher');
      expect(sections.any((s) => s.id == 'work'), isTrue);
      expect(sections.any((s) => s.id == 'people'),
          isFalse); // Teachers shouldn't see People
    });

    test('getStructureForRole returns student structure for student role', () {
      final sections = SidebarConfig.getStructureForRole('student');
      expect(sections.any((s) => s.id == 'learning'), isTrue);
      expect(sections.any((s) => s.id == 'operations'), isFalse);
    });

    test('getStructureForRole defaults to student structure for null role', () {
      final sections = SidebarConfig.getStructureForRole(null);
      expect(sections.any((s) => s.id == 'learning'), isTrue);
    });
  });

  group('SidebarService', () {
    late SidebarService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = SidebarService();
    });

    test('loadSidebar returns default structure when no prefs exist', () async {
      final sections = await service.loadSidebar('admin');
      final defaultSections = SidebarConfig.getStructureForRole('admin');

      expect(sections.length, equals(defaultSections.length));
      expect(sections[0].id, equals(defaultSections[0].id));
    });

    test('saveSidebarState saves order and expansion state', () async {
      final sections = SidebarConfig.getStructureForRole('admin');
      // Modify state
      sections[0].isExpanded = false;

      await service.saveSidebarState(sections);

      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('admin_sidebar_preferences');
      expect(jsonString, isNotNull);

      // Verify persistence
      final loadedSections = await service.loadSidebar('admin');
      expect(loadedSections[0].isExpanded, isFalse);
    });

    test('loadSidebar applies saved order', () async {
      final sections = SidebarConfig.getStructureForRole('admin');
      // Swap first two sections
      final first = sections[0];
      final second = sections[1];
      sections[0] = second;
      sections[1] = first;

      await service.saveSidebarState(sections);

      final loadedSections = await service.loadSidebar('admin');
      expect(loadedSections[0].id, equals(second.id));
      expect(loadedSections[1].id, equals(first.id));
    });

    test('resetToDefault clears preferences', () async {
      final sections = SidebarConfig.getStructureForRole('admin');
      sections[0].isExpanded = false;
      await service.saveSidebarState(sections);

      final resetSections = await service.resetToDefault('admin');
      expect(resetSections[0].isExpanded,
          isTrue); // Should be back to default (true)

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('admin_sidebar_preferences'), isFalse);
    });
  });
}
