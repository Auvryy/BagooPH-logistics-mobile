import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/session_gate.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final storage = await StorageService.init();
  final api = ApiService(storage);

  runApp(BagooScannerApp(storage: storage, api: api));
}

class BagooScannerApp extends StatelessWidget {
  final StorageService storage;
  final ApiService api;

  const BagooScannerApp({super.key, required this.storage, required this.api});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bagoo Scanner Terminal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        fontFamily: 'Plus Jakarta Sans',
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.primaryLight,
          surface: AppColors.surface,
          error: AppColors.error,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          elevation: 0,
        ),
      ),
      home: SessionGate(storage: storage, api: api),
    );
  }
}
