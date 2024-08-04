// import 'package:flutter/material.dart';
//
// class HomePage extends StatelessWidget {
//   const HomePage({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Connecteam Clone'),
//         actions: [
//           IconButton(icon: Icon(Icons.notifications), onPressed: () {}),
//           CircleAvatar(
//             backgroundColor: Colors.blue,
//             child: Text('HN'),
//           ),
//         ],
//       ),
//       body: Row(
//         children: [
//           NavigationPanel(),
//           Expanded(child: MainContent()),
//         ],
//       ),
//     );
//   }
// }
//
// class NavigationPanel extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: 250,
//       color: Colors.grey[200],
//       child: ListView(
//         children: [
//           const UserAccountsDrawerHeader(
//             accountName: Text('Hassimiou Niane'),
//             accountEmail: Text('HN'),
//             currentAccountPicture: CircleAvatar(
//               backgroundColor: Colors.blue,
//               child: Text('HN'),
//             ),
//           ),
//           ListTile(
//             leading: Icon(Icons.access_time),
//             title: Text('Time Clock'),
//             onTap: () {},
//           ),
//           ListTile(
//             leading: Icon(Icons.assignment),
//             title: Text('Forms'),
//             onTap: () {},
//           ),
//           ListTile(
//             leading: Icon(Icons.schedule),
//             title: Text('Job Scheduling'),
//             onTap: () {},
//           ),
//           ListTile(
//             leading: Icon(Icons.task),
//             title: Text('Quick Tasks'),
//             onTap: () {},
//           ),
//           ListTile(
//             leading: Icon(Icons.time_to_leave),
//             title: Text('Time Off'),
//             onTap: () {},
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class MainContent extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           TodayClock(),
//           SizedBox(height: 16),
//           RequestsSection(),
//           SizedBox(height: 16),
//           TimesheetSection(),
//         ],
//       ),
//     );
//   }
// }
//
// class TodayClock extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text('Total work hours today 00:00'),
//             ElevatedButton(
//               onPressed: () {},
//               child: Text('Clock in'),
//               style: ElevatedButton.styleFrom(
//                 shape: CircleBorder(),
//                 padding: EdgeInsets.all(24),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class RequestsSection extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Requests'),
//             SizedBox(height: 8),
//             ElevatedButton.icon(
//               onPressed: () {},
//               icon: Icon(Icons.add),
//               label: Text('Add a shift request'),
//             ),
//             ElevatedButton.icon(
//               onPressed: () {},
//               icon: Icon(Icons.add),
//               label: Text('Add an absence request'),
//             ),
//             TextButton(
//               onPressed: () {},
//               child: Text('View your requests'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class TimesheetSection extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Text('Timesheet (07/06 to 07/20)'),
//                 Spacer(),
//                 TextButton(
//                   onPressed: () {},
//                   child: Text('Select empty days'),
//                 ),
//                 TextButton(
//                   onPressed: () {},
//                   child: Text('Export'),
//                 ),
//                 ElevatedButton(
//                   onPressed: () {},
//                   child: Text('Submit timesheet'),
//                 ),
//               ],
//             ),
//             DataTable(
//               columns: [
//                 DataColumn(label: Text('Date')),
//                 DataColumn(label: Text('Type')),
//                 DataColumn(label: Text('Sub job')),
//                 DataColumn(label: Text('Start')),
//                 DataColumn(label: Text('End')),
//                 DataColumn(label: Text('Total hours')),
//               ],
//               rows: [
//                 DataRow(cells: [
//                   DataCell(Text('Sat 7/20')),
//                   DataCell(Text('--')),
//                   DataCell(Text('--')),
//                   DataCell(Text('--')),
//                   DataCell(Text('--')),
//                   DataCell(Text('--')),
//                 ]),
//                 DataRow(cells: [
//                   DataCell(Text('Fri 7/19')),
//                   DataCell(Text('Front Desk')),
//                   DataCell(Text('--')),
//                   DataCell(Text('03:24 PM')),
//                   DataCell(Text('03:25 PM')),
//                   DataCell(Text('00:01')),
//                 ]),
//                 DataRow(cells: [
//                   DataCell(Text('Thu 7/18')),
//                   DataCell(Text('--')),
//                   DataCell(Text('--')),
//                   DataCell(Text('--')),
//                   DataCell(Text('--')),
//                   DataCell(Text('--')),
//                 ]),
//                 DataRow(cells: [
//                   DataCell(Text('Wed 7/17')),
//                   DataCell(Text('--')),
//                   DataCell(Text('--')),
//                   DataCell(Text('--')),
//                   DataCell(Text('--')),
//                   DataCell(Text('--')),
//                 ]),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
