// lib/features/rss_feed/presentation/pages/fresh_rss_app.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/feed_view_model.dart';
import 'login_page.dart';
import 'feed_page.dart';
import 'settings_page.dart';
import 'saved_page.dart';
import 'servers_page.dart';
import 'subscriptions_page.dart';

// Bağımlılıkları manuel oluşturacağımız için bu import'lara ihtiyacımız var:
import '../../data/repositories/feed_repository.dart';
import '../../data/datasources/rss_feed_api_data_source.dart';
import '../../../../core/services/secure_storage_service.dart';

// GetIt kullanmayacağımız için bu import'u kaldırıyoruz
// import 'package:get_it/get_it.dart';

class FreshRSSApp extends StatelessWidget {
  const FreshRSSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FreshFlow Mobile',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const FreshRSSMobileDesign(),
    );
  }
}

class FreshRSSMobileDesign extends StatefulWidget {
  const FreshRSSMobileDesign({super.key});

  @override
  State<FreshRSSMobileDesign> createState() => _FreshRSSMobileDesignState();
}

class _FreshRSSMobileDesignState extends State<FreshRSSMobileDesign> {
  bool _isLoggedIn = false;
  bool _isInitializing = true;
  late FeedViewModel _viewModel;

  // Bağımlılıkları burada tutmak için değişkenler tanımlayın
  late SecureStorageService _secureStorageService;
  late RssFeedApiDataSource _apiDataSource;
  late FeedRepository _feedRepository;


  @override
  void initState() {
    super.initState();
    _initializeDependenciesAndCheckLogin();
  }

  void _initializeDependenciesAndCheckLogin() async {
    // 1. SecureStorageService'i oluştur
    _secureStorageService = SecureStorageService();

    // 2. RssFeedApiDataSource'u oluştur ve secureStorageService'i enjekte et
    _apiDataSource = RssFeedApiDataSource(storageService: _secureStorageService);

    // 3. FeedRepository'yi oluştur ve apiDataSource ile secureStorageService'i enjekte et
    _feedRepository = FeedRepository(
      apiDataSource: _apiDataSource,
      storageService: _secureStorageService,
    );

    // 4. ViewModel'ı oluştur ve repository'i enjekte et
    _viewModel = FeedViewModel(_feedRepository);
    _viewModel.addListener(_onViewModelChange);

    final status = await _viewModel.checkLoginStatus();

    if (status) {
      await _viewModel.fetchAllRssData();
    }

    setState(() {
      _isLoggedIn = status;
      _isInitializing = false;
    });
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChange);
    _viewModel.dispose();
    super.dispose();
  }

  void _onViewModelChange() {
    if (!mounted) return;

    if (_isLoggedIn && _viewModel.feeds.isEmpty && !_viewModel.isLoading) {
      setState(() {
        _isLoggedIn = false;
      });
    }
  }

  void _handleLoginSuccess() {
    setState(() {
      _isLoggedIn = true;
    });
    // Giriş başarılı olduktan sonra feed verilerini tekrar çek
    _viewModel.fetchAllRssData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ChangeNotifierProvider<FeedViewModel>.value(
      value: _viewModel,
      child: _isLoggedIn
          ? _buildAppScaffold()
          : LoginPage(onLoginSuccess: _handleLoginSuccess),
    );
  }

  Widget _buildAppScaffold() {
    return Consumer<FeedViewModel>(
      builder: (context, viewModel, child) {
        switch (viewModel.activeTab) {
          case 'settings':
            return const SettingsPage();

          case 'subscriptions':
            return const SubscriptionsPage();

          case 'saved':
            return const SavedPage();

          case 'home':
          default:
            return const FeedPage();
        }
      },
    );
  }
}