import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

// Mengelola seluruh proses autentikasi (daftar, masuk, keluar) dan data pengguna menggunakan Firebase
class AuthService {
  // Menginisialisasi layanan Firebase Authentication dan Firestore
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Mendapatkan data dasar pengguna yang sedang aktif (login) saat ini
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges(); // Memantau perubahan status sesi pengguna secara real-time (misal: saat login atau logout)

  // Mendaftarkan akun pengguna baru menggunakan email dan password
  Future<UserCredential> register({
    required String username,
    required String phone,
    required String email,
    required String password,
  }) async {
    UserCredential credential = await _auth.createUserWithEmailAndPassword( // Membuat akun baru di sistem Firebase Authentication
      email: email,
      password: password,
    );

    UserModel user = UserModel( // Menyiapkan kerangka data profil pengguna yang baru saja mendaftar
      uid: credential.user!.uid,
      username: username,
      phone: phone,
      email: email,
    );

  // Menyimpan rincian data profil pengguna tersebut ke dalam koleksi 'users' di database Firestore
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(user.toMap());

    return credential;
  }

  // Melakukan proses masuk (login) bagi pengguna yang sudah terdaftar
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> logout() async { // Mengeluarkan pengguna dari sesi aplikasi (logout)
    await _auth.signOut();
  }

  Future<UserModel?> getUserData(String uid) async { // Mengambil data profil pengguna secara lengkap dari database berdasarkan UID
    DocumentSnapshot doc =
        await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {                                // Mengubah data mentah dari Firestore menjadi objek UserModel jika datanya ditemukan
      return UserModel.fromMap(doc.data() as Map<String, dynamic>);
    }
    return null;
  }

  // Memperbarui sebagian atau seluruh data profil pengguna di database (seperti nama, nomor HP, foto, atau tema)
  Future<void> updateUserProfile({
    required String uid,
    String? username,
    String? phone,
    String? photoUrl,
    bool? darkMode,
  }) async {
    Map<String, dynamic> data = {};
    // Mengecek dan hanya memasukkan data yang benar-benar diubah (tidak null)
    if (username != null) data['username'] = username;
    if (phone != null) data['phone'] = phone;
    if (photoUrl != null) data['photoUrl'] = photoUrl;
    if (darkMode != null) data['darkMode'] = darkMode;
    await _firestore.collection('users').doc(uid).update(data); // Mengirim perubahan data tersebut ke dokumen pengguna yang bersangkutan di Firestore
  }
}
