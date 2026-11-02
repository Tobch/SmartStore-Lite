import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/stock_movement_viewmodel.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../viewmodels/reports_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';

class AddMovementScreen extends StatefulWidget {
  const AddMovementScreen({super.key});

  @override
  State<AddMovementScreen> createState() => _AddMovementScreenState();
}

class _AddMovementScreenState extends State<AddMovementScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String _selectedType = 'IN';
  String? _selectedProductId;
  String? _selectedFromLocationId;
  String? _selectedToLocationId;
  String _adjustmentDirection = 'INCREASE'; // 'INCREASE' (+) or 'DECREASE' (-)
  final _quantityController = TextEditingController();

  final List<String> _movementTypes = ['IN', 'OUT', 'TRANSFER', 'ADJUSTMENT'];
  int? _availableStockAtSource;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StockMovementViewModel>().loadFormData();
    });
  }

  Future<void> _updateAvailableStock() async {
    final vm = context.read<StockMovementViewModel>();
    final productId = _selectedProductId;
    
    String? sourceId;
    if (_selectedType == 'OUT' || _selectedType == 'TRANSFER') {
      sourceId = _selectedFromLocationId;
    } else if (_selectedType == 'ADJUSTMENT' && _adjustmentDirection == 'DECREASE') {
      sourceId = _selectedFromLocationId;
    }

    if (productId != null && sourceId != null) {
      final stock = await vm.getAvailableStock(productId, sourceId);
      if (mounted) {
        setState(() => _availableStockAtSource = stock);
      }
    } else {
      if (mounted) {
        setState(() => _availableStockAtSource = null);
      }
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final movementVM = context.read<StockMovementViewModel>();
    final authVM = context.read<AuthViewModel>();

    String? fromLoc;
    String? toLoc;

    if (_selectedType == 'IN') {
      fromLoc = null;
      toLoc = _selectedToLocationId;
    } else if (_selectedType == 'OUT') {
      fromLoc = _selectedFromLocationId;
      toLoc = null;
    } else if (_selectedType == 'TRANSFER') {
      fromLoc = _selectedFromLocationId;
      toLoc = _selectedToLocationId;
    } else if (_selectedType == 'ADJUSTMENT') {
      if (_adjustmentDirection == 'INCREASE') {
        fromLoc = null;
        toLoc = _selectedFromLocationId;
      } else {
        fromLoc = _selectedFromLocationId;
        toLoc = null;
      }
    }

    bool success = await movementVM.recordMovement(
      authVM: authVM,
      movementType: _selectedType,
      productId: _selectedProductId!,
      quantity: int.parse(_quantityController.text.trim()),
      fromLocationId: fromLoc,
      toLocationId: toLoc,
    );

    if (success && mounted) {
      // Refresh dashboard and reports in background
      context.read<DashboardViewModel>().loadDashboardMetrics();
      context.read<ReportsViewModel>().loadReports();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock movement recorded successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StockMovementViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Record Stock Movement')),
      body: vm.isLoading && vm.products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: const InputDecoration(labelText: 'Movement Type'),
                      items: _movementTypes.map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      )).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedType = val!;
                          _updateAvailableStock();
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    if (_selectedType == 'ADJUSTMENT') ...[
                      DropdownButtonFormField<String>(
                        value: _adjustmentDirection,
                        decoration: const InputDecoration(labelText: 'Adjustment Action'),
                        items: const [
                          DropdownMenuItem(value: 'INCREASE', child: Text('Add Stock (+)')),
                          DropdownMenuItem(value: 'DECREASE', child: Text('Remove Stock (-)')),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _adjustmentDirection = val!;
                            _updateAvailableStock();
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    DropdownButtonFormField<String>(
                      isExpanded: true, // ADDED to fix overflow
                      value: _selectedProductId,
                      decoration: const InputDecoration(labelText: 'Product'),
                      items: vm.products.map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          p.name,
                          overflow: TextOverflow.ellipsis, // ADDED to fix overflow
                        ),
                      )).toList(),
                      onChanged: (val) {
                        setState(() => _selectedProductId = val);
                        _updateAvailableStock();
                      },
                      validator: (v) => v == null ? 'Select a product' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final qty = int.tryParse(v);
                        if (qty == null || qty <= 0) return 'Must be a positive whole number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Source Location (for OUT, TRANSFER, and ADJUSTMENT)
                    if (_selectedType != 'IN') ...[
                      DropdownButtonFormField<String>(
                        isExpanded: true, // ADDED to fix overflow
                        value: _selectedFromLocationId,
                        decoration: InputDecoration(
                          labelText: _selectedType == 'ADJUSTMENT' ? 'Location' : 'Source Location',
                        ),
                        items: vm.locations.map((loc) => DropdownMenuItem(
                          value: loc.id,
                          child: Text(
                            loc.name,
                            overflow: TextOverflow.ellipsis, // ADDED to fix overflow
                          ),
                        )).toList(),
                        onChanged: (val) {
                          setState(() => _selectedFromLocationId = val);
                          _updateAvailableStock();
                        },
                        validator: (v) => v == null ? 'Select a location' : null,
                      ),
                      if (_availableStockAtSource != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                          child: Text(
                            'Available at source: $_availableStockAtSource units',
                            style: TextStyle(
                              color: _availableStockAtSource! > 0 ? Colors.green.shade700 : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],

                    // Destination Location (for IN and TRANSFER)
                    if (_selectedType == 'IN' || _selectedType == 'TRANSFER') ...[
                      DropdownButtonFormField<String>(
                        isExpanded: true, // ADDED to fix overflow
                        value: _selectedToLocationId,
                        decoration: InputDecoration(
                          labelText: _selectedType == 'IN' ? 'Destination Location' : 'Destination Location',
                        ),
                        items: vm.locations.map((loc) => DropdownMenuItem(
                          value: loc.id,
                          child: Text(
                            loc.name,
                            overflow: TextOverflow.ellipsis, // ADDED to fix overflow
                          ),
                        )).toList(),
                        onChanged: (val) => setState(() => _selectedToLocationId = val),
                        validator: (v) {
                          if (v == null) return 'Select destination location';
                          if (_selectedType == 'TRANSFER' && v == _selectedFromLocationId) {
                            return 'Destination must differ from source';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (vm.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(vm.errorMessage!, style: const TextStyle(color: Colors.red)),
                      ),

                    ElevatedButton(
                      onPressed: vm.isLoading ? null : _submit,
                      child: vm.isLoading 
                          ? const CircularProgressIndicator() 
                          : const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: Text('RECORD MOVEMENT', style: TextStyle(fontSize: 16)),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}