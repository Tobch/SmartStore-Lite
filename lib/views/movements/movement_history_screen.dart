import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/stock_movement_viewmodel.dart';

class MovementHistoryScreen extends StatefulWidget {
  final String? productId;
  final bool showOnlyToday; // Flag to trigger the today filter

  const MovementHistoryScreen({
    super.key, 
    this.productId, 
    this.showOnlyToday = false,
  });

  @override
  State<MovementHistoryScreen> createState() => _MovementHistoryScreenState();
}

class _MovementHistoryScreenState extends State<MovementHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StockMovementViewModel>().loadMovements(
        productId: widget.productId, 
        filterToday: widget.showOnlyToday,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final movementVM = context.watch<StockMovementViewModel>();
    final movements = movementVM.movements;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.showOnlyToday ? "Today's Movements" : 'Stock Movement History'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => context.read<StockMovementViewModel>().loadMovements(
          productId: widget.productId, 
          filterToday: widget.showOnlyToday,
        ),
        child: movementVM.isLoading
            ? const Center(child: CircularProgressIndicator())
            : movements.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        widget.showOnlyToday 
                            ? 'No movements recorded today.' 
                            : 'No movement records found.\nUse "Record Stock Movement" to log IN, OUT, or TRANSFER.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: movements.length,
                    itemBuilder: (context, index) {
                      final m = movements[index];
                      final type = m['movement_type']?.toString() ?? '';
                      
                      Color iconColor = Colors.blue;
                      IconData iconData = Icons.swap_horiz;
                      if (type == 'IN') {
                        iconColor = Colors.green;
                        iconData = Icons.add_box;
                      } else if (type == 'OUT') {
                        iconColor = Colors.red;
                        iconData = Icons.indeterminate_check_box;
                      } else if (type == 'TRANSFER') {
                        iconColor = Colors.orange;
                        iconData = Icons.compare_arrows;
                      }

                      final fromLoc = m['from_loc_name'] ?? '';
                      final toLoc = m['to_loc_name'] ?? '';
                      String route = '';
                      if (type == 'TRANSFER') {
                        route = '$fromLoc → $toLoc';
                      } else if (type == 'IN') {
                        route = 'To: $toLoc';
                      } else if (type == 'OUT') {
                        route = 'From: $fromLoc';
                      } else {
                        route = '$fromLoc';
                      }

                      String dateStr = m['timestamp']?.toString() ?? '';
                      if (dateStr.length >= 10) dateStr = dateStr.substring(0, 10);

                      return ListTile(
                        leading: Icon(iconData, color: iconColor, size: 32),
                        title: Text(
                          m['product_name'].toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('$type • Qty: ${m['quantity']} • $route'),
                        trailing: Text(dateStr),
                      );
                    },
                  ),
      ),
    );
  }
}