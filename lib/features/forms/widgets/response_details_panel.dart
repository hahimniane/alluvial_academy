import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class ResponseDetailsPanel extends StatelessWidget {
  final QueryDocumentSnapshot? response;
  final DocumentSnapshot? formTemplate;
  final VoidCallback onClose;

  const ResponseDetailsPanel({
    super.key,
    required this.response,
    required this.formTemplate,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (response == null || formTemplate == null) return const SizedBox();

    final data = response!.data() as Map<String, dynamic>;
    final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
    final status = (data['status'] ?? 'unknown').toString();
    final firstName = data['userFirstName']?.toString() ?? '';
    final lastName = data['userLastName']?.toString() ?? '';
    final email = data['userEmail']?.toString() ?? 'Unknown';
    final fullName = '$firstName $lastName'.trim();
    final templateData = formTemplate!.data() as Map<String, dynamic>?;
    final formTitle = templateData?['title']?.toString() ?? 'Unknown Form';

    return Container(
      width: 340,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Color(0xffE2E8F0))),
      ),
      child: Column(
        children: [
          // ── Compact header ─────────────────────────────────────────────
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xffF8FAFC),
              border: Border(bottom: BorderSide(color: Color(0xffE2E8F0))),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_outlined, size: 16, color: Color(0xff6B7280)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.responseDetails,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff111827),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  color: const Color(0xff6B7280),
                  tooltip: AppLocalizations.of(context)!.commonClose,
                ),
              ],
            ),
          ),

          // ── Scrollable body ────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Form name
                  Text(
                    formTitle,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff111827),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Submitter info row
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xff0386FF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xff0386FF),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName.isEmpty ? email : fullName,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xff111827),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              email,
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xff6B7280)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      _buildStatusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Submission date
                  if (submittedAt != null)
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 13, color: Color(0xff9CA3AF)),
                        const SizedBox(width: 4),
                        Text(
                          _formatDateTime(submittedAt),
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xff6B7280)),
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xffF1F5F9)),
                  const SizedBox(height: 16),

                  // Responses label
                  Text(
                    AppLocalizations.of(context)!.responses,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff6B7280),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Response fields
                  ..._buildResponseFields(
                    context,
                    Map<String, dynamic>.from(data['responses'] as Map? ?? {}),
                    formTemplate!,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final lower = status.toLowerCase();
    final Color bg;
    final Color fg;
    switch (lower) {
      case 'completed':
        bg = const Color(0xffD1FAE5);
        fg = const Color(0xff065F46);
        break;
      case 'pending':
        bg = const Color(0xffFEF3C7);
        fg = const Color(0xff92400E);
        break;
      default:
        bg = const Color(0xffF3F4F6);
        fg = const Color(0xff6B7280);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  List<Widget> _buildResponseFields(
    BuildContext context,
    Map<String, dynamic> responses,
    DocumentSnapshot formTemplate,
  ) {
    final raw = (formTemplate.data() as Map<String, dynamic>?)?['fields'];
    final Map<String, dynamic> fields = {};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is Map) fields[k.toString()] = Map<String, dynamic>.from(v);
      });
    } else if (raw is List) {
      for (var i = 0; i < raw.length; i++) {
        final f = raw[i];
        if (f is Map) {
          final id = f['id']?.toString() ?? 'field_$i';
          fields[id] = Map<String, dynamic>.from(f);
        }
      }
    }

    return fields.entries.map((entry) {
      final fieldId = entry.key;
      final fieldData = Map<String, dynamic>.from(entry.value as Map);
      final fieldResp = responses[fieldId];

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fieldData['label'] ?? 'Untitled Field',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xff6B7280),
              ),
            ),
            const SizedBox(height: 4),
            if (fieldResp == null)
              Text(
                AppLocalizations.of(context)!.noResponse,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xff9CA3AF),
                  fontStyle: FontStyle.italic,
                ),
              )
            else if (fieldResp is Map)
              _buildImagePreview(context, Map<String, dynamic>.from(fieldResp))
            else if (fieldResp is List)
              Text(
                fieldResp.join(', '),
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xff111827)),
              )
            else
              Text(
                fieldResp.toString(),
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xff111827)),
              ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildImagePreview(BuildContext context, Map<String, dynamic> imageData) {
    final url = imageData['downloadURL']?.toString();
    if (url == null || url.isEmpty) {
      return Text(
        AppLocalizations.of(context)!.noResponse,
        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xff9CA3AF), fontStyle: FontStyle.italic),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(
            url,
            width: 160,
            height: 120,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 160,
                height: 120,
                color: const Color(0xffF3F4F6),
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            },
            errorBuilder: (_, __, ___) => Container(
              width: 160,
              height: 120,
              color: const Color(0xffF3F4F6),
              child: const Icon(Icons.broken_image, color: Color(0xffD1D5DB), size: 32),
            ),
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => html.window.open(url, '_blank'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.download, size: 13, color: Color(0xff0386FF)),
              const SizedBox(width: 4),
              Text(
                AppLocalizations.of(context)!.downloadImage,
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xff0386FF)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime date) {
    final d =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final t =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '$d  $t';
  }
}
