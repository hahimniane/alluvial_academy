import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String? email;
  final String? role;
  final String? name;
  final bool isActive;
  final String? timezone;
  final String? kiosqueCode; // Family/parent identifier code
  final bool aiTutorEnabled;

  AppUser({
    required this.id,
    this.email,
    this.role,
    this.name,
    this.isActive = true,
    this.timezone,
    this.kiosqueCode,
    this.aiTutorEnabled = false,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    String displayName = '';
    if (data['first_name'] != null || data['last_name'] != null) {
      displayName = ((data['first_name'] ?? '') + ' ' + (data['last_name'] ?? '')).trim();
    }
    if (displayName.isEmpty && data['name'] != null) {
      displayName = data['name'];
    }
    if (displayName.isEmpty) {
      displayName = data['email'] ?? data['e-mail'] ?? 'Unknown User';
    }

    return AppUser(
      id: doc.id,
      email: data['e-mail'] ?? data['email'],
      role: data['user_type'] ?? data['role'],
      name: displayName,
      isActive: data['is_active'] ?? true,
      timezone: data['timezone'],
      kiosqueCode: data['kiosque_code'] ?? data['family_code'],
      aiTutorEnabled: data['ai_tutor_enabled'] ?? false,
    );
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? '',
      name: map['name'] ?? '',
      isActive: map['isActive'] ?? true,
      timezone: map['timezone'],
      kiosqueCode: map['kiosqueCode'],
      aiTutorEnabled: map['aiTutorEnabled'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'name': name,
      'isActive': isActive,
      'timezone': timezone,
      'kiosqueCode': kiosqueCode,
      'aiTutorEnabled': aiTutorEnabled,
    };
  }
}
