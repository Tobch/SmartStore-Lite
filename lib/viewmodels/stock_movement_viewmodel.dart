import 'package:flutter/material.dart';
import '../data/models/product_model.dart';
import '../data/models/location_model.dart';
import '../data/models/stock_movement_model.dart';
import '../data/repositories/product_repository.dart';
import '../data/repositories/location_repository.dart';
import '../data/repositories/movement_repository.dart';
import '../core/database/db_helper.dart';
import '../core/services/sync_service.dart';
import '../core/services/notification_service.dart';
import 'auth_viewmodel.dart';

class StockMovementViewModel extends ChangeNotifier {
  final ProductRepository _productRepo = ProductRepository();
  final LocationRepository _locationRepo = LocationRepository();
  final MovementRepository _movementRepo = MovementRepository();
  final SyncService _syncService = SyncService();

  List<ProductModel> _products = [];
  List<LocationModel> _locations = [];
  List<Map<String, Object?>> _movements = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ProductModel> get products => _products;
  List<LocationModel> get locations => _locations;
  List<Map<String, Object?>> get movements => _movements;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadFormData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await _locationRepo.seedDefaultLocations();
    _products = await _productRepo.getAllProducts();
    _locations = await _locationRepo.getAllLocations();

    _isLoading = false;
    notifyListeners();
  }

  // Loads full movement history with product and location names
  Future<void> loadMovements({String? productId, bool filterToday = false}) async {
    _isLoading = true;
    notifyListeners();

    final db = await DBHelper.instance.database;
    String query = '''
      SELECT s.*, COALESCE(p.name, 'Unknown Product') as product_name,
             COALESCE(fl.name, 'Supplier / Ext') as from_loc_name,
             COALESCE(tl.name, 'Customer / Ext') as to_loc_name,
             COALESCE(u.name, 'Staff') as user_name
      FROM stock_movements s
      LEFT JOIN products p ON s.product_id = p.id
      LEFT JOIN locations fl ON s.from_location_id = fl.id
      LEFT JOIN locations tl ON s.to_location_id = tl.id
      LEFT JOIN users u ON s.user_id = u.id
      WHERE 1=1
    ''';
    
    List<dynamic> args = [];

    if (productId != null) {
      query += ' AND s.product_id = ?';
      args.add(productId);
    }
    
    // ADDED: Filter logic for 'Today's Movements'
    if (filterToday) {
      // Get current date string in UTC (matches SQLite datetime format)
      String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      query += " AND date(s.timestamp) = date(?)";
      args.add(today);
    }
    
    query += ' ORDER BY s.timestamp DESC';

    _movements = await db.rawQuery(query, args);
    _isLoading = false;
    notifyListeners();
  }

  Future<int> getAvailableStock(String productId, String locationId) async {
    return await _movementRepo.calculateStock(productId, locationId);
  }

  Future<bool> recordMovement({
    required AuthViewModel authVM,
    required String movementType,
    required String productId,
    required int quantity,
    required String? fromLocationId,
    required String? toLocationId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = authVM.currentUser?.id ?? 'UNKNOWN_USER';

      // Validation Rules
      if (quantity <= 0) {
        throw Exception('Quantity must be a positive whole number.');
      }

      if (movementType == 'TRANSFER') {
        if (fromLocationId == null || toLocationId == null) {
          throw Exception('Transfer requires both source and destination locations.');
        }
        if (fromLocationId == toLocationId) {
          throw Exception('Source and destination locations must differ.');
        }
      }

      if (movementType == 'OUT' && fromLocationId == null) {
        throw Exception('Source location is required for Stock Out.');
      }

      if (movementType == 'IN' && toLocationId == null) {
        throw Exception('Destination location is required for Stock In.');
      }

      // Check available stock if goods are leaving a location
      if (fromLocationId != null) {
        int currentStock = await _movementRepo.calculateStock(productId, fromLocationId);
        if (quantity > currentStock) {
          throw Exception('Stock out cannot exceed available quantity. (Available: $currentStock)');
        }
      }

      final movement = StockMovementModel(
        productId: productId,
        movementType: movementType,
        fromLocationId: fromLocationId,
        toLocationId: toLocationId,
        quantity: quantity,
        userId: userId,
      );

      // Record transaction locally in SQLite
      await _movementRepo.recordTransfer(movement);

      // Check Stock Alert Threshold and Trigger Notification
      ProductModel? affectedProduct;
      try {
        affectedProduct = _products.firstWhere((p) => p.id == productId);
      } catch (e) {
        affectedProduct = null;
      }

      if (affectedProduct != null && (movementType == 'OUT' || movementType == 'TRANSFER')) {
        int newStockAtSource = await _movementRepo.calculateStock(productId, fromLocationId!);
        
        if (newStockAtSource < affectedProduct.minStockThreshold) {
          // FIXED: Use static method call and provide required 'id' parameter
          NotificationService.showNotification(
            id: affectedProduct.id.hashCode, // Uses a unique integer based on the product ID
            title: 'Low Stock Alert ⚠️',
            body: '${affectedProduct.name} stock has dropped to $newStockAtSource units.',
          );
        }
      }

      // Reload local movements list
      await loadMovements();

      // Trigger automatic sync with Firebase in background
      _syncService.syncPendingChanges();

      _isLoading = false;
      notifyListeners();
      return true;

    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}