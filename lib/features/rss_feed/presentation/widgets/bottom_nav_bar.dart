// lib/features/rss_feed/presentation/widgets/bottom_nav_bar.dart

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../view_models/feed_view_model.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    // ViewModel'deki değişiklikleri dinle
    final viewModel = Provider.of<FeedViewModel>(context);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border:
            Border(top: BorderSide(color: AppColors.greyDivider, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(context, LucideIcons.home, 'Ana Sayfa', 'home', viewModel),
            _buildNavItem(context, LucideIcons.bookmark, 'Kaydedilenler', 'saved', viewModel),
            _buildNavItem(context, LucideIcons.podcast, 'Abonelikler', 'subscriptions', viewModel),
            _buildNavItem(context, LucideIcons.settings, 'Ayarlar', 'settings', viewModel),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
      BuildContext context, IconData icon, String label, String tabName, FeedViewModel viewModel) {
    final bool isSelected = viewModel.activeTab == tabName;

    return GestureDetector(
      // OnTap'te ViewModel'deki aktif sekme değiştirilir
      onTap: () => viewModel.setActiveTab(tabName), 
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryIndigo.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? AppColors.primaryIndigo : Colors.grey[600],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isSelected ? AppColors.primaryIndigo : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}