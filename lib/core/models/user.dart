class AppUser {
  final String id;
  final String email;
  final String role;
  final String name;
  final bool isActive;

  AppUser({
    required this.id,
    required this.email,
    required this.role,
    required this.name,
    this.isActive = true,
  });

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
