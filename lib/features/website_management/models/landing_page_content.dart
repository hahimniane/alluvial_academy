import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for editable landing page content
class LandingPageContent {
  final String id;
  final HeroSectionContent heroSection;
  final List<FeatureContent> features;
  final StatsContent stats;
  final List<CourseContent> courses;
  final List<TestimonialContent> testimonials;
  final CTASectionContent ctaSection;
  final FooterContent footer;
  final DateTime lastModified;
  final String lastModifiedBy;

  const LandingPageContent({
    required this.id,
    required this.heroSection,
    required this.features,
    required this.stats,
    required this.courses,
    required this.testimonials,
    required this.ctaSection,
    required this.footer,
    required this.lastModified,
    required this.lastModifiedBy,
  });

  /// Default content for new installations
  factory LandingPageContent.defaultContent() {
    return LandingPageContent(
      id: 'main',
      heroSection: HeroSectionContent.defaultContent(),
      features: FeatureContent.defaultFeatures(),
      stats: StatsContent.defaultContent(),
      courses: CourseContent.defaultCourses(),
      testimonials: TestimonialContent.defaultTestimonials(),
      ctaSection: CTASectionContent.defaultContent(),
      footer: FooterContent.defaultContent(),
      lastModified: DateTime.now(),
      lastModifiedBy: 'system',
    );
  }

  /// Convert from Firestore document
  factory LandingPageContent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return LandingPageContent(
      id: doc.id,
      heroSection: HeroSectionContent.fromMap(data['hero_section'] ?? {}),
      features: (data['features'] as List<dynamic>? ?? [])
          .map((item) => FeatureContent.fromMap(item as Map<String, dynamic>))
          .toList(),
      stats: StatsContent.fromMap(data['stats'] ?? {}),
      courses: (data['courses'] as List<dynamic>? ?? [])
          .map((item) => CourseContent.fromMap(item as Map<String, dynamic>))
          .toList(),
      testimonials: (data['testimonials'] as List<dynamic>? ?? [])
          .map((item) =>
              TestimonialContent.fromMap(item as Map<String, dynamic>))
          .toList(),
      ctaSection: CTASectionContent.fromMap(data['cta_section'] ?? {}),
      footer: FooterContent.fromMap(data['footer'] ?? {}),
      lastModified: data['last_modified'] != null
          ? (data['last_modified'] as Timestamp).toDate()
          : DateTime.now(),
      lastModifiedBy: data['last_modified_by'] ?? 'unknown',
    );
  }

  /// Convert from a raw map (e.g., from JSON)
  factory LandingPageContent.fromMap(Map<String, dynamic> data) {
    return LandingPageContent(
      id: data['id'] ?? 'main',
      heroSection: HeroSectionContent.fromMap(data['hero_section'] ?? {}),
      features: (data['features'] as List<dynamic>? ?? [])
          .map((item) => FeatureContent.fromMap(item as Map<String, dynamic>))
          .toList(),
      stats: StatsContent.fromMap(data['stats'] ?? {}),
      courses: (data['courses'] as List<dynamic>? ?? [])
          .map((item) => CourseContent.fromMap(item as Map<String, dynamic>))
          .toList(),
      testimonials: (data['testimonials'] as List<dynamic>? ?? [])
          .map((item) =>
              TestimonialContent.fromMap(item as Map<String, dynamic>))
          .toList(),
      ctaSection: CTASectionContent.fromMap(data['cta_section'] ?? {}),
      footer: FooterContent.fromMap(data['footer'] ?? {}),
      lastModified: data['last_modified'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (data['last_modified']['_seconds'] as int) * 1000)
          : DateTime.now(),
      lastModifiedBy: data['last_modified_by'] ?? 'unknown',
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'hero_section': heroSection.toMap(),
      'features': features.map((f) => f.toMap()).toList(),
      'stats': stats.toMap(),
      'courses': courses.map((c) => c.toMap()).toList(),
      'testimonials': testimonials.map((t) => t.toMap()).toList(),
      'cta_section': ctaSection.toMap(),
      'footer': footer.toMap(),
      'last_modified': Timestamp.fromDate(lastModified),
      'last_modified_by': lastModifiedBy,
    };
  }

  /// Create a copy with updated fields
  LandingPageContent copyWith({
    String? id,
    HeroSectionContent? heroSection,
    List<FeatureContent>? features,
    StatsContent? stats,
    List<CourseContent>? courses,
    List<TestimonialContent>? testimonials,
    CTASectionContent? ctaSection,
    FooterContent? footer,
    DateTime? lastModified,
    String? lastModifiedBy,
  }) {
    return LandingPageContent(
      id: id ?? this.id,
      heroSection: heroSection ?? this.heroSection,
      features: features ?? this.features,
      stats: stats ?? this.stats,
      courses: courses ?? this.courses,
      testimonials: testimonials ?? this.testimonials,
      ctaSection: ctaSection ?? this.ctaSection,
      footer: footer ?? this.footer,
      lastModified: lastModified ?? this.lastModified,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
    );
  }
}

