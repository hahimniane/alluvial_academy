import 'package:cloud_firestore/cloud_firestore.dart';

/// Single-plan overrides stored under [PublicSiteCmsPricingDoc.plans][planId].
class PublicSitePlanPricing {
  final double? session30Usd;
  final double? session60Usd;
  final double? hourlyUsd;
  /// Tutoring: $/hr when total weekly hours are under 4 (default 11.99).
  final double? tutoringHrUnder4Usd;
  /// Tutoring: $/hr when weekly hours are 4+ (default 9.99).
  final double? tutoringHr4PlusUsd;
  /// Islamic 1-on-1: $/hr when weekly hours are under 5 (default 8.50).
  final double? islamicHrUnder5Usd;
  /// Islamic 1-on-1: $/hr when weekly hours are 5+ (default 6.99).
  final double? islamicHr5PlusUsd;
  /// V2 Islamic track base hourly price.
  final double? islamicBaseUsd;
  /// V2 Islamic track discounted hourly price (4+ hrs/week).
  final double? islamicDiscountUsd;
  /// Weekly hours at or below this use base rate; discount applies when hours > threshold (default 4).
  final int? islamicDiscountThreshold;
  /// V2 Tutoring track base hourly price.
  final double? tutoringBaseUsd;
  /// V2 Tutoring track discounted hourly price (4+ hrs/week).
  final double? tutoringDiscountUsd;
  /// Weekly hours at or below this use base rate; discount when hours > threshold (default 4).
  final int? tutoringDiscountThreshold;
  /// V2 Group track hourly price.
  final double? groupHourlyUsd;
  final List<String> bullets;

  const PublicSitePlanPricing({
    this.session30Usd,
    this.session60Usd,
    this.hourlyUsd,
    this.tutoringHrUnder4Usd,
    this.tutoringHr4PlusUsd,
    this.islamicHrUnder5Usd,
    this.islamicHr5PlusUsd,
    this.islamicBaseUsd,
    this.islamicDiscountUsd,
    this.islamicDiscountThreshold,
    this.tutoringBaseUsd,
    this.tutoringDiscountUsd,
    this.tutoringDiscountThreshold,
    this.groupHourlyUsd,
    this.bullets = const [],
  });

  bool get hasNumericOverrides =>
      session30Usd != null ||
      session60Usd != null ||
      hourlyUsd != null ||
      tutoringHrUnder4Usd != null ||
      tutoringHr4PlusUsd != null ||
      islamicHrUnder5Usd != null ||
      islamicHr5PlusUsd != null ||
      islamicBaseUsd != null ||
      islamicDiscountUsd != null ||
      islamicDiscountThreshold != null ||
      tutoringBaseUsd != null ||
      tutoringDiscountUsd != null ||
      tutoringDiscountThreshold != null ||
      groupHourlyUsd != null;

  Map<String, dynamic> toMap() => {
        if (session30Usd != null) 'session30Usd': session30Usd,
        if (session60Usd != null) 'session60Usd': session60Usd,
        if (hourlyUsd != null) 'hourlyUsd': hourlyUsd,
        if (tutoringHrUnder4Usd != null) 'tutoringHrUnder4Usd': tutoringHrUnder4Usd,
        if (tutoringHr4PlusUsd != null) 'tutoringHr4PlusUsd': tutoringHr4PlusUsd,
        if (islamicHrUnder5Usd != null) 'islamicHrUnder5Usd': islamicHrUnder5Usd,
        if (islamicHr5PlusUsd != null) 'islamicHr5PlusUsd': islamicHr5PlusUsd,
        if (islamicBaseUsd != null) 'islamicBaseUsd': islamicBaseUsd,
        if (islamicDiscountUsd != null) 'islamicDiscountUsd': islamicDiscountUsd,
        if (islamicDiscountThreshold != null)
          'islamicDiscountThreshold': islamicDiscountThreshold,
        if (tutoringBaseUsd != null) 'tutoringBaseUsd': tutoringBaseUsd,
        if (tutoringDiscountUsd != null) 'tutoringDiscountUsd': tutoringDiscountUsd,
        if (tutoringDiscountThreshold != null)
          'tutoringDiscountThreshold': tutoringDiscountThreshold,
        if (groupHourlyUsd != null) 'groupHourlyUsd': groupHourlyUsd,
        'bullets': bullets,
      };

