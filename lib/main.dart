import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

// Core Themes & Services
import 'core/constants/app_theme.dart';
import 'core/services/notification_service.dart';
import 'core/services/tts_stt_service.dart';

// ViewModels
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/dashboard_viewmodel.dart';
import 'viewmodels/product_viewmodel.dart';
import 'viewmodels/stock_movement_viewmodel.dart';
import 'viewmodels/reports_viewmodel.dart';
import 'viewmodels/settings_viewmodel.dart';

// Screens
import 'views/splash_auth/login_screen.dart';
import 'views/splash_auth/register_screen.dart';
import 'views/splash_auth/forgot_password_screen.dart';
import 'views/home/home_screen.dart';
import 'views/responsive/product_master_detail_landscape.dart';
import 'views/products/product_edit_screen.dart';
import 'views/movements/add_movement_screen.dart';
import 'views/reports/reports_screen.dart';
import 'views/splash_auth/splash_screen.dart';
import 'views/movements/movement_history_screen.dart';
import 'views/settings/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize local notifications service
  await NotificationService.init();

  runApp(
    MultiProvider(
      providers: [
        // Inject TTS/STT Service so screens can use it
        Provider(create: (_) => TtsSttService()), 
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => DashboardViewModel()),
        ChangeNotifierProvider(create: (_) => ProductViewModel()),
        ChangeNotifierProvider(create: (_) => StockMovementViewModel()),
        ChangeNotifierProvider(create: (_) => ReportsViewModel()),
        ChangeNotifierProvider(create: (_) => SettingsViewModel()..loadSettings()),
      ],
      child: const SmartStoreApp(),
    ),
  );
}

class SmartStoreApp extends StatelessWidget {
  const SmartStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsVM = context.watch<SettingsViewModel>();

    return MaterialApp(
      title: 'SmartStore Lite',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settingsVM.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      
      initialRoute: '/splash',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/forgot_password': (context) => const ForgotPasswordScreen(),
        '/dashboard': (context) => const HomeScreen(),
        '/products': (context) => const ProductResponsiveWrapper(),
        '/add_product': (context) => const ProductEditScreen(),
        '/add_movement': (context) => const AddMovementScreen(),
        '/reports': (context) => const ReportsScreen(),
        '/splash': (context) => const SplashScreen(),
        '/movement_history': (context) => const MovementHistoryScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}