import 'package:flutter/material.dart';
import '../app_info.dart';

class TopHeader extends StatelessWidget {
  final VoidCallback? onCheckForUpdates;

  const TopHeader({super.key, this.onCheckForUpdates});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF2E5B8C), const Color(0xFF4A7AB8)],
        ),
      ),
      child: Row(
        children: [
          // Ilsan Logo
          Image.asset(
            'assets/ImagenLogo1.png',
            width: 24,
            height: 24,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.business, size: 24, color: Colors.white),
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
          const Spacer(),
          Opacity(
            opacity: 0.45,
            child: Text(
              'v${AppInfo.version}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            onPressed: onCheckForUpdates,
            tooltip: 'Buscar actualizaciones',
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 26, height: 26),
            splashRadius: 14,
            color: Colors.white70,
            icon: const Icon(Icons.system_update_alt),
          ),
        ],
      ),
    );
  }
}
