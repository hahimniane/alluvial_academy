import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../../core/services/onboarding_service.dart';
import '../../../core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Manages the student feature tour using coach marks
class StudentFeatureTour {
  TutorialCoachMark? _tutorialCoachMark;
  bool _isActive = false;

  /// GlobalKeys for target widgets - set these from the UI
  final GlobalKey classesTabKey = GlobalKey();
  final GlobalKey firstClassCardKey = GlobalKey();
  final GlobalKey chatTabKey = GlobalKey();
  final GlobalKey tasksTabKey = GlobalKey();
  final GlobalKey profileButtonKey = GlobalKey();
  final GlobalKey helpButtonKey = GlobalKey();
  
  /// Optional keys for color legend (set from class screen if available)
  final GlobalKey colorLegendKey = GlobalKey();

  /// Check if tour is currently active
  bool get isActive => _isActive;

  /// Play haptic feedback for button interactions (kid-friendly)
  void _playHapticFeedback() {
    HapticFeedback.mediumImpact();
  }

  /// Start the feature tour
  Future<void> startTour(BuildContext context, {bool isReplay = false}) async {
    if (_isActive) return;

    // If not a replay, check if already completed
    if (!isReplay) {
      final completed = await OnboardingService.hasCompletedFeatureTour();
      if (completed) {
        AppLogger.debug('Feature tour already completed, skipping');
        return;
      }
    }

    _isActive = true;

    final targets = _createTargets(context);
    
    if (targets.isEmpty) {
      AppLogger.warning('No valid targets found for feature tour');
      _isActive = false;
      return;
    }

    _tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: const Color(0xFF111827),
      opacityShadow: 0.9,
      textSkip: 'SKIP TOUR',
      textStyleSkip: GoogleFonts.inter(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      paddingFocus: 10,
      focusAnimationDuration: const Duration(milliseconds: 400),
      pulseAnimationDuration: const Duration(milliseconds: 1000),
      onFinish: () {
        _isActive = false;
        OnboardingService.completeFeatureTour();
        AppLogger.info('Feature tour completed');
      },
      onSkip: () {
        _isActive = false;
        OnboardingService.completeFeatureTour();
        AppLogger.info('Feature tour skipped');
        return true;
      },
      onClickTarget: (target) {
        AppLogger.debug('Clicked target: ${target.identify}');
      },
    );

    // Small delay to ensure UI is ready
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (context.mounted) {
      _tutorialCoachMark!.show(context: context);
    }
  }