/// Hero section content
class HeroSectionContent {
  final String badgeText;
  final String mainHeadline;
  final String subtitle;
  final String primaryButtonText;
  final String secondaryButtonText;
  final String trustIndicatorText;

  const HeroSectionContent({
    required this.badgeText,
    required this.mainHeadline,
    required this.subtitle,
    required this.primaryButtonText,
    required this.secondaryButtonText,
    required this.trustIndicatorText,
  });

  factory HeroSectionContent.defaultContent() {
    return const HeroSectionContent(
      badgeText: '🌍 Embracing Africa\'s Triple Heritage',
      mainHeadline: 'The Alluwal Education Hub\nLearn, Lead & Thrive',
      subtitle:
          'Our mission seamlessly embraces what the eminent Ali Mazrui termed the \'Africa Triple Heritage\': the fusion of Islamic, African, and Western civilizations.',
      primaryButtonText: 'Sign Up for Class',
      secondaryButtonText: 'Learn More',
      trustIndicatorText:
          'Preparing students for a diverse and globalized world',
    );
  }

  factory HeroSectionContent.fromMap(Map<String, dynamic> map) {
    return HeroSectionContent(
      badgeText: map['badge_text'] ??
          '🕌 Nurturing Young Hearts Through Islamic Education',
      mainHeadline: map['main_headline'] ??
          'Quality Islamic Education\nfor Your Children',
      subtitle: map['subtitle'] ??
          'Connect with qualified Islamic teachers for Quran, Arabic, and Islamic Studies.\nTrusted by parents worldwide for authentic Islamic education.',
      primaryButtonText: map['primary_button_text'] ?? 'Start Free Trial',
      secondaryButtonText: map['secondary_button_text'] ?? 'Watch Demo',
      trustIndicatorText:
          map['trust_indicator_text'] ?? 'Trusted by Muslim families worldwide',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'badge_text': badgeText,
      'main_headline': mainHeadline,
      'subtitle': subtitle,
      'primary_button_text': primaryButtonText,
      'secondary_button_text': secondaryButtonText,
      'trust_indicator_text': trustIndicatorText,
    };
  }

  HeroSectionContent copyWith({
    String? badgeText,
    String? mainHeadline,
    String? subtitle,
    String? primaryButtonText,
    String? secondaryButtonText,
    String? trustIndicatorText,
  }) {
    return HeroSectionContent(
      badgeText: badgeText ?? this.badgeText,
      mainHeadline: mainHeadline ?? this.mainHeadline,
      subtitle: subtitle ?? this.subtitle,
      primaryButtonText: primaryButtonText ?? this.primaryButtonText,
      secondaryButtonText: secondaryButtonText ?? this.secondaryButtonText,
      trustIndicatorText: trustIndicatorText ?? this.trustIndicatorText,
    );
  }
}

/// Feature content
class FeatureContent {
  final String title;
  final String description;
  final String iconName; // Store icon as string identifier

  const FeatureContent({
    required this.title,
    required this.description,
    required this.iconName,
  });

