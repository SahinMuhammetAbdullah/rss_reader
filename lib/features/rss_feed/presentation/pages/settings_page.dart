// lib/features/rss_feed/presentation/pages/settings_page.dart

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../view_models/feed_view_model.dart';
import '../widgets/bottom_nav_bar.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<FeedViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primaryIndigo,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                _buildSectionHeader('Hesap Yönetimi'),
                _buildSettingsItem(
                  icon: LucideIcons.user,
                  title: 'RSS Kaynağı Adı (Örnek)', // Başlığı değiştirdim, çünkü FeedItem'dan kullanıcı adı gelmez
                  // Düzeltme: feed.source yerine feed.sourceName kullanıldı
                  subtitle: viewModel.feeds.isEmpty
                      ? 'Yükleniyor...'
                      : viewModel.feeds.first.sourceName, // YENİ: sourceName
                ),
                _buildSectionHeader('Uygulama'),
                _buildSettingsItem(
                  icon: LucideIcons.moon,
                  title: 'Koyu Tema',
                  trailing: Switch(value: false, onChanged: (v) {}),
                ),
                _buildSettingsItem(
                  icon: LucideIcons.list,
                  title: 'Okunmamışları Gizle',
                  trailing: Switch(value: true, onChanged: (v) {}),
                ),
                const Divider(),
                // Çıkış Yap Butonu
                ListTile(
                  leading: const Icon(LucideIcons.logOut, color: AppColors.primaryPink),
                  title: const Text('Çıkış Yap'),
                  trailing: viewModel.isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : null,
                  onTap: () async {
                    if (!viewModel.isLoading) {
                      await viewModel.logout();
                      // FreshRSSMobileDesign state'i otomatik olarak login'e dönecektir
                    }
                  },
                ),
              ],
            ),
          ),
          const BottomNavBar(), // Alt navigasyonu koruyoruz
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryIndigo,
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textColorSecondary),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
      trailing: trailing,
      onTap: trailing == null ? () {} : null,
    );
  }
}