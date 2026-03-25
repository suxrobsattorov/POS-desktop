class UserModel {
  final int id;
  final String username;
  final String fullName;
  final String role;

  const UserModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      username: json['username'] as String,
      fullName: json['fullName'] as String,
      role: json['role'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'fullName': fullName,
    'role': role,
  };

  bool get isAdmin => role == 'SUPER_ADMIN' || role == 'ADMIN';
}
