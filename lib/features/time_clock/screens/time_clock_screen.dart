import 'package:flutter/material.dart';
import '../widgets/clock_card.dart';
import '../widgets/timesheet_table.dart';

class TimeClockScreen extends StatelessWidget {
  const TimeClockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Time Clock',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
          const ClockCard(),
          const SizedBox(height: 24),
          Text(
            'Recent Time Entries',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          const Expanded(
            child: TimesheetTable(),
          ),
        ],
      ),
    );
  }
}
