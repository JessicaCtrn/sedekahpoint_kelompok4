import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';
import '../services/theme_provider.dart';
import 'login_screen.dart';
import 'favorite_screen.dart';
import 'history_screen.dart';
import 'detail_screen.dart';

// untuk mengecek apakah waktu kegiatan postingan sudah berakhir
// menggunakan tanggalSelesai jika ada, fallback ke jamSelesai di hari dibuat
bool _isWaktuHabis(PostModel post) {
  try {
    final now = DateTime.now();
    // untuk postingan baru yang punya tanggalSelesai lengkap
    if (post.tanggalSelesai != null) {
      return now.isAfter(post.tanggalSelesai!);
    }
    // untuk postingan lama yang hanya punya jamSelesai (fallback)
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

// untuk menentukan apakah card postingan harus tampil abu-abu (nonaktif)
// nonaktif jika stok habis atau waktu kegiatan sudah lewat
bool _isInaktif(PostModel post) {
  return post.stokKuota <= 0 || _isWaktuHabis(post);
}

// untuk menampilkan halaman profil pengguna
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final PostService _postService = PostService();
  final ImagePicker _picker = ImagePicker();

  // untuk menyimpan data pengguna yang sedang login
  UserModel? _user;

  // untuk mengontrol mode edit profil aktif atau tidak
  bool _isEditing = false;

  // untuk menampilkan loading saat menyimpan profil
  bool _isLoading = false;

  // untuk menampilkan loading saat foto sedang diupload
  bool _isUploadingPhoto = false;

  // untuk menyimpan input nama dan nomor hp dari pengguna
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();

  // untuk menyimpan foto profil baru sebelum disimpan ke Firestore
  String? _newPhotoBase64;
  dynamic _newPhotoBytes;

  @override
  void initState() {
    super.initState();
    // untuk memuat data profil pengguna saat halaman pertama dibuka
    _loadUser();
  }

  // untuk mengambil data profil pengguna dari Firestore
  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final user = await _authService.getUserData(uid);
    if (user != null && mounted) {
      setState(() {
        _user = user;
        // untuk mengisi field form dengan data profil yang sudah ada
        _usernameController.text = user.username;
        _phoneController.text = user.phone;
      });
    }
  }

  // untuk membuka galeri dan memilih foto profil baru
  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 25,
      maxWidth: 200,
      maxHeight: 200,
    );
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final bytes = await picked.readAsBytes();
      final base64Str = base64Encode(bytes);
      final sizeKb = (bytes.length / 1024).toStringAsFixed(1);

      // untuk membatasi ukuran foto agar tidak melebihi batas Firestore
      if (base64Str.length > 500000) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Foto masih terlalu besar (${sizeKb}KB). Pilih foto lebih kecil.')),
          );
        }
        return;
      }

      setState(() {
        _newPhotoBytes = bytes;
        _newPhotoBase64 = base64Str;
      });

      // untuk langsung menyimpan foto ke Firestore tanpa perlu tekan simpan
      if (_user != null) {
        await _authService.updateUserProfile(
          uid: _user!.uid,
          photoUrl: base64Str,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Foto profil berhasil disimpan')),
        );
        _loadUser();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  // untuk menyimpan perubahan nama dan nomor hp ke Firestore
  Future<void> _saveProfile() async {
    if (_user == null) return;
    setState(() => _isLoading = true);
    try {
      await _authService.updateUserProfile(
        uid: _user!.uid,
        username: _usernameController.text.trim(),
        phone: _phoneController.text.trim(),
        // untuk mempertahankan foto lama jika tidak ada foto baru
        photoUrl: _newPhotoBase64 ?? _user!.photoUrl,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Profil berhasil diperbarui')));
        setState(() {
          _isEditing = false;
          _newPhotoBase64 = null;
          _newPhotoBytes = null;
        });
        _loadUser();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // untuk keluar dari akun dan kembali ke halaman login
  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  // untuk membangun widget avatar profil yang bisa diklik untuk ganti foto
  Widget _buildAvatar() {
    // untuk menentukan sumber gambar profil: bytes baru, URL, atau base64
    ImageProvider? imageProvider;
    if (_newPhotoBytes != null) {
      imageProvider = MemoryImage(_newPhotoBytes!);
    } else if (_user?.photoUrl != null && _user!.photoUrl!.isNotEmpty) {
      final photo = _user!.photoUrl!;
      if (photo.startsWith('http')) {
        imageProvider = NetworkImage(photo);
      } else {
        try {
          imageProvider = MemoryImage(base64Decode(photo));
        } catch (_) {
          imageProvider = null;
        }
      }
    }

    return GestureDetector(
      // untuk membuka galeri saat avatar diklik
      onTap: _pickPhoto,
      child: Stack(
        children: [
          // untuk menampilkan foto profil berbentuk lingkaran
          CircleAvatar(
            radius: 44,
            backgroundColor: Theme.of(context)
                .colorScheme
                .primary
                .withOpacity(0.1),
            backgroundImage: imageProvider,
            // untuk menampilkan ikon default jika tidak ada foto
            child: imageProvider == null
                ? Icon(Icons.person,
                    size: 44,
                    color: Theme.of(context).colorScheme.primary)
                : null,
          ),
          // untuk menampilkan ikon kamera di pojok kanan bawah avatar
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              // untuk menampilkan loading spinner saat foto sedang diupload
              child: _isUploadingPhoto
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.camera_alt,
                      color: Colors.white, size: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // untuk menampilkan bagian header profil (avatar, nama, stats)
              Container(
                color: cardColor,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // untuk menampilkan judul "Profile Saya" di tengah
                    // dan ikon pengaturan di pojok kanan menggunakan Stack
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // untuk judul halaman yang tepat di tengah layar
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            'Profile Saya',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        // untuk tombol pengaturan dark mode di pojok kanan atas
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            onPressed: () {
                              // untuk membuka dialog toggle dark mode
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  backgroundColor: theme.cardColor,
                                  title: Text('Pengaturan',
                                      style: TextStyle(
                                          color: theme
                                              .colorScheme.onSurface)),
                                  content: Row(
                                    children: [
                                      Text('Dark Mode',
                                          style: TextStyle(
                                              color: theme.colorScheme
                                                  .onSurface)),
                                      const Spacer(),
                                      Switch(
                                        value: themeProvider.isDarkMode,
                                        activeColor:
                                            theme.colorScheme.primary,
                                        onChanged: (v) async {
                                          themeProvider.toggleDarkMode(v);
                                          Navigator.pop(context);
                                          // untuk menyimpan preferensi tema ke Firestore
                                          if (_user != null) {
                                            await _authService
                                                .updateUserProfile(
                                                    uid: _user!.uid,
                                                    darkMode: v);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            icon: Icon(Icons.brightness_6_outlined,
                                color: theme.colorScheme.onSurface),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // untuk menampilkan avatar yang bisa diklik untuk ganti foto
                    _buildAvatar(),
                    const SizedBox(height: 10),

                    // untuk menampilkan nama pengguna
                    Text(_user?.username ?? '',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 2),

                    // untuk menampilkan lokasi pengguna
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14, color: Colors.grey),
                        SizedBox(width: 2),
                        Text('Sumatera Selatan, Palembang',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // untuk menampilkan statistik favorit, post, dan riwayat
                    StreamBuilder<List<PostModel>>(
                      stream: _postService.getUserFavorites(uid),
                      builder: (context, favSnap) {
                        return StreamBuilder<List<PostModel>>(
                          stream: _postService.getPosts(),
                          builder: (context, postSnap) {
                            // untuk menghitung jumlah favorit
                            final favCount =
                                (favSnap.data ?? []).length;

                            // untuk memfilter postingan milik user ini saja
                            final userPosts = (postSnap.data ?? [])
                                .where((p) => p.uid == uid)
                                .toList();
                            final postCount = userPosts.length;

                            // untuk menghitung riwayat kuota yang pernah diambil
                            final riwayatCount =
                                (postSnap.data ?? [])
                                    .where((p) => p.diambilOleh
                                        .contains(uid))
                                    .length;

                            return Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceEvenly,
                              children: [
                                // untuk membuka halaman Favorite
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const FavoriteScreen())),
                                  child: _statChip(Icons.favorite,
                                      '$favCount Favorite', Colors.red),
                                ),
                                // untuk membuka bottom sheet daftar postingan user
                                GestureDetector(
                                  onTap: () =>
                                      _showUserPosts(userPosts),
                                  child: _statChip(
                                      Icons.grid_view,
                                      '$postCount Post',
                                      theme.colorScheme.primary),
                                ),
                                // untuk membuka halaman Riwayat
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const HistoryScreen())),
                                  child: _statChip(Icons.history,
                                      '$riwayatCount Riwayat',
                                      Colors.blueGrey),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // untuk menampilkan form data profil (nama, hp, email, password)
              Container(
                color: cardColor,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // untuk field nama yang bisa diedit
                    _buildFormField('Nama', _usernameController,
                        enabled: _isEditing),
                    const SizedBox(height: 14),
                    // untuk field nomor hp yang bisa diedit
                    _buildFormField(
                        'No. Handphone', _phoneController,
                        enabled: _isEditing,
                        keyboardType: TextInputType.phone),
                    const SizedBox(height: 14),
                    // untuk field email yang tidak bisa diedit
                    _buildFormField(
                        'Email',
                        TextEditingController(
                            text: _user?.email ?? ''),
                        enabled: false),
                    const SizedBox(height: 14),
                    // untuk field password yang selalu tersembunyi
                    _buildFormField(
                        'Password',
                        TextEditingController(
                            text: '••••••••••••••'),
                        enabled: false,
                        obscure: true),
                    const SizedBox(height: 22),

                    // untuk tombol Edit Profil (muncul saat tidak sedang edit)
                    if (!_isEditing)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () =>
                              setState(() => _isEditing = true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFFE8A930),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                          ),
                          child: const Text('Edit Profil',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                        ),
                      )
                    else
                      // untuk tombol Batal dan Simpan (muncul saat mode edit aktif)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              // untuk membatalkan perubahan dan keluar dari mode edit
                              onPressed: () => setState(() {
                                _isEditing = false;
                                _newPhotoBase64 = null;
                                _newPhotoBytes = null;
                              }),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                    color:
                                        theme.colorScheme.primary),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                                padding:
                                    const EdgeInsets.symmetric(
                                        vertical: 13),
                              ),
                              child: Text('Batal',
                                  style: TextStyle(
                                      color: theme
                                          .colorScheme.primary)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              // untuk menyimpan perubahan profil ke Firestore
                              onPressed:
                                  _isLoading ? null : _saveProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    theme.colorScheme.primary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                                padding:
                                    const EdgeInsets.symmetric(
                                        vertical: 13),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2)
                                  : const Text('Simpan',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight:
                                              FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // untuk menampilkan opsi dark mode dan tombol keluar
              Container(
                color: cardColor,
                child: Column(
                  children: [
                    // untuk toggle dark mode dari halaman profil
                    ListTile(
                      leading: Icon(Icons.dark_mode_outlined,
                          color: theme.colorScheme.onSurface),
                      title: Text('Dark Mode',
                          style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface)),
                      trailing: Switch(
                        value: themeProvider.isDarkMode,
                        activeColor: theme.colorScheme.primary,
                        onChanged: (v) async {
                          themeProvider.toggleDarkMode(v);
                          // untuk menyimpan preferensi tema ke Firestore
                          if (_user != null) {
                            await _authService.updateUserProfile(
                                uid: _user!.uid, darkMode: v);
                          }
                        },
                      ),
                    ),
                    Divider(height: 0, color: theme.dividerColor),
                    // untuk tombol keluar dari akun
                    ListTile(
                      leading: const Icon(Icons.logout,
                          color: Colors.red),
                      title: const Text('Keluar',
                          style: TextStyle(
                              fontSize: 14, color: Colors.red)),
                      onTap: _logout,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // untuk menampilkan bottom sheet daftar postingan milik pengguna ini
  void _showUserPosts(List<PostModel> posts) {
    // untuk mengurutkan: postingan aktif di atas, nonaktif di bawah
    final sortedPosts = List<PostModel>.from(posts);
    sortedPosts.sort((a, b) {
      final aInaktif = _isInaktif(a) ? 1 : 0;
      final bInaktif = _isInaktif(b) ? 1 : 0;
      if (aInaktif != bInaktif) return aInaktif - bInaktif;
      return b.createdAt.compareTo(a.createdAt);
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              // untuk handle bar drag di atas bottom sheet
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              // untuk judul bottom sheet
              Text('Postingan Saya',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface)),
              Divider(color: Theme.of(context).dividerColor),
              Expanded(
                child: sortedPosts.isEmpty
                    ? const Center(
                        child: Text('Belum ada postingan',
                            style:
                                TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        controller: controller,
                        padding: const EdgeInsets.all(16),
                        itemCount: sortedPosts.length,
                        // untuk membangun satu item postingan
                        itemBuilder: (_, i) =>
                            _buildPostItem(sortedPosts[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // untuk membangun tampilan satu item postingan di bottom sheet
  Widget _buildPostItem(PostModel post) {
    final theme = Theme.of(context);
    final inaktif = _isInaktif(post);
    // untuk warna abu sesuai tema terang/gelap
    final abuColor = theme.brightness == Brightness.dark
        ? Colors.grey.shade800
        : Colors.grey.shade200;

    return GestureDetector(
      // untuk menonaktifkan klik jika postingan sudah lewat atau habis
      onTap: inaktif
          ? null
          : () {
              Navigator.pop(context);
              // untuk membuka halaman detail postingan
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => DetailScreen(post: post)));
            },
      child: Opacity(
        // untuk membuat item terlihat redup jika nonaktif
        opacity: inaktif ? 0.5 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            // untuk memberi warna abu jika nonaktif
            color: inaktif
                ? abuColor
                : theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              // untuk menampilkan thumbnail gambar postingan
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child:
                    _buildPostImage(post.imageUrl, 60, 60),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // untuk menampilkan nama kegiatan
                    Text(post.namaKegiatan,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color:
                                theme.colorScheme.onSurface)),
                    const SizedBox(height: 3),
                    // untuk menampilkan jenis bantuan
                    Text(post.jenisBantuan,
                        style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.primary)),
                    const SizedBox(height: 3),
                    // untuk menampilkan jam kegiatan
                    Text(
                        '${post.jamMulai} - ${post.jamSelesai} WIB',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey)),
                  ],
                ),
              ),
              // untuk menampilkan badge status sisa kuota atau status nonaktif
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: inaktif
                      ? Colors.grey
                      : (post.stokKuota <= 10
                          ? Colors.red.shade50
                          : theme.colorScheme.primary
                              .withOpacity(0.1)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  inaktif
                      ? (post.stokKuota <= 0
                          ? 'Habis'
                          : 'Lewat')
                      : 'Sisa ${post.stokKuota}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: inaktif
                          ? Colors.white
                          : (post.stokKuota <= 10
                              ? Colors.red
                              : theme.colorScheme.primary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // untuk membangun widget gambar thumbnail dari URL atau base64
  Widget _buildPostImage(String imageUrl, double w, double h) {
    if (imageUrl.isEmpty) return _photoPlaceholder(w, h);
    if (imageUrl.startsWith('http')) {
      return Image.network(imageUrl,
          width: w,
          height: h,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _photoPlaceholder(w, h));
    }
    try {
      return Image.memory(base64Decode(imageUrl),
          width: w,
          height: h,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _photoPlaceholder(w, h));
    } catch (_) {
      return _photoPlaceholder(w, h);
    }
  }

  // untuk menampilkan placeholder ikon masjid jika gambar tidak tersedia
  Widget _photoPlaceholder(double w, double h) {
    return Container(
      width: w,
      height: h,
      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      child: Icon(Icons.mosque,
          color: Theme.of(context).colorScheme.primary, size: 20),
    );
  }

  // untuk membangun chip statistik (Favorit, Post, Riwayat)
  Widget _statChip(IconData icon, String label, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // untuk membangun satu field form dengan label di atasnya
  Widget _buildFormField(
    String label,
    TextEditingController controller, {
    bool enabled = true,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // untuk menampilkan label di atas field
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        // untuk menampilkan input field dengan styling yang konsisten
        TextField(
          controller: controller,
          enabled: enabled,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            filled: true,
            // untuk membedakan warna latar field aktif dan nonaktif
            fillColor: enabled
                ? theme.inputDecorationTheme.fillColor ??
                    theme.colorScheme.surface
                : theme.disabledColor.withOpacity(0.1),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}