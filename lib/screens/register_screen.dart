import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sedekahpoint_kelompok4/models/user_model.dart';
import 'package:sedekahpoint_kelompok4/screens/home_screen.dart';
import 'package:sedekahpoint_kelompok4/screens/login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool isHidden = true;
  bool isLoading = false;
  final usernameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String? usernameError;
  String? phoneError;
  String? emailError;
  String? passwordError;

  Future<void> registerUser() async {
    setState(() {
      usernameError =
          usernameController.text.isEmpty ? "Username wajib diisi" : null;
      phoneError =
          phoneController.text.isEmpty ? "No. Handphone wajib diisi" : null;
      emailError =
          emailController.text.isEmpty ? "Email wajib diisi" : null;
      passwordError =
          passwordController.text.isEmpty ? "Password wajib diisi" : null;
    });

    if (usernameError != null ||
        phoneError != null ||
        emailError != null ||
        passwordError != null) return;

    try {
      setState(() => isLoading = true);
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      UserModel user = UserModel(
        uid: userCredential.user!.uid,
        username: usernameController.text.trim(),
        phone: phoneController.text.trim(),
        email: emailController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(user.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Register berhasil")),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = "";
      if (e.code == 'email-already-in-use') {
        message = "Email sudah digunakan";
      } else if (e.code == 'weak-password') {
        message = "Password terlalu lemah";
      } else if (e.code == 'invalid-email') {
        message = "Format email tidak valid";
      } else {
        message = e.message ?? "Terjadi kesalahan";
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // untuk memaksa tema halaman ini agar selalu berada di mode terang (light mode)
    return Theme(
      data: ThemeData.light(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Color(0xFFA8F0D5)],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 10,
                  left: 10,
                  child: SafeArea(
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.black, size: 24),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 60, vertical: 30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/Logo APK.png', width: 220),
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Center(
                                  child: Text(
                                    "REGISTER",
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                      // untuk memastikan tulisan register tetap berwarna gelap
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                buildLabel("Username"),
                                const SizedBox(height: 6),
                                buildTextField(
                                  controller: usernameController,
                                  hint: "Masukkan Username",
                                  errorText: usernameError,
                                ),
                                const SizedBox(height: 16),
                                buildLabel("No. Handphone"),
                                const SizedBox(height: 6),
                                buildTextField(
                                  controller: phoneController,
                                  hint: "(+62) xxx-xxxx-xxxx",
                                  keyboardType: TextInputType.phone,
                                  errorText: phoneError,
                                ),
                                const SizedBox(height: 16),
                                buildLabel("Email"),
                                const SizedBox(height: 6),
                                buildTextField(
                                  controller: emailController,
                                  hint: "Masukkan Email",
                                  keyboardType: TextInputType.emailAddress,
                                  errorText: emailError,
                                ),
                                const SizedBox(height: 16),
                                buildLabel("Password"),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: passwordController,
                                  obscureText: isHidden,
                                  // untuk memastikan warna teks saat diketik tetap berwarna gelap
                                  style: const TextStyle(color: Colors.black87),
                                  decoration: InputDecoration(
                                    hintText: "Minimum 8 characters",
                                    errorText: passwordError,
                                    filled: true,
                                    fillColor: const Color(0xFFE2ECE8),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 16),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        isHidden
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () => setState(
                                          () => isHidden = !isHidden),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed:
                                        isLoading ? null : registerUser,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF157A5B),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: isLoading
                                        ? const CircularProgressIndicator(
                                            color: Colors.white)
                                        : const Text(
                                            "Register",
                                            style: TextStyle(
                                              fontSize: 17,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text("Already have an account?",
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87)),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const LoginScreen()),
                                      ),
                                      child: const Text(
                                        "Login",
                                        style: TextStyle(
                                          color: Color(0xFF157A5B),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildLabel(String text) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w500),
        children: const [
          TextSpan(text: " *", style: TextStyle(color: Colors.red)),
        ],
      ),
    );
  }

  Widget buildTextField({
    required TextEditingController controller,
    required String hint,
    String? errorText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      // untuk memastikan warna teks saat diketik tetap berwarna gelap
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        errorText: errorText,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFE2ECE8),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}