// lib/features/rss_feed/presentation/widgets/feed_item_card.dart (Varsayımsal örnek)

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/feed_item.dart';

class FeedItemCard extends StatelessWidget {
  final FeedItem feed;

  const FeedItemCard({super.key, required this.feed});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          if (await canLaunchUrl(Uri.parse(feed.url))) {
            await launchUrl(Uri.parse(feed.url));
          } else {
            // Hata mesajı göster
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('URL açılamadı: ${feed.url}')),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                feed.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryIndigo,
                ),
              ),
              const SizedBox(height: 8),
              // BURADA DEĞİŞİKLİK YAPILMALI
              Text(
                // Eskisi: feed.source
                feed.sourceName, // YENİ: feed.sourceName kullanılıyor
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    feed.time,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (feed.category.isNotEmpty)
                    Chip(
                      label: Text(
                        feed.category,
                        style: const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                      backgroundColor: AppColors.primaryPurple.withOpacity(0.8),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}