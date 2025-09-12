import 'package:cloud_firestore/cloud_firestore.dart';

class Subject {
  final String id;
  final String name;
  final String displayName;
  final String? description;
  final String? arabicName;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Subject({
    required this.id,
    required this.name,
    required this.displayName,
    this.description,
    this.arabicName,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Subject.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Subject(
      id: doc.id,
      name: data['name'] ?? '',
      displayName: data['displayName'] ?? '',
      description: data['description'],
      arabicName: data['arabicName'],
      sortOrder: data['sortOrder'] ?? 0,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'displayName': displayName,
      'description': description,
      'arabicName': arabicName,
      'sortOrder': sortOrder,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Subject copyWith({
    String? id,
    String? name,
    String? displayName,
    String? description,
    String? arabicName,
    int? sortOrder,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Subject(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      arabicName: arabicName ?? this.arabicName,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Default subjects to be added on first run
class DefaultSubjects {
  static final List<Map<String, dynamic>> subjects = [
    {
      'name': 'quran_studies',
      'displayName': 'Quran Studies',
      'arabicName': 'دراسات القرآن',
      'description':
          'Comprehensive Quran recitation, memorization, and understanding',
      'sortOrder': 1,
      'isActive': true,
    },
    {
      'name': 'hadith_studies',
      'displayName': 'Hadith Studies',
      'arabicName': 'دراسات الحديث',
      'description': 'Study of Prophet Muhammad\'s (PBUH) sayings and actions',
      'sortOrder': 2,
      'isActive': true,
    },
    {
      'name': 'fiqh',
      'displayName': 'Fiqh (Islamic Jurisprudence)',
      'arabicName': 'الفقه',
      'description': 'Islamic law and jurisprudence',
      'sortOrder': 3,
      'isActive': true,
    },
    {
      'name': 'arabic_language',
      'displayName': 'Arabic Language',
      'arabicName': 'اللغة العربية',
      'description': 'Classical and modern Arabic language studies',
      'sortOrder': 4,
      'isActive': true,
    },
    {
      'name': 'islamic_history',
      'displayName': 'Islamic History',
      'arabicName': 'التاريخ الإسلامي',
      'description': 'History of Islam and Muslim civilizations',
      'sortOrder': 5,
      'isActive': true,
    },
    {
      'name': 'aqeedah',
      'displayName': 'Aqeedah (Islamic Theology)',
      'arabicName': 'العقيدة',
      'description': 'Islamic beliefs and theology',
      'sortOrder': 6,
      'isActive': true,
    },
    {
      'name': 'tafseer',
      'displayName': 'Tafseer (Quran Interpretation)',
      'arabicName': 'التفسير',
      'description': 'Interpretation and explanation of the Quran',
      'sortOrder': 7,
      'isActive': true,
    },
    {
      'name': 'seerah',
      'displayName': 'Seerah (Prophet\'s Biography)',
      'arabicName': 'السيرة النبوية',
      'description': 'Life and teachings of Prophet Muhammad (PBUH)',
      'sortOrder': 8,
      'isActive': true,
    },
  ];
}
