import 'package:alluwalacademyadmin/core/widgets/export_widget.dart';
import 'package:flutter/material.dart';
import '../../features/user_management/screens/add_user_screen.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class HeaderWidget extends StatelessWidget {
  final Function(String) onSearchChanged;
  final Function(String?) onFilterChanged;
  final VoidCallback onExport;
  final VoidCallback? onShowNeverLoggedIn;
  final VoidCallback? onSelectParent;

  const HeaderWidget({
    super.key,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onExport,
    this.onShowNeverLoggedIn,
    this.onSelectParent,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
        child: Row(
          children: [
            // Filter Button
            PopupMenuTheme(
              data: const PopupMenuThemeData(
                color: Colors.white,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  side: BorderSide(color: Color(0xffE2E8F0), width: 1),
                ),
              ),
              child: PopupMenuButton<String>(
                onSelected: (String? value) {
                  onFilterChanged(value);
                },
                itemBuilder: (BuildContext context) => [
                  // User Type Filters
                  PopupMenuItem<String>(
                    value: 'all',
                    child: Row(
                      children: [
                        Icon(Icons.people, color: Colors.grey, size: 20),
                        SizedBox(width: 8),
                        Text(AppLocalizations.of(context)!.allUsers,
                            style: TextStyle(color: Color(0xff2D3748))),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'teacher',
                    child: Row(
                      children: [
                        Icon(Icons.school, color: Color(0xff0386FF), size: 20),
                        SizedBox(width: 8),
                        Text(AppLocalizations.of(context)!.teachers,
                            style: TextStyle(color: Color(0xff2D3748))),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'student',
                    child: Row(
                      children: [
                        Icon(Icons.person, color: Color(0xff00d084), size: 20),
                        SizedBox(width: 8),
                        Text(AppLocalizations.of(context)!.shiftStudents,
                            style: TextStyle(color: Color(0xff2D3748))),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'admin',
                    child: Row(
                      children: [
                        Icon(Icons.admin_panel_settings,
                            color: Color(0xffFF9A6C), size: 20),
                        SizedBox(width: 8),
                        Text(AppLocalizations.of(context)!.admins,
                            style: TextStyle(color: Color(0xff2D3748))),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'parent',
                    child: Row(
                      children: [
                        Icon(Icons.family_restroom,
                            color: Color(0xff9333EA), size: 20),
                        SizedBox(width: 8),
                        Text(AppLocalizations.of(context)!.parents,
                            style: TextStyle(color: Color(0xff2D3748))),
                      ],
                    ),
                  ),
                  // Divider
                  const PopupMenuDivider(),
                  // Status Filters
                  PopupMenuItem<String>(
                    value: 'active',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Text(AppLocalizations.of(context)!.activeUsers,
                            style: TextStyle(color: Color(0xff2D3748))),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'archived',
                    child: Row(
                      children: [
                        Icon(Icons.archive, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text(AppLocalizations.of(context)!.archivedUsers,
                            style: TextStyle(color: Color(0xff2D3748))),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'never_logged_in',
                    child: Row(
                      children: [
                        Icon(Icons.login, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text(AppLocalizations.of(context)!.neverLoggedIn,
                            style: TextStyle(color: Color(0xff2D3748))),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.filter_list, color: Colors.blue, size: 17),
                      const SizedBox(width: 6),
                      Text(
                        AppLocalizations.of(context)!.filter,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Search Field
            SizedBox(
              width: 220,
              height: 34,
              child: TextField(
                maxLines: 1,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.commonSearch,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xffE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xff0386FF)),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                ),
                onChanged: (value) {
                  onSearchChanged(value); // Call the search callback
                },
              ),
            ),
            // Export Button
            const SizedBox(width: 8),
            ExportWidget(onExport: onExport),
            const SizedBox(width: 8),
            // Never Logged In Button
            ElevatedButton(
              onPressed: onShowNeverLoggedIn ??
                  () {
                    onFilterChanged('never_logged_in');
                  },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.login, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(AppLocalizations.of(context)!.usersDidnTLogInYet,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
            ),
            // Filter by Parent Button
            if (onSelectParent != null)
              ElevatedButton(
                onPressed: onSelectParent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff9333EA),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.family_restroom,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(AppLocalizations.of(context)!.filterByParent,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
              ),
            // Add Users Button
            ElevatedButton.icon(
              onPressed: () {
                _showAddUsersBottomSheet(context);
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(AppLocalizations.of(context)!.addUsers,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  )),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddUsersBottomSheet(BuildContext context) {
    showModalBottomSheet(
      constraints: const BoxConstraints(),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
      ),
      backgroundColor: Colors.transparent,
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height *
              0.9, // Adjust the height as needed
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: const AddUsersScreen(),
        );
      },
    );
  }
}