  factory PublicSitePlanPricing.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) {
      return const PublicSitePlanPricing();
    }
    List<String> bullets = const [];
    final raw = map['bullets'];
    if (raw is List) {
      bullets = raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    return PublicSitePlanPricing(
      session30Usd: _readDouble(map['session30Usd']),
      session60Usd: _readDouble(map['session60Usd']),
      hourlyUsd: _readDouble(map['hourlyUsd']),
      tutoringHrUnder4Usd: _readDouble(map['tutoringHrUnder4Usd']),
      tutoringHr4PlusUsd: _readDouble(map['tutoringHr4PlusUsd']),
      islamicHrUnder5Usd: _readDouble(map['islamicHrUnder5Usd']),
      islamicHr5PlusUsd: _readDouble(map['islamicHr5PlusUsd']),
      islamicBaseUsd: _readDouble(map['islamicBaseUsd']) ?? _readDouble(map['islamicHrUnder5Usd']),
      islamicDiscountUsd: _readDouble(map['islamicDiscountUsd']) ?? _readDouble(map['islamicHr5PlusUsd']),
      islamicDiscountThreshold: _readInt(map['islamicDiscountThreshold']),
      tutoringBaseUsd: _readDouble(map['tutoringBaseUsd']) ?? _readDouble(map['tutoringHrUnder4Usd']),
      tutoringDiscountUsd: _readDouble(map['tutoringDiscountUsd']) ?? _readDouble(map['tutoringHr4PlusUsd']),
      tutoringDiscountThreshold: _readInt(map['tutoringDiscountThreshold']),
      groupHourlyUsd: _readDouble(map['groupHourlyUsd']) ?? _readDouble(map['hourlyUsd']),
      bullets: bullets,
    );
  }

  static int? _readInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double? _readDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

/// Document: collection [PublicSiteCmsService.pricingCollection] / main
class PublicSiteCmsPricingDoc {
  final Map<String, PublicSitePlanPricing> plans;
  final DateTime? updatedAt;

