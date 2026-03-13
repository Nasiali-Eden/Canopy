import 'package:flutter/material.dart';
import '../../Shared/theme/app_theme.dart';

class SellerFeedPage extends StatelessWidget {
  const SellerFeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Feed'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Seller Feed - Add your data here'),
      ),
    );
  }
}
