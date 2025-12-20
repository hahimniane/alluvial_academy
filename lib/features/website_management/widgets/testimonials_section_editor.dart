import 'package:flutter/material.dart';
import '../../../core/models/landing_page_content.dart';

class TestimonialsSectionEditor extends StatelessWidget {
  final List<TestimonialContent> testimonials;
  final Function(List<TestimonialContent>) onChanged;

  const TestimonialsSectionEditor({
    super.key,
    required this.testimonials,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Testimonials Editor'));
  }
} 