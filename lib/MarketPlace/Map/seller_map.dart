import 'package:flutter/material.dart';
import '../../Shared/theme/app_theme.dart';

class SellerMapPage extends StatelessWidget {
  const SellerMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Map'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Seller Map - Add your data here'),
      ),
    );
  }
}
