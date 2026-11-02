import 'package:flutter/material.dart';
import '../products/products_list_screen.dart';
import '../products/product_detail_screen.dart';

class ProductResponsiveWrapper extends StatelessWidget {
  const ProductResponsiveWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Determine if tablet/landscape (Width > 800)[cite: 6]
    final isWideScreen = MediaQuery.of(context).size.width > 800;

    if (isWideScreen) {
      return Scaffold(
        body: Row(
          children: [
            const Expanded(
              flex: 2,
              child: ProductsListScreen(isEmbedded: true),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              flex: 3,
              child: const ProductDetailScreen(isEmbedded: true),
            ),
          ],
        ),
      );
    }

    // Phone / Portrait Layout
    return const ProductsListScreen(isEmbedded: false);
  }
}