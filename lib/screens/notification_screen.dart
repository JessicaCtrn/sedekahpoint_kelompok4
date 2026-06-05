import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// untuk menyimpan struktur data satu notifikasi
class NotificationModel {
  final String id;
  final String type;
  final String title;
  final String body;
  final String postId;
  final DateTime createdAt;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.postId,
    required this.createdAt,
    required this.isRead,
  });

  // untuk membaca data notifikasi dari database Firestore dan mengubahnya menjadi objek
  factory NotificationModel.fromMap(
      String id, Map<String, dynamic> map) {
    return NotificationModel(
      id: id,
      type: map['type'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      postId: map['postId'] ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: map['isRead'] ?? false,
    );
  }
}

// untuk menampilkan daftar notifikasi pengguna secara real-time
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});
  @override
  State<NotificationScreen> createState() =>
      _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  // untuk mendapatkan daftar notifikasi milik user dan diurutkan secara manual
  // agar terhindar dari error "Composite Index" Firebase
  Stream<List<NotificationModel>> _getNotifications() {
    return _firestore
        .collection('notifications')
        .where('toUid', isEqualTo: _currentUid)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => NotificationModel.fromMap(d.id, d.data()))
              .toList();
          
          // untuk mengurutkan notifikasi dari yang paling baru ke paling lama di dalam aplikasi
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // untuk menandai satu pesan notifikasi menjadi sudah dibaca
  Future<void> _markAsRead(String notifId) async {
    await _firestore
        .collection('notifications')
        .doc(notifId)
        .update({'isRead': true});
  }

  // untuk menandai semua notifikasi menjadi sudah dibaca sekaligus
  Future<void> _markAllAsRead(
      List<NotificationModel> notifs) async {
    final batch = _firestore.batch();
    for (final n in notifs.where((n) => !n.isRead)) {
      batch.update(
        _firestore.collection('notifications').doc(n.id),
        {'isRead': true},
      );
    }
    await batch.commit();
  }

  // untuk mengubah waktu menjadi teks ramah pengguna (contoh: 2 menit lalu)
  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
    if (diff.inDays < 1) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  // untuk menentukan ikon yang pas sesuai tipe notifikasi
  IconData _getIcon(String type) {
    switch (type) {
      case 'comment':
        return Icons.comment_outlined;
      case 'reply':
        return Icons.reply_outlined;
      case 'new_post':
        return Icons.campaign_outlined;
      case 'my_post':
        return Icons.check_circle_outline;
      case 'edit_post':
        return Icons.edit_outlined;
      case 'delete_post':
        return Icons.delete_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  // untuk menentukan warna ikon sesuai tipe notifikasi
  Color _getIconColor(String type) {
    switch (type) {
      case 'comment':
      case 'reply':
        return const Color(0xFF157A5B); // Hijau khas aplikasi
      case 'new_post':
        return Colors.orange;
      case 'my_post':
      case 'edit_post':
        return Colors.blue;
      case 'delete_post':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(       // untuk membangun bilah navigasi bagian atas (App Bar)
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? theme.cardColor,
        elevation: 0.5,
        // untuk memposisikan tombol kembali di pojok kiri atas
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: theme.iconTheme.color, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifikasi',
          style: TextStyle(
            color: theme.textTheme.titleLarge?.color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        // untuk menampilkan tombol Baca Semua di sebelah kanan atas jika ada pesan baru
        actions: [
          StreamBuilder<List<NotificationModel>>(
            stream: _getNotifications(),
            builder: (context, snapshot) {
              final notifs = snapshot.data ?? [];
              final adaYangBelumDibaca =          // untuk mengecek apakah masih ada notifikasi yang statusnya belum dibaca
                  notifs.any((n) => !n.isRead);
              if (!adaYangBelumDibaca) return const SizedBox();   // untuk menyembunyikan tombol "Baca Semua" jika semua notifikasi sudah terbaca
              return TextButton(      // untuk menampilkan tombol "Baca Semua"
                onPressed: () => _markAllAsRead(notifs),
                child: const Text(
                  'Baca Semua',
                  style: TextStyle(
                      color: Color(0xFF157A5B), fontSize: 13),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        // untuk menampilkan data langsung saat ada aktivitas notifikasi baru
        stream: _getNotifications(),
        builder: (context, snapshot) {
          // untuk memunculkan pesan error di layar jika ada masalah dengan database/izin Firebase
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Terjadi Kesalahan:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          // untuk memunculkan indikator berputar saat aplikasi sedang menunggu balasan data dari database
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF157A5B)));
          }
          final notifs = snapshot.data ?? [];
          if (notifs.isEmpty) {
            // untuk menampilkan layar informasi bahwa notifikasi sedang kosong
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.notifications_off_outlined,
                      size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Belum ada notifikasi',
                      style: TextStyle(
                          color: Colors.grey, fontSize: 16)),
                  SizedBox(height: 8),
                  Text(
                    'Pemberitahuan komentar dan postingan baru\nakan muncul di sini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(    // untuk menyusun daftar notifikasi menjadi urutan ke bawah (list)
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifs.length,
            separatorBuilder: (_, __) =>
                Divider(height: 0, color: theme.dividerColor),
            // untuk membangun blok tampilan dari setiap pesan notifikasi
            itemBuilder: (_, i) =>        // untuk membangun desain satu baris notifikasi
                _buildNotifTile(context, notifs[i]),
          );
        },
      ),
    );
  }

  // untuk merender bentuk satu baris notifikasi
  Widget _buildNotifTile(
      BuildContext context, NotificationModel notif) {
    final theme = Theme.of(context);
    final iconColor = _getIconColor(notif.type);
    return InkWell(
      // untuk menandai pesan menjadi sudah dibaca saat disentuh
      onTap: () => _markAsRead(notif.id),
      child: Container(
        color: notif.isRead
            ? Colors.transparent
            // untuk memberi penanda warna hijau samar pada pesan yang belum dibaca
            : const Color(0xFF157A5B).withOpacity(0.06),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // untuk memunculkan ikon bulat sesuai kategori notifikasi
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_getIcon(notif.type),
                  color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // untuk judul notifikasi
                  Text(
                    notif.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: notif.isRead
                          ? FontWeight.normal
                          : FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  // untuk rincian pesan notifikasi
                  Text(
                    notif.body,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // untuk durasi notifikasi terkirim
                  Text(
                    _timeAgo(notif.createdAt),
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.primary
                            .withOpacity(0.7)),
                  ),
                ],
              ),
            ),
            // untuk memunculkan titik hijau kecil sebagai penanda bahwa pesan ini baru
            if (!notif.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4, left: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF157A5B),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}