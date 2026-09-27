class UserModel {
  final String id;
  final String email;
  final String fullName;
  final int role; // 0 = Admin, 1 = User
  final String token;
  final String? accountNumber;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.token,
    this.accountNumber,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['userId'] ?? json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? '',
      role: json['role'] is int ? json['role'] : (json['role'] == 'Admin' ? 0 : 1),
      token: json['token'] ?? '',
      accountNumber: json['accountNumber'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': id,
      'email': email,
      'fullName': fullName,
      'role': role,
      'token': token,
      'accountNumber': accountNumber,
    };
  }
}
