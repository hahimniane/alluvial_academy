import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class NavigationMenu extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const NavigationMenu({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onItemSelected,
      labelType: NavigationRailLabelType.selected,
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.dashboard),
          label: Text(AppLocalizations.of(context)!.navDashboard),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.chat),
          label: Text(AppLocalizations.of(context)!.navChat),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.access_time),
          label: Text(AppLocalizations.of(context)!.navTimeClock),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.people),
          label: Text(AppLocalizations.of(context)!.navUsers),
        ),
      ],
    );
  }
}
