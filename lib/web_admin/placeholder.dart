import 'package:flutter/material.dart';

// Warna yang sering digunakan
const Color _secondaryColor = Color(0xFF2c3e50); // Biru Tua

class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction,
            size: 80,
            color: _secondaryColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 20),
          Text(
            'Halaman "$title"',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _secondaryColor,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Dalam pengembangan. Silakan pilih menu lain.',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
