import 'package:flutter/material.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class ClockCard extends StatelessWidget {
  const ClockCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              AppLocalizations.of(context)!.time1200Pm,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Implement clock in
                  },
                  child: Text(AppLocalizations.of(context)!.clockIn),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Implement clock out
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: Text(AppLocalizations.of(context)!.clockOut),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
