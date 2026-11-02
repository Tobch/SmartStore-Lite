import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../viewmodels/product_viewmodel.dart';
import '../../viewmodels/stock_movement_viewmodel.dart';
import '../../viewmodels/reports_viewmodel.dart';
import '../../core/services/sync_service.dart';
import '../dashboard/dashboard_screen.dart';
import '../responsive/product_master_detail_landscape.dart';
import '../movements/movement_history_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';

/// Main shell screen that provides [BottomNavigationBar] navigation
/// between the app's primary sections. Tabs are role-aware:
/// managers see Reports, staff do not.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Pre-load movement history and sync pending changes
      context.read<StockMovementViewModel>().loadMovements();
      SyncService().syncPendingChanges().then((_) {
        if (mounted) {
          context.read<DashboardViewModel>().loadDashboardMetrics();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    final bool isManager =
        authVM.currentUser?.role.toLowerCase() == 'manager';

    // Build the list of tab screens based on role
    final List<Widget> screens = [
      const DashboardScreen(),
      const ProductResponsiveWrapper(),
      const MovementHistoryScreen(),
      if (isManager) const ReportsScreen(),
      const SettingsScreen(),
    ];

    // Build matching navigation items
    final List<BottomNavigationBarItem> navItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.dashboard),
        label: 'Dashboard',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.inventory_2),
        label: 'Products',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.swap_horiz),
        label: 'Movements',
      ),
      if (isManager)
        const BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart),
          label: 'Reports',
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.settings),
        label: 'Settings',
      ),
    ];

    // Clamp index in case role changes mid-session
    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          // Auto-refresh respective viewmodels on tab switch
          if (index == 0) {
            context.read<DashboardViewModel>().loadDashboardMetrics();
          } else if (index == 1) {
            context.read<ProductViewModel>().loadProducts();
          } else if (index == 2) {
            context.read<StockMovementViewModel>().loadMovements();
          } else if (isManager && index == 3) {
            context.read<ReportsViewModel>().loadReports();
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: navItems,
      ),
    );
  }
}
