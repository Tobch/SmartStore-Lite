import 'package:flutter/material.dart';
import '../core/database/db_helper.dart';

class DashboardViewModel extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper.instance;

  double _totalStockValue = 0.0;
  int _lowStockCount = 0;
  int _todaysMovements = 0;
  int _pendingSyncCount = 0;
  bool _isLoading = true;

  double get totalStockValue => _totalStockValue;
  int get lowStockCount => _lowStockCount;
  int get todaysMovements => _todaysMovements;
  int get pendingSyncCount => _pendingSyncCount;
  bool get isLoading => _isLoading;

  String get syncStatus {
    if (_pendingSyncCount > 0) return 'Changes Waiting';
    return 'Synced / Online';
  }

  Future<void> loadDashboardMetrics() async {
    _isLoading = true;
    notifyListeners();

    final db = await _dbHelper.database;

    // 1. Calculate Company-Wide Total Stock Value & Low Stock Count from Ledger
    final stockQuery = await db.rawQuery('''
      SELECT 
        p.id, p.price, p.min_stock_threshold,
        COALESCE((SELECT SUM(quantity) FROM stock_movements WHERE product_id = p.id AND (movement_type = 'IN' OR (movement_type = 'ADJUSTMENT' AND to_location_id IS NOT NULL))), 0) - 
        COALESCE((SELECT SUM(quantity) FROM stock_movements WHERE product_id = p.id AND (movement_type = 'OUT' OR (movement_type = 'ADJUSTMENT' AND from_location_id IS NOT NULL))), 0) as current_stock
      FROM products p
    ''');

    _totalStockValue = 0.0;
    _lowStockCount = 0;

    for (var row in stockQuery) {
      int stock = (row['current_stock'] as num).toInt();
      double price = (row['price'] as num).toDouble();
      int threshold = (row['min_stock_threshold'] as num).toInt();

      _totalStockValue += (stock * price);
      if (stock < threshold) _lowStockCount++;
    }

    // 2. Count Today's Movements
    String todayDatePrefix = DateTime.now().toIso8601String().substring(0, 10);
    final moveQuery = await db.rawQuery('''
      SELECT COUNT(*) as count FROM stock_movements 
      WHERE timestamp LIKE ?
    ''', ['$todayDatePrefix%']);
    
    _todaysMovements = (moveQuery.first['count'] as num).toInt();

    // 3. Count Pending Sync Changes Queue
    final syncQuery = await db.rawQuery('SELECT COUNT(*) as count FROM pending_changes');
    _pendingSyncCount = (syncQuery.first['count'] as num).toInt();

    _isLoading = false;
    notifyListeners();
  }
}
