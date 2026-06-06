import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sedekahpoint_kelompok4/models/post_model.dart';
import 'package:sedekahpoint_kelompok4/services/post_service.dart';
import 'package:sedekahpoint_kelompok4/services/location_service.dart';
import 'package:sedekahpoint_kelompok4/services/theme_provider.dart';
import 'package:sedekahpoint_kelompok4/services/auth_service.dart';
import 'package:sedekahpoint_kelompok4/screens/detail_screen.dart';
import 'package:sedekahpoint_kelompok4/screens/favorite_screen.dart';
import 'package:sedekahpoint_kelompok4/screens/notification_screen.dart';
import 'package:sedekahpoint_kelompok4/screens/post_screen.dart';
import 'package:sedekahpoint_kelompok4/screens/search_screen.dart';
import 'package:sedekahpoint_kelompok4/screens/profile_screen.dart';

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

String _labelStatus(PostModel post) {
  if (post.stokKuota <= 0) return 'Kuota Habis';
  if (_isWaktuHabis(post)) return 'Waktu Habis';
  return 'Sisa: ${post.stokKuota}/${post.totalKuota}';
}

Stream<int> _getUnreadNotifCount() {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  if (uid.isEmpty) return Stream.value(0);
  return FirebaseFirestore.instance
      .collection('notifications')
      .where('toUid', isEqualTo: uid)
      .snapshots()
      .map(
        (snap) => snap.docs
            .where((d) => d.data()['isRead'] == false)
            .length,
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PostService _postService = PostService();
  final LocationService _locationService = LocationService();
  final AuthService _authService = AuthService();
  int _currentIndex = 0;
  final ValueNotifier<bool> _showMenuNotifier = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  @override
  void dispose() {
    _showMenuNotifier.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    await _locationService.getCurrentPosition();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _HomeBody(
        postService: _postService,
        authService: _authService,
        showMenuNotifier: _showMenuNotifier,
        onGoToProfile: () => setState(() => _currentIndex = 4),
        onGoToSearch: () => setState(() => _currentIndex = 1),
      ),
      const SearchScreen(),
      const PostScreen(),
      const FavoriteScreen(),
      const ProfileScreen(),
    ];
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF157A5B),
        unselectedItemColor: Colors.grey,
        backgroundColor: Theme.of(context).cardColor,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box_outlined),
            label: 'Post',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline),
            label: 'Favorite',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  final PostService postService;
  final AuthService authService;
  final ValueNotifier<bool> showMenuNotifier;
  final VoidCallback onGoToProfile;
  final VoidCallback onGoToSearch;

  const _HomeBody({
    required this.postService,
    required this.authService,
    required this.showMenuNotifier,
    required this.onGoToProfile,
    required this.onGoToSearch,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _AppBar(showMenuNotifier: showMenuNotifier),
              ),
              SliverToBoxAdapter(
                child: _SearchBar(onTap: onGoToSearch),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'Segera Habis',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleMedium?.color,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _SegeraHabisList(postService: postService),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Postingan Terbaru',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.titleMedium?.color,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showSemuaPostingan(context, postService),
                        child: const Text(
                          'Lihat Semua',
                          style: TextStyle(color: Color(0xFF157A5B)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _LatestList(postService: postService),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Text(
                    'Jenis Bantuan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleMedium?.color,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _JenisBantuan(postService: postService),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 20),
              ),
            ],
          ),
          ValueListenableBuilder<bool>(
            valueListenable: showMenuNotifier,
            builder: (context, showMenu, _) {
              if (!showMenu) return const SizedBox.shrink();
              return Stack(
                children: [
                  GestureDetector(
                    onTap: () => showMenuNotifier.value = false,
                    behavior: HitTestBehavior.translucent,
                    child: Container(color: Colors.transparent),
                  ),
                  _DropdownMenu(
                    authService: authService,
                    onClose: () => showMenuNotifier.value = false,
                    onGoToProfile: onGoToProfile,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showSemuaPostingan(BuildContext context, PostService postService) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        final cardColor = Theme.of(sheetCtx).cardColor;
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (ctx, scrollController) => Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF157A5B).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.access_time_filled,
                          color: Color(0xFF157A5B),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Semua Postingan Terbaru',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),
                Expanded(
                  child: StreamBuilder<List<PostModel>>(
                    stream: postService.getPosts(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF157A5B),
                          ),
                        );
                      }
                      final all = List<PostModel>.from(snapshot.data!);
                      all.sort((a, b) {
                        final aInaktif = _isInaktif(a) ? 1 : 0;
                        final bInaktif = _isInaktif(b) ? 1 : 0;
                        if (aInaktif != bInaktif) return aInaktif - bInaktif;
                        return b.createdAt.compareTo(a.createdAt);
                      });
                      if (all.isEmpty) {
                        return const Center(
                          child: Text(
                            'Belum ada postingan',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }
                      return ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: all.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _LokasiListTile(
                          key: ValueKey(all[i].id),
                          post: all[i],
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DetailScreen(post: all[i]),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LokasiListTile extends StatelessWidget {
  final PostModel post;
  final VoidCallback onTap;

  const _LokasiListTile({
    super.key,
    required this.post,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inaktif = _isInaktif(post);
    final Color sisaColor = inaktif
        ? Colors.grey
        : (post.stokKuota <= 10 ? Colors.red : const Color(0xFF157A5B));
    final abuColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey.shade800
        : Colors.grey.shade200;

    return GestureDetector(
      onTap: inaktif ? null : onTap,
      child: Opacity(
        opacity: inaktif ? 0.5 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: inaktif ? abuColor : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
                child: _img(post.imageUrl, 100, 100),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.namaKegiatan,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: Color(0xFF157A5B),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              post.alamat.isNotEmpty ? post.alamat : post.lokasi,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${post.jamMulai} - ${post.jamSelesai} WIB',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: sisaColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _labelStatus(post),
                            style: TextStyle(
                              fontSize: 11,
                              color: sisaColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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

  Widget _img(String url, double w, double h) {
    if (url.isEmpty) return _ph(w, h);
    if (url.startsWith('http')) {
      return Image.network(
        url,
        width: w,
        height: h,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _ph(w, h),
      );
    }
    try {
      return Image.memory(
        base64Decode(url),
        width: w,
        height: h,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _ph(w, h),
      );
    } catch (_) {
      return _ph(w, h);
    }
  }

  Widget _ph(double w, double h) {
    return Container(
      width: w,
      height: h,
      color: const Color(0xFFE0F2EE),
      child: const Icon(
        Icons.mosque,
        color: Color(0xFF157A5B),
        size: 36,
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  final ValueNotifier<bool> showMenuNotifier;

  const _AppBar({required this.showMenuNotifier});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
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
                const Padding(
                  padding: EdgeInsets.only(left: 7),
                  child: Text(
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
          GestureDetector(
            onTap: () => showMenuNotifier.value = !showMenuNotifier.value,
            child: StreamBuilder<int>(
              stream: _getUnreadNotifCount(),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      Icons.menu,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFF157A5B),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).cardColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final VoidCallback? onTap;

  const _SearchBar({this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: theme.cardColor,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: AbsorbPointer(
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 13,
              ),
              decoration: const InputDecoration(
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey,
                  size: 20,
                ),
                hintText: 'Cari lokasi pembagian makanan',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownMenu extends StatelessWidget {
  final AuthService authService;
  final VoidCallback onClose;
  final VoidCallback onGoToProfile;

  const _DropdownMenu({
    required this.authService,
    required this.onClose,
    required this.onGoToProfile,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Positioned(
      top: 60,
      right: 16,
      child: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).cardColor,
        child: Container(
          width: 220,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<int>(
                stream: _getUnreadNotifCount(),
                builder: (context, snapshot) {
                  final unreadCount = snapshot.data ?? 0;
                  return _menuItem(
                    context: context,
                    icon: Icons.notifications_none_outlined,
                    iconColor: Colors.orange,
                    label: 'Notifikasi',
                    subtitle: 'Info balasan & post baru',
                    showBadge: unreadCount > 0,
                    onTap: () {
                      onClose();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationScreen(),
                        ),
                      );
                    },
                  );
                },
              ),
              Divider(height: 0, color: Colors.grey.shade200),
              _menuItem(
                context: context,
                icon: Icons.privacy_tip_outlined,
                iconColor: Colors.blue,
                label: 'Kebijakan Privasi',
                subtitle: 'Data & privasi Anda',
                onTap: () {
                  onClose();
                  _showKebijakanPrivasi(context);
                },
              ),
              Divider(height: 0, color: Colors.grey.shade200),
              _menuItemSwitch(
                icon: Icons.dark_mode_outlined,
                iconColor: Colors.indigo,
                label: 'Dark Mode',
                subtitle: 'Ubah tema gelap',
                value: themeProvider.isDarkMode,
                onChanged: (v) => themeProvider.toggleDarkMode(v),
              ),
              Divider(height: 0, color: Colors.grey.shade200),
              _menuItem(
                context: context,
                icon: Icons.person_outline,
                iconColor: Colors.purple,
                label: 'Profile Saya',
                subtitle: 'Lihat & edit profil',
                onTap: () {
                  onClose();
                  onGoToProfile();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    bool showBadge = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                if (showBadge)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF157A5B),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).cardColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuItemSwitch({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF157A5B),
            ),
          ),
        ],
      ),
    );
  }

  void _showKebijakanPrivasi(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final cardColor = Theme.of(sheetContext).cardColor;
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) => Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.privacy_tip_outlined,
                          color: Colors.blue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Kebijakan Privasi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    children: const [
                      _PrivasiSection(
                        icon: Icons.person_outline,
                        iconColor: Color(0xFF157A5B),
                        title: '1. Data yang Dikumpulkan',
                        content:
                            'Kami mengumpulkan nama pengguna, nomor telepon, alamat email, dan data lokasi GPS untuk menampilkan postingan terdekat di sekitar Anda.',
                      ),
                      SizedBox(height: 16),
                      _PrivasiSection(
                        icon: Icons.storage_outlined,
                        iconColor: Colors.orange,
                        title: '2. Penggunaan Data',
                        content:
                            'Data digunakan untuk menampilkan konten relevan, mengelola akun Anda, serta menghubungkan donatur dengan penerima manfaat di sekitar lokasi Anda.',
                      ),
                      SizedBox(height: 16),
                      _PrivasiSection(
                        icon: Icons.lock_outline,
                        iconColor: Colors.blue,
                        title: '3. Keamanan Data',
                        content:
                            'Data disimpan aman menggunakan Firebase Cloud Firestore. Kami tidak menjual atau membagikan data pribadi Anda kepada pihak ketiga.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PrivasiSection extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String content;

  const _PrivasiSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegeraHabisList extends StatelessWidget {
  final PostService postService;

  const _SegeraHabisList({required this.postService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PostModel>>(
      stream: postService.getPosts(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 180,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        final posts = snapshot.data!
            .where((p) => p.stokKuota <= 10 && p.stokKuota > 0 && !_isWaktuHabis(p))
            .take(5)
            .toList();
            
        if (posts.isEmpty) {
          return const SizedBox(
            height: 100,
            child: Center(
              child: Text(
                'Tidak ada data',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }
        return SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: posts.length,
            itemBuilder: (_, i) => _SegeraCard(
              key: ValueKey(posts[i].id),
              post: posts[i],
            ),
          ),
        );
      },
    );
  }
}

class _LatestList extends StatelessWidget {
  final PostService postService;

  const _LatestList({required this.postService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PostModel>>(
      stream: postService.getPosts(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 60);
        final all = List<PostModel>.from(snapshot.data!);
        final visible = all.toList();
        visible.sort((a, b) {
          final aInaktif = _isInaktif(a) ? 1 : 0;
          final bInaktif = _isInaktif(b) ? 1 : 0;
          if (aInaktif != bInaktif) return aInaktif - bInaktif;
          return b.createdAt.compareTo(a.createdAt);
        });
        final limitedList = visible.take(8).toList();
        if (limitedList.isEmpty) return const SizedBox();
        return SizedBox(
          height: 260,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            itemCount: limitedList.length,
            itemBuilder: (_, i) => _NearbyCard(
              key: ValueKey(limitedList[i].id),
              post: limitedList[i],
            ),
          ),
        );
      },
    );
  }
}

class _JenisBantuan extends StatelessWidget {
  final PostService postService;

  const _JenisBantuan({required this.postService});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> jenis = [
      {'label': 'Nasi Gratis', 'asset': 'assets/rice.jpg', 'filter': 'Nasi Gratis'},
      {'label': 'Minuman', 'asset': 'assets/minuman.jpg', 'filter': 'Minuman'},
      {'label': 'Sembako', 'asset': 'assets/sembako.jpg', 'filter': 'Sembako Gratis'},
      {'label': 'Roti/Snack', 'asset': 'assets/roti.jpg', 'filter': 'Roti/Snack'},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: jenis.map((item) {
          return Expanded(
            child: GestureDetector(
              onTap: () => _showPostinganByJenis(
                context,
                item['label'],
                item['filter'],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipOval(
                    child: Image.asset(
                      item['asset'],
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 90,
                        height: 90,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFE0F2EE),
                        ),
                        child: const Icon(
                          Icons.fastfood,
                          size: 40,
                          color: Color(0xFF157A5B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item['label'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showPostinganByJenis(
      BuildContext context, String label, String filter) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        final cardColor = Theme.of(sheetCtx).cardColor;
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (ctx, scrollController) => Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF157A5B).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.fastfood,
                          color: Color(0xFF157A5B),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),
                Expanded(
                  child: StreamBuilder<List<PostModel>>(
                    stream: postService.getPosts(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF157A5B),
                          ),
                        );
                      }
                      final posts = snapshot.data!
                          .where((p) =>
                              p.jenisBantuan == filter && !_isInaktif(p))
                          .toList();
                      if (posts.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 56,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Belum ada postingan "$label"',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Coba lagi nanti',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: posts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _LokasiListTile(
                          key: ValueKey(posts[i].id),
                          post: posts[i],
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DetailScreen(post: posts[i]),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SegeraCard extends StatelessWidget {
  final PostModel post;

  const _SegeraCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetailScreen(post: post),
        ),
      ),
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 12, bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _img(post.imageUrl, 220, 200),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.75),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.namaKegiatan,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${post.jamMulai} - ${post.jamSelesai} WIB',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Sisa: ${post.stokKuota}/${post.totalKuota}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _img(String url, double w, double h) {
    if (url.isEmpty) return _ph(w, h);
    if (url.startsWith('http')) {
      return Image.network(
        url,
        width: w,
        height: h,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _ph(w, h),
      );
    }
    try {
      return Image.memory(
        base64Decode(url),
        width: w,
        height: h,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _ph(w, h),
      );
    } catch (_) {
      return _ph(w, h);
    }
  }

  Widget _ph(double w, double h) {
    return Container(
      width: w,
      height: h,
      color: const Color(0xFFE0F2EE),
      child: const Icon(
        Icons.mosque,
        color: Color(0xFF157A5B),
        size: 40,
      ),
    );
  }
}

class _NearbyCard extends StatelessWidget {
  final PostModel post;

  const _NearbyCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final inaktif = _isInaktif(post);
    final isBaru = !inaktif &&
        DateTime.now().difference(post.createdAt).inHours < 5;
    final Color sisaColor = inaktif
        ? Colors.grey
        : (post.stokKuota <= 10 ? Colors.red : const Color(0xFF157A5B));
    final abuColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey.shade800
        : Colors.grey.shade200;

    return GestureDetector(
      onTap: inaktif
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailScreen(post: post),
                ),
              ),
      child: Opacity(
        opacity: inaktif ? 0.5 : 1.0,
        child: Container(
          width: 200,
          margin: const EdgeInsets.only(right: 12, bottom: 4),
          decoration: BoxDecoration(
            color: inaktif ? abuColor : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: _img(post.imageUrl, 200, 150),
                  ),
                  if (isBaru)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF157A5B),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Baru',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (inaktif)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade600,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          post.stokKuota <= 0 ? 'Kuota Habis' : 'Waktu Habis',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        post.namaKegiatan,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: Color(0xFF157A5B),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              post.alamat.isNotEmpty ? post.alamat : post.lokasi,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${post.jamMulai} - ${post.jamSelesai} WIB',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          _labelStatus(post),
                          style: TextStyle(
                            fontSize: 12,
                            color: sisaColor,
                            fontWeight: FontWeight.bold,
                          ),
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

  Widget _img(String url, double w, double h) {
    if (url.isEmpty) return _ph(w, h);
    if (url.startsWith('http')) {
      return Image.network(
        url,
        width: w,
        height: h,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _ph(w, h),
      );
    }
    try {
      return Image.memory(
        base64Decode(url),
        width: w,
        height: h,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _ph(w, h),
      );
    } catch (_) {
      return _ph(w, h);
    }
  }

  Widget _ph(double w, double h) {
    return Container(
      width: w,
      height: h,
      color: const Color(0xFFE0F2EE),
      child: const Icon(
        Icons.mosque,
        color: Color(0xFF157A5B),
        size: 40,
      ),
    );
  }
}