  const PublicSiteCmsPricingDoc({
    this.plans = const {},
    this.updatedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'plans': plans.map((k, v) => MapEntry(k, v.toMap())),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory PublicSiteCmsPricingDoc.fromFirestore(Map<String, dynamic> data) {
    final rawPlans = data['plans'];
    final plans = <String, PublicSitePlanPricing>{};
    if (rawPlans is Map) {
      rawPlans.forEach((key, value) {
        if (key is! String) return;
        if (value is Map<String, dynamic>) {
          plans[key] = PublicSitePlanPricing.fromMap(value);
        } else if (value is Map) {
          plans[key] = PublicSitePlanPricing.fromMap(
            value.map((k, v) => MapEntry(k.toString(), v)),
          );
        }
      });
    }
    final ts = data['updatedAt'];
    DateTime? updatedAt;
    if (ts is Timestamp) updatedAt = ts.toDate();
    return PublicSiteCmsPricingDoc(plans: plans, updatedAt: updatedAt);
  }

  /// For quote math: nested maps as expected by [PricingQuoteService].
  Map<String, Map<String, dynamic>> planOverridesForQuotes() {
    final out = <String, Map<String, dynamic>>{};
    plans.forEach((id, p) {
      final m = <String, dynamic>{};
      if (p.session30Usd != null) m['session30Usd'] = p.session30Usd;
      if (p.session60Usd != null) m['session60Usd'] = p.session60Usd;
      if (p.hourlyUsd != null) m['hourlyUsd'] = p.hourlyUsd;
      if (p.tutoringHrUnder4Usd != null) {
        m['tutoringHrUnder4Usd'] = p.tutoringHrUnder4Usd;
      }
      if (p.tutoringHr4PlusUsd != null) {
        m['tutoringHr4PlusUsd'] = p.tutoringHr4PlusUsd;
      }
      if (p.islamicHrUnder5Usd != null) {
        m['islamicHrUnder5Usd'] = p.islamicHrUnder5Usd;
      }
      if (p.islamicHr5PlusUsd != null) {
        m['islamicHr5PlusUsd'] = p.islamicHr5PlusUsd;
      }
      if (p.islamicBaseUsd != null) m['islamicBaseUsd'] = p.islamicBaseUsd;
      if (p.islamicDiscountUsd != null) {
        m['islamicDiscountUsd'] = p.islamicDiscountUsd;
      }
      if (p.islamicDiscountThreshold != null) {
        m['islamicDiscountThreshold'] = p.islamicDiscountThreshold;
      }
      if (p.tutoringBaseUsd != null) m['tutoringBaseUsd'] = p.tutoringBaseUsd;
      if (p.tutoringDiscountUsd != null) {
        m['tutoringDiscountUsd'] = p.tutoringDiscountUsd;
      }
      if (p.tutoringDiscountThreshold != null) {
        m['tutoringDiscountThreshold'] = p.tutoringDiscountThreshold;
      }
      if (p.groupHourlyUsd != null) m['groupHourlyUsd'] = p.groupHourlyUsd;
      if (m.isNotEmpty) out[id] = m;
    });
    return out;
  }
}

/// Public team row (Firestore). Document in [PublicSiteCmsService.teamCollection].
class PublicSiteTeamMember {
  final String id;
  final String name;
  final String role;
  final String city;
  final String education;
  final String bio;
  final List<String> languages;
  final String whyAlluwal;
  final String? imageUrl;
  /// Bundled asset path (e.g. `assets/images/staff/…`) when the row was imported
  /// from [assets/data/staff.json]; used as avatar fallback when [imageUrl] is empty.
  final String? photoAsset;
  /// Optional Firebase Auth UID of a teacher/leader linked to this public profile.
  final String? linkedUserUid;
  final String category;
  final int sortOrder;
  final bool active;

  const PublicSiteTeamMember({
    required this.id,
    required this.name,
    required this.role,
    required this.city,
    required this.education,
    required this.bio,
    required this.languages,
    required this.whyAlluwal,
    this.imageUrl,
    this.photoAsset,
    this.linkedUserUid,
    required this.category,
    required this.sortOrder,
    this.active = true,
  });

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'role': role,
        'city': city,
        'education': education,
        'bio': bio,
        'languages': languages,
        'whyAlluwal': whyAlluwal,
        if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
        if (photoAsset != null && photoAsset!.trim().isNotEmpty)
          'photoAsset': photoAsset!.trim(),
        'linkedUserUid': (linkedUserUid ?? '').trim(),
        'category': category,
        'sortOrder': sortOrder,
        'active': active,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory PublicSiteTeamMember.fromDoc(
    String id,
    Map<String, dynamic> data,
  ) {
    final langs = data['languages'];
    final lu = data['linkedUserUid']?.toString().trim();
    final pa = data['photoAsset']?.toString().trim();
    return PublicSiteTeamMember(
      id: id,
      name: (data['name'] ?? '').toString(),
      role: (data['role'] ?? '').toString(),
      city: (data['city'] ?? '').toString(),
      education: (data['education'] ?? '').toString(),
      bio: (data['bio'] ?? '').toString(),
      languages: langs is List
          ? langs.map((e) => e.toString()).toList()
          : const [],
      whyAlluwal: (data['whyAlluwal'] ?? '').toString(),
      imageUrl: data['imageUrl']?.toString(),
      photoAsset: (pa != null && pa.isNotEmpty) ? pa : null,
      linkedUserUid: (lu != null && lu.isNotEmpty) ? lu : null,
      category: (data['category'] ?? 'teacher').toString(),
      sortOrder: (data['sortOrder'] is int)
          ? data['sortOrder'] as int
          : int.tryParse('${data['sortOrder']}') ?? 0,
      active: data['active'] != false,
    );
  }
}

/// One social network entry (header utility bar). Firestore map under
/// [PublicSiteSocialDoc.instagram] / facebook / tiktok.
class PublicSiteSocialNetwork {
  final bool enabled;
  final String url;

  const PublicSiteSocialNetwork({
    this.enabled = false,
    this.url = '',
  });

  /// Non-null only when [enabled], non-empty, and URL is http(s).
  Uri? get validUri {
    if (!enabled) return null;
    final t = url.trim();
    if (t.isEmpty) return null;
    final u = Uri.tryParse(t);
    if (u == null || !(u.isScheme('http') || u.isScheme('https'))) {
      return null;
    }
    return u;
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'url': url.trim(),
      };

  factory PublicSiteSocialNetwork.fromMap(dynamic raw) {
    if (raw is! Map) return const PublicSiteSocialNetwork();
    return PublicSiteSocialNetwork(
      enabled: raw['enabled'] == true,
      url: (raw['url'] ?? '').toString(),
    );
  }
}

/// Document: [PublicSiteCmsService.socialCollection] / main
class PublicSiteSocialDoc {
  final PublicSiteSocialNetwork instagram;
  final PublicSiteSocialNetwork facebook;
  final PublicSiteSocialNetwork tiktok;
  final DateTime? updatedAt;

  const PublicSiteSocialDoc({
    this.instagram = const PublicSiteSocialNetwork(),
    this.facebook = const PublicSiteSocialNetwork(),
    this.tiktok = const PublicSiteSocialNetwork(),
    this.updatedAt,
  });

  Map<String, dynamic> toFirestore() => {
        'instagram': instagram.toMap(),
        'facebook': facebook.toMap(),
        'tiktok': tiktok.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory PublicSiteSocialDoc.fromFirestore(Map<String, dynamic> data) {
    DateTime? updatedAt;
    final ts = data['updatedAt'];
    if (ts is Timestamp) updatedAt = ts.toDate();
    return PublicSiteSocialDoc(
      instagram: PublicSiteSocialNetwork.fromMap(data['instagram']),
      facebook: PublicSiteSocialNetwork.fromMap(data['facebook']),
      tiktok: PublicSiteSocialNetwork.fromMap(data['tiktok']),
      updatedAt: updatedAt,
    );
  }
}

/// Public landing hero (home page) — Firestore [PublicSiteCmsService.landingCollection] / main.
class PublicSiteLandingDoc {
  static const String defaultHeroBackgroundHex = '#001E4E';

  /// `#RRGGBB` or `RRGGBB` (leading # optional).
  final String heroBackgroundColorHex;
  final String heroMainImageUrl;
  final String heroLeftImageUrl;
  final String heroRightImageUrl;
  final DateTime? updatedAt;

  const PublicSiteLandingDoc({
    this.heroBackgroundColorHex = defaultHeroBackgroundHex,
    this.heroMainImageUrl = '',
    this.heroLeftImageUrl = '',
    this.heroRightImageUrl = '',
    this.updatedAt,
  });

  /// Parses [heroBackgroundColorHex] to `0xAARRGGBB`; [fallbackArgb] if invalid.
  static int parseHeroBackgroundArgb(
    String? raw, {
    int fallbackArgb = 0xFF001E4E,
  }) {
    var s = (raw ?? '').trim();
    if (s.isEmpty) return fallbackArgb;
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 6) {
      final v = int.tryParse(s, radix: 16);
      if (v != null) return 0xFF000000 | v;
    }
    if (s.length == 8) {
      final v = int.tryParse(s, radix: 16);
      if (v != null) return v;
    }
    return fallbackArgb;
  }

  /// Non-null https URI for hero slot, or null to use bundled asset.
  static Uri? heroImageUri(String? raw) {
    final t = (raw ?? '').trim();
    if (t.isEmpty) return null;
    final u = Uri.tryParse(t);
    if (u == null || !u.hasScheme) return null;
    if (u.isScheme('https')) return u;
    if (u.isScheme('http')) return u;
    return null;
  }

  Map<String, dynamic> toFirestore() => {
        'heroBackgroundColorHex': heroBackgroundColorHex.trim().isEmpty
            ? defaultHeroBackgroundHex
            : heroBackgroundColorHex.trim(),
        'heroMainImageUrl': heroMainImageUrl.trim(),
        'heroLeftImageUrl': heroLeftImageUrl.trim(),
        'heroRightImageUrl': heroRightImageUrl.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory PublicSiteLandingDoc.fromFirestore(Map<String, dynamic> data) {
    DateTime? updatedAt;
    final ts = data['updatedAt'];
    if (ts is Timestamp) updatedAt = ts.toDate();
    final hex = (data['heroBackgroundColorHex'] ?? defaultHeroBackgroundHex)
        .toString()
        .trim();
    return PublicSiteLandingDoc(
      heroBackgroundColorHex:
          hex.isEmpty ? defaultHeroBackgroundHex : hex,
      heroMainImageUrl: (data['heroMainImageUrl'] ?? '').toString(),
      heroLeftImageUrl: (data['heroLeftImageUrl'] ?? '').toString(),
      heroRightImageUrl: (data['heroRightImageUrl'] ?? '').toString(),
      updatedAt: updatedAt,
    );
  }
}
