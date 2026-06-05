class UserModel {
  final String uid;
  final String username;
  final String phone;
  final String email;
  final String? photoUrl;
  final bool darkMode;

  UserModel({
    required this.uid,
    required this.username,
    required this.phone,
    required this.email,
    this.photoUrl,
    this.darkMode = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'phone': phone,
      'email': email,
      'photoUrl': photoUrl ?? '',
      'darkMode': darkMode,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      username: map['username'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'],
      darkMode: map['darkMode'] ?? false,
    );
  }

  UserModel copyWith({
    String? uid,
    String? username,
    String? phone,
    String? email,
    String? photoUrl,
    bool? darkMode,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      darkMode: darkMode ?? this.darkMode,
    );
  }
}
