import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import '../core/database/db_helper.dart';

class ReportsViewModel extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper.instance;

  bool _isLoading = false;
  String? _errorMessage;
  
  Map<String, double> _categoryStockValue = {};
  List _fastestMoving = [];
  List _movementHistory = [];
  
  DateTime? _startDate;
  DateTime? _endDate;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, double> get categoryStockValue => _categoryStockValue;
  List get fastestMoving => _fastestMoving;
  List get movementHistory => _movementHistory;

  Future<void> loadReports() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final db = await _dbHelper.database;

      // 1. Calculate stock value per category from ledger
      final valueQuery = await db.rawQuery('''
        SELECT p.category, 
          SUM(
            p.price * (
              COALESCE((SELECT SUM(quantity) FROM stock_movements WHERE product_id = p.id AND (movement_type = 'IN' OR (movement_type = 'ADJUSTMENT' AND to_location_id IS NOT NULL))), 0) - 
              COALESCE((SELECT SUM(quantity) FROM stock_movements WHERE product_id = p.id AND (movement_type = 'OUT' OR (movement_type = 'ADJUSTMENT' AND from_location_id IS NOT NULL))), 0)
            )
          ) as total_value
        FROM products p
        GROUP BY p.category
      ''');

      _categoryStockValue = {};
      for (var row in valueQuery) {
        if (row['total_value'] != null) {
          double val = (row['total_value'] as num).toDouble();
          if (val > 0) {
            _categoryStockValue[row['category'] as String] = val;
          }
        }
      }

      // 2. Fastest moving products based on OUT movements
      _fastestMoving = await db.rawQuery('''
        SELECT p.name, SUM(s.quantity) as total_out
        FROM stock_movements s
        JOIN products p ON s.product_id = p.id
        WHERE s.movement_type = 'OUT'
        GROUP BY p.id, p.name
        ORDER BY total_out DESC
        LIMIT 5
      ''');

      // 3. Movement history with safe LEFT JOIN on users
      await _loadMovementHistory();

    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setDateRange(DateTime start, DateTime end) async {
    _startDate = start;
    _endDate = end;
    _isLoading = true;
    notifyListeners();
    
    await _loadMovementHistory();
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadMovementHistory() async {
    final db = await _dbHelper.database;
    
    String query = '''
      SELECT s.timestamp, s.movement_type, s.quantity, p.name as product_name, COALESCE(u.name, 'Staff') as user_name
      FROM stock_movements s
      JOIN products p ON s.product_id = p.id
      LEFT JOIN users u ON s.user_id = u.id
    ''';
    
    List args = [];
    if (_startDate != null && _endDate != null) {
      query += ' WHERE s.timestamp >= ? AND s.timestamp <= ?';
      args.add(_startDate!.toIso8601String().substring(0, 10));
      args.add('${_endDate!.toIso8601String().substring(0, 10)}T23:59:59');
    }
    query += ' ORDER BY s.timestamp DESC';

    _movementHistory = await db.rawQuery(query, args);
  }

  Future<String?> exportToCSV() async {
    try {
      List<List<dynamic>> rows = [];
      rows.add(["Date", "Type", "Product", "Quantity", "User"]);

      for (var row in _movementHistory) {
        rows.add([
          row['timestamp'],
          row['movement_type'],
          row['product_name'],
          row['quantity'],
          row['user_name']
        ]);
      }

      String csvData = const ListToCsvConverter().convert(rows);

      Directory directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final file = File('${directory.path}/movement_report_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvData);

      return file.path;
    } catch (e) {
      _errorMessage = 'Export failed: $e';
      notifyListeners();
      return null;
    }
  }
}
