import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

enum _InvoiceBillingMode {
  combinedNow,
  separateNow,
  recurring,
}

/// Admin screen to create invoices for parents (with children) or adult students.
class AdminCreateInvoiceScreen extends StatefulWidget {
  const AdminCreateInvoiceScreen({super.key});

  @override
  State<AdminCreateInvoiceScreen> createState() =>
      _AdminCreateInvoiceScreenState();
}

class _AdminCreateInvoiceScreenState extends State<AdminCreateInvoiceScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _firestore = FirebaseFirestore.instance;

  // All parents + adult students loaded once
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoadingUsers = true;
  bool _showSearchResults = false;

  // Selected user
  Map<String, dynamic>? _selectedUser;
  String? _selectedUserId;

  // Children of the selected parent
  List<Map<String, dynamic>> _children = [];
  bool _isLoadingChildren = false;

  // Amount controllers per child
  final Map<String, TextEditingController> _amountControllers = {};
  final Map<String, TextEditingController> _descriptionControllers = {};

  // Billing months
  final Set<DateTime> _selectedMonths = {};
  _InvoiceBillingMode _billingMode = _InvoiceBillingMode.combinedNow;
  int _recurringSendDay = 1;

  // Due date (default: 7 days from now)
  late DateTime _dueDate;
  // Which preset button is active (null = calendar pick or none)
  int? _activePresetDays = 7;

  // Access cutoff date — day after due date by default
  late DateTime _accessCutoffDate;
  // Track whether cutoff is still at the auto-default; if so, advance it when due date changes
  bool _accessCutoffIsDefault = true;

  bool _isCreating = false;
  String? _error;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    // Default to current month
    final now = DateTime.now();
    _selectedMonths.add(DateTime(now.year, now.month));
    // Default due date: 7 days from today
    _dueDate =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 7));
    // Default access cutoff: 1 day after due date
    _accessCutoffDate = _dueDate.add(const Duration(days: 1));
    _loadAllUsers();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (_searchFocusNode.hasFocus) {
      setState(() {
        _showSearchResults = true;
        _filteredUsers = _allUsers;
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchFocusNode.removeListener(_onFocusChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    for (final c in _amountControllers.values) {
      c.dispose();
    }
    for (final c in _descriptionControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _showSearchResults = true;
      if (query.isEmpty) {
        _filteredUsers = _allUsers;
        return;
      }
      _filteredUsers = _allUsers.where((user) {
        final name = '${user['first_name']} ${user['last_name']}'.toLowerCase();
        final email = (user['email'] ?? '').toString().toLowerCase();
        final phone = (user['phone'] ?? '').toString().toLowerCase();
        final compactPhone = phone.replaceAll(RegExp(r'\D'), '');
        final compactQuery = query.replaceAll(RegExp(r'\D'), '');
        return name.contains(query) ||
            email.contains(query) ||
            phone.contains(query) ||
            (compactQuery.isNotEmpty && compactPhone.contains(compactQuery));
      }).toList();
    });
  }

  Future<void> _loadAllUsers() async {
    try {
      final parentSnap = await _firestore
          .collection('users')
          .where('user_type', isEqualTo: 'parent')
          .get();

      final studentSnap = await _firestore
          .collection('users')
          .where('user_type', isEqualTo: 'student')
          .where('is_adult_student', isEqualTo: true)
          .get();

      final users = <Map<String, dynamic>>[];
      for (final doc in [...parentSnap.docs, ...studentSnap.docs]) {
        final data = doc.data();
        users.add({
          'id': doc.id,
          'first_name': (data['first_name'] ?? '').toString(),
          'last_name': (data['last_name'] ?? '').toString(),
          'email': (data['e-mail'] ?? '').toString(),
          'phone': _phoneFromUserData(data),
          'user_type': (data['user_type'] ?? '').toString(),
          'children_ids': List<String>.from(data['children_ids'] ?? []),
          'is_adult_student': data['is_adult_student'] == true,
        });
      }

      // Sort alphabetically
      users.sort((a, b) {
        final nameA = '${a['first_name']} ${a['last_name']}'.toLowerCase();
        final nameB = '${b['first_name']} ${b['last_name']}'.toLowerCase();
        return nameA.compareTo(nameB);
      });

      if (mounted) {
        setState(() {
          _allUsers = users;
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      AppLogger.error('AdminCreateInvoice: Failed to load users: $e');
      if (mounted) {
        setState(() => _isLoadingUsers = false);
      }
    }
  }

  Future<void> _selectUser(Map<String, dynamic> user) async {
    // Clear old state
    for (final c in _amountControllers.values) {
      c.dispose();
    }
    for (final c in _descriptionControllers.values) {
      c.dispose();
    }
    _amountControllers.clear();
    _descriptionControllers.clear();

    setState(() {
      _selectedUser = user;
      _selectedUserId = user['id'];
      _children = [];
      _isLoadingChildren = true;
      _error = null;
      _successMessage = null;
      _showSearchResults = false;
      _searchController.clear();
    });

    final userType = user['user_type'];
    final childrenIds = List<String>.from(user['children_ids'] ?? []);

    if (userType == 'parent' && childrenIds.isNotEmpty) {
      final children = <Map<String, dynamic>>[];
      for (final childId in childrenIds) {
        try {
          final doc = await _firestore.collection('users').doc(childId).get();
          if (doc.exists) {
            final data = doc.data()!;
            children.add({
              'id': doc.id,
              'first_name': (data['first_name'] ?? '').toString(),
              'last_name': (data['last_name'] ?? '').toString(),
            });
            _amountControllers[doc.id] = TextEditingController(text: '0.00');
            _descriptionControllers[doc.id] =
                TextEditingController(text: 'Tuition');
          }
        } catch (e) {
          AppLogger.error('Failed to load child $childId: $e');
        }
      }
      if (mounted) {
        setState(() {
          _children = children;
          _isLoadingChildren = false;
        });
      }
    } else {
      // Adult student paying for themselves
      _amountControllers[user['id']] = TextEditingController(text: '0.00');
      _descriptionControllers[user['id']] =
          TextEditingController(text: 'Tuition');
      if (mounted) {
        setState(() {
          _children = [
            {
              'id': user['id'],
              'first_name': user['first_name'],
              'last_name': user['last_name'],
            }
          ];
          _isLoadingChildren = false;
        });
      }
    }
  }

  void _clearSelection() {
    for (final c in _amountControllers.values) {
      c.dispose();
    }
    for (final c in _descriptionControllers.values) {
      c.dispose();
    }
    _amountControllers.clear();
    _descriptionControllers.clear();
    setState(() {
      _selectedUser = null;
      _selectedUserId = null;
      _children = [];
      _error = null;
      _successMessage = null;
    });
  }

  List<Map<String, dynamic>>? _buildInvoiceItems({
    DateTime? month,
    bool includeMonthInDescription = false,
    required String missingPositiveAmountMessage,
  }) {
    final items = <Map<String, dynamic>>[];
    for (final child in _children) {
      final childId = child['id'] as String;
      final amountText = _amountControllers[childId]?.text.trim() ?? '';
      final description =
          _descriptionControllers[childId]?.text.trim() ?? 'Tuition';

      if (amountText.isEmpty) continue;

      final amount = double.tryParse(amountText);
      if (amount == null || amount <= 0) {
        setState(() => _error =
            'Invalid amount for ${child['first_name']} ${child['last_name']}');
        return null;
      }

      final childName = '${child['first_name']} ${child['last_name']}'.trim();
      final monthLabel = month == null ? '' : DateFormat.yMMMM().format(month);
      final itemDescription = [
        description,
        childName,
        if (includeMonthInDescription && monthLabel.isNotEmpty) monthLabel,
      ].join(' - ');
      items.add({
        'description': itemDescription,
        'quantity': 1,
        'unit_price': amount,
        'total': amount,
      });
    }

    if (items.isEmpty) {
      setState(() => _error = missingPositiveAmountMessage);
      return null;
    }
    return items;
  }

  int get _dueDaysForRecurring {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    return _dueDate.difference(todayNorm).inDays.clamp(0, 365);
  }

  int get _accessCutoffDaysAfterDue {
    return _accessCutoffDate.difference(_dueDate).inDays.clamp(0, 365);
  }

  Future<void> _createInvoice() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedMonths.isEmpty) {
      setState(() => _error = l10n.adminCreateInvoiceSelectBillingMonth);
      return;
    }

    final sortedMonths = _selectedMonths.toList()
      ..sort((a, b) => a.compareTo(b));
    final firstChildId = _children.first['id'] as String;
    final parentId = _selectedUserId!;
    final billToId =
        _selectedUser!['user_type'] == 'parent' ? parentId : firstChildId;

    setState(() {
      _isCreating = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('createInvoice');
      final invoiceNumbers = <String>[];

      if (_billingMode == _InvoiceBillingMode.recurring) {
        final items = _buildInvoiceItems(
          missingPositiveAmountMessage:
              l10n.adminCreateInvoiceMissingPositiveAmount,
        );
        if (items == null) return;
        await callable.call({
          'billingMode': 'recurring',
          'parentId': billToId,
          'studentId': firstChildId,
          'currency': 'USD',
          'items': items,
          'period': DateFormat('yyyy-MM').format(sortedMonths.first),
          'periods': sortedMonths
              .map((month) => DateFormat('yyyy-MM').format(month))
              .toList(),
          'recurringSendDay': _recurringSendDay,
          'repeatIntervalMonths': 1,
          'repeatCount': sortedMonths.length,
          'dueDays': _dueDaysForRecurring,
          'accessCutoffDaysAfterDue': _accessCutoffDaysAfterDue,
        });
        setState(() {
          _successMessage = l10n.adminCreateInvoiceRecurringCreated(
            DateFormat.yMMMM().format(sortedMonths.first),
          );
          for (final c in _amountControllers.values) {
            c.text = '0.00';
          }
        });
        return;
      }

      if (_billingMode == _InvoiceBillingMode.combinedNow) {
        final items = <Map<String, dynamic>>[];
        for (final month in sortedMonths) {
          final monthItems = _buildInvoiceItems(
            month: month,
            includeMonthInDescription: sortedMonths.length > 1,
            missingPositiveAmountMessage:
                l10n.adminCreateInvoiceMissingPositiveAmount,
          );
          if (monthItems == null) return;
          items.addAll(monthItems);
        }
        final period = sortedMonths.length == 1
            ? DateFormat('yyyy-MM').format(sortedMonths.first)
            : '${DateFormat('yyyy-MM').format(sortedMonths.first)} to ${DateFormat('yyyy-MM').format(sortedMonths.last)}';
        final result = await callable.call({
          'parentId': billToId,
          'studentId': firstChildId,
          'currency': 'USD',
          'items': items,
          'period': period,
          'dueDate': _dueDate.toIso8601String(),
          'accessCutoffDate': _accessCutoffDate.toIso8601String(),
          'recurring': false,
        });
        final data = (result.data as Map?)?.cast<String, dynamic>() ?? {};
        invoiceNumbers.add((data['invoiceNumber'] ?? 'Unknown').toString());
      } else {
        for (final month in sortedMonths) {
          final items = _buildInvoiceItems(
            month: month,
            missingPositiveAmountMessage:
                l10n.adminCreateInvoiceMissingPositiveAmount,
          );
          if (items == null) return;
          final period = DateFormat('yyyy-MM').format(month);
          final result = await callable.call({
            'parentId': billToId,
            'studentId': firstChildId,
            'currency': 'USD',
            'items': items,
            'period': period,
            'dueDate': _dueDate.toIso8601String(),
            'accessCutoffDate': _accessCutoffDate.toIso8601String(),
            'recurring': false,
          });

          final data = (result.data as Map?)?.cast<String, dynamic>() ?? {};
          invoiceNumbers.add((data['invoiceNumber'] ?? 'Unknown').toString());
        }
      }

      setState(() {
        _successMessage = invoiceNumbers.length == 1
            ? l10n.adminCreateInvoiceOneCreated(invoiceNumbers.first)
            : l10n.adminCreateInvoiceManyCreated(
                invoiceNumbers.length,
                invoiceNumbers.join(', '),
              );
        for (final c in _amountControllers.values) {
          c.text = '0.00';
        }
      });
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;
    final contentWidth = isWide ? 640.0 : double.infinity;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoadingUsers
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentWidth),
                child: CustomScrollView(
                  slivers: [
                    // Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF0386FF),
                                        Color(0xFF0EA5E9),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.receipt_long,
                                      color: Colors.white, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Create Invoice',
                                        style: GoogleFonts.inter(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Bill a parent or adult student',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: const Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          ],
                        ),
                      ),
                    ),

                    // Selected user or search
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                        child: _selectedUser != null
                            ? _buildSelectedUserCard()
                            : _buildSearchSection(),
                      ),
                    ),

                    // Month selector
                    if (_selectedUser != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                          child: _buildBillingPlanSection(),
                        ),
                      ),

                    // Due date picker
                    if (_selectedUser != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                          child: _buildDueDatePicker(),
                        ),
                      ),

                    // Access cutoff date picker
                    if (_selectedUser != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                          child: _buildAccessCutoffPicker(),
                        ),
                      ),

                    // Children amount entries
                    if (_selectedUser != null && !_isLoadingChildren)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                          child: _buildAmountSection(),
                        ),
                      ),

                    if (_isLoadingChildren)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),

                    // Messages + button
                    if (_selectedUser != null && !_isLoadingChildren)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                          child: Column(
                            children: [
                              if (_error != null) ...[
                                _buildMessage(
                                  _error!,
                                  icon: Icons.error_outline,
                                  bgColor: const Color(0xFFFEF2F2),
                                  borderColor: const Color(0xFFFECACA),
                                  iconColor: const Color(0xFFDC2626),
                                  textColor: const Color(0xFF7F1D1D),
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (_successMessage != null) ...[
                                _buildMessage(
                                  _successMessage!,
                                  icon: Icons.check_circle_outline,
                                  bgColor: const Color(0xFFF0FDF4),
                                  borderColor: const Color(0xFFBBF7D0),
                                  iconColor: const Color(0xFF16A34A),
                                  textColor: const Color(0xFF14532D),
                                ),
                                const SizedBox(height: 12),
                              ],
                              _buildCreateButton(),
                            ],
                          ),
                        ),
                      ),

                    // Bottom padding
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ),
              ),
            ),
    );
  }

  // ──────────────── Search Section ────────────────

  String _phoneFromUserData(Map<String, dynamic> data) {
    const keys = [
      'phone',
      'phone_number',
      'phoneNumber',
      'mobile',
      'mobile_phone',
      'whatsapp',
      'whatsapp_number',
      'guardian_phone',
    ];
    for (final key in keys) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  Widget _buildSearchSection() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select a parent or student',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: InputDecoration(
              hintText: l10n.adminCreateInvoiceSearchHintPhone,
              hintStyle: GoogleFonts.inter(
                  color: const Color(0xFF94A3B8), fontSize: 14),
              prefixIcon:
                  const Icon(Icons.search, color: Color(0xFF94A3B8), size: 20),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        if (_showSearchResults) ...[
          const SizedBox(height: 8),
          _buildSearchResults(),
        ],
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_filteredUsers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Text(
            'No parents or adult students found',
            style: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: _filteredUsers.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
          itemBuilder: (context, index) {
            final user = _filteredUsers[index];
            final name = '${user['first_name']} ${user['last_name']}'.trim();
            final isParent = user['user_type'] == 'parent';
            final childCount = (user['children_ids'] as List).length;
            final email = (user['email'] ?? '').toString();
            final phone = (user['phone'] ?? '').toString();
            final details = [
              if (isParent)
                '$childCount ${childCount == 1 ? 'child' : 'children'}'
              else
                'Adult Student',
              if (email.isNotEmpty) email,
              if (phone.isNotEmpty) phone,
            ].join('  •  ');

            return InkWell(
              onTap: () => _selectUser(user),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isParent
                              ? [
                                  const Color(0xFF10B981),
                                  const Color(0xFF059669)
                                ]
                              : [
                                  const Color(0xFF3B82F6),
                                  const Color(0xFF2563EB)
                                ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            details,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: const Color(0xFFCBD5E1),
                      size: 20,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ──────────────── Selected User Card ────────────────

  Widget _buildSelectedUserCard() {
    final user = _selectedUser!;
    final name = '${user['first_name']} ${user['last_name']}'.trim();
    final isParent = user['user_type'] == 'parent';
    final email = (user['email'] ?? '').toString();
    final phone = (user['phone'] ?? '').toString();
    final details = [
      isParent ? 'Parent' : 'Adult Student',
      if (email.isNotEmpty) email,
      if (phone.isNotEmpty) phone,
    ].join('  •  ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isParent
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [const Color(0xFF1E3A5F), const Color(0xFF1E293B)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  details,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: _clearSelection,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close, color: Colors.white70, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────── Amount Section ────────────────

  Widget _buildAmountSection() {
    if (_children.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF94A3B8), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No children linked to this parent.',
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
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
        Text(
          'Enter amount per student',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 12),
        ..._children.map((child) => _buildChildAmountCard(child)),
      ],
    );
  }

  Widget _buildChildAmountCard(Map<String, dynamic> child) {
    final childId = child['id'] as String;
    final childName = '${child['first_name']} ${child['last_name']}'.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    childName.isNotEmpty ? childName[0].toUpperCase() : '?',
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
                child: Text(
                  childName,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Description field
          TextField(
            controller: _descriptionControllers[childId],
            style: GoogleFonts.inter(fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Description',
              labelStyle: GoogleFonts.inter(
                  fontSize: 12, color: const Color(0xFF64748B)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Color(0xFF0386FF), width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),

          // Amount field
          TextField(
            controller: _amountControllers[childId],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              labelText: 'Amount (USD)',
              labelStyle: GoogleFonts.inter(
                  fontSize: 12, color: const Color(0xFF64748B)),
              prefixText: '\$ ',
              prefixStyle: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: const Color(0xFF0F172A),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Color(0xFF0386FF), width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────── Helpers ────────────────

  /// The earliest date allowed for the due date:
  /// the later of today and the first day of the billing month.
  DateTime get _minDueDate {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    final months = _selectedMonths.toList()..sort((a, b) => a.compareTo(b));
    final selected =
        months.isEmpty ? DateTime(today.year, today.month) : months.first;
    final billingStart = DateTime(selected.year, selected.month, 1);
    return billingStart.isAfter(todayNorm) ? billingStart : todayNorm;
  }

  /// Toggles a billing month and clamps _dueDate if it would fall before the new minimum.
  void _toggleMonth(DateTime month) {
    final normalized = DateTime(month.year, month.month);
    final wasSelected = _selectedMonths.contains(normalized);
    if (wasSelected && _selectedMonths.length == 1) return;

    final newMin = () {
      final today = DateTime.now();
      final todayNorm = DateTime(today.year, today.month, today.day);
      final nextMonths = Set<DateTime>.from(_selectedMonths);
      if (wasSelected) {
        nextMonths.remove(normalized);
      } else {
        nextMonths.add(normalized);
      }
      final sorted = nextMonths.toList()..sort((a, b) => a.compareTo(b));
      final selected = sorted.isEmpty ? normalized : sorted.first;
      final billingStart = DateTime(selected.year, selected.month, 1);
      return billingStart.isAfter(todayNorm) ? billingStart : todayNorm;
    }();

    setState(() {
      if (wasSelected) {
        _selectedMonths.remove(normalized);
      } else {
        _selectedMonths.add(normalized);
      }
      if (_dueDate.isBefore(newMin)) {
        // Auto-clamp: clear any active preset so nothing looks selected
        _dueDate = newMin.add(const Duration(days: 7));
        _activePresetDays = null;
        if (_accessCutoffIsDefault) {
          _accessCutoffDate = _dueDate.add(const Duration(days: 1));
        }
      }
    });
  }

  // ──────────────── Month Selector ────────────────

  Widget _buildBillingPlanSection() {
    final l10n = AppLocalizations.of(context)!;
    final selectedMonths = _selectedMonths.toList()
      ..sort((a, b) => a.compareTo(b));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Billing plan',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMonthSelector(compact: true),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 14),
              _billingModeOption(
                mode: _InvoiceBillingMode.combinedNow,
                icon: Icons.all_inbox_rounded,
                title: l10n.adminCreateInvoiceBillingModeOneTitle,
                description: l10n.adminCreateInvoiceBillingModeOneDescription,
              ),
              const SizedBox(height: 8),
              _billingModeOption(
                mode: _InvoiceBillingMode.separateNow,
                icon: Icons.splitscreen_rounded,
                title: l10n.adminCreateInvoiceBillingModeSeparateTitle,
                description:
                    l10n.adminCreateInvoiceBillingModeSeparateDescription,
              ),
              const SizedBox(height: 8),
              _billingModeOption(
                mode: _InvoiceBillingMode.recurring,
                icon: Icons.event_repeat_rounded,
                title: l10n.adminCreateInvoiceBillingModeRecurringTitle,
                description:
                    l10n.adminCreateInvoiceBillingModeRecurringDescription,
              ),
              if (_billingMode == _InvoiceBillingMode.recurring) ...[
                const SizedBox(height: 12),
                _recurringControls(selectedMonths),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _billingModeOption({
    required _InvoiceBillingMode mode,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final selected = _billingMode == mode;
    return InkWell(
      onTap: () => setState(() => _billingMode = mode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF0386FF) : const Color(0xFFE2E8F0),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF0386FF)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : const Color(0xFF64748B),
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? const Color(0xFF0386FF) : Colors.white,
                border: Border.all(
                  color: selected
                      ? const Color(0xFF0386FF)
                      : const Color(0xFFCBD5E1),
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _recurringControls(List<DateTime> selectedMonths) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.adminCreateInvoiceRepeatTiming,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [1, 5, 10, 15].map((day) {
              final selected = _recurringSendDay == day;
              return InkWell(
                onTap: () => setState(() => _recurringSendDay = day),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF0386FF) : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF0386FF)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    l10n.adminCreateInvoiceRecurringDay(day),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.adminCreateInvoiceRecurringSummary(selectedMonths.length),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector({bool compact = false}) {
    final l10n = AppLocalizations.of(context)!;
    final selectedMonths = _selectedMonths.toList()
      ..sort((a, b) => a.compareTo(b));
    final anchor = selectedMonths.isEmpty
        ? DateTime(DateTime.now().year, DateTime.now().month)
        : selectedMonths.first;
    final monthOptions = List<DateTime>.generate(
      12,
      (index) => DateTime(anchor.year, anchor.month + index),
    );
    final selectedLabel = selectedMonths
        .map((month) => DateFormat('MMM yyyy').format(month))
        .join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) ...[
          Text(
            l10n.adminCreateInvoiceBillingMonths,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Container(
          padding: compact ? EdgeInsets.zero : const EdgeInsets.all(14),
          decoration: compact
              ? null
              : BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedMonths.length == 1
                          ? DateFormat.yMMMM().format(selectedMonths.first)
                          : l10n.adminCreateInvoiceMonthsSelected(
                              selectedMonths.length,
                            ),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  _monthNavButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => _toggleMonth(
                      DateTime(anchor.year, anchor.month - 1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _monthNavButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: () => _toggleMonth(
                      DateTime(
                        anchor.year,
                        anchor.month + selectedMonths.length,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                selectedLabel,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: monthOptions.map((month) {
                  final selected = _selectedMonths.contains(month);
                  return InkWell(
                    onTap: () => _toggleMonth(month),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF0386FF)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF0386FF)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        DateFormat.MMM().format(month),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color:
                              selected ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _monthNavButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Icon(icon, size: 19, color: const Color(0xFF64748B)),
      ),
    );
  }

  // ──────────────── Due Date Picker ────────────────

  Widget _buildDueDatePicker() {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    final minDate = _minDueDate;
    final daysUntilDue = _dueDate.difference(todayNorm).inDays;
    final isOverdue = daysUntilDue < 0;

    final chipColor = isOverdue
        ? const Color(0xFFDC2626)
        : daysUntilDue <= 3
            ? const Color(0xFFD97706)
            : const Color(0xFF059669);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment due date',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _dueDate.isBefore(minDate) ? minDate : _dueDate,
              firstDate: minDate,
              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
            );
            if (picked != null) {
              setState(() {
                _dueDate = picked;
                _activePresetDays = null; // calendar pick, no preset active
                if (_accessCutoffIsDefault) {
                  _accessCutoffDate = picked.add(const Duration(days: 1));
                }
              });
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: chipColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.event_rounded, size: 20, color: chipColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, MMMM d, y').format(_dueDate),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOverdue
                            ? 'Past due'
                            : daysUntilDue == 0
                                ? 'Due today'
                                : daysUntilDue == 1
                                    ? 'Due tomorrow'
                                    : 'Due in $daysUntilDue days',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: chipColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: const Color(0xFFCBD5E1), size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Quick presets
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _dueDatePreset('1 week', 7),
              const SizedBox(width: 8),
              _dueDatePreset('2 weeks', 14),
              const SizedBox(width: 8),
              _dueDatePreset('1 month', 30),
              const SizedBox(width: 8),
              _dueDatePreset('2 months', 60),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dueDatePreset(String label, int days) {
    final raw = DateTime.now().add(Duration(days: days));
    final rawNorm = DateTime(raw.year, raw.month, raw.day);
    // Never allow a preset that falls before the billing month start or today.
    final targetNorm = rawNorm.isBefore(_minDueDate) ? _minDueDate : rawNorm;
    // Selected only when this specific preset was the last one tapped.
    final isSelected = _activePresetDays == days;

    return GestureDetector(
      onTap: () => setState(() {
        _dueDate = targetNorm;
        _activePresetDays = days;
        if (_accessCutoffIsDefault) {
          _accessCutoffDate = targetNorm.add(const Duration(days: 1));
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0386FF) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF0386FF) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  // ──────────────── Access Cutoff Date Picker ────────────────

  Widget _buildAccessCutoffPicker() {
    final daysAfterDue = _accessCutoffDate.difference(_dueDate).inDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Access cutoff date',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Text(
                'Optional',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0369A1),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Students lose platform access if the invoice is unpaid by this date.',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () async {
            final minDate =
                _accessCutoffDate.isBefore(_dueDate) ? _dueDate : _dueDate;
            final picked = await showDatePicker(
              context: context,
              initialDate: _accessCutoffDate.isBefore(minDate)
                  ? minDate
                  : _accessCutoffDate,
              firstDate: _dueDate,
              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
            );
            if (picked != null) {
              setState(() {
                _accessCutoffDate = picked;
                _accessCutoffIsDefault = false;
              });
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _accessCutoffIsDefault
                    ? const Color(0xFFE2E8F0)
                    : const Color(0xFFF59E0B),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lock_clock_rounded,
                      size: 20, color: Color(0xFFF59E0B)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, MMMM d, y').format(_accessCutoffDate),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _accessCutoffIsDefault
                            ? 'Default: 1 day after due date'
                            : daysAfterDue >= 0
                                ? '$daysAfterDue day${daysAfterDue == 1 ? '' : 's'} after due date'
                                : 'Before due date',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: const Color(0xFFCBD5E1), size: 20),
              ],
            ),
          ),
        ),
        if (!_accessCutoffIsDefault) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => setState(() {
                _accessCutoffDate = _dueDate.add(const Duration(days: 1));
                _accessCutoffIsDefault = true;
              }),
              child: Text(
                'Reset to default',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0386FF),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ──────────────── Create Button ────────────────

  Widget _buildCreateButton() {
    final l10n = AppLocalizations.of(context)!;
    final label = switch (_billingMode) {
      _InvoiceBillingMode.combinedNow =>
        l10n.adminCreateInvoiceCreateOneInvoice,
      _InvoiceBillingMode.separateNow =>
        l10n.adminCreateInvoiceCreateSeparateInvoices,
      _InvoiceBillingMode.recurring =>
        l10n.adminCreateInvoiceCreateRecurringSchedule,
    };
    final icon = _billingMode == _InvoiceBillingMode.recurring
        ? Icons.event_repeat_rounded
        : Icons.send_rounded;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isCreating ? null : _createInvoice,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0386FF),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE2E8F0),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isCreating
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ──────────────── Messages ────────────────

  Widget _buildMessage(
    String message, {
    required IconData icon,
    required Color bgColor,
    required Color borderColor,
    required Color iconColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
