import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../services/post_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'post_screen.dart';

class DetailScreen extends StatefulWidget {
  final PostModel post;
  const DetailScreen({super.key, required this.post});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final PostService _postService = PostService();
  final AuthService _authService = AuthService();

  final TextEditingController _commentController =
      TextEditingController();

  // simpan id dan username komentar yang sedang dibalas
  String? _replyToId;
  String? _replyToUsername;
  bool _isFavorited = false;
  bool _sudahAmbil = false;
  String? _currentUid;
  // simpan data postingan yang bisa diperbarui secara realtime
  late PostModel _post;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _currentUid = FirebaseAuth.instance.currentUser?.uid;

    // cek apakah postingan sudah difavoritkan oleh pengguna
    if (_currentUid != null) {
      _isFavorited =
          widget.post.favoritedBy.contains(_currentUid);
      if (widget.post.diambilOleh.contains(_currentUid)) {    // cek pengguna sudah ambil kuota/belum
        _sudahAmbil = true;
      }
    }
  }

  @override
  void dispose() {
    // membersihkan controller komentar saat widget dihancurkan
    _commentController.dispose();
    super.dispose();
  }

  // toggle favorit postingan (tambah/hapus dari daftar favorit)
  void _toggleFavorite() async {
    if (_currentUid == null) return;
    await _postService.toggleFavorite(_post.id, _currentUid!);
    setState(() => _isFavorited = !_isFavorited);
  }

  void _ambilKuota() async {    // ambil kuota dan komentar otomatis
    if (_currentUid == null) return;

    await _postService.ambilKuota(_post.id, _currentUid!);
    setState(() => _sudahAmbil = true);

    final userData = await _authService.getUserData(_currentUid!);  // ambil nama pengguna untuk komentar otomatis

    // membuat komentar otomatis saat kuota berhasil diambil
    final autoComment = CommentModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      postId: _post.id,
      uid: _currentUid!,
      username: userData?.username ?? 'Anonim',
      userPhotoUrl: userData?.photoUrl ?? '',
      text: '✅ Sudah Mengambil',
      createdAt: DateTime.now(),
      replyToId: null,
      replyToUsername: null,
    );
    await _postService.addComment(autoComment);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Berhasil mengambil kuota!')));
    }
  }

  // membuka Google Maps berdasarkan koordinat GPS postingan
  void _openMaps() async {
    final url =
        'https://www.google.com/maps/search/?api=1&query=${_post.latitude},${_post.longitude}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;
    if (_currentUid == null) return;

    
    final userData = await _authService.getUserData(_currentUid!);  // mengambil data pengguna terbaru termasuk foto profil
    final comment = CommentModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      postId: _post.id,
      uid: _currentUid!,
      username: userData?.username ?? 'Anonim',
      userPhotoUrl: userData?.photoUrl ?? '',
      text: _commentController.text.trim(),
      createdAt: DateTime.now(),
      replyToId: _replyToId,
      replyToUsername: _replyToUsername,
    );
    await _postService.addComment(comment);

    // mengirim notifikasi ke pemilik postingan saat ada komentar baru
    // notifikasi tidak dikirim jika yang berkomentar adalah pemilik postingan itu sendiri
    await NotificationService().notifyKomentar(
      postOwnerUid: _post.uid,
      postId: _post.id,
      namaKegiatan: _post.namaKegiatan,
      commenterUsername: userData?.username ?? 'Anonim',
    );

    _commentController.clear();
    // mereset state balasan setelah komentar terkirim
    setState(() {
      _replyToId = null;
      _replyToUsername = null;
    });
  }

  void _confirmDeleteComment(String commentId) {  // dialog konfirm sblm apus komentar
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Hapus Komentar',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text(
            'Apakah kamu yakin ingin menghapus komentar ini?'),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal',
                style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              // untuk menghapus komentar dari Firestore
              await _postService.deleteComment(
                  _post.id, commentId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Komentar berhasil dihapus')),
                );
              }
            },
            child: const Text('Hapus',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePost() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Hapus Postingan',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text(
            'Apakah kamu yakin ingin menghapus postingan ini? Tindakan ini tidak dapat dibatalkan.'),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal',
                style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              // untuk menghapus postingan beserta komentarnya dari Firestore
              await _postService.deletePost(_post.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Postingan berhasil dihapus')),
                );
                Navigator.pop(context);   // kembali ke halaman sebelumnya setelah menghapus
              }
            },
            child: const Text('Hapus',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // untuk membangun widget gambar postingan dari URL atau base64
  Widget _buildPostImage() {
    final imageUrl = _post.imageUrl;
    if (imageUrl.isEmpty) return _placeholderImage();
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => _placeholderImage(),
      );
    }
    try {
      final bytes = base64Decode(imageUrl);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _placeholderImage(),
      );
    } catch (_) {
      return _placeholderImage();
    }
  }

  // menampilkan placeholder ikon masjid jika gambar tidak tersedia
  Widget _placeholderImage() {
    return Container(
      color: const Color(0xFFE0F2EE),
      height: 220,
      child: const Center(
        child: Icon(Icons.mosque,
            color: Color(0xFF157A5B), size: 60),
      ),
    );
  }

  Widget _buildAvatar(String? photoUrl, {double radius = 18}) {
    final double size = radius * 2;

    Widget fallback = CircleAvatar(   // icon default kalau tidak ada foto
      radius: radius,
      backgroundColor: const Color(0xFFE0F2EE),
      child: Icon(Icons.person,
          color: const Color(0xFF157A5B), size: radius),
    );

    if (photoUrl == null || photoUrl.trim().isEmpty)
      return fallback;

    if (photoUrl.startsWith('http') ||    // menampilkan foto dari URL internet
        photoUrl.startsWith('https')) {
      return ClipOval(
        child: Image.network(
          photoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        ),
      );
    }

    try {   // menampilkan foto dari string base64
      String cleanBase64 = photoUrl;
      if (photoUrl.contains(',')) {   // membersihkan prefix data URL jika ada
        cleanBase64 = photoUrl.split(',').last;
      }
      final bytes = base64Decode(cleanBase64);
      return ClipOval(
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => fallback,
        ),
      );
    } catch (_) {
      return fallback;
    }
  }

  // mengubah selisih waktu menjadi teks relatif seperti "2j" atau "1h"
  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}j';
    return '${diff.inDays}h';
  }

  // mengubah angka hari (1-7)
  String _namaHari(int weekday) {
    const hari = [
      'Senin', 'Selasa', 'Rabu', 'Kamis',
      'Jumat', 'Sabtu', 'Minggu'
    ];
    return hari[(weekday - 1).clamp(0, 6)];
  }

  String _namaBulan(int month) {
    const bulan = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return bulan[(month - 1).clamp(0, 11)];
  }

  // memformat DateTime menjadi teks tanggal yang mudah dibaca
  // contoh hasil: "Jumat, 30 Mei 2025"
  String _formatTanggal(DateTime? dt) {
    if (dt == null) return '';
    return '${_namaHari(dt.weekday)}, ${dt.day} ${_namaBulan(dt.month)} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: StreamBuilder<List<PostModel>>(
        stream: _postService.getPosts(),
        builder: (context, snapshot) {
          // memperbarui data postingan secara realtime dari Firestore
          if (snapshot.hasData) {
            final updated = snapshot.data!
                .where((p) => p.id == _post.id)
                .toList();
            if (updated.isNotEmpty) {
              _post = updated.first;
              if (_currentUid != null) {    // memperbarui status sudah ambil secara realtime
                _sudahAmbil =
                    _post.diambilOleh.contains(_currentUid);
              }
            }
          }
          return CustomScrollView(
            slivers: [
              // menampilkan AppBar yang tetap terlihat saat scroll
              SliverAppBar(
                pinned: true,
                backgroundColor:
                    theme.appBarTheme.backgroundColor,
                surfaceTintColor:
                    theme.appBarTheme.backgroundColor,
                elevation: 1,
                shadowColor: Colors.black.withOpacity(0.2),
                // tombol kembali ke halaman sebelumnya
                leading: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back_ios_new,
                      color: theme.colorScheme.onSurface,
                      size: 20),
                ),
                title: Text('Detail',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                centerTitle: true,
                actions: [
                  if (_currentUid == _post.uid)   // tombol edit (pembuat postingan)
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PostScreen(postToEdit: _post),
                          ),
                        );
                      },
                      icon: Icon(Icons.edit,
                          color: theme.colorScheme.onSurface,
                          size: 24),
                    ),
                  if (_currentUid == _post.uid)   // tombol hapus postingan (pemilik)
                    IconButton(
                      onPressed: _confirmDeletePost,
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red, size: 24),
                    ),
                  // tombol favorit di pojok kanan AppBar
                  IconButton(
                    onPressed: _toggleFavorite,
                    icon: Icon(
                      _isFavorited
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: _isFavorited
                          ? Colors.red
                          : theme.colorScheme.onSurface,
                      size: 26,
                    ),
                  ),
                ],
              ),

              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // menampilkan gambar postingan dengan rasio 16:9
                    Container(
                      color: const Color(0xFFE0F2EE),
                      width: double.infinity,
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: _buildPostImage(),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(_post.namaKegiatan,
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: theme
                                      .colorScheme.onSurface)),
                          const SizedBox(height: 10),

                          Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: Color(0xFF157A5B)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _post.alamat.isNotEmpty
                                      ? _post.alamat
                                      : _post.lokasi,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color:
                                          Color(0xFF157A5B)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // untuk menampilkan koordinat GPS yang bisa diklik
                          // agar pengguna bisa membuka lokasi di Google Maps
                          GestureDetector(
                            onTap: _openMaps,
                            child: Row(
                              children: [
                                Icon(Icons.map_outlined,
                                    size: 13,
                                    color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _post.lokasi,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                        decoration:
                                            TextDecoration
                                                .none),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // card jadwal kegiatan: hari, tanggal dan jam berlangsung
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E3A2F)
                                  : const Color(0xFFE8F5E9),
                              borderRadius:
                                  BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF157A5B)
                                    .withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                        Icons.event_available,
                                        size: 16,
                                        color:
                                            Color(0xFF157A5B)),
                                    SizedBox(width: 6),
                                    Text(
                                      'Jadwal Kegiatan',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight:
                                              FontWeight.bold,
                                          color: Color(
                                              0xFF157A5B)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // menampilkan hari dan tanggal kegiatan
                                // menggunakan tanggalMulai jika ada, fallback ke createdAt
                                Row(
                                  children: [
                                    const Icon(
                                        Icons.calendar_today,
                                        size: 14,
                                        color:
                                            Color(0xFF157A5B)),
                                    const SizedBox(width: 6),
                                    Text(
                                      _post.tanggalMulai != null
                                          ? _formatTanggal(
                                              _post.tanggalMulai)
                                          : _formatTanggal(
                                              _post.createdAt),
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight:
                                              FontWeight.w600,
                                          color: theme
                                              .colorScheme
                                              .onSurface),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // menampilkan jam mulai sampai jam selesai
                                Row(
                                  children: [
                                    const Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color:
                                            Color(0xFF157A5B)),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_post.jamMulai} - ${_post.jamSelesai} WIB',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight:
                                              FontWeight.w600,
                                          color: theme
                                              .colorScheme
                                              .onSurface),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          Container(    // badge jenis bantuan
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E3A2F)
                                  : const Color(0xFFE0F2EE),
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            child: Text(
                                'Jenis Bantuan: ${_post.jenisBantuan}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF157A5B),
                                    fontWeight:
                                        FontWeight.w500)),
                          ),
                          const SizedBox(height: 20),

                          Container(    // card informasi kuota bantuan
                            width: double.infinity,
                            padding:
                                const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius:
                                  BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black
                                        .withOpacity(0.06),
                                    blurRadius: 8,
                                    offset:
                                        const Offset(0, 2))
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(    // tampilkan total kuota yang disediakan
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .spaceBetween,
                                  children: [
                                    Text('Total Kuota:',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color:
                                                Colors.grey[600])),
                                    Text(
                                        _post.totalKuota
                                            .toString(),
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight:
                                                FontWeight.bold,
                                            color: theme
                                                .colorScheme
                                                .onSurface)),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                Row(    // tampilkan jumlah yang sudah diambil
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .spaceBetween,
                                  children: [
                                    Text('Sudah Diambil',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: theme
                                                .colorScheme
                                                .onSurface)),
                                    Text(
                                        _post.sudahDiambil
                                            .toString(),
                                        style: TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                            fontSize: 13,
                                            color: theme
                                                .colorScheme
                                                .onSurface)),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // progress bar hijau (sudah diambil)
                                ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(6),
                                  child:
                                      LinearProgressIndicator(
                                    value: _post.totalKuota > 0
                                        ? _post.sudahDiambil /
                                            _post.totalKuota
                                        : 0,
                                    minHeight: 10,
                                    backgroundColor: isDark
                                        ? Colors.grey[700]
                                        : Colors.grey.shade200,
                                    valueColor:
                                        const AlwaysStoppedAnimation<
                                                Color>(
                                            Color(0xFF157A5B)),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .spaceBetween,
                                  children: [
                                    Text('Stok Kuota',    // sisa stok kuota
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: theme
                                                .colorScheme
                                                .onSurface)),
                                    Container(
                                      padding: const EdgeInsets
                                          .symmetric(
                                          horizontal: 10,
                                          vertical: 4),
                                      decoration:
                                          BoxDecoration(
                                        color: _post.stokKuota <=
                                                10
                                            ? Colors.red.shade50
                                            : isDark
                                                ? const Color(
                                                    0xFF1E3A2F)
                                                : const Color(
                                                    0xFFE0F2EE),
                                        borderRadius:
                                            BorderRadius
                                                .circular(8),
                                      ),
                                      child: Text(
                                        _post.stokKuota
                                            .toString(),
                                        style: TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                          fontSize: 13,
                                          color: _post
                                                      .stokKuota <=
                                                  10
                                              ? Colors.red
                                              : const Color(
                                                  0xFF157A5B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // progress bar oranye (sisa stok)
                                ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(6),
                                  child:
                                      LinearProgressIndicator(
                                    value: _post.totalKuota > 0
                                        ? _post.stokKuota /
                                            _post.totalKuota
                                        : 0,
                                    minHeight: 10,
                                    backgroundColor: isDark
                                        ? Colors.grey[700]
                                        : Colors.grey.shade200,
                                    valueColor:
                                        AlwaysStoppedAnimation<
                                            Color>(
                                      _post.stokKuota <= 10
                                          ? Colors.red
                                          : Colors.orange,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // tombol ambil kuota menjadi abu dan nonaktif jika sudah diambil atau stok habis
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: (_sudahAmbil ||
                                            _post.stokKuota ==
                                                0)
                                        ? null
                                        : _ambilKuota,
                                    icon: Icon(
                                      _sudahAmbil
                                          ? Icons.check_circle
                                          : Icons
                                              .check_circle_outline,
                                      color: Colors.white,
                                    ),
                                    label: Text(
                                      _sudahAmbil
                                          ? 'Sudah Mengambil'
                                          : _post.stokKuota ==
                                                  0
                                              ? 'Kuota Habis'
                                              : 'Ambil Sekarang',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight:
                                              FontWeight.bold),
                                    ),
                                    style: ElevatedButton
                                        .styleFrom(
                                      backgroundColor:
                                          (_sudahAmbil ||
                                                  _post.stokKuota ==
                                                      0)
                                              ? Colors.grey
                                              : const Color(
                                                  0xFF157A5B),
                                      shape:
                                          RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius
                                                      .circular(
                                                          12)),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Divider(
                              color: isDark
                                  ? Colors.grey[700]
                                  : null),

                          Text('Komentar',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: theme
                                      .colorScheme.onSurface)),
                          const SizedBox(height: 8),

                          StreamBuilder<List<CommentModel>>(    // daftar komentar realtime
                            stream: _postService
                                .getComments(_post.id),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                    child:
                                        CircularProgressIndicator());
                              }
                              final comments =
                                  snapshot.data!;
                              if (comments.isEmpty) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          vertical: 12),
                                  child: Text(
                                      'Belum ada komentar',
                                      style: TextStyle(
                                          color:
                                              Colors.grey[500])),
                                );
                              }
                              return Column(
                                children: comments
                                    .map((c) =>
                                        _buildCommentTile(c))
                                    .toList(),
                              );
                            },
                          ),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),

      // input komentar yang selalu terlihat di bawah layar
      bottomSheet: Container(
        color: theme.appBarTheme.backgroundColor ??
            Colors.white,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom:
              MediaQuery.of(context).viewInsets.bottom + 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyToUsername != null)   // info membalas komentar siapa
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E3A2F)
                      : const Color(0xFFE0F2EE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                          'Membalas @$_replyToUsername',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF157A5B))),
                    ),
                    // batal mode balas komentar
                    GestureDetector(
                      onTap: () => setState(() {
                        _replyToId = null;
                        _replyToUsername = null;
                      }),
                      child: Icon(Icons.close,
                          size: 16, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),

            // field input teks dan tombol kirim komentar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText:
                          'Tulis komentarmu disini...',
                      hintStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500]),
                      filled: true,
                      fillColor:
                          theme.scaffoldBackgroundColor,
                      contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // untuk tombol kirim komentar
                GestureDetector(
                  onTap: _submitComment,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF157A5B),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentTile(CommentModel comment) {    // tampilan satu tile komentar
    // untuk mendeteksi komentar otomatis "Sudah Mengambil"
    // agar ditampilkan dengan bubble hijau berbeda
    final bool isSudahMengambil =
        comment.text == '✅ Sudah Mengambil';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(comment.userPhotoUrl, radius: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(comment.username,    // nama dan waktu komentar
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color:
                                theme.colorScheme.onSurface)),
                    const SizedBox(width: 6),
                    Text(
                      _timeAgo(comment.createdAt),
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500]),
                    ),
                  ],
                ),

                if (comment.replyToUsername != null &&
                    comment.replyToUsername!.isNotEmpty)
                  Text('@${comment.replyToUsername}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF157A5B))),
                const SizedBox(height: 4),

                if (isSudahMengambil)   // bubble khusus komen "sudah mengambil"
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E3A2F)
                          : const Color(0xFFE8F5E9),
                      borderRadius:
                          BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF157A5B)
                              .withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            color: Color(0xFF157A5B),
                            size: 16),
                        SizedBox(width: 6),
                        Text('Sudah Mengambil',
                            style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF157A5B),
                                fontWeight:
                                    FontWeight.w600)),
                      ],
                    ),
                  )
                else
                  // bubble komentar
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius:
                          BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black
                                .withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1))
                      ],
                    ),
                    child: Text(comment.text,
                        style: TextStyle(
                            fontSize: 13,
                            color:
                                theme.colorScheme.onSurface)),
                  ),

                const SizedBox(height: 6),

                Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() {
                        _replyToId = comment.id;
                        _replyToUsername = comment.username;
                      }),
                      child: Text('Balas',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500)),
                    ),
                    if (comment.uid == _currentUid) ...[    // tombol hapus komentar milik sendiri
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () =>
                            _confirmDeleteComment(comment.id),
                        child: const Text('Hapus',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.red,
                                fontWeight:
                                    FontWeight.w500)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}