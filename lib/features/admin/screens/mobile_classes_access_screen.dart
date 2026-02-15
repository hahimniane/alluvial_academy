import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alluwalacademyadmin/core/services/mobile_classes_access_service.dart';
import 'package:alluwalacademyadmin/core/services/user_role_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class MobileClassesAccessScreen extends StatefulWidget {
  const MobileClassesAccessScreen({super.key});

  @override
  State<MobileClassesAccessScreen> createState() =>
      _MobileClassesAccessScreenState();
}

class _MobileClassesAccessScreenState extends State<MobileClassesAccessScreen> {
  bool _checkingAccess = true;
  bool _hasAccess = false;

  String _search = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAccess();
    _searchController.addListener(() {
      final next = _searchController.text;
      if (next == _search) return;
      setState(() => _search = next);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkAccess() async {
    try {
      final userData = await UserRoleService.getCurrentUserData();
      final primaryRole =
          (userData?['user_type'] as String?)?.trim().toLowerCase();
      final isAdmin = primaryRole == 'admin' || primaryRole == 'super_admin';

      if (!mounted) return;
      setState(() {
        _hasAccess = isAdmin;
        _checkingAccess = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasAccess = false;
        _checkingAccess = false;
      });
    }
  }

  Future<void> _setAllowAllTeachers(bool allowAll) async {
    try {
      await MobileClassesAccessService.setAllowAllTeachers(allowAll);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update setting: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _setTeacherEnabled({
    required String teacherDocId,
    required Map<String, dynamic> teacherData,
    required bool enabled,
  }) async {
    try {
      // Update the current doc, plus any other docs that represent the same user
      // (some deployments key user docs by UID, others by email).
      final users = FirebaseFirestore.instance.collection('users');
      final payload = <String, dynamic>{
        'mobile_classes_enabled': enabled,
        'updated_at': FieldValue.serverTimestamp(),
      };

      final idsToUpdate = <String>{teacherDocId};

      final uid = (teacherData['uid'] as String?)?.trim();
      if (uid != null && uid.isNotEmpty) {
        idsToUpdate.add(uid);
      }

      final rawEmail = (teacherData['email'] ?? teacherData['e-mail'])
          ?.toString()
          .trim();
      final lowerEmail = rawEmail?.toLowerCase();
      if (lowerEmail != null && lowerEmail.isNotEmpty) {
        // Only update the email-id doc if it already exists (avoid creating ghost docs).
        final emailIdDoc = await users.doc(lowerEmail).get();
        if (emailIdDoc.exists) {
          idsToUpdate.add(lowerEmail);
        }

        // Also find any other user docs that match this email in a field.
        final variants = <String>{
          lowerEmail,
          if (rawEmail != null && rawEmail.isNotEmpty) rawEmail,
        };

        for (final emailVariant in variants) {
          final q1 = await users
              .where('email', isEqualTo: emailVariant)
              .limit(5)
              .get();
          for (final d in q1.docs) {
            idsToUpdate.add(d.id);
          }

          final q2 = await users
              .where('e-mail', isEqualTo: emailVariant)
              .limit(5)
              .get();
          for (final d in q2.docs) {
            idsToUpdate.add(d.id);
          }
        }
      }

      final batch = FirebaseFirestore.instance.batch();
      for (final id in idsToUpdate) {
        batch.set(users.doc(id), payload, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update teacher: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  bool _matchesSearch({
    required String query,
    required String name,
    required String email,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) || email.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_checkingAccess) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasAccess) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mobile Classes'),
        ),
        body: Center(
          child: Text(
            l10n?.accessRestricted ?? 'Access restricted',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xff6B7280),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mobile Classes'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<bool>(
            stream: MobileClassesAccessService.watchAllowAllTeachers(),
            builder: (context, snapshot) {
              final allowAll = snapshot.data == true;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xffE5E7EB)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Allow all teachers',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xff111827),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'When enabled, every teacher can host/join classes from the native mobile app.',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: const Color(0xff6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: allowAll,
                            onChanged: _setAllowAllTeachers,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search teachers (name or email)',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xffE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xffE5E7EB)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .snapshots(),
                      builder: (context, teacherSnap) {
                        if (teacherSnap.hasError) {
                          return Center(
                            child: Text(
                              'Failed to load teachers: ${teacherSnap.error}',
                              style: GoogleFonts.inter(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        if (!teacherSnap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        bool isTeacher(Map<String, dynamic> data) {
                          final raw = (data['user_type'] ??
                                  data['userType'] ??
                                  data['role'])
                              ?.toString();
                          final normalized = (raw ?? '').trim().toLowerCase();
                          return normalized == 'teacher';
                        }

                        final docs = teacherSnap.data!.docs
                            .where((d) => isTeacher(d.data()))
                            .toList();
                        docs.sort((a, b) {
                          final aName =
                              '${(a.data()['first_name'] ?? '').toString()} ${(a.data()['last_name'] ?? '').toString()}'
                                  .trim();
                          final bName =
                              '${(b.data()['first_name'] ?? '').toString()} ${(b.data()['last_name'] ?? '').toString()}'
                                  .trim();
                          return aName.toLowerCase().compareTo(bName.toLowerCase());
                        });

                        final filtered = docs.where((doc) {
                          final data = doc.data();
                          final name =
                              '${(data['first_name'] ?? '').toString()} ${(data['last_name'] ?? '').toString()}'
                                  .trim();
                          final email = (data['email'] ??
                                  data['e-mail'] ??
                                  '')
                              .toString();
                          return _matchesSearch(
                            query: _search,
                            name: name,
                            email: email,
                          );
                        }).toList();

                        if (filtered.isEmpty) {
                          return Center(
                            child: Text(
                              'No teachers found',
                              style: GoogleFonts.inter(
                                color: const Color(0xff6B7280),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xffE5E7EB)),
                          ),
                          child: ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                            ),
                            itemBuilder: (context, index) {
                              final doc = filtered[index];
                              final data = doc.data();
                              final teacherId = doc.id;
                              final firstName =
                                  (data['first_name'] ?? '').toString();
                              final lastName =
                                  (data['last_name'] ?? '').toString();
                              final name = ('$firstName $lastName').trim();
                              final email = (data['email'] ??
                                      data['e-mail'] ??
                                      '')
                                  .toString()
                                  .trim();
                              final enabled =
                                  data['mobile_classes_enabled'] == true;
                              final effectiveEnabled = allowAll || enabled;
                              final isActive = data['is_active'] != false;

                              return ListTile(
                                title: Text(
                                  name.isEmpty ? 'Unnamed teacher' : name,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  [
                                    if (email.isNotEmpty) email,
                                    if (!isActive) 'Inactive',
                                    if (allowAll) 'Enabled via allow-all',
                                  ].join(' • '),
                                  style: GoogleFonts.inter(fontSize: 12),
                                ),
                                trailing: Switch(
                                  value: effectiveEnabled,
                                  onChanged: allowAll
                                      ? null
                                      : (value) =>
                                          _setTeacherEnabled(
                                            teacherDocId: teacherId,
                                            teacherData: data,
                                            enabled: value,
                                          ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
