import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../services/language_service.dart';

class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({
    super.key,
    this.foregroundColor,
    this.backgroundColor,
    this.compact = true,
  });

  final Color? foregroundColor;
  final Color? backgroundColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final languageService = context.watch<LanguageService>();
    final l = AppLocalizations.of(context)!;
    final code = languageService.locale?.languageCode ??
        Localizations.localeOf(context).languageCode;
    final color = foregroundColor ?? Theme.of(context).colorScheme.primary;

    return Semantics(
      button: true,
      label: l.languageTitle,
      value: code == 'fr' ? l.languageFrench : l.languageEnglish,
      child: PopupMenuButton<String>(
        key: const ValueKey('public-language-switcher'),
        tooltip: l.languageTitle,
        initialValue: code,
        onSelected: (value) => languageService.setLocale(Locale(value)),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'en',
            child: Text('EN — ${l.languageEnglish}'),
          ),
          PopupMenuItem(
            value: 'fr',
            child: Text('FR — ${l.languageFrench}'),
          ),
        ],
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor ?? color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 12,
              vertical: compact ? 5 : 8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.language_rounded,
                    size: compact ? 15 : 18, color: color),
                const SizedBox(width: 5),
                Text(
                  code.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: compact ? 11 : 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Icon(Icons.arrow_drop_down_rounded,
                    size: compact ? 15 : 18, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
