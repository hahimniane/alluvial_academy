import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
    if (response == null || formTemplate == null) {
      return const SizedBox();
    }

    final data = response!.data() as Map<String, dynamic>;
    final submittedAt = (data['submittedAt'] as Timestamp).toDate();

    return Container(
      width: 400,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: Color(0xffE2E8F0)),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xffE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.responseDetails,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formTemplate!['title'] ?? 'Unknown Form',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xff6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                  tooltip: AppLocalizations.of(context)!.commonClose,
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Submission info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xffF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xffE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.submissionInfo,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xff374151),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          'Submitted By',
                          '${data['userFirstName'] ?? ''} ${data['userLastName'] ?? ''}'
                              .trim(),
                          data['userEmail'] ?? 'Unknown User',
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          'Submitted On',
                          _formatDate(submittedAt),
                          _formatTime(submittedAt),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          'Status',
                          data['status']?.toString().toUpperCase() ?? 'UNKNOWN',
                          null,
                          color: _getStatusColor(data['status'] ?? 'unknown'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Form responses
                  Text(
                    AppLocalizations.of(context)!.responses,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff374151),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._buildResponseFields(
                    Map<String, dynamic>.from(data['responses'] as Map),
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

  Widget _buildInfoRow(String label, String value, String? subtitle,
      {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xff6B7280),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: color ?? const Color(0xff374151),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xff6B7280),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildResponseFields(
    Map<String, dynamic> responses,
    DocumentSnapshot formTemplate,
  ) {
    final fields = Map<String, dynamic>.from(
      (formTemplate.data() as Map<String, dynamic>)['fields'] as Map,
    );
    final widgets = <Widget>[];

    for (final entry in fields.entries) {
      final fieldId = entry.key;
      final fieldData = Map<String, dynamic>.from(entry.value as Map);
      final response = responses[fieldId];

      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xffE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fieldData['label'] ?? 'Untitled Field',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff374151),
                ),
              ),
              const SizedBox(height: 8),
              if (response == null)
                Text(
                  AppLocalizations.of(context)!.noResponse,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xff6B7280),
                    fontStyle: FontStyle.italic,
                  ),
                )
              else if (response is Map)
                _buildImagePreview(Map<String, dynamic>.from(response))
              else if (response is List)
                Text(
                  response.join(', '),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xff111827),
                  ),
                )
              else
                Text(
                  response.toString(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xff111827),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildImagePreview(Map<String, dynamic> imageData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xffE5E7EB)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageData['downloadURL'],
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xffF3F4F6),
                child: const Icon(
                  Icons.error_outline,
                  color: Color(0xffEF4444),
                  size: 48,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {
            // Open image in new tab
            final url = imageData['downloadURL'];
            html.window.open(url.toString(), '_blank');
          },
          icon: const Icon(Icons.download),
          label: Text(AppLocalizations.of(context)!.downloadImage),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xff10B981);
      case 'draft':
        return const Color(0xff6B7280);
      case 'pending':
        return const Color(0xffF59E0B);
      default:
        return const Color(0xff6B7280);
    }
  }
}
