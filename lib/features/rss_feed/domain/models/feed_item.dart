// lib/features/rss_feed/domain/models/feed_item.dart

import 'package:flutter/material.dart';

class FeedItem {
  final int id;
  final String title;
  final String sourceName; // Yeni isim: Kaynağın adı
  final int feedId; // YENİ: Doğrudan feed ID'si
  final String time;
  final bool unread;
  final String category;
  final String url;
  final int timestamp;

  FeedItem({
    required this.id,
    required this.title,
    required this.sourceName, // source yerine sourceName
    required this.feedId, // Yeni alan
    required this.time,
    required this.unread,
    required this.category,
    required this.url,
    required this.timestamp,
  });
}


class Category {
  final int id;
  final String name;
  final int count;
  final IconData icon;
  final List<int> feedIds; // <<< YENİ: Bu kategoriye ait feed ID'leri

  Category({
    required this.id,
    required this.name,
    required this.count,
    required this.icon,
    required this.feedIds, // <<< YENİ: Constructor'a eklendi
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
