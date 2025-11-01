// lib/features/rss_feed/domain/models/feed_item.dart (veya models.dart gibi bir dosya)

import 'package:flutter/material.dart';

class FeedItem {
  final String id;
  final String title;

  // TEK KAYNAK ALANI: Ekrandaki adı taşır.
  final String source;

  final int feedId;
  final String time;
  final bool unread;
  final String category;
  final String? url;
  final int timestamp;
  final String? image;
  // ⚠️ Çift tanım olan 'sourceName' KALDIRILDI.

  FeedItem({
    required this.id,
    required this.title,
    this.image,
    // YENİ: Constructor, 'source' bekler.
    required this.source,
    required this.feedId,
    required this.time,
    required this.unread,
    required this.category,
    required this.url,
    required this.timestamp,
  });
}

// ⚠️ Category ismini RssCategory olarak değiştirdik
class RssCategory {
  final int id;
  final String name;
  final int count;
  final IconData icon;
  final List<int> feedIds;

  RssCategory({
    required this.id,
    required this.name,
    required this.count,
    required this.icon,
    required this.feedIds,
  });
}

class Server {
  final String name;
  final String url;
  final String status;
  final int feeds;

  Server({
    required this.name,
    required this.url,
    required this.status,
    required this.feeds,
  });
}

class FeedSubscription {
  final int feedId;
  final String title;
  final String categoryName;
  final int categoryId;

  FeedSubscription({
    required this.feedId,
    required this.title,
    required this.categoryName,
    required this.categoryId,
  });
}
