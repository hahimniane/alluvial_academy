import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';

class AddUsersScreen extends StatefulWidget {
  const AddUsersScreen({super.key});

  @override
  _AddUsersScreenState createState() => _AddUsersScreenState();
}

class _AddUsersScreenState extends State<AddUsersScreen> {
  List<int> userRows = [0]; // Start with one row
  final Map<int, UserInputRow> userRowsWidgets = {};
  final Map<int, GlobalKey<_UserInputRowState>> rowKeys = {};

  // Generate unique kiosk code
  String _generateKioskCode(
      String firstName, String lastName, String userType) {
    // Strategy 1: Use initials + user type + random number + timestamp
    final initials =
        '${firstName.isNotEmpty ? firstName[0].toUpperCase() : 'X'}${lastName.isNotEmpty ? lastName[0].toUpperCase() : 'X'}';
    final typeCode = _getUserTypeCode(userType);
    final random = Random().nextInt(999).toString().padLeft(3, '0');
    final timestamp = DateTime.now()
        .millisecondsSinceEpoch
        .toString()
        .substring(8); // Last 5 digits

    return '$initials$typeCode$random$timestamp';
  }

  String _getUserTypeCode(String userType) {
    switch (userType.toLowerCase()) {
      case 'admin':
        return 'AD';
      case 'teacher':
        return 'TC';
      case 'student':
        return 'ST';
      case 'parent':
        return 'PR';
      default:
        return 'US';
    }
  }

  // Check if kiosk code already exists in Firestore
  Future<bool> _isKioskCodeUnique(String kioskCode) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('kiosk_code', isEqualTo: kioskCode)
          .limit(1)
          .get();

