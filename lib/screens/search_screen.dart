import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sedekahpoint_kelompok4/models/post_model.dart';
import 'package:sedekahpoint_kelompok4/services/post_service.dart';
import 'package:sedekahpoint_kelompok4/screens/detail_screen.dart';

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

bool _isInaktif(PostModel post) {
  return post.stokKuota <= 0 || _isWaktuHabis(post);
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final PostService _postService = PostService();
  final TextEditingController _searchController = TextEditingController();

  String _query = '';
  String _selectedFilter = 'Semua';
  final List<String> _filters = [
    'Semua',
    'Nasi Gratis',
    'Jumat Berkah',
    'Sembako Gratis',
    'Masjid Terdekat',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: theme.cardColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.asset(
                          'assets/Logo APK.png',
                          height: 40,
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.only(left: 7),
                          child: const Text(
                            'Berbagi kebaikan setiap hari',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _query = v),
                        style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 13),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search,
                              color: Colors.grey, size: 20),
                          hintText: 'Cari lokasi pembagian makanan',
                          hintStyle: TextStyle(
                              fontSize: 13, color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 0, 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _filters.map((f) {
                          final selected = _selectedFilter == f;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedFilter = f),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFF157A5B)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFF157A5B)
                                      : Colors.grey.shade500,
                                ),
                              ),
                              child: Text(
                                f,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: selected
                                      ? Colors.white
                                      : theme.colorScheme.onSurface,
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<PostModel>>(
                stream: _postService.getPosts(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF157A5B)));
                  }

                  final now = DateTime.now();
                  var posts = snapshot.data!.where((p) {
                    if (_isWaktuHabis(p)) return false;
                    if (p.stokKuota <= 0) {
                      return now.difference(p.createdAt).inHours < 24;
                    }
                    return true;
                  }).toList();
                  if (_query.isNotEmpty) {
                    posts = posts
                        .where((p) =>
                            p.namaKegiatan
                                .toLowerCase()
                                .contains(_query.toLowerCase()) ||
                            p.lokasi
                                .toLowerCase()
                                .contains(_query.toLowerCase()) ||
                            p.alamat
                                .toLowerCase()
                                .contains(_query.toLowerCase()))
                        .toList();
                  }
                  if (_selectedFilter != 'Semua') {
                    if (_selectedFilter == 'Masjid Terdekat') {
                      posts = posts
                          .where((p) =>
                              p.namaKegiatan
                                  .toLowerCase()
                                  .contains('masjid') ||
                              p.alamat
                                  .toLowerCase()
                                  .contains('masjid') ||
                              p.lokasi
                                  .toLowerCase()
                                  .contains('masjid'))
                          .toList();
                    } else {
                      posts = posts
                          .where((p) =>
                              p.jenisBantuan == _selectedFilter)
                          .toList();
                    }
                  }
                  if (posts.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off,
                              size: 48,
                              color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            _selectedFilter == 'Masjid Terdekat'
                                ? 'Tidak ada masjid ditemukan'
                                : 'Tidak ada hasil',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: posts.length,
                    itemBuilder: (_, i) => _SearchCard(
                      key: ValueKey(posts[i].id),
                      post: posts[i],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _SearchCard extends StatelessWidget {
  final PostModel post;
  const _SearchCard({super.key, required this.post});
  static const double _cardHeight = 110.0;
  static const double _imgWidth = 110.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool inaktif = _isInaktif(post);
    final bool isLow = post.stokKuota <= 10 && post.stokKuota > 0;
    final Color sisaColor = inaktif
        ? Colors.grey
        : (isLow ? Colors.red : const Color(0xFF157A5B));
    final Color sisaBgColor = inaktif
        ? Colors.grey.withOpacity(0.1)
        : (isLow
            ? Colors.red.withOpacity(0.1)
            : const Color(0xFF157A5B).withOpacity(0.1));
    final Color abuColor = theme.brightness == Brightness.dark
        ? Colors.grey.shade800
        : Colors.grey.shade200;

    return GestureDetector(
      onTap: inaktif
          ? null
          : () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => DetailScreen(post: post))),
      child: Opacity(
        opacity: inaktif ? 0.55 : 1.0,
        child: Container(
          height: _cardHeight,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: inaktif ? abuColor : theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(14)),
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              post.namaKegiatan,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: sisaBgColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              inaktif
                                  ? (post.stokKuota <= 0
                                      ? 'Habis'
                                      : 'Tutup')
                                  : 'Sisa: ${post.stokKuota}',
                              style: TextStyle(
                                fontSize: 11,
                                color: sisaColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 13,
                              color: Color(0xFF157A5B)),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              post.alamat.isNotEmpty
                                  ? post.alamat
                                  : post.lokasi,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 12, color: Colors.grey),
                          const SizedBox(width: 3),
                          Text(
                            '${post.jamMulai} - ${post.jamSelesai} WIB',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                      Text(
                        'Jenis Bantuan: ${post.jenisBantuan}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF157A5B),
                          fontWeight: FontWeight.w500,
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
  Widget _buildImage(String imageUrl, BuildContext context) {
    if (imageUrl.isEmpty) return _placeholder(context);
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        width: _imgWidth,
        height: _cardHeight,
        fit: BoxFit.cover,
        gaplessPlayback: true,
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
  Widget _placeholder(BuildContext context) {
    return Container(
      width: _imgWidth,
      height: _cardHeight,
      color: const Color(0xFF157A5B).withOpacity(0.1),
      child: const Icon(Icons.mosque,
          color: Color(0xFF157A5B), size: 30),
    );
  }
}