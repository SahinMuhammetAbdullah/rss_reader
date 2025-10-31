// lib/features/rss_feed/presentation/pages/feed_page.dart

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../view_models/feed_view_model.dart';
import '../widgets/feed_item_card.dart';
import '../widgets/bottom_nav_bar.dart';

class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<FeedViewModel>(context);

    if (viewModel.isLoading && viewModel.filteredAndSortedFeeds.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(context, viewModel),
          if (viewModel.errorMessage != 'Bilinmeyen Hata')
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.red.shade100,
              child: Text(
                'Hata: ${viewModel.errorMessage}',
                style: TextStyle(
                    color: Colors.red.shade800, fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            // Yenileme (Pull-to-Refresh) mekanizması
            child: RefreshIndicator(
              onRefresh: () => viewModel.fetchAllRssData(),
              color: AppColors.primaryIndigo,
              child: ListView.builder(
                itemCount: viewModel.filteredAndSortedFeeds.length,
                itemBuilder: (context, index) {
                  return FeedItemCard(
                      feed: viewModel.filteredAndSortedFeeds[index]);
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }

  Widget _buildHeader(BuildContext context, FeedViewModel viewModel) {
    return Container(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16,
          bottom: 16,
          left: 20,
          right: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.primaryIndigo,
            AppColors.primaryPurple,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık ve Aksiyonlar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              
              // 1. SOL BLOK: BAŞLIK ve YENİLEME (Expanded ile kalan tüm alanı kapla)
              Expanded( // <<< BU, BAŞLIĞIN SAĞ BLOĞU İTMESİNİ ENGELLER
                child: Row(
                  children: [
                    // Text widget'ına overflow.ellipsis uygulamaya gerek yok, 
                    // çünkü parent Expanded zaten yer açacaktır.
                    const Text(
                      "FreshFlow", 
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // YENİLEME İKONU (Sabit boyutlu)
                    if (viewModel.isLoading)
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                    if (!viewModel.isLoading)
                      IconButton(
                        icon: const Icon(LucideIcons.refreshCw, color: Colors.white, size: 20),
                        onPressed: () => viewModel.fetchAllRssData(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),
              
              // 2. SAĞ BLOK: Aksiyon İkonları
              // 💡 ÇÖZÜM 2: Ikonlar arasına Sized Box yerine negatif margin veya sade ikon yerleşimi.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeaderIcon(LucideIcons.search), // Arama
                  // SizedBox(width: 12), <-- KALDIRILDI!
                  _buildSortButton(viewModel), // Sıralama
                  // SizedBox(width: 12), <-- KALDIRILDI!
                  _buildMarkAllReadButton(viewModel), // Tümünü Oku
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildReadFilterBar(viewModel), // OKUNDU/OKUNMADI Filtre Çubuğu
          const SizedBox(height: 16),
          _buildCategoryList(viewModel), // KATEGORİ LİSTESİ VE FİLTRELEME
        ],
      ),
    );
  }

  Widget _buildReadFilterBar(FeedViewModel viewModel) {
    final options = [
      {'label': 'Tümü', 'value': 'all'},
      {'label': 'Okunmamış', 'value': 'unread'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: options.map((option) {
          final isSelected = viewModel.readFilter == option['value'];
          return TextButton(
            onPressed: () => viewModel.setReadFilter(option['value']!),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              backgroundColor: isSelected ? Colors.white : Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              option['label']!,
              style: TextStyle(
                color: isSelected ? AppColors.primaryIndigo : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMarkAllReadButton(FeedViewModel viewModel) {
    return IconButton(
      icon: Icon(LucideIcons.checkCheck, // İki onay işareti
          color: Colors.white,
          size: 20),
      onPressed: viewModel.isLoading ? null : () => viewModel.markAllAsRead(),
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildSortButton(FeedViewModel viewModel) {
    return IconButton(
      icon: Icon(
          viewModel.sortOrder == 'desc'
              ? LucideIcons.arrowDownWideNarrow
              : LucideIcons.arrowUpWideNarrow,
          color: Colors.white,
          size: 20),
      onPressed: () {
        viewModel.setSortOrder(viewModel.sortOrder == 'desc' ? 'asc' : 'desc');
      },
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildHeaderIcon(IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: () {},
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
      ),
    );
  }

  Widget _buildCategoryList(FeedViewModel viewModel) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: viewModel.categories.length,
        itemBuilder: (context, index) {
          final cat = viewModel.categories[index];
          final isSelected = cat.name == viewModel.activeCategoryFilter;

          return Padding(
            padding: EdgeInsets.only(
                right: index == viewModel.categories.length - 1 ? 0 : 8),
            child: ElevatedButton.icon(
              onPressed: () => viewModel
                  .setActiveCategoryFilter(cat.name), // FİLTRELEME İŞLEMİ
              icon: Icon(cat.icon,
                  size: 16,
                  color: isSelected ? AppColors.primaryIndigo : Colors.white),
              label: Row(
                children: [
                  Text(
                    cat.name,
                    style: TextStyle(
                        fontSize: 14,
                        color: isSelected
                            ? AppColors.primaryIndigo
                            : Colors.white),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryIndigo
                          : Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      cat.count.toString(), // RSS SAYISI GÖSTERİLİYOR
                      style: TextStyle(
                          fontSize: 10,
                          color: isSelected
                              ? Colors.white
                              : AppColors.primaryIndigo,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isSelected ? Colors.white : Colors.white.withOpacity(0.2),
                foregroundColor:
                    isSelected ? AppColors.primaryIndigo : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.compact,
                side: BorderSide(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withOpacity(0.1),
                    width: 0.5),
              ),
            ),
          );
        },
      ),
    );
  }
}
