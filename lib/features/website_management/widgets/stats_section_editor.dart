import 'package:flutter/material.dart';
import '../../../core/models/landing_page_content.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class StatsSectionEditor extends StatelessWidget {
  final StatsContent stats;
  final Function(StatsContent) onChanged;

  const StatsSectionEditor({
    super.key,
    required this.stats,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(AppLocalizations.of(context)!.statsEditor));
  }
} 