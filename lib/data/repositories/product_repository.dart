import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:sqflite_sqlcipher/sqflite.dart'; // FIX: Required for ConflictAlgorithm and Database types
import '../../core/network/api_client.dart';
import '../../core/database/db_helper.dart';
import '../models/product_model.dart';
import 'package:uuid/uuid.dart';

class ProductRepository {
  final ApiClient _apiClient = ApiClient();
  final DBHelper _dbHelper = DBHelper.instance;

  // Fetch from Open Food Facts API with local caching fallback
  Future<Map<String, dynamic>?> lookupBarcodeAPI(String barcode) async {
    try {
      final response = await _apiClient.client.get('product/$barcode.json');
      
      if (response.data != null && response.data['status'] == 1) {
        final productData = response.data['product'];
        
        // Cache the raw JSON response in SQLite for offline capability
        final db = await _dbHelper.database;
        await db.insert(
          'api_cache', 
          {
            'barcode': barcode,
            'json_data': jsonEncode(response.data),
            'cached_at': DateTime.now().toIso8601String(),
          }, 
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        return {
          'name': productData['product_name'] ?? '',
          'brand': productData['brands'] ?? '',
          'category': productData['categories']?.split(',').first ?? 'Uncategorized',
          'imageUrl': productData['image_url'] ?? '',
        };
      }
      return null;
    } on DioException {
      // Offline fallback: load from local SQLite cache
      final db = await _dbHelper.database;
      final cached = await db.query('api_cache', where: 'barcode = ?', whereArgs: [barcode]);
      
      if (cached.isNotEmpty) {
        final data = jsonDecode(cached.first['json_data'] as String);
        if (data['status'] == 1) {
          final productData = data['product'];
          return {
            'name': productData['product_name'] ?? '',
            'brand': productData['brands'] ?? '',
            'category': productData['categories']?.split(',').first ?? 'Uncategorized',
            'imageUrl': productData['image_url'] ?? '',
          };
        }
      }
      rethrow; 
    }
  }

  // Save product to local SQLite database and queue for Firebase sync
  Future<void> saveProduct(ProductModel product) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.insert(
        'products', 
        product.toMap(), 
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      await txn.insert('pending_changes', {
        'id': const Uuid().v4(),
        'table_name': 'products',
        'record_id': product.id,
        'action_type': 'CREATE',
        'payload': jsonEncode(product.toMap()),
        'created_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
      });
    });
  }

  // Fetch all products stored locally
  Future<List<ProductModel>> getAllProducts() async {
    final db = await _dbHelper.database;
    final maps = await db.query('products', orderBy: 'name ASC');
    return maps.map((map) => ProductModel.fromMap(map)).toList();
  }
}