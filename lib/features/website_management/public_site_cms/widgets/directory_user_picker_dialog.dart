import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alluwalacademyadmin/core/services/public_site_cms_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

Future<PublicSiteDirectoryUser?> showDirectoryUserPickerDialog(BuildContext context) {
  return showDialog<PublicSiteDirectoryUser>(
    context: context,
    builder: (ctx) => const DirectoryUserPickerDialog(),
  );
}

class DirectoryUserPickerDialog extends StatefulWidget {
  const DirectoryUserPickerDialog({super.key});

  @override
  State<DirectoryUserPickerDialog> createState() => _DirectoryUserPickerDialogState();
}

class _DirectoryUserPickerDialogState extends State<DirectoryUserPickerDialog> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  List<PublicSiteDirectoryUser> _results = const [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String raw) async {
    final q = raw.trim();
    if (q.length < 2) {
      setState(() {
        _results = const [];
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await PublicSiteCmsService.searchDirectoryUsers(q);
      if (!mounted) return;
      setState(() {
        _results = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.publicSiteCmsPickLinkedUserTitle),
      content: SizedBox(
        width: 420,
        height: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _search,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l.publicSiteCmsPickLinkedUserSearchLabel,
                hintText: l.publicSiteCmsPickLinkedUserSearchHint,
              ),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), () => _runSearch(v));
              },
            ),
            const SizedBox(height: 8),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            Expanded(
              child: _results.isEmpty && !_loading
                  ? Center(
                      child: Text(
                        l.publicSiteCmsPickLinkedUserEmpty,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: const Color(0xff64748B)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (ctx, i) {
                        final u = _results[i];
                        return ListTile(
                          title: Text(u.displayName, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            '${u.email}\n${u.uid}',
                            maxLines: 3,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () => Navigator.pop(context, u),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.commonCancel)),
      ],
    );
  }
}
