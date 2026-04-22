import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:alluwalacademyadmin/core/models/public_site_cms_models.dart';
import 'package:alluwalacademyadmin/core/services/public_site_cms_service.dart';
import 'package:alluwalacademyadmin/features/website_management/public_site_cms/team_cms_state.dart';
import 'package:alluwalacademyadmin/features/website_management/public_site_cms/theme/public_site_cms_tokens.dart';
import 'package:alluwalacademyadmin/features/website_management/public_site_cms/widgets/cms_team_list_leading.dart';
import 'package:alluwalacademyadmin/features/website_management/public_site_cms/widgets/hover_list_card.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

Future<void> confirmTeamMemberDelete(BuildContext context, PublicSiteTeamMember m) async {
  final l = AppLocalizations.of(context)!;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.publicSiteCmsConfirmDelete),
      content: Text(m.name),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.commonCancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.commonDelete)),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    try {
      await PublicSiteCmsService.deleteTeamMember(m.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class PublicSiteTeamTab extends StatefulWidget {
  const PublicSiteTeamTab({super.key});

  @override
  State<PublicSiteTeamTab> createState() => _PublicSiteTeamTabState();
}

class _PublicSiteTeamTabState extends State<PublicSiteTeamTab> {
  bool _importing = false;

  Future<void> _importBundled() async {
    if (_importing) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l = AppLocalizations.of(context)!;
    setState(() => _importing = true);
    try {
      final r = await PublicSiteCmsService.importBundledStaffJsonToFirestore();
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text(l.publicSiteCmsTeamImportDone(r.imported, r.skipped))),
      );
    } catch (e) {
      if (mounted) {
        messenger?.showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  void _openEditor(BuildContext context, {PublicSiteTeamMember? existing}) {
    context.read<TeamCmsState>().openForEdit(existing);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return StreamBuilder<List<PublicSiteTeamMember>>(
      stream: PublicSiteCmsService.teamMembersAdminCmsStream(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('${l.commonError}: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!;

        return Stack(
          children: [
            if (docs.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l.publicSiteCmsTeamEmpty,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: const Color(0xff64748B)),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l.publicSiteCmsTeamImportBundledHint,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.35,
                          color: const Color(0xff94A3B8),
                        ),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: _importing ? null : _importBundled,
                        icon: _importing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cloud_download_outlined),
                        label: Text(l.publicSiteCmsTeamImportBundled),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final m = docs[i];
                  return HoverListCard(
                    child: ListTile(
                      leading: CmsTeamListLeading(member: m),
                      title: Text(
                        m.name,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: PublicSiteCmsTheme.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '${m.role} · ${m.category} · #${m.sortOrder}'
                        '${m.active ? '' : ' · ${l.publicSiteCmsTeamInactiveBadge}'}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: PublicSiteCmsTheme.textSecondary,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _openEditor(context, existing: m),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => confirmTeamMemberDelete(context, m),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (docs.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton.icon(
                        onPressed: _importing ? null : _importBundled,
                        icon: _importing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cloud_download_outlined),
                        label: Text(l.publicSiteCmsTeamImportBundled),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: () => _openEditor(context, existing: null),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: Text(l.publicSiteCmsTeamAddProfile),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
