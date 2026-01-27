import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/core/widgets/performance_log_viewer.dart';
import 'package:alluwalacademyadmin/core/widgets/performance_summary_dashboard.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class FirestoreDebugScreen extends StatefulWidget {
  const FirestoreDebugScreen({super.key});

  @override
  State<FirestoreDebugScreen> createState() => _FirestoreDebugScreenState();
}

class _FirestoreDebugScreenState extends State<FirestoreDebugScreen> {
  List<Map<String, dynamic>> userDocuments = [];
  List<Map<String, dynamic>> capitalUserDocuments = [];
  bool isLoading = true;
  String? error;

  // Email test variables
  bool _isEmailTesting = false;
  String _emailTestResult = '';

  @override
  void initState() {
    super.initState();
    _checkFirestoreData();
  }

  Future<void> _checkFirestoreData() async {
    try {
      // Check lowercase 'users' collection
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();

      userDocuments = usersSnapshot.docs.map((doc) {
        final data = doc.data();
        data['docId'] = doc.id;
        return data;
      }).toList();

      // Check uppercase 'Users' collection
      try {
        final capitalUsersSnapshot =
            await FirebaseFirestore.instance.collection('Users').get();

        capitalUserDocuments = capitalUsersSnapshot.docs.map((doc) {
          final data = doc.data();
          data['docId'] = doc.id;
          return data;
        }).toList();
      } catch (e) {
        AppLogger.debug('No Users collection found: $e');
      }

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          isLoading = false;
        });
      }
    }
  }

  Future<void> _sendTestEmail() async {
    setState(() {
      _isEmailTesting = true;
      _emailTestResult = '';
    });

    try {
      if (kIsWeb) {
        // For web, use Cloud Functions (works across all platforms)
        final HttpsCallable callable =
            FirebaseFunctions.instance.httpsCallable('sendTestEmail');
        final result = await callable.call({
          'to': 'hassimiou.niane@maine.edu',
          'subject': 'Test Email from Alluwal Academy Debug (Web)',
          'message':
              'This test email was sent from the web version of Alluwal Academy.\n\nSent at: ${DateTime.now().toIso8601String()}'
        });

        setState(() {
          _emailTestResult = '''✅ Email Sent Successfully via Cloud Function!

From: support@alluwaleducationhub.org
To: hassimiou.niane@maine.edu
Subject: Test Email from Alluwal Academy Debug (Web)

Method: Firebase Cloud Function
Platform: Web Browser
Status: ${result.data}
Timestamp: ${DateTime.now().toIso8601String()}

✉️ Check your inbox at hassimiou.niane@maine.edu''';
        });
      } else {
        // For mobile/desktop, could use direct SMTP if needed
        setState(() {
          _emailTestResult = '''ℹ️ Platform: ${defaultTargetPlatform.name}

For mobile/desktop platforms, direct SMTP is supported.
Currently configured for web via Cloud Functions.

To test on mobile/desktop:
1. Deploy the app to a mobile device
2. Or use the Cloud Function approach (recommended)''';
        });
      }
    } catch (e) {
      setState(() {
        _emailTestResult = '''❌ Email sending failed: 

Error: $e

Troubleshooting:
${kIsWeb ? '''
🌐 Web Platform Detected:
- Direct SMTP not supported in browsers
- Using Cloud Functions instead
- Make sure sendTestEmail function is deployed

Solutions:
1. Deploy Cloud Functions: firebase deploy --only functions
2. Check Firebase Console for function logs
3. Verify function permissions
''' : '''
📱 Mobile/Desktop Platform:
- Direct SMTP should work
- Check internet connection
- Verify SMTP credentials
'''}''';
      });
    } finally {
      setState(() {
        _isEmailTesting = false;
      });
    }
  }

  /// Send test task assignment notification
  Future<void> _sendTestTaskNotification() async {
    setState(() {
      _isEmailTesting = true;
      _emailTestResult = '';
    });

    try {
      final HttpsCallable callable = FirebaseFunctions.instance
          .httpsCallable('sendTaskAssignmentNotification');
      final result = await callable.call({
        'taskId': 'test-task-123',
        'taskTitle': 'Test Task Assignment',
        'taskDescription':
            'This is a test task to verify the assignment notification system.',
        'dueDate':
            DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        'assignedUserIds': [
          'test-user-id'
        ], // This would normally be real user IDs
        'assignedByName': 'Debug System',
      });

      setState(() {
        _emailTestResult = '''✅ Task Assignment Notification Sent!

Test Data:
- Task: Test Task Assignment  
- Due: ${DateTime.now().add(const Duration(days: 7)).toLocal().toString().split('.')[0]}
- Assigned To: test-user-id
- Assigned By: Debug System

Function Result: ${result.data}
Status: Success''';
      });
    } catch (e) {
      setState(() {
        _emailTestResult = '''❌ Task Assignment Test Failed!
        
Error: $e

This helps us debug the data format issue.''';
      });
    } finally {
      setState(() {
        _isEmailTesting = false;
      });
    }
  }

  /// Send test welcome email notification
  Future<void> _sendTestWelcomeEmail() async {
    setState(() {
      _isEmailTesting = true;
      _emailTestResult = '';
    });

    try {
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('sendWelcomeEmail');
      final result = await callable.call({
        'email': 'hassimiou.niane@maine.edu',
        'firstName': 'Test',
        'lastName': 'User',
        'role': 'teacher',
      });

      setState(() {
        _emailTestResult = '''✅ Welcome Email Sent Successfully!

Test Data:
- To: hassimiou.niane@maine.edu
- Name: Test User
- Role: teacher
- Password: 123456

Function Result: ${result.data}
Status: Success''';
      });
    } catch (e) {
      setState(() {
        _emailTestResult = '''❌ Welcome Email Test Failed!
        
Error: $e

This helps us debug the welcome email system.''';
      });
    } finally {
      setState(() {
        _isEmailTesting = false;
      });
    }
  }

  /// Send test task status update notification
  Future<void> _sendTestStatusUpdate() async {
    setState(() {
      _isEmailTesting = true;
      _emailTestResult = '';
    });

    try {
      // Try to use a real user ID if we have users in the database
      String createdByUserId = 'test-creator-id'; // Default fallback

      // Check if we have any real users
      if (userDocuments.isNotEmpty) {
        // Use the first user as the task creator for testing
        createdByUserId = userDocuments.first['id'] ?? 'test-creator-id';
      }

      final HttpsCallable callable = FirebaseFunctions.instance
          .httpsCallable('sendTaskStatusUpdateNotification');
      final result = await callable.call({
        'taskId': 'test-task-status-123',
        'taskTitle': 'Test Status Update Task',
        'oldStatus': 'todo',
        'newStatus': 'completed',
        'updatedByName': 'Debug Tester',
        'createdBy': createdByUserId,
      });

      setState(() {
        _emailTestResult = '''✅ Status Update Email Sent!

Test Data:
- Task: Test Status Update Task
- Status: todo → completed  
- Updated By: Debug Tester
- Created By: $createdByUserId
- Notification sent to task creator

Function Result: ${result.data}
Status: Success''';
      });
    } catch (e) {
      setState(() {
        _emailTestResult = '''❌ Status Update Test Failed!
        
Error: $e

This helps us debug the status update notification system.''';
      });
    } finally {
      setState(() {
        _isEmailTesting = false;
      });
    }
  }

  /// Test updating last login time for current user
  Future<void> _testUpdateLastLogin() async {
    setState(() {
      _isEmailTesting = true;
      _emailTestResult = '';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _emailTestResult = '''❌ No User Logged In!
          
Please sign in first to test last login update.''';
        });
        return;
      }

      // Update last login time manually for testing
      final QuerySnapshot userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('e-mail', isEqualTo: user.email?.toLowerCase())
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final userDoc = userQuery.docs.first;
        await userDoc.reference.update({
          'last_login': FieldValue.serverTimestamp(),
        });

        setState(() {
          _emailTestResult = '''✅ Last Login Updated Successfully!

User: ${user.email}
Updated: last_login field set to current timestamp
Document ID: ${userDoc.id}

This user should now be removed from the "never logged in" category.
Check the User Management screen to verify.''';
        });
      } else {
        setState(() {
          _emailTestResult = '''❌ User Document Not Found!
          
User email: ${user.email}
The user document might not exist in Firestore.''';
        });
      }
    } catch (e) {
      setState(() {
        _emailTestResult = '''❌ Last Login Update Failed!
        
Error: $e

This helps us debug the login tracking system.''';
      });
    } finally {
      setState(() {
        _isEmailTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.debug,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xff0386FF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (mounted) {
                setState(() {
                  isLoading = true;
                  userDocuments.clear();
                  capitalUserDocuments.clear();
                });
                _checkFirestoreData();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PerformanceSummaryDashboard(),
            const SizedBox(height: 10),
            Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                childrenPadding: const EdgeInsets.only(top: 10),
                title: Text(
                  AppLocalizations.of(context)!.detailedPerformanceLogs,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff111827),
                  ),
                ),
                subtitle: Text(
                  AppLocalizations.of(context)!.onlyIfYouNeedTheRaw,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xff6B7280),
                  ),
                ),
                children: const [
                  PerformanceLogViewer(),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (error != null)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(AppLocalizations.of(context)!.errorError),
                  ],
                ),
              )
            else ...[
              // Email Test Section
              _buildEmailTestSection(),
              const SizedBox(height: 32),
              _buildCollectionSection(
                'users (lowercase)',
                userDocuments,
                Colors.blue,
              ),
              const SizedBox(height: 32),
              _buildCollectionSection(
                'Users (uppercase)',
                capitalUserDocuments,
                Colors.red,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmailTestSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.purple,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.emailTest,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Email credentials info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.emailSystemWebCompatible,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context)!.methodFirebaseCloudFunctionHostingerSmtp,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: Colors.grey[600]),
                  ),
                  Text(
                    AppLocalizations.of(context)!.fromSupportAlluwaleducationhubOrg,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: Colors.grey[600]),
                  ),
                  Text(
                    AppLocalizations.of(context)!.toHassimiouNianeMaineEdu,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.availableFunctions,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.purpleBasicEmailTest,
                    style:
                        GoogleFonts.inter(fontSize: 10, color: Colors.purple),
                  ),
                  Text(
                    AppLocalizations.of(context)!.orangeTaskAssignmentNotification,
                    style:
                        GoogleFonts.inter(fontSize: 10, color: Colors.orange),
                  ),
                  Text(
                    AppLocalizations.of(context)!.greenWelcomeEmailForNewUsers,
                    style: GoogleFonts.inter(fontSize: 10, color: Colors.green),
                  ),
                  Text(
                    AppLocalizations.of(context)!.blueTaskStatusUpdateNotification,
                    style: GoogleFonts.inter(fontSize: 10, color: Colors.blue),
                  ),
                  Text(
                    AppLocalizations.of(context)!.tealTestLastLoginUpdateTracking,
                    style: GoogleFonts.inter(fontSize: 10, color: Colors.teal),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Email test buttons
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isEmailTesting ? null : _sendTestEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isEmailTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(AppLocalizations.of(context)!.sendTestEmail),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _isEmailTesting ? null : _sendTestTaskNotification,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isEmailTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(AppLocalizations.of(context)!.testTaskAssignment),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isEmailTesting ? null : _sendTestWelcomeEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isEmailTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(AppLocalizations.of(context)!.testWelcomeEmail),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isEmailTesting ? null : _sendTestStatusUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isEmailTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(AppLocalizations.of(context)!.testStatusUpdate),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isEmailTesting ? null : _testUpdateLastLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isEmailTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(AppLocalizations.of(context)!.testLoginTracking),
                  ),
                ),
              ],
            ),

            // Result display
            if (_emailTestResult.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _emailTestResult.startsWith('✅')
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _emailTestResult.startsWith('✅')
                        ? Colors.green.withOpacity(0.3)
                        : Colors.red.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  _emailTestResult,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _emailTestResult.startsWith('✅')
                        ? Colors.green[800]
                        : Colors.red[800],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionSection(
      String title, List<Map<String, dynamic>> documents, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${documents.length} documents',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (documents.isEmpty)
              Text(
                AppLocalizations.of(context)!.noDocumentsFoundInThisCollection,
                style: GoogleFonts.inter(color: Colors.grey[600]),
              )
            else
              Column(
                children: documents.take(5).map((doc) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ID: ${doc['docId']}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (doc['email'] != null)
                          Text('Email: ${doc['email']}'),
                        if (doc['first_name'] != null)
                          Text(
                              'Name: ${doc['first_name']} ${doc['lastName'] ?? ''}'),
                        if (doc['user_type'] != null)
                          Text('Type: ${doc['user_type']}'),
                      ],
                    ),
                  );
                }).toList(),
              ),
            if (documents.length > 5)
              Text(
                '... and ${documents.length - 5} more documents',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
