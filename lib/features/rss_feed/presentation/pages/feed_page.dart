// lib/features/rss_feed/presentation/pages/feed_page.dart

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; // Bu import muhtemelen FeedItemCard içinde kullanılabilir
import '../../../../core/constants/app_colors.dart';
import '../view_models/feed_view_model.dart';
import '../widgets/feed_item_card.dart';
import '../widgets/bottom_nav_bar.dart';
import '../../domain/models/feed_item.dart'; // Gerekli değilse kaldırılabilir

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
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => viewModel.fetchAllRssData(),
              color: AppColors.primaryIndigo,
              child:
                  // KRİTİK DÜZELTME: Filtrelenmiş ve sıralanmış listeyi kullan
                  ListView.builder(
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

  // Header'ı ViewModel alacak şekilde güncelliyoruz
  Widget _buildHeader(BuildContext context, FeedViewModel viewModel) {
    return Container(
      // Gradient arka plan için padding ayarı
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
          // BAŞLIK ve AKSİYONLAR
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            // Bu ana Row, iki ana bloğu yan yana koyar
            children: [
              // 1. SOL BLOK: Başlık ve Yenileme İkonu
              Row(
                // Başlık (Text) ve Yenileme İkonu
                children: [
                  const Text(
                    "FreshFlow", // TEK KULLANIM
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Yenileme ikonu veya Loading Indicator
                  if (viewModel.isLoading)
                    const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)),
                  if (!viewModel.isLoading)
                    IconButton(
                      icon: const Icon(LucideIcons.refreshCw,
                          color: Colors.white, size: 20),
                      onPressed: () => viewModel.fetchAllRssData(),
                      padding:
                          EdgeInsets.zero, // Padding'i sıfırlayarak yer kazan
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),

              // 2. SAĞ BLOK: Arama ve Sıralama İkonları
              Row(
                children: [
                  _buildHeaderIcon(LucideIcons.search),
                  const SizedBox(width: 12),
                  _buildSortButton(viewModel), // SIRALAMA BUTONU
                ],
              ),
              // Kaldırılan satır: const Text("FreshFlow", ...)
            ],
          ),

          const SizedBox(height: 16),
          _buildCategoryList(viewModel), // KATEGORİ LİSTESİ VE FİLTRELEME
        ],
      ),
    );
  }

  // Sıralama Butonu
  Widget _buildSortButton(FeedViewModel viewModel) {
    return IconButton(
      icon: Icon(
          // 'desc' ise aşağı ok (en yeni), 'asc' ise yukarı ok (en eski)
          viewModel.sortOrder == 'desc'
              ? LucideIcons.arrowDownWideNarrow
              : LucideIcons.arrowUpWideNarrow,
          color: Colors.white,
          size: 20),
      onPressed: () {
        // Sıralama yönünü değiştir
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

  // Kategori Listesi ve Filtreleme
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
                  // Kategori sayısını gösterme (Artık gerçek data)
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