      return querySnapshot.docs.isEmpty;
    } catch (e) {
      print('Error checking kiosk code uniqueness: $e');
      return false;
    }
  }

  // Generate a guaranteed unique kiosk code
  Future<String> _generateUniqueKioskCode(
      String firstName, String lastName, String userType) async {
    String kioskCode;
    bool isUnique = false;
    int attempts = 0;

    do {
      kioskCode = _generateKioskCode(firstName, lastName, userType);
      isUnique = await _isKioskCodeUnique(kioskCode);
      attempts++;

      // If we've tried 10 times, use a more unique approach
      if (attempts >= 10) {
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        kioskCode = '${_getUserTypeCode(userType)}$timestamp';
        isUnique = await _isKioskCodeUnique(kioskCode);
      }
    } while (!isUnique && attempts < 20);

    return kioskCode;
  }

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

  bool _isLoading = false;

  Future<void> _handleContinue() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    print('Handle continue called');
    List<Map<String, dynamic>> usersData = [];
    bool allValid = true;

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

        // Check validation based on user type
        bool emailRequired = true;
        bool guardianRequired = false;
        
        if (rowState.selectedUserType == 'Student') {
          // For students: email is required only for adults
          emailRequired = rowState.isAdultStudent;
          // For minor students: guardian is required
          guardianRequired = !rowState.isAdultStudent;
        }
        
        // Check if all required fields are populated
        bool missingRequiredFields = rowState.firstNameController.text.isEmpty ||
            rowState.lastNameController.text.isEmpty ||
            rowState.kioskCodeController.text.isEmpty ||
            (emailRequired && rowState.emailController.text.isEmpty) ||
            (guardianRequired && (rowState.selectedGuardianId == null || rowState.availableGuardians.isEmpty));
            
        if (missingRequiredFields) {
          print('Row $index is incomplete');
          allValid = false;
          setState(() {
            _isLoading = false;
          });
          String errorMessage = 'Missing required fields in row ${index + 1}: ';
          List<String> missingFields = [];
          
          if (rowState.firstNameController.text.isEmpty) missingFields.add('First name');
          if (rowState.lastNameController.text.isEmpty) missingFields.add('Last name');
          if (rowState.kioskCodeController.text.isEmpty) missingFields.add('Kiosk code');
          if (emailRequired && rowState.emailController.text.isEmpty) missingFields.add('Email');
          if (guardianRequired && (rowState.selectedGuardianId == null || rowState.availableGuardians.isEmpty)) {
            missingFields.add(rowState.availableGuardians.isEmpty ? 'Parent (none available - create parent first)' : 'Parent selection');
          }
          
          errorMessage += missingFields.join(', ');
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xffF56565),
              content: Text(
                errorMessage,
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
        final fullPhoneNumber = rowState.phoneController.text.trim().isNotEmpty
            ? "${rowState.countryCode}${rowState.phoneController.text.trim()}"
            : "";

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

        // Parse hourly rate, default to 15.0 if invalid
        double hourlyRate = 15.0;
        try {
          hourlyRate = double.parse(rowState.hourlyRateController.text.trim());
        } catch (e) {
          hourlyRate = 15.0; // Default rate
        }

        Map<String, dynamic> userData = {
          'first_name': rowState.firstNameController.text.trim(),
          'last_name': rowState.lastNameController.text.trim(),
          'phone_number': fullPhoneNumber,
          'e-mail': rowState.emailController.text.trim().toLowerCase(),
          'country_code': rowState.countryCode,
          'user_type': rowState.selectedUserType.toLowerCase(),
          'title': title,
          'employment_start_date': Timestamp.fromDate(DateTime.now()),
          'kiosk_code': rowState.kioskCodeController.text.trim(),
          'hourly_rate': hourlyRate,
          'date_added': FieldValue.serverTimestamp(),
          'last_login': null,
          'is_active': true,
        };
        
        // Add student-specific fields
        if (rowState.selectedUserType == 'Student') {
          userData['is_adult_student'] = rowState.isAdultStudent;
          if (!rowState.isAdultStudent && rowState.selectedGuardianId != null) {
            userData['guardian_id'] = rowState.selectedGuardianId;
          }
        }
        
        usersData.add(userData);
      } else {
        print('Row $index has no fields populated');
      }
    }

    print('\nFinal validation:');
    print('All valid: $allValid');
    print('Users data length: ${usersData.length}');

    if (usersData.isEmpty) {
      print('No users data to save');
      setState(() {
        _isLoading = false;
      });
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

    // Check for duplicate kiosk codes within the current batch
    Set<String> kioskCodes = {};
    for (var userData in usersData) {
      String kioskCode = userData['kiosk_code'];
      if (kioskCodes.contains(kioskCode)) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Duplicate kiosk code found: $kioskCode. Please ensure all kiosk codes are unique.',
              style: GoogleFonts.openSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xffF56565),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }
      kioskCodes.add(kioskCode);
    }

    // Check for existing kiosk codes in Firestore
    for (String kioskCode in kioskCodes) {
      bool isUnique = await _isKioskCodeUnique(kioskCode);
      if (!isUnique) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Kiosk code $kioskCode already exists. Please use a different code.',
              style: GoogleFonts.openSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xffF56565),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }
    }

    // Create users using Firebase Functions
    try {
      print('Calling Firebase Function to create users...');
      print('Users data to create: ${usersData.length}');

      // Transform data to match Firebase Functions expected format
      List<Map<String, dynamic>> transformedUsers = usersData.map((userData) {
        return {
          'email': userData['e-mail'],
          'firstName': userData['first_name'],
          'lastName': userData['last_name'],
          'phoneNumber': userData['phone_number'],
          'countryCode': userData['country_code'],
          'userType': userData['user_type'],
          'title': userData['title'],
          'kioskCode': userData['kiosk_code'],
        };
      }).toList();

      print('Transformed user data: ${transformedUsers.length} users');
      for (int i = 0; i < transformedUsers.length; i++) {
        print('User ${i + 1}: ${transformedUsers[i]}');
      }

      // Call Firebase Function based on user type and number of users
      if (transformedUsers.length == 1) {
        final functions = FirebaseFunctions.instance;
        final userData = transformedUsers.first;
        
        // Check if this is a student creation
        if (userData['userType'] == 'student') {
          // Use createStudentAccount function for students
          final callable = functions.httpsCallable('createStudentAccount');
          
          Map<String, dynamic> studentData = {
            'firstName': userData['firstName'],
            'lastName': userData['lastName'],
            'phoneNumber': userData['phoneNumber'],
            'isAdultStudent': usersData.first['is_adult_student'] ?? false,
          };
          
          // Add email only if provided (for adult students)
          if (userData['email'].isNotEmpty) {
            studentData['email'] = userData['email'];
          }
          
          // Add guardian ID for minor students
          if (usersData.first['guardian_id'] != null) {
            studentData['guardianIds'] = [usersData.first['guardian_id']];
          }
          
          final result = await callable.call(studentData);
          print('Student creation result: ${result.data}');
        } else {
          // Use createUserWithEmail function for regular users
          final callable = functions.httpsCallable('createUserWithEmail');
          final result = await callable.call(userData);
          print('Regular user creation result: ${result.data}');
        }

        // Send welcome email (only if email is provided)
        if (userData['email'].isNotEmpty) {
          try {
            final welcomeCallable = functions.httpsCallable('sendWelcomeEmail');
            final user = transformedUsers.first;
            await welcomeCallable.call({
              'email': user['email'],
              'firstName': user['firstName'],
              'lastName': user['lastName'],
              'role': user['userType'],
            });
            print('Welcome email sent successfully');
          } catch (emailError) {
            print('Failed to send welcome email: $emailError');
            // Don't fail the entire operation if email fails
          }
        }
      } else {
        // Use createMultipleUsers function for multiple users
        final functions = FirebaseFunctions.instance;
        final callable = functions.httpsCallable('createMultipleUsers');

        final result = await callable.call({
          'users': transformedUsers,
        });

        print('Multiple users creation result: ${result.data}');

        // Send welcome emails to all users
        try {
          final welcomeCallable = functions.httpsCallable('sendWelcomeEmail');
          for (final user in transformedUsers) {
            try {
              await welcomeCallable.call({
                'email':
                    user['e-mail'], // Use correct field name from Firestore
                'firstName': user['first_name'],
                'lastName': user['last_name'],
                'role': user['user_type'], // Use correct field name
              });
              print('Welcome email sent to ${user['e-mail']}');
            } catch (emailError) {
              print(
                  'Failed to send welcome email to ${user['e-mail']}: $emailError');
            }
          }
        } catch (e) {
          print('Failed to send welcome emails: $e');
        }
      }

      // Show detailed success message
      String successMessage;
      if (transformedUsers.length == 1) {
        final userData = transformedUsers.first;
        if (userData['userType'] == 'student') {
          bool isAdult = usersData.first['is_adult_student'] ?? false;
          if (isAdult) {
            successMessage = '✅ Adult Student created successfully!\n'
                '• Student ID login account created\n'
                '• Profile saved to database\n'
                '• Welcome email sent with login credentials';
          } else {
            successMessage = '✅ Minor Student created successfully!\n'
                '• Student ID login account created\n'
                '• Profile saved and linked to guardian\n'
                '• No email required for minor students';
          }
        } else {
          successMessage = '✅ User created successfully!\n'
              '• Firebase Auth account created\n'
              '• User profile saved to database\n'
              '• Welcome email sent with login credentials';
        }
      } else {
        successMessage =
            '✅ ${transformedUsers.length} users created successfully!\n'
            '• Firebase Auth accounts created\n'
            '• User profiles saved to database\n'
            '• Welcome emails sent with login credentials';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            successMessage,
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
          duration: const Duration(seconds: 5),
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
      print("Error creating users: $e");

      String errorMessage = 'Error creating users: ';
      if (e is FirebaseFunctionsException) {
        errorMessage += e.message ?? e.code;
        print('Firebase Functions Error Code: ${e.code}');
        print('Firebase Functions Error Message: ${e.message}');
        print('Firebase Functions Error Details: ${e.details}');
      } else {
        errorMessage += e.toString();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage,
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
    } finally {
      setState(() {
        _isLoading = false;
      });
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
                          'Users will receive login credentials via email. Phone number is optional.',
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
                            flex: 2,
                            child: Text(
                              'Kiosk Code*',
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
                              'Mobile Phone',
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
                  onPressed: _isLoading ? null : _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isLoading
                        ? const Color(0xffA0AEC0)
                        : const Color(0xff0386FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Creating...',
                              style: GoogleFonts.openSans(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        )
                      : Text(
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
  final TextEditingController kioskCodeController = TextEditingController();
  final TextEditingController hourlyRateController =
      TextEditingController(text: '15.00');
  String countryCode = "1";
  String selectedUserType = "Admin"; // Default to Admin

  final List<String> userTypes = ["Admin", "Teacher", "Student", "Parent"];
  
  // Student-specific fields
  bool isAdultStudent = false;
  String? selectedGuardianId;
  List<Map<String, dynamic>> availableGuardians = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableGuardians();
  }

  // Load available guardians (parents) from Firestore
  Future<void> _loadAvailableGuardians() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('user_type', isEqualTo: 'parent')
          .where('is_active', isEqualTo: true)
          .get();

      if (mounted) {
        setState(() {
          availableGuardians = querySnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim(),
              'email': data['e-mail'] ?? '',
            };
          }).toList();
        });
      }
    } catch (e) {
      print('Error loading guardians: $e');
    }
  }

  // Helper methods for guardian display
  String _getGuardianName(String guardianId) {
    final guardian = availableGuardians.firstWhere(
      (g) => g['id'] == guardianId,
      orElse: () => {'name': 'Unknown Parent'},
    );
    return guardian['name'] ?? 'Unknown Parent';
  }

  String _getGuardianEmail(String guardianId) {
    final guardian = availableGuardians.firstWhere(
      (g) => g['id'] == guardianId,
      orElse: () => {'email': ''},
    );
    return guardian['email'] ?? '';
  }

  // Show parent selection dialog
  void _showParentSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => ParentSelectionDialog(
        availableParents: availableGuardians,
        selectedParentId: selectedGuardianId,
        onParentSelected: (parentId) {
          setState(() {
            selectedGuardianId = parentId;
          });
        },
      ),
    );
  }

  // Auto-generate kiosk code when name or user type changes
  void _generateKioskCode() {
    if (firstNameController.text.isNotEmpty &&
        lastNameController.text.isNotEmpty) {
      final initials =
          '${firstNameController.text[0].toUpperCase()}${lastNameController.text[0].toUpperCase()}';
      final typeCode = _getUserTypeCode(selectedUserType);
      final random = Random().nextInt(999).toString().padLeft(3, '0');
      final timestamp =
          DateTime.now().millisecondsSinceEpoch.toString().substring(8, 13);

      kioskCodeController.text = '$initials$typeCode$random$timestamp';
    }
  }

  String _getUserTypeCode(String userType) {
    switch (userType.toLowerCase()) {
      case 'admin':
        return 'AD';
      case 'teacher':
        return 'TC';
      case 'student':
        return 'ST';
      case 'parent':
        return 'PR';
      default:
        return 'US';
    }
  }

  bool isAnyFieldPopulated() {
    return firstNameController.text.isNotEmpty ||
        lastNameController.text.isNotEmpty ||
        phoneController.text.isNotEmpty ||
        emailController.text.isNotEmpty ||
        kioskCodeController.text.isNotEmpty ||
        hourlyRateController.text.isNotEmpty;
  }

  bool areAllFieldsPopulated() {
    return firstNameController.text.isNotEmpty &&
        lastNameController.text.isNotEmpty &&
        emailController.text.isNotEmpty &&
        kioskCodeController.text.isNotEmpty &&
        hourlyRateController.text.isNotEmpty;
  }

  void clearFields() {
    firstNameController.clear();
    lastNameController.clear();
    phoneController.clear();
    emailController.clear();
    kioskCodeController.clear();
    hourlyRateController.text = '15.00';
    countryCode = "1";
    selectedUserType = "Admin";
    isAdultStudent = false;
    selectedGuardianId = null;
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
              onChanged: (value) {
                setState(() {});
                _generateKioskCode();
              },
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
              onChanged: (value) {
                setState(() {});
                _generateKioskCode();
              },
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
            child: DropdownButtonFormField<String>(
              value: selectedUserType,
              decoration: InputDecoration(
                hintText: 'User Type',
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
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
              items: userTypes.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Row(
                    children: [
                      Icon(
                        _getIconForUserType(value),
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
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    selectedUserType = newValue;
                    _generateKioskCode();
                    
                    // Reset student-specific fields when changing away from Student
                    if (newValue != 'Student') {
                      isAdultStudent = false;
                      selectedGuardianId = null;
                    }
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 16),

          // Kiosk Code
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: kioskCodeController,
              onChanged: (value) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Auto-generated',
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
                suffixIcon: IconButton(
                  icon: const Icon(
                    Icons.refresh,
                    color: Color(0xff0386FF),
                    size: 18,
                  ),
                  onPressed: _generateKioskCode,
                  tooltip: 'Regenerate Code',
                ),
              ),
              style: GoogleFonts.openSans(
                fontSize: 14,
                color: const Color(0xff2D3748),
                fontWeight: FontWeight.w600,
              ),
              readOnly: true, // Make kiosk code non-editable
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
                hintText: 'Phone Number (Optional)',
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
                hintText: selectedUserType == 'Student' && !isAdultStudent 
                    ? 'Email (Optional for minors)' 
                    : 'Email address',
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
          const SizedBox(width: 16),

          // Student-specific fields
          if (selectedUserType == 'Student') ...[
            // Adult/Minor Toggle
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xffF7FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xffE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student Type',
                      style: GoogleFonts.openSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff2D3748),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => isAdultStudent = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              decoration: BoxDecoration(
                                color: isAdultStudent ? const Color(0xff0386FF) : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isAdultStudent ? const Color(0xff0386FF) : const Color(0xffE2E8F0),
                                ),
                              ),
                              child: Text(
                                'Adult',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.openSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isAdultStudent ? Colors.white : const Color(0xff718096),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => isAdultStudent = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              decoration: BoxDecoration(
                                color: !isAdultStudent ? const Color(0xff0386FF) : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: !isAdultStudent ? const Color(0xff0386FF) : const Color(0xffE2E8F0),
                                ),
                              ),
                              child: Text(
                                'Minor',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.openSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: !isAdultStudent ? Colors.white : const Color(0xff718096),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Guardian Selection (only for minors)
            if (!isAdultStudent)
              Expanded(
                flex: 3,
                child: availableGuardians.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xffFED7D7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xffFC8181)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Color(0xffE53E3E),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'No Parents Found',
                                    style: GoogleFonts.openSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xffE53E3E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Create parent first',
                              style: GoogleFonts.openSans(
                                fontSize: 11,
                                color: const Color(0xffE53E3E),
                              ),
                            ),
                          ],
                        ),
                      )
                    : GestureDetector(
                        onTap: () => _showParentSelectionDialog(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xffF7FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xffE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      selectedGuardianId != null
                                          ? _getGuardianName(selectedGuardianId!)
                                          : 'Select Parent/Guardian*',
                                      style: GoogleFonts.openSans(
                                        fontSize: 14,
                                        color: selectedGuardianId != null
                                            ? const Color(0xff2D3748)
                                            : const Color(0xff718096),
                                        fontWeight: selectedGuardianId != null
                                            ? FontWeight.w500
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    if (selectedGuardianId != null)
                                      Text(
                                        _getGuardianEmail(selectedGuardianId!),
                                        style: GoogleFonts.openSans(
                                          fontSize: 12,
                                          color: const Color(0xff718096),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.search,
                                color: Color(0xff718096),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            const SizedBox(width: 16),
          ],

          // Hourly Rate (only for Teachers and Admins)
          if (selectedUserType == 'Teacher' || selectedUserType == 'Admin')
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: hourlyRateController,
                onChanged: (value) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Hourly Rate',
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
                    Icons.attach_money,
                    color: Color(0xffA0AEC0),
                    size: 20,
                  ),
                ),
                style: GoogleFonts.openSans(
                  fontSize: 14,
                  color: const Color(0xff2D3748),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getIconForUserType(String userType) {
    switch (userType) {
      case 'Admin':
        return Icons.admin_panel_settings;
      case 'Teacher':
        return Icons.school;
      case 'Student':
        return Icons.person;
      case 'Parent':
        return Icons.family_restroom;
      default:
        return Icons.person_outline;
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    kioskCodeController.dispose();
    hourlyRateController.dispose();
    super.dispose();
  }
}

// Parent Selection Dialog Component
class ParentSelectionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> availableParents;
  final String? selectedParentId;
  final Function(String?) onParentSelected;

  const ParentSelectionDialog({
    super.key,
    required this.availableParents,
    required this.selectedParentId,
    required this.onParentSelected,
  });

  @override
  State<ParentSelectionDialog> createState() => _ParentSelectionDialogState();
}

class _ParentSelectionDialogState extends State<ParentSelectionDialog> {
  final _searchController = TextEditingController();
  String _searchTerm = '';
  String? _tempSelectedParentId;

  @override
  void initState() {
    super.initState();
    _tempSelectedParentId = widget.selectedParentId;
  }

  List<Map<String, dynamic>> get _filteredParents {
    if (_searchTerm.isEmpty) return widget.availableParents;
    final term = _searchTerm.toLowerCase();
    return widget.availableParents.where((parent) {
      final name = parent['name'].toString().toLowerCase();
      final email = parent['email'].toString().toLowerCase();
      return name.contains(term) || email.contains(term);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xff0386FF),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Parent/Guardian',
                          style: GoogleFonts.openSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Choose a parent for this minor student',
                          style: GoogleFonts.openSans(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.all(24),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search parents by name or email...',
                  hintStyle: GoogleFonts.openSans(
                    color: const Color(0xffA0AEC0),
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xff718096),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xffE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xffE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xff0386FF), width: 2),
                  ),
                  filled: true,
                  fillColor: const Color(0xffF7FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchTerm = value;
                  });
                },
              ),
            ),
            // Parent List
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                child: _filteredParents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchTerm.isNotEmpty ? Icons.search_off : Icons.family_restroom,
                              size: 48,
                              color: const Color(0xff718096),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchTerm.isNotEmpty
                                  ? 'No parents found matching "$_searchTerm"'
                                  : 'No parents available',
                              style: GoogleFonts.openSans(
                                fontSize: 16,
                                color: const Color(0xff718096),
                              ),
                            ),
                            if (_searchTerm.isEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Create a parent account first',
                                style: GoogleFonts.openSans(
                                  fontSize: 14,
                                  color: const Color(0xff718096),
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredParents.length,
                        itemBuilder: (context, index) {
                          final parent = _filteredParents[index];
                          final isSelected = _tempSelectedParentId == parent['id'];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  setState(() {
                                    _tempSelectedParentId = parent['id'];
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xff0386FF)
                                          : const Color(0xffE2E8F0),
                                      width: isSelected ? 2 : 1,
                                    ),
                                    color: isSelected
                                        ? const Color(0xff0386FF).withOpacity(0.05)
                                        : Colors.white,
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: const Color(0xff0386FF).withOpacity(0.1),
                                        child: Text(
                                          parent['name'].isNotEmpty
                                              ? parent['name'][0].toUpperCase()
                                              : 'P',
                                          style: GoogleFonts.openSans(
                                            color: const Color(0xff0386FF),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              parent['name'],
                                              style: GoogleFonts.openSans(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xff2D3748),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              parent['email'],
                                              style: GoogleFonts.openSans(
                                                fontSize: 14,
                                                color: const Color(0xff718096),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_circle,
                                          color: Color(0xff0386FF),
                                          size: 24,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xffE2E8F0)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.openSans(
                        fontSize: 14,
                        color: const Color(0xff6B7280),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _tempSelectedParentId != null
                        ? () {
                            widget.onParentSelected(_tempSelectedParentId);
                            Navigator.of(context).pop();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff0386FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Select',
                      style: GoogleFonts.openSans(
                        fontSize: 14,
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
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
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
