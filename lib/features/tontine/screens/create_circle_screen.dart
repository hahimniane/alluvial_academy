import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import 'package:alluwalacademyadmin/core/utils/phone_national_input_validation.dart';
import 'package:alluwalacademyadmin/features/tontine/config/tontine_ui.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle_invite.dart';
import 'package:alluwalacademyadmin/features/tontine/screens/circle_dashboard_screen.dart';
import 'package:alluwalacademyadmin/features/tontine/services/tontine_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class CreateCircleScreen extends StatefulWidget {
  const CreateCircleScreen({super.key});

  @override
  State<CreateCircleScreen> createState() => _CreateCircleScreenState();
}

class _CreateCircleScreenState extends State<CreateCircleScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController =
      TextEditingController(text: '100');
  final TextEditingController _memberCountController =
      TextEditingController(text: '3');
  final TextEditingController _gracePeriodController =
      TextEditingController(text: '3');
  final TextEditingController _paymentInstructionsController =
      TextEditingController();
  final TextEditingController _inviteQueryController = TextEditingController();

  bool _isCreating = false;
  bool _isLoadingCreator = true;
  DateTime _startDate = DateTime.now().add(const Duration(days: 30));
  String _frequency = 'monthly';
  CircleMissedPaymentAction _missedAction =
      CircleMissedPaymentAction.moveToBack;
  CircleInviteMethod _inviteMethod = CircleInviteMethod.email;
  final List<_DraftParticipant> _participants = <_DraftParticipant>[];

  int get _targetMemberCount =>
      int.tryParse(_memberCountController.text.trim()) ?? 0;

  static const _teal = Color(0xFF0F766E);
  static const _tealLight = Color(0xFFCCFBF1);

  @override
  void initState() {
    super.initState();
    _loadCreator();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _memberCountController.dispose();
    _gracePeriodController.dispose();
    _paymentInstructionsController.dispose();
    _inviteQueryController.dispose();
    super.dispose();
  }

  InputDecoration _inputDeco({
    required IconData icon,
    String? hint,
    String? prefix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefix,
      prefixIcon: Container(
        margin: const EdgeInsets.only(left: 12, right: 8),
        child: Icon(icon, color: _teal, size: 20),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 0),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: GoogleFonts.inter(
        color: const Color(0xFFCBD5E1),
        fontSize: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _teal, width: 1.5),
      ),
    );
  }

  Widget _fieldWithInfo({
    required String label,
    required String info,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF475569),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 5),
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _InfoSheet(title: label, message: info),
                );
              },
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: _teal.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 12,
                    color: _teal,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(
          l10n.tontineCreateCircle,
          style: GoogleFonts.inter(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: _isLoadingCreator
          ? const Center(child: CircularProgressIndicator(color: _teal))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    children: [
                      _buildSectionHeader(
                        step: 1,
                        title: l10n.tontineStepBasics,
                        icon: Icons.auto_awesome_rounded,
                        color: _teal,
                      ),
                      _buildCard(_buildBasicsStep(context)),
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        step: 2,
                        title: l10n.tontineStepRules,
                        icon: Icons.shield_outlined,
                        color: const Color(0xFFF59E0B),
                      ),
                      _buildCard(_buildRulesStep(context)),
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        step: 3,
                        title: l10n.tontineStepInvite,
                        icon: Icons.people_alt_rounded,
                        color: const Color(0xFF2563EB),
                      ),
                      _buildCard(_buildInviteStep(context)),
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        step: 4,
                        title: l10n.tontineStepOrder,
                        icon: Icons.swap_vert_rounded,
                        color: const Color(0xFF8B5CF6),
                      ),
                      _buildCard(_buildOrderStep(context)),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
                _buildBottomBar(context),
              ],
            ),
    );
  }

  Widget _buildSectionHeader({
    required int step,
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, left: 2),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(icon, color: color, size: 18),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$step/4',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
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
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: child,
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: _isCreating ? null : _createCircle,
            icon: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.rocket_launch_rounded, size: 20),
            label: Text(
              _isCreating ? '...' : l10n.tontineCreateCircle,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _teal,
              disabledBackgroundColor: _teal.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBasicsStep(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final frequencyOptions = <MapEntry<String, _FreqOption>>[
      MapEntry('weekly', _FreqOption(l10n.tontineFrequencyWeekly, Icons.view_week_rounded)),
      MapEntry('biweekly', _FreqOption(l10n.tontineFrequencyBiweekly, Icons.date_range_rounded)),
      MapEntry('monthly', _FreqOption(l10n.tontineFrequencyMonthly, Icons.calendar_month_rounded)),
      MapEntry('quarterly', _FreqOption(l10n.tontineFrequencyQuarterly, Icons.event_note_rounded)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldWithInfo(
          label: l10n.tontineCircleName,
          info: l10n.tontineHintCircleName,
          child: TextField(
            controller: _titleController,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            decoration: _inputDeco(
              icon: Icons.group_work_rounded,
              hint: 'e.g. Family Savings',
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _fieldWithInfo(
                label: l10n.tontineContributionAmount,
                info: l10n.tontineHintAmount,
                child: TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  decoration: _inputDeco(
                    icon: Icons.attach_money_rounded,
                    hint: '0.00',
                    prefix: '\$ ',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _fieldWithInfo(
                label: l10n.tontineMemberCount,
                info: l10n.tontineHintMemberCount,
                child: TextField(
                  controller: _memberCountController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  decoration: _inputDeco(
                    icon: Icons.people_outline_rounded,
                    hint: 'e.g. 5',
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        _fieldWithInfo(
          label: l10n.tontineStartDate,
          info: l10n.tontineHintStartDate,
          child: Material(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _pickStartDate,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _tealLight,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                          Icons.event_rounded, color: _teal, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        MaterialLocalizations.of(context)
                            .formatMediumDate(_startDate),
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _teal.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l10n.commonEdit,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _teal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        _fieldWithInfo(
          label: l10n.tontineFrequency,
          info: l10n.tontineHintFrequency,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: frequencyOptions.map((entry) {
              final isSelected = _frequency == entry.key;
              return ChoiceChip(
                selected: isSelected,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      entry.value.icon,
                      size: 16,
                      color:
                          isSelected ? Colors.white : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(entry.value.label),
                  ],
                ),
                labelStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
                selectedColor: _teal,
                backgroundColor: const Color(0xFFF1F5F9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected ? _teal : const Color(0xFFE2E8F0),
                  ),
                ),
                showCheckmark: false,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                onSelected: (_) => setState(() => _frequency = entry.key),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRulesStep(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldWithInfo(
          label: l10n.tontineGracePeriodDays,
          info: l10n.tontineHintGracePeriod,
          child: TextField(
            controller: _gracePeriodController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            decoration: _inputDeco(
              icon: Icons.timer_outlined,
              hint: 'e.g. 3',
            ),
          ),
        ),
        const SizedBox(height: 20),
        _fieldWithInfo(
          label: l10n.tontineMissedPaymentAction,
          info: l10n.tontineHintMissedPayment,
          child: DropdownButtonFormField<CircleMissedPaymentAction>(
            initialValue: _missedAction,
            decoration: _inputDeco(
              icon: Icons.report_gmailerrorred_rounded,
            ),
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
              fontSize: 14,
            ),
            items: CircleMissedPaymentAction.values
                .map(
                  (action) => DropdownMenuItem<CircleMissedPaymentAction>(
                    value: action,
                    child: Text(
                        TontineUi.missedPaymentActionLabel(context, action)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _missedAction = value;
              });
            },
          ),
        ),
        const SizedBox(height: 20),
        _fieldWithInfo(
          label: l10n.tontinePaymentInstructions,
          info: l10n.tontineHintPaymentInstructions,
          child: TextField(
            controller: _paymentInstructionsController,
            maxLines: 4,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: _inputDeco(
              icon: Icons.description_outlined,
              hint: 'e.g. Send via Zelle to ...',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInviteStep(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final invitedParticipants =
        _participants.where((participant) => !participant.isCreator).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: Color(0xFF2563EB), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.tontineInviteExistingUsersOnly,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF1E40AF),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Invite method toggle
        Text(
          l10n.tontineInviteMethod,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: CircleInviteMethod.values.map((method) {
            final isSelected = _inviteMethod == method;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ChoiceChip(
                selected: isSelected,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      method == CircleInviteMethod.email
                          ? Icons.email_outlined
                          : Icons.phone_rounded,
                      size: 16,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(TontineUi.inviteMethodLabel(context, method)),
                  ],
                ),
                labelStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isSelected
                      ? Colors.white
                      : const Color(0xFF334155),
                ),
                selectedColor: const Color(0xFF2563EB),
                backgroundColor: const Color(0xFFF1F5F9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                onSelected: (_) => setState(() {
                  _inviteMethod = method;
                  _inviteQueryController.clear();
                }),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _inviteMethod == CircleInviteMethod.email
                  ? TextField(
                      controller: _inviteQueryController,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      decoration: _inputDeco(
                        icon: Icons.alternate_email_rounded,
                        hint: l10n.tontineInviteEmail,
                      ),
                    )
                  : IntlPhoneField(
                      initialCountryCode: 'US',
                      disableLengthCheck: true,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (p) =>
                          PhoneNationalInputValidation.validateOptionalNational(
                        p,
                        l10n.phoneInternationalSubscriberInvalid,
                      ),
                      onChanged: (phone) {
                        _inviteQueryController.text = phone.completeNumber;
                      },
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      decoration: _inputDeco(
                        icon: Icons.phone_outlined,
                        hint: l10n.tontineInvitePhone,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _addParticipant,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Icon(Icons.person_add_rounded, size: 22),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Member count badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _participants.length == _targetMemberCount && _targetMemberCount > 0
                ? const Color(0xFFDCFCE7)
                : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _participants.length == _targetMemberCount && _targetMemberCount > 0
                    ? Icons.check_circle_rounded
                    : Icons.group_rounded,
                size: 18,
                color: _participants.length == _targetMemberCount && _targetMemberCount > 0
                    ? const Color(0xFF15803D)
                    : const Color(0xFFD97706),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.tontineParticipantsAdded(
                    _participants.length, _targetMemberCount),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: _participants.length == _targetMemberCount && _targetMemberCount > 0
                      ? const Color(0xFF15803D)
                      : const Color(0xFFD97706),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...invitedParticipants.map(
          (participant) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F766E), Color(0xFF10B981)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        TontineUi.initialsForName(participant.displayName),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          participant.displayName,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          participant.contactInfo,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        setState(() {
                          _participants.remove(participant);
                        });
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.close_rounded,
                            color: Color(0xFFDC2626), size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderStep(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_participants.length != _targetMemberCount) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFD97706), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                l10n.tontineNeedAllMembersBeforeOrdering,
                style: GoogleFonts.inter(
                  color: const Color(0xFF92400E),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.swap_vert_rounded,
                size: 16, color: Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            Text(
              l10n.tontineReorderHint,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 360,
          child: ReorderableListView.builder(
            padding: EdgeInsets.zero,
            buildDefaultDragHandles: false,
            itemCount: _participants.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final participant = _participants.removeAt(oldIndex);
                _participants.insert(newIndex, participant);
              });
            },
            proxyDecorator: (child, index, animation) {
              return Material(
                elevation: 6,
                color: Colors.transparent,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(16),
                child: child,
              );
            },
            itemBuilder: (context, index) {
              final participant = _participants[index];
              final isCreator = participant.isCreator;
              return Container(
                key: ValueKey(participant.userId.isNotEmpty
                    ? participant.userId
                    : participant.contactInfo),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isCreator
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCreator
                        ? const Color(0xFFBBF7D0)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isCreator
                            ? [
                                const Color(0xFF15803D),
                                const Color(0xFF22C55E)
                              ]
                            : [
                                const Color(0xFF1D4ED8),
                                const Color(0xFF3B82F6)
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    participant.displayName,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    isCreator ? l10n.tontineYou : participant.contactInfo,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                  trailing: ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.drag_handle_rounded,
                          color: Color(0xFF94A3B8)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _loadCreator() async {
    try {
      final creator = await TontineService.getCurrentUserLookup();
      if (!mounted) return;
      setState(() {
        _participants.add(
          _DraftParticipant(
            userId: creator.userId,
            displayName: creator.displayName,
            photoUrl: creator.photoUrl,
            contactInfo: creator.phoneNumber.isNotEmpty
                ? creator.phoneNumber
                : creator.email,
            isCreator: true,
          ),
        );
        _isLoadingCreator = false;
      });
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tontineUnableToLoadProfile)),
      );
      setState(() {
        _isLoadingCreator = false;
      });
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
    });
  }

  bool _validateAll() {
    final l10n = AppLocalizations.of(context)!;

    // Basics
    if (_titleController.text.trim().isEmpty) {
      _showMessage(l10n.tontineCircleNameRequired);
      return false;
    }
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showMessage(l10n.tontineEnterValidAmount);
      return false;
    }
    if (_targetMemberCount < 2) {
      _showMessage(l10n.tontineMinimumMembers);
      return false;
    }

    // Rules
    final grace = int.tryParse(_gracePeriodController.text.trim());
    if (grace == null || grace < 0) {
      _showMessage(l10n.tontineInvalidGracePeriod);
      return false;
    }
    if (_paymentInstructionsController.text.trim().isEmpty) {
      _showMessage(l10n.tontinePaymentInstructionsRequired);
      return false;
    }

    // Invites
    if (_participants.length != _targetMemberCount) {
      _showMessage(l10n.tontineNeedExactMemberCount);
      return false;
    }

    return true;
  }

  Future<void> _addParticipant() async {
    final l10n = AppLocalizations.of(context)!;
    final query = _inviteQueryController.text.trim();
    if (query.isEmpty) {
      _showMessage(l10n.tontineEnterInviteLookup);
      return;
    }
    if (_inviteMethod == CircleInviteMethod.phone) {
      if (!PhoneNationalInputValidation.isValidInternationalString(query)) {
        _showMessage(l10n.enrollmentPhoneInvalid);
        return;
      }
    }
    if (_participants.length >= _targetMemberCount) {
      _showMessage(l10n.tontineMemberCountReached);
      return;
    }

    final lookup = await TontineService.searchExistingUser(
      query,
      method: _inviteMethod,
    );
    if (!mounted) return;

    if (lookup != null) {
      if (_participants
          .any((participant) => participant.userId == lookup.userId)) {
        _showMessage(l10n.tontineUserAlreadyAdded);
        return;
      }

      final contactInfo = _inviteMethod == CircleInviteMethod.email
          ? lookup.email
          : lookup.phoneNumber;
      if (contactInfo.isEmpty) {
        _showMessage(l10n.tontineSelectedMethodUnavailable);
        return;
      }

      setState(() {
        _participants.add(
          _DraftParticipant(
            userId: lookup.userId,
            displayName: lookup.displayName,
            photoUrl: lookup.photoUrl,
            contactInfo: contactInfo,
            isCreator: false,
            inviteMethod: _inviteMethod,
          ),
        );
        _inviteQueryController.clear();
      });
    } else {
      if (_participants.any((p) => p.contactInfo == query)) {
        _showMessage(l10n.tontineUserAlreadyAdded);
        return;
      }

      setState(() {
        _participants.add(
          _DraftParticipant(
            userId: '',
            displayName: query,
            photoUrl: null,
            contactInfo: query,
            isCreator: false,
            inviteMethod: _inviteMethod,
          ),
        );
        _inviteQueryController.clear();
      });
    }
  }

  Future<void> _createCircle() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_validateAll()) return;
    setState(() {
      _isCreating = true;
    });

    try {
      final circleId = await TontineService.createCircle(
        title: _titleController.text.trim(),
        type: CircleType.open,
        contributionAmount: double.parse(_amountController.text.trim()),
        currency: 'USD',
        frequency: _frequency,
        startDate: _startDate,
        rules: CircleRules(
          gracePeriodDays: int.parse(_gracePeriodController.text.trim()),
          missedPaymentAction: _missedAction,
        ),
        paymentInstructions: _paymentInstructionsController.text.trim(),
        participantsInOrder: _participants
            .map(
              (participant) => TontineParticipantDraft(
                userId: participant.userId,
                displayName: participant.displayName,
                photoUrl: participant.photoUrl,
                contactInfo: participant.contactInfo,
                isCreator: participant.isCreator,
                inviteMethod: participant.inviteMethod,
              ),
            )
            .toList(),
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => CircleDashboardScreen(circleId: circleId),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(l10n.tontineCreateFailed(error.toString()));
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DraftParticipant {
  final String userId;
  final String displayName;
  final String? photoUrl;
  final String contactInfo;
  final bool isCreator;
  final CircleInviteMethod? inviteMethod;

  const _DraftParticipant({
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    required this.contactInfo,
    required this.isCreator,
    this.inviteMethod,
  });
}

class _FreqOption {
  final String label;
  final IconData icon;
  const _FreqOption(this.label, this.icon);
}

class _InfoSheet extends StatelessWidget {
  final String title;
  final String message;

  const _InfoSheet({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: 44,
            height: 44,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFF14B8A6),
              size: 24,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF64748B),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: const Color(0xFFF1F5F9),
              ),
              child: Text(
                'Got it',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
