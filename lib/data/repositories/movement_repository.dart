import 'dart:convert';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../core/database/db_helper.dart';
import '../models/stock_movement_model.dart';
import 'package:uuid/uuid.dart';

class MovementRepository {
  final DBHelper _dbHelper = DBHelper.instance;

  // Calculates current stock dynamically using SQL aggregations (Ledger Engine)
  Future<int> calculateStock(String productId, String locationId) async {
    final db = await _dbHelper.database;
    
    // FIX: Let Dart infer the type to prevent generic bracket parsing errors
    final result = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN to_location_id = ? THEN quantity ELSE 0 END), 0) - 
        COALESCE(SUM(CASE WHEN from_location_id = ? THEN quantity ELSE 0 END), 0) as current_stock
      FROM stock_movements 
      WHERE product_id = ?
    ''', [locationId, locationId, productId]);

    if (result.isNotEmpty && result.first['current_stock'] != null) {
      return (result.first['current_stock'] as num).toInt();
    }
    return 0;
  }

  // Executes a transfer as ONE atomic database transaction, queueing it for sync
  Future<void> recordTransfer(StockMovementModel movement) async {
    final db = await _dbHelper.database;
    
    // Validate stock-out doesn't exceed available quantity
    int currentStock = await calculateStock(movement.productId, movement.fromLocationId!);
    if (movement.quantity > currentStock) {
      throw Exception('Stock out cannot exceed available quantity');
    }

    await db.transaction((txn) async {
      // 1. Insert Movement Record
      await txn.insert('stock_movements', movement.toMap());

      // 2. Add to Pending Changes Queue for Offline-First sync
      await txn.insert('pending_changes', {
        'id': const Uuid().v4(),
        'table_name': 'stock_movements',
        'record_id': movement.id,
        'action_type': 'CREATE',
        'payload': jsonEncode(movement.toMap()),
        'created_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
      });
    });
  }
}