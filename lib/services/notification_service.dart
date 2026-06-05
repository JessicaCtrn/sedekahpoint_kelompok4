import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// untuk mengelola seluruh pengiriman notifikasi ke dalam database Firestore
class NotificationService {
  final _firestore = FirebaseFirestore.instance;

  // untuk format dasar pengiriman data notifikasi ke database
  Future<void> _sendNotif({
    required String toUid,
    required String type,
    required String title,
    required String body,
    required String postId,
  }) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (toUid.isEmpty) return;

    await _firestore.collection('notifications').add({
      'toUid': toUid,
      'fromUid': currentUid,
      'type': type,
      'title': title,
      'body': body,
      'postId': postId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // untuk mengirim notifikasi ke diri sendiri saat berhasil membuat postingan
  Future<void> notifyPostinganSaya({
    required String postId,
    required String namaKegiatan,
  }) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUid.isEmpty) return;
    
    await _sendNotif(
      toUid: currentUid,
      type: 'my_post',
      title: 'Postingan Berhasil',
      body: 'Postingan "$namaKegiatan" berhasil diterbitkan.',
      postId: postId,
    );
  }

  // untuk mengirim notifikasi broadcast ke seluruh pengguna lain saat ada postingan baru
  Future<void> notifyPostinganBaru({
    required String postId,
    required String namaKegiatan,
    required String posterUsername,
  }) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    // untuk mengambil daftar semua pengguna yang ada di database
    final usersSnap = await _firestore.collection('users').get();
    
    for (final doc in usersSnap.docs) {
      final uid = doc.id;
      // untuk memastikan notifikasi ini tidak dikirim ke pembuat postingan itu sendiri
      if (uid == currentUid) continue;
      
      await _sendNotif(
        toUid: uid,
        type: 'new_post',
        title: 'Postingan Kegiatan Baru',
        body: '$posterUsername baru saja memposting "$namaKegiatan"',
        postId: postId,
      );
    }
  }

  // untuk mengirim notifikasi kepada pemilik postingan saat ada yang berkomentar
  Future<void> notifyKomentar({
    required String postOwnerUid,
    required String postId,
    required String namaKegiatan,
    required String commenterUsername,
  }) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    // untuk mencegah munculnya notifikasi jika pengguna mengomentari postingannya sendiri
    if (postOwnerUid == currentUid) return;

    await _sendNotif(
      toUid: postOwnerUid,
      type: 'comment',
      title: 'Komentar Baru',
      body: '$commenterUsername mengomentari postingan "$namaKegiatan"',
      postId: postId,
    );
  }

  // untuk mengirim notifikasi kepada pemilik komentar saat komentarnya dibalas
  Future<void> notifyBalasanKomentar({
    required String commentOwnerUid,
    required String postId,
    required String replierUsername,
  }) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    // untuk mencegah notifikasi jika pengguna membalas komentarnya sendiri
    if (commentOwnerUid == currentUid) return;

    await _sendNotif(
      toUid: commentOwnerUid,
      type: 'reply',
      title: 'Balasan Komentar',
      body: '$replierUsername membalas komentar kamu',
      postId: postId,
    );
  }

  // untuk mengirim notifikasi ke diri sendiri saat postingan berhasil diedit
  Future<void> notifyEditPostingan({
    required String postId,
    required String namaKegiatan,
  }) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUid.isEmpty) return;

    await _sendNotif(
      toUid: currentUid,
      type: 'edit_post',
      title: 'Postingan Diperbarui',
      body: 'Postingan "$namaKegiatan" berhasil diperbarui.',
      postId: postId,
    );
  }

  // untuk mengirim notifikasi ke diri sendiri saat postingan berhasil dihapus
  Future<void> notifyHapusPostingan({
    required String namaKegiatan,
  }) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUid.isEmpty) return;

    await _sendNotif(
      toUid: currentUid,
      type: 'delete_post',
      title: 'Postingan Dihapus',
      body: 'Postingan "$namaKegiatan" berhasil dihapus.',
      postId: '', // untuk mengosongkan ID karena postingan sudah tidak ada
    );
  }
}