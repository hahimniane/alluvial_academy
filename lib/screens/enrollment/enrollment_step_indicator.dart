import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Horizontal connected-step progress bar for the enrollment wizard.
/// Dark background strip with step circles connected by lines.
class EnrollmentStepIndicator extends StatelessWidget {
  const EnrollmentStepIndicator({
    super.key,
    required this.stepTitles,
    required this.currentStep,
    required this.stepIcons,
  });

  final List<String> stepTitles;
  final List<IconData> stepIcons;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final compact = screenW < 768;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xff0F172A), Color(0xff1E293B)],
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 14,
          vertical: compact ? 5 : 6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _buildSteps(compact),
        ),
      ),
    );
  }

  List<Widget> _buildSteps(bool compact) {
    final widgets = <Widget>[];
    for (var i = 0; i < stepTitles.length; i++) {
      if (i > 0) {
        widgets.add(_buildConnector(i, compact));
      }
      widgets.add(_buildStepNode(i, compact));
    }
    return widgets;
  }

  Widget _buildConnector(int toIndex, bool compact) {
    final completed = toIndex <= currentStep;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      width: compact ? 18 : 28,
      height: 2,
      margin: EdgeInsets.symmetric(horizontal: compact ? 1 : 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(1),
        color: completed
            ? const Color(0xff10B981)
            : const Color(0xff334155),
      ),
    );
  }

  Widget _buildStepNode(int index, bool compact) {
    final isCompleted = index < currentStep;
    final isCurrent = index == currentStep;
    final isFuture = index > currentStep;

    final circleSize = compact ? 22.0 : 24.0;

    Color circleColor;
    List<BoxShadow>? shadow;
    if (isCompleted) {
      circleColor = const Color(0xff10B981);
      shadow = null;
    } else if (isCurrent) {
      circleColor = const Color(0xffF59E0B);
      shadow = [
        BoxShadow(
          color: const Color(0xffF59E0B).withValues(alpha: 0.35),
          blurRadius: 6,
          offset: const Offset(0, 1),
        ),
      ];
    } else {
      circleColor = const Color(0xff334155);
      shadow = null;
    }

    Widget circleChild;
    if (isCompleted) {
      circleChild =
          const Icon(Icons.check_rounded, size: 13, color: Colors.white);
    } else if (isCurrent) {
      circleChild = Icon(stepIcons[index], size: 13, color: Colors.white);
    } else {
      circleChild = Text(
        '${index + 1}',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: const Color(0xff64748B),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: circleColor,
            boxShadow: shadow,
          ),
          child: Center(child: circleChild),
        ),
        SizedBox(height: compact ? 2 : 3),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: GoogleFonts.inter(
            fontSize: compact ? 8 : 8.5,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: isCurrent
                ? Colors.white
                : isFuture
                    ? const Color(0xff64748B)
                    : const Color(0xff94A3B8),
            letterSpacing: 0.05,
            height: 1.15,
          ),
          child: Text(
            stepTitles[index],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
