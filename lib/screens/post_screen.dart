import 'package:flutter/material.dart';

class PostScreen extends StatelessWidget {
  const PostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('post screen'),
      ),
      body: const Center(
        child: Text('post screen'),
      ),
    );
  }
}