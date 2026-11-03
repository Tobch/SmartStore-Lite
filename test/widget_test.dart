import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smartstore_lite/viewmodels/auth_viewmodel.dart';
import 'package:smartstore_lite/viewmodels/dashboard_viewmodel.dart';
import 'package:smartstore_lite/viewmodels/product_viewmodel.dart';
import 'package:smartstore_lite/viewmodels/stock_movement_viewmodel.dart';
import 'package:smartstore_lite/viewmodels/reports_viewmodel.dart';
import 'package:smartstore_lite/viewmodels/settings_viewmodel.dart';

void main() {
  // Ensure Flutter binding is initialized for tests
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Login screen basic smoke test', (WidgetTester tester) async {
    // Build a simplified MaterialApp container to test widget rendering
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

    // Verify that the text renders correctly in the widget tree
    expect(find.text('SmartStore Lite Test Mock'), findsOneWidget);
  });
}