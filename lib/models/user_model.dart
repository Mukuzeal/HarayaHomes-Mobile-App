class UserModel {
  final int id;
  final String fname;
  final String lname;
  final String email;
  final String role;

  UserModel({
    required this.id,
    required this.fname,
    required this.lname,
    required this.email,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      fname: json['fname'] ?? '',
      lname: json['lname'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'buyer',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fname': fname,
    'lname': lname,
    'email': email,
    'role': role,
  };
}
