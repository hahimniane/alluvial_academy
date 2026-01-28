import 'package:flutter/material.dart';
import '../../../core/models/landing_page_content.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class FooterSectionEditor extends StatelessWidget {
  final FooterContent footer;
  final Function(FooterContent) onChanged;

  const FooterSectionEditor({
    super.key,
    required this.footer,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(AppLocalizations.of(context)!.footerEditor));
  }
} 