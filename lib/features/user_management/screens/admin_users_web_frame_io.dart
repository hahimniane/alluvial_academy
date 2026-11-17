import 'package:flutter/material.dart';

/// Native builds never reach this widget — [AdminUsersEntry] shows
/// [UserManagementScreen] off the web. It exists only to satisfy the
/// conditional import.
class AdminUsersWebFrame extends StatelessWidget {
  const AdminUsersWebFrame({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
