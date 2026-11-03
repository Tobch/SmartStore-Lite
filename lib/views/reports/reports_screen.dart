import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../viewmodels/reports_viewmodel.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportsViewModel>().loadReports();
    });
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && mounted) {
      context.read<ReportsViewModel>().setDateRange(picked.start, picked.end);
    }
  }

  void _exportCSV() async {
    final path = await context.read<ReportsViewModel>().exportToCSV();
    if (path != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report exported to: $path')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportsViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Export CSV',
            onPressed: vm.movementHistory.isNotEmpty ? _exportCSV : null,
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => context.read<ReportsViewModel>().loadReports(),
        child: vm.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Asset Distribution', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    _buildDonutChart(vm),
                    const SizedBox(height: 32),
                    const Divider(height: 1),
                    const SizedBox(height: 24),

                    Text('Fastest-Moving Products', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if (vm.fastestMoving.isEmpty)
                      _buildEmptyState('No stock-out movements yet. Record OUT movements to generate insights.')
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                        ),
                        child: Column(
                          children: vm.fastestMoving.map((item) => ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.trending_up, color: Colors.green, size: 20),
                            ),
                            title: Text(item['name'] ?? 'Product', style: const TextStyle(fontWeight: FontWeight.w600)),
                            trailing: Text('${item['total_out']} sold/out', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          )).toList(),
                        ),
                      ),
                    
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Movement Ledger', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          icon: const Icon(Icons.filter_list_rounded, size: 18),
                          label: const Text('Filter'),
                          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.primary),
                          onPressed: () => _pickDateRange(context),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (vm.movementHistory.isEmpty)
                      _buildEmptyState('No movements recorded yet in this date range.')
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: vm.movementHistory.length,
                        itemBuilder: (context, index) {
                          final move = vm.movementHistory[index];
                          String rawTime = move['timestamp']?.toString() ?? '';
                          String displayTime = rawTime.length >= 16 ? rawTime.substring(0, 16).replaceAll('T', ' ') : rawTime;
                          
                          Color iconColor;
                          IconData iconData;
                          if (move['movement_type'] == 'IN') {
                            iconColor = Colors.green;
                            iconData = Icons.call_received_rounded;
                          } else if (move['movement_type'] == 'OUT') {
                            iconColor = Colors.red;
                            iconData = Icons.call_made_rounded;
                          } else {
                            iconColor = Colors.blue;
                            iconData = Icons.sync_alt_rounded;
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12.0),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                child: Icon(iconData, color: iconColor),
                              ),
                              title: Text('${move['product_name'] ?? 'Product'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text('${move['movement_type']} • $displayTime\nBy ${move['user_name'] ?? 'Staff'}', style: const TextStyle(height: 1.4)),
                              ),
                              trailing: Text(
                                '${move['quantity']} U', 
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: iconColor)
                              ),
                            ),
                          );
                        },
                      )
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.analytics_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _buildDonutChart(ReportsViewModel vm) {
    if (vm.categoryStockValue.isEmpty) {
      return _buildEmptyState('Record an IN stock movement to see the asset breakdown.');
    }
    
    int colorIndex = 0;
    final List<Color> colors = [
      const Color(0xFF2196F3), // Blue
      const Color(0xFF00BFA5), // Teal
      const Color(0xFFFFCA28), // Amber
      const Color(0xFFAB47BC), // Purple
      const Color(0xFFFF7043), // Deep Orange
      const Color(0xFF5C6BC0), // Indigo
      const Color(0xFFEC407A), // Pink
    ];

    double totalValue = 0;
    for (var val in vm.categoryStockValue.values) {
      totalValue += val;
    }

    final sections = vm.categoryStockValue.entries.map((entry) {
      final color = colors[colorIndex % colors.length];
      colorIndex++;
      return PieChartSectionData(
        value: entry.value,
        title: '', // Hide inline titles for a cleaner modern look
        color: color,
        radius: 25, // Slim donut ring
      );
    }).toList();

    colorIndex = 0;
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 60,
                    sectionsSpace: 4,
                    startDegreeOffset: -90,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Total Value', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    const SizedBox(height: 4),
                    Text(
                      '${(totalValue / 1000).toStringAsFixed(1)}k', 
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: vm.categoryStockValue.entries.map((entry) {
                final color = colors[colorIndex % colors.length];
                colorIndex++;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(entry.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                      ),
                      Text('EGP ${entry.value.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}