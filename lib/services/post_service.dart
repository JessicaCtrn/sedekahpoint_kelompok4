import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'notification_service.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // untuk menginisialisasi layanan notifikasi agar bisa dipanggil di dalam fungsi-fungsi di bawah
  final NotificationService _notifService = NotificationService();

  // ── POST ─────────────────────────────────────────────────

  Stream<List<PostModel>> getPosts() {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => PostModel.fromMap(d.data())).toList());
  }

  Stream<List<PostModel>> getUserFavorites(String uid) {
    return _firestore
        .collection('posts')
        .where('favoritedBy', arrayContains: uid)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => PostModel.fromMap(d.data())).toList());
  }

  Stream<List<PostModel>> getUserPosts(String uid) {
    return _firestore
        .collection('posts')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => PostModel.fromMap(d.data())).toList());
  }

  // untuk mengambil postingan yang sudah diambil oleh user
  Stream<List<PostModel>> getRiwayatPengambilan(String uid) {
    return _firestore
        .collection('posts')
        .where('diambilOleh', arrayContains: uid)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => PostModel.fromMap(d.data())).toList());
  }

  // untuk mengonversi XFile ke Base64 string, disimpan langsung ke Firestore
  Future<String> convertImageToBase64(XFile imageFile) async {
    final bytes = await imageFile.readAsBytes();
    return base64Encode(bytes);
  }

  // untuk membuat postingan baru dan memicu pengiriman notifikasi
  Future<void> createPost(PostModel post) async {
    // untuk menyimpan data postingan ke database
    await _firestore.collection('posts').doc(post.id).set(post.toMap()); 
    
    // untuk mengirim notifikasi ke diri sendiri
    await _notifService.notifyPostinganSaya(
      postId: post.id, 
      namaKegiatan: post.namaKegiatan
    );
    // untuk mengirim notifikasi ke semua pengguna lain di aplikasi
    await _notifService.notifyPostinganBaru(
      postId: post.id, 
      namaKegiatan: post.namaKegiatan, 
      posterUsername: post.username
    );
  }

  Future<void> toggleFavorite(String postId, String uid) async {
    final ref = _firestore.collection('posts').doc(postId);
    final snap = await ref.get();
    final List<dynamic> favoritedBy =
        (snap.data() as Map<String, dynamic>)['favoritedBy'] ?? [];

    if (favoritedBy.contains(uid)) {
      await ref.update({'favoritedBy': FieldValue.arrayRemove([uid])});
    } else {
      await ref.update({'favoritedBy': FieldValue.arrayUnion([uid])});
    }
  }

  // untuk mencatat UID user yang mengambil kuota
  Future<void> ambilKuota(String postId, String uid) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'sudahDiambil': FieldValue.increment(1),
        'diambilOleh': FieldValue.arrayUnion([uid]), // untuk menyimpan UID ke database
      });
    } catch (e) {
      print("Gagal ambil kuota: $e");
    }
  }

  // ── KOMENTAR ─────────────────────────────────────────────

  Stream<List<CommentModel>> getComments(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => CommentModel.fromMap(d.data())).toList());
  }

  // untuk menambahkan komentar dan mendeteksi apakah memicu notifikasi komentar biasa atau balasan
  Future<void> addComment(CommentModel comment) async {
    // untuk menyimpan data komentar ke database
    await _firestore
        .collection('posts')
        .doc(comment.postId)
        .collection('comments')
        .doc(comment.id)
        .set(comment.toMap());

    // untuk mendapatkan detail postingan asli dari database
    final postSnap = await _firestore.collection('posts').doc(comment.postId).get();
    if (postSnap.exists) {
      final postData = postSnap.data() as Map<String, dynamic>;
      final postOwnerUid = postData['uid'];
      final namaKegiatan = postData['namaKegiatan'];

      // untuk mengecek apakah komentar ini adalah balasan terhadap komentar pengguna lain
      if (comment.replyToId != null && comment.replyToId!.isNotEmpty) {
         final originalCommentSnap = await _firestore
            .collection('posts')
            .doc(comment.postId)
            .collection('comments')
            .doc(comment.replyToId)
            .get();

         if (originalCommentSnap.exists) {
            final originalUid = originalCommentSnap.data()?['uid'];
            // untuk mengirim notifikasi kepada pemilik komentar yang dibalas
            await _notifService.notifyBalasanKomentar(
                commentOwnerUid: originalUid, 
                postId: comment.postId, 
                replierUsername: comment.username
            );
         }
      } else {
        // untuk mengirim notifikasi komentar baru kepada pemilik postingan
        await _notifService.notifyKomentar(
          postOwnerUid: postOwnerUid,
          postId: comment.postId,
          namaKegiatan: namaKegiatan,
          commenterUsername: comment.username,
        );
      }
    }
  }

  // untuk menghapus komentar
  Future<void> deleteComment(String postId, String commentId) async {
    try {
      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .delete();
    } catch (e) {
      print("Gagal menghapus komentar: $e");
    }
  }

  // untuk menghapus postingan beserta seluruh komentarnya dan memicu notifikasi
  Future<void> deletePost(String postId) async {
    try {
      // untuk mengambil nama kegiatan terlebih dahulu untuk data notifikasi sebelum dihapus
      final snap = await _firestore.collection('posts').doc(postId).get();
      String namaKegiatan = 'Kegiatan';
      if (snap.exists) {
        namaKegiatan = snap.data()?['namaKegiatan'] ?? 'Kegiatan';
      }

      // untuk menghapus semua komentar di postingan terlebih dahulu
      final commentsQuery = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .get();
      for (var doc in commentsQuery.docs) {
        await doc.reference.delete();
      }
      
      // untuk menghapus postingan utama
      await _firestore.collection('posts').doc(postId).delete();

      // untuk mengirim notifikasi bahwa postingan berhasil dihapus
      if (snap.exists) {
        await _notifService.notifyHapusPostingan(namaKegiatan: namaKegiatan);
      }
    } catch (e) {
      print("Gagal menghapus postingan: $e");
    }
  }

  // untuk mengupdate postingan dan memicu notifikasi pembaruan
  Future<void> updatePost(PostModel post) async {
    try {
      await _firestore.collection('posts').doc(post.id).update(post.toMap());
      
      // untuk mengirim notifikasi ke diri sendiri bahwa postingan berhasil diedit
      await _notifService.notifyEditPostingan(
        postId: post.id, 
        namaKegiatan: post.namaKegiatan
      );
    } catch (e) {
      print("Gagal mengupdate postingan: $e");
    }
  }
}