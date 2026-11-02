import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/product_viewmodel.dart';
import '../../viewmodels/stock_movement_viewmodel.dart';
import '../../core/services/sync_service.dart';

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
      // Attempt background sync on screen load
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboardVM = context.watch<DashboardViewModel>();
    final authVM = context.watch<AuthViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync Now',
            onPressed: _isSyncing ? null : _manualSync,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await authVM.logout();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New Movement'),
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
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sync Status Indicator with tap-to-sync
                    _buildSyncStatusCard(context, dashboardVM),
                    const SizedBox(height: 24),
                    
                    // Metrics Grid (Responsive Wrap)
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        _buildMetricCard(
                          context,
                          title: 'Total Stock Value',
                          value: 'EGP ${dashboardVM.totalStockValue.toStringAsFixed(2)}',
                          icon: Icons.account_balance_wallet,
                          color: Theme.of(context).colorScheme.primary,
                          onTap: () {
                            context.read<ProductViewModel>().setLowStockFilter(false);
                            Navigator.pushNamed(context, '/products');
                          },
                        ),
                        _buildMetricCard(
                          context,
                          title: 'Low-Stock Products',
                          value: '${dashboardVM.lowStockCount}',
                          icon: Icons.warning_amber_rounded,
                          color: Theme.of(context).colorScheme.error,
                          onTap: () {
                            // Filter products list to only show low-stock items
                            context.read<ProductViewModel>().setLowStockFilter(true);
                            Navigator.pushNamed(context, '/products');
                          },
                        ),
                        _buildMetricCard(
                          context,
                          title: "Today's Movements",
                          value: '${dashboardVM.todaysMovements}',
                          icon: Icons.swap_horiz,
                          color: Theme.of(context).colorScheme.secondary,
                          onTap: () {
                            context.read<StockMovementViewModel>().loadMovements();
                            Navigator.pushNamed(context, '/movement_history');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSyncStatusCard(BuildContext context, DashboardViewModel vm) {
    bool isPending = vm.pendingSyncCount > 0;
    return Card(
      color: isPending ? Colors.orange.shade100 : Colors.green.shade100,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _isSyncing ? null : _manualSync,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              _isSyncing
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Icon(
                      isPending ? Icons.sync_problem : Icons.cloud_done,
                      color: isPending ? Colors.orange.shade800 : Colors.green.shade800,
                      size: 28,
                    ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isSyncing ? 'Syncing with Firebase...' : 'Sync Status: ${vm.syncStatus}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isPending ? Colors.orange.shade900 : Colors.green.shade900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPending
                          ? '${vm.pendingSyncCount} changes waiting • Tap to upload now'
                          : 'All changes synced with cloud Firestore',
                      style: TextStyle(
                        fontSize: 12,
                        color: isPending ? Colors.orange.shade800 : Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              if (isPending && !_isSyncing)
                IconButton(
                  icon: const Icon(Icons.cloud_upload),
                  color: Colors.orange.shade900,
                  tooltip: 'Upload now',
                  onPressed: _manualSync,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    double width = MediaQuery.of(context).size.width > 600 
      ? (MediaQuery.of(context).size.width / 3) - 24 
      : (MediaQuery.of(context).size.width / 2) - 24;

    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 32, color: color),
                const SizedBox(height: 16),
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value, 
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
