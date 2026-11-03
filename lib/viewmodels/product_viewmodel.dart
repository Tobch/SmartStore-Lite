import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import '../data/models/product_model.dart';
import '../data/repositories/product_repository.dart';
import '../core/network/interceptors/error_interceptor.dart';
import '../core/database/db_helper.dart';
import '../core/services/sync_service.dart';

class ProductViewModel extends ChangeNotifier {
  final ProductRepository _repository = ProductRepository();
  final SyncService _syncService = SyncService();
  
  List<ProductModel> _products = [];
  List<ProductModel> _filteredProducts = [];
  Map<String, int> _productStock = {};
  bool _isLoading = false;
  String _searchQuery = '';
  bool _onlyLowStock = false;
  ProductModel? _selectedProduct;

  List<ProductModel> get filteredProducts => _filteredProducts;
  bool get isLoading => _isLoading;
  bool get onlyLowStock => _onlyLowStock;
  ProductModel? get selectedProduct => _selectedProduct;

  int getProductStock(String productId) => _productStock[productId] ?? 0;

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();
    
    _products = await _repository.getAllProducts();

    // Corrected SQL aggregation to prevent double-counting
    // Adds stock arriving from outside (IN/Increase) and subtracts stock leaving (OUT/Decrease)
    // Completely ignores internal location-to-location TRANSFERs.
    final db = await DBHelper.instance.database;
    final stockRows = await db.rawQuery('''
      SELECT product_id,
        COALESCE(SUM(CASE WHEN from_location_id IS NULL AND to_location_id IS NOT NULL THEN quantity ELSE 0 END), 0) -
        COALESCE(SUM(CASE WHEN from_location_id IS NOT NULL AND to_location_id IS NULL THEN quantity ELSE 0 END), 0) as total_stock
      FROM stock_movements
      GROUP BY product_id
    ''');

    _productStock = {};
    for (var row in stockRows) {
      if (row['product_id'] != null) {
        _productStock[row['product_id'] as String] = (row['total_stock'] as num? ?? 0).toInt();
      }
    }

    _applyFilters();
    
    _isLoading = false;
    notifyListeners();
  }

  void searchProducts(String query) {
    _searchQuery = query.toLowerCase();
    _applyFilters();
  }

  void setLowStockFilter(bool onlyLowStock) {
    _onlyLowStock = onlyLowStock;
    _applyFilters();
  }

  void selectProduct(ProductModel? product) {
    _selectedProduct = product;
    notifyListeners();
  }

  void _applyFilters() {
    _filteredProducts = _products.where((p) {
      final matchesSearch = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery) || 
          p.barcode.contains(_searchQuery) ||
          p.category.toLowerCase().contains(_searchQuery);

      if (!matchesSearch) return false;

      if (_onlyLowStock) {
        final stock = getProductStock(p.id);
        return stock < p.minStockThreshold;
      }

      return true;
    }).toList();
    notifyListeners();
  }

  // Lookup Barcode via API
  Future<dynamic> lookupBarcode(String barcode) async {
    try {
      return await _repository.lookupBarcodeAPI(barcode);
    } on DioException catch (e) {
      if (e.error is ProductNotFoundException) {
        throw e.error!;
      }
      rethrow;
    }
  }

  // Save Product and push to sync
  Future<void> addProduct(ProductModel product) async {
    _isLoading = true;
    notifyListeners();

    await _repository.saveProduct(product);
    await loadProducts();

    // Trigger sync in background
    _syncService.syncPendingChanges();

    _isLoading = false;
    notifyListeners();
  }
}