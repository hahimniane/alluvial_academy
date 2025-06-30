import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String? email;
  final String? role;
  final String? name;
  final bool isActive;

  AppUser({
    required this.id,
    this.email,
    this.role,
    this.name,
    this.isActive = true,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AppUser(
      id: doc.id,
      email: data['e-mail'] ?? data['email'],
      role: data['user_type'] ?? data['role'],
      name: (data['first_name'] ?? '') + ' ' + (data['last_name'] ?? ''),
      isActive: data['is_active'] ?? true,
    );
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? '',
      name: map['name'] ?? '',
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'name': name,
      'isActive': isActive,
    };
  }
}
