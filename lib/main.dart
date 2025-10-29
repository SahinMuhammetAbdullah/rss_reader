// lib/main.dart (GÜNCEL)

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // YENİ
import 'features/rss_feed/presentation/pages/fresh_rss_app.dart'; 

void main() async { // <<< main() metodunu async yapın
  // WIDGETS BAĞLANTISINI SAĞLA
  WidgetsFlutterBinding.ensureInitialized();
  
  // .env dosyasını yükle (Projenizin kök dizinine '.env' adında bir dosya eklemelisiniz.)
  await dotenv.load(fileName: ".env"); 
  
  runApp(const FreshRSSApp());
}