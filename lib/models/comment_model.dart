import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String postId;
  final String uid;
  final String username;
  final String? userPhotoUrl;
  final String text;
  final DateTime createdAt;
  final String? replyToId;
  final String? replyToUsername;

  CommentModel({
    required this.id,
    required this.postId,
    required this.uid,
    required this.username,
    this.userPhotoUrl,
    required this.text,
    required this.createdAt,
    this.replyToId,
    this.replyToUsername,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'postId': postId,
      'uid': uid,
      'username': username,
      'userPhotoUrl': userPhotoUrl ?? '',
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'replyToId': replyToId ?? '',
      'replyToUsername': replyToUsername ?? '',
    };
  }

  factory CommentModel.fromMap(Map<String, dynamic> map) {
    return CommentModel(
      id: map['id'] ?? '',
      postId: map['postId'] ?? '',
      uid: map['uid'] ?? '',
      username: map['username'] ?? '',
      userPhotoUrl: map['userPhotoUrl'],
      text: map['text'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      replyToId: map['replyToId'],
      replyToUsername: map['replyToUsername'],
    );
  }
}
