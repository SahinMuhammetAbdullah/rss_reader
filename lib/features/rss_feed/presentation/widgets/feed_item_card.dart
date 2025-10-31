// lib/features/rss_feed/presentation/widgets/feed_item_card.dart

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/models/feed_item.dart';
import '../../../../core/constants/app_colors.dart';
import '../view_models/feed_view_model.dart'; // ViewModel import edildi

class FeedItemCard extends StatelessWidget {
  final FeedItem feed;

  const FeedItemCard({super.key, required this.feed});

  @override
  Widget build(BuildContext context) {
    // ViewModel'e erişim (İkon butonu için listen: false yeterlidir)
    final viewModel = Provider.of<FeedViewModel>(context, listen: false);

    return Container(
      decoration: BoxDecoration(
        color: feed.unread
            ? AppColors.lightBlueBackground.withOpacity(0.5)
            : Colors.white,
        border: const Border(
            bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1)),
      ),
      // Kartın tamamı değil, içindeki başlık tıklanabilir olacak.
      child: InkWell(
        // Ana InkWell'in onTap'i kaldırıldı, mantık başlıkta ve ikonda.
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ... (Opsiyonel Resim kısmı) ...
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- KATEGORİ VE OKUNMAMIŞ İNDİKATÖRÜ ---
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryIndigo.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                feed.category,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryIndigo,
                                ),
                              ),
                            ),
                            if (feed.unread)
                              // Okunmamış İndikatörü (Mavi nokta)
                              const Padding(
                                padding: EdgeInsets.only(left: 8.0),
                                child: CircleAvatar(
                                    radius: 4,
                                    backgroundColor: AppColors.accentBlue),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // --- MAKALE BAŞLIĞI (URL Açma İşlevi) ---
                        GestureDetector(
                          onTap: () async {
                            final urlString = feed.url;
                            if (urlString != null && urlString != '#') {
                              final uri = Uri.tryParse(urlString);
                              if (uri != null && await canLaunchUrl(uri)) {
                                await launchUrl(uri,
                                    mode: LaunchMode.externalApplication);

                                // Makale açıldıktan sonra otomatik okundu işaretlenir (UX Kuralı)
                                if (feed.unread) {
                                  // Asenkron olarak çağır
                                  viewModel.markItemStatus(feed.id, true);
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Bağlantı açılamıyor.')),
                                );
                              }
                            }
                          },
                          child: Text(
                            feed.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: feed.unread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: feed.unread
                                  ? AppColors.textColorPrimary
                                  : AppColors.textColorSecondary,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // --- ALT BİLGİ (Kaynak ve Tarih) ---
                        Row(
                          children: [
                            Text(
                              feed.source,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textColorSecondary,
                                  fontWeight: FontWeight.w500),
                            ),
                            const Text(" • ",
                                style: TextStyle(
                                    color: AppColors.textColorSecondary)),
                            Icon(LucideIcons.clock,
                                size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              feed.time, // ZAMAN BİLGİSİ FORMATLI
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // --- OKUNDU/OKUNMADI TOGGLE İKONU ---
                  _buildReadToggleButton(context, viewModel, feed),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Zarf ikonunu oluşturur ve okundu/okunmadı durumunu değiştirir
  Widget _buildReadToggleButton(
      BuildContext context, FeedViewModel viewModel, FeedItem feed) {
    return Container(
      margin: const EdgeInsets.only(left: 12, top: 4),
      child: IconButton(
        icon: Icon(
          feed.unread
              ? LucideIcons.mail
              : LucideIcons.mailOpen, // Okunmamışsa açık zarf
          size: 20,
          color: feed.unread ? AppColors.primaryIndigo : Colors.grey[400],
        ),
        onPressed: () async {
          if (feed.unread) {
            // Durumu tersine çevirerek sunucuya gönder (isRead = !feed.unread)
            final urlString = feed.url;
            if (feed.unread) {
              // Asenkron olarak çağır
              viewModel.markItemStatus(feed.id, true);
            }
            // if (urlString != null && urlString != '#') {
            //   final uri = Uri.tryParse(urlString);
            //   if (uri != null && await canLaunchUrl(uri)) {
            //     await launchUrl(uri, mode: LaunchMode.externalApplication);

            //     // Makale açıldıktan sonra otomatik okundu işaretlenir (UX Kuralı)

            //   } else {
            //     ScaffoldMessenger.of(context).showSnackBar(
            //       const SnackBar(content: Text('Bağlantı açılamıyor.')),
            //     );
            //   }
            // }
          } else {
            viewModel.markItemStatus(feed.id, false);
          }

          //  viewModel.markItemStatus(feed.id, !feed.unread);
        },
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }
}
