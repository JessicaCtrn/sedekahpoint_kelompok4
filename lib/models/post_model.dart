import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String uid;
  final String username;
  final String? userPhotoUrl;
  final String namaKegiatan;
  final String jenisBantuan;
  final String lokasi;
  final double latitude;
  final double longitude;
  final String imageUrl;
  final int jumlahPorsi;
  final String alamat;
  final int totalKuota;
  final int sudahDiambil;
  final String jamMulai;
  final String jamSelesai;
  final DateTime createdAt;
  final List<String> favoritedBy;
  final List<String> diambilOleh;

  // untuk menyimpan tanggal + jam mulai & selesai secara penuh
  // sehingga postingan bisa otomatis hilang sesuai hari & jam yang ditentukan
  final DateTime? tanggalMulai;
  final DateTime? tanggalSelesai;

  PostModel({
    required this.id,
    required this.uid,
    required this.username,
    this.userPhotoUrl,
    required this.namaKegiatan,
    required this.jenisBantuan,
    required this.lokasi,
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
    required this.jumlahPorsi,
    required this.totalKuota,
    required this.sudahDiambil,
    required this.jamMulai,
    required this.jamSelesai,
    required this.alamat,
    required this.createdAt,
    this.favoritedBy = const [],
    this.diambilOleh = const [],
    this.tanggalMulai,   // nullable agar postingan lama tidak error
    this.tanggalSelesai, // nullable agar postingan lama tidak error
  });

  int get stokKuota => totalKuota - sudahDiambil;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'username': username,
      'userPhotoUrl': userPhotoUrl ?? '',
      'namaKegiatan': namaKegiatan,
      'jenisBantuan': jenisBantuan,
      'lokasi': lokasi,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrl': imageUrl,
      'jumlahPorsi': jumlahPorsi,
      'totalKuota': totalKuota,
      'sudahDiambil': sudahDiambil,
      'jamMulai': jamMulai,
      'jamSelesai': jamSelesai,
      'alamat': alamat,
      'createdAt': Timestamp.fromDate(createdAt),
      'favoritedBy': favoritedBy,
      'diambilOleh': diambilOleh,
      // simpan ke Firestore jika ada, null jika tidak ada
      'tanggalMulai': tanggalMulai != null
          ? Timestamp.fromDate(tanggalMulai!)
          : null,
      'tanggalSelesai': tanggalSelesai != null
          ? Timestamp.fromDate(tanggalSelesai!)
          : null,
    };
  }

  factory PostModel.fromMap(Map<String, dynamic> map) {
    return PostModel(
      id: map['id'] ?? '',
      uid: map['uid'] ?? '',
      username: map['username'] ?? '',
      userPhotoUrl: map['userPhotoUrl'],
      namaKegiatan: map['namaKegiatan'] ?? '',
      jenisBantuan: map['jenisBantuan'] ?? '',
      lokasi: map['lokasi'] ?? '',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      imageUrl: map['imageUrl'] ?? '',
      jumlahPorsi: map['jumlahPorsi'] ?? 0,
      totalKuota: map['totalKuota'] ?? 0,
      sudahDiambil: map['sudahDiambil'] ?? 0,
      alamat: map['alamat'] ?? '',
      jamMulai: map['jamMulai'] ?? '',
      jamSelesai: map['jamSelesai'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      favoritedBy: List<String>.from(map['favoritedBy'] ?? []),
      diambilOleh: List<String>.from(map['diambilOleh'] ?? []),
      // baca dari Firestore, null-safe agar postingan lama tidak crash
      tanggalMulai: map['tanggalMulai'] != null
          ? (map['tanggalMulai'] as Timestamp).toDate()
          : null,
      tanggalSelesai: map['tanggalSelesai'] != null
          ? (map['tanggalSelesai'] as Timestamp).toDate()
          : null,
    );
  }
}