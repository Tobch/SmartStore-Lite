class UserModel {
  final String id;
  final String name;
  final String email;
  final String role; // 'Manager' or 'Staff'
  final String? defaultLocationId;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.defaultLocationId,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      id: documentId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'Staff',
      defaultLocationId: map['defaultLocationId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'defaultLocationId': defaultLocationId,
    };
  }
}