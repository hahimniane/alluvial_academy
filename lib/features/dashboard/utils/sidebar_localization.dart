import 'package:flutter/material.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class SidebarLocalization {
  static String translate(BuildContext context, String text) {
    switch (text) {
      case 'Audits':
        return AppLocalizations.of(context)!.sidebarAudits;
      case 'CMS':
        return AppLocalizations.of(context)!.sidebarCms;
      case 'Chat':
        return AppLocalizations.of(context)!.navChat;
      case 'Classes':
        return AppLocalizations.of(context)!.dashboardClasses;
      case 'Communication':
        return AppLocalizations.of(context)!.sidebarCommunication;
      case 'Dashboard':
        return AppLocalizations.of(context)!.navDashboard;
      case 'Debug':
        return AppLocalizations.of(context)!.debug;
      case 'Form Builder':
        return AppLocalizations.of(context)!.sidebarFormbuilder;
      case 'Forms':
        return AppLocalizations.of(context)!.navForms;
      case 'Learning':
        return AppLocalizations.of(context)!.sidebarLearning;
      case 'My Report':
        return AppLocalizations.of(context)!.sidebarMyreport;
      case 'My Shifts':
        return AppLocalizations.of(context)!.sidebarMyshifts;
      case 'Notifications':
        return AppLocalizations.of(context)!.notificationsTitle;
      case 'Operations':
        return AppLocalizations.of(context)!.sidebarOperations;
      case 'Overview':
        return AppLocalizations.of(context)!.overview;
      case 'People':
        return AppLocalizations.of(context)!.sidebarPeople;
      case 'Reports':
        return AppLocalizations.of(context)!.sidebarReports;
      case 'Responses':
        return AppLocalizations.of(context)!.responses;
      case 'Roles (Test)':
        return AppLocalizations.of(context)!.sidebarRolestest;
      case 'Settings':
        return AppLocalizations.of(context)!.settingsTitle;
      case 'Shifts':
        return AppLocalizations.of(context)!.navShifts;
      case 'Student Applicants':
        return AppLocalizations.of(context)!.studentApplicants;
      case 'Subject Rates':
        return AppLocalizations.of(context)!.sidebarSubjectrates;
      case 'Submit Form':
        return AppLocalizations.of(context)!.submitForm;
      case 'System':
        return AppLocalizations.of(context)!.settingsSystemMode;
      case 'Tasks':
        return AppLocalizations.of(context)!.navTasks;
      case 'Teacher Applicants':
        return AppLocalizations.of(context)!.teacherApplicants;
      case 'Test Audit Génération':
        return AppLocalizations.of(context)!.sidebarTestauditgeneration;
      case 'Time Clock':
        return AppLocalizations.of(context)!.navTimeClock;
      case 'Timesheets':
        return AppLocalizations.of(context)!.timesheets;
      case 'Users':
        return AppLocalizations.of(context)!.navUsers;
      case 'Website':
        return AppLocalizations.of(context)!.sidebarWebsite;
      case 'Work':
        return AppLocalizations.of(context)!.sidebarWork;
      default:
        return text;
    }
  }
}
