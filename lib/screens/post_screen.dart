import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import 'home_screen.dart';

class PostScreen extends StatefulWidget {
  final PostModel? postToEdit;
  const PostScreen({super.key, this.postToEdit});
  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final PostService _postService = PostService();
  final AuthService _authService = AuthService();
  final LocationService _locationService = LocationService();
  final ImagePicker _picker = ImagePicker();

  // untuk menyimpan teks yang diisi pengguna
  final _namaController = TextEditingController();
  final _alamatController = TextEditingController();
  final _porsiController = TextEditingController();
  final _jamMulaiController = TextEditingController();
  final _jamSelesaiController = TextEditingController();

  // untuk menyimpan gambar yang dipilih
  XFile? _imageFile;
  Uint8List? _imageBytes;

  // untuk menyimpan pilihan jenis bantuan
  String _selectedJenis = 'Nasi Gratis';

  // untuk menyimpan koordinat GPS
  double? _lat;
  double? _lng;

  // untuk mengontrol loading state tombol posting dan GPS
  bool _isLoading = false;
  bool _isLoadingLocation = false;

  // untuk menyimpan tanggal kegiatan yang dipilih pengguna
  DateTime? _selectedDate;

  // untuk daftar pilihan jenis bantuan di dropdown
  final List<String> _jenisList = [
    'Nasi Gratis',
    'Jumat Berkah',
    'Sembako Gratis',
    'Minuman',
    'Roti/Snack',
    'Lainnya',
  ];