  static List<FeatureContent> defaultFeatures() {
    return const [
      FeatureContent(
        title: 'Islamic Programs',
        description:
            'Our Islamic program is meticulously designed to immerse students in the profound depths of Islamic knowledge. Offering courses in more than six islamic subjects including: Arabic language, Quran, Hadith, Tawhid, Tafsir etc.',
        iconName: 'menu_book',
      ),
      FeatureContent(
        title: 'After School Tutoring & Adults Literacy Program',
        description:
            'Discover the transformative power of our After-school Tutoring Program at Alluwal Education Hub, where education extends beyond traditional boundaries to embrace students from kindergarten through 12th grade, alongside a specialized adult program with a flexible and personalized class schedule.',
        iconName: 'school',
      ),
      FeatureContent(
        title: 'Afrolingual Program',
        description:
            'Indigenous African Language: Embark on a captivating journey through our African Indigenous Language Learning Program, tailored for both children and adults.',
        iconName: 'language',
      ),
    ];
  }

  factory FeatureContent.fromMap(Map<String, dynamic> map) {
    return FeatureContent(
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      iconName: map['icon_name'] ?? 'star',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'icon_name': iconName,
    };
  }

  FeatureContent copyWith({
    String? title,
    String? description,
    String? iconName,
  }) {
    return FeatureContent(
      title: title ?? this.title,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
    );
  }
}

/// Stats content
class StatsContent {
  final String studentsCount;
  final String teachersCount;
  final String satisfactionRate;
  final String coursesCount;

  const StatsContent({
    required this.studentsCount,
    required this.teachersCount,
    required this.satisfactionRate,
    required this.coursesCount,
  });

  factory StatsContent.defaultContent() {
    return const StatsContent(
      studentsCount: '1,000+',
      teachersCount: '50+',
      satisfactionRate: '98%',
      coursesCount: '15+',
    );
  }

  factory StatsContent.fromMap(Map<String, dynamic> map) {
    return StatsContent(
      studentsCount: map['students_count'] ?? '1,000+',
      teachersCount: map['teachers_count'] ?? '50+',
      satisfactionRate: map['satisfaction_rate'] ?? '98%',
      coursesCount: map['courses_count'] ?? '15+',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'students_count': studentsCount,
      'teachers_count': teachersCount,
      'satisfaction_rate': satisfactionRate,
      'courses_count': coursesCount,
    };
  }

  StatsContent copyWith({
    String? studentsCount,
    String? teachersCount,
    String? satisfactionRate,
    String? coursesCount,
  }) {
    return StatsContent(
      studentsCount: studentsCount ?? this.studentsCount,
      teachersCount: teachersCount ?? this.teachersCount,
      satisfactionRate: satisfactionRate ?? this.satisfactionRate,
      coursesCount: coursesCount ?? this.coursesCount,
    );
  }
}

/// Course content
class CourseContent {
  final String title;
  final String description;
  final String duration;
  final String level;
  final String iconName;

  const CourseContent({
    required this.title,
    required this.description,
    required this.duration,
    required this.level,
    required this.iconName,
  });

  static List<CourseContent> defaultCourses() {
    return const [
      CourseContent(
        title: 'Quran Reading',
        description: 'Learn to read the Holy Quran with proper Tajweed.',
        duration: '6 months',
        level: 'Beginner',
        iconName: 'book',
      ),
      CourseContent(
        title: 'Arabic Language',
        description: 'Master Arabic language for better understanding.',
        duration: '12 months',
        level: 'All Levels',
        iconName: 'language',
      ),
      CourseContent(
        title: 'Islamic Studies',
        description: 'Comprehensive Islamic education program.',
        duration: '9 months',
        level: 'Intermediate',
        iconName: 'mosque',
      ),
    ];
  }

  factory CourseContent.fromMap(Map<String, dynamic> map) {
    return CourseContent(
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      duration: map['duration'] ?? '',
      level: map['level'] ?? '',
      iconName: map['icon_name'] ?? 'book',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'duration': duration,
      'level': level,
      'icon_name': iconName,
    };
  }

  CourseContent copyWith({
    String? title,
    String? description,
    String? duration,
    String? level,
    String? iconName,
  }) {
    return CourseContent(
      title: title ?? this.title,
      description: description ?? this.description,
      duration: duration ?? this.duration,
      level: level ?? this.level,
      iconName: iconName ?? this.iconName,
    );
  }
}

