import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_viewmodel.dart';
import '../../data/models/product_model.dart';
import '../../core/utils/barcode_validator.dart';
import '../../core/network/interceptors/error_interceptor.dart';

class ProductEditScreen extends StatefulWidget {
  final ProductModel? product;
  const ProductEditScreen({super.key, this.product});

  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _barcodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _categoryController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _priceController = TextEditingController();
  final _thresholdController = TextEditingController(text: '5');

  bool _isLookingUp = false;
  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final p = widget.product!;
      _barcodeController.text = p.barcode;
      _nameController.text = p.name;
      _brandController.text = p.brand ?? '';
      _categoryController.text = p.category;
      _imageUrlController.text = p.imageUrl ?? '';
      _priceController.text = p.price.toString();
      _thresholdController.text = p.minStockThreshold.toString();
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    _brandController.dispose();
    _categoryController.dispose();
    _imageUrlController.dispose();
    _priceController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _lookupBarcode() async {
    final barcode = _barcodeController.text.trim();
    
    // Validate EAN-13 before making API request[cite: 3]
    if (!BarcodeValidator.isValidEAN13(barcode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid EAN-13 Barcode check-digit format.')),
      );
      return;
    }

    setState(() => _isLookingUp = true);

    try {
      final vm = context.read<ProductViewModel>();
      final data = await vm.lookupBarcode(barcode);

      if (data != null && mounted) {
        setState(() {
          _nameController.text = data['name'] ?? '';
          _brandController.text = data['brand'] ?? '';
          _categoryController.text = data['category'] ?? '';
          _imageUrlController.text = data['imageUrl'] ?? '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product details fetched from Open Food Facts!')),
        );
      }
    } on ProductNotFoundException catch (e) {
      // Maps the API error to a friendly message, allowing manual entry[cite: 2]
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error. You can enter details manually.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLookingUp = false);
    }
  }

  void _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final product = ProductModel(
      id: _isEditing ? widget.product!.id : null,
      barcode: _barcodeController.text.trim(),
      name: _nameController.text.trim(),
      brand: _brandController.text.trim(),
      category: _categoryController.text.trim(),
      imageUrl: _imageUrlController.text.trim(),
      price: double.parse(_priceController.text.trim()),
      minStockThreshold: int.parse(_thresholdController.text.trim()),
      createdAt: _isEditing ? widget.product!.createdAt : null,
      updatedAt: DateTime.now(),
    );

    if (_isEditing) {
      await context.read<ProductViewModel>().updateProduct(product);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product updated and queued for sync.')),
        );
        Navigator.pop(context);
      }
      return;
    }

    await context.read<ProductViewModel>().addProduct(product);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product saved and queued for sync.')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Product' : 'Add Product')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Barcode input with lookup button[cite: 2]
                TextFormField(
                  controller: _barcodeController,
                  decoration: InputDecoration(
                    labelText: 'EAN-13 Barcode',
                    suffixIcon: _isLookingUp 
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: _lookupBarcode,
                            tooltip: 'Lookup in Open Food Facts',
                          ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) => BarcodeValidator.isValidEAN13(v ?? '') ? null : 'Invalid EAN-13 Barcode',
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Product Name'),
                  validator: (v) => v == null || v.isEmpty ? 'Required field' : null,
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _brandController,
                        decoration: const InputDecoration(labelText: 'Brand (Optional)'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _categoryController,
                        decoration: const InputDecoration(labelText: 'Category'),
                        validator: (v) => v == null || v.isEmpty ? 'Required field' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _imageUrlController,
                  decoration: const InputDecoration(labelText: 'Image URL (Optional)'),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(labelText: 'Unit Price (EGP)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required field';
                          final price = double.tryParse(v);
                          if (price == null || price <= 0) return 'Must be > 0'; // Requirement #4 Validation[cite: 3]
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _thresholdController,
                        decoration: const InputDecoration(labelText: 'Low Stock Alert At'),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          final threshold = int.tryParse(v);
                          if (threshold == null || threshold < 0) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                ElevatedButton(
                  onPressed: _saveProduct,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(_isEditing ? 'UPDATE PRODUCT' : 'SAVE PRODUCT', style: const TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}