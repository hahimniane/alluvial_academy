import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class ChildrenListWidget extends StatelessWidget {
  final List<Map<String, dynamic>> children;
  final void Function(Map<String, dynamic> child)? onChildTap;

  const ChildrenListWidget({
    super.key,
    required this.children,
    this.onChildTap,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF6B7280)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.noChildrenLinkedToThisParent,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.family_restroom_rounded, color: Color(0xFF111827), size: 20),
                const SizedBox(width: 10),
                Text(
                  AppLocalizations.of(context)!.children,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          ...children.map((child) {
            final name = (child['name'] ?? '').toString();
            final code = (child['studentCode'] ?? child['kioskCode'])?.toString();
            final subtitle = (code == null || code.trim().isEmpty) ? null : 'ID: ${code.trim()}';

            return ListTile(
              onTap: onChildTap == null ? null : () => onChildTap!(child),
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFEFF6FF),
                foregroundColor: const Color(0xFF1D4ED8),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                ),
              ),
              title: Text(
                name.isNotEmpty ? name : 'Student',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
              subtitle: subtitle == null
                  ? null
                  : Text(
                      subtitle,
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
                    ),
              trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
            );
          }),
        ],
      ),
    );
  }
}

