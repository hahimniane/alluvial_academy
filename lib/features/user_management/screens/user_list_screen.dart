import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class UserListScreen extends StatelessWidget {
  const UserListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(AppLocalizations.of(context)!.userListScreenComingSoon),
    );
  }
}
