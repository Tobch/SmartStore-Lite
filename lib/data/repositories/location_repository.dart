import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../core/database/db_helper.dart';
import '../models/location_model.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

class LocationRepository {
  final DBHelper _dbHelper = DBHelper.instance;

  Future<List<LocationModel>> getAllLocations() async {
    final db = await _dbHelper.database;
    final maps = await db.query('locations', orderBy: 'name ASC');
    return maps.map((map) => LocationModel.fromMap(map)).toList();
  }

  // Helper method to seed initial locations if the DB is empty
  Future<void> seedDefaultLocations() async {
    final db = await _dbHelper.database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM locations'));
    
    if (count == 0) {
      final defaultStore = LocationModel(name: 'Main Store', code: 'STORE-01', isWarehouse: false);
      final defaultWarehouse = LocationModel(name: 'Main Warehouse', code: 'WH-01', isWarehouse: true);
      
      await db.transaction((txn) async {
        await txn.insert('locations', defaultStore.toMap());
        await txn.insert('locations', defaultWarehouse.toMap());
        
        // Queue for sync
        await _queueSync(txn, defaultStore);
        await _queueSync(txn, defaultWarehouse);
      });
    }
  }

  Future<void> _queueSync(Transaction txn, LocationModel loc) async {
    await txn.insert('pending_changes', {
      'id': const Uuid().v4(),
      'table_name': 'locations',
      'record_id': loc.id,
      'action_type': 'CREATE',
      'payload': jsonEncode(loc.toMap()),
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
    });
  }
}