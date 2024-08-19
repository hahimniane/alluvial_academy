import 'package:alluwalacademyadmin/widgets/export_widget.dart';
import 'package:flutter/material.dart';
import 'add_new_user_screen.dart';
import 'const.dart';

class HeaderWidget extends StatelessWidget {
  final Function(String) onSearchChanged;
  final VoidCallback onExport;

  const HeaderWidget(
      {super.key, required this.onSearchChanged, required this.onExport});

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
            ElevatedButton.icon(
              onPressed: () {
                // Handle filter button press
              },
              icon: const Icon(Icons.filter_list, color: Colors.blue),
              label: const Text('Filter', style: TextStyle(color: Colors.blue)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Colors.blue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            // Search Field
            Container(
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
                  contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                ),
                onChanged: (value) {
                  onSearchChanged(value); // Call the search callback
                },
              ),
            ),
            // Export Button
            ExportWidget(onExport: onExport),
            // Notification Button
            ElevatedButton(
              onPressed: () {
                // Handle notification button press
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 5),
                  Text('Users didn\'t log in yet',
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
      constraints: BoxConstraints(),
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
          child: AddUsersScreen(),
        );
      },
    );
  }
}
