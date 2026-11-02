import 'package:uuid/uuid.dart';

class ProductModel {
  final String id;
  final String barcode;
  final String name;
  final String? brand;
  final String category;
  final String? imageUrl;
  final double price;
  final int minStockThreshold;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductModel({
    String? id,
    required this.barcode,
    required this.name,
    this.brand,
    required this.category,
    this.imageUrl,
    required this.price,
    this.minStockThreshold = 5,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'barcode': barcode,
      'name': name,
      'brand': brand,
      'category': category,
      'image_url': imageUrl,
      'price': price,
      'min_stock_threshold': minStockThreshold,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] as String,
      barcode: map['barcode'] as String,
      name: map['name'] as String,
      brand: map['brand'] as String?,
      category: map['category'] as String,
      imageUrl: map['image_url'] as String?,
      price: (map['price'] as num).toDouble(),
      minStockThreshold: (map['min_stock_threshold'] as num).toInt(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}