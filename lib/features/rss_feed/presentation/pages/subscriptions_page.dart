// lib/features/rss_feed/presentation/pages/subscriptions_page.dart

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../view_models/feed_view_model.dart';
import '../widgets/bottom_nav_bar.dart';
import '../../domain/models/feed_item.dart'; // <<< KRİTİK IMPORT: FeedSubscription ve Category modelleri için

class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({super.key});

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _selectedCategoryName; // Yeni abonelik için seçilen kategori
  final List<String> _categoryNames = []; // Kategori adlarını tutmak için

  @override
  void dispose() {
    _urlController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewModel = Provider.of<FeedViewModel>(context, listen: false);
    _categoryNames.clear();
    // 'Hepsi' hariç tüm kategorileri al
    _categoryNames.addAll(viewModel.categories
        .where((cat) => cat.id != 0)
        .map((cat) => cat.name)
        .toList());
  }

  Future<void> _addSubscription(FeedViewModel viewModel) async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Lütfen geçerli bir RSS/Web adresi girin.')));
      return;
    }

    try {
      await viewModel.addSubscription(url);
      _urlController.clear();
      _focusNode.unfocus(); // Klavyeyi kapat
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Abonelik başarıyla eklendi! Yenileniyor...')));

      // Veri çekimini zorla (eklenen feed'in ana sayfada görünmesi için)
      await viewModel.fetchAllRssData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Abonelik hatası: ${viewModel.errorMessage}')));
    }
  }

  Future<void> _confirmDeleteFeed(
      FeedViewModel viewModel, FeedSubscription feed) async {
    final confirmed = await showDialog<bool>(
      context: context, // <<< CONTEXT NAMED ARGÜMAN OLARAK GEREKLİ
      builder: (context) {
        return AlertDialog(
          title: const Text('Aboneliği Sil'),
          content: Text(
              '${feed.title} aboneliğini silmek istediğinizden emin misiniz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sil', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      }, // <<< builder kesinlikle bir Widget döndürür.
    );
    if (confirmed == true) {
      await viewModel.removeSubscription(feed.feedId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<FeedViewModel>(context);

    final managementCategories =
        viewModel.categories.where((cat) => cat.id != 0).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Abonelik Yönetimi',
            style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primaryIndigo,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- 1. Abonelik Ekleme Formu ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Yeni Abonelik Ekle',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _selectedCategoryName,
                  hint: const Text('Kategori Seç (Opsiyonel)'),
                  items:
                      viewModel.categories // ViewModel'den gelen listeyi kullan
                          .where((cat) => cat.id != 0)
                          .map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat.name,
                      child: Text(cat.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedCategoryName = value);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _urlController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    labelText: 'RSS veya Web Adresi',
                    hintText: 'https://...',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(LucideIcons.rss),
                    suffixIcon: viewModel.isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : IconButton(
                            icon: const Icon(LucideIcons.plusCircle),
                            onPressed: () => _addSubscription(viewModel),
                          ),
                  ),
                  onSubmitted: (_) => _addSubscription(viewModel),
                  keyboardType: TextInputType.url,
                ),
              ],
            ),
          ),

          const Divider(),

          // --- 2. Kategori ve Abonelik Listesi (Yönetim) ---
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
                'Mevcut Abonelikler (${viewModel.categories.fold(0, (sum, cat) => sum + cat.count)})',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: managementCategories.length,
              itemBuilder: (context, index) {
                final cat = managementCategories[index];
                final feedsInCat = viewModel.getFeedsForCategory(cat.id);
                final isCategoryEmpty = feedsInCat
                    .isEmpty; // cat.count yerine feedsInCat.isEmpty kullanıyoruz

                return ExpansionTile(
                  leading: Icon(cat.icon, color: AppColors.primaryIndigo),
                  title: Text('${cat.name} (${feedsInCat.length})'),
                  initiallyExpanded: false,

                  // Kategori Silme Butonu (Sadece boşsa)
                  trailing: isCategoryEmpty && cat.id != 'Genel'.hashCode
                      ? IconButton(
                          icon: const Icon(LucideIcons.trash2, color: Colors.red),
                          onPressed: () async {
                            // Diyalog üzerinden onayı al (gövdesi eksik)
                            final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                    title: const Text('Kategori Silme Onayı'),
                                    content: Text('${cat.name} kategorisini silmek istediğinizden emin misiniz?'),
                                    actions: [
                                        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('İptal')),
                                        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sil', style: TextStyle(color: Colors.red))),
                                    ],
                                )
                            );
                            
                            if (confirmed == true) {
                                await viewModel.deleteCategory(cat.id);
                                // Hata mesajı otomatik olarak ViewModel'den gelecektir.
                            }
                          },
                        )
                      : null,

                  children: feedsInCat
                      .map((feed) => _buildFeedListTile(
                          context, viewModel, feed, managementCategories))
                      .toList(),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }

  Widget _buildFeedListTile(BuildContext context, FeedViewModel viewModel,
      FeedSubscription feed, List<RssCategory> allCategories) {
    // Kategori adı listesi (Mevcut kategori hariç)
    final otherCategories = allCategories
        .where((cat) => cat.id != feed.categoryId && cat.id != 0)
        .map((cat) => cat.name)
        .toList();

    return ListTile(
      contentPadding: const EdgeInsets.only(left: 32, right: 16),
      title: Text(feed.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('ID: ${feed.feedId}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Kategori Değiştirme Butonu (Move)
          if (otherCategories.isNotEmpty)
            IconButton(
              icon: const Icon(LucideIcons.folderInput,
                  size: 20, color: AppColors.primaryIndigo),
              onPressed: () => _showCategoryChangeDialog(
                  context, viewModel, feed, otherCategories),
            ),
          // Silme Butonu
          IconButton(
            icon: const Icon(LucideIcons.trash2, size: 20, color: Colors.red),
            onPressed: () => _confirmDeleteFeed(viewModel, feed),
          ),
        ],
      ),
    );
  }

  // Kategori Değiştirme Diyaloğu
  void _showCategoryChangeDialog(BuildContext context, FeedViewModel viewModel,
      FeedSubscription feed, List<String> otherCategories) {
    String? newCategory =
        otherCategories.first; // Varsayılan olarak ilk kategoriyi seç

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Kategoriyi Değiştir'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return DropdownButton<String>(
                value: newCategory,
                items: otherCategories.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    newCategory = newValue;
                  });
                },
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('İptal'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Taşı'),
              onPressed: () {
                Navigator.of(context).pop();
                if (newCategory != null) {
                  viewModel.moveSubscription(feed.feedId, newCategory!,
                      oldCategoryName: feed.categoryName);
                }
              },
            ),
          ],
        );
      },
    );
  }
}
