import 'package:flutter/material.dart';
import '../models/sidebar_model.dart';

class SidebarConfig {
  static List<SidebarSection> getStructureForRole(String? role) {
    // Default to student/limited view if role is null
    final userRole = role?.toLowerCase() ?? 'student';

    if (userRole == 'admin' || userRole == 'super_admin') {
      return _getAdminStructure();
    } else if (userRole == 'teacher') {
      return _getTeacherStructure();
    } else {
      return _getStudentStructure();
    }
  }

  static List<SidebarSection> _getAdminStructure() {
    return [
      SidebarSection(
        id: 'overview',
        title: 'Overview',
        items: [
          const SidebarItem(
            id: 'dashboard',
            label: 'Dashboard',
            icon: Icons.dashboard,
            screenIndex: 0,
            colorValue: 0xff0386FF,
          ),
        ],
      ),
      SidebarSection(
        id: 'people',
        title: 'People',
        items: [
          const SidebarItem(
            id: 'users',
            label: 'Users',
            icon: Icons.people,
            screenIndex: 1,
            colorValue: 0xff10B981,
          ),
          const SidebarItem(
            id: 'enrollment',
            label: 'Student Applicants',
            icon: Icons.school,
            screenIndex: 16,
            colorValue: 0xff8B5CF6,
          ),
          const SidebarItem(
            id: 'applications',
            label: 'Teacher Applicants',
            icon: Icons.assignment_ind,
            screenIndex: 17,
            colorValue: 0xffF59E0B,
          ),
        ],
      ),
      SidebarSection(
        id: 'operations',
        title: 'Operations',
        items: [
          const SidebarItem(
            id: 'shifts',
            label: 'Shifts',
            icon: Icons.schedule,
            screenIndex: 3,
            colorValue: 0xffF59E0B,
          ),
          const SidebarItem(
            id: 'timesheets',
            label: 'Timesheets',
            icon: Icons.receipt_long,
            screenIndex: 7,
            colorValue: 0xff8B5CF6,
          ),
          const SidebarItem(
            id: 'tasks',
            label: 'Tasks',
            icon: Icons.task_alt,
            screenIndex: 11,
            colorValue: 0xff14B8A6,
          ),
          const SidebarItem(
            id: 'audits',
            label: 'Audits',
            icon: Icons.assessment,
            screenIndex: 19,
            colorValue: 0xffDC2626,
          ),
          const SidebarItem(
            id: 'subject_rates',
            label: 'Subject Rates',
            icon: Icons.attach_money,
            screenIndex: 20,
            colorValue: 0xff059669,
          ),
        ],
      ),
      SidebarSection(
        id: 'communication',
        title: 'Communication',
        items: [
          const SidebarItem(
            id: 'chat',
            label: 'Chat',
            icon: Icons.chat,
            screenIndex: 5,
            colorValue: 0xffA646F2,
          ),
          const SidebarItem(
            id: 'zoom',
            label: 'Classes',
            icon: Icons.videocam,
            screenIndex: 12,
            colorValue: 0xff2D8CFF,
          ),
          const SidebarItem(
            id: 'notifications',
            label: 'Notifications',
            icon: Icons.notifications,
            screenIndex: 15,
            colorValue: 0xffF43F5E,
          ),
        ],
      ),
      SidebarSection(
        id: 'forms',
        title: 'Forms',
        items: [
          const SidebarItem(
            id: 'form_builder',
            label: 'Form Builder',
            icon: Icons.build,
            screenIndex: 10,
            colorValue: 0xffF97316,
          ),
          const SidebarItem(
            id: 'responses',
            label: 'Responses',
            icon: Icons.list_alt,
            screenIndex: 9,
            colorValue: 0xff6366F1,
          ),
          const SidebarItem(
            id: 'submit_form',
            label: 'Submit Form',
            icon: Icons.description,
            screenIndex: 8,
            colorValue: 0xffEC4899,
          ),
        ],
      ),
      SidebarSection(
        id: 'website',
        title: 'Website',
        items: [
          const SidebarItem(
            id: 'website_mgmt',
            label: 'CMS',
            icon: Icons.web,
            screenIndex: 2,
            colorValue: 0xff7C3AED,
          ),
        ],
      ),
      SidebarSection(
        id: 'system',
        title: 'System',
        items: [
          const SidebarItem(
            id: 'settings',
            label: 'Settings',
            icon: Icons.settings,
            screenIndex: 18,
            colorValue: 0xff6B7280,
          ),
          const SidebarItem(
            id: 'test_audit',
            label: 'Test Audit Génération',
            icon: Icons.play_arrow,
            screenIndex: 22,
            colorValue: 0xff10B981,
          ),
          const SidebarItem(
            id: 'roles',
            label: 'Roles (Test)',
            icon: Icons.security,
            screenIndex: 13,
          ),
          const SidebarItem(
            id: 'debug',
            label: 'Debug',
            icon: Icons.bug_report,
            screenIndex: 14,
          ),
        ],
      ),
    ];
  }

