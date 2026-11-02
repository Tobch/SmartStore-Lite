import 'package:uuid/uuid.dart';

class StockMovementModel {
  final String id;
  final String productId;
  final String movementType; // 'IN', 'OUT', 'ADJUSTMENT', 'TRANSFER'
  final String? fromLocationId;
  final String? toLocationId;
  final int quantity;
  final String userId;
  final DateTime timestamp;
  final String syncStatus; // 'PENDING', 'SYNCED', 'CONFLICT'

  StockMovementModel({
    String? id,
    required this.productId,
    required this.movementType,
    this.fromLocationId,
    this.toLocationId,
    required this.quantity,
    required this.userId,
    DateTime? timestamp,
    this.syncStatus = 'PENDING',
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'movement_type': movementType,
      'from_location_id': fromLocationId,
      'to_location_id': toLocationId,
      'quantity': quantity,
      'user_id': userId,
      'timestamp': timestamp.toIso8601String(),
      'sync_status': syncStatus,
    };
  }

  factory StockMovementModel.fromMap(Map<String, dynamic> map) {
    return StockMovementModel(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      movementType: map['movement_type'] as String,
      fromLocationId: map['from_location_id'] as String?,
      toLocationId: map['to_location_id'] as String?,
      quantity: map['quantity'] as int,
      userId: map['user_id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      syncStatus: map['sync_status'] as String,
    );
  }
}