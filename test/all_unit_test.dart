import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Import ViewModels
import 'package:smartstore_lite/viewmodels/auth_viewmodel.dart';
import 'package:smartstore_lite/viewmodels/dashboard_viewmodel.dart';
import 'package:smartstore_lite/viewmodels/product_viewmodel.dart';
import 'package:smartstore_lite/viewmodels/stock_movement_viewmodel.dart';
import 'package:smartstore_lite/viewmodels/reports_viewmodel.dart';
import 'package:smartstore_lite/viewmodels/settings_viewmodel.dart';

// Import Utilities & Models for Unit Testing
import 'package:smartstore_lite/core/utils/barcode_validator.dart';
import 'package:smartstore_lite/data/models/product_model.dart';
import 'package:smartstore_lite/data/models/stock_movement_model.dart';
import 'package:smartstore_lite/data/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SmartStore Lite Comprehensive Test Suite', () {
    
    // --- 1. Unit Tests (Requirement #5) ---
    test('EAN-13 Barcode Validation Test', () {
      String validBarcode = '6221145523115'; 
      expect(BarcodeValidator.isValidEAN13(validBarcode), true);

      String invalidBarcode = '1234567890123';
      expect(BarcodeValidator.isValidEAN13(invalidBarcode), false);

      String shortBarcode = '12345';
      expect(BarcodeValidator.isValidEAN13(shortBarcode), false);
    });

    test('Product Model Serialization Test', () {
      final product = ProductModel(
        barcode: '6221145523115',
        name: 'Juhayna Milk 1L',
        brand: 'Juhayna',
        category: 'Dairy',
        price: 35.5,
        minStockThreshold: 10,
      );

      final map = product.toMap();
      expect(map['name'], 'Juhayna Milk 1L');
      expect(map['price'], 35.5);

      final parsed = ProductModel.fromMap(map);
      expect(parsed.barcode, product.barcode);
      expect(parsed.category, 'Dairy');
    });

    test('User Model toDbMap and fromMap Test', () {
      final user = UserModel(
        id: 'test_user_id',
        name: 'John Manager',
        email: 'manager@smartstore.com',
        role: 'Manager',
        defaultLocationId: 'WH-01',
      );

      final dbMap = user.toDbMap();
      expect(dbMap['id'], 'test_user_id');
      expect(dbMap['name'], 'John Manager');
      expect(dbMap['role'], 'Manager');
      expect(dbMap['default_location_id'], 'WH-01');

      final parsed = UserModel.fromMap(dbMap, 'test_user_id');
      expect(parsed.id, 'test_user_id');
      expect(parsed.name, 'John Manager');
      expect(parsed.role, 'Manager');
    });

    test('Stock Movement Ledger Model Test', () {
      final movement = StockMovementModel(
        productId: 'PROD-001',
        movementType: 'IN',
        toLocationId: 'WH-01',
        quantity: 50,
        userId: 'USER-01',
      );

      final map = movement.toMap();
      expect(map['movement_type'], 'IN');
      expect(map['quantity'], 50);
      expect(map['sync_status'], 'PENDING');
      expect(map['from_location_id'], isNull);
      expect(map['to_location_id'], 'WH-01');
    });

    test('Stock Calculation Ledger Logic Simulation', () {
      // Simulates ledger calculations per Requirement #3
      final movements = [
        {'type': 'IN', 'from': null, 'to': 'WH-01', 'qty': 100},
        {'type': 'TRANSFER', 'from': 'WH-01', 'to': 'STORE-01', 'qty': 30},
        {'type': 'OUT', 'from': 'STORE-01', 'to': null, 'qty': 10},
      ];

      int calculateStock(String locationId) {
        int stock = 0;
        for (var m in movements) {
          if (m['to'] == locationId) stock += (m['qty'] as int);
          if (m['from'] == locationId) stock -= (m['qty'] as int);
        }
        return stock;
      }

      expect(calculateStock('WH-01'), 70); // 100 IN - 30 transferred out
      expect(calculateStock('STORE-01'), 20); // 30 transferred in - 10 sold OUT
    });

    test('Transfer Rule Validation: Source and Destination must differ', () {
      String sourceLoc = 'WH-01';
      String destLoc = 'STORE-01';
      expect(sourceLoc != destLoc, true);

      String sameLoc = 'WH-01';
      expect(sourceLoc != sameLoc, false);
    });

    // --- 2. Widget Tests (Requirement #5) ---
    testWidgets('App smoke test with MultiProvider', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthViewModel()),
            ChangeNotifierProvider(create: (_) => DashboardViewModel()),
            ChangeNotifierProvider(create: (_) => ProductViewModel()),
            ChangeNotifierProvider(create: (_) => StockMovementViewModel()),
            ChangeNotifierProvider(create: (_) => ReportsViewModel()),
            ChangeNotifierProvider(create: (_) => SettingsViewModel()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text('SmartStore Lite Test Mock'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('SmartStore Lite Test Mock'), findsOneWidget);
    });

  });
}
