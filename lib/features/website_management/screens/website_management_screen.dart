import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/landing_page_content.dart';
import '../../../core/services/landing_page_service.dart';
import '../widgets/hero_section_editor.dart';
import '../widgets/features_section_editor.dart';
import '../widgets/stats_section_editor.dart';
import '../widgets/courses_section_editor.dart';
import '../widgets/testimonials_section_editor.dart';
import '../widgets/cta_section_editor.dart';
import '../widgets/footer_section_editor.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class WebsiteManagementScreen extends StatefulWidget {
  const WebsiteManagementScreen({super.key});

  @override
  State<WebsiteManagementScreen> createState() => _WebsiteManagementScreenState();
}

class _WebsiteManagementScreenState extends State<WebsiteManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  LandingPageContent? _content;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  static const _tabCount = 7;
  late List<Tab> _tabs;
  bool _tabsInitialized = false;

  void _initTabs(BuildContext context) {
    if (_tabsInitialized) return;
    _tabsInitialized = true;
    final l10n = AppLocalizations.of(context)!;
    _tabs = [
      Tab(text: l10n.heroSection, icon: const Icon(Icons.home, size: 20)),
      Tab(text: l10n.features, icon: const Icon(Icons.star, size: 20)),
      Tab(text: l10n.statistics, icon: const Icon(Icons.analytics, size: 20)),
      Tab(text: l10n.courses, icon: const Icon(Icons.school, size: 20)),
      Tab(text: l10n.testimonials, icon: const Icon(Icons.reviews, size: 20)),
      Tab(text: l10n.callToAction, icon: const Icon(Icons.campaign, size: 20)),
      Tab(text: l10n.footer, icon: const Icon(Icons.info, size: 20)),
    ];
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _loadContent();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final content = await LandingPageService.getLandingPageContent();
      setState(() {
        _content = content;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load content: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveContent() async {
    if (_content == null) return;

    try {
      setState(() => _isSaving = true);
      
      // Create backup before saving
      await LandingPageService.createContentBackup('Manual save from admin panel');
      
      // Save the content
      await LandingPageService.saveLandingPageContent(_content!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(AppLocalizations.of(context)!.websiteContentSavedSuccessfullyChangesWill),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'View Site',
              textColor: Colors.white,
              onPressed: () {
                // Navigate to landing page to see changes
                Navigator.of(context).pushReplacementNamed('/');
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedToSaveContentE),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _onContentChanged(LandingPageContent updatedContent) {
    setState(() {
      _content = updatedContent;
    });
  }

  @override
  Widget build(BuildContext context) {
    _initTabs(context);
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.websiteManagement,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: const Color(0xff111827),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
        actions: [
          if (_content != null)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  // Last modified info
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.lastModified,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xff6B7280),
                        ),
                      ),
                      Text(
                        _formatDate(_content!.lastModified),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xff374151),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Save button
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveContent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff3B82F6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.save, size: 16),
                    label: Text(
                      _isSaving ? 'Saving...' : 'Save Changes',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        bottom: _content != null
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: const Color(0xff3B82F6),
                unselectedLabelColor: const Color(0xff6B7280),
                indicatorColor: const Color(0xff3B82F6),
                labelStyle: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                tabs: _tabs,
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.loadingWebsiteContent,
              style: TextStyle(
                fontSize: 16,
                color: Color(0xff6B7280),
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
            SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadContent,
              child: Text(AppLocalizations.of(context)!.commonRetry),
            ),
          ],
        ),
      );
    }

    if (_content == null) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.noContentAvailable,
          style: TextStyle(
            fontSize: 16,
            color: Color(0xff6B7280),
          ),
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        HeroSectionEditor(
          content: _content!.heroSection,
          onChanged: (heroSection) {
            _onContentChanged(_content!.copyWith(heroSection: heroSection));
          },
        ),
        FeaturesSectionEditor(
          features: _content!.features,
          onChanged: (features) {
            _onContentChanged(_content!.copyWith(features: features));
          },
        ),
        StatsSectionEditor(
          stats: _content!.stats,
          onChanged: (stats) {
            _onContentChanged(_content!.copyWith(stats: stats));
          },
        ),
        CoursesSectionEditor(
          courses: _content!.courses,
          onChanged: (courses) {
            _onContentChanged(_content!.copyWith(courses: courses));
          },
        ),
        TestimonialsSectionEditor(
          testimonials: _content!.testimonials,
          onChanged: (testimonials) {
            _onContentChanged(_content!.copyWith(testimonials: testimonials));
          },
        ),
        CTASectionEditor(
          content: _content!.ctaSection,
          onChanged: (ctaSection) {
            _onContentChanged(_content!.copyWith(ctaSection: ctaSection));
          },
        ),
        FooterSectionEditor(
          footer: _content!.footer,
          onChanged: (footer) {
            _onContentChanged(_content!.copyWith(footer: footer));
          },
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
} 