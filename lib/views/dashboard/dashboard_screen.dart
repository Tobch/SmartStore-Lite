import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/product_viewmodel.dart';
import '../../core/services/sync_service.dart';
import '../movements/movement_history_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardViewModel>().loadDashboardMetrics();
      SyncService().syncPendingChanges().then((_) {
        if (mounted) context.read<DashboardViewModel>().loadDashboardMetrics();
      });
    });
  }

  Future<void> _manualSync() async {
    setState(() => _isSyncing = true);
    final messenger = ScaffoldMessenger.of(context);
    final count = await SyncService().syncPendingChanges();
    if (!mounted) return;
    await context.read<DashboardViewModel>().loadDashboardMetrics();
    setState(() => _isSyncing = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(count > 0 
            ? 'Successfully synced $count changes to Firebase!' 
            : 'All changes are already up to date.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboardVM = context.watch<DashboardViewModel>();
    final authVM = context.watch<AuthViewModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Sync Now',
            onPressed: _isSyncing ? null : _manualSync,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              await authVM.logout();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Movement', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => Navigator.pushNamed(context, '/add_movement'),
      ),
      body: dashboardVM.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await SyncService().syncPendingChanges();
                await dashboardVM.loadDashboardMetrics();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSyncStatusCard(context, dashboardVM, isDark),
                    const SizedBox(height: 24),
                    
                    // Hero Metric Card (Full Width)
                    _buildGradientCard(
                      context: context,
                      title: 'Total Asset Value',
                      value: 'EGP ${dashboardVM.totalStockValue.toStringAsFixed(2)}',
                      icon: Icons.account_balance_wallet_rounded,
                      colors: [const Color(0xFF1976D2), const Color(0xFF0D47A1)], // Enterprise Blues
                      onTap: () {
                        context.read<ProductViewModel>().setLowStockFilter(false);
                        Navigator.pushNamed(context, '/products');
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Secondary Metrics (Half Width)
                    Row(
                      children: [
                        Expanded(
                          child: _buildGradientCard(
                            context: context,
                            title: 'Low Stock Alerts',
                            value: '${dashboardVM.lowStockCount}',
                            icon: Icons.warning_amber_rounded,
                            colors: [const Color(0xFFEF5350), const Color(0xFFC62828)], // Alert Reds
                            onTap: () {
                              context.read<ProductViewModel>().setLowStockFilter(true);
                              Navigator.pushNamed(context, '/products');
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildGradientCard(
                            context: context,
                            title: "Today's Volume",
                            value: '${dashboardVM.todaysMovements}',
                            icon: Icons.swap_horiz_rounded,
                            colors: [const Color(0xFF26A69A), const Color(0xFF00695C)], // Success Teals
                            onTap: () {
                            Navigator.push(
                              context, 
                              MaterialPageRoute(builder: (context) => const MovementHistoryScreen(showOnlyToday: true))
                            );
                          },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSyncStatusCard(BuildContext context, DashboardViewModel vm, bool isDark) {
    bool isPending = vm.pendingSyncCount > 0;
    
    Color bgColor = isPending 
        ? (isDark ? Colors.orange.shade900.withOpacity(0.2) : Colors.orange.shade50)
        : (isDark ? Colors.green.shade900.withOpacity(0.2) : Colors.green.shade50);
        
    Color borderColor = isPending ? Colors.orange.shade300 : Colors.green.shade300;
    Color textColor = isPending 
        ? (isDark ? Colors.orange.shade200 : Colors.orange.shade900)
        : (isDark ? Colors.green.shade200 : Colors.green.shade900);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withOpacity(0.5), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _isSyncing ? null : _manualSync,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Row(
            children: [
              _isSyncing
                  ? SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3, color: textColor))
                  : Icon(isPending ? Icons.sync_problem_rounded : Icons.cloud_done_rounded, color: textColor, size: 32),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isSyncing ? 'Synchronizing Data...' : 'Sync Status: ${vm.syncStatus}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPending
                          ? '${vm.pendingSyncCount} pending operations • Tap to push'
                          : 'System is fully synchronized with Cloud Firestore',
                      style: TextStyle(fontSize: 13, color: textColor.withOpacity(0.8), height: 1.2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradientCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                      child: Icon(icon, color: Colors.white, size: 28),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                  ],
                ),
                const SizedBox(height: 24),
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}