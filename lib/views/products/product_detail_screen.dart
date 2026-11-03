import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_viewmodel.dart';
import '../../data/repositories/location_repository.dart';
import '../../data/repositories/movement_repository.dart';
import '../../data/models/location_model.dart';
import 'product_edit_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final bool isEmbedded;
  const ProductDetailScreen({super.key, this.isEmbedded = false});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final LocationRepository _locationRepo = LocationRepository();
  final MovementRepository _movementRepo = MovementRepository();
  
  Map<String, int> _locationStock = {};
  List<LocationModel> _locations = [];
  bool _isLoadingStock = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadStockByLocation();
  }

  Future<void> _loadStockByLocation() async {
    final product = context.read<ProductViewModel>().selectedProduct;
    if (product == null) return;

    await _locationRepo.seedDefaultLocations();
    final locations = await _locationRepo.getAllLocations();
    Map<String, int> stockMap = {};

    for (var loc in locations) {
      int stock = await _movementRepo.calculateStock(product.id, loc.id);
      stockMap[loc.id] = stock;
    }

    if (mounted) {
      setState(() {
        _locations = locations;
        _locationStock = stockMap;
        _isLoadingStock = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProductViewModel>();
    final product = vm.selectedProduct;

    if (product == null) {
      return Scaffold(
        appBar: widget.isEmbedded ? null : AppBar(title: const Text('Details')),
        body: const Center(child: Text('Select a product to view details.')),
      );
    }

    return Scaffold(
      appBar: widget.isEmbedded ? null : AppBar(
        title: Text(product.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductEditScreen(product: product),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.imageUrl != null && product.imageUrl!.isNotEmpty)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    product.imageUrl!,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.inventory, size: 100),
                  ),
                ),
              )
            else
              const Center(child: Icon(Icons.image_not_supported, size: 100)),
            
            const SizedBox(height: 24),
            Text(product.name, style: Theme.of(context).textTheme.headlineMedium),
            Text(product.brand ?? 'No Brand', style: Theme.of(context).textTheme.titleMedium),
            const Divider(height: 32),
            
            _buildDetailRow('Barcode', product.barcode),
            _buildDetailRow('Category', product.category),
            _buildDetailRow('Unit Price', 'EGP ${product.price.toStringAsFixed(2)}'),
            _buildDetailRow('Low Stock Alert At', '${product.minStockThreshold} units'),
            
            const SizedBox(height: 24),
            Text('Stock by Location:', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),

            if (_isLoadingStock)
              const Center(child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ))
            else if (_locations.isEmpty)
              const Text('No locations found.')
            else
              ..._locations.map((loc) {
                final qty = _locationStock[loc.id] ?? 0;
                final isLow = qty < product.minStockThreshold;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  child: ListTile(
                    leading: Icon(
                      loc.isWarehouse ? Icons.warehouse : Icons.store,
                      color: isLow ? Colors.red : Colors.blue,
                    ),
                    title: Text(loc.name),
                    subtitle: Text(loc.code),
                    trailing: Text(
                      '$qty Units',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isLow ? Colors.red : null,
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
