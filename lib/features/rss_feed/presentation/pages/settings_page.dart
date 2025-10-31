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
        automaticallyImplyLeading: false, 
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                _buildSectionHeader('Hesap Yönetimi'),
                _buildSettingsItem(
                  icon: LucideIcons.server,
                  title: 'Sunucu Adresi',
                  subtitle: viewModel.loggedInServerUrl ?? 'Bağlantı Kurulmadı', // Bağlı sunucu URL'si
                ),
                _buildSettingsItem(
                  icon: LucideIcons.user,
                  title: 'Kullanıcı Adı',
                  // NOT: Secure Storage'dan kullanıcı adını çekme mantığı eklenmelidir. Şimdilik sabit.
                  subtitle: 'Giriş Başarılı (API Key)', 
                ),
                _buildSectionHeader('Görünüm'),
                _buildSettingsItem(
                  icon: LucideIcons.moon,
                  title: 'Koyu Tema',
                  trailing: Switch(value: false, onChanged: (v) {}),
                ),
                _buildSectionHeader('Veri'),
                _buildSettingsItem(
                  icon: LucideIcons.list,
                  title: 'Okunmuşları Göster',
                  subtitle: 'Tüm makaleler listede görünür.',
                  trailing: Switch(
                      value: viewModel.readFilter == 'all', 
                      onChanged: (v) {
                        viewModel.setReadFilter(v ? 'all' : 'unread');
                      }
                  ),
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
                    }
                  },
                ),
              ],
            ),
          ),
          const BottomNavBar(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Text(
        title,
        style: const TextStyle(
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