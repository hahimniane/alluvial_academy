import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:alluwalacademyadmin/features/tontine/config/tontine_ui.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle.dart';
import 'package:alluwalacademyadmin/features/tontine/services/tontine_service.dart';
import 'package:alluwalacademyadmin/features/tontine/screens/circle_dashboard_screen.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class CreateAdminCircleScreen extends StatefulWidget {
  final CircleType circleType;

  const CreateAdminCircleScreen({super.key, required this.circleType});

  @override
  State<CreateAdminCircleScreen> createState() =>
      _CreateAdminCircleScreenState();
}

class _CreateAdminCircleScreenState extends State<CreateAdminCircleScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _amountController = TextEditingController(text: '100');
  final _gracePeriodController = TextEditingController(text: '3');
  final _paymentInstructionsController = TextEditingController();

  DateTime _startDate = DateTime.now().add(const Duration(days: 30));
  String _frequency = 'monthly';
  bool _isCreating = false;
  CircleMissedPaymentAction _missedAction =
      CircleMissedPaymentAction.moveToBack;

  // Enrollment mode: 'manual' or 'open'
  String _enrollmentMode = 'manual';

  // Eligibility rule fields (for open enrollment)
  final _incomeMultiplierController = TextEditingController(text: '1.6');
  int _minTenureMonths = 0;
  final _minShiftsController = TextEditingController(text: '0');
  final _maxMembersController = TextEditingController(text: '0');

  // Manual mode
  final List<DocumentSnapshot> _selectedParticipants = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _paymentInstructionsController.text =
        widget.circleType == CircleType.teacher
            ? 'Deducted manually by admin from monthly payout.'
            : 'Please upload your receipt here every month.';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _gracePeriodController.dispose();
    _paymentInstructionsController.dispose();
    _incomeMultiplierController.dispose();
    _minShiftsController.dispose();
    _maxMembersController.dispose();
    super.dispose();
  }

  String get _userTypeToQuery =>
      widget.circleType == CircleType.teacher ? 'teacher' : 'parent';
  String get _roleLabel =>
      widget.circleType == CircleType.teacher ? 'Teachers' : 'Parents';
  String get _titlePrefix =>
      widget.circleType == CircleType.teacher ? 'Teacher' : 'Parent';
  bool get _isOpen => _enrollmentMode == 'open';

  Future<void> _createCircle() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isOpen && _selectedParticipants.length < 2) {
      _showMessage('Please select at least 2 ${_roleLabel.toLowerCase()}');
      return;
    }

    setState(() => _isCreating = true);

    try {
      final creator = await TontineService.getCurrentUserLookup();
      final batch = FirebaseFirestore.instance.batch();
      final circleRef =
          FirebaseFirestore.instance.collection('circles').doc();

      final incomeMultiplier =
          double.tryParse(_incomeMultiplierController.text) ?? 1.6;
      final minShifts =
          int.tryParse(_minShiftsController.text) ?? 0;
      final maxMembers =
          int.tryParse(_maxMembersController.text) ?? 0;

      final eligibility = _isOpen
          ? EligibilityRules(
              incomeMultiplier: incomeMultiplier,
              minTenureMonths: _minTenureMonths,
              minShiftsLast30Days: minShifts,
            )
          : null;

      final participants = !_isOpen
          ? _selectedParticipants.map((doc) {
              final data =
                  doc.data() as Map<String, dynamic>? ?? {};
              final firstName = data['first_name'] ?? '';
              final lastName = data['last_name'] ?? '';
              final email =
                  data['email'] ?? data['e-mail'] ?? '';

              return _DraftAdminParticipant(
                userId: doc.id,
                displayName: '$firstName $lastName'.trim(),
                photoUrl: data['profile_picture_url'] ??
                    data['profile_picture'],
                contactInfo: email,
              );
            }).toList()
          : <_DraftAdminParticipant>[];

      final circle = Circle(
        id: circleRef.id,
        title: _titleController.text.trim(),
        type: widget.circleType,
        status: _isOpen ? CircleStatus.forming : CircleStatus.active,
        contributionAmount:
            double.parse(_amountController.text.trim()),
        currency: 'USD',
        frequency: _frequency,
        totalMembers: _isOpen ? 0 : participants.length,
        currentCycleIndex: 0,
        createdBy: creator.userId,
        createdAt: DateTime.now(),
        startDate: _startDate,
        rules: CircleRules(
          gracePeriodDays:
              int.parse(_gracePeriodController.text),
          missedPaymentAction: _missedAction,
        ),
        paymentInstructions:
            _paymentInstructionsController.text.trim(),
        enrollmentMode: _enrollmentMode,
        maxMembers: _isOpen && maxMembers > 0 ? maxMembers : null,
        eligibilityRules: eligibility,
      );

      final circleData = circle.toMap()
        ..['created_at'] = FieldValue.serverTimestamp();
      batch.set(circleRef, circleData);

      for (var index = 0; index < participants.length; index++) {
        final participant = participants[index];
        final memberRef = FirebaseFirestore.instance
            .collection('circle_members')
            .doc();
        batch.set(memberRef, {
          'circle_id': circleRef.id,
          'user_id': participant.userId,
          'display_name': participant.displayName,
          'photo_url': participant.photoUrl,
          'contact_info': participant.contactInfo,
          'is_tontine_head': false,
          'payout_position': index + 1,
          'status': 'active',
          'joined_at': FieldValue.serverTimestamp(),
          'total_contributed': 0.0,
          'total_received': 0.0,
          'has_received_payout': false,
        });
      }

      await batch.commit();

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        if (_isOpen) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(l10n.tontineOpenCircleCreated)),
          );
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) =>
                  CircleDashboardScreen(circleId: circle.id),
            ),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Failed to create circle: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Create $_titlePrefix Circle',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
      bottomNavigationBar: isDesktop ? _buildBottomBar() : null,
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: _buildFormSection()),
        Container(width: 1, color: const Color(0xFFE2E8F0)),
        Expanded(
          flex: 4,
          child: _isOpen
              ? _buildEligibilitySection()
              : _buildParticipantSelectionSection(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    final tabCount = _isOpen ? 2 : 2;
    return Column(
      children: [
        Expanded(
          child: DefaultTabController(
            length: tabCount,
            child: Column(
              children: [
                TabBar(
                  labelColor: const Color(0xFF0F766E),
                  unselectedLabelColor: const Color(0xFF64748B),
                  indicatorColor: const Color(0xFF0F766E),
                  tabs: [
                    const Tab(text: 'Circle Details'),
                    Tab(
                      text: _isOpen
                          ? 'Eligibility Rules'
                          : 'Select Members',
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildFormSection(),
                      _isOpen
                          ? _buildEligibilitySection()
                          : _buildParticipantSelectionSection(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildFormSection() {
    final l10n = AppLocalizations.of(context)!;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Enrollment mode toggle
          if (widget.circleType == CircleType.teacher) ...[
            _buildSectionHeader(
                l10n.tontineEnrollmentMode, Icons.toggle_on_rounded),
            _buildCard(_buildEnrollmentModeToggle(l10n)),
            const SizedBox(height: 28),
          ],
          _buildSectionHeader('Basics', Icons.info_outline_rounded),
          _buildCard(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: _inputDecoration('Circle Name'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration:
                      _inputDecoration('Monthly Contribution (USD)'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v) == null) return 'Invalid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    leading: const Icon(Icons.event_rounded,
                        color: Color(0xFF0F766E)),
                    title: const Text('Start Date'),
                    subtitle: Text(
                      MaterialLocalizations.of(context)
                          .formatMediumDate(_startDate),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => _startDate = picked);
                        }
                      },
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF0F766E)),
                      child: const Text('Edit'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _frequency,
                  decoration:
                      _inputDecoration('Contribution Frequency'),
                  items: const [
                    DropdownMenuItem(
                        value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(
                        value: 'biweekly',
                        child: Text('Every 2 weeks')),
                    DropdownMenuItem(
                        value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(
                        value: 'quarterly',
                        child: Text('Quarterly')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _frequency = v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _buildSectionHeader('Rules', Icons.gavel_rounded),
          _buildCard(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _gracePeriodController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('Grace Period (days)'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (int.tryParse(v) == null) return 'Invalid number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<CircleMissedPaymentAction>(
                  value: _missedAction,
                  decoration:
                      _inputDecoration('Missed payment action'),
                  items: CircleMissedPaymentAction.values
                      .map((action) => DropdownMenuItem(
                            value: action,
                            child: Text(
                                TontineUi.missedPaymentActionLabel(
                                    context, action)),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _missedAction = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _paymentInstructionsController,
                  maxLines: 4,
                  decoration:
                      _inputDecoration('Payment Instructions'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty
                          ? 'Required'
                          : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnrollmentModeToggle(AppLocalizations l10n) {
    return Column(
      children: [
        _EnrollmentModeOption(
          icon: Icons.person_search_rounded,
          title: l10n.tontineManualSelection,
          subtitle: l10n.tontineManualSelectionDesc,
          selected: !_isOpen,
          onTap: () => setState(() => _enrollmentMode = 'manual'),
        ),
        const SizedBox(height: 12),
        _EnrollmentModeOption(
          icon: Icons.public_rounded,
          title: l10n.tontineOpenEnrollment,
          subtitle: l10n.tontineOpenEnrollmentDesc,
          selected: _isOpen,
          onTap: () => setState(() => _enrollmentMode = 'open'),
        ),
      ],
    );
  }

  Widget _buildEligibilitySection() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSectionHeader(
              l10n.tontineEligibilityRules, Icons.rule_rounded),
          const SizedBox(height: 8),
          _buildCard(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _EligibilityField(
                  icon: Icons.monetization_on_rounded,
                  label: l10n.tontineIncomeMultiplier,
                  hint: l10n.tontineIncomeMultiplierHint,
                  child: TextFormField(
                    controller: _incomeMultiplierController,
                    keyboardType:
                        const TextInputType.numberWithOptions(
                            decimal: true),
                    decoration: _inputDecoration('e.g. 1.6'),
                  ),
                ),
                const Divider(height: 32, color: Color(0xFFF1F5F9)),
                _EligibilityField(
                  icon: Icons.calendar_month_rounded,
                  label: l10n.tontineMinTenure,
                  hint: l10n.tontineMinTenureHint,
                  child: DropdownButtonFormField<int>(
                    value: _minTenureMonths,
                    decoration: _inputDecoration(''),
                    items: const [
                      DropdownMenuItem(
                          value: 0, child: Text('No minimum')),
                      DropdownMenuItem(
                          value: 1, child: Text('1 month')),
                      DropdownMenuItem(
                          value: 3, child: Text('3 months')),
                      DropdownMenuItem(
                          value: 6, child: Text('6 months')),
                      DropdownMenuItem(
                          value: 12, child: Text('12 months')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _minTenureMonths = v);
                      }
                    },
                  ),
                ),
                const Divider(height: 32, color: Color(0xFFF1F5F9)),
                _EligibilityField(
                  icon: Icons.school_rounded,
                  label: l10n.tontineMinShifts,
                  hint: l10n.tontineMinShiftsHint,
                  child: TextFormField(
                    controller: _minShiftsController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('e.g. 5'),
                  ),
                ),
                const Divider(height: 32, color: Color(0xFFF1F5F9)),
                _EligibilityField(
                  icon: Icons.group_rounded,
                  label: l10n.tontineMaxMembers,
                  hint: l10n.tontineMaxMembersHint,
                  child: TextFormField(
                    controller: _maxMembersController,
                    keyboardType: TextInputType.number,
                    decoration:
                        _inputDecoration('0 = ${l10n.tontineUnlimited}'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantSelectionSection() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select $_roleLabel',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_selectedParticipants.length} Selected',
                        style: const TextStyle(
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    prefixIcon: const Icon(Icons.search,
                        color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase();
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('user_type', isEqualTo: _userTypeToQuery)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                if (!snapshot.hasData ||
                    snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No ${_roleLabel.toLowerCase()} found.',
                      style: const TextStyle(
                          color: Color(0xFF64748B)),
                    ),
                  );
                }

                var docs = snapshot.data!.docs;
                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((doc) {
                    final data =
                        doc.data() as Map<String, dynamic>;
                    final fn = (data['first_name'] ?? '')
                        .toString()
                        .toLowerCase();
                    final ln = (data['last_name'] ?? '')
                        .toString()
                        .toLowerCase();
                    final em = (data['email'] ??
                            data['e-mail'] ??
                            '')
                        .toString()
                        .toLowerCase();
                    return fn.contains(_searchQuery) ||
                        ln.contains(_searchQuery) ||
                        em.contains(_searchQuery);
                  }).toList();
                }

                return ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(
                      height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data =
                        doc.data() as Map<String, dynamic>;
                    final isSelected = _selectedParticipants
                        .any((d) => d.id == doc.id);
                    final fullName =
                        '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'
                            .trim();
                    final email = data['email'] ??
                        data['e-mail'] ??
                        '';
                    final photoUrl =
                        data['profile_picture_url'] ??
                            data['profile_picture'];

                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedParticipants.removeWhere(
                                (d) => d.id == doc.id);
                          } else {
                            _selectedParticipants.add(doc);
                          }
                        });
                      },
                      child: Container(
                        color: isSelected
                            ? const Color(0xFFF0FDFA)
                            : Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF0F766E)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF0F766E)
                                      : const Color(0xFFCBD5E1),
                                  width: 2,
                                ),
                                borderRadius:
                                    BorderRadius.circular(6),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check,
                                      size: 16,
                                      color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            CircleAvatar(
                              radius: 20,
                              backgroundColor:
                                  const Color(0xFFE2E8F0),
                              backgroundImage: photoUrl != null
                                  ? NetworkImage(photoUrl)
                                  : null,
                              child: photoUrl == null
                                  ? Text(
                                      TontineUi.initialsForName(
                                          fullName),
                                      style: const TextStyle(
                                        color:
                                            Color(0xFF64748B),
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fullName.isEmpty
                                        ? 'Unknown User'
                                        : fullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  if (email.isNotEmpty)
                                    Text(
                                      email,
                                      style: const TextStyle(
                                        color:
                                            Color(0xFF64748B),
                                        fontSize: 13,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF94A3B8), size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: _isCreating ? null : _createCircle,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isCreating
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 3, color: Colors.white),
                  )
                : Text(
                    'Create $_titlePrefix Circle',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ),
    );
  }
}

class _EnrollmentModeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _EnrollmentModeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFF0FDFA)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFF0F766E)
                : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF0F766E).withOpacity(0.12)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: selected
                    ? const Color(0xFF0F766E)
                    : const Color(0xFF94A3B8),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: selected
                          ? const Color(0xFF0F766E)
                          : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected
                  ? const Color(0xFF0F766E)
                  : const Color(0xFFCBD5E1),
            ),
          ],
        ),
      ),
    );
  }
}

class _EligibilityField extends StatefulWidget {
  final IconData icon;
  final String label;
  final String hint;
  final Widget child;

  const _EligibilityField({
    required this.icon,
    required this.label,
    required this.hint,
    required this.child,
  });

  @override
  State<_EligibilityField> createState() => _EligibilityFieldState();
}

class _EligibilityFieldState extends State<_EligibilityField> {
  bool _showHint = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(widget.icon,
                size: 18, color: const Color(0xFF0F766E)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFF334155),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _showHint = !_showHint),
              child: Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: _showHint
                    ? const Color(0xFF0F766E)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
        if (_showHint) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.hint,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        widget.child,
      ],
    );
  }
}

class _DraftAdminParticipant {
  final String userId;
  final String displayName;
  final String? photoUrl;
  final String contactInfo;

  const _DraftAdminParticipant({
    required this.userId,
    required this.displayName,
    this.photoUrl,
    required this.contactInfo,
  });
}
