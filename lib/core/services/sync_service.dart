import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../database/db_helper.dart';
import 'notification_service.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DBHelper _dbHelper = DBHelper.instance;
  final List<StreamSubscription> _remoteSubscriptions = [];

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> startRealtimeSync() async {
    await pullRemoteChanges();
    await syncPendingChanges();

    if (_remoteSubscriptions.isNotEmpty) {
      return;
    }

    final collections = ['users', 'locations', 'products', 'stock_movements'];

    for (final collectionName in collections) {
      final subscription = _firestore
          .collection(collectionName)
          .snapshots()
          .listen((snapshot) async {
        try {
          await _applyRemoteSnapshot(collectionName, snapshot);
        } catch (e) {
          debugPrint('Remote sync listener error for $collectionName: $e');
        }
      });

      _remoteSubscriptions.add(subscription);
    }
  }

  Future<void> stopRealtimeSync() async {
    for (final subscription in _remoteSubscriptions) {
      await subscription.cancel();
    }
    _remoteSubscriptions.clear();
  }

  Map<String, dynamic> _normalizeForSqlite(
    String collectionName,
    Map<String, dynamic> data,
  ) {
    final normalized = <String, dynamic>{};

    for (final entry in data.entries) {
      var value = entry.value;
      if (value is Timestamp) {
        value = value.toDate().toIso8601String();
      }
      normalized[entry.key] = value;
    }

    if (normalized['id'] == null && normalized.containsKey('docId')) {
      normalized['id'] = normalized['docId'];
    }

    switch (collectionName) {
      case 'users':
        if (normalized.containsKey('defaultLocationId') &&
            !normalized.containsKey('default_location_id')) {
          normalized['default_location_id'] = normalized['defaultLocationId'];
        }
        normalized.remove('defaultLocationId');
        break;
      case 'locations':
        if (normalized.containsKey('isWarehouse') &&
            !normalized.containsKey('is_warehouse')) {
          normalized['is_warehouse'] = normalized['isWarehouse'] == true ||
                  normalized['isWarehouse'] == 1
              ? 1
              : 0;
        }
        normalized.remove('isWarehouse');
        break;
      case 'products':
        if (normalized.containsKey('imageUrl') &&
            !normalized.containsKey('image_url')) {
          normalized['image_url'] = normalized['imageUrl'];
        }
        if (normalized.containsKey('minStockThreshold') &&
            !normalized.containsKey('min_stock_threshold')) {
          normalized['min_stock_threshold'] = normalized['minStockThreshold'];
        }
        if (normalized.containsKey('createdAt') &&
            !normalized.containsKey('created_at')) {
          normalized['created_at'] = normalized['createdAt'];
        }
        if (normalized.containsKey('updatedAt') &&
            !normalized.containsKey('updated_at')) {
          normalized['updated_at'] = normalized['updatedAt'];
        }
        if (normalized.containsKey('syncStatus') &&
            !normalized.containsKey('sync_status')) {
          normalized['sync_status'] = normalized['syncStatus'];
        }
        if (normalized.containsKey('sync_status')) {
          normalized['sync_status'] = normalized['sync_status']?.toString();
        }
        normalized.remove('imageUrl');
        normalized.remove('minStockThreshold');
        normalized.remove('createdAt');
        normalized.remove('updatedAt');
        normalized.remove('syncStatus');
        break;
      case 'stock_movements':
        if (normalized.containsKey('productId') &&
            !normalized.containsKey('product_id')) {
          normalized['product_id'] = normalized['productId'];
        }
        if (normalized.containsKey('movementType') &&
            !normalized.containsKey('movement_type')) {
          normalized['movement_type'] = normalized['movementType'];
        }
        if (normalized.containsKey('fromLocationId') &&
            !normalized.containsKey('from_location_id')) {
          normalized['from_location_id'] = normalized['fromLocationId'];
        }
        if (normalized.containsKey('toLocationId') &&
            !normalized.containsKey('to_location_id')) {
          normalized['to_location_id'] = normalized['toLocationId'];
        }
        if (normalized.containsKey('userId') &&
            !normalized.containsKey('user_id')) {
          normalized['user_id'] = normalized['userId'];
        }
        if (normalized.containsKey('syncStatus') &&
            !normalized.containsKey('sync_status')) {
          normalized['sync_status'] = normalized['syncStatus'];
        }
        normalized.remove('productId');
        normalized.remove('movementType');
        normalized.remove('fromLocationId');
        normalized.remove('toLocationId');
        normalized.remove('userId');
        normalized.remove('syncStatus');
        break;
    }

    if (normalized.containsKey('created_at') &&
        normalized['created_at'] is Timestamp) {
      normalized['created_at'] =
          (normalized['created_at'] as Timestamp).toDate().toIso8601String();
    }
    if (normalized.containsKey('updated_at') &&
        normalized['updated_at'] is Timestamp) {
      normalized['updated_at'] =
          (normalized['updated_at'] as Timestamp).toDate().toIso8601String();
    }
    if (normalized.containsKey('timestamp') &&
        normalized['timestamp'] is Timestamp) {
      normalized['timestamp'] =
          (normalized['timestamp'] as Timestamp).toDate().toIso8601String();
    }

    return normalized;
  }

  Future<bool> _canInsertRemoteRow(
    String collectionName,
    Map<String, dynamic> row,
    Database db,
  ) async {
    if (collectionName != 'stock_movements') {
      return true;
    }

    final productId = row['product_id']?.toString();
    if (productId == null || productId.isEmpty) {
      return false;
    }

    final productExists = (Sqflite.firstIntValue(await db.rawQuery(
              'SELECT COUNT(*) FROM products WHERE id = ?',
              [productId],
            )) ??
            0) >
        0;

    if (!productExists) {
      return false;
    }

    final fromLocationId = row['from_location_id']?.toString();
    final toLocationId = row['to_location_id']?.toString();

    if (fromLocationId != null && fromLocationId.isNotEmpty) {
      final fromExists = (Sqflite.firstIntValue(await db.rawQuery(
                'SELECT COUNT(*) FROM locations WHERE id = ?',
                [fromLocationId],
              )) ??
              0) >
          0;
      if (!fromExists) return false;
    }

    if (toLocationId != null && toLocationId.isNotEmpty) {
      final toExists = (Sqflite.firstIntValue(await db.rawQuery(
                'SELECT COUNT(*) FROM locations WHERE id = ?',
                [toLocationId],
              )) ??
              0) >
          0;
      if (!toExists) return false;
    }

    return true;
  }

  Future<void> _insertRemoteCollection(
    String collectionName,
    QuerySnapshot<Map<String, dynamic>> snaps,
    Database db,
  ) async {
    for (final doc in snaps.docs) {
      final normalized = _normalizeForSqlite(collectionName, doc.data());
      if (normalized['id'] == null) {
        normalized['id'] = doc.id;
      }

      if (collectionName == 'stock_movements') {
        final canInsert =
            await _canInsertRemoteRow(collectionName, normalized, db);
        if (!canInsert) {
          debugPrint(
            'Skipping stock movement ${doc.id} because product or location is missing locally yet.',
          );
          continue;
        }
      }

      try {
        await db.insert(
          collectionName,
          normalized,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (e) {
        debugPrint('Insert blocked for $collectionName/${doc.id}: $e');
      }
    }
  }

  Future<void> _applyRemoteSnapshot(
    String collectionName,
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final db = await _dbHelper.database;

    for (final change in snapshot.docChanges) {
      final data = change.doc.data();
      if (data == null) continue;

      final normalized = _normalizeForSqlite(collectionName, data);
      if (normalized['id'] == null) {
        normalized['id'] = change.doc.id;
      }

      if (change.type == DocumentChangeType.removed) {
        await db.delete(
          collectionName,
          where: 'id = ?',
          whereArgs: [change.doc.id],
        );
        continue;
      }

      if (collectionName == 'stock_movements') {
        final canInsert =
            await _canInsertRemoteRow(collectionName, normalized, db);
        if (!canInsert) {
          debugPrint(
              'Skipping remote snapshot row for stock movement: ${change.doc.id}');
          continue;
        }
      }

      try {
        await db.insert(
          collectionName,
          normalized,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (e) {
        debugPrint(
            'Remote sync listener insert failed for $collectionName: $e');
      }
    }
  }

  Future<void> pullRemoteChanges() async {
    final Database db = await _dbHelper.database;
    try {
      final collections = ['users', 'locations', 'products', 'stock_movements'];

      for (final collectionName in collections) {
        final snaps = await _firestore.collection(collectionName).get();

        if (snaps.docs.isEmpty) {
          await db.delete(collectionName);
          continue;
        }

        await _insertRemoteCollection(collectionName, snaps, db);
      }
    } catch (e) {
      debugPrint('Error pulling remote changes: $e');
    }
  }

  Future<int> syncPendingChanges() async {
    final Database db = await _dbHelper.database;

    await pullRemoteChanges();

    final pendingChanges = await db.query(
      'pending_changes',
      orderBy: 'created_at ASC',
    );

    if (pendingChanges.isEmpty) {
      return 0;
    }

    final seen = <String>{};
    final dedupedPending = <Map<String, dynamic>>[];
    for (final change in pendingChanges) {
      final key = '${change['table_name']}|${change['record_id']}';
      if (seen.contains(key)) {
        await db.delete(
          'pending_changes',
          where: 'id = ?',
          whereArgs: [change['id']],
        );
        continue;
      }
      seen.add(key);
      dedupedPending.add(change);
    }

    int syncedCount = 0;
    int conflictCount = 0;

    for (final change in dedupedPending) {
      final id = change['id'].toString();
      final tableName = change['table_name'].toString();
      final recordId = change['record_id'].toString();

      Map<String, dynamic> payload;
      try {
        payload = jsonDecode(change['payload'].toString());
      } catch (e) {
        await db.delete('pending_changes', where: 'id = ?', whereArgs: [id]);
        continue;
      }

      try {
        bool hadConflict = false;

        if (tableName == 'stock_movements') {
          hadConflict = await _handleStockMovementSync(db, recordId, payload);
        } else if (tableName == 'products') {
          hadConflict = await _handleProductSyncConflict(db, recordId, payload);
        } else {
          await _firestore
              .collection(tableName)
              .doc(recordId)
              .set(payload, SetOptions(merge: true));
        }

        if (hadConflict) conflictCount++;

        await db.delete('pending_changes', where: 'id = ?', whereArgs: [id]);
        syncedCount++;
      } catch (e) {
        debugPrint('Sync error on table $tableName (record $recordId): $e');
        await db.rawUpdate(
          'UPDATE pending_changes SET retry_count = retry_count + 1 WHERE id = ?',
          [id],
        );
      }
    }

    if (syncedCount > 0) {
      if (conflictCount > 0) {
        await NotificationService.showNotification(
          id: 101,
          title: 'Sync Completed with Conflicts',
          body:
              '$syncedCount changes synced. $conflictCount items flagged for manager review.',
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

  Future<bool> _handleProductSyncConflict(
    Database db,
    String recordId,
    Map<String, dynamic> payload,
  ) async {
    final remoteDoc =
        await _firestore.collection('products').doc(recordId).get();
    if (!remoteDoc.exists) {
      payload['sync_status'] = 'SYNCED';
      await _firestore
          .collection('products')
          .doc(recordId)
          .set(payload, SetOptions(merge: true));
      return false;
    }

    final remoteData = remoteDoc.data() ?? {};
    final remoteUpdatedAt =
        _parseTimestamp(remoteData['updated_at'] ?? remoteData['updatedAt']);
    final localUpdatedAt =
        _parseTimestamp(payload['updated_at'] ?? payload['updatedAt']);

    if (remoteUpdatedAt != null &&
        localUpdatedAt != null &&
        remoteUpdatedAt.isAfter(localUpdatedAt)) {
      payload['sync_status'] = 'CONFLICT';
      await _firestore.collection('sync_conflicts').add({
        'recordType': 'products',
        'recordId': recordId,
        'localPayload': payload,
        'remotePayload': remoteData,
        'reason':
            'Another user edited the same product after this device queued its change',
        'status': 'PENDING_MANAGER_REVIEW',
        'createdAt': DateTime.now().toIso8601String(),
      });

      await db.update(
        'products',
        {'updated_at': remoteUpdatedAt.toIso8601String()},
        where: 'id = ?',
        whereArgs: [recordId],
      );
      return true;
    }

    payload['sync_status'] = 'SYNCED';
    await _firestore
        .collection('products')
        .doc(recordId)
        .set(payload, SetOptions(merge: true));
    return false;
  }

  Future<bool> _handleStockMovementSync(
    Database db,
    String recordId,
    Map<String, dynamic> payload,
  ) async {
    bool isConflict = false;

    if (payload['movement_type'] == 'OUT' ||
        payload['movement_type'] == 'TRANSFER') {
      final fromLoc = payload['from_location_id']?.toString();
      final prodId = payload['product_id'].toString();
      final qty = (payload['quantity'] as num).toInt();

      if (fromLoc != null && fromLoc.isNotEmpty) {
        try {
          final cloudDocs = await _firestore
              .collection('stock_movements')
              .where('product_id', isEqualTo: prodId)
              .get();

          int cloudStock = 0;
          for (final doc in cloudDocs.docs) {
            if (doc.id == recordId) continue;
            final data = doc.data();
            if (data['to_location_id'] == fromLoc) {
              cloudStock += (data['quantity'] as num? ?? 0).toInt();
            }
            if (data['from_location_id'] == fromLoc) {
              cloudStock -= (data['quantity'] as num? ?? 0).toInt();
            }
          }

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
          payload['sync_status'] = 'SYNCED';
        }
      } else {
        payload['sync_status'] = 'SYNCED';
      }
    } else {
      payload['sync_status'] = 'SYNCED';
    }

    await _firestore
        .collection('stock_movements')
        .doc(recordId)
        .set(payload, SetOptions(merge: true));

    await db.update(
      'stock_movements',
      {'sync_status': payload['sync_status']},
      where: 'id = ?',
      whereArgs: [recordId],
    );

    return isConflict;
  }
}
