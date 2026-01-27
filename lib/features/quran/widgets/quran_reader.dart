import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/quran_models.dart';
import '../../../core/services/quran_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class QuranReader extends StatefulWidget {
  final int initialSurahNumber;
  final bool showTranslationByDefault;

  const QuranReader({
    super.key,
    this.initialSurahNumber = 1,
    this.showTranslationByDefault = true,
  });

  @override
  State<QuranReader> createState() => _QuranReaderState();
}

class _QuranReaderState extends State<QuranReader> {
  List<QuranSurah>? _surahs;
  QuranSurah? _selectedSurah;
  Future<QuranSurahContent>? _contentFuture;
  String? _loadError;

  late bool _showTranslation;
  double _arabicFontSize = 28;
  double _translationFontSize = 16;

  @override
  void initState() {
    super.initState();
    _showTranslation = widget.showTranslationByDefault;
    _loadSurahs();
  }

  Future<void> _loadSurahs({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _loadError = null;
      _surahs = null;
      _selectedSurah = null;
      _contentFuture = null;
    });

    try {
      final surahs = await QuranService.getSurahs(forceRefresh: forceRefresh);
      if (!mounted) return;

      final initial = surahs.firstWhere(
        (s) => s.number == widget.initialSurahNumber,
        orElse: () => surahs.first,
      );

      setState(() {
        _surahs = surahs;
        _selectedSurah = initial;
        _contentFuture = QuranService.getSurahContent(initial.number);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
      });
    }
  }

  void _selectSurah(QuranSurah surah) {
    setState(() {
      _selectedSurah = surah;
      _contentFuture = QuranService.getSurahContent(surah.number);
    });
  }

  void _adjustArabicFontSize(double delta) {
    setState(() {
      _arabicFontSize = (_arabicFontSize + delta).clamp(18, 60);
    });
  }

  void _adjustTranslationFontSize(double delta) {
    setState(() {
      _translationFontSize = (_translationFontSize + delta).clamp(12, 30);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return _QuranErrorState(
        title: AppLocalizations.of(context)!.unableToLoadQuran,
        message: _loadError!,
        onRetry: () => _loadSurahs(forceRefresh: true),
      );
    }

    if (_surahs == null || _selectedSurah == null || _contentFuture == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final surahs = _surahs!;
    final selectedSurah = _selectedSurah!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 720;
            final picker = _SurahAutocomplete(
              key: ValueKey<int>(selectedSurah.number),
              surahs: surahs,
              selectedSurah: selectedSurah,
              onSelected: _selectSurah,
            );

            final controls = Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment:
                  isCompact ? WrapAlignment.spaceBetween : WrapAlignment.end,
              children: [
                _ToggleChip(
                  selected: _showTranslation,
                  icon: Icons.translate,
                  label: 'Translation',
                  onPressed: () => setState(() => _showTranslation = !_showTranslation),
                ),
                _IconChip(
                  icon: Icons.text_decrease,
                  label: 'Arabic',
                  onPressed: () => _adjustArabicFontSize(-2),
                ),
                _IconChip(
                  icon: Icons.text_increase,
                  label: 'Arabic',
                  onPressed: () => _adjustArabicFontSize(2),
                ),
                if (_showTranslation) ...[
                  _IconChip(
                    icon: Icons.remove,
                    label: 'Text',
                    onPressed: () => _adjustTranslationFontSize(-1),
                  ),
                  _IconChip(
                    icon: Icons.add,
                    label: 'Text',
                    onPressed: () => _adjustTranslationFontSize(1),
                  ),
                ],
                _IconChip(
                  icon: Icons.refresh,
                  label: 'Reload',
                  onPressed: () {
                    if (_selectedSurah == null) return;
                    setState(() {
                      _contentFuture = QuranService.getSurahContent(
                        _selectedSurah!.number,
                        forceRefresh: true,
                      );
                    });
                  },
                ),
              ],
            );

            if (isCompact) {
              return Column(
                children: [
                  picker,
                  const SizedBox(height: 12),
                  controls,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: picker),
                const SizedBox(width: 12),
                Flexible(child: controls),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Expanded(
          child: FutureBuilder<QuranSurahContent>(
            future: _contentFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _QuranErrorState(
                  title: AppLocalizations.of(context)!.unableToLoadSurah,
                  message: '${snapshot.error}',
                  onRetry: () {
                    setState(() {
                      _contentFuture = QuranService.getSurahContent(
                        selectedSurah.number,
                        forceRefresh: true,
                      );
                    });
                  },
                );
              }

              final content = snapshot.data;
              if (content == null) {
                return const Center(child: Text(AppLocalizations.of(context)!.noData));
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: content.ayahs.length,
                itemBuilder: (context, index) {
                  final ayah = content.ayahs[index];
                  return _AyahCard(
                    ayah: ayah,
                    showTranslation: _showTranslation,
                    arabicFontSize: _arabicFontSize,
                    translationFontSize: _translationFontSize,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SurahAutocomplete extends StatelessWidget {
  final List<QuranSurah> surahs;
  final QuranSurah selectedSurah;
  final ValueChanged<QuranSurah> onSelected;

  const _SurahAutocomplete({
    super.key,
    required this.surahs,
    required this.selectedSurah,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<QuranSurah>(
      initialValue: TextEditingValue(
        text: _displayStringForOption(selectedSurah),
      ),
      displayStringForOption: _displayStringForOption,
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return surahs;

        return surahs.where((s) {
          final numberMatch = s.number.toString() == query;
          final en = s.englishName.toLowerCase();
          final enTrans = s.englishNameTranslation.toLowerCase();
          final ar = s.nameArabic;
          return numberMatch ||
              en.contains(query) ||
              enTrans.contains(query) ||
              ar.contains(textEditingValue.text.trim());
        });
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.surah,
            hintText: AppLocalizations.of(context)!.searchByNameOrNumber,
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          onSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onOptionSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360, maxWidth: 520),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(
                      '${option.number}. ${option.englishName}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      option.englishNameTranslation,
                      style: GoogleFonts.inter(),
                    ),
                    trailing: Text(
                      option.nameArabic,
                      style: GoogleFonts.amiri(fontSize: 18),
                      textDirection: TextDirection.rtl,
                    ),
                    onTap: () => onOptionSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  static String _displayStringForOption(QuranSurah surah) {
    final translation = surah.englishNameTranslation.trim();
    if (translation.isEmpty) return '${surah.number}. ${surah.englishName}';
    return '${surah.number}. ${surah.englishName} — $translation';
  }
}

class _AyahCard extends StatelessWidget {
  final QuranAyah ayah;
  final bool showTranslation;
  final double arabicFontSize;
  final double translationFontSize;

  const _AyahCard({
    required this.ayah,
    required this.showTranslation,
    required this.arabicFontSize,
    required this.translationFontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xffEEF2FF),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${ayah.numberInSurah}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff3730A3),
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Directionality(
              textDirection: TextDirection.rtl,
              child: SelectableText(
                ayah.arabicText,
                textAlign: TextAlign.right,
                style: GoogleFonts.amiri(
                  fontSize: arabicFontSize,
                  height: 1.7,
                  color: const Color(0xff111827),
                ),
              ),
            ),
            if (showTranslation) ...[
              const SizedBox(height: 12),
              SelectableText(
                ayah.translation,
                style: GoogleFonts.inter(
                  fontSize: translationFontSize,
                  height: 1.5,
                  color: const Color(0xff374151),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuranErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _QuranErrorState({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 44),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff111827),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xff6B7280),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(AppLocalizations.of(context)!.commonRetry),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff0386FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _IconChip({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: const Color(0xff374151)),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff374151),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ToggleChip({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = selected ? const Color(0xffDBEAFE) : Colors.white;
    final fgColor = selected ? const Color(0xff1D4ED8) : const Color(0xff374151);

    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fgColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fgColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

