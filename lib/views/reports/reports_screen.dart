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
            icon: const Icon(Icons.download),
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
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stock Value by Category', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    _buildPieChart(vm),
                    const Divider(height: 48),

                    Text('Fastest-Moving Products', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    if (vm.fastestMoving.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'No stock-out movements yet. Record OUT movements to see fastest moving products.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ...vm.fastestMoving.map((item) => ListTile(
                            leading: const Icon(Icons.trending_up, color: Colors.green),
                            title: Text(item['name'] ?? 'Product'),
                            trailing: Text('${item['total_out']} sold/out', style: const TextStyle(fontWeight: FontWeight.bold)),
                          )),
                    const Divider(height: 48),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Movement History', style: Theme.of(context).textTheme.titleLarge),
                        TextButton.icon(
                          icon: const Icon(Icons.date_range),
                          label: const Text('Filter Dates'),
                          onPressed: () => _pickDateRange(context),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (vm.movementHistory.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'No movements recorded yet. Record stock movements to see history.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
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
                            iconData = Icons.arrow_downward;
                          } else if (move['movement_type'] == 'OUT') {
                            iconColor = Colors.red;
                            iconData = Icons.arrow_upward;
                          } else {
                            iconColor = Colors.blue;
                            iconData = Icons.swap_horiz;
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8.0),
                            child: ListTile(
                              leading: Icon(iconData, color: iconColor),
                              title: Text('${move['product_name'] ?? 'Product'}'),
                              subtitle: Text('${move['movement_type']} • $displayTime • By ${move['user_name'] ?? 'Staff'}'),
                              trailing: Text(
                                '${move['quantity']}', 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
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

  Widget _buildPieChart(ReportsViewModel vm) {
    if (vm.categoryStockValue.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'No stock data available yet.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Record an IN stock movement to see category breakdown.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    
    int colorIndex = 0;
    final List<Color> colors = [
      Colors.blue,
      Colors.teal,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.amber,
      Colors.indigo,
    ];

    final sections = vm.categoryStockValue.entries.map((entry) {
      final color = colors[colorIndex % colors.length];
      colorIndex++;
      return PieChartSectionData(
        value: entry.value,
        title: 'EGP ${entry.value.toStringAsFixed(0)}',
        color: color,
        radius: 65,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    colorIndex = 0;
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 35,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: vm.categoryStockValue.entries.map((entry) {
            final color = colors[colorIndex % colors.length];
            colorIndex++;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('${entry.key}: EGP ${entry.value.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}
