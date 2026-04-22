import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:alluwalacademyadmin/core/constants/pricing_plan_ids.dart';
import 'package:alluwalacademyadmin/core/models/public_site_cms_models.dart';
import 'package:alluwalacademyadmin/core/services/public_site_cms_service.dart';
import 'package:alluwalacademyadmin/features/website_management/public_site_cms/team_cms_state.dart';
import 'package:alluwalacademyadmin/features/website_management/public_site_cms/tabs/landing_tab.dart';
import 'package:alluwalacademyadmin/features/website_management/public_site_cms/tabs/pricing_tab.dart';
import 'package:alluwalacademyadmin/features/website_management/public_site_cms/tabs/social_tab.dart';
import 'package:alluwalacademyadmin/features/website_management/public_site_cms/tabs/team_tab.dart';
import 'package:alluwalacademyadmin/features/website_management/public_site_cms/theme/public_site_cms_tokens.dart';
import 'package:alluwalacademyadmin/features/website_management/public_site_cms/widgets/cms_section_header.dart';
import 'package:alluwalacademyadmin/features/website_management/public_site_cms/widgets/team_member_side_sheet.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Admin: public pricing, team profiles, and header social links (Instagram / Facebook / TikTok).
class PublicSiteCmsScreen extends StatelessWidget {
  const PublicSiteCmsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TeamCmsState(),
      child: const _PublicSiteCmsScaffoldContent(),
    );
  }
}

class _PublicSiteCmsScaffoldContent extends StatefulWidget {
  const _PublicSiteCmsScaffoldContent();

  @override
  State<_PublicSiteCmsScaffoldContent> createState() => _PublicSiteCmsScaffoldContentState();
}

