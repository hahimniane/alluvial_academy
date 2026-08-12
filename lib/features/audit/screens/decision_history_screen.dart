import 'package:flutter/material.dart';

import '../../../core/models/decision_audit_event.dart';
import '../../../core/services/decision_audit_service.dart';
import '../../../core/widgets/decision_history_card.dart';
import '../../../l10n/app_localizations.dart';
import '../utils/decision_history_filter.dart';

class DecisionHistoryScreen extends StatefulWidget {
  const DecisionHistoryScreen({super.key});

  @override
  State<DecisionHistoryScreen> createState() => _DecisionHistoryScreenState();
}

class _DecisionHistoryScreenState extends State<DecisionHistoryScreen> {
  final DecisionAuditService _service = DecisionAuditService();
  final TextEditingController _searchController = TextEditingController();
  String _entityFilter = 'all';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ColoredBox(
      color: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.fact_check_outlined,
                      color: Color(0xFF4F46E5),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.decisionHistory,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            l10n.decisionHistoryDescription,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: l10n.decisionHistorySearchHint,
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _filterChip('all', l10n.decisionHistoryAll),
                    _filterChip('user', l10n.decisionEntityUsers),
                    _filterChip('shift', l10n.decisionEntityShifts),
                    _filterChip('invoice', l10n.decisionEntityInvoices),
                    _filterChip('timesheet', l10n.decisionEntityTimesheets),
                    _filterChip(
                      'application',
                      l10n.decisionEntityApplications,
                    ),
                    _filterChip('task', l10n.decisionEntityTasks),
                    _filterChip('form_response', l10n.decisionEntityForms),
                    _filterChip('no_show', l10n.decisionEntityNoShows),
                    _filterChip(
                      'enrollment',
                      l10n.decisionEntityEnrollments,
                    ),
                    _filterChip('audit', l10n.decisionEntityAudits),
                    _filterChip('setting', l10n.decisionEntitySettings),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<DecisionAuditEvent>>(
              stream: _service.watchRecentHistory(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.decisionHistoryLoadError,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFB91C1C)),
                      ),
                    ),
                  );
                }

                final events = (snapshot.data ?? const <DecisionAuditEvent>[])
                    .where(
                      (event) => matchesDecisionHistoryEvent(
                        event: event,
                        query: _searchController.text,
                        entityFilter: _entityFilter,
                      ),
                    )
                    .toList(growable: false);
                if (events.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.decisionHistoryEmpty,
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DecisionHistoryEventTile(
                        event: event,
                        showEntityLabel: true,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _entityFilter == value,
      onSelected: (_) => setState(() => _entityFilter = value),
      selectedColor: const Color(0xFFE0E7FF),
      side: const BorderSide(color: Color(0xFFE2E8F0)),
      labelStyle: TextStyle(
        color: _entityFilter == value
            ? const Color(0xFF3730A3)
            : const Color(0xFF475569),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
