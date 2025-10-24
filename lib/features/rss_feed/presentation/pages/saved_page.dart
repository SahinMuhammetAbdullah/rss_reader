// lib/features/rss_feed/presentation/pages/saved_page.dart

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../view_models/feed_view_model.dart';
import '../widgets/bottom_nav_bar.dart';

class SavedPage extends StatelessWidget {
  const SavedPage({super.key});

  @override
  Widget build(BuildContext context) {
    // ViewModel'den herhangi bir state alabiliriz, şimdilik sadece Scaffold'u veriyoruz.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kaydedilenler', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primaryIndigo,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.bookmark, size: 60, color: Colors.orange),
            const SizedBox(height: 16),
            const Text('Kaydedilen Makaleler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Henüz kaydedilmiş makale yok.', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}