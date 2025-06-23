import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_fonts/google_fonts.dart';

class AddUsersScreen extends StatefulWidget {
  const AddUsersScreen({super.key});

  @override
  _AddUsersScreenState createState() => _AddUsersScreenState();
}

class _AddUsersScreenState extends State<AddUsersScreen> {
  List<int> userRows = [0]; // Start with one row
  final Map<int, UserInputRow> userRowsWidgets = {};
  final Map<int, GlobalKey<_UserInputRowState>> rowKeys = {};

  void _addUserRow() {
    setState(() {
      final newIndex = userRows.length;
      userRows.add(newIndex);
      rowKeys[newIndex] = GlobalKey<_UserInputRowState>();
    });
  }

  void _removeUserRow(int index) {
    setState(() {
      userRows.removeAt(index);
      userRowsWidgets.remove(index);
      rowKeys.remove(index);
    });
  }

  void _handleContinue() async {
    print('Starting _handleContinue');
    print('Number of rows: ${userRows.length}');
    print('Number of widgets: ${userRowsWidgets.length}');
    print('Number of keys: ${rowKeys.length}');

    bool allValid = true;
    List<Map<String, dynamic>> usersData = [];

    for (var index in userRows) {
      print('\nChecking row $index');
      final key = rowKeys[index];
      if (key == null) {
        print('Key for row $index is null');
        continue;
      }

      final rowState = key.currentState;
      if (rowState == null) {
        print('Row state for row $index is null');
        continue;
      }

      print('Row $index field values:');
      print('First Name: "${rowState.firstNameController.text}"');
      print('Last Name: "${rowState.lastNameController.text}"');
      print('Phone: "${rowState.phoneController.text}"');
      print('Email: "${rowState.emailController.text}"');
      print('Country Code: "${rowState.countryCode}"');
      print('User Type: "${rowState.selectedUserType}"');

      // Check if any field is populated
      if (rowState.firstNameController.text.isNotEmpty ||
          rowState.lastNameController.text.isNotEmpty ||
          rowState.phoneController.text.isNotEmpty ||
          rowState.emailController.text.isNotEmpty) {
        print('Row $index has some fields populated');

        // Check if all required fields are populated
        if (rowState.firstNameController.text.isEmpty ||
            rowState.lastNameController.text.isEmpty ||
            rowState.phoneController.text.isEmpty ||
            rowState.emailController.text.isEmpty) {
          print('Row $index is incomplete');
          allValid = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xffF56565),
              content: Text(
                'All fields in row ${index + 1} must be filled',
                style: GoogleFonts.openSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          return;
        }

        print('Row $index is complete, adding to usersData');
        final fullPhoneNumber =
            "${rowState.countryCode}${rowState.phoneController.text.trim()}";

        // Map user type to title (user type and title should be the same)
        String title = rowState.selectedUserType;
        switch (rowState.selectedUserType) {
          case 'Admin':
            title = 'Admin';
            break;
          case 'Teacher':
            title = 'Teacher';
            break;
          case 'Student':
            title = 'Student';
            break;
          case 'Parent':
            title = 'Parent';
            break;
          default:
            title = 'Teacher';
        }

        usersData.add({
          'first_name': rowState.firstNameController.text.trim(),
          'last_name': rowState.lastNameController.text.trim(),
          'phone_number': fullPhoneNumber,
          'e-mail': rowState.emailController.text.trim().toLowerCase(),
          'country_code': rowState.countryCode,
          'user_type': rowState.selectedUserType.toLowerCase(),
          'title': title,
          'employment_start_date': Timestamp.fromDate(DateTime.now()),
          'kiosk_code': "123",
          'date_added': FieldValue.serverTimestamp(),
          'last_login': FieldValue.serverTimestamp(),
          'is_active': true,
        });
      } else {
        print('Row $index has no fields populated');
      }
    }

    print('\nFinal validation:');
    print('All valid: $allValid');
    print('Users data length: ${usersData.length}');

    if (usersData.isEmpty) {
      print('No users data to save');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No complete rows to save',
            style: GoogleFonts.openSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xffED8936),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    // Save users to Firestore
    try {
      final batch = FirebaseFirestore.instance.batch();

      for (var userData in usersData) {
        // Create a new document reference with auto-generated ID
        final userRef = FirebaseFirestore.instance.collection('users').doc();
        batch.set(userRef, userData);
      }

      // Commit the batch
      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Users saved successfully!',
            style: GoogleFonts.openSans(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: const Color(0xff00d084),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      // Clear form fields
      setState(() {
        for (var row in userRowsWidgets.values) {
          row.clearFields();
        }
      });

      Navigator.pop(context);
    } catch (e) {
      print("Error saving users: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error saving users: $e',
            style: GoogleFonts.openSans(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: const Color(0xffF56565),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // Initialize keys for initial rows
    for (var index in userRows) {
      rowKeys[index] = GlobalKey<_UserInputRowState>();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7FAFC),
      body: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Color(0xffE2E8F0),
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xff0386FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_add,
                        color: Color(0xff0386FF),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add New Users',
                            style: GoogleFonts.openSans(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xff0B3858),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Create user accounts and assign roles for your organization',
                            style: GoogleFonts.openSans(
                              fontSize: 16,
                              color: const Color(0xff718096),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        // Handle "Learn more"
                      },
                      icon: const Icon(
                        Icons.help_outline,
                        size: 20,
                        color: Color(0xff0386FF),
                      ),
                      label: Text(
                        'Learn more',
                        style: GoogleFonts.openSans(
                          color: const Color(0xff0386FF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xff0386FF).withOpacity(0.05),
                    border: Border.all(
                      color: const Color(0xff0386FF).withOpacity(0.2),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Color(0xff0386FF),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Users will log in using their mobile phone number and receive login credentials via email',
                          style: GoogleFonts.openSans(
                            fontSize: 14,
                            color: const Color(0xff0B3858),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content Section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      spreadRadius: 0,
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 20),
                      decoration: const BoxDecoration(
                        color: Color(0xffF7FAFC),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: Color(0xffE2E8F0),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              'First Name*',
                              style: GoogleFonts.openSans(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xff0B3858),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Last Name*',
                              style: GoogleFonts.openSans(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xff0B3858),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'User Type*',
                              style: GoogleFonts.openSans(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xff0B3858),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Mobile Phone*',
                              style: GoogleFonts.openSans(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xff0B3858),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Email Address*',
                              style: GoogleFonts.openSans(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xff0B3858),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 50),
                        ],
                      ),
                    ),

                    // User Input Rows
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(0),
                        itemCount: userRows.length,
                        itemBuilder: (context, index) {
                          final rowIndex = userRows[index];
                          // Only create a new UserInputRow if it doesn't exist
                          if (!userRowsWidgets.containsKey(rowIndex)) {
                            userRowsWidgets[rowIndex] = UserInputRow(
                              key: rowKeys[rowIndex],
                              index: rowIndex,
                              onDelete: () => _removeUserRow(rowIndex),
                            );
                          }
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color:
                                      const Color(0xffE2E8F0).withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(child: userRowsWidgets[rowIndex]!),
                                SizedBox(
                                  width: 50,
                                  child: IconButton(
                                    onPressed: userRows.length > 1
                                        ? () => _removeUserRow(rowIndex)
                                        : null,
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: userRows.length > 1
                                          ? const Color(0xffF56565)
                                          : const Color(0xffCBD5E0),
                                      size: 20,
                                    ),
                                    tooltip: userRows.length > 1
                                        ? 'Remove user'
                                        : 'Cannot remove last user',
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Add User Button
                    Container(
                      padding: const EdgeInsets.all(32),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _addUserRow,
                          icon: const Icon(
                            Icons.add,
                            color: Color(0xff0386FF),
                            size: 20,
                          ),
                          label: Text(
                            'Add another user',
                            style: GoogleFonts.openSans(
                              color: const Color(0xff0386FF),
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor:
                                const Color(0xff0386FF).withOpacity(0.05),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Footer Buttons
          Container(
            padding: const EdgeInsets.all(32),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: Color(0xffE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.openSans(
                      color: const Color(0xff718096),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff0386FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Create Users',
                    style: GoogleFonts.openSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class UserInputRow extends StatefulWidget {
  final int index;
  final VoidCallback onDelete;

  const UserInputRow({
    super.key,
    required this.index,
    required this.onDelete,
  });

  void clearFields() {
    (key as GlobalKey<_UserInputRowState>).currentState?.clearFields();
  }

  @override
  State<UserInputRow> createState() => _UserInputRowState();
}

class _UserInputRowState extends State<UserInputRow> {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  String countryCode = "1";
  String selectedUserType = "Admin"; // Default to Admin

  final List<String> userTypes = ["Admin", "Teacher", "Student", "Parent"];

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
        emailController.text.isNotEmpty &&
        countryCode.isNotEmpty;
  }

  void clearFields() {
    firstNameController.clear();
    lastNameController.clear();
    phoneController.clear();
    emailController.clear();
    countryCode = "1";
    selectedUserType = "Admin";
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          // First Name
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: firstNameController,
              onChanged: (value) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'First name',
                hintStyle: GoogleFonts.openSans(
                  color: const Color(0xffA0AEC0),
                  fontSize: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xffE2E8F0),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xffE2E8F0),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xff0386FF),
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: const Color(0xffF7FAFC),
                hoverColor: Colors.transparent,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: GoogleFonts.openSans(
                fontSize: 14,
                color: const Color(0xff2D3748),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Last Name
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: lastNameController,
              onChanged: (value) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Last name',
                hintStyle: GoogleFonts.openSans(
                  color: const Color(0xffA0AEC0),
                  fontSize: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xffE2E8F0),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xffE2E8F0),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xff0386FF),
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: const Color(0xffF7FAFC),
                hoverColor: Colors.transparent,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: GoogleFonts.openSans(
                fontSize: 14,
                color: const Color(0xff2D3748),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // User Type Dropdown
          Expanded(
            flex: 2,
            child: Theme(
              data: Theme.of(context).copyWith(
                popupMenuTheme: PopupMenuThemeData(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(
                      color: Color(0xffE2E8F0),
                      width: 1,
                    ),
                  ),
                  elevation: 8,
                  shadowColor: Colors.black.withOpacity(0.1),
                ),
                canvasColor: Colors.white,
              ),
              child: DropdownButtonFormField<String>(
                value: selectedUserType,
                onChanged: (String? newValue) {
                  setState(() {
                    selectedUserType = newValue!;
                  });
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xffE2E8F0),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xffE2E8F0),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xff0386FF),
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: const Color(0xffF7FAFC),
                  hoverColor: Colors.transparent,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                items: userTypes.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            value == 'Teacher'
                                ? Icons.school
                                : value == 'Student'
                                    ? Icons.person
                                    : Icons.admin_panel_settings,
                            size: 16,
                            color: const Color(0xff0386FF),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            value,
                            style: GoogleFonts.openSans(
                              fontSize: 14,
                              color: const Color(0xff2D3748),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                style: GoogleFonts.openSans(
                  fontSize: 14,
                  color: const Color(0xff2D3748),
                ),
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Color(0xff718096),
                ),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(12),
                menuMaxHeight: 200,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Phone Number
          Expanded(
            flex: 3,
            child: IntlPhoneField(
              controller: phoneController,
              initialCountryCode: 'US',
              onChanged: (phone) {
                setState(() {
                  countryCode = phone.countryCode;
                });
              },
              decoration: InputDecoration(
                hintText: 'Phone Number',
                hintStyle: GoogleFonts.openSans(
                  color: const Color(0xffA0AEC0),
                  fontSize: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xffE2E8F0),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xffE2E8F0),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xff0386FF),
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: const Color(0xffF7FAFC),
                hoverColor: Colors.transparent,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: GoogleFonts.openSans(
                fontSize: 14,
                color: const Color(0xff2D3748),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Email
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: emailController,
              onChanged: (value) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Email address',
                hintStyle: GoogleFonts.openSans(
                  color: const Color(0xffA0AEC0),
                  fontSize: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xffE2E8F0),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xffE2E8F0),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xff0386FF),
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: const Color(0xffF7FAFC),
                hoverColor: Colors.transparent,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                prefixIcon: const Icon(
                  Icons.email_outlined,
                  color: Color(0xffA0AEC0),
                  size: 20,
                ),
              ),
              style: GoogleFonts.openSans(
                fontSize: 14,
                color: const Color(0xff2D3748),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    super.dispose();
  }
}

// BottomSheet function with improved styling
void _showAddUsersBottomSheet(BuildContext context) {
  showModalBottomSheet(
    backgroundColor: Colors.transparent,
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.95,
        decoration: const BoxDecoration(
          color: Color(0xffF7FAFC),
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
