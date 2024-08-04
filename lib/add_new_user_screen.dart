// import 'package:alluwalacademyadmin/const.dart';
// import 'package:flutter/material.dart';
// import 'package:intl_phone_field/intl_phone_field.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
//
// class AddUsersScreen extends StatefulWidget {
//   @override
//   _AddUsersScreenState createState() => _AddUsersScreenState();
// }
//
// class _AddUsersScreenState extends State<AddUsersScreen> {
//   List<int> userRows = [0, 1, 2]; // Initial list with three rows
//   final Map<int, UserInputRow> userRowsWidgets =
//       {}; // Map to hold the row widgets by index
//
//   void _addUserRow() {
//     setState(() {
//       userRows.add(userRows.length);
//     });
//   }
//
//   void _removeUserRow(int index) {
//     setState(() {
//       userRows.removeAt(index);
//       userRowsWidgets.remove(index);
//     });
//   }
//
//   void _handleContinue() async {
//     bool allValid = true;
//     List<Map<String, String?>> usersData = [];
//
//     for (var index in userRows) {
//       var row = userRowsWidgets[index];
//       if (row!.isAnyFieldPopulated() && !row.areAllFieldsPopulated()) {
//         allValid = false;
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             backgroundColor: Colors.red,
//             content: Text(
//               'All fields in row ${index + 1} must be filled',
//               style: openSansHebrewTextStyle.copyWith(color: Colors.white),
//             ),
//           ),
//         );
//         break;
//       }
//
//       if (row.areAllFieldsPopulated()) {
//         usersData.add({
//           'first_name': row.firstNameController.text,
//           'last_name': row.lastNameController.text,
//           'phone_number': row.phoneController.text,
//           'email': row.emailController.text,
//           'country_code': row.countryCode,
//           'user_type': "admin",
//           'title': "Teacher",
//           'employment_start_date': DateTime.now().toString(),
//           'kiosk_code': "123",
//           'date_added': DateTime.now().toString(),
//           'last_login': DateTime.now().toString(),
//         });
//       }
//     }
//
//     if (allValid) {
//       for (var userData in usersData) {
//         try {
//           await FirebaseFirestore.instance.collection('users').add(userData);
//         } catch (e) {
//           print(e.toString());
//         }
//       }
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Data saved successfully')),
//       );
//
//       // Clear all the fields
//       setState(() {
//         for (var row in userRowsWidgets.values) {
//           row.clearFields();
//         }
//       });
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             // Header
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Row(
//                   children: [
//                     Icon(Icons.add, color: Colors.grey),
//                     SizedBox(width: 8),
//                     Text('Add new users', style: TextStyle(color: Colors.grey)),
//                   ],
//                 ),
//                 TextButton(
//                   onPressed: () {
//                     // Handle learn more
//                   },
//                   child:
//                       Text('Learn more', style: TextStyle(color: Colors.blue)),
//                 ),
//               ],
//             ),
//             SizedBox(height: 16),
//
//             // Instruction
//             Text(
//               'Users login to the mobile and web app using their mobile phone number',
//               style: TextStyle(fontSize: 16),
//               textAlign: TextAlign.center,
//             ),
//             SizedBox(height: 16),
//
//             // Table Header
//             Container(
//               padding: const EdgeInsets.symmetric(vertical: 8.0),
//               color: Colors.grey[200],
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceAround,
//                 children: [
//                   Text('First name*',
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   Text('Last name*',
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   Text('Mobile phone*',
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   Text('Email', style: TextStyle(fontWeight: FontWeight.bold)),
//                 ],
//               ),
//             ),
//
//             // User Input Rows
//             Expanded(
//               child: ListView.builder(
//                 itemCount: userRows.length,
//                 itemBuilder: (context, index) {
//                   final rowIndex = userRows[index];
//                   final row = UserInputRow(
//                     key: ValueKey(rowIndex),
//                     index: rowIndex,
//                     onDelete: () => _removeUserRow(rowIndex),
//                   );
//                   userRowsWidgets[rowIndex] = row;
//                   return Row(
//                     children: [
//                       Expanded(child: row),
//                       IconButton(
//                         onPressed: () => _removeUserRow(rowIndex),
//                         icon: Icon(Icons.delete, color: Colors.grey, size: 18),
//                       ),
//                     ],
//                   );
//                 },
//               ),
//             ),
//
//             // Add User Button
//             TextButton.icon(
//               onPressed: _addUserRow,
//               icon: const Icon(Icons.add, color: Colors.blue),
//               label:
//                   const Text('Add user', style: TextStyle(color: Colors.blue)),
//             ),
//
//             // Footer Buttons
//             Align(
//               alignment: Alignment.centerRight,
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.end,
//                 children: [
//                   TextButton(
//                     onPressed: () {
//                       Navigator.pop(context);
//                     },
//                     child: const Text('Cancel'),
//                   ),
//                   ElevatedButton(
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.blue,
//                     ),
//                     onPressed: _handleContinue,
//                     child: const Text(
//                       'Continue',
//                       style: TextStyle(color: Colors.white),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class UserInputRow extends StatelessWidget {
//   final int index;
//   final TextEditingController firstNameController = TextEditingController();
//   final TextEditingController lastNameController = TextEditingController();
//   final TextEditingController phoneController = TextEditingController();
//   final TextEditingController emailController = TextEditingController();
//   String countryCode = "";
//   final VoidCallback onDelete;
//
//   UserInputRow({Key? key, required this.index, required this.onDelete})
//       : super(key: key);
//
//   bool isAnyFieldPopulated() {
//     return firstNameController.text.isNotEmpty ||
//         lastNameController.text.isNotEmpty ||
//         phoneController.text.isNotEmpty ||
//         emailController.text.isNotEmpty;
//   }
//
//   bool areAllFieldsPopulated() {
//     return firstNameController.text.isNotEmpty &&
//         lastNameController.text.isNotEmpty &&
//         phoneController.text.isNotEmpty &&
//         emailController.text.isNotEmpty;
//   }
//
//   void clearFields() {
//     firstNameController.clear();
//     lastNameController.clear();
//     phoneController.clear();
//     emailController.clear();
//     countryCode = "";
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8.0),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceAround,
//         children: [
//           Expanded(
//             flex: 2,
//             child: Container(
//               height: 60,
//               child: TextField(
//                 controller: firstNameController,
//                 decoration: InputDecoration(
//                   hintStyle: const TextStyle(color: Colors.grey),
//                   hintText: 'First name',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(width: 8),
//           Expanded(
//             flex: 2,
//             child: Container(
//               height: 60,
//               child: TextField(
//                 controller: lastNameController,
//                 decoration: InputDecoration(
//                   hintStyle: const TextStyle(color: Colors.grey),
//                   hintText: 'Last name',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(width: 8),
//           Expanded(
//             flex: 3,
//             child: Container(
//               padding: const EdgeInsets.only(top: 5),
//               height: 70,
//               child: IntlPhoneField(
//                 controller: phoneController,
//                 initialCountryCode: 'US',
//                 onChanged: (phone) {
//                   countryCode = phone.countryCode;
//                 },
//                 decoration: InputDecoration(
//                   hintText: 'Phone Number',
//                   hintStyle: const TextStyle(color: Colors.grey),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(width: 8),
//           Expanded(
//             flex: 3,
//             child: SizedBox(
//               height: 60,
//               child: TextField(
//                 controller: emailController,
//                 decoration: InputDecoration(
//                   hintStyle: const TextStyle(color: Colors.grey),
//                   hintText: 'Email',
//                   border: OutlineInputBorder(
//                     borderSide: const BorderSide(
//                       color: Colors.grey, // Set the color of the border
//                       width:
//                           0.0, // Set the width of the border (make it smaller)
//                     ),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // Function to show the bottom sheet
// void _showAddUsersBottomSheet(BuildContext context) {
//   showModalBottomSheet(
//     shape: const RoundedRectangleBorder(
//       borderRadius: BorderRadius.only(
//         topLeft: Radius.circular(20.0),
//         topRight: Radius.circular(20.0),
//       ),
//     ),
//     backgroundColor: Colors.transparent,
//     context: context,
//     isScrollControlled: true,
//     builder: (context) {
//       return Container(
//         height: MediaQuery.of(context).size.height *
//             0.9, // Adjust the height as needed
//         decoration: const BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.only(
//             topLeft: Radius.circular(20),
//             topRight: Radius.circular(20),
//           ),
//         ),
//         child: AddUsersScreen(),
//       );
//     },
//   );
// }
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'const.dart';

class AddUsersScreen extends StatefulWidget {
  @override
  _AddUsersScreenState createState() => _AddUsersScreenState();
}

class _AddUsersScreenState extends State<AddUsersScreen> {
  List<int> userRows = [0, 1, 2]; // Initial list with three rows
  final Map<int, UserInputRow> userRowsWidgets =
      {}; // Map to hold the row widgets by index

  void _addUserRow() {
    setState(() {
      userRows.add(userRows.length);
    });
  }

  void _removeUserRow(int index) {
    setState(() {
      userRows.removeAt(index);
      userRowsWidgets.remove(index);
    });
  }

  void _handleContinue() async {
    bool allValid = true;
    List<Map<String, String?>> usersData = [];

    for (var index in userRows) {
      var row = userRowsWidgets[index];
      if (row!.isAnyFieldPopulated() && !row.areAllFieldsPopulated()) {
        allValid = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              'All fields in row ${index + 1} must be filled',
              style: openSansHebrewTextStyle.copyWith(color: Colors.white),
            ),
          ),
        );
        break;
      }

      if (row.areAllFieldsPopulated()) {
        usersData.add({
          'first_name': row.firstNameController.text,
          'last_name': row.lastNameController.text,
          'phone_number': row.phoneController.text,
          'email': row.emailController.text,
          'country_code': row.countryCode,
          'user_type': "admin",
          'title': "Teacher",
          'employment_start_date': DateTime.now().toString(),
          'kiosk_code': "123",
          'date_added': DateTime.now().toString(),
          'last_login': DateTime.now().toString(),
        });
      }
    }

    if (allValid) {
      for (var userData in usersData) {
        try {
          await FirebaseFirestore.instance.collection('users').add(userData);
        } catch (e) {
          print(e.toString());
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data saved successfully')),
      );

      // Clear all the fields
      setState(() {
        for (var row in userRowsWidgets.values) {
          row.clearFields();
        }
      });
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.add, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Add new users', style: TextStyle(color: Colors.grey)),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    // Handle learn more
                  },
                  child: const Text('Learn more',
                      style: TextStyle(color: Colors.blue)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Instruction
            const Text(
              'Users login to the mobile and web app using their mobile phone number',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Table Header
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(3),
                3: FlexColumnWidth(3),
              },
              children: const [
                TableRow(
                  decoration: BoxDecoration(),
                  children: [
                    Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 8.0, horizontal: 8),
                      child: Text(
                        'First name*',
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.start,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Last name*',
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.start,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Mobile phone*',
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.start,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Email',
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.start,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // User Input Rows
            Expanded(
              child: ListView.builder(
                itemCount: userRows.length,
                itemBuilder: (context, index) {
                  final rowIndex = userRows[index];
                  final row = UserInputRow(
                    key: ValueKey(rowIndex),
                    index: rowIndex,
                    onDelete: () => _removeUserRow(rowIndex),
                  );
                  userRowsWidgets[rowIndex] = row;
                  return Row(
                    children: [
                      Expanded(child: row),
                      IconButton(
                        onPressed: () => _removeUserRow(rowIndex),
                        icon: const Icon(Icons.delete,
                            color: Colors.grey, size: 18),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Add User Button
            TextButton.icon(
              onPressed: _addUserRow,
              icon: const Icon(Icons.add, color: Colors.blue),
              label:
                  const Text('Add user', style: TextStyle(color: Colors.blue)),
            ),

            // Footer Buttons
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    onPressed: _handleContinue,
                    child: const Text(
                      'Continue',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UserInputRow extends StatelessWidget {
  final int index;
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  String countryCode = "";
  final VoidCallback onDelete;

  UserInputRow({Key? key, required this.index, required this.onDelete})
      : super(key: key);

  bool isAnyFieldPopulated() {
    return firstNameController.text.isNotEmpty ||
        lastNameController.text.isNotEmpty ||
        phoneController.text.isNotEmpty ||
        emailController.text.isNotEmpty;
  }

  bool areAllFieldsPopulated() {
    return firstNameController.text.isNotEmpty &&
        lastNameController.text.isNotEmpty &&
        phoneController.text.isNotEmpty &&
        emailController.text.isNotEmpty;
  }

  void clearFields() {
    firstNameController.clear();
    lastNameController.clear();
    phoneController.clear();
    emailController.clear();
    countryCode = "";
  }

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(3),
        3: FlexColumnWidth(3),
      },
      children: [
        TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8),
              child: TextField(
                controller: firstNameController,
                decoration: InputDecoration(
                  hintStyle: const TextStyle(color: Colors.grey),
                  hintText: 'First name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextField(
                controller: lastNameController,
                decoration: InputDecoration(
                  hintStyle: const TextStyle(color: Colors.grey),
                  hintText: 'Last name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8),
              child: IntlPhoneField(
                controller: phoneController,
                initialCountryCode: 'US',
                onChanged: (phone) {
                  countryCode = phone.countryCode;
                },
                decoration: InputDecoration(
                  hintText: 'Phone Number',
                  hintStyle: const TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8),
              child: TextField(
                controller: emailController,
                decoration: InputDecoration(
                  hintStyle: const TextStyle(color: Colors.grey),
                  hintText: 'Email',
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(
                      color: Colors.grey, // Set the color of the border
                      width:
                          0.0, // Set the width of the border (make it smaller)
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Function to show the bottom sheet
void _showAddUsersBottomSheet(BuildContext context) {
  showModalBottomSheet(
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