  // untuk tracking apakah sedang dalam mode edit
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    // untuk load data postingan jika sedang di mode edit
    if (widget.postToEdit != null) {
      _isEditMode = true;
      final post = widget.postToEdit!;
      _namaController.text = post.namaKegiatan;
      _alamatController.text = post.alamat;
      _porsiController.text = post.jumlahPorsi.toString();
      _jamMulaiController.text = post.jamMulai;
      _jamSelesaiController.text = post.jamSelesai;
      _selectedDate = post.tanggalMulai ?? post.createdAt;
      _lat = post.latitude;
      _lng = post.longitude;
      _selectedJenis = post.jenisBantuan;
      // untuk menggunakan gambar yang sudah ada
      _imageFile = null;
      // menyimpan base64 image untuk ditampilkan
      if (post.imageUrl.isNotEmpty) {
        try {
          _imageBytes = base64Decode(post.imageUrl);
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    // untuk membersihkan controller saat widget dihancurkan
    _namaController.dispose();
    _alamatController.dispose();
    _porsiController.dispose();
    _jamMulaiController.dispose();
    _jamSelesaiController.dispose();
    super.dispose();
  }

  // untuk membuka galeri dan memilih foto kegiatan
  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageFile = picked;
        _imageBytes = bytes;
      });
    }
  }

  // untuk membuka date picker dan menyimpan tanggal yang dipilih
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      // untuk membatasi pilihan tanggal mulai dari hari ini
      firstDate: now,
      // untuk membatasi pilihan tanggal sampai 30 hari ke depan
      lastDate: now.add(const Duration(days: 30)),
      builder: (context, child) {
        // untuk menyesuaikan warna date picker dengan tema aplikasi
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFF157A5B),
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  // untuk mengambil koordinat GPS dari perangkat
  Future<void> _getLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final pos = await _locationService.getCurrentPosition();
      if (pos == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Gagal mendapatkan lokasi. Pastikan GPS aktif.')),
          );
        }
        return;
      }
      if (mounted) {
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Koordinat GPS berhasil didapatkan')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  // untuk memvalidasi format waktu agar maksimal 23:59 dan mencegah angka aneh seperti 25:00
  bool _isFormatJamValid(String time) {
    final regex = RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$');
    return regex.hasMatch(time);
  }

  // untuk memvalidasi semua field dan menyimpan postingan ke Firestore
  Future<void> _submitPost() async {
    // untuk memastikan semua field wajib sudah diisi sebelum submit
    if (_namaController.text.isEmpty ||
        _alamatController.text.isEmpty ||
        _porsiController.text.isEmpty ||
        _jamMulaiController.text.isEmpty ||
        _jamSelesaiController.text.isEmpty ||
        _selectedDate == null ||
        _lat == null ||
        _lng == null ||
        (_imageFile == null && !_isEditMode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Harap lengkapi semua field termasuk tanggal dan GPS')),
      );
      return;
    }

    // untuk memunculkan peringatan jika format jam yang diketik melebihi batas 24 jam
    if (!_isFormatJamValid(_jamMulaiController.text.trim()) ||
        !_isFormatJamValid(_jamSelesaiController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Format jam salah! Gunakan format 24 jam (contoh: 13:00, maksimal 23:59)')),
      );
      return;
    }

    final porsi = int.tryParse(_porsiController.text) ?? 0;
    if (porsi <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Jumlah porsi tidak valid! Harus lebih dari 0.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final userData = await _authService.getUserData(uid);

      // untuk mengubah gambar menjadi string base64 agar bisa disimpan di Firestore
      // atau gunakan gambar yang sudah ada jika dalam mode edit dan tidak ganti gambar
      String imageBase64;
      if (_imageFile != null) {
        imageBase64 = await _postService.convertImageToBase64(_imageFile!);
      } else if (_isEditMode) {
        imageBase64 = widget.postToEdit!.imageUrl;
      } else {
        imageBase64 = '';
      }
      
      // untuk menggabungkan tanggal yang dipilih dengan jam mulai/selesai
      // sehingga bisa dibandingkan dengan waktu sekarang secara akurat
      final jamMulaiParts = _jamMulaiController.text.trim().split(':');
      final jamSelesaiParts =
          _jamSelesaiController.text.trim().split(':');

      final DateTime tanggalMulai = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        jamMulaiParts.length >= 2
            ? int.tryParse(jamMulaiParts[0]) ?? 0
            : 0,
        jamMulaiParts.length >= 2
            ? int.tryParse(jamMulaiParts[1]) ?? 0
            : 0,
      );

      final DateTime tanggalSelesai = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        jamSelesaiParts.length >= 2
            ? int.tryParse(jamSelesaiParts[0]) ?? 0
            : 0,
        jamSelesaiParts.length >= 2
            ? int.tryParse(jamSelesaiParts[1]) ?? 0
            : 0,
      );

      final post = PostModel(
        id: _isEditMode ? widget.postToEdit!.id : DateTime.now().millisecondsSinceEpoch.toString(),
        uid: uid,
        username: userData?.username ?? 'Anonim',
        userPhotoUrl: userData?.photoUrl ?? '',
        namaKegiatan: _namaController.text.trim(),
        jenisBantuan: _selectedJenis,
        alamat: _alamatController.text.trim(),
        lokasi:
            'Lat: ${_lat!.toStringAsFixed(6)}, Lng: ${_lng!.toStringAsFixed(6)}',
        latitude: _lat!,
        longitude: _lng!,
        imageUrl: imageBase64,
        jumlahPorsi: porsi,
        totalKuota: _isEditMode ? widget.postToEdit!.totalKuota : porsi,
        sudahDiambil: _isEditMode ? widget.postToEdit!.sudahDiambil : 0,
        jamMulai: _jamMulaiController.text.trim(),
        jamSelesai: _jamSelesaiController.text.trim(),
        // untuk menyimpan tanggal kegiatan lengkap dengan jam mulai
        tanggalMulai: tanggalMulai,
        // untuk menyimpan tanggal selesai lengkap sehingga bisa dicek waktu habis
        tanggalSelesai: tanggalSelesai,
        createdAt: _isEditMode ? widget.postToEdit!.createdAt : DateTime.now(),
        favoritedBy: _isEditMode ? widget.postToEdit!.favoritedBy : [],
        diambilOleh: _isEditMode ? widget.postToEdit!.diambilOleh : [],
      );

      if (_isEditMode) {
        await _postService.updatePost(post);
      } else {
        await _postService.createPost(post);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_isEditMode ? 'Postingan berhasil diubah!' : 'Posting berhasil!')));
        // untuk kembali ke halaman Home setelah posting berhasil
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // untuk kembali ke halaman Home via bottom navigation
  void _goBackToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  // untuk membuat label teks di atas setiap field input
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  // untuk membuat TextField dengan style yang konsisten
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        filled: true,
        fillColor: Theme.of(context).inputDecorationTheme.fillColor ??
            Theme.of(context).colorScheme.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // untuk memformat tanggal yang dipilih menjadi teks yang ramah pengguna
    final String tanggalText = _selectedDate == null
        ? 'Pilih tanggal kegiatan'
        : '${_hariIndonesia(_selectedDate!.weekday)}, ${_selectedDate!.day} ${_bulanIndonesia(_selectedDate!.month)} ${_selectedDate!.year}';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        elevation: 0,
        // untuk tombol kembali ke halaman Home
        leading: IconButton(
          onPressed: _goBackToHome,
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: theme.colorScheme.onSurface,
            size: 20,
          ),
        ),
        title: Text(
          _isEditMode ? 'Edit Postingan' : 'Buat Postingan',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // untuk area memilih foto kegiatan
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    width: 1.5,
                  ),
                  // untuk menampilkan preview foto yang sudah dipilih
                  image: _imageBytes != null
                      ? DecorationImage(
                          image: MemoryImage(_imageBytes!),
                          fit: BoxFit.cover)
                      : null,
                ),
                child: _imageBytes == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 44,
                              color: theme.colorScheme.primary),
                          const SizedBox(height: 8),
                          Text(
                            'Ketuk untuk memilih foto',
                            style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      )
                    : Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('Ubah Foto',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // untuk mengisi nama kegiatan
            _buildLabel('Nama Kegiatan'),
            const SizedBox(height: 6),
            _buildTextField(
                controller: _namaController,
                hint: 'Jumat Berkah Masjid Al-Hikmah'),
            const SizedBox(height: 14),

            // untuk memilih jenis bantuan dari dropdown
            _buildLabel('Jenis Bantuan'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: theme.inputDecorationTheme.fillColor ??
                    theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedJenis,
                  isExpanded: true,
                  dropdownColor: theme.cardColor,
                  style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14),
                  items: _jenisList
                      .map((j) =>
                          DropdownMenuItem(value: j, child: Text(j)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedJenis = v!),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // untuk mengisi alamat kegiatan secara manual
            _buildLabel('Alamat'),
            const SizedBox(height: 6),
            TextField(
              controller: _alamatController,
              maxLines: 2,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Ketik alamat lengkap secara manual',
                hintStyle:
                    const TextStyle(color: Colors.grey, fontSize: 13),
                filled: true,
                fillColor: theme.inputDecorationTheme.fillColor ??
                    theme.colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // untuk mengambil koordinat GPS dari perangkat
            _buildLabel('Lokasi (Koordinat GPS)'),
            const SizedBox(height: 6),
            Row(
              children: [
                // untuk menampilkan koordinat GPS yang sudah diambil
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: theme.inputDecorationTheme.fillColor ??
                          theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _lat != null && _lng != null
                          ? 'Lat: ${_lat!.toStringAsFixed(6)}, Lng: ${_lng!.toStringAsFixed(6)}'
                          : 'Ketuk ikon untuk mengambil GPS',
                      style: TextStyle(
                        fontSize: 13,
                        color: _lat != null
                            ? theme.colorScheme.onSurface
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // untuk tombol mengambil GPS
                Material(
                  color: _lat != null
                      ? const Color(0xFF0F5C44)
                      : theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _isLoadingLocation ? null : _getLocation,
                    child: Padding(
                      padding: const EdgeInsets.all(13),
                      child: _isLoadingLocation
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location,
                              color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),
            // untuk menampilkan konfirmasi GPS sudah berhasil diambil
            if (_lat != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        size: 13, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      'GPS: ${_lat!.toStringAsFixed(6)}, ${_lng!.toStringAsFixed(6)}',
                      style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.primary),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),

            // untuk memilih tanggal pelaksanaan kegiatan
            _buildLabel('Tanggal Kegiatan'),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: theme.inputDecorationTheme.fillColor ??
                      theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  // untuk memberi border hijau jika tanggal sudah dipilih
                  border: _selectedDate != null
                      ? Border.all(
                          color: theme.colorScheme.primary
                              .withOpacity(0.5))
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 18,
                      // untuk memberi warna hijau jika tanggal sudah dipilih
                      color: _selectedDate != null
                          ? theme.colorScheme.primary
                          : Colors.grey,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tanggalText,
                        style: TextStyle(
                          fontSize: 13,
                          // untuk memberi warna sesuai apakah sudah dipilih atau belum
                          color: _selectedDate != null
                              ? theme.colorScheme.onSurface
                              : Colors.grey,
                        ),
                      ),
                    ),
                    // untuk ikon chevron yang menandakan bisa diklik
                    const Icon(Icons.chevron_right,
                        size: 18, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // untuk mengisi jam mulai dan jam selesai kegiatan
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Jam Mulai'),
                      const SizedBox(height: 6),
                      _buildTextField(
                          controller: _jamMulaiController,
                          hint: '11:30',
                          keyboardType: TextInputType.datetime), // untuk menampilkan keyboard angka
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Jam Selesai'),
                      const SizedBox(height: 6),
                      _buildTextField(
                          controller: _jamSelesaiController,
                          hint: '13:00',
                          keyboardType: TextInputType.datetime), // untuk menampilkan keyboard angka
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // untuk mengisi jumlah porsi yang tersedia
            _buildLabel('Jumlah Porsi'),
            const SizedBox(height: 6),
            _buildTextField(
                controller: _porsiController,
                hint: '50',
                keyboardType: TextInputType.number),
            const SizedBox(height: 28),

            // untuk tombol submit postingan
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white)
                    : Text(
                        _isEditMode ? 'Simpan Perubahan' : 'Posting',
                        style: const TextStyle(
                            fontSize: 17,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // untuk mengubah angka hari (1-7) menjadi nama hari dalam bahasa Indonesia
  String _hariIndonesia(int weekday) {
    const hari = [
      'Senin', 'Selasa', 'Rabu', 'Kamis',
      'Jumat', 'Sabtu', 'Minggu'
    ];
    return hari[(weekday - 1).clamp(0, 6)];
  }

  // untuk mengubah angka bulan (1-12) menjadi nama bulan dalam bahasa Indonesia
  String _bulanIndonesia(int month) {
    const bulan = [
      'Januari', 'Februari', 'Maret', 'April',
      'Mei', 'Juni', 'Juli', 'Agustus',
      'September', 'Oktober', 'November', 'Desember'
    ];
    return bulan[(month - 1).clamp(0, 11)];
  }
}