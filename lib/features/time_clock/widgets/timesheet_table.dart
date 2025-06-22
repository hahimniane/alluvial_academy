import 'package:flutter/material.dart';

class TimesheetTable extends StatelessWidget {
  const TimesheetTable({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Clock In')),
            DataColumn(label: Text('Clock Out')),
            DataColumn(label: Text('Total Hours')),
          ],
          rows: const [
            DataRow(cells: [
              DataCell(Text('2024-03-20')),
              DataCell(Text('9:00 AM')),
              DataCell(Text('5:00 PM')),
              DataCell(Text('8.0')),
            ]),
            // Add more rows as needed
          ],
        ),
      ),
    );
  }
}
