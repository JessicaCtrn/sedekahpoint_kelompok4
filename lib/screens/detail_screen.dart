import 'package:flutter/material.dart';
import 'package:sedekahpoint_kelompok4/models/post_model.dart';

class DetailScreen extends StatelessWidget {
  final PostModel post;

  const DetailScreen({
    super.key,
    required this.post,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Bantuan'),
      ),
      body: const Center(
        child: Text('TEST'),
      ),
    );
  }
}