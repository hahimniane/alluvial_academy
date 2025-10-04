import 'package:alluwalacademyadmin/widgets/export_widget.dart';
import 'package:flutter/material.dart';
import '../../features/user_management/screens/add_user_screen.dart';
import '../../core/constants/app_constants.dart';

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
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 30),
        child: Wrap(
          spacing: 18,
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
                  const PopupMenuItem<String>(
                    value: 'all',
                    child: Row(
                      children: [
                        Icon(Icons.people, color: Colors.grey, size: 20),
                        SizedBox(width: 8),
                        Text('All Users',
                            style: TextStyle(color: Color(0xff2D3748))),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'teacher',
                    child: Row(
                      children: [
                        Icon(Icons.school, color: Color(0xff0386FF), size: 20),
                        SizedBox(width: 8),
                        Text('Teachers',
                            style: TextStyle(color: Color(0xff2D3748))),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'student',
                    child: Row(
                      children: [
                        Icon(Icons.person, color: Color(0xff00d084), size: 20),
                        SizedBox(width: 8),
                        Text('Students',
                            style: TextStyle(color: Color(0xff2D3748))),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'admin',
                    child: Row(
                      children: [
                        Icon(Icons.admin_panel_settings,
                            color: Color(0xffFF9A6C), size: 20),
                        SizedBox(width: 8),
                        Text('Admins',
                            style: TextStyle(color: Color(0xff2D3748))),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'parent',
                    child: Row(
                      children: [
                        Icon(Icons.family_restroom,
                            color: Color(0xff9333EA), size: 20),
                        SizedBox(width: 8),
                        Text('Parents',
                            style: TextStyle(color: Color(0xff2D3748))),
                      ],
                    ),
                  ),
                  // Divider
                  const PopupMenuDivider(),
                  // Status Filters
                  const PopupMenuItem<String>(
                    value: 'active',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Text('Active Users',
                            style: TextStyle(color: Color(0xff2D3748))),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'archived',
                    child: Row(
                      children: [
                        Icon(Icons.archive, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Archived Users',
                            style: TextStyle(color: Color(0xff2D3748))),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'never_logged_in',
                    child: Row(
                      children: [
                        Icon(Icons.login, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text('Never Logged In',
                            style: TextStyle(color: Color(0xff2D3748))),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.filter_list, color: Colors.blue, size: 18),
                      SizedBox(width: 8),
                      Text('Filter', style: TextStyle(color: Colors.blue)),
                    ],
                  ),
                ),
              ),
            ),
            // Search Field
            SizedBox(
              width: 200,
              height: 35,
              child: TextField(
                maxLines: 1,
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                ),
                onChanged: (value) {
                  onSearchChanged(value); // Call the search callback
                },
              ),
            ),
            // Export Button
            ExportWidget(onExport: onExport),
            // Never Logged In Button
            ElevatedButton(
              onPressed: onShowNeverLoggedIn ??
                  () {
                    onFilterChanged('never_logged_in');
                  },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.login, color: Colors.white),
                  SizedBox(width: 5),
                  Text('Users didn\'t log in yet',
                      style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            // Filter by Parent Button
            if (onSelectParent != null)
              ElevatedButton(
                onPressed: onSelectParent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff9333EA),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.family_restroom, color: Colors.white),
                    SizedBox(width: 5),
                    Text('Filter by Parent',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            // Add Users Button
            ElevatedButton.icon(
              onPressed: () {
                _showAddUsersBottomSheet(context);
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add users',
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
