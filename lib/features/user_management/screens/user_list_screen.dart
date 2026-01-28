import 'package:flutter/material.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class UserListScreen extends StatelessWidget {
  const UserListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(AppLocalizations.of(context)!.userListScreenComingSoon),
    );
  }
}
