import 'package:flutter/material.dart';

class ClockCard extends StatelessWidget {
  const ClockCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              '12:00:00 PM',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Implement clock in
                  },
                  child: const Text('Clock In'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Implement clock out
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text('Clock Out'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
