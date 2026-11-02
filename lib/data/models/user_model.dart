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
      defaultLocationId: map['defaultLocationId'] ?? map['default_location_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'defaultLocationId': defaultLocationId,
    };
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'default_location_id': defaultLocationId,
    };
  }
}
