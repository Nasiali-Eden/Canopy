import 'package:flutter/material.dart';
import '../../Shared/theme/app_theme.dart';

class SellerActivitiesPage extends StatelessWidget {
  const SellerActivitiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Activities'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Seller Activities - Add your data here'),
      ),
    );
  }
}
