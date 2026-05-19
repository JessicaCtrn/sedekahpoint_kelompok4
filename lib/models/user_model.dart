class UserModel {
  final String uid;
  final String username;
  final String phone;
  final String email;

  UserModel({
    required this.uid,
    required this.username,
    required this.phone,
    required this.email,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'phone': phone,
      'email': email,
    };
  }
}