  /// Create the tour targets
  List<TargetFocus> _createTargets(BuildContext context) {
    final targets = <TargetFocus>[];
    int stepNumber = 0;
    final totalSteps = _getTargetCount();

    // Target 1: Classes Tab (if key is attached)
    if (classesTabKey.currentContext != null) {
      stepNumber++;
      final currentStep = stepNumber;
      targets.add(
        TargetFocus(
          identify: 'classes_tab',
          keyTarget: classesTabKey,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                return _buildTooltipContent(
                  context,
                  icon: Icons.school_rounded,
                  iconColor: const Color(0xFF0E72ED),
                  title: AppLocalizations.of(context)!.yourClasses,
                  description:
                      'This is your main screen! Here you\'ll see all your upcoming classes and can join them when it\'s time.',
                  stepNumber: currentStep,
                  totalSteps: totalSteps,
                  onNext: () {
                    _playHapticFeedback();
                    controller.next();
                  },
                );
              },
            ),
          ],
        ),
      );
    }

    // Target 2: First Class Card (if available)
    if (firstClassCardKey.currentContext != null) {
      stepNumber++;
      final currentStep = stepNumber;
      targets.add(
        TargetFocus(
          identify: 'first_class_card',
          keyTarget: firstClassCardKey,
          shape: ShapeLightFocus.RRect,
          radius: 16,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return _buildTooltipContent(
                  context,
                  icon: Icons.videocam_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: AppLocalizations.of(context)!.classCards,
                  description:
                      'Each card shows your class details. When the "Join" button appears, tap it to enter your live class!',
                  stepNumber: currentStep,
                  totalSteps: totalSteps,
                  onNext: () {
                    _playHapticFeedback();
                    controller.next();
                  },
                );
              },
            ),
          ],
        ),
      );
    }

    // Target 3: Color Legend explanation (shown after class card)
    // This is a custom overlay without a specific widget target
    stepNumber++;
    final currentLegendStep = stepNumber;
    targets.add(
      TargetFocus(
        identify: 'color_legend',
        targetPosition: TargetPosition(
          Size(MediaQuery.of(context).size.width * 0.8, 200),
          Offset(
            MediaQuery.of(context).size.width * 0.1,
            MediaQuery.of(context).size.height * 0.3,
          ),
        ),
        shape: ShapeLightFocus.RRect,
        radius: 20,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(
              top: MediaQuery.of(context).size.height * 0.15,
            ),
            builder: (context, controller) {
              return _buildColorLegendContent(
                context,
                stepNumber: currentLegendStep,
                totalSteps: totalSteps,
                onNext: () {
                  _playHapticFeedback();
                  controller.next();
                },
              );
            },
          ),
        ],
      ),
    );

    // Target 4: Chat Tab
    if (chatTabKey.currentContext != null) {
      stepNumber++;
      final currentStep = stepNumber;
      targets.add(
        TargetFocus(
          identify: 'chat_tab',
          keyTarget: chatTabKey,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                return _buildTooltipContent(
                  context,
                  icon: Icons.chat_bubble_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  title: AppLocalizations.of(context)!.chatMessages,
                  description:
                      'Stay connected with your teachers and classmates. Send messages and get help when you need it.',
                  stepNumber: currentStep,
                  totalSteps: totalSteps,
                  onNext: () {
                    _playHapticFeedback();
                    controller.next();
                  },
                );
              },
            ),
          ],
        ),
      );
    }

    // Target 5: Tasks Tab (if available)
    if (tasksTabKey.currentContext != null) {
      stepNumber++;
      final currentStep = stepNumber;
      targets.add(
        TargetFocus(
          identify: 'tasks_tab',
          keyTarget: tasksTabKey,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                return _buildTooltipContent(
                  context,
                  icon: Icons.task_alt_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: AppLocalizations.of(context)!.navTasks,
                  description:
                      'Keep track of your homework and assignments here. Stay organized and never miss a deadline!',
                  stepNumber: currentStep,
                  totalSteps: totalSteps,
                  onNext: () {
                    _playHapticFeedback();
                    controller.next();
                  },
                );
              },
            ),
          ],
        ),
      );
    }

    // Target 6: Profile Button
    if (profileButtonKey.currentContext != null) {
      stepNumber++;
      final currentStep = stepNumber;
      targets.add(
        TargetFocus(
          identify: 'profile_button',
          keyTarget: profileButtonKey,
          shape: ShapeLightFocus.Circle,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return _buildTooltipContent(
                  context,
                  icon: Icons.person_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  title: AppLocalizations.of(context)!.yourProfileSettings,
                  description:
                      'Tap here to view your profile, change settings, get help, or sign out. You can also restart this tour anytime from here!',
                  stepNumber: currentStep,
                  totalSteps: totalSteps,
                  onNext: () {
                    _playHapticFeedback();
                    controller.next();
                  },
                  isLast: true,
                );
              },
            ),
          ],
        ),
      );
    }

    return targets;
  }

  int _getTargetCount() {
    int count = 1; // Always include color legend
    if (classesTabKey.currentContext != null) count++;
    if (firstClassCardKey.currentContext != null) count++;
    if (chatTabKey.currentContext != null) count++;
    if (tasksTabKey.currentContext != null) count++;
    if (profileButtonKey.currentContext != null) count++;
    return count > 0 ? count : 6; // Default to 6 if checking before mount
  }

  /// Build the color legend explanation widget
  Widget _buildColorLegendContent(BuildContext context, {
    required int stepNumber,
    required int totalSteps,
    required VoidCallback onNext,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E72ED).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.palette_rounded, color: Color(0xFF0E72ED), size: 24),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Step ${stepNumber} of ${totalSteps}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Title
          Text(
            AppLocalizations.of(context)!.understandingClassColors,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            AppLocalizations.of(context)!.eachClassCardHasAColor,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF6B7280),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Color legend items
          _buildColorLegendItem(
            color: const Color(0xFF10B981),
            label: AppLocalizations.of(context)!.studentFeatureTourLive,
            description:
                AppLocalizations.of(context)!.studentFeatureTourLiveDesc,
          ),
          const SizedBox(height: 10),
          _buildColorLegendItem(
            color: const Color(0xFF0E72ED),
            label: AppLocalizations.of(context)!.studentFeatureTourJoinnow,
            description:
                AppLocalizations.of(context)!.studentFeatureTourJoinNowDesc,
          ),
          const SizedBox(height: 10),
          _buildColorLegendItem(
            color: const Color(0xFFDC2626),
            label: AppLocalizations.of(context)!.studentFeatureTourStartingsoon,
            description:
                AppLocalizations.of(context)!.studentFeatureTourStartingSoonDesc,
          ),
          const SizedBox(height: 10),
          _buildColorLegendItem(
            color: const Color(0xFFF59E0B),
            label: AppLocalizations.of(context)!.studentFeatureTourStartingin15min,
            description:
                AppLocalizations.of(context)!.studentFeatureTourStartingSoon15Desc,
          ),
          const SizedBox(height: 10),
          _buildColorLegendItem(
            color: const Color(0xFF6B7280),
            label: AppLocalizations.of(context)!.shiftScheduled,
            description:
                AppLocalizations.of(context)!.studentFeatureTourScheduledDesc,
          ),
          
          const SizedBox(height: 20),
          
          // Next button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E72ED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppLocalizations.of(context)!.gotIt,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorLegendItem({
    required Color color,
    required String label,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF6B7280),
            ),
          ),
        ),
      ],
    );
  }

  /// Build the tooltip content widget
  Widget _buildTooltipContent(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required int stepNumber,
    required int totalSteps,
    required VoidCallback onNext,
    bool isLast = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and step counter
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Step ${stepNumber} of ${totalSteps}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Title
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Description
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: const Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Next button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: iconColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLast ? 'Start Learning!' : 'Next',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isLast ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Stop the tour programmatically
  void stopTour() {
    _tutorialCoachMark?.finish();
    _isActive = false;
  }
}

/// Singleton instance for the student feature tour
final studentFeatureTour = StudentFeatureTour();
