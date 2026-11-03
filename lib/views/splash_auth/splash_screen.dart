import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    _checkLoginState();
  }

  Future<void> _checkLoginState() async {
    // 1. Give the splash screen a 2-second delay for branding
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // 2. Check the local cache for an existing session
    final authVM = context.read<AuthViewModel>();
    await authVM.checkAuthStatus();

    if (!mounted) return;

    // 3. Route appropriately (Offline safe!)
    if (authVM.currentUser != null) {
      // User has a cached session, go straight to Dashboard
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      // No cached session, requires internet to log in
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2, size: 100, color: Colors.blueAccent),
            const SizedBox(height: 24),
            Text('SmartStore Lite', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}