  static List<SidebarSection> _getTeacherStructure() {
    return [
      SidebarSection(
        id: 'overview',
        title: 'Overview',
        items: [
          const SidebarItem(
            id: 'dashboard',
            label: 'Dashboard',
            icon: Icons.dashboard,
            screenIndex: 0,
            colorValue: 0xff0386FF,
          ),
        ],
      ),
      SidebarSection(
        id: 'work',
        title: 'Work',
        items: [
          const SidebarItem(
            id: 'my_shifts',
            label: 'My Shifts',
            icon: Icons.schedule,
            screenIndex: 4,
            colorValue: 0xff059669,
          ),
          const SidebarItem(
            id: 'time_clock',
            label: 'Time Clock',
            icon: Icons.timer,
            screenIndex: 6,
            colorValue: 0xffEF4444,
          ),
          const SidebarItem(
            id: 'tasks',
            label: 'Tasks',
            icon: Icons.task_alt,
            screenIndex: 11,
            colorValue: 0xff14B8A6,
          ),
        ],
      ),
      SidebarSection(
        id: 'communication',
        title: 'Communication',
        items: [
          const SidebarItem(
            id: 'chat',
            label: 'Chat',
            icon: Icons.chat,
            screenIndex: 5,
            colorValue: 0xffA646F2,
          ),
          const SidebarItem(
            id: 'zoom',
            label: 'Classes',
            icon: Icons.videocam,
            screenIndex: 12,
            colorValue: 0xff2D8CFF,
          ),
        ],
      ),
      SidebarSection(
        id: 'forms',
        title: 'Forms',
        items: [
          const SidebarItem(
            id: 'submit_form',
            label: 'Submit Form',
            icon: Icons.description,
            screenIndex: 23, // Changed to TeacherFormsScreen (new template system)
            colorValue: 0xffEC4899,
          ),
        ],
      ),
      SidebarSection(
        id: 'reports',
        title: 'Reports',
        items: [
          const SidebarItem(
            id: 'my_audit',
            label: 'My Report',
            icon: Icons.assessment,
            screenIndex: 21,
            colorValue: 0xffDC2626,
          ),
        ],
      ),
    ];
  }

  static List<SidebarSection> _getStudentStructure() {
    return [
      SidebarSection(
        id: 'overview',
        title: 'Overview',
        items: [
          const SidebarItem(
            id: 'dashboard',
            label: 'Dashboard',
            icon: Icons.dashboard,
            screenIndex: 0,
            colorValue: 0xff0386FF,
          ),
        ],
      ),
      SidebarSection(
        id: 'learning',
        title: 'Learning',
        items: [
          const SidebarItem(
            id: 'zoom',
            label: 'Classes',
            icon: Icons.videocam,
            screenIndex: 12,
            colorValue: 0xff2D8CFF,
          ),
          const SidebarItem(
            id: 'tasks',
            label: 'Tasks',
            icon: Icons.task_alt,
            screenIndex: 11,
            colorValue: 0xff14B8A6,
          ),
        ],
      ),
      SidebarSection(
        id: 'communication',
        title: 'Communication',
        items: [
          const SidebarItem(
            id: 'chat',
            label: 'Chat',
            icon: Icons.chat,
            screenIndex: 5,
            colorValue: 0xffA646F2,
          ),
        ],
      ),
    ];
  }
}
