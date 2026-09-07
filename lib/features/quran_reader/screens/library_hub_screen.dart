import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

import '../../curriculum/screens/curriculum_books_screen.dart';
import 'quran_reader_screen.dart';

/// The Qur'an and the curriculum books under one tab, so teachers and
/// parents reach the Qur'an reader without another slot on the bottom bar.
class LibraryHubScreen extends StatelessWidget {
  const LibraryHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.navLibrary, style: const TextStyle(fontWeight: FontWeight.w800)),
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.auto_stories_rounded), text: l10n.libraryQuran),
              Tab(icon: const Icon(Icons.menu_book_rounded), text: l10n.moreBooks),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            QuranReaderScreen(),
            CurriculumBooksScreen(),
          ],
        ),
      ),
    );
  }
}
