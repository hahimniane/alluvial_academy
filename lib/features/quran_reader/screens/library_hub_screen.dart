import 'package:flutter/material.dart';

import '../../curriculum/screens/curriculum_books_screen.dart';
import 'quran_reader_screen.dart';

/// The Qur'an and the curriculum books under one tab, so teachers and
/// parents reach the Qur'an reader without another slot on the bottom bar.
class LibraryHubScreen extends StatelessWidget {
  const LibraryHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Library', style: TextStyle(fontWeight: FontWeight.w800)),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.auto_stories_rounded), text: "Qur'an"),
              Tab(icon: Icon(Icons.menu_book_rounded), text: 'Books'),
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
