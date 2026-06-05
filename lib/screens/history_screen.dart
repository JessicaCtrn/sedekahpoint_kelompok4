import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import 'detail_screen.dart';

// untuk mengecek apakah waktu kegiatan sudah berakhir menggunakan data tanggalSelesai atau jamSelesai
bool _isWaktuHabis(PostModel post) {
  try {
    final now = DateTime.now();
    if (post.tanggalSelesai != null) {
      return now.isAfter(post.tanggalSelesai!);
    }
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

// menentukan apakah kartu riwayat harus berwarna abu-abu karena stok habis atau waktu berakhir
bool _isInaktif(PostModel post) {
  return post.stokKuota <= 0 || _isWaktuHabis(post);
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // mengambil ID unik dari pengguna yang saat ini sedang login
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final postService = PostService();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(       // bilah menu di appbar
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(  // tombol ke profil
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface, size: 20),
        ),
        title: Text(
          'Riwayat Pengambilan',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<PostModel>>(
        stream: postService.getRiwayatPengambilan(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {    // untuk memunculkan loading animasi berputar saat sistem sedang menarik data
            return const Center(child: CircularProgressIndicator());
          }

          // untuk menampung seluruh daftar dokumen riwayat tanpa ada yang disembunyikan
          final posts = List<PostModel>.from(snapshot.data ?? []);

          // untuk mengurutkan susunan riwayat agar item kartu yang sudah habis/tutup otomatis dipindah ke paling bawah
          posts.sort((a, b) {
            final aInaktif = _isInaktif(a) ? 1 : 0;
            final bInaktif = _isInaktif(b) ? 1 : 0;
            if (aInaktif != bInaktif) return aInaktif - bInaktif;
            return b.createdAt.compareTo(a.createdAt);
          });

          if (posts.isEmpty) {
            // untuk memunculkan informasi layar kosong bergambar jika pengguna belum pernah mengambil kuota bantuan
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Belum ada riwayat', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  SizedBox(height: 4),
                  Text(
                    'Ambil kuota dari postingan untuk\nmuncul di sini',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            );
          }
          
          // untuk merender atau menyusun daftar kartu riwayat menjadi gulungan ke bawah (list)
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (_, i) => _HistoryCard(post: posts[i]),
          );
        },
      ),
    );
  }
}

// untuk membangun komponen visual satu buah kartu item riwayat pengambilan kuota
class _HistoryCard extends StatelessWidget {
  static const double _cardHeight = 135.0;
  static const double _imgWidth = 120.0;
  final PostModel post;

  const _HistoryCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inaktif = _isInaktif(post);
    final abuColor = theme.brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200;

    return GestureDetector(
      // untuk mematikan fungsi klik atau ketuk pada kartu apabila status riwayat kuota/waktunya sudah habis
      onTap: inaktif ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(post: post))),
      child: Opacity(
        // untuk memberikan efek transparansi agak redup sebesar 50% jika status kartu sudah inaktif
        opacity: inaktif ? 0.5 : 1.0,
        child: Container(
          height: _cardHeight,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            // untuk merubah latar belakang kartu menjadi warna abu-abu jika inaktif, atau warna normal jika masih aktif
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
              // untuk menampilkan bagian foto kegiatan di sisi sebelah kiri kartu
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                child: SizedBox(
                  width: _imgWidth,
                  height: _cardHeight,
                  child: _buildImage(post.imageUrl, _imgWidth, _cardHeight, context),
                ),
              ),
              // untuk menampilkan blok rincian teks informasi di sisi sebelah kanan kartu
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // untuk menampilkan nama kegiatan bantuan
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
                          const SizedBox(height: 2),
                          // untuk menampilkan info lokasi alamat dengan ikon pin peta
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  post.alamat.isNotEmpty ? post.alamat : post.lokasi,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          // untuk menampilkan info rincian jam operasional kegiatan
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 12, color: Colors.grey),
                              const SizedBox(width: 2),
                              Text(
                                '${post.jamMulai} - ${post.jamSelesai} WIB',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          // untuk menampilkan jenis bantuan bantuan makanan/sembako
                          Text(
                            'Jenis Bantuan: ${post.jenisBantuan}',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // untuk menampilkan label pemberitahuan teks merah tebal jika status postingan sudah inaktif
                      if (inaktif)
                        Text(
                          post.stokKuota <= 0 ? 'Kuota Habis' : 'Waktu Kegiatan Habis', 
                          style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
                        )
                      else
                        // untuk menampilkan badge hijau berlogo centang tanda sukses mengambil kuota bantuan
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 15, color: theme.colorScheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                'Sudah Mengambil',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
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

  // untuk memproses pemuatan file gambar baik yang berasal dari alamat URL internet maupun kode teks biner base64
  Widget _buildImage(String imageUrl, double w, double h, BuildContext context) {
    if (imageUrl.isEmpty) return _placeholder(w, h, context);
    if (imageUrl.startsWith('http')) {
      return Image.network(imageUrl, width: w, height: h, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder(w, h, context));
    }
    try {
      final bytes = base64Decode(imageUrl);
      return Image.memory(bytes, width: w, height: h, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, __, ___) => _placeholder(w, h, context));
    } catch (_) {
      return _placeholder(w, h, context);
    }
  }

  // untuk merender bentuk kotak warna berlogo gambar masjid apabila proses pemuatan gambar utama gagal dilakukan
  Widget _placeholder(double w, double h, BuildContext context) {
    return Container(
      width: w,
      height: h,
      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      child: Icon(Icons.mosque, color: Theme.of(context).colorScheme.primary, size: 36),
    );
  }
}