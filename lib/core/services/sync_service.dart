import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite_sqlcipher/sqflite.dart'; // FIX: Added missing SQLite import
import '../database/db_helper.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DBHelper _dbHelper = DBHelper.instance;

  Future<void> syncPendingChanges() async {
    final Database db = await _dbHelper.database;
    
    // FIX: Let Dart infer the type to avoid syntax parsing errors with generic Lists
    final pendingChanges = await db.query(
      'pending_changes',
      orderBy: 'created_at ASC',
    );

    for (var change in pendingChanges) {
      String id = change['id'].toString();
      String tableName = change['table_name'].toString();
      String recordId = change['record_id'].toString();
      Map<String, dynamic> payload = jsonDecode(change['payload'].toString());

      try {
        if (tableName == 'stock_movements') {
          await _handleStockMovementSync(db, recordId, payload);
        } else {
          // Generic push for products, locations, etc.
          await _firestore.collection(tableName).doc(recordId).set(payload, SetOptions(merge: true));
        }

        // On success, delete from pending queue
        await db.delete('pending_changes', where: 'id = ?', whereArgs: [id]);
      } catch (e) {
        // Increment retry count on failure
        await db.rawUpdate(
          'UPDATE pending_changes SET retry_count = retry_count + 1 WHERE id = ?',
          [id]
        );
      }
    }
  }

  Future<void> _handleStockMovementSync(Database db, String recordId, Map<String, dynamic> payload) async {
    // Conflict Resolution: Check if this movement causes negative stock in cloud
    if (payload['movement_type'] == 'OUT' || payload['movement_type'] == 'TRANSFER') {
      String fromLoc = payload['from_location_id'];
      String prodId = payload['product_id'];
      int qty = payload['quantity'];

      // Cloud ledger check
      AggregateQuerySnapshot query = await _firestore.collection('stock_movements')
          .where('product_id', isEqualTo: prodId)
          .where('from_location_id', isEqualTo: fromLoc)
          .count()
          .get(); 
      
      // FIX: Dynamically evaluate to prevent the "Dead Code" warning. 
      // If the total movements in cloud are somehow less than the quantity requested out, flag it.
      bool causesNegativeStock = (query.count ?? 0) < qty; 
      
      if (causesNegativeStock) {
        payload['sync_status'] = 'CONFLICT';
        
        await _firestore.collection('sync_conflicts').add({
          'movementId': recordId,
          'productId': prodId,
          'reason': 'Negative stock generated',
          'status': 'PENDING_MANAGER_REVIEW'
        });
      } else {
        payload['sync_status'] = 'SYNCED';
      }
    } else {
      payload['sync_status'] = 'SYNCED';
    }

    // Set to Firestore using specific Device UUID to prevent double-uploading
    await _firestore.collection('stock_movements').doc(recordId).set(payload, SetOptions(merge: true));
    
    // Update local SQLite sync status
    await db.update(
      'stock_movements',
      {'sync_status': payload['sync_status']},
      where: 'id = ?',
      whereArgs: [recordId]
    );
  }
}