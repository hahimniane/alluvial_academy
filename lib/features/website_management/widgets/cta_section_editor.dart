import 'package:flutter/material.dart';
import '../../../core/models/landing_page_content.dart';

class CTASectionEditor extends StatelessWidget {
  final CTASectionContent content;
  final Function(CTASectionContent) onChanged;

  const CTASectionEditor({
    super.key,
    required this.content,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('CTA Editor'));
  }
} 