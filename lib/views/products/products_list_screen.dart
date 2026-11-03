import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_viewmodel.dart';
import 'product_detail_screen.dart';
// ADD THESE IMPORTS
import '../../core/services/tts_stt_service.dart';
import '../../data/models/product_model.dart';

class ProductsListScreen extends StatefulWidget {
  final bool isEmbedded;
  const ProductsListScreen({super.key, this.isEmbedded = false});

  @override
  State<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends State<ProductsListScreen> {
  final _searchController = TextEditingController(); // Added controller

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductViewModel>().loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProductViewModel>();

    return Scaffold(
      appBar: widget.isEmbedded ? null : AppBar(title: const Text('Products Catalog')),
      body: Column(
        children: [
          // UPDATED Search Bar with Voice Interception
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by name, barcode, or category',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.mic),
                  onPressed: () {
                    // Start speech recognition and populate field
                    context.read<TtsSttService>().startListening((text) {
                      _searchController.text = text;
                      _handleSearch(text, vm); // Automatically submit after listening
                    });
                  },
                ),
              ),
              onChanged: (val) {
                // Only perform visual search if it's not a "how many" query
                if (!val.toLowerCase().startsWith('how many')) {
                  vm.searchProducts(val);
                }
              },
              onSubmitted: (val) => _handleSearch(val, vm),
            ),
          ),

          // Filter Chips (All vs Low Stock)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All Products'),
                  selected: !vm.onlyLowStock,
                  onSelected: (_) => context.read<ProductViewModel>().setLowStockFilter(false),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                  label: const Text('Low Stock Only'),
                  selected: vm.onlyLowStock,
                  selectedColor: Colors.red.shade100,
                  onSelected: (val) => context.read<ProductViewModel>().setLowStockFilter(val),
                ),
              ],
            ),
          ),

          Expanded(
            child: vm.isLoading
                ? const Center(child: CircularProgressIndicator())
                : vm.filteredProducts.isEmpty
                    ? Center(
                        child: Text(
                          vm.onlyLowStock
                              ? 'No low-stock products found! All items meet threshold.'
                              : 'No products found. Tap + to add one.',
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => context.read<ProductViewModel>().loadProducts(),
                        child: ListView.builder(
                          itemCount: vm.filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = vm.filteredProducts[index];
                            final isSelected = vm.selectedProduct?.id == product.id;
                            final stock = vm.getProductStock(product.id);
                            final isLowStock = stock < product.minStockThreshold;

                            return ListTile(
                              selected: widget.isEmbedded && isSelected,
                              selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
                              selectedColor: Theme.of(context).colorScheme.onPrimaryContainer,
                              leading: product.imageUrl != null && product.imageUrl!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        product.imageUrl!,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.inventory, size: 50),
                                      ),
                                    )
                                  : const Icon(Icons.inventory, size: 50),
                              title: Text(
                                product.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${product.category} • EGP ${product.price.toStringAsFixed(2)}'),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        'Stock: $stock units',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: isLowStock ? Colors.red : Colors.green.shade700,
                                        ),
                                      ),
                                      if (isLowStock) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade100,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Low Stock (Limit: ${product.minStockThreshold})',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.red.shade900,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                              onTap: () {
                                vm.selectProduct(product);
                                if (!widget.isEmbedded) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const ProductDetailScreen()),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'products_fab',
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.pushNamed(context, '/add_product');
        },
      ),
    );
  }

 Future<void> _handleSearch(String query, ProductViewModel vm) async {
    final lowerQuery = query.toLowerCase();
    
    if (lowerQuery.startsWith('how many')) {
      vm.searchProducts(''); // Clear visual search so all products show
      
      String targetProduct = lowerQuery
          .replaceAll('how many ', '')
          .replaceAll(' in the warehouse', '')
          .trim();

      ProductModel? foundProduct;
      try {
        foundProduct = vm.filteredProducts.firstWhere(
          (p) => p.name.toLowerCase().contains(targetProduct),
        );
      } catch (e) {
        foundProduct = null;
      }

      if (foundProduct != null) {
        int totalStock = vm.getProductStock(foundProduct.id);
        // Accurately announces total stock across all storage facilities
        context.read<TtsSttService>().speak('There are a total of $totalStock ${foundProduct.name} across all locations.');
      } else {
        context.read<TtsSttService>().speak('I could not find $targetProduct in the catalog.');
      }
    } else {
      vm.searchProducts(query);
    }
  }
}