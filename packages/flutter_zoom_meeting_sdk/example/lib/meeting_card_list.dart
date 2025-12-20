import 'package:flutter/material.dart';

class MeetingCardList extends StatelessWidget {
  final List<Map<String, String>> data;
  final Function(Map<String, String>) onJoinPressed;

  const MeetingCardList({
    super.key,
    required this.data,
    required this.onJoinPressed,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Set column count based on screen width
    int crossAxisCount;
    if (screenWidth > 1000) {
      crossAxisCount = 3;
    } else if (screenWidth > 600) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 1;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        itemCount: data.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.3,
        ),
        itemBuilder: (context, index) {
          final meeting = data[index];
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meeting Number: ${meeting['meetingNumber']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Password: ${meeting['password']}'),
                  const SizedBox(height: 8),
                  Text('Display Name: ${meeting['displayName']}'),
                  const SizedBox(height: 8),
                  Text('Webinar Token: ${meeting['webinarToken']}'),
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: ElevatedButton(
                      onPressed: () => onJoinPressed(meeting),
                      child: const Text("Join"),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
