import 'package:flutter/material.dart';
import '../../Shared/theme/app_theme.dart';

class SellerShopPage extends StatelessWidget {
  const SellerShopPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Shop'),
        backgroundColor: AppTheme.tertiary,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Seller Shop - Add your data here'),
      ),
    );
  }
}