class _PublicSiteCmsScaffoldContentState extends State<_PublicSiteCmsScaffoldContent>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _scaffoldKeyAttached = false;
  late TabController _tabController;

  bool _pricingLoading = true;
  String? _pricingError;
  bool _pricingSaving = false;

  final Map<String, TextEditingController> _bulletsCtrls = {};
  final Map<String, TextEditingController> _v2IslamicBase = {};
  final Map<String, TextEditingController> _v2IslamicDiscount = {};
  final Map<String, TextEditingController> _v2IslamicThreshold = {};
  final Map<String, TextEditingController> _v2TutoringBase = {};
  final Map<String, TextEditingController> _v2TutoringDiscount = {};
  final Map<String, TextEditingController> _v2TutoringThreshold = {};
  final Map<String, TextEditingController> _v2GroupHourly = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _loadPricingDraft();
    PublicSiteCmsService.syncAdminClaimForPublicSiteStorage();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_scaffoldKeyAttached) {
      _scaffoldKeyAttached = true;
      context.read<TeamCmsState>().attachScaffoldKey(_scaffoldKey);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _bulletsCtrls.values) {
      c.dispose();
    }
    for (final c in _v2IslamicBase.values) {
      c.dispose();
    }
    for (final c in _v2IslamicDiscount.values) {
      c.dispose();
    }
    for (final c in _v2IslamicThreshold.values) {
      c.dispose();
    }
    for (final c in _v2TutoringBase.values) {
      c.dispose();
    }
    for (final c in _v2TutoringDiscount.values) {
      c.dispose();
    }
    for (final c in _v2TutoringThreshold.values) {
      c.dispose();
    }
    for (final c in _v2GroupHourly.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _disposePricingControllers() {
    for (final c in _bulletsCtrls.values) {
      c.dispose();
    }
    _bulletsCtrls.clear();
    for (final c in _v2IslamicBase.values) {
      c.dispose();
    }
    _v2IslamicBase.clear();
    for (final c in _v2IslamicDiscount.values) {
      c.dispose();
    }
    _v2IslamicDiscount.clear();
    for (final c in _v2IslamicThreshold.values) {
      c.dispose();
    }
    _v2IslamicThreshold.clear();
    for (final c in _v2TutoringBase.values) {
      c.dispose();
    }
    _v2TutoringBase.clear();
    for (final c in _v2TutoringDiscount.values) {
      c.dispose();
    }
    _v2TutoringDiscount.clear();
    for (final c in _v2TutoringThreshold.values) {
      c.dispose();
    }
    _v2TutoringThreshold.clear();
    for (final c in _v2GroupHourly.values) {
      c.dispose();
    }
    _v2GroupHourly.clear();
  }

  Future<void> _loadPricingDraft() async {
    setState(() {
      _pricingLoading = true;
      _pricingError = null;
    });
    try {
      final doc = await PublicSiteCmsService.getPricingDoc();
      _disposePricingControllers();

      for (final id in PublicSiteCmsService.allPricingPlanIds()) {
        final p = doc.plans[id] ?? const PublicSitePlanPricing();
        _bulletsCtrls[id] = TextEditingController(text: p.bullets.join('\n'));
        if (id == PricingPlanIds.islamic) {
          _v2IslamicBase[id] = TextEditingController(text: p.islamicBaseUsd?.toString() ?? '');
          _v2IslamicDiscount[id] =
              TextEditingController(text: p.islamicDiscountUsd?.toString() ?? '');
          _v2IslamicThreshold[id] = TextEditingController(
            text: (p.islamicDiscountThreshold ?? 4).toString(),
          );
        }
        if (id == PricingPlanIds.tutoring) {
          _v2TutoringBase[id] = TextEditingController(text: p.tutoringBaseUsd?.toString() ?? '');
          _v2TutoringDiscount[id] =
              TextEditingController(text: p.tutoringDiscountUsd?.toString() ?? '');
          _v2TutoringThreshold[id] = TextEditingController(
            text: (p.tutoringDiscountThreshold ?? 4).toString(),
          );
        }
        if (id == PricingPlanIds.group) {
          _v2GroupHourly[id] = TextEditingController(text: p.groupHourlyUsd?.toString() ?? '');
        }
      }
      if (mounted) {
        setState(() => _pricingLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pricingLoading = false;
          _pricingError = '$e';
        });
      }
    }
  }

  String _planTitle(AppLocalizations l, String id) {
    switch (id) {
      case PricingPlanIds.islamic:
        return l.pricingTrackIslamicTitle;
      case PricingPlanIds.tutoring:
        return l.pricingTrackTutoringTitle;
      case PricingPlanIds.group:
        return l.pricingTrackGroupTitle;
      default:
        return id;
    }
  }

  Future<void> _savePricing({String? planIdForMessage}) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _pricingSaving = true);
    try {
      final plans = <String, PublicSitePlanPricing>{};
      for (final id in PublicSiteCmsService.allPricingPlanIds()) {
        final b = _bulletsCtrls[id]?.text ?? '';
        final bullets = b
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        plans[id] = PublicSitePlanPricing(
          islamicBaseUsd: id == PricingPlanIds.islamic
              ? double.tryParse(_v2IslamicBase[id]?.text ?? '')
              : null,
          islamicDiscountUsd: id == PricingPlanIds.islamic
              ? double.tryParse(_v2IslamicDiscount[id]?.text ?? '')
              : null,
          islamicDiscountThreshold: id == PricingPlanIds.islamic
              ? int.tryParse(_v2IslamicThreshold[id]?.text ?? '')
              : null,
          tutoringBaseUsd: id == PricingPlanIds.tutoring
              ? double.tryParse(_v2TutoringBase[id]?.text ?? '')
              : null,
          tutoringDiscountUsd: id == PricingPlanIds.tutoring
              ? double.tryParse(_v2TutoringDiscount[id]?.text ?? '')
              : null,
          tutoringDiscountThreshold: id == PricingPlanIds.tutoring
              ? int.tryParse(_v2TutoringThreshold[id]?.text ?? '')
              : null,
          groupHourlyUsd: id == PricingPlanIds.group
              ? double.tryParse(_v2GroupHourly[id]?.text ?? '')
              : null,
          bullets: bullets,
        );
      }
      await PublicSiteCmsService.savePricingDoc(PublicSiteCmsPricingDoc(plans: plans));
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        final msg = planIdForMessage == null
            ? l10n.publicSiteCmsPricingSaved
            : l10n.publicSiteCmsPricingSavedThisTrack(_planTitle(l10n, planIdForMessage));
        messenger.showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            showCloseIcon: true,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text('${l10n.commonError}: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
            showCloseIcon: true,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _pricingSaving = false);
      }
    }
  }

  Widget _buildNavigationRail(AppLocalizations l) {
    return Material(
      color: PublicSiteCmsTheme.surface,
      child: NavigationRail(
        backgroundColor: PublicSiteCmsTheme.surface,
        selectedIndex: _tabController.index,
        onDestinationSelected: (i) {
          if (i == _tabController.index) return;
          _tabController.animateTo(i);
        },
        labelType: NavigationRailLabelType.all,
        groupAlignment: -1,
        leading: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Icon(Icons.public, color: PublicSiteCmsTheme.accentNavy, size: 22),
        ),
        destinations: [
          NavigationRailDestination(
            icon: const Icon(Icons.attach_money_outlined),
            selectedIcon: const Icon(Icons.attach_money),
            label: Text(l.publicSiteCmsTabPricing, style: GoogleFonts.inter(fontSize: 12)),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.groups_outlined),
            selectedIcon: const Icon(Icons.groups),
            label: Text(l.publicSiteCmsTabTeam, style: GoogleFonts.inter(fontSize: 12)),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.share_outlined),
            selectedIcon: const Icon(Icons.share),
            label: Text(l.publicSiteCmsTabSocial, style: GoogleFonts.inter(fontSize: 12)),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.landscape_outlined),
            selectedIcon: const Icon(Icons.landscape),
            label: Text(l.publicSiteCmsTabLanding, style: GoogleFonts.inter(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(AppLocalizations l) {
    return NavigationBar(
      backgroundColor: PublicSiteCmsTheme.surface,
      surfaceTintColor: Colors.transparent,
      height: 64,
      selectedIndex: _tabController.index,
      onDestinationSelected: (i) {
        if (i == _tabController.index) return;
        _tabController.animateTo(i);
      },
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.attach_money_outlined),
          selectedIcon: const Icon(Icons.attach_money),
          label: l.publicSiteCmsTabPricing,
        ),
        NavigationDestination(
          icon: const Icon(Icons.groups_outlined),
          selectedIcon: const Icon(Icons.groups),
          label: l.publicSiteCmsTabTeam,
        ),
        NavigationDestination(
          icon: const Icon(Icons.share_outlined),
          selectedIcon: const Icon(Icons.share),
          label: l.publicSiteCmsTabSocial,
        ),
        NavigationDestination(
          icon: const Icon(Icons.landscape_outlined),
          selectedIcon: const Icon(Icons.landscape),
          label: l.publicSiteCmsTabLanding,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final w = MediaQuery.sizeOf(context).width;
    final useRail = PublicSiteCmsTheme.useSideRail(w);
    final team = context.watch<TeamCmsState>();

    final bodyContent = ColoredBox(
      color: PublicSiteCmsTheme.bg,
      child: SafeArea(
        top: true,
        left: true,
        right: true,
        bottom: useRail,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: PublicSiteCmsTheme.contentMaxW),
                child: CmsSectionHeader(
                  index: _tabController.index,
                  showProductLine: useRail,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: PublicSiteCmsTheme.contentMaxW),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: TabBarView(
                      controller: _tabController,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        PublicSitePricingTab(
                          loading: _pricingLoading,
                          errorText: _pricingError,
                          saving: _pricingSaving,
                          bulletsCtrls: _bulletsCtrls,
                          v2IslamicBase: _v2IslamicBase,
                          v2IslamicDiscount: _v2IslamicDiscount,
                          v2IslamicThreshold: _v2IslamicThreshold,
                          v2TutoringBase: _v2TutoringBase,
                          v2TutoringDiscount: _v2TutoringDiscount,
                          v2TutoringThreshold: _v2TutoringThreshold,
                          v2GroupHourly: _v2GroupHourly,
                          onRetryLoad: _loadPricingDraft,
                          onSaveAll: () => _savePricing(),
                          onSaveThisTrack: (id) => _savePricing(planIdForMessage: id),
                        ),
                        const PublicSiteTeamTab(),
                        const PublicSiteSocialTab(),
                        const PublicSiteLandingTab(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: PublicSiteCmsTheme.bg,
      onEndDrawerChanged: (open) {
        if (!open) {
          context.read<TeamCmsState>().clearEditing();
        }
      },
      endDrawer: team.editing == null
          ? null
          : Drawer(
              width: math.min(520, w * 0.9),
              child: TeamMemberSideSheet(
                key: ValueKey('${team.editing?.id ?? "new"}-${team.drawerNonce}'),
                existing: team.editing,
              ),
            ),
      appBar: useRail
          ? null
          : AppBar(
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: PublicSiteCmsTheme.bg,
              surfaceTintColor: Colors.transparent,
              title: Text(
                l.publicSiteCmsTitle,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: PublicSiteCmsTheme.textPrimary,
                ),
              ),
            ),
      body: useRail
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildNavigationRail(l),
                const VerticalDivider(width: 1, thickness: 1, color: PublicSiteCmsTheme.border),
                Expanded(child: bodyContent),
              ],
            )
          : bodyContent,
      bottomNavigationBar: useRail ? null : _buildBottomBar(l),
    );
  }
}
