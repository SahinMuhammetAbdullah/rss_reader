// lib/features/rss_feed/presentation/pages/fresh_rss_app.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/feed_view_model.dart';
import 'login_page.dart';
import 'feed_page.dart';
import 'settings_page.dart';
import 'saved_page.dart';
import 'servers_page.dart';
import '../../data/repositories/feed_repository.dart';
import '../../data/datasources/rss_feed_api_data_source.dart';
import '../../../../core/services/secure_storage_service.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeDependenciesAndCheckLogin();
  }

  void _initializeDependenciesAndCheckLogin() async {
    final apiDataSource = RssFeedApiDataSource();
    final storageService = SecureStorageService();
    final repository = FeedRepository(
      apiDataSource: apiDataSource,
      storageService: storageService,
    );
    _viewModel = FeedViewModel(repository: repository);
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
    super.dispose();
  }

  void _onViewModelChange() {
    if (!mounted) return;

    // Eğer kullanıcı login görünüyor, ancak Feeds listesi boşsa (logout yapılmış demektir)
    // Feeds listesi, filtrelenmemiş ham liste olduğu için bu kontrol güvenlidir.
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

          case 'servers':
            return const ServersPage();

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
