import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/landing_page_content.dart';

class LandingPageService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collectionName = 'landing_page_content';
  static const String _documentId = 'main';
  static const String _cloudFunctionUrl =
      'https://us-central1-alluwal-academy.cloudfunctions.net/getLandingPageContent';

  // Return static content without remote fetch – used for the public landing page.
  static Future<LandingPageContent> getLandingPageContent() async {
    print('LandingPageService: Returning static default landing page content');
    return LandingPageContent.defaultContent();
  }

  /// Save landing page content
  static Future<void> saveLandingPageContent(LandingPageContent content) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('User must be authenticated to save content');
    }

    final updatedContent = content.copyWith(
      lastModified: DateTime.now(),
      lastModifiedBy: currentUser.uid,
    );

    await _saveLandingPageContent(updatedContent);
  }

  /// Private method to save content to Firestore
  static Future<void> _saveLandingPageContent(
      LandingPageContent content) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(_documentId)
          .set(content.toFirestore(), SetOptions(merge: true));

      print('Landing page content saved successfully');
    } catch (e) {
      print('Error saving landing page content: $e');
      throw Exception('Failed to save landing page content: $e');
    }
  }

  /// Update specific section of landing page content
  static Future<void> updateHeroSection(HeroSectionContent heroSection) async {
    try {
      final currentContent = await getLandingPageContent();
      final updatedContent = currentContent.copyWith(
        heroSection: heroSection,
        lastModified: DateTime.now(),
        lastModifiedBy: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
      );
      await _saveLandingPageContent(updatedContent);
    } catch (e) {
      throw Exception('Failed to update hero section: $e');
    }
  }

  /// Update features section
  static Future<void> updateFeatures(List<FeatureContent> features) async {
    try {
      final currentContent = await getLandingPageContent();
      final updatedContent = currentContent.copyWith(
        features: features,
        lastModified: DateTime.now(),
        lastModifiedBy: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
      );
      await _saveLandingPageContent(updatedContent);
    } catch (e) {
      throw Exception('Failed to update features: $e');
    }
  }

  /// Update stats section
  static Future<void> updateStats(StatsContent stats) async {
    try {
      final currentContent = await getLandingPageContent();
      final updatedContent = currentContent.copyWith(
        stats: stats,
        lastModified: DateTime.now(),
        lastModifiedBy: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
      );
      await _saveLandingPageContent(updatedContent);
    } catch (e) {
      throw Exception('Failed to update stats: $e');
    }
  }

  /// Update courses section
  static Future<void> updateCourses(List<CourseContent> courses) async {
    try {
      final currentContent = await getLandingPageContent();
      final updatedContent = currentContent.copyWith(
        courses: courses,
        lastModified: DateTime.now(),
        lastModifiedBy: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
      );
      await _saveLandingPageContent(updatedContent);
    } catch (e) {
      throw Exception('Failed to update courses: $e');
    }
  }

  /// Update testimonials section
  static Future<void> updateTestimonials(
      List<TestimonialContent> testimonials) async {
    try {
      final currentContent = await getLandingPageContent();
      final updatedContent = currentContent.copyWith(
        testimonials: testimonials,
        lastModified: DateTime.now(),
        lastModifiedBy: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
      );
      await _saveLandingPageContent(updatedContent);
    } catch (e) {
      throw Exception('Failed to update testimonials: $e');
    }
  }

  /// Update CTA section
  static Future<void> updateCTASection(CTASectionContent ctaSection) async {
    try {
      final currentContent = await getLandingPageContent();
      final updatedContent = currentContent.copyWith(
        ctaSection: ctaSection,
        lastModified: DateTime.now(),
        lastModifiedBy: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
      );
      await _saveLandingPageContent(updatedContent);
    } catch (e) {
      throw Exception('Failed to update CTA section: $e');
    }
  }

  /// Update footer section
  static Future<void> updateFooter(FooterContent footer) async {
    try {
      final currentContent = await getLandingPageContent();
      final updatedContent = currentContent.copyWith(
        footer: footer,
        lastModified: DateTime.now(),
        lastModifiedBy: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
      );
      await _saveLandingPageContent(updatedContent);
    } catch (e) {
      throw Exception('Failed to update footer: $e');
    }
  }

  /// Get content change history (for future implementation)
  static Future<List<Map<String, dynamic>>> getContentHistory() async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .doc(_documentId)
          .collection('history')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      print('Error loading content history: $e');
      return [];
    }
  }

  /// Create a backup of current content (for version control)
  static Future<void> createContentBackup(String reason) async {
    try {
      final currentContent = await getLandingPageContent();
      final currentUser = FirebaseAuth.instance.currentUser;

      await _firestore
          .collection(_collectionName)
          .doc(_documentId)
          .collection('history')
          .add({
        ...currentContent.toFirestore(),
        'backup_timestamp': FieldValue.serverTimestamp(),
        'backup_reason': reason,
        'backup_by': currentUser?.uid ?? 'unknown',
      });

      print('Content backup created successfully');
    } catch (e) {
      print('Error creating content backup: $e');
    }
  }

  /// Stream for real-time content updates (useful for preview)
  static Stream<LandingPageContent> getLandingPageContentStream() {
    return _firestore
        .collection(_collectionName)
        .doc(_documentId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return LandingPageContent.fromFirestore(doc);
      } else {
        return LandingPageContent.defaultContent();
      }
    });
  }
}
