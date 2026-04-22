import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/countries.dart' as intl_phone_countries;
import 'package:country_picker/country_picker.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import '../../widgets/modern_header.dart';
import '../../core/models/enrollment_request.dart';
import '../../core/services/enrollment_service.dart';
import '../../core/constants/pricing_plan_ids.dart';
import '../../core/models/public_site_cms_models.dart';
import '../../core/services/pricing_quote_service.dart';
import '../../core/services/public_site_cms_service.dart';
import '../enrollment_success_page.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import 'enrollment_flow_models.dart';
import 'enrollment_summary_panel.dart';
import 'enrollment_step_indicator.dart';
import 'widgets/review_summary_card.dart';
import 'steps/step_role_selection.dart';

part 'enrollment_state.dart';

class EnrollmentCoordinator extends StatefulWidget {
  final String? initialSubject;
  final bool isLanguageSelection;
  final String? initialAfricanLanguage;

  /// Stable id from [PricingPlanIds]; pre-fills program track and metadata on submit.
  final String? initialPricingPlanId;
  final String? initialTrackId;

  /// Optional display line (e.g. pre-translated from landing); otherwise derived from [initialPricingPlanId].
  final String? initialPricingPlanSummary;

  /// Hours/week from the sticky bar so pricing carries over into the form.
  final int? initialHoursPerWeek;

  /// Number of extra [EnrollmentStateMixin._students] rows to create at startup
  /// (e.g. 1 = two children total when parent uses the sibling stepper).
  final int initialAdditionalStudents;

  const EnrollmentCoordinator({
    super.key,
    this.initialSubject,
    this.isLanguageSelection = false,
    this.initialAfricanLanguage,
    this.initialPricingPlanId,
    this.initialTrackId,
    this.initialPricingPlanSummary,
    this.initialHoursPerWeek,
    this.initialAdditionalStudents = 0,
  });

  @override
  State<EnrollmentCoordinator> createState() => _EnrollmentCoordinatorState();
}

class _EnrollmentCoordinatorState extends State<EnrollmentCoordinator>
    with TickerProviderStateMixin, EnrollmentStateMixin {}
