import 'package:flutter/material.dart';

class TopHeader extends StatelessWidget {
  const TopHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2E5B8C),
            const Color(0xFF4A7AB8),
          ],
        ),
      ),
      child: Row(
        children: [
          // Ilsan Logo
          Image.asset(
            'assets/ImagenLogo1.png',
            width: 24,
            height: 24,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.business,
              size: 24,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Ilsan Packing System',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
