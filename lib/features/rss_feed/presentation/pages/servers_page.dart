// lib/features/rss_feed/presentation/pages/servers_page.dart

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../view_models/feed_view_model.dart';
import '../widgets/bottom_nav_bar.dart';

class ServersPage extends StatelessWidget {
  const ServersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<FeedViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sunucularım', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primaryIndigo,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: false, // Ana navigasyon olduğu için geri tuşu yok
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus, size: 24),
            onPressed: () {
              // Yeni sunucu ekleme aksiyonu
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.server, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Sunucu Yönetimi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Bağlantı kurulan ${viewModel.servers.length} sunucu listeleniyor.', style: const TextStyle(color: Colors.grey)),
            // Burada sunucu listesi (viewModel.servers) gösterilebilir
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}