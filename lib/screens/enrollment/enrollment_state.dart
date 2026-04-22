part of 'enrollment_coordinator.dart';

// Helper class for time ranges
class _TimeRange {
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  const _TimeRange({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });
}

// Helper class for student input (multi-student support with individual program)
class _StudentInput {
  final TextEditingController nameController;
  final TextEditingController ageController;
  String? gender;

  // Individual program details for each student
  String? subject;
  String? specificLanguage;
  String? level;
  String? classType;
  String? sessionDuration;
  int? hoursPerWeek;
  String? timeOfDayPreference;
  List<String> selectedDays;
  List<String> selectedTimeSlots;
  List<String> customTimeSlots;
  bool useCustomSchedule;

  _StudentInput()
      : nameController = TextEditingController(),
        ageController = TextEditingController(),
        gender = null,
        subject = null,
        specificLanguage = null,
        level = null,
        classType = null,
        sessionDuration = null,
        hoursPerWeek = null,
        timeOfDayPreference = null,
        selectedDays = [],
        selectedTimeSlots = [],
        customTimeSlots = [],
        useCustomSchedule = false;

  void dispose() {
    nameController.dispose();
    ageController.dispose();
  }
}

mixin EnrollmentStateMixin on State<EnrollmentCoordinator>, TickerProvider {
  static const String _islamicSubject =
      'Islamic Program (Arabic, Quran, etc...)';
  static const String _afroLanguagesSubject =
      'AfroLanguages (Pular, Mandingo, Swahili, Wolof, etc...)';
  static const String _afterSchoolSubject =
      'After School Tutoring (Math, Science, Physics, etc...)';
  static const String _adultLiteracySubject =
      'Adult Literacy (Reading and Writing English & French, etc...)';

  final _formKey = GlobalKey<FormState>();
  late AnimationController _progressController;
  late AnimationController _cardController;
  final ScrollController _rightPaneScroll = ScrollController();
  int _currentStep = 0;

  // Controllers
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _whatsAppNumberController = TextEditingController();
  final _studentNameController = TextEditingController();
  final _studentAgeController = TextEditingController();
  final _parentIdentityController = TextEditingController();
  final _schedulingNotesController = TextEditingController();

  // State variables
  bool _isCheckingIdentity = false;
  Map<String, dynamic>? _linkedParentData;
  String? _guardianId;

  String? _selectedSubject;
  String? _selectedGrade;
  String? _selectedAfricanLanguage;
  Country? _selectedCountry;
  String _phoneNumber = '';
  String _ianaTimeZone = 'UTC';
  String _initialCountryCode = 'US';
  String _phoneIntlCountryCode = 'US';
  String _whatsAppIntlCountryCode = 'US';
  bool _isSubmitting = false;

  // Enhanced form fields
  String? _role;
  String? _preferredLanguage;
  String _whatsAppNumber = '';
  String? _gender;
  String? _classType;
  String? _sessionDuration;
  int? _hoursPerWeek;
  String? _timeOfDayPreference;
  String? _selectedLevel;

  // Multi-student support
  final List<_StudentInput> _students = [];
  bool _applyProgramToAll = true;
  int _activeProgramTab = 0;
  /// Selected student on step 1 (0 = first child, 1..n = [_students] entries).
  int _activeStudentProfileTab = 0;
  bool _enrollmentSummaryExpanded = true;
  bool _showDetailedTimeSlots = true;
  bool _stepForward = true;

  /// When not from landing pricing CTA ([initialPricingPlanId] is null).
  String? _pickedPricingPlanId;
  String? _selectedTrackId;

  /// CMS USD overrides for tier cards (same source as landing / admin).
  PublicSiteCmsPricingDoc _pricingCms = const PublicSiteCmsPricingDoc();

  // Available options
  final List<String> _subjects = [
    _islamicSubject,
    kGroupClassesSubject,
    _afroLanguagesSubject,
    'Entrepreneurship',
    'Coding',
    _afterSchoolSubject,
    _adultLiteracySubject,
  ];

  final List<String> _otherAfricanLanguages = [
    'Pular',
    'Mandingo',
    'Swahili',
    'Wolof',
    'Hausa',
    'Yoruba',
    'Adlam',
    'Amharic',
    'Other'
  ];

  // Program level options (for non-After School programs)
  final List<String> _programLevelOptions = [
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  // After School level options
  final List<String> _afterSchoolLevelOptions = [
    'Elementary School',
    'Middle School',
    'High School',
    'University',
  ];

  /// Normalizes route/CMS strings and tutoring language rows to values used in
  /// [_subjects], [_trackForSubject], and dropdowns.
  String? _canonicalProgramSubject(String? raw) {
    final input = raw?.trim();
    if (input == null || input.isEmpty) return null;
    if (_subjects.contains(input)) return input;
    const tutoringLangSingletons = {'English', 'French', 'Adlam'};
    if (tutoringLangSingletons.contains(input)) return input;
    return _resolveInitialSubject(input);
  }

  String? _resolveInitialSubject(String? raw) {
    final input = raw?.trim();
    if (input == null || input.isEmpty) return null;
    if (_subjects.contains(input)) return input;

    final normalized = input.toLowerCase();
    if (normalized.contains('islamic') ||
        normalized.contains('quran') ||
        normalized.contains('arabic')) {
      return _islamicSubject;
    }
    if (normalized.contains('afro') ||
        normalized.contains('adlam') ||
        normalized.contains('language') ||
        normalized.contains('pular') ||
        normalized.contains('mandingo') ||
        normalized.contains('swahili') ||
        normalized.contains('wolof')) {
      return _afroLanguagesSubject;
    }
    if (normalized.contains('adult literacy') ||
        normalized == 'english' ||
        normalized == 'french') {
      return _adultLiteracySubject;
    }
    if (normalized.contains('coding') ||
        normalized.contains('programming') ||
        normalized == 'math' ||
        normalized.contains('science') ||
        normalized.contains('physics') ||
        normalized.contains('chemistry') ||
        normalized.contains('after school')) {
      return _afterSchoolSubject;
    }
    if (normalized.contains('entrepreneur')) {
      return 'Entrepreneurship';
    }
    if (normalized.contains('starter') ||
        normalized.contains('standard') ||
        normalized.contains('family')) {
      return _afterSchoolSubject;
    }
    if (normalized.contains('group class') ||
        (normalized.contains('group') && normalized.contains('weekend')) ||
        normalized.contains('small group')) {
      return kGroupClassesSubject;
    }
    return null;
  }

  /// Islamic tiers → Islamic program; tutoring tiers → after-school.
  String? _subjectForPricingPlanId(String planId) {
    switch (planId) {
      case PricingPlanIds.islamic14:
      case PricingPlanIds.islamicWeekend:
        return kGroupClassesSubject;
      case PricingPlanIds.tutoring5Plus:
      case PricingPlanIds.tutoring13:
      case PricingPlanIds.tutoring4Plus:
        return _afterSchoolSubject;
    }
    return null;
  }

  String _displayLabelForPricingPlan(AppLocalizations l, String planId) {
    switch (planId) {
      case PricingPlanIds.islamic14:
        return l.pricingTrackIslamicTitle;
      case PricingPlanIds.islamicWeekend:
        return l.pricingTrackGroupTitle;
      case PricingPlanIds.tutoring5Plus:
      case PricingPlanIds.tutoring13:
      case PricingPlanIds.tutoring4Plus:
        return l.pricingTrackTutoringTitle;
    }
    return planId;
  }

  /// Landing CTA plan or in-form tier choice.
  String? get _resolvedPricingPlanId =>
      widget.initialPricingPlanId ?? _pickedPricingPlanId;

  String? get _resolvedTrackId =>
      widget.initialTrackId ??
      _selectedTrackId ??
      legacyToTrack(_resolvedPricingPlanId);

  /// Track for banner, shared hours estimate, and tier cards.
  String? get _quoteTrackId =>
      _trackForSubject(_selectedSubject) ?? _resolvedTrackId;

  String _shortProgramLabelFromSubject(String? subject) {
    final l = AppLocalizations.of(context)!;
    if (subject == null || subject.isEmpty) return '—';
    final t = _trackForSubject(subject);
    if (t == PricingPlanIds.islamic) return l.pricingTrackIslamicTitle;
    if (t == PricingPlanIds.tutoring) return l.pricingTrackTutoringTitle;
    if (t == PricingPlanIds.group) return l.pricingTrackGroupTitle;
    return subject;
  }

  String _monthlyEstimatePriceLabel(String? trackId, int hours) {
    if (trackId == null) return '—';
    final h = hours.clamp(1, 8);
    final snap = PricingQuoteService.buildSnapshotV2(
      trackId: trackId,
      hoursPerWeek: h,
      cmsOverrides: _pricingCms.planOverridesForQuotes(),
    );
    if (snap == null) return '—';
    final v = snap['monthlyEstimateUsd'] as double;
    return '\$${v.toStringAsFixed(0)}/mo';
  }

  double? _monthlyEstimateRaw(String? trackId, int hours) {
    if (trackId == null || hours < 1) return null;
    final h = hours.clamp(1, 8);
    final snap = PricingQuoteService.buildSnapshotV2(
      trackId: trackId,
      hoursPerWeek: h,
      cmsOverrides: _pricingCms.planOverridesForQuotes(),
    );
    return snap?['monthlyEstimateUsd'] as double?;
  }

  int get _totalHoursPerWeek {
    final globalH = _hoursPerWeek ?? 0;
    if (!_isParentGuardian || _students.isEmpty) return globalH;
    int total = globalH;
    for (final s in _students) {
      total += s.hoursPerWeek ?? globalH;
    }
    return total;
  }

  String _totalMonthlyEstimateLabel() {
    final numStudents = 1 + _students.length;
    if (!_isParentGuardian || _students.isEmpty) {
      return _monthlyEstimatePriceLabel(_quoteTrackId, _hoursPerWeek ?? 0);
    }
    if (_applyProgramToAll) {
      final perStudent = _monthlyEstimateRaw(_quoteTrackId, _hoursPerWeek ?? 0);
      if (perStudent == null) return '—';
      return '\$${(perStudent * numStudents).toStringAsFixed(0)}/mo';
    }
    double total = 0;
    final h1 = _hoursPerWeek ?? 0;
    final t1 = _trackForSubject(_selectedSubject) ?? _quoteTrackId;
    final p1 = _monthlyEstimateRaw(t1, h1);
    if (p1 == null) return '—';
    total += p1;
    for (final s in _students) {
      final h = s.hoursPerWeek ?? h1;
      final tr = _trackForSubject(s.subject) ?? _quoteTrackId;
      final p = _monthlyEstimateRaw(tr, h);
      if (p == null) return '—';
      total += p;
    }
    return '\$${total.toStringAsFixed(0)}/mo';
  }

  List<EnrollmentSummaryLine> _buildEnrollmentSummaryLines() {
    final l = AppLocalizations.of(context)!;
    final parentMulti =
        (_role == 'Parent' || _role == 'Guardian') && _students.isNotEmpty;

    if (!parentMulti) {
      final name = _studentNameController.text.trim().isEmpty
          ? l.studentDefaultName1
          : _studentNameController.text.trim();
      final hours = _hoursPerWeek ?? 1;
      final track = _trackForSubject(_selectedSubject) ?? _quoteTrackId;
      final detail = l.enrollmentSummaryLineDetail(
        _shortProgramLabelFromSubject(_selectedSubject),
        hours,
        _monthlyEstimatePriceLabel(track, hours),
      );
      return [EnrollmentSummaryLine(title: name, detail: detail)];
    }

    // One "All children" line only when the flag is on *and* every child truly
    // matches the first child's program bundle. Otherwise list each child
    // (fixes stale _applyProgramToAll after per-child edits).
    if (_applyProgramToAll && !_perChildProgramBundlesDifferFromFirst()) {
      final n = 1 + _students.length;
      final hours = _hoursPerWeek ?? 1;
      final track = _trackForSubject(_selectedSubject) ?? _quoteTrackId;
      final detail = l.enrollmentSummaryLineDetail(
        _shortProgramLabelFromSubject(_selectedSubject),
        hours,
        _monthlyEstimatePriceLabel(track, hours),
      );
      return [
        EnrollmentSummaryLine(
          title: l.enrollmentSummaryAllChildrenTitle(n),
          detail: detail,
        ),
      ];
    }

    final lines = <EnrollmentSummaryLine>[];
    final h1 = _hoursPerWeek ?? 1;
    final t1 = _trackForSubject(_selectedSubject) ?? _quoteTrackId;
    lines.add(EnrollmentSummaryLine(
      title: _studentNameController.text.trim().isEmpty
          ? l.studentDefaultName1
          : _studentNameController.text.trim(),
      detail: l.enrollmentSummaryLineDetail(
        _shortProgramLabelFromSubject(_selectedSubject),
        h1,
        _monthlyEstimatePriceLabel(t1, h1),
      ),
    ));
    for (var i = 0; i < _students.length; i++) {
      final s = _students[i];
      final nm = s.nameController.text.trim().isEmpty
          ? 'Student ${i + 2}'
          : s.nameController.text.trim();
      final h = s.hoursPerWeek ?? _hoursPerWeek ?? 1;
      final subj = s.subject ?? _selectedSubject;
      final tr = _trackForSubject(subj) ?? _quoteTrackId;
      lines.add(EnrollmentSummaryLine(
        title: nm,
        detail: l.enrollmentSummaryLineDetail(
          _shortProgramLabelFromSubject(subj),
          h,
          _monthlyEstimatePriceLabel(tr, h),
        ),
      ));
    }
    return lines;
  }

  /// True when any additional child differs from the first child's resolved
  /// program (subject, Afro language, level, class type, or weekly hours).
  bool _perChildProgramBundlesDifferFromFirst() {
    for (final s in _students) {
      final subj = s.subject ?? _selectedSubject;
      if (_canonicalProgramSubject(subj) !=
          _canonicalProgramSubject(_selectedSubject)) {
        return true;
      }
      if (subj == _afroLanguagesSubject) {
        final la = s.specificLanguage ?? _selectedAfricanLanguage;
        if (la != _selectedAfricanLanguage) return true;
      }
      if ((s.level ?? _selectedLevel) != _selectedLevel) return true;
      if ((s.classType ?? _classType) != _classType) return true;
      final h = s.hoursPerWeek ?? _hoursPerWeek;
      if (h != _hoursPerWeek) return true;
    }
    return false;
  }

  String _reviewStudentSlotName(int slot, AppLocalizations l) {
    if (slot == 0) {
      final t = _studentNameController.text.trim();
      return t.isEmpty ? l.studentDefaultName1 : t;
    }
    final s = _students[slot - 1];
    final t = s.nameController.text.trim();
    return t.isEmpty ? 'Student ${slot + 1}' : t;
  }

  String? _programSubjectForReviewSlot(int slot) =>
      slot == 0 ? _selectedSubject : (_students[slot - 1].subject ?? _selectedSubject);

  String? _programLevelForReviewSlot(int slot) =>
      slot == 0 ? _selectedLevel : (_students[slot - 1].level ?? _selectedLevel);

  String? _programClassTypeForReviewSlot(int slot) =>
      slot == 0 ? _classType : (_students[slot - 1].classType ?? _classType);

  int _programHoursForReviewSlot(int slot) {
    final h = slot == 0
        ? _hoursPerWeek
        : (_students[slot - 1].hoursPerWeek ?? _hoursPerWeek);
    return (h ?? 1).clamp(1, 8);
  }

  List<String> _sortedDayList(List<String> xs) => List<String>.from(xs)..sort();

  bool _dayListsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final sa = _sortedDayList(a);
    final sb = _sortedDayList(b);
    for (var i = 0; i < sa.length; i++) {
      if (sa[i] != sb[i]) return false;
    }
    return true;
  }

  bool _slotListsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final sa = List<String>.from(a)..sort();
    final sb = List<String>.from(b)..sort();
    for (var i = 0; i < sa.length; i++) {
      if (sa[i] != sb[i]) return false;
    }
    return true;
  }

  List<String> _daysForScheduleReviewSlot(int slot) {
    if (slot == 0) return List<String>.from(_selectedDays);
    final s = _students[slot - 1];
    return List<String>.from(
        s.useCustomSchedule ? s.selectedDays : _selectedDays);
  }

  List<String> _slotsForScheduleReviewSlot(int slot) {
    if (slot == 0) return List<String>.from(_selectedTimeSlots);
    final s = _students[slot - 1];
    return List<String>.from(
        s.useCustomSchedule ? s.selectedTimeSlots : _selectedTimeSlots);
  }

  String? _todForScheduleReviewSlot(int slot) {
    if (slot == 0) return _timeOfDayPreference;
    final s = _students[slot - 1];
    return s.timeOfDayPreference ?? _timeOfDayPreference;
  }

  bool _allHouseholdStudentsShareSameSchedule() {
    if (!_isParentGuardian || _students.isEmpty) return true;
    final d0 = _daysForScheduleReviewSlot(0);
    final sl0 = _slotsForScheduleReviewSlot(0);
    final t0 = _todForScheduleReviewSlot(0);
    for (var slot = 1; slot < 1 + _students.length; slot++) {
      if (!_dayListsEqual(d0, _daysForScheduleReviewSlot(slot))) {
        return false;
      }
      if (!_slotListsEqual(sl0, _slotsForScheduleReviewSlot(slot))) {
        return false;
      }
      if (_todForScheduleReviewSlot(slot) != t0) return false;
    }
    return true;
  }

  String _abbrevDaysLine(List<String> days) {
    if (days.isEmpty) return '';
    return days.map((d) => d.length > 3 ? d.substring(0, 3) : d).join(', ');
  }

  /// Resolves a stored pricing plan id (legacy or V2 track) to a V2 track id.
  String? _planIdToTierTrack(String planId) {
    if (planId == PricingPlanIds.islamic ||
        planId == PricingPlanIds.tutoring ||
        planId == PricingPlanIds.group) {
      return planId;
    }
    return legacyToTrack(planId);
  }

  /// Whether [subject] belongs on the same V2 track as the tier chosen at checkout.
  bool _subjectMatchesPricingPlan(String? subject, String planId) {
    final canon = _canonicalProgramSubject(subject);
    if (canon == null || canon.isEmpty) return true;
    final tier = _planIdToTierTrack(planId);
    if (tier == null) return true;
    final st = _trackForSubject(canon);
    if (st == null) return false;
    return st == tier;
  }

  ({String? id, String? label}) _pricingPlanForSubmit() {
    final qt = _quoteTrackId;
    final String? id;
    if (qt != null &&
        widget.initialPricingPlanId != null &&
        legacyToTrack(widget.initialPricingPlanId) == qt) {
      id = widget.initialPricingPlanId;
    } else if (qt != null) {
      id = _defaultLegacyPlanForTrack(qt);
    } else {
      id = _resolvedPricingPlanId;
    }
    if (id == null) {
      return (id: null, label: widget.initialPricingPlanSummary);
    }
    final l = AppLocalizations.of(context)!;
    final landingTrack = legacyToTrack(widget.initialPricingPlanId);
    final label = (widget.initialPricingPlanSummary != null &&
            widget.initialPricingPlanId != null &&
            qt == landingTrack)
        ? (widget.initialPricingPlanSummary ??
            _displayLabelForPricingPlan(l, id))
        : _displayLabelForPricingPlan(l, id);
    return (id: id, label: label);
  }

  String _defaultLegacyPlanForTrack(String trackId) {
    switch (trackId) {
      case PricingPlanIds.islamic:
        return PricingPlanIds.islamic14;
      case PricingPlanIds.group:
        return PricingPlanIds.islamicWeekend;
      case PricingPlanIds.tutoring:
      default:
        return PricingPlanIds.tutoring13;
    }
  }

  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final List<String> _selectedDays = [];

  static const Map<String, _TimeRange> _timeRanges = {
    'Morning':
        _TimeRange(startHour: 6, startMinute: 0, endHour: 12, endMinute: 0),
    'Afternoon':
        _TimeRange(startHour: 12, startMinute: 0, endHour: 17, endMinute: 0),
    'Evening':
        _TimeRange(startHour: 17, startMinute: 0, endHour: 21, endMinute: 0),
  };

  final List<String> _selectedTimeSlots = [];
  final List<String> _customTimeSlots = [];

  List<String> get _allTimeSlots =>
      [..._filteredTimeSlots, ..._customTimeSlots];

  List<String> get _filteredTimeSlots =>
      _getFilteredTimeSlotsFor(_sessionDuration, _timeOfDayPreference);

  String? _durationFromHoursPerWeek(int? hoursPerWeek) {
    if (hoursPerWeek == null || hoursPerWeek < 1) return null;
    final bounded = hoursPerWeek > 4 ? 4 : hoursPerWeek;
    return bounded == 1 ? '1 hr' : '$bounded hrs';
  }

  /// Returns time slots for a given duration and time-of-day.
  List<String> _getFilteredTimeSlotsFor(String? duration, String? timeOfDay) {
    if (duration == null) return [];
    if (timeOfDay == null) return [];
    if (timeOfDay == 'Flexible') {
      return ['8 AM - 12 PM', '12 PM - 4 PM', '4 PM - 8 PM', '8 PM - 12 AM'];
    }
    final timeRange = _timeRanges[timeOfDay];
    if (timeRange == null) return [];
    final durationMinutes = _parseDurationToMinutes(duration);
    if (durationMinutes == null) return [];
    return _generateTimeSlots(
      startHour: timeRange.startHour,
      startMinute: timeRange.startMinute,
      endHour: timeRange.endHour,
      endMinute: timeRange.endMinute,
      durationMinutes: durationMinutes,
    );
  }

  int? _parseDurationToMinutes(String duration) {
    if (duration.contains('1 hr 30')) return 90;
    if (duration.contains('2 hr 30')) return 150;
    if (duration.contains('30 mins')) return 30;
    if (duration.contains('1 hr')) return 60;
    if (duration.contains('2 hrs')) return 120;
    if (duration.contains('3 hrs')) return 180;
    if (duration.contains('4 hrs')) return 240;
    return null;
  }

  List<String> _generateTimeSlots({
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    required int durationMinutes,
  }) {
    final slots = <String>[];
    final startTotalMinutes = startHour * 60 + startMinute;
    final endTotalMinutes = endHour * 60 + endMinute;
    int currentMinutes = startTotalMinutes;
    while (currentMinutes + durationMinutes <= endTotalMinutes) {
      final startTime = _formatTimeFromMinutes(currentMinutes);
      final endTime = _formatTimeFromMinutes(currentMinutes + durationMinutes);
      slots.add('$startTime - $endTime');
      currentMinutes += durationMinutes;
    }
    return slots;
  }

  String _formatTimeFromMinutes(int totalMinutes) {
    final wrapped = totalMinutes % (24 * 60);
    final hours = wrapped ~/ 60;
    final minutes = wrapped % 60;
    final period = hours >= 12 ? 'PM' : 'AM';
    var hour12 = hours % 12;
    if (hour12 == 0) {
      hour12 = 12;
    }
    final minuteStr = minutes.toString().padLeft(2, '0');
    return '$hour12:$minuteStr $period';
  }

  String _formatCustomRangeSlot(TimeOfDay start, TimeOfDay end) {
    final startM = start.hour * 60 + start.minute;
    final endM = end.hour * 60 + end.minute;
    return '${_formatTimeFromMinutes(startM)} - ${_formatTimeFromMinutes(endM)}';
  }

  Future<void> _addCustomTimeSlot() async {
    final l = AppLocalizations.of(context)!;
    if (_sessionDuration == null) return;
    final durationMinutes = _parseDurationToMinutes(_sessionDuration!);
    if (durationMinutes == null) return;
    final now = DateTime.now();
    final initialStart =
        TimeOfDay(hour: now.hour, minute: (now.minute ~/ 15) * 15);
    final pickedStart = await showTimePicker(
      context: context,
      initialTime: initialStart,
      helpText: l.enrollmentScheduleDetailedSlotsTitle,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xff3B82F6),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (pickedStart == null || !mounted) return;
    final startM = pickedStart.hour * 60 + pickedStart.minute;
    final initialEndM = (startM + durationMinutes) % (24 * 60);
    final initialEnd =
        TimeOfDay(hour: initialEndM ~/ 60, minute: initialEndM % 60);
    final pickedEnd = await showTimePicker(
      context: context,
      initialTime: initialEnd,
      helpText: l.enrollmentCustomTimePickEndTitle,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xff3B82F6),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (pickedEnd == null || !mounted) return;
    final endM = pickedEnd.hour * 60 + pickedEnd.minute;
    if (endM <= startM) {
      _showSnackBar(l.enrollmentCustomTimeInvalidRange, isError: true);
      return;
    }
    final slot = _formatCustomRangeSlot(pickedStart, pickedEnd);
    if (_customTimeSlots.contains(slot)) return;
    setState(() {
      _customTimeSlots.add(slot);
      _selectedTimeSlots.add(slot);
    });
  }

  Future<void> _addCustomTimeSlotForStudent(_StudentInput s) async {
    final l = AppLocalizations.of(context)!;
    final duration = s.sessionDuration ?? _sessionDuration;
    if (duration == null) return;
    final durationMinutes = _parseDurationToMinutes(duration);
    if (durationMinutes == null) return;
    final now = DateTime.now();
    final initialStart =
        TimeOfDay(hour: now.hour, minute: (now.minute ~/ 15) * 15);
    final pickedStart = await showTimePicker(
      context: context,
      initialTime: initialStart,
      helpText: l.enrollmentScheduleDetailedSlotsTitle,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xff3B82F6),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (pickedStart == null || !mounted) return;
    final startM = pickedStart.hour * 60 + pickedStart.minute;
    final initialEndM = (startM + durationMinutes) % (24 * 60);
    final initialEnd =
        TimeOfDay(hour: initialEndM ~/ 60, minute: initialEndM % 60);
    final pickedEnd = await showTimePicker(
      context: context,
      initialTime: initialEnd,
      helpText: l.enrollmentCustomTimePickEndTitle,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xff3B82F6),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (pickedEnd == null || !mounted) return;
    final endM = pickedEnd.hour * 60 + pickedEnd.minute;
    if (endM <= startM) {
      _showSnackBar(l.enrollmentCustomTimeInvalidRange, isError: true);
      return;
    }
    final slot = _formatCustomRangeSlot(pickedStart, pickedEnd);
    if (s.customTimeSlots.contains(slot)) return;
    setState(() {
      s.customTimeSlots.add(slot);
      s.selectedTimeSlots.add(slot);
    });
  }

  final List<String> _languages = ['English', 'French', 'Arabic', 'Other'];
  final List<String> _classTypes = ['One-on-One', 'Group', 'Both'];

  @override
  void initState() {
    super.initState();
    _selectedSubject = _canonicalProgramSubject(widget.initialSubject);
    if (_selectedSubject == null && widget.initialPricingPlanId != null) {
      _selectedSubject = _subjectForPricingPlanId(widget.initialPricingPlanId!);
    }
    if (widget.initialTrackId != null) {
      _selectedTrackId = widget.initialTrackId;
      _pickedPricingPlanId = _defaultLegacyPlanForTrack(widget.initialTrackId!);
      _selectedSubject ??= _defaultSubjectForTrack(widget.initialTrackId!);
    } else if (widget.initialPricingPlanId != null) {
      _selectedTrackId = legacyToTrack(widget.initialPricingPlanId);
    }
    _hoursPerWeek = (widget.initialHoursPerWeek ?? 1).clamp(1, 8);
    _sessionDuration = _durationFromHoursPerWeek(_hoursPerWeek);
    _selectedAfricanLanguage = widget.initialAfricanLanguage;
    final extraStudents = widget.initialAdditionalStudents.clamp(0, 7);
    for (var i = 0; i < extraStudents; i++) {
      _students.add(_StudentInput());
    }
    _selectedCountry = Country.parse('US');
    _initialCountryCode = 'US';
    _phoneIntlCountryCode = _initialCountryCode;
    _whatsAppIntlCountryCode = _initialCountryCode;

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _cardController.forward();

    _initTimezone();

    PublicSiteCmsService.getPricingDoc().then((doc) {
      if (mounted) setState(() => _pricingCms = doc);
    });
  }

  Future<void> _initTimezone() async {
    try {
      final dynamic timezoneInfo = await FlutterTimezone.getLocalTimezone();
      String currentTimeZone;
      if (timezoneInfo is String) {
        currentTimeZone = timezoneInfo;
      } else {
        currentTimeZone = timezoneInfo.identifier as String;
      }
      if (mounted) {
        setState(() {
          _ianaTimeZone = currentTimeZone;
        });
      }
    } catch (e) {
      debugPrint('Could not get IANA timezone: $e');
      if (mounted) {
        setState(() {
          _ianaTimeZone = 'UTC';
        });
      }
    }
  }

  Future<void> _checkParentIdentity() async {
    final identifier = _parentIdentityController.text.trim();
    if (identifier.isEmpty) {
      _showSnackBar('Please enter an email or kiosque code to link account',
          isError: true);
      return;
    }

    setState(() => _isCheckingIdentity = true);

    try {
      final result = await EnrollmentService().checkParentIdentity(identifier);

      if (!mounted) return;

      if (result['found'] == true) {
        setState(() {
          _linkedParentData = result;
          _guardianId = result['userId'] as String?;
          _parentNameController.text =
              '${result['firstName'] ?? ''} ${result['lastName'] ?? ''}'.trim();
          _emailController.text = (result['email'] as String?) ?? '';
          _phoneController.text = (result['phone'] as String?) ?? '';
          _phoneNumber = (result['phone'] as String?) ?? '';
        });
        _showSnackBar('Account linked successfully!', isSuccess: true);
      } else if (result['error'] != null) {
        // Server/network error - distinct from "not found"
        _showSnackBar(
            'Could not verify account right now. Please try again.',
            isError: true);
      } else {
        _showSnackBar(
            'No parent account found with that email or kiosque code',
            isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error checking identity: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isCheckingIdentity = false);
    }
  }

  void _showSnackBar(String message,
      {bool isSuccess = false, bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess
                  ? Icons.check_circle
                  : isError
                      ? Icons.error
                      : Icons.info,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess
            ? const Color(0xff059669)
            : isError
                ? const Color(0xffDC2626)
                : const Color(0xff3B82F6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _unlinkParent() {
    setState(() {
      _linkedParentData = null;
      _guardianId = null;
      _parentNameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _parentIdentityController.clear();
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _cardController.dispose();
    _rightPaneScroll.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _parentNameController.dispose();
    _cityController.dispose();
    _whatsAppNumberController.dispose();
    _studentNameController.dispose();
    _studentAgeController.dispose();
    _parentIdentityController.dispose();
    _schedulingNotesController.dispose();
    for (final student in _students) {
      student.dispose();
    }
    super.dispose();
  }

  // ─── Navigation ─────────────────────────────────────────────────────

  void _scrollRightPaneToTop() {
    if (_rightPaneScroll.hasClients) {
      _rightPaneScroll.jumpTo(0);
    }
  }

  void _nextStep() {
    if (!_validateCurrentStep()) return;
    if (_currentStep < kEnrollmentFlowSubmitStepIndex) {
      _stepForward = true;
      _cardController.reverse().then((_) {
        setState(() {
          final fromStep = _currentStep;
          _currentStep++;
          // Entering "Student details" from role step: always start on first
          // child so we don't reopen on an empty 2nd tab after a prior session.
          if (fromStep == 0 && _currentStep == 1) {
            _activeStudentProfileTab = 0;
          }
        });
        _cardController.forward();
        _scrollRightPaneToTop();
      });
    } else {
      _submitForm();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _stepForward = false;
      _cardController.reverse().then((_) {
        setState(() => _currentStep--);
        _cardController.forward();
        _scrollRightPaneToTop();
      });
    }
  }

  // ─── Validation ─────────────────────────────────────────────────────

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _validateRoleStep();
      case 1:
        return _validateStudentInfoStep();
      case 2:
        return _validateProgramPricingStep();
      case 3:
        return _validateScheduleStep();
      case 4:
        return _validateContactSubmitStep();
      default:
        return true;
    }
  }

  bool _validateStudentInfoStep() {
    final studentName = _studentNameController.text.trim();
    if (studentName.isEmpty) {
      _showSnackBar('Please enter the student name', isError: true);
      return false;
    }

    final isParentOrGuardian = _role == 'Parent' || _role == 'Guardian';
    if (isParentOrGuardian) {
      for (int i = 0; i < _students.length; i++) {
        final student = _students[i];
        if (student.nameController.text.trim().isEmpty) {
          _showSnackBar('Please enter name for Student ${i + 2}',
              isError: true);
          return false;
        }
      }
    }

    return true;
  }

  bool _validateSingleChildProgramFields({
    required String? subject,
    required String? specificLanguage,
    required String? level,
    required String? classType,
    required int studentNumber,
    String? emptyProgramMessage,
    String? emptyLanguageMessage,
    String? emptyLevelMessage,
    String? emptyClassTypeMessage,
    /// When false (additional children in "different programs" mode), the
    /// program may be on another V2 track than the banner tier; only student 1
    /// must match the globally selected pricing tier.
    bool enforceGlobalPricingTier = true,
  }) {
    final planId = _resolvedPricingPlanId;
    final mismatch =
        AppLocalizations.of(context)!.enrollmentPlanProgramMismatch;
    if (subject == null || subject.isEmpty) {
      _showSnackBar(
        emptyProgramMessage ??
            'Please select a program for Student $studentNumber',
        isError: true,
      );
      return false;
    }
    final canonSubject = _canonicalProgramSubject(subject);
    if (canonSubject == null) {
      _showSnackBar(
        AppLocalizations.of(context)!
            .enrollmentStudentProgramTrackMissing(studentNumber),
        isError: true,
      );
      return false;
    }
    if (enforceGlobalPricingTier &&
        planId != null &&
        !_subjectMatchesPricingPlan(canonSubject, planId)) {
      _showSnackBar(mismatch, isError: true);
      return false;
    }
    if (canonSubject == _afroLanguagesSubject &&
        (specificLanguage == null || specificLanguage.isEmpty)) {
      _showSnackBar(
        emptyLanguageMessage ??
            'Please select a specific language for Student $studentNumber',
        isError: true,
      );
      return false;
    }
    if (level == null || level.isEmpty) {
      _showSnackBar(
        emptyLevelMessage ?? 'Please select a level for Student $studentNumber',
        isError: true,
      );
      return false;
    }
    if (!_getLevelsForSubject(canonSubject).contains(level)) {
      _showSnackBar(
        emptyLevelMessage ?? 'Please select a level for Student $studentNumber',
        isError: true,
      );
      return false;
    }
    if (classType == null || classType.isEmpty) {
      _showSnackBar(
        emptyClassTypeMessage ??
            'Please select a class type for Student $studentNumber',
        isError: true,
      );
      return false;
    }
    if (!_classTypes.contains(classType)) {
      _showSnackBar(
        emptyClassTypeMessage ??
            'Please select a class type for Student $studentNumber',
        isError: true,
      );
      return false;
    }
    if (_trackForSubject(canonSubject) == null) {
      _showSnackBar(
        AppLocalizations.of(context)!
            .enrollmentStudentProgramTrackMissing(studentNumber),
        isError: true,
      );
      return false;
    }
    return true;
  }

  bool _validateProgramStep() {
    final planId = _resolvedPricingPlanId;
    final mismatch =
        AppLocalizations.of(context)!.enrollmentPlanProgramMismatch;
    final isParentOrGuardian = _role == 'Parent' || _role == 'Guardian';

    if (isParentOrGuardian &&
        _students.isNotEmpty &&
        _applyProgramToAll &&
        !_perChildProgramBundlesDifferFromFirst()) {
      if (_selectedSubject == null || _selectedSubject!.isEmpty) {
        _showSnackBar('Please select a program for all children',
            isError: true);
        return false;
      }
      if (planId != null &&
          !_subjectMatchesPricingPlan(_selectedSubject, planId)) {
        _showSnackBar(mismatch, isError: true);
        return false;
      }
      if (_selectedSubject == _afroLanguagesSubject &&
          (_selectedAfricanLanguage == null ||
              _selectedAfricanLanguage!.isEmpty)) {
        _showSnackBar('Please select a specific language', isError: true);
        return false;
      }
      if (_selectedLevel == null || _selectedLevel!.isEmpty) {
        _showSnackBar('Please select a level for all children', isError: true);
        return false;
      }
      if (_classType == null || _classType!.isEmpty) {
        _showSnackBar('Please select a class type for all children',
            isError: true);
        return false;
      }
      return true;
    }

    // Per-child mode (or "same for all" UI but children no longer match)
    if (isParentOrGuardian && _students.isNotEmpty) {
      if (!_validateSingleChildProgramFields(
        subject: _selectedSubject,
        specificLanguage: _selectedAfricanLanguage,
        level: _selectedLevel,
        classType: _classType,
        studentNumber: 1,
      )) {
        return false;
      }
      for (int i = 0; i < _students.length; i++) {
        final student = _students[i];
        if (!_validateSingleChildProgramFields(
          subject: student.subject,
          specificLanguage: student.specificLanguage,
          level: student.level,
          classType: student.classType,
          studentNumber: i + 2,
          enforceGlobalPricingTier: false,
        )) {
          return false;
        }
      }
      return true;
    }

    if (_selectedSubject == null || _selectedSubject!.isEmpty) {
      _showSnackBar('Please select a program for Student 1', isError: true);
      return false;
    }
    if (planId != null &&
        !_subjectMatchesPricingPlan(_selectedSubject, planId)) {
      _showSnackBar(mismatch, isError: true);
      return false;
    }
    if (_selectedSubject == _afroLanguagesSubject &&
        (_selectedAfricanLanguage == null ||
            _selectedAfricanLanguage!.isEmpty)) {
      _showSnackBar('Please select a specific language for Student 1',
          isError: true);
      return false;
    }
    if (_selectedLevel == null || _selectedLevel!.isEmpty) {
      _showSnackBar('Please select a level for Student 1', isError: true);
      return false;
    }
    if (_classType == null || _classType!.isEmpty) {
      _showSnackBar('Please select a class type for Student 1', isError: true);
      return false;
    }

    return true;
  }

  bool _validateScheduleStep() {
    if (_hoursPerWeek == null || _hoursPerWeek! < 1) {
      _showSnackBar('Please select hours per week', isError: true);
      return false;
    }

    if (_selectedDays.isEmpty) {
      _showSnackBar('Please select at least one preferred day', isError: true);
      return false;
    }

    if (_selectedTimeSlots.isEmpty &&
        !_showDetailedTimeSlots &&
        _allTimeSlots.isNotEmpty) {
      setState(() => _selectedTimeSlots.addAll(_allTimeSlots));
    }
    if (_selectedTimeSlots.isEmpty) {
      _showSnackBar(
        AppLocalizations.of(context)!.enrollmentScheduleSelectTimeOfDayOrSlots,
        isError: true,
      );
      return false;
    }

    for (var i = 0; i < _students.length; i++) {
      final s = _students[i];
      final resolvedHours = s.hoursPerWeek ?? _hoursPerWeek;
      if (resolvedHours == null || resolvedHours < 1) {
        _showSnackBar(
          AppLocalizations.of(context)!.enrollmentStudentHoursMissing(i + 2),
          isError: true,
        );
        return false;
      }
      if (s.useCustomSchedule) {
        if (s.selectedDays.isEmpty) {
          _showSnackBar(
            'Student ${i + 2}: please select at least one preferred day',
            isError: true,
          );
          return false;
        }
        if (s.selectedTimeSlots.isEmpty) {
          _showSnackBar(
            'Student ${i + 2}: please select at least one preferred time slot',
            isError: true,
          );
          return false;
        }
      }
    }

    return true;
  }

  /// Digits-only national number must fit the selected country's rules.
  /// [raw] may include spaces or punctuation from [IntlPhoneField]; those are stripped.
  bool _nationalDigitsValidForIso(String isoCode, String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return false;
    intl_phone_countries.Country? match;
    for (final c in intl_phone_countries.countries) {
      if (c.code == isoCode) {
        match = c;
        break;
      }
    }
    if (match == null) {
      return digits.length >= 6 && digits.length <= 15;
    }
    return digits.length >= match.minLength && digits.length <= match.maxLength;
  }

  bool _validatePhoneFields(AppLocalizations l) {
    final phoneDigits = _phoneController.text.trim();
    if (phoneDigits.isEmpty) {
      _showSnackBar(l.enrollmentPhoneRequired, isError: true);
      return false;
    }
    if (!_nationalDigitsValidForIso(_phoneIntlCountryCode, phoneDigits)) {
      _showSnackBar(l.enrollmentPhoneInvalid, isError: true);
      return false;
    }
    final waDigits = _whatsAppNumberController.text.trim();
    if (waDigits.isNotEmpty &&
        !_nationalDigitsValidForIso(_whatsAppIntlCountryCode, waDigits)) {
      _showSnackBar(l.enrollmentWhatsAppInvalid, isError: true);
      return false;
    }
    return true;
  }

  bool _validateRoleStep() {
    if (_role == null || _role!.isEmpty) {
      _showSnackBar(
        'Please select who you are (Student, Parent, or Guardian)',
        isError: true,
      );
      return false;
    }
    return true;
  }

  bool _validateProgramPricingStep() {
    final l = AppLocalizations.of(context)!;
    if (_quoteTrackId == null) {
      _showSnackBar(l.enrollmentTrackRequired, isError: true);
      return false;
    }
    if (_hoursPerWeek == null || _hoursPerWeek! < 1) {
      _showSnackBar(l.enrollmentHoursRequired, isError: true);
      return false;
    }
    if (_isParentGuardian &&
        _students.isNotEmpty &&
        (!_applyProgramToAll || _perChildProgramBundlesDifferFromFirst())) {
      for (var i = 0; i < _students.length; i++) {
        final s = _students[i];
        final h = s.hoursPerWeek ?? _hoursPerWeek;
        if (h == null || h < 1) {
          _showSnackBar(l.enrollmentStudentHoursMissing(i + 2), isError: true);
          return false;
        }
      }
    }
    return _validateProgramStep();
  }

  bool _validateContactSubmitStep() {
    final l = AppLocalizations.of(context)!;
    if (_isParentGuardian &&
        _linkedParentData == null &&
        _parentNameController.text.trim().isEmpty) {
      _showSnackBar(l.enrollmentParentNameRequired, isError: true);
      return false;
    }
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fill in all required fields', isError: true);
      return false;
    }
    if (!_validatePhoneFields(l)) return false;
    return true;
  }

  bool get _isParentGuardian => _role == 'Parent' || _role == 'Guardian';

  bool _programStepFieldsSatisfied() {
    final planId = _resolvedPricingPlanId;

    bool okFields({
      required String? subject,
      String? specificLanguage,
      String? level,
      String? classType,
      bool enforceGlobalPricingTier = true,
    }) {
      final canon = _canonicalProgramSubject(subject);
      if (canon == null || canon.isEmpty) return false;
      if (enforceGlobalPricingTier &&
          planId != null &&
          !_subjectMatchesPricingPlan(canon, planId)) {
        return false;
      }
      if (canon == _afroLanguagesSubject &&
          (specificLanguage == null || specificLanguage.isEmpty)) {
        return false;
      }
      if (level == null || level.isEmpty) return false;
      final levels = _getLevelsForSubject(canon);
      if (!levels.contains(level)) return false;
      if (classType == null || classType.isEmpty) return false;
      if (!_classTypes.contains(classType)) return false;
      if (_trackForSubject(canon) == null) return false;
      return true;
    }

    // Multi-child: one shared bundle only when "same for all" AND every child
    // still matches that bundle (otherwise validate each child like per-tab mode).
    if (_isParentGuardian && _students.isNotEmpty) {
      final oneSharedBundle =
          _applyProgramToAll && !_perChildProgramBundlesDifferFromFirst();
      if (oneSharedBundle) {
        return okFields(
          subject: _selectedSubject,
          specificLanguage: _selectedAfricanLanguage,
          level: _selectedLevel,
          classType: _classType,
        );
      }
      if (!okFields(
        subject: _selectedSubject,
        specificLanguage: _selectedAfricanLanguage,
        level: _selectedLevel,
        classType: _classType,
      )) {
        return false;
      }
      for (final student in _students) {
        if (!okFields(
          subject: student.subject,
          specificLanguage: student.specificLanguage,
          level: student.level,
          classType: student.classType,
          enforceGlobalPricingTier: false,
        )) {
          return false;
        }
      }
      return true;
    }

    return okFields(
      subject: _selectedSubject,
      specificLanguage: _selectedAfricanLanguage,
      level: _selectedLevel,
      classType: _classType,
    );
  }

  bool _studentStepFieldsSatisfied() {
    if (_studentNameController.text.trim().isEmpty) return false;
    if (_isParentGuardian) {
      for (final s in _students) {
        if (s.nameController.text.trim().isEmpty) return false;
      }
    }
    return true;
  }

  bool _scheduleStepFieldsSatisfied() {
    if ((_hoursPerWeek ?? 0) < 1) return false;
    if (_selectedDays.isEmpty) return false;
    if (_selectedTimeSlots.isEmpty) {
      if (!_showDetailedTimeSlots && _allTimeSlots.isNotEmpty) {
        return true;
      }
      return false;
    }
    for (var i = 0; i < _students.length; i++) {
      final s = _students[i];
      final resolvedHours = s.hoursPerWeek ?? _hoursPerWeek;
      if (resolvedHours == null || resolvedHours < 1) return false;
      if (s.useCustomSchedule) {
        if (s.selectedDays.isEmpty || s.selectedTimeSlots.isEmpty) {
          return false;
        }
      }
    }
    return true;
  }

  bool _contactStepFieldsSatisfied() {
    if (_isParentGuardian) {
      final hasLinkedParent = _linkedParentData != null;
      if (!hasLinkedParent &&
          _parentNameController.text.trim().isEmpty) {
        return false;
      }
    }
    final e = _emailController.text.trim();
    if (e.isEmpty) return false;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) return false;
    final phoneDigits = _phoneController.text.trim();
    if (phoneDigits.isEmpty) return false;
    if (!_nationalDigitsValidForIso(_phoneIntlCountryCode, phoneDigits)) {
      return false;
    }
    final waDigits = _whatsAppNumberController.text.trim();
    if (waDigits.isNotEmpty &&
        !_nationalDigitsValidForIso(_whatsAppIntlCountryCode, waDigits)) {
      return false;
    }
    if (_selectedCountry == null) return false;
    if (_cityController.text.trim().isEmpty) return false;
    return true;
  }

  bool get _isCurrentStepValidForContinue {
    switch (_currentStep) {
      case 0:
        return _role != null && _role!.isNotEmpty;
      case 1:
        return _studentStepFieldsSatisfied();
      case 2:
        if (_quoteTrackId == null || (_hoursPerWeek ?? 0) < 1) return false;
        // Additional students: stepper display falls back to [_hoursPerWeek] when
        // [hoursPerWeek] was never written — align validation with that UX.
        if (_isParentGuardian &&
            _students.isNotEmpty &&
            (!_applyProgramToAll ||
                _perChildProgramBundlesDifferFromFirst())) {
          for (final s in _students) {
            final h = s.hoursPerWeek ?? _hoursPerWeek;
            if ((h ?? 0) < 1) return false;
          }
        }
        return _programStepFieldsSatisfied();
      case 3:
        return _scheduleStepFieldsSatisfied();
      case 4:
        return _contactStepFieldsSatisfied();
      default:
        return false;
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: Column(
        children: [
          const ModernHeader(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 8 : 12,
                    4,
                    isMobile ? 8 : 12,
                    isMobile ? 4 : 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHorizontalStepBar(),
                      const SizedBox(height: 4),
                      Expanded(child: _buildFormContent(isMobile)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalStepBar() {
    final l = AppLocalizations.of(context)!;
    return EnrollmentStepIndicator(
      currentStep: _currentStep,
      stepTitles: [
        l.enrollmentWizardRoleTitle,
        l.enrollmentWizardStudentsTitle,
        l.enrollmentWizardProgramTitle,
        l.enrollmentWizardScheduleTitle,
        l.enrollmentWizardContactTitle,
      ],
      stepIcons: const [
        Icons.badge_outlined,
        Icons.person_outline,
        Icons.auto_stories_outlined,
        Icons.calendar_today_outlined,
        Icons.mail_outline,
      ],
    );
  }

  Widget _buildFormContent(bool isMobile) {
    final l = AppLocalizations.of(context)!;
    final summaryLines = _buildEnrollmentSummaryLines();
    final showSummary = _currentStep >= 2 && summaryLines.isNotEmpty;
    final hPad = isMobile ? 12.0 : 14.0;

    final summaryColumn = _currentStep >= 1
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${1 + _students.length} student${_students.isNotEmpty ? 's' : ''} · $_totalHoursPerWeek hrs/wk',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xff64748B),
                    ),
                  ),
                  Text(
                    _totalMonthlyEstimateLabel(),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff059669),
                    ),
                  ),
                ],
              ),
              if (showSummary && isMobile) ...[
                InkWell(
                  onTap: () => setState(() => _enrollmentSummaryExpanded =
                      !_enrollmentSummaryExpanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Details',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xff94A3B8))),
                        Icon(
                          _enrollmentSummaryExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 16,
                          color: const Color(0xff94A3B8),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_enrollmentSummaryExpanded)
                  ...summaryLines.map((line) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(line.title,
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xff64748B))),
                            Text(line.detail,
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xff374151))),
                          ],
                        ),
                      )),
              ],
              if (showSummary && !isMobile)
                EnrollmentSummaryPanel(
                  title: l.enrollmentSummaryPanelTitle,
                  lines: summaryLines,
                  expanded: _enrollmentSummaryExpanded,
                  onExpandedChanged: (v) =>
                      setState(() => _enrollmentSummaryExpanded = v),
                  showCollapseToggle: false,
                ),
            ],
          )
        : null;

    final bottomPinned = Padding(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, isMobile ? 6 : 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_currentStep >= 1 && summaryColumn != null) ...[
            const Divider(
              height: 1,
              thickness: 1,
              color: Color(0xffE2E8F0),
            ),
            const SizedBox(height: 6),
            summaryColumn,
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Divider(
                height: 1,
                color: const Color(0xffE2E8F0).withValues(alpha: 0.9),
              ),
            ),
          ],
          _buildNavigationButtons(isMobile, embeddedInFooter: true),
        ],
      ),
    );

    final unifiedCard = Material(
      color: Colors.white,
      elevation: isMobile ? 2 : 1,
      shadowColor: const Color(0xff0F172A).withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              controller: _rightPaneScroll,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(hPad, isMobile ? 8 : 10, hPad, 2),
              child: _buildCurrentStepContent(
                scrollable: false,
                includeStepCardShell: false,
              ),
            ),
          ),
          bottomPinned,
        ],
      ),
    );

    final wrappedCard = isMobile
        ? SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 4),
            child: unifiedCard,
          )
        : unifiedCard;

    return Form(
      key: _formKey,
      child: wrappedCard,
    );
  }

  /// Shared hours stepper + monthly estimate for a V2 [trackId].
  Widget _buildHoursStepper({
    required int hours,
    required void Function(int newHours) onHoursChanged,
    required String? trackId,
    String? headerLabel,
  }) {
    final l = AppLocalizations.of(context)!;
    final h = hours.clamp(1, 8);
    final snapshot = (trackId != null && h > 0)
        ? PricingQuoteService.buildSnapshotV2(
            trackId: trackId,
            hoursPerWeek: h,
            cmsOverrides: _pricingCms.planOverridesForQuotes(),
          )
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                headerLabel ?? l.pricingSelectHours,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff1E293B),
                  letterSpacing: 0.15,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xffFAFBFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xffE2E8F0), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff0F172A).withValues(alpha: 0.02),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    onPressed: h > 1 ? () => onHoursChanged(h - 1) : null,
                    icon: Icon(
                      Icons.remove_circle_outline_rounded,
                      color: h > 1 ? const Color(0xff3B82F6) : const Color(0xffCBD5E1),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '$h',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xff0F172A),
                        letterSpacing: 0.15,
                      ),
                    ),
                  ),
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    onPressed: h < 8 ? () => onHoursChanged(h + 1) : null,
                    icon: Icon(
                      Icons.add_circle_outline_rounded,
                      color: h < 8 ? const Color(0xff3B82F6) : const Color(0xffCBD5E1),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (snapshot != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xff059669).withValues(alpha: 0.08),
                  const Color(0xff10B981).withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xff059669).withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              l.pricingMonthlyBreakdown(
                h,
                snapshot['hourlyRateUsd'].toStringAsFixed(2),
                trackId == PricingPlanIds.group ? '4.33' : '4',
                (snapshot['monthlyEstimateUsd'] as double).toStringAsFixed(2),
              ),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xff059669),
                letterSpacing: 0.05,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHoursPerWeekPicker(bool isMobile) {
    final hours = _hoursPerWeek ?? 1;
    return _buildHoursStepper(
      hours: hours,
      trackId: _quoteTrackId,
      onHoursChanged: (nh) {
        setState(() {
          _hoursPerWeek = nh;
          _sessionDuration = _durationFromHoursPerWeek(nh);
        });
      },
    );
  }

  Widget _buildParentLookup() {
    final l = AppLocalizations.of(context)!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _linkedParentData != null
              ? [const Color(0xffECFDF5), const Color(0xffD1FAE5)]
              : [const Color(0xffEFF6FF), const Color(0xffDBEAFE)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _linkedParentData != null
              ? const Color(0xff10B981).withValues(alpha: 0.3)
              : const Color(0xff3B82F6).withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (_linkedParentData != null
                    ? const Color(0xff10B981)
                    : const Color(0xff3B82F6))
                .withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _linkedParentData != null
                      ? const Color(0xff10B981).withValues(alpha: 0.15)
                      : const Color(0xff3B82F6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _linkedParentData != null
                      ? Icons.check_circle_rounded
                      : Icons.link_rounded,
                  color: _linkedParentData != null
                      ? const Color(0xff059669)
                      : const Color(0xff3B82F6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _linkedParentData != null
                          ? l.accountLinked
                          : l.alreadyHaveChildEnrolled,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _linkedParentData != null
                            ? const Color(0xff047857)
                            : const Color(0xff1E40AF),
                      ),
                    ),
                    if (_linkedParentData == null) ...[
                      const SizedBox(height: 2),
                      Text(
                        l.linkYourAccountToManageAll,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xff64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_linkedParentData != null)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              const Color(0xff10B981).withValues(alpha: 0.15),
                          child: Text(
                            (_linkedParentData!['firstName'] as String?)
                                    ?.substring(0, 1)
                                    .toUpperCase() ??
                                'P',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xff059669),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${l.welcomeBack}, ${_linkedParentData!['firstName']}!',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: const Color(0xff065F46),
                                ),
                              ),
                              Text(
                                l.newStudentWillBeLinkedTo,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xff059669),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _unlinkParent,
                  icon: const Icon(Icons.close, size: 16),
                  label: Text(l.unlink),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xffDC2626),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _parentIdentityController,
                    decoration: InputDecoration(
                      hintText: l.enterYourEmailOrKiosqueCode,
                      hintStyle: GoogleFonts.inter(
                        color: const Color(0xff94A3B8),
                        fontSize: 13,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: Color(0xff94A3B8), size: 20),
                    ),
                    onSubmitted: (_) => _checkParentIdentity(),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: const Color(0xff3B82F6),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: _isCheckingIdentity ? null : _checkParentIdentity,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: _isCheckingIdentity
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              children: [
                                const Icon(Icons.link_rounded,
                                    color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  l.link,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(bool isMobile,
      {bool embeddedInFooter = false}) {
    final l = AppLocalizations.of(context)!;
    final isSubmit = _currentStep == kEnrollmentFlowSubmitStepIndex;
    final primaryLabel =
        isSubmit ? l.enrollmentFlowSubmit : l.enrollmentFlowContinue;

    final stepReady = _isCurrentStepValidForContinue;

    final Color bgColor;
    final Color fgColor;
    if (isSubmit) {
      bgColor = stepReady ? const Color(0xff059669) : const Color(0xff94A3B8);
      fgColor = Colors.white;
    } else {
      bgColor = stepReady ? const Color(0xff3B82F6) : const Color(0xffCBD5E1);
      fgColor = stepReady ? Colors.white : const Color(0xff94A3B8);
    }

    final vPad = embeddedInFooter
        ? EdgeInsets.zero
        : EdgeInsets.only(top: isMobile ? 4 : 5, bottom: isMobile ? 4 : 5);
    return Padding(
      padding: vPad,
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              flex: isMobile ? 1 : 0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xff0F172A).withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: OutlinedButton.icon(
                  onPressed: _previousStep,
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: Text(isMobile ? '' : l.commonBack),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xff475569),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xffE2E8F0), width: 1.5),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 10 : 14,
                      vertical: isMobile ? 9 : 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.15,
                    ),
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) SizedBox(width: isMobile ? 6 : 10),
          Expanded(
            flex: isMobile ? 2 : 0,
            child: Container(
              constraints: BoxConstraints(
                minWidth: isMobile ? 0 : 160,
              ),
              decoration: stepReady
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: isSubmit
                              ? const Color(0xff059669).withValues(alpha: 0.2)
                              : const Color(0xff3B82F6).withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    )
                  : null,
              child: ElevatedButton(
                onPressed: stepReady && !_isSubmitting ? _nextStep : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: bgColor,
                  foregroundColor: fgColor,
                  disabledBackgroundColor: bgColor,
                  disabledForegroundColor: fgColor,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 14 : 18,
                    vertical: isMobile ? 9 : 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              primaryLabel,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isSubmit
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                            size: 19,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _isAdult {
    if (_selectedLevel == 'University' ||
        _selectedGrade == 'University' ||
        _selectedGrade == 'Adult Professionals') return true;
    final age = int.tryParse(_studentAgeController.text) ?? 0;
    if (age >= 18) return true;
    return false;
  }

  // ─── Steps Content ──────────────────────────────────────────────────

  Widget _buildStepCard({
    required String title,
    String? subtitle,
    required List<Widget> children,
    bool scrollable = true,
    bool includeOuterShell = true,
    bool centerHeader = false,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final curvedAnim = CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutCubic,
    );
    final slideBegin = _stepForward
        ? const Offset(0.04, 0)
        : const Offset(-0.04, 0);
    
    final headerColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: centerHeader ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: centerHeader ? TextAlign.center : null,
          style: GoogleFonts.plusJakartaSans(
            fontSize: isMobile ? 14 : 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xff0F172A),
            letterSpacing: -0.3,
            height: 1.15,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: centerHeader ? TextAlign.center : null,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: const Color(0xff64748B),
              height: 1.25,
              letterSpacing: 0,
            ),
          ),
        ],
        const SizedBox(height: 4),
        Container(
          width: 26,
          height: 2,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff3B82F6), Color(0xff60A5FA)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );

    final innerColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (centerHeader)
          Center(child: headerColumn)
        else
          headerColumn,
        SizedBox(height: isMobile ? 6 : 5),
        ...children,
        if (includeOuterShell) const SizedBox(height: 4),
      ],
    );
    final shellChild = includeOuterShell
        ? Container(
            padding: EdgeInsets.all(isMobile ? 12 : 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xff0F172A).withValues(alpha: 0.06),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: const Color(0xff0F172A).withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: innerColumn,
          )
        : innerColumn;
    final content = FadeTransition(
      opacity: _cardController,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: slideBegin,
          end: Offset.zero,
        ).animate(curvedAnim),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1.0).animate(curvedAnim),
          alignment: Alignment.topCenter,
          child: shellChild,
        ),
      ),
    );
    if (scrollable) {
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: content,
      );
    }
    return content;
  }

  Widget _buildCurrentStepContent({
    bool scrollable = true,
    bool includeStepCardShell = true,
  }) {
    switch (_currentStep) {
      case 0:
        return _buildStep0RoleAccountLink(
          scrollable: scrollable,
          includeStepCardShell: includeStepCardShell,
        );
      case 1:
        return _buildStep1StudentProfiles(
          scrollable: scrollable,
          includeStepCardShell: includeStepCardShell,
        );
      case 2:
        return _buildStep2Programs(
          scrollable: scrollable,
          includeStepCardShell: includeStepCardShell,
        );
      case 3:
        return _buildStep3Schedule(
          scrollable: scrollable,
          includeStepCardShell: includeStepCardShell,
        );
      case 4:
        return _buildStep4ReviewContact(
          scrollable: scrollable,
          includeStepCardShell: includeStepCardShell,
        );
      default:
        return _buildStep0RoleAccountLink(
          scrollable: scrollable,
          includeStepCardShell: includeStepCardShell,
        );
    }
  }

  // ─── Step 0: Role + Account Link ────────────────────────────────────

  Widget _buildStep0RoleAccountLink({
    bool scrollable = true,
    bool includeStepCardShell = true,
  }) {
    final l = AppLocalizations.of(context)!;
    return _buildStepCard(
      title: l.enrollmentWizardRoleTitle,
      subtitle: l.enrollmentWizardRoleSubtitle,
      scrollable: scrollable,
      includeOuterShell: includeStepCardShell,
      children: [
        EnrollmentStepRoleView(
          selectedRole: _role,
          onSelectRole: (r) => setState(() => _role = r),
          extraStudentCount: _students.length,
          onAddStudent: _addStudent,
          onRemoveLastStudent: _students.isEmpty
              ? null
              : () => _removeStudent(_students.length - 1),
        ),
        if (_isParentGuardian) ...[
          const SizedBox(height: 14),
          _buildParentLookup(),
        ],
      ],
    );
  }

  // ─── Step 1: Student Profiles (was Step 2) ──────────────────────────

  Widget _buildStep1StudentProfiles({
    bool scrollable = true,
    bool includeStepCardShell = true,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final isParentOrGuardian = _role == 'Parent' || _role == 'Guardian';

    if (!isParentOrGuardian) {
      return _buildStepCard(
        title:
            AppLocalizations.of(context)?.yourInformation ?? 'Your Information',
        subtitle:
            AppLocalizations.of(context)!.enrollmentWizardStudentsSubtitle,
        scrollable: scrollable,
        includeOuterShell: includeStepCardShell,
        children: [
          _buildModernTextField(
            'Full Name',
            _studentNameController,
            Icons.person_outline_rounded,
            hint: 'Enter your full name',
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 360;
              final age = _buildModernTextField(
                'Age',
                _studentAgeController,
                Icons.cake_outlined,
                isNumber: true,
                hint: 'Years',
                compact: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final parsed = int.tryParse(v);
                  if (parsed == null || parsed < 1 || parsed > 99) {
                    return 'Enter a valid age (1-99)';
                  }
                  return null;
                },
              );
              final gender = _buildSegmentedGender(
                _gender,
                (v) => setState(() => _gender = v),
              );
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    age,
                    const SizedBox(height: 12),
                    gender,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: age),
                  const SizedBox(width: 12),
                  Expanded(child: gender),
                ],
              );
            },
          ),
        ],
      );
    }

    return _buildStepCard(
      title: AppLocalizations.of(context)!.studentSInformation,
      subtitle: AppLocalizations.of(context)!.enrollmentWizardStudentsSubtitle,
      scrollable: scrollable,
      includeOuterShell: includeStepCardShell,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 12,
            vertical: isMobile ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xff3B82F6).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: const Color(0xff3B82F6).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline,
                  color: const Color(0xff3B82F6), size: isMobile ? 14 : 16),
              SizedBox(width: isMobile ? 6 : 8),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.youCanAddMultipleStudentsIn,
                  style: GoogleFonts.inter(
                    fontSize: isMobile ? 10 : 11,
                    color: const Color(0xff3B82F6),
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: isMobile ? 6 : 8),
        _buildParentStudentsProfilePanel(),
      ],
    );
  }

  /// Tab strip + one visible form; [IndexedStack] keeps every student's fields
  /// in the tree so [FormState] validators still run (same data as before).
  Widget _buildParentStudentsProfilePanel() {
    const surface = Color(0xff0F172A);
    const surface2 = Color(0xff1E293B);
    const borderLine = Color(0xff334155);
    const gold = Color(0xffEAB308);
    const goldText = Color(0xffFCD34D);
    const iconTint = Color(0xffA78BFA);

    final l = AppLocalizations.of(context)!;
    final maxTab = _students.length;
    final safeTab = _activeStudentProfileTab.clamp(0, maxTab);
    final removable = safeTab >= 1;

    final isMobile = MediaQuery.of(context).size.width < 768;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [surface, surface2],
        ),
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        border: Border.all(color: borderLine),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: isMobile ? 16 : 20,
            offset: Offset(0, isMobile ? 6 : 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 8 : 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStudentProfileTabRow(
              gold: gold,
              goldText: goldText,
              iconTint: iconTint,
              borderLine: borderLine,
              surface2: surface2,
            ),
            SizedBox(height: isMobile ? 6 : 8),
            Container(
              padding: EdgeInsets.all(isMobile ? 10 : 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isMobile ? 10 : 14),
                border: Border.all(color: const Color(0xffE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff0F172A).withValues(alpha: 0.06),
                    blurRadius: isMobile ? 8 : 12,
                    offset: Offset(0, isMobile ? 2 : 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_rounded, 
                          size: isMobile ? 14 : 16, 
                          color: iconTint),
                      SizedBox(width: isMobile ? 5 : 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _studentProfileEditorTitle(safeTab, l),
                              style: GoogleFonts.inter(
                                fontSize: isMobile ? 12 : 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xff0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Student ${safeTab + 1}',
                              style: GoogleFonts.inter(
                                fontSize: isMobile ? 9 : 10,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xff64748B),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (removable)
                        IconButton(
                          tooltip: l.removeStudent,
                          onPressed: () =>
                              _removeStudent(safeTab - 1),
                          icon: Icon(Icons.close_rounded, 
                              size: isMobile ? 16 : 18),
                          color: const Color(0xffEF4444),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(
                            minWidth: isMobile ? 28 : 32,
                            minHeight: isMobile ? 28 : 32,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 6 : 8),
                  IndexedStack(
                    index: safeTab,
                    sizing: StackFit.passthrough,
                    children: [
                      KeyedSubtree(
                        key: const ValueKey('profile-tab-0'),
                        child: _buildStudentProfileFields(
                          nameController: _studentNameController,
                          ageController: _studentAgeController,
                          gender: _gender,
                          onGenderChanged: (v) => setState(() => _gender = v),
                        ),
                      ),
                      ...List.generate(_students.length, (i) {
                        final student = _students[i];
                        return KeyedSubtree(
                          key: ValueKey('profile-tab-${i + 1}'),
                          child: _buildStudentProfileFields(
                            nameController: student.nameController,
                            ageController: student.ageController,
                            gender: student.gender,
                            onGenderChanged: (v) =>
                                setState(() => student.gender = v),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _studentProfileEditorTitle(int tab, AppLocalizations l) {
    if (tab == 0) {
      final t = _studentNameController.text.trim();
      if (t.isNotEmpty) {
        return t;
      }
      return l.studentDefaultName1;
    }
    final s = _students[tab - 1];
    final t = s.nameController.text.trim();
    if (t.isNotEmpty) {
      return t;
    }
    return 'Student ${tab + 1}';
  }

  Widget _buildStudentProfileTabRow({
    required Color gold,
    required Color goldText,
    required Color iconTint,
    required Color borderLine,
    required Color surface2,
  }) {
    final l = AppLocalizations.of(context)!;
    final tabCount = 1 + _students.length;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Use [List.generate] so each [onTap] closes over its own index. A
          // C-style `for (var i = 0; ...)` + closure captures one [i] updated
          // each iteration — every tab would act like the last index (classic
          // Dart gotcha), jumping to the last student when tapping any pill.
          ...List.generate(tabCount, (i) {
            return Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 2),
              child: GestureDetector(
                onTap: () => setState(() => _activeStudentProfileTab = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: surface2,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _activeStudentProfileTab == i ? gold : borderLine,
                      width: _activeStudentProfileTab == i ? 2 : 1,
                    ),
                    boxShadow: _activeStudentProfileTab == i
                        ? [
                            BoxShadow(
                              color: gold.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_outline_rounded,
                          size: 14,
                          color: _activeStudentProfileTab == i
                              ? goldText
                              : iconTint),
                      const SizedBox(width: 5),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 110),
                        child: Text(
                          _studentProfileTabLabel(i, l),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: _activeStudentProfileTab == i
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _activeStudentProfileTab == i
                                ? goldText
                                : const Color(0xff94A3B8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: InkWell(
              onTap: _addStudent,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xff0F172A),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: gold, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 16, color: goldText),
                    const SizedBox(width: 4),
                    Text(
                      l.addAnotherStudent,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: goldText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _studentProfileTabLabel(int tab, AppLocalizations l) {
    if (tab == 0) {
      final t = _studentNameController.text.trim();
      return t.isNotEmpty ? t : l.studentDefaultName1;
    }
    final t = _students[tab - 1].nameController.text.trim();
    return t.isNotEmpty ? t : 'Student ${tab + 1}';
  }

  Widget _buildStudentProfileFields({
    required TextEditingController nameController,
    required TextEditingController ageController,
    required String? gender,
    required void Function(String?) onGenderChanged,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModernTextField(
          'Student Name',
          nameController,
          Icons.person_outline_rounded,
          hint: 'Enter full name',
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: isMobile ? 8 : 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 360;
            final age = _buildModernTextField(
              'Age',
              ageController,
              Icons.cake_outlined,
              isNumber: true,
              hint: 'Years',
              compact: true,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final parsed = int.tryParse(v);
                if (parsed == null || parsed < 1 || parsed > 99) {
                  return 'Enter a valid age (1-99)';
                }
                return null;
              },
            );
            final genderWidget =
                _buildSegmentedGender(gender, onGenderChanged);
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  age,
                  SizedBox(height: isMobile ? 6 : 8),
                  genderWidget,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: age),
                SizedBox(width: isMobile ? 8 : 10),
                Expanded(child: genderWidget),
              ],
            );
          },
        ),
      ],
    );
  }

  void _addStudent() {
    setState(() {
      _students.add(_StudentInput());
      _applyProgramToAll = true;
      _activeProgramTab = 0;
      // Keep focus on the child you're already editing; the new slot appears
      // in the strip — user taps it when ready (avoids empty Student 2 jump).
      _activeStudentProfileTab =
          _activeStudentProfileTab.clamp(0, _students.length - 1);
    });
  }

  void _removeStudent(int index) {
    setState(() {
      final removedTab = index + 1;
      final wasActive = _activeStudentProfileTab == removedTab;
      _students[index].dispose();
      _students.removeAt(index);
      final maxTab = _students.length;
      if (wasActive) {
        _activeStudentProfileTab = (removedTab - 1).clamp(0, maxTab);
      } else if (_activeStudentProfileTab > removedTab) {
        _activeStudentProfileTab -= 1;
      }
      _activeStudentProfileTab = _activeStudentProfileTab.clamp(0, maxTab);
    });
  }

  List<String> _getLevelsForSubject(String? subject) {
    if (subject == _afterSchoolSubject) {
      return _afterSchoolLevelOptions;
    }
    return _programLevelOptions;
  }

  /// Reusable track card selector.
  Widget _buildTrackCards({
    required String? selectedTrackId,
    required ValueChanged<String> onTrackSelected,
  }) {
    final l = AppLocalizations.of(context)!;
    final tracks = [
      (PricingPlanIds.islamic, l.pricingTrackIslamicTitle, Icons.menu_book_rounded),
      (PricingPlanIds.tutoring, l.pricingTrackTutoringTitle, Icons.school_rounded),
      (PricingPlanIds.group, l.pricingTrackGroupTitle, Icons.groups_rounded),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tracks.map((t) {
        final (trackId, title, icon) = t;
        final selected = selectedTrackId == trackId;
        return InkWell(
          onTap: () => onTrackSelected(trackId),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      colors: [Color(0xff4F46E5), Color(0xff6366F1)])
                  : null,
              color: selected ? null : const Color(0xffF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? const Color(0xff4F46E5)
                    : const Color(0xffE2E8F0),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 14,
                    color: selected ? Colors.white : const Color(0xff64748B)),
                const SizedBox(width: 5),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? Colors.white : const Color(0xff374151),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _defaultSubjectForTrack(String trackId) {
    switch (trackId) {
      case PricingPlanIds.islamic:
        return _islamicSubject;
      case PricingPlanIds.tutoring:
        return _afterSchoolSubject;
      case PricingPlanIds.group:
        return kGroupClassesSubject;
      default:
        return _islamicSubject;
    }
  }

  String? _trackForSubject(String? subject) {
    if (subject == null) return null;
    if (subject == kGroupClassesSubject) return PricingPlanIds.group;
    if (subject == _islamicSubject) return PricingPlanIds.islamic;
    if (subject == _afterSchoolSubject ||
        subject == _adultLiteracySubject ||
        subject == 'Coding' ||
        subject == 'Entrepreneurship' ||
        subject == 'English' ||
        subject == 'French' ||
        subject == 'Adlam') {
      return PricingPlanIds.tutoring;
    }
    if (subject == _afroLanguagesSubject) return PricingPlanIds.islamic;
    final mapped = _resolveInitialSubject(subject);
    if (mapped != null && mapped != subject) {
      return _trackForSubject(mapped);
    }
    return null;
  }

  Widget _buildProgramFields({
    required String? subject,
    required Function(String?) onSubjectChanged,
    required String? specificLanguage,
    required Function(String?) onSpecificLanguageChanged,
    required String? level,
    required Function(String?) onLevelChanged,
    required String? classType,
    required Function(String?) onClassTypeChanged,
    String fieldKeyPrefix = 'prog',
    bool showTrackSelector = true,
  }) {
    final l = AppLocalizations.of(context)!;
    return Column(
      children: [
        if (showTrackSelector)
          _buildTrackCards(
            selectedTrackId: _trackForSubject(subject),
            onTrackSelected: (trackId) {
              onSubjectChanged(_defaultSubjectForTrack(trackId));
            },
          ),
        if (subject == _afroLanguagesSubject) ...[
          SizedBox(height: showTrackSelector ? 10 : 6),
          _buildModernDropdown(
            l.enrollmentStateSpecificLanguage,
            _otherAfricanLanguages,
            specificLanguage,
            onSpecificLanguageChanged,
            Icons.language_rounded,
            fieldKey: ValueKey('$fieldKeyPrefix-afroLang'),
          ),
        ],
        if (subject != null) ...[
          const SizedBox(height: 6),
          _buildModernDropdown(
            subject == _afterSchoolSubject
                ? l.enrollmentStateGradeLevel
                : l.enrollmentStateProficiencyLevel,
            _getLevelsForSubject(subject),
            level,
            onLevelChanged,
            Icons.school_outlined,
            fieldKey: ValueKey('$fieldKeyPrefix-level'),
          ),
        ],
        const SizedBox(height: 8),
        _buildSegmentedClassType(
          classType,
          onClassTypeChanged,
        ),
      ],
    );
  }

  Widget _buildStudentProgramCard({
    required int studentIndex,
    required String studentName,
    required String? subject,
    required Function(String?) onSubjectChanged,
    required String? specificLanguage,
    required Function(String?) onSpecificLanguageChanged,
    required String? level,
    required Function(String?) onLevelChanged,
    required String? classType,
    required Function(String?) onClassTypeChanged,
    _StudentInput? hoursRow,
    bool showGlobalHoursStepper = false,
  }) {
    final l = AppLocalizations.of(context)!;
    final hoursTarget = hoursRow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          _buildProgramFields(
            subject: subject,
            onSubjectChanged: onSubjectChanged,
            specificLanguage: specificLanguage,
            onSpecificLanguageChanged: onSpecificLanguageChanged,
            level: level,
            onLevelChanged: onLevelChanged,
            classType: classType,
            onClassTypeChanged: onClassTypeChanged,
            fieldKeyPrefix: 'student$studentIndex',
            showTrackSelector: true,
          ),
          if (hoursTarget != null) ...[
            const SizedBox(height: 8),
            _buildHoursStepper(
              hours:
                  (hoursTarget.hoursPerWeek ?? _hoursPerWeek ?? 1).clamp(1, 8),
              trackId: _trackForSubject(subject) ?? _quoteTrackId,
              headerLabel: l.enrollmentStudentHoursPerWeek,
              onHoursChanged: (nh) {
                setState(() {
                  hoursTarget.hoursPerWeek = nh;
                  hoursTarget.sessionDuration = _durationFromHoursPerWeek(nh);
                });
              },
            ),
          ],
          if (showGlobalHoursStepper && hoursTarget == null) ...[
            const SizedBox(height: 8),
            _buildHoursStepper(
              hours: (_hoursPerWeek ?? 1).clamp(1, 8),
              trackId: _trackForSubject(subject) ?? _quoteTrackId,
              headerLabel: l.enrollmentStudentHoursPerWeek,
              onHoursChanged: (nh) {
                setState(() {
                  _hoursPerWeek = nh;
                  _sessionDuration = _durationFromHoursPerWeek(nh);
                });
              },
            ),
          ],
      ],
    );
  }

  // ─── Step 2: Programs with Pill Tabs (was Step 1) ───────────────────

  Widget _buildStudentPillTabs() {
    final allStudents = [
      _studentNameController.text.isNotEmpty
          ? _studentNameController.text
          : AppLocalizations.of(context)!.studentDefaultName1,
      ...List.generate(
          _students.length,
          (i) => _students[i].nameController.text.isNotEmpty
              ? _students[i].nameController.text
              : 'Student ${i + 2}'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: allStudents.asMap().entries.map((entry) {
          final idx = entry.key;
          final name = entry.value;
          final isActive = _activeProgramTab == idx;
          return Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 2),
            child: GestureDetector(
              onTap: () => setState(() => _activeProgramTab = idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: isActive ? 16 : 14,
                  vertical: isActive ? 8 : 7,
                ),
                decoration: BoxDecoration(
                  gradient: isActive
                      ? const LinearGradient(
                          colors: [Color(0xff3B82F6), Color(0xff2563EB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isActive ? null : const Color(0xffFAFBFC),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xff2563EB)
                        : const Color(0xffE2E8F0),
                    width: isActive ? 2 : 1.5,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: const Color(0xff3B82F6).withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: const Color(0xff0F172A).withValues(alpha: 0.02),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isActive)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.edit_note_rounded,
                            size: 16, color: Colors.white),
                      ),
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w600,
                        color:
                            isActive ? Colors.white : const Color(0xff475569),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSubCard({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff0F172A).withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xffF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: Color(0xffE2E8F0))),
            ),
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xff1E293B),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Programs({
    bool scrollable = true,
    bool includeStepCardShell = true,
  }) {
    final l = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.of(context).size.width < 768;
    final isParentOrGuardian = _role == 'Parent' || _role == 'Guardian';
    final totalStudents = isParentOrGuardian ? 1 + _students.length : 1;

    final trackSelector = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModernLabel(l.pricingSelectTrack),
        const SizedBox(height: 4),
        _buildTrackCards(
          selectedTrackId: _quoteTrackId,
          onTrackSelected: (trackId) {
            setState(() {
              _selectedTrackId = trackId;
              _pickedPricingPlanId = _defaultLegacyPlanForTrack(trackId);
              final newSubject = _defaultSubjectForTrack(trackId);
              _selectedSubject = newSubject;
              if (newSubject != _afroLanguagesSubject) {
                _selectedAfricanLanguage = null;
              }
              _selectedLevel = null;
              if (_applyProgramToAll) {
                for (final s in _students) {
                  s.subject = newSubject;
                  s.specificLanguage = null;
                  s.level = null;
                }
              }
            });
          },
        ),
      ],
    );

    final hoursSection = _buildHoursPerWeekPicker(isMobile);

    if (!isParentOrGuardian || totalStudents == 1) {
      return _buildStepCard(
        title: l.programDetails,
        scrollable: scrollable,
        includeOuterShell: includeStepCardShell,
        children: [
          _buildSubCard(
            title: l.enrollmentStateChooseProgram,
            child: trackSelector,
          ),
          _buildSubCard(
            title: l.enrollmentStateClassPreferences,
            child: Column(
              children: [
                _buildProgramFields(
                  subject: _selectedSubject,
                  onSubjectChanged: (v) {
                    setState(() {
                      _selectedSubject = v;
                      if (v != _afroLanguagesSubject) _selectedAfricanLanguage = null;
                      _selectedLevel = null;
                    });
                  },
                  specificLanguage: _selectedAfricanLanguage,
                  onSpecificLanguageChanged: (v) =>
                      setState(() => _selectedAfricanLanguage = v),
                  level: _selectedLevel,
                  onLevelChanged: (v) => setState(() => _selectedLevel = v),
                  classType: _classType,
                  onClassTypeChanged: (v) => setState(() => _classType = v),
                  fieldKeyPrefix: 'solo',
                  showTrackSelector: false,
                ),
                const SizedBox(height: 12),
                _buildModernDropdown(
                  l.enrollmentStatePreferredLanguage,
                  _languages,
                  _preferredLanguage,
                  (v) => setState(() => _preferredLanguage = v),
                  Icons.translate_rounded,
                ),
              ],
            ),
          ),
          _buildSubCard(
            title: l.enrollmentStatePricingAndHours,
            child: hoursSection,
          ),
        ],
      );
    }

    return _buildStepCard(
      title: l.programDetailsForEachStudent,
      subtitle: _applyProgramToAll
          ? l.enrollmentProgramSameForAllSubtitle
          : l.enrollmentMultiStudentHoursHint,
      scrollable: scrollable,
      includeOuterShell: includeStepCardShell,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xffF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xffE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l.enrollmentStateCustomizePerStudent,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff1E293B),
                ),
              ),
              Switch(
                value: !_applyProgramToAll,
                onChanged: (val) {
                  setState(() {
                    if (val) {
                      _applyProgramToAll = false;
                      _activeProgramTab = 1;
                      for (final s in _students) {
                        s.subject ??= _selectedSubject;
                        s.specificLanguage ??= _selectedAfricanLanguage;
                        s.level ??= _selectedLevel;
                        s.classType ??= _classType;
                        s.hoursPerWeek ??= _hoursPerWeek;
                        s.sessionDuration ??= _sessionDuration;
                      }
                    } else {
                      _applyProgramToAll = true;
                      _activeProgramTab = 0;
                      for (final s in _students) {
                        s.subject = _selectedSubject;
                        s.specificLanguage = _selectedAfricanLanguage;
                        s.level = _selectedLevel;
                        s.classType = _classType;
                      }
                    }
                  });
                },
                activeTrackColor: const Color(0xff3B82F6).withOpacity(0.5),
                activeThumbColor: const Color(0xff3B82F6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_applyProgramToAll) ...[
          _buildSubCard(
            title: l.enrollmentStateChooseProgram,
            child: trackSelector,
          ),
          _buildSubCard(
            title: l.enrollmentStateClassPreferences,
            child: Column(
              children: [
                _buildProgramFields(
                  subject: _selectedSubject,
                  onSubjectChanged: (v) {
                    setState(() {
                      _selectedSubject = v;
                      if (v != _afroLanguagesSubject) {
                        _selectedAfricanLanguage = null;
                      }
                      _selectedLevel = null;
                      for (final s in _students) {
                        s.subject = v;
                        s.specificLanguage = null;
                        s.level = null;
                      }
                    });
                  },
                  specificLanguage: _selectedAfricanLanguage,
                  onSpecificLanguageChanged: (v) {
                    setState(() {
                      _selectedAfricanLanguage = v;
                      for (final s in _students) {
                        s.specificLanguage = v;
                      }
                    });
                  },
                  level: _selectedLevel,
                  onLevelChanged: (v) {
                    setState(() {
                      _selectedLevel = v;
                      for (final s in _students) {
                        s.level = v;
                      }
                    });
                  },
                  classType: _classType,
                  onClassTypeChanged: (v) {
                    setState(() {
                      _classType = v;
                      for (final s in _students) {
                        s.classType = v;
                      }
                    });
                  },
                  fieldKeyPrefix: 'applyAll',
                  showTrackSelector: false,
                ),
                const SizedBox(height: 12),
                _buildModernDropdown(
                  l.enrollmentStatePreferredLanguage,
                  _languages,
                  _preferredLanguage,
                  (v) => setState(() => _preferredLanguage = v),
                  Icons.translate_rounded,
                ),
              ],
            ),
          ),
          _buildSubCard(
            title: l.enrollmentStatePricingAndHours,
            child: hoursSection,
          ),
        ] else ...[
          _buildSubCard(
            title: l.enrollmentStateStudentPrograms,
            child: Column(
              children: [
                _buildStudentPillTabs(),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _activeProgramTab == 0
                      ? KeyedSubtree(
                          key: const ValueKey('prog-tab-0'),
                          child: _buildStudentProgramCard(
                            studentIndex: 0,
                            studentName: _studentNameController.text.isNotEmpty
                                ? _studentNameController.text
                                : l.studentDefaultName1,
                            subject: _selectedSubject,
                            onSubjectChanged: (v) {
                              setState(() {
                                _selectedSubject = v;
                                if (v != _afroLanguagesSubject) {
                                  _selectedAfricanLanguage = null;
                                }
                                _selectedLevel = null;
                              });
                            },
                            specificLanguage: _selectedAfricanLanguage,
                            onSpecificLanguageChanged: (v) =>
                                setState(() => _selectedAfricanLanguage = v),
                            level: _selectedLevel,
                            onLevelChanged: (v) =>
                                setState(() => _selectedLevel = v),
                            classType: _classType,
                            onClassTypeChanged: (v) =>
                                setState(() => _classType = v),
                            showGlobalHoursStepper: true,
                          ),
                        )
                      : Builder(
                          key: ValueKey('prog-tab-$_activeProgramTab'),
                          builder: (context) {
                            final i = _activeProgramTab - 1;
                            if (i < 0 || i >= _students.length) {
                              return const SizedBox.shrink();
                            }
                            final student = _students[i];
                            final studentName =
                                student.nameController.text.isNotEmpty
                                    ? student.nameController.text
                                    : 'Student ${i + 2}';
                            return _buildStudentProgramCard(
                              studentIndex: i + 1,
                              studentName: studentName,
                              subject: student.subject,
                              onSubjectChanged: (v) {
                                setState(() {
                                  student.subject = v;
                                  if (v != _afroLanguagesSubject) {
                                    student.specificLanguage = null;
                                  }
                                  student.level = null;
                                });
                              },
                              specificLanguage: student.specificLanguage,
                              onSpecificLanguageChanged: (v) =>
                                  setState(() => student.specificLanguage = v),
                              level: student.level,
                              onLevelChanged: (v) =>
                                  setState(() => student.level = v),
                              classType: student.classType,
                              onClassTypeChanged: (v) =>
                                  setState(() => student.classType = v),
                              hoursRow: student,
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                _buildModernDropdown(
                  l.enrollmentStatePreferredLanguage,
                  _languages,
                  _preferredLanguage,
                  (v) => setState(() => _preferredLanguage = v),
                  Icons.translate_rounded,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ─── Step 3: Schedule (Progressive Disclosure) ──────────────────────

  Widget _buildStep3Schedule({
    bool scrollable = true,
    bool includeStepCardShell = true,
  }) {
    final l = AppLocalizations.of(context)!;
    final isParentWithStudents =
        (_role == 'Parent' || _role == 'Guardian') && _students.isNotEmpty;
    final hasHours = (_hoursPerWeek ?? 0) >= 1;

    return _buildStepCard(
      title: AppLocalizations.of(context)?.schedulePreferences ??
          'Schedule Preferences',
      scrollable: scrollable,
      includeOuterShell: includeStepCardShell,
      subtitle: l.enrollmentScheduleDefaultSubtitle,
      children: [
        // Conversational timezone row
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const Icon(Icons.public_rounded, size: 16, color: Color(0xff3B82F6)),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xff1E293B),
                    ),
                    children: [
                      const TextSpan(text: 'All times are in your local timezone: '),
                      TextSpan(
                        text: _ianaTimeZone,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Text(
          l.enrollmentScheduleConfirmTimesHint,
          style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w500,
            color: const Color(0xff64748B), height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        
        _buildModernLabel(l.enrollmentStateWhichDaysWorkBest),
        const SizedBox(height: 8),
        _buildCompactDayChips(
          selectedDays: _selectedDays,
          onToggle: (day) => setState(() {
            _selectedDays.contains(day)
                ? _selectedDays.remove(day)
                : _selectedDays.add(day);
          }),
        ),
        
        const SizedBox(height: 16),
        _buildModernLabel(l.enrollmentStateWhatTimeOfDay),
        const SizedBox(height: 8),
        _buildTimeOfDayCards(
          _timeOfDayPreference,
          (v) => setState(() {
            _timeOfDayPreference = v;
            _customTimeSlots.clear();
            _selectedTimeSlots
                .removeWhere((slot) => !_filteredTimeSlots.contains(slot));
            for (final s in _students) {
              s.selectedTimeSlots
                  .removeWhere((slot) => !_allTimeSlots.contains(slot));
            }
          }),
        ),
        
        if (hasHours) ...[
          const SizedBox(height: 10),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                l.enrollmentStateAdvancedSelectTimes,
                style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: const Color(0xff3B82F6),
                ),
              ),
              initiallyExpanded: _showDetailedTimeSlots,
              onExpansionChanged: (open) =>
                  setState(() => _showDetailedTimeSlots = open),
              children: [
                if (_allTimeSlots.isNotEmpty)
                  _buildCompactSlotChips(
                    slots: _allTimeSlots,
                    selectedSlots: _selectedTimeSlots,
                    onToggle: (slot) => setState(() {
                      _selectedTimeSlots.contains(slot)
                          ? _selectedTimeSlots.remove(slot)
                          : _selectedTimeSlots.add(slot);
                    }),
                  ),
                if (_sessionDuration != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton.icon(
                      onPressed: _addCustomTimeSlot,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(l.enrollmentStateAddCustomTime,
                          style: GoogleFonts.inter(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xff3B82F6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        // Per-student schedule sections (compact)
        if (isParentWithStudents) ...[
          ..._students.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            final label = s.nameController.text.trim().isNotEmpty
                ? s.nameController.text.trim()
                : 'Student ${i + 2}';
            
            final studentHours = s.hoursPerWeek ?? _hoursPerWeek;
            final studentDuration = s.sessionDuration ?? _sessionDuration;
            final bool canBeSame = _applyProgramToAll || (studentHours == _hoursPerWeek && studentDuration == _sessionDuration);
            
            final bool effectivelyCustom = !canBeSame || s.useCustomSchedule;

            return AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(label,
                            style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: const Color(0xff0F172A),
                            ),
                          ),
                        ),
                        if (canBeSame)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                !s.useCustomSchedule ? 'Same' : 'Custom',
                                style: GoogleFonts.inter(
                                  fontSize: 11, fontWeight: FontWeight.w500,
                                  color: const Color(0xff64748B),
                                ),
                              ),
                              const SizedBox(width: 4),
                              SizedBox(
                                height: 28,
                                child: Switch(
                                  value: s.useCustomSchedule,
                                  onChanged: (bool value) {
                                    setState(() {
                                      s.useCustomSchedule = value;
                                      if (!value) {
                                        s.selectedDays = [];
                                        s.selectedTimeSlots = [];
                                        s.customTimeSlots = [];
                                      } else {
                                        if (s.selectedDays.isEmpty) {
                                          s.selectedDays = List.from(_selectedDays);
                                        }
                                        if (s.selectedTimeSlots.isEmpty) {
                                          s.selectedTimeSlots =
                                              List.from(_selectedTimeSlots);
                                        }
                                      }
                                    });
                                  },
                                  activeTrackColor: const Color(0xff3B82F6).withValues(alpha: 0.5),
                                  activeThumbColor: const Color(0xff3B82F6),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    if (effectivelyCustom) ...[
                      const SizedBox(height: 8),
                      _buildModernLabel(l.enrollmentStateWhatTimeOfDay),
                      const SizedBox(height: 8),
                      _buildTimeOfDayCards(
                        s.timeOfDayPreference ?? _timeOfDayPreference,
                        (v) => setState(() {
                          s.timeOfDayPreference = v;
                          s.customTimeSlots.clear();
                          final slots = _getFilteredTimeSlotsFor(
                              s.sessionDuration ?? _sessionDuration, v);
                          s.selectedTimeSlots
                              .removeWhere((slot) => !slots.contains(slot));
                        }),
                      ),
                      const SizedBox(height: 8),
                      _buildModernLabel(l.enrollmentStatePreferredDays),
                      const SizedBox(height: 6),
                      _buildCompactDayChips(
                        selectedDays: s.selectedDays,
                        onToggle: (day) => setState(() {
                          s.selectedDays.contains(day)
                              ? s.selectedDays.remove(day)
                              : s.selectedDays.add(day);
                        }),
                      ),
                      const SizedBox(height: 6),
                      Builder(
                        builder: (context) {
                          final baseSlots = _getFilteredTimeSlotsFor(
                            s.sessionDuration ?? _sessionDuration,
                            s.timeOfDayPreference ?? _timeOfDayPreference,
                          );
                          final studentSlots = [
                            ...baseSlots,
                            ...s.customTimeSlots
                          ];
                          final hasDuration =
                              (s.hoursPerWeek ?? _hoursPerWeek ?? 0) > 0;
                          return Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: EdgeInsets.zero,
                              title: Text(
                                l.enrollmentStateAdvancedSelectTimes,
                                style: GoogleFonts.inter(
                                  fontSize: 13, fontWeight: FontWeight.w600,
                                  color: const Color(0xff3B82F6),
                                ),
                              ),
                              children: [
                                if (studentSlots.isNotEmpty)
                                  _buildCompactSlotChips(
                                    slots: studentSlots,
                                    selectedSlots: s.selectedTimeSlots,
                                    onToggle: (slot) => setState(() {
                                      s.selectedTimeSlots.contains(slot)
                                          ? s.selectedTimeSlots.remove(slot)
                                          : s.selectedTimeSlots.add(slot);
                                    }),
                                  ),
                                if (hasDuration)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: TextButton.icon(
                                      onPressed: () =>
                                          _addCustomTimeSlotForStudent(s),
                                      icon: const Icon(Icons.add_rounded, size: 16),
                                      label: Text(l.enrollmentStateAddCustomTime,
                                          style: GoogleFonts.inter(fontSize: 12)),
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xff3B82F6),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
        // Scheduling notes — at the bottom, compact
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xffFEF3C7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xffFDE68A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_note_rounded, color: Color(0xffD97706), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Important Scheduling Notes',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff92400E),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xffFDE68A),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(l.enrollmentStateOptional,
                        style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: const Color(0xffB45309),
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _schedulingNotesController,
                maxLines: 3,
                minLines: 2,
                style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w500,
                  color: const Color(0xff0F172A),
                ),
                decoration: InputDecoration(
                  hintText: l.enrollmentStateSchedulingNotesHint,
                  hintStyle: GoogleFonts.inter(
                    color: const Color(0xff94A3B8), fontWeight: FontWeight.w400,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xffFDE68A)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xffFDE68A)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xffF59E0B), width: 2),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Compact day chips (Mon, Tue, Wed...) with tight padding.
  Widget _buildCompactDayChips({
    required List<String> selectedDays,
    required void Function(String day) onToggle,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _days.map((day) {
        final isSelected = selectedDays.contains(day);
        return InkWell(
          onTap: () => onToggle(day),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [Color(0xff3B82F6), Color(0xff2563EB)])
                  : null,
              color: isSelected ? null : const Color(0xffF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              day.length > 3 ? day.substring(0, 3) : day,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: isSelected ? Colors.white : const Color(0xff64748B),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Compact time slot chips with tight padding.
  Widget _buildCompactSlotChips({
    required List<String> slots,
    required List<String> selectedSlots,
    required void Function(String slot) onToggle,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: slots.map((slot) {
        final isSelected = selectedSlots.contains(slot);
        return InkWell(
          onTap: () => onToggle(slot),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [Color(0xff10B981), Color(0xff059669)])
                  : null,
              color: isSelected ? null : const Color(0xffF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              slot,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: isSelected ? Colors.white : const Color(0xff64748B),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Step 4: Review + Contact (was Step 4 Contact+Review) ───────────

  Widget _buildStep4ReviewContact({
    bool scrollable = true,
    bool includeStepCardShell = true,
  }) {
    final l = AppLocalizations.of(context)!;
    return _buildStepCard(
      title: l.enrollmentWizardContactTitle,
      subtitle: l.enrollmentWizardContactSubtitle,
      scrollable: scrollable,
      includeOuterShell: includeStepCardShell,
      centerHeader: true,
      children: [
        EnrollmentReviewSummaryCard(
          sections: _buildReviewSections(),
          onEditSection: (stepIndex) {
            _cardController.reverse().then((_) {
              setState(() => _currentStep = stepIndex);
              _cardController.forward();
              _scrollRightPaneToTop();
            });
          },
        ),
        const SizedBox(height: 16),
        _buildEnrollmentContactPanel(),
      ],
    );
  }

  List<EnrollmentReviewSection> _buildReviewSections() {
    final l = AppLocalizations.of(context)!;
    final parentMulti =
        (_role == 'Parent' || _role == 'Guardian') && _students.isNotEmpty;
    final sections = <EnrollmentReviewSection>[];

    // ── Students (names / ages) ───────────────────────────────────────
    final studentRows = <(String, String)>[];
    final name1 = _studentNameController.text.trim().isNotEmpty
        ? _studentNameController.text.trim()
        : l.studentDefaultName1;
    final age1 = _studentAgeController.text.trim();
    studentRows.add(('Student 1', '$name1${age1.isNotEmpty ? ', $age1' : ''}'));
    if (parentMulti) {
      for (var i = 0; i < _students.length; i++) {
        final s = _students[i];
        final nm = s.nameController.text.trim().isNotEmpty
            ? s.nameController.text.trim()
            : 'Student ${i + 2}';
        final a = s.ageController.text.trim();
        studentRows.add(('Student ${i + 2}', '$nm${a.isNotEmpty ? ', $a' : ''}'));
      }
    }

    // ── Program / enrollment details ───────────────────────────────────
    final programRows = <(String, String)>[];
    programRows.addAll(studentRows);

    if (!parentMulti) {
      final progLabel = _shortProgramLabelFromSubject(_selectedSubject);
      if (progLabel.isNotEmpty) programRows.add(('Program', progLabel));
      if (_selectedLevel != null) programRows.add(('Level', _selectedLevel!));
      if (_classType != null) programRows.add(('Format', _classType!));
      if ((_hoursPerWeek ?? 0) > 0) {
        programRows.add(('Hours/week', '${_hoursPerWeek}h'));
      }
    } else if (_applyProgramToAll && !_perChildProgramBundlesDifferFromFirst()) {
      final progLabel = _shortProgramLabelFromSubject(_selectedSubject);
      if (progLabel.isNotEmpty) programRows.add(('Program', progLabel));
      if (_selectedLevel != null) programRows.add(('Level', _selectedLevel!));
      if (_classType != null) programRows.add(('Format', _classType!));
      if ((_hoursPerWeek ?? 0) > 0) {
        programRows.add(('Hours/week', '${_hoursPerWeek}h'));
      }
    } else {
      for (var slot = 0; slot < 1 + _students.length; slot++) {
        final name = _reviewStudentSlotName(slot, l);
        final subj = _programSubjectForReviewSlot(slot);
        final prog = _shortProgramLabelFromSubject(subj);
        final lev = _programLevelForReviewSlot(slot);
        final fmt = _programClassTypeForReviewSlot(slot);
        final h = _programHoursForReviewSlot(slot);
        final tr = _trackForSubject(subj) ?? _quoteTrackId;
        final detail = l.enrollmentSummaryLineDetail(
          prog,
          h,
          _monthlyEstimatePriceLabel(tr, h),
        );
        final levStr = lev ?? '—';
        final fmtStr = fmt ?? '—';
        programRows.add((name, '$levStr · $fmtStr · $detail'));
      }
    }
    if (programRows.isNotEmpty) {
      sections.add(EnrollmentReviewSection(
        sectionTitle: 'Enrollment Details',
        icon: '\u{1F4CB}',
        editStepIndex: 1,
        rows: programRows,
      ));
    }

    // ── Schedule ──────────────────────────────────────────────────────
    final schedRows = <(String, String)>[];
    if (!parentMulti) {
      if (_selectedDays.isNotEmpty) {
        schedRows.add(('Days', _abbrevDaysLine(_selectedDays)));
      }
      if (_selectedTimeSlots.isNotEmpty) {
        schedRows.add(('Time slots', _selectedTimeSlots.join(', ')));
      }
      if (_timeOfDayPreference != null) {
        schedRows.add(('Time preference', _timeOfDayPreference!));
      }
    } else if (_allHouseholdStudentsShareSameSchedule()) {
      if (_selectedDays.isNotEmpty) {
        schedRows.add(('Days', _abbrevDaysLine(_selectedDays)));
      }
      if (_selectedTimeSlots.isNotEmpty) {
        schedRows.add(('Time slots', _selectedTimeSlots.join(', ')));
      }
      if (_timeOfDayPreference != null) {
        schedRows.add(('Time preference', _timeOfDayPreference!));
      }
    } else {
      for (var slot = 0; slot < 1 + _students.length; slot++) {
        final name = _reviewStudentSlotName(slot, l);
        final days = _daysForScheduleReviewSlot(slot);
        final slots = _slotsForScheduleReviewSlot(slot);
        final tod = _todForScheduleReviewSlot(slot);
        if (days.isNotEmpty) {
          schedRows.add(('$name — Days', _abbrevDaysLine(days)));
        }
        if (slots.isNotEmpty) {
          schedRows.add(('$name — Time slots', slots.join(', ')));
        }
        if (tod != null && tod.isNotEmpty) {
          schedRows.add(('$name — Time preference', tod));
        }
      }
    }
    if (schedRows.isNotEmpty) {
      sections.add(EnrollmentReviewSection(
        sectionTitle: 'Schedule',
        icon: '\u{1F4C5}',
        editStepIndex: 3,
        rows: schedRows,
      ));
    }

    return sections;
  }

  /// Dark “contact card” (reference layout): parent name + email grid, then
  /// WhatsApp / phone, then country / city. Same controllers and submit data.
  Widget _buildEnrollmentContactPanel() {
    final l = AppLocalizations.of(context)!;
    const borderLine = Color(0xff334155);
    const labelOnDark = Color(0xffCBD5E1);
    const phoneDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xffCBD5E1), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xffCBD5E1), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xff3B82F6), width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );

    final emailField = _buildModernTextField(
      _role == 'Student' ? l.userEmail : l.enrollmentContactEmailFieldLabel,
      _emailController,
      Icons.email_outlined,
      hint: 'your@email.com',
      isEnabled: _linkedParentData == null,
      onDarkPanel: true,
      onChanged: (_) => setState(() {}),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Required';
        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
          return 'Enter a valid email';
        }
        return null;
      },
    );

    final parentField = _buildModernTextField(
      l.enrollmentContactParentFullNameLabel,
      _parentNameController,
      Icons.person_outline_rounded,
      hint: l.enrollmentContactParentFullNameHint,
      isEnabled: _linkedParentData == null,
      onDarkPanel: true,
      onChanged: (_) => setState(() {}),
      validator: (v) {
        if (!_isParentGuardian || _linkedParentData != null) return null;
        if (v == null || v.trim().isEmpty) return 'Required';
        return null;
      },
    );

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff0F172A), Color(0xff1E293B)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderLine),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.enrollmentContactPanelTitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.enrollmentContactPanelHint,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xff94A3B8),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, c) {
              final narrow = c.maxWidth < 520;
              if (!_isParentGuardian) {
                return emailField;
              }
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    parentField,
                    const SizedBox(height: 14),
                    emailField,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: parentField),
                  const SizedBox(width: 12),
                  Expanded(child: emailField),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final narrow = c.maxWidth < 520;
              final wa = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModernLabel(l.whatsappNumber, color: labelOnDark),
                  const SizedBox(height: 6),
                  IntlPhoneField(
                    controller: _whatsAppNumberController,
                    key: ValueKey('wa_panel_$_initialCountryCode'),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onCountryChanged: (country) {
                      setState(() {
                        _whatsAppIntlCountryCode = country.code;
                      });
                    },
                    decoration: phoneDecoration.copyWith(
                      hintText: l.whatsappNumber,
                      hintStyle:
                          GoogleFonts.inter(color: const Color(0xff94A3B8)),
                    ),
                    initialCountryCode: _initialCountryCode,
                    onChanged: (phone) {
                      setState(() => _whatsAppNumber = phone.completeNumber);
                    },
                  ),
                ],
              );
              final ph = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModernLabel(l.userPhone, color: labelOnDark),
                  const SizedBox(height: 6),
                  IntlPhoneField(
                    controller: _phoneController,
                    key: ValueKey('phone_panel_$_initialCountryCode'),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onCountryChanged: (country) {
                      setState(() => _phoneIntlCountryCode = country.code);
                    },
                    decoration: phoneDecoration.copyWith(
                      hintText: l.userPhone,
                      hintStyle:
                          GoogleFonts.inter(color: const Color(0xff94A3B8)),
                    ),
                    initialCountryCode: _initialCountryCode,
                    onChanged: (phone) {
                      setState(() => _phoneNumber = phone.completeNumber);
                    },
                  ),
                ],
              );
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    wa,
                    const SizedBox(height: 14),
                    ph,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: wa),
                  const SizedBox(width: 12),
                  Expanded(child: ph),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final narrow = c.maxWidth < 520;
              final country = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModernLabel(l.selectCountry, color: labelOnDark),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () {
                      showCountryPicker(
                        context: context,
                        showPhoneCode: false,
                        countryListTheme: CountryListThemeData(
                          borderRadius: BorderRadius.circular(16),
                          inputDecoration: InputDecoration(
                            hintText: l.searchCountry,
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        onSelect: (Country country) {
                          setState(() {
                            _selectedCountry = country;
                            _initialCountryCode = country.countryCode;
                            _phoneIntlCountryCode = country.countryCode;
                            _whatsAppIntlCountryCode = country.countryCode;
                          });
                        },
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xffCBD5E1), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _selectedCountry?.flagEmoji ?? '🇺🇸',
                            style: const TextStyle(fontSize: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _selectedCountry?.name ?? l.selectCountry,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xff374151),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xff94A3B8),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
              final city = _buildModernTextField(
                l.city,
                _cityController,
                Icons.location_city_outlined,
                hint: l.city,
                onDarkPanel: true,
                onChanged: (_) => setState(() {}),
              );
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    country,
                    const SizedBox(height: 14),
                    city,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: country),
                  const SizedBox(width: 12),
                  Expanded(child: city),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Segmented Controls ─────────────────────────────────────────────

  Widget _buildSegmentedClassType(String? value, Function(String?) onChanged) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModernLabel(l.enrollmentStateClassType),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff0F172A).withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(
                  value: 'One-on-One',
                  label: Text(l.enrollmentStateOneOnOne),
                  icon: const Icon(Icons.person, size: 14)),
              ButtonSegment(
                  value: 'Group',
                  label: Text(l.enrollmentStateGroupClass),
                  icon: const Icon(Icons.groups, size: 14)),
              ButtonSegment(value: 'Both', label: Text(l.enrollmentStateBoth)),
            ],
            selected: value != null ? {value} : {},
            emptySelectionAllowed: true,
            onSelectionChanged: (s) => onChanged(s.isEmpty ? null : s.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(
                  GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  )),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xff3B82F6);
                }
                return const Color(0xffFAFBFC);
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return const Color(0xff64748B);
              }),
              side: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const BorderSide(color: Color(0xff3B82F6), width: 1.5);
                }
                return const BorderSide(color: Color(0xffE2E8F0), width: 1.5);
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedGender(String? value, Function(String?) onChanged) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModernLabel(l.enrollmentStateGender),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff0F172A).withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(
                  value: 'Male',
                  label: Text(l.enrollmentStateMale),
                  icon: const Icon(Icons.male, size: 14)),
              ButtonSegment(
                  value: 'Female',
                  label: Text(l.enrollmentStateFemale),
                  icon: const Icon(Icons.female, size: 14)),
            ],
            selected: value != null ? {value} : {},
            emptySelectionAllowed: true,
            onSelectionChanged: (s) => onChanged(s.isEmpty ? null : s.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(
                  GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  )),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xff3B82F6);
                }
                return const Color(0xffFAFBFC);
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return const Color(0xff64748B);
              }),
              side: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const BorderSide(color: Color(0xff3B82F6), width: 1.5);
                }
                return const BorderSide(color: Color(0xffE2E8F0), width: 1.5);
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeOfDayCards(String? selected, Function(String?) onChanged) {
    final l = AppLocalizations.of(context)!;
    final items = [
      ('Morning', Icons.wb_sunny_outlined, const Color(0xffF59E0B)),
      ('Afternoon', Icons.wb_cloudy_outlined, const Color(0xff3B82F6)),
      ('Evening', Icons.nights_stay_outlined, const Color(0xff6366F1)),
      ('Flexible', Icons.access_time_rounded, const Color(0xff10B981)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModernLabel(l.enrollmentStatePreferredTimeOfDay),
        const SizedBox(height: 5),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: items.map((item) {
            final isSelected = selected == item.$1;
            return GestureDetector(
              onTap: () => onChanged(isSelected ? null : item.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            item.$3.withValues(alpha: 0.15),
                            item.$3.withValues(alpha: 0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : const Color(0xffFAFBFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? item.$3 : const Color(0xffE2E8F0),
                    width: isSelected ? 2 : 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: item.$3.withValues(alpha: 0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: const Color(0xff0F172A).withValues(alpha: 0.02),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.$2,
                        size: 15,
                        color: isSelected ? item.$3 : const Color(0xff64748B)),
                    const SizedBox(width: 5),
                    Text(
                      item.$1,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? item.$3 : const Color(0xff475569),
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Modern Helpers ─────────────────────────────────────────────────

  Widget _buildModernLabel(String text, {Color? color}) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: 11,
        letterSpacing: 0.12,
        color: color ?? const Color(0xff1E293B),
        height: 1.25,
      ),
    );
  }

  Widget _buildModernTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isNumber = false,
    bool isEnabled = true,
    String? hint,
    bool compact = false,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    bool onDarkPanel = false,
  }) {
    final labelColor =
        onDarkPanel ? const Color(0xffCBD5E1) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModernLabel(label, color: labelColor),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff0F172A).withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            enabled: isEnabled,
            onChanged: onChanged,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            inputFormatters: inputFormatters ??
                (isNumber ? [FilteringTextInputFormatter.digitsOnly] : null),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xff0F172A),
              height: 1.35,
              letterSpacing: 0.05,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint ?? label,
              hintStyle: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xff94A3B8),
                fontWeight: FontWeight.w400,
                letterSpacing: 0.05,
              ),
            prefixIcon: Icon(icon, color: const Color(0xff64748B), size: 18),
            filled: true,
            fillColor: onDarkPanel
                ? (isEnabled ? Colors.white : const Color(0xffF1F5F9))
                : (isEnabled
                    ? const Color(0xffFAFBFC)
                    : const Color(0xffF1F5F9)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: onDarkPanel
                    ? const Color(0xffCBD5E1)
                    : const Color(0xffE2E8F0),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: onDarkPanel
                    ? const Color(0xffCBD5E1)
                    : const Color(0xffE2E8F0),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xff3B82F6), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xffEF4444), width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xffEF4444), width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: onDarkPanel
                    ? const Color(0xff94A3B8)
                    : const Color(0xffE2E8F0),
                width: 1.5,
              ),
            ),
            contentPadding: compact
                ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
                : const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          ),
          validator: validator ??
              (value) => value == null || value.isEmpty ? 'Required' : null,
        ),
      ),
    ],
  );
}

  Widget _buildModernDropdown(
    String label,
    List<String> items,
    String? value,
    Function(String?) onChanged,
    IconData icon, {
    bool isRequired = true,
    String? hintText,
    Key? fieldKey,
  }) {
    final effectiveHint = hintText ?? 'Select $label';
    final effectiveValue =
        (value != null && items.contains(value)) ? value : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModernLabel(label),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff0F172A).withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            key: fieldKey,
            isExpanded: true,
            value: effectiveValue,
            validator: isRequired
                ? (v) => v == null || v.isEmpty ? 'Required' : null
                : null,
            items: items
                .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xff1E293B),
                          letterSpacing: 0.05,
                        ),
                      ),
                    ))
                .toList(),
            onChanged: onChanged,
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: Color(0xff64748B), size: 18),
            decoration: InputDecoration(
              isDense: true,
              hintText: effectiveHint,
              hintStyle: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xff94A3B8),
                fontWeight: FontWeight.w400,
                letterSpacing: 0.05,
              ),
              prefixIcon: Icon(icon, color: const Color(0xff64748B), size: 18),
              filled: true,
              fillColor: const Color(0xffFAFBFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xffE2E8F0), width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xffE2E8F0), width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xff3B82F6), width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xffEF4444), width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xffEF4444), width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            ),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }

  // ─── Submit ─────────────────────────────────────────────────────────

  Future<void> _submitForm() async {
    final l = AppLocalizations.of(context)!;
    if (_formKey.currentState!.validate() && _validatePhoneFields(l)) {
      setState(() => _isSubmitting = true);
      try {
        final isAdultStudent = _isAdult;
        final isParentOrGuardian = _role == 'Parent' || _role == 'Guardian';

        if (isParentOrGuardian && _students.isNotEmpty) {
          final plan = _pricingPlanForSubmit();
          final allStudents = <StudentInfo>[
            StudentInfo(
              name: _studentNameController.text.trim(),
              age: _studentAgeController.text.trim(),
              gender: _gender,
              subject: _selectedSubject,
              specificLanguage: _selectedSubject == _afroLanguagesSubject
                  ? _selectedAfricanLanguage
                  : null,
              level: _selectedLevel,
              classType: _classType,
              sessionDuration: _sessionDuration,
              hoursPerWeek: _hoursPerWeek,
              timeOfDayPreference: _timeOfDayPreference,
              preferredDays: _selectedDays,
              preferredTimeSlots: _selectedTimeSlots,
              trackId: _trackForSubject(_selectedSubject),
            ),
            ..._students.map((s) => StudentInfo(
                  name: s.nameController.text.trim(),
                  age: s.ageController.text.trim(),
                  gender: s.gender,
                  subject: _applyProgramToAll
                      ? _selectedSubject
                      : (s.subject ?? _selectedSubject),
                  specificLanguage:
                      (_applyProgramToAll ? _selectedSubject : s.subject) ==
                              _afroLanguagesSubject
                          ? (_applyProgramToAll
                              ? _selectedAfricanLanguage
                              : s.specificLanguage)
                          : null,
                  level: _applyProgramToAll
                      ? _selectedLevel
                      : (s.level ?? _selectedLevel),
                  classType: _applyProgramToAll
                      ? _classType
                      : (s.classType ?? _classType),
                  sessionDuration: s.sessionDuration ?? _sessionDuration,
                  hoursPerWeek: s.hoursPerWeek ?? _hoursPerWeek,
                  timeOfDayPreference:
                      s.timeOfDayPreference ?? _timeOfDayPreference,
                  preferredDays: s.selectedDays.isNotEmpty
                      ? s.selectedDays
                      : _selectedDays,
                  preferredTimeSlots: s.selectedTimeSlots.isNotEmpty
                      ? s.selectedTimeSlots
                      : _selectedTimeSlots,
                  trackId: _trackForSubject(
                    _applyProgramToAll
                        ? _selectedSubject
                        : (s.subject ?? _selectedSubject),
                  ),
                )),
          ];

          await EnrollmentService().submitMultipleEnrollments(
            parentName: _parentNameController.text.trim(),
            email: _emailController.text.trim(),
            phoneNumber: _phoneNumber,
            countryCode: _selectedCountry?.countryCode ?? 'US',
            countryName: _selectedCountry?.name ?? 'United States',
            city: _cityController.text.trim(),
            whatsAppNumber: _whatsAppNumber,
            timeZone: _ianaTimeZone,
            preferredLanguage: _preferredLanguage ?? 'English',
            role: _role ?? 'Parent',
            guardianId: _guardianId,
            students: allStudents,
            programTitle: widget.initialPricingPlanSummary,
            pricingPlanId: plan.id,
            pricingPlanLabel: plan.label,
            trackId: _quoteTrackId ?? _resolvedTrackId,
            hoursPerWeek: _hoursPerWeek,
            schedulingNotes: _schedulingNotesController.text.trim().isEmpty
                ? null
                : _schedulingNotesController.text.trim(),
          );
        } else {
          final plan = _pricingPlanForSubmit();
          final request = EnrollmentRequest(
            subject: _selectedSubject,
            programTitle: widget.initialPricingPlanSummary,
            specificLanguage: _selectedSubject == _afroLanguagesSubject
                ? _selectedAfricanLanguage
                : null,
            gradeLevel: _selectedLevel ?? _selectedGrade ?? '',
            email: _emailController.text.trim(),
            phoneNumber: _phoneNumber,
            countryCode: _selectedCountry?.countryCode ?? 'US',
            countryName: _selectedCountry?.name ?? 'United States',
            preferredDays: _selectedDays,
            preferredTimeSlots: _selectedTimeSlots,
            submittedAt: DateTime.now(),
            timeZone: _ianaTimeZone,
            role: isAdultStudent ? 'Student' : (_role ?? 'Parent'),
            preferredLanguage: _preferredLanguage,
            parentName:
                isAdultStudent ? null : _parentNameController.text.trim(),
            city: _cityController.text.trim(),
            whatsAppNumber: _whatsAppNumber,
            studentName: _studentNameController.text.trim(),
            studentAge: _studentAgeController.text.trim(),
            gender: _gender,
            knowsZoom: null,
            classType: _classType,
            sessionDuration: _sessionDuration,
            hoursPerWeek: _hoursPerWeek,
            timeOfDayPreference: _timeOfDayPreference,
            guardianId: _guardianId,
            isAdult: isAdultStudent,
            pricingPlanId: plan.id,
            pricingPlanLabel: plan.label,
            trackId: _quoteTrackId ?? _resolvedTrackId,
            schedulingNotes: _schedulingNotesController.text.trim().isEmpty
                ? null
                : _schedulingNotesController.text.trim(),
          );

          await EnrollmentService().submitEnrollment(request);
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const EnrollmentSuccessPage(),
              transitionDuration: const Duration(milliseconds: 400),
              transitionsBuilder: (_, animation, __, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('Error: $e', isError: true);
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }
}