/// Testimonial content
class TestimonialContent {
  final String name;
  final String role;
  final String content;
  final String imageUrl;
  final int rating;

  const TestimonialContent({
    required this.name,
    required this.role,
    required this.content,
    required this.imageUrl,
    required this.rating,
  });

  static List<TestimonialContent> defaultTestimonials() {
    return const [
      TestimonialContent(
        name: 'Sarah Ahmad',
        role: 'Parent',
        content:
            'Excellent teachers and wonderful learning experience for my children.',
        imageUrl: '',
        rating: 5,
      ),
      TestimonialContent(
        name: 'Muhammad Hassan',
        role: 'Parent',
        content: 'My son has improved tremendously in his Quran recitation.',
        imageUrl: '',
        rating: 5,
      ),
    ];
  }

  factory TestimonialContent.fromMap(Map<String, dynamic> map) {
    return TestimonialContent(
      name: map['name'] ?? '',
      role: map['role'] ?? '',
      content: map['content'] ?? '',
      imageUrl: map['image_url'] ?? '',
      rating: map['rating'] ?? 5,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'role': role,
      'content': content,
      'image_url': imageUrl,
      'rating': rating,
    };
  }

  TestimonialContent copyWith({
    String? name,
    String? role,
    String? content,
    String? imageUrl,
    int? rating,
  }) {
    return TestimonialContent(
      name: name ?? this.name,
      role: role ?? this.role,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      rating: rating ?? this.rating,
    );
  }
}

/// CTA section content
class CTASectionContent {
  final String title;
  final String description;
  final String buttonText;

  const CTASectionContent({
    required this.title,
    required this.description,
    required this.buttonText,
  });

  factory CTASectionContent.defaultContent() {
    return const CTASectionContent(
      title: 'Give Your Child the Gift of Comprehensive Education',
      description:
          'Join our community where Islamic, African, and Western education converge to prepare students for a diverse and increasingly globalized world.',
      buttonText: 'Sign Up for Class',
    );
  }

  factory CTASectionContent.fromMap(Map<String, dynamic> map) {
    return CTASectionContent(
      title: map['title'] ?? 'Ready to Start Your Journey?',
      description: map['description'] ??
          'Join thousands of families who trust us with their children\'s Islamic education.',
      buttonText: map['button_text'] ?? 'Get Started Today',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'button_text': buttonText,
    };
  }

  CTASectionContent copyWith({
    String? title,
    String? description,
    String? buttonText,
  }) {
    return CTASectionContent(
      title: title ?? this.title,
      description: description ?? this.description,
      buttonText: buttonText ?? this.buttonText,
    );
  }
}

/// Footer content
class FooterContent {
  final String companyDescription;
  final String address;
  final String phone;
  final String email;
  final List<String> socialLinks;

  const FooterContent({
    required this.companyDescription,
    required this.address,
    required this.phone,
    required this.email,
    required this.socialLinks,
  });

  factory FooterContent.defaultContent() {
    return const FooterContent(
      companyDescription:
          'At Alluwal Education Hub, we envision a world where education transcends boundaries, cultures, and beliefs, fostering an environment where diverse knowledge thrives.',
      address: '',
      phone: 'WhatsApp: +1 646-872-8590',
      email: 'alluwhalacademy@gmail.com',
      socialLinks: [],
    );
  }

  factory FooterContent.fromMap(Map<String, dynamic> map) {
    return FooterContent(
      companyDescription: map['company_description'] ??
          'Alluwal Education Hub - Connecting Muslim families with qualified Islamic teachers.',
      address: map['address'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      socialLinks: List<String>.from(map['social_links'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'company_description': companyDescription,
      'address': address,
      'phone': phone,
      'email': email,
      'social_links': socialLinks,
    };
  }

  FooterContent copyWith({
    String? companyDescription,
    String? address,
    String? phone,
    String? email,
    List<String>? socialLinks,
  }) {
    return FooterContent(
      companyDescription: companyDescription ?? this.companyDescription,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      socialLinks: socialLinks ?? this.socialLinks,
    );
  }
}
