import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../database/db_helper.dart';
import 'notification_service.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DBHelper _dbHelper = DBHelper.instance;

  /// Syncs all queued changes in SQLite [pending_changes] to Firebase Firestore.
  /// Returns the number of changes successfully uploaded.
  Future<int> syncPendingChanges() async {
    final Database db = await _dbHelper.database;
    
    final pendingChanges = await db.query(
      'pending_changes',
      orderBy: 'created_at ASC',
    );

    if (pendingChanges.isEmpty) {
      return 0;
    }

    int syncedCount = 0;
    int conflictCount = 0;

    for (var change in pendingChanges) {
      String id = change['id'].toString();
      String tableName = change['table_name'].toString();
      String recordId = change['record_id'].toString();
      
      Map<String, dynamic> payload;
      try {
        payload = jsonDecode(change['payload'].toString());
      } catch (e) {
        // If payload is corrupted, delete the pending entry to avoid permanent blocking
        await db.delete('pending_changes', where: 'id = ?', whereArgs: [id]);
        continue;
      }

      try {
        if (tableName == 'stock_movements') {
          bool hadConflict = await _handleStockMovementSync(db, recordId, payload);
          if (hadConflict) conflictCount++;
        } else {
          // Push products, locations, etc. to Firestore
          await _firestore
              .collection(tableName)
              .doc(recordId)
              .set(payload, SetOptions(merge: true));
        }

        // On success, remove from SQLite pending queue
        await db.delete('pending_changes', where: 'id = ?', whereArgs: [id]);
        syncedCount++;
      } catch (e) {
        debugPrint('Sync error on table $tableName (record $recordId): $e');
        // Increment retry count
        await db.rawUpdate(
          'UPDATE pending_changes SET retry_count = retry_count + 1 WHERE id = ?',
          [id],
        );
      }
    }

    // Trigger local notification if sync uploaded records or had conflicts
    if (syncedCount > 0) {
      if (conflictCount > 0) {
        await NotificationService.showNotification(
          id: 101,
          title: 'Sync Completed with Conflicts',
          body: '$syncedCount changes synced. $conflictCount items flagged for manager review.',
        );
      } else {
        await NotificationService.showNotification(
          id: 100,
          title: 'Sync Complete',
          body: 'All $syncedCount pending changes uploaded to Firestore.',
        );
      }
    }

    return syncedCount;
  }

  Future<bool> _handleStockMovementSync(
    Database db,
    String recordId,
    Map<String, dynamic> payload,
  ) async {
    bool isConflict = false;

    // Conflict Resolution: Check if this movement would cause negative stock in cloud
    if (payload['movement_type'] == 'OUT' || payload['movement_type'] == 'TRANSFER') {
      String? fromLoc = payload['from_location_id'];
      String prodId = payload['product_id'];
      int qty = (payload['quantity'] as num).toInt();

      if (fromLoc != null) {
        try {
          // Query cloud stock ledger for this product
          final cloudDocs = await _firestore
              .collection('stock_movements')
              .where('product_id', isEqualTo: prodId)
              .get();

          int cloudStock = 0;
          for (var doc in cloudDocs.docs) {
            if (doc.id == recordId) continue; // Skip self if retrying
            final data = doc.data();
            if (data['to_location_id'] == fromLoc) {
              cloudStock += (data['quantity'] as num? ?? 0).toInt();
            }
            if (data['from_location_id'] == fromLoc) {
              cloudStock -= (data['quantity'] as num? ?? 0).toInt();
            }
          }

          // If available stock in cloud is less than required quantity, flag as CONFLICT
          if ((cloudStock - qty) < 0) {
            isConflict = true;
            payload['sync_status'] = 'CONFLICT';

            await _firestore.collection('sync_conflicts').add({
              'movementId': recordId,
              'productId': prodId,
              'fromLocationId': fromLoc,
              'requestedQty': qty,
              'availableInCloud': cloudStock,
              'reason': 'Negative stock would be generated in cloud ledger',
              'status': 'PENDING_MANAGER_REVIEW',
              'createdAt': DateTime.now().toIso8601String(),
            });
          } else {
            payload['sync_status'] = 'SYNCED';
          }
        } catch (e) {
          // If query fails, default to SYNCED
          payload['sync_status'] = 'SYNCED';
        }
      } else {
        payload['sync_status'] = 'SYNCED';
      }
    } else {
      payload['sync_status'] = 'SYNCED';
    }

    // Write to Firestore with specific device ID to prevent duplicate records
    await _firestore
        .collection('stock_movements')
        .doc(recordId)
        .set(payload, SetOptions(merge: true));

    // Update local SQLite sync status
    await db.update(
      'stock_movements',
      {'sync_status': payload['sync_status']},
      where: 'id = ?',
      whereArgs: [recordId],
    );

    return isConflict;
  }
}
