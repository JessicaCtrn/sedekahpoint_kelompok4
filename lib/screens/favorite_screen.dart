import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import 'detail_screen.dart';

// untuk mengecek apakah waktu kegiatan sudah berakhir
// menggunakan tanggalSelesai jika ada, fallback ke jamSelesai di hari dibuat
bool _isWaktuHabis(PostModel post) {
  try {
    final now = DateTime.now();
    // untuk membandingkan postingan baru yang punya tanggalSelesai lengkap
    if (post.tanggalSelesai != null) {
      return now.isAfter(post.tanggalSelesai!);
    }
    // untuk membandingkan postingan lama yang hanya punya jamSelesai
    final parts = post.jamSelesai.split(':');
    if (parts.length < 2) return false;
    final jamInt = int.tryParse(parts[0]) ?? 0;
    final menitInt = int.tryParse(parts[1]) ?? 0;
    final selesaiDiHariDibuat = DateTime(
      post.createdAt.year,
      post.createdAt.month,
      post.createdAt.day,
      jamInt,
      menitInt,
    );
    return now.isAfter(selesaiDiHariDibuat);
  } catch (_) {
    return false;
  }
}

// untuk menentukan apakah card harus tampil abu-abu (nonaktif)
bool _isInaktif(PostModel post) {
  return post.stokKuota <= 0 || _isWaktuHabis(post);
}

// untuk menampilkan daftar postingan yang difavoritkan
class FavoriteScreen extends StatelessWidget {
  const FavoriteScreen({super.key});

  // untuk mengatur ukuran tinggi dan lebar gambar card
  static const double _cardHeight = 130.0;
  static const double _imgWidth = 120.0;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final postService = PostService();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ??
            theme.colorScheme.surface,
        elevation: 0,
        title: Text(
          'Favorite',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<PostModel>>(
        // untuk mendengarkan data favorit secara real-time dari database
        stream: postService.getUserFavorites(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // untuk memuat seluruh data favorit tanpa ada yang dihapus/disembunyikan
          final posts = List<PostModel>.from(snapshot.data ?? []);

          // untuk mengurutkan daftar agar kartu yang sudah habis/abu-abu berada di paling bawah
          posts.sort((a, b) {
            final aInaktif = _isInaktif(a) ? 1 : 0;
            final bInaktif = _isInaktif(b) ? 1 : 0;
            if (aInaktif != bInaktif) return aInaktif - bInaktif;
            return b.createdAt.compareTo(a.createdAt);
          });

          if (posts.isEmpty) {
            // untuk menampilkan layar kosong jika belum ada postingan yang difavoritkan
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.favorite_border,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Belum ada favorit',
                      style: TextStyle(
                          color: Colors.grey, fontSize: 16)),
                  SizedBox(height: 4),
                  Text(
                    'Tandai postingan sebagai favorit\ndari layar detail',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            // untuk memanggil dan membangun widget kartu favorit
            itemBuilder: (_, i) => _buildFavoriteCard(context, posts[i]),
          );
        },
      ),
    );
  }

  // untuk membangun tampilan satu kartu postingan favorit
  Widget _buildFavoriteCard(BuildContext context, PostModel post) {
    final theme = Theme.of(context);
    final inaktif = _isInaktif(post);

    // untuk menyesuaikan warna latar kartu menjadi abu-abu sesuai tema terang/gelap
    final abuColor = theme.brightness == Brightness.dark
        ? Colors.grey.shade800
        : Colors.grey.shade200;

    return GestureDetector(
      // untuk mematikan fungsi klik jika waktu/kuota postingan sudah habis
      onTap: inaktif
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => DetailScreen(post: post)),
              ),
      child: Opacity(
        // untuk membuat tampilan kartu sedikit transparan/redup jika inaktif
        opacity: inaktif ? 0.5 : 1.0,
        child: Container(
          height: _cardHeight,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            // untuk menerapkan warna abu-abu jika inaktif, atau warna normal jika aktif
            color: inaktif ? abuColor : theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // untuk menaruh gambar di sebelah kiri kartu
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16)),
                child: SizedBox(
                  width: _imgWidth,
                  height: _cardHeight,
                  child: _buildImage(post.imageUrl, context),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // untuk teks nama kegiatan
                      Text(
                        post.namaKegiatan,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),

                      // untuk teks lokasi dengan ikon peta
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 13,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              post.alamat.isNotEmpty
                                  ? post.alamat
                                  : post.lokasi,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.primary),
                            ),
                          ),
                        ],
                      ),

                      // untuk teks durasi waktu kegiatan
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '${post.jamMulai} - ${post.jamSelesai} WIB',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),

                      // untuk teks jenis bantuan
                      Text(
                        'Jenis Bantuan: ${post.jenisBantuan}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      // untuk memunculkan teks merah yang ukurannya sudah diperbesar saat postingan inaktif
                      if (inaktif)
                        Text(
                          post.stokKuota <= 0
                              ? 'Kuota Habis'
                              : 'Waktu Kegiatan Habis',
                          style: const TextStyle(
                              fontSize: 12, // diperbesar
                              color: Colors.red,
                              fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // untuk membangun widget gambar
  Widget _buildImage(String imageUrl, BuildContext context) {
    if (imageUrl.isEmpty) return _placeholder(context);
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        width: _imgWidth,
        height: _cardHeight,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(context),
      );
    }
    try {
      final bytes = base64Decode(imageUrl);
      return Image.memory(
        bytes,
        width: _imgWidth,
        height: _cardHeight,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _placeholder(context),
      );
    } catch (_) {
      return _placeholder(context);
    }
  }

  // untuk menampilkan ikon kotak abu-abu jika gagal memuat gambar
  Widget _placeholder(BuildContext context) {
    return Container(
      width: _imgWidth,
      height: _cardHeight,
      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      child: Icon(Icons.mosque,
          color: Theme.of(context).colorScheme.primary, size: 36),
    );
  }
}