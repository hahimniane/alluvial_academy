import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/admin_users_web_cutover.dart';
import 'admin_users_web_frame.dart';
import 'user_management_screen.dart';

/// The admin dashboard's Users item. On the web, an admin named by
/// `settings/admin_users_web_cutover` gets the Next.js page in a frame;
/// everyone else — and every native build — keeps [UserManagementScreen].
class AdminUsersEntry extends StatefulWidget {
  const AdminUsersEntry({super.key});

  @override
  State<AdminUsersEntry> createState() => _AdminUsersEntryState();
}

class _AdminUsersEntryState extends State<AdminUsersEntry> {
  late final Future<bool> _useWeb;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _useWeb = kIsWeb
        ? AdminUsersWebCutover.shouldUseWebPage(uid)
        : Future<bool>.value(false);
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const UserManagementScreen();
    return FutureBuilder<bool>(
      future: _useWeb,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return snapshot.data == true
            ? const AdminUsersWebFrame()
            : const UserManagementScreen();
      },
    );
  }
}
