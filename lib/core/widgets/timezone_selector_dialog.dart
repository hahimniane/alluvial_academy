import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/timezone_utils.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class TimezoneSelectorDialog extends StatefulWidget {
  final String? initialTimezone;
  final String title;

  const TimezoneSelectorDialog({
    super.key,
    required this.initialTimezone,
    this.title = 'Select Timezone',
  });

  @override
  State<TimezoneSelectorDialog> createState() => _TimezoneSelectorDialogState();
}

class _TimezoneOption {
  final String id;
  final String region;
  final String display;
  final String searchText;

  const _TimezoneOption({
    required this.id,
    required this.region,
    required this.display,
    required this.searchText,
  });
}

class _TimezoneSelectorDialogState extends State<TimezoneSelectorDialog> {
  final TextEditingController _searchController = TextEditingController();

  late final String _initialTimezone;
  late final Map<String, List<_TimezoneOption>> _optionsByRegion;
  late final List<_TimezoneOption> _allOptions;
  late List<_TimezoneOption> _filtered;
  late final Set<String> _expandedRegions;

  @override
  void initState() {
    super.initState();

    TimezoneUtils.initializeTimezones();
    _initialTimezone = TimezoneUtils.normalizeTimezone(widget.initialTimezone);

    final byRegion = TimezoneUtils.getTimezonesByRegion();
    _optionsByRegion = byRegion.map((region, ids) {
      final options = ids.map((id) {
        final display = TimezoneUtils.formatTimezoneForDisplay(id);
        return _TimezoneOption(
          id: id,
          region: region,
          display: display,
          searchText: display.toLowerCase(),
        );
      }).toList();
      return MapEntry(region, options);
    });

    _allOptions = _optionsByRegion.values.expand((v) => v).toList();
    _filtered = _allOptions;

    final initialRegion = _initialTimezone.contains('/')
        ? _initialTimezone.split('/').first
        : 'Other';
    _expandedRegions = {initialRegion};

    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = _allOptions;
      } else {
        _filtered = _allOptions.where((o) => o.searchText.contains(q)).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        height: 600,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 10),
            _buildSearchField(),
            const SizedBox(height: 12),
            Expanded(
              child: query.isEmpty ? _buildGroupedList() : _buildFlatList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            widget.title,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xff111827),
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, size: 20),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: AppLocalizations.of(context)!.searchByCityTimezoneIdOr,
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xffE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xffE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xff0386FF), width: 2),
        ),
      ),
    );
  }

  Widget _buildGroupedList() {
    return ListView(
      children: _optionsByRegion.entries.map((entry) {
        final region = entry.key;
        final options = entry.value;
        if (options.isEmpty) return const SizedBox.shrink();
        final isExpanded = _expandedRegions.contains(region);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xffE2E8F0)),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: PageStorageKey<String>('timezone_region_$region'),
              initiallyExpanded: isExpanded,
              onExpansionChanged: (expanded) {
                setState(() {
                  if (expanded) {
                    _expandedRegions.add(region);
                  } else {
                    _expandedRegions.remove(region);
                  }
                });
              },
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              title: Text(
                '$region (${options.length})',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff111827),
                ),
              ),
              children: isExpanded
                  ? options.map(_buildOptionTile).toList()
                  : const [],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFlatList() {
    return ListView.builder(
      itemCount: _filtered.length,
      itemBuilder: (context, index) => _buildOptionTile(_filtered[index]),
    );
  }

  Widget _buildOptionTile(_TimezoneOption option) {
    final isSelected = option.id == _initialTimezone;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xff0386FF).withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? const Color(0xff0386FF) : const Color(0xffE2E8F0),
        ),
      ),
      child: InkWell(
        onTap: () => Navigator.pop(context, option.id),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (isSelected)
                const Icon(Icons.check_circle,
                    color: Color(0xff0386FF), size: 18)
              else
                const Icon(Icons.circle_outlined,
                    color: Color(0xff9CA3AF), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  option.display,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff111827),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
