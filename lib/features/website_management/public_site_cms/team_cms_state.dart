import 'package:flutter/material.dart';
import 'package:alluwalacademyadmin/core/models/public_site_cms_models.dart';

/// Manages which team member is being edited in the end drawer.
class TeamCmsState extends ChangeNotifier {
  PublicSiteTeamMember? _editing;
  bool _drawerOpen = false;
  int _drawerNonce = 0;
  GlobalKey<ScaffoldState>? _scaffoldKey;

  PublicSiteTeamMember? get editing => _editing;

  /// True while the team sheet should be mounted (new profile or edit existing).
  bool get isTeamDrawerOpen => _drawerOpen;

  /// Bumped on each [openForEdit] so the side sheet can reset [State] for new-member flows.
  int get drawerNonce => _drawerNonce;

  void attachScaffoldKey(GlobalKey<ScaffoldState> key) {
    _scaffoldKey = key;
  }

  void openForEdit(PublicSiteTeamMember? existing) {
    _editing = existing;
    _drawerOpen = true;
    _drawerNonce++;
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldKey?.currentState?.openEndDrawer();
    });
  }

  void clearEditing() {
    if (!_drawerOpen && _editing == null) return;
    _drawerOpen = false;
    _editing = null;
    notifyListeners();
  }
}
