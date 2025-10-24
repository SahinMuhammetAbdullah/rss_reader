// lib/features/rss_feed/domain/models/feed_item.dart (veya models.dart gibi bir dosya)

import 'package:flutter/material.dart';

class FeedItem {
  final int id;
  final String title;
  final String sourceName;
  final int feedId;
  final String time;
  final bool unread;
  final String category; // Bu hala string olarak kategori adını tutabilir
  final String url;
  final int timestamp;
  

  FeedItem({
    required this.id,
    required this.title,
    required this.sourceName,
    required this.feedId,
    required this.time,
    required this.unread,
    required this.category,
    required this.url,
    required this.timestamp, required String source,
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