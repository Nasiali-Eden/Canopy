import 'package:flutter/material.dart';
import '../../Shared/theme/app_theme.dart';

class EnvMarketScreen extends StatefulWidget {
  const EnvMarketScreen({super.key});

  @override
  State<EnvMarketScreen> createState() => _EnvMarketScreenState();
}

class _EnvMarketScreenState extends State<EnvMarketScreen> {
  bool _showBuying = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildStatStrip(),
            const SizedBox(height: 12),
            _buildTabSwitcher(),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children:
                    _showBuying ? _buildBuyOrders() : _buildSellListings(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.darkGreen, AppTheme.primary],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Post Order coming soon')),
            );
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
          label: const Text(
            'Post Order',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildStatStrip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard('Active Orders', '—'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard('Kg This Month', '—'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard('Avg KSh/kg', '—'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: AppTheme.darkGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.darkGreen.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showBuying = true),
              child: Container(
                height: 30,
                decoration: BoxDecoration(
                  color: _showBuying
                      ? AppTheme.accent
                      : AppTheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Buying',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _showBuying
                        ? Colors.white
                        : AppTheme.darkGreen.withOpacity(0.65),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showBuying = false),
              child: Container(
                height: 30,
                decoration: BoxDecoration(
                  color: !_showBuying
                      ? AppTheme.accent
                      : AppTheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Offered',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: !_showBuying
                        ? Colors.white
                        : AppTheme.darkGreen.withOpacity(0.65),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBuyOrders() {
    return [
      _buildBuyOrderCard(
        material: 'PET Clean',
        grade: 'Grade A',
        status: 'Active',
        price: 28,
        currentKg: 240,
        totalKg: 500,
        zone: 'Kibera',
      ),
      const SizedBox(height: 12),
      _buildBuyOrderCard(
        material: 'Carrier Bags',
        grade: 'Mixed',
        status: 'Active',
        price: 8,
        currentKg: 80,
        totalKg: 200,
        zone: 'Mathare',
      ),
    ];
  }

  List<Widget> _buildSellListings() {
    return [
      _buildSellListingCard(
        material: 'HDPE Pellets',
        grade: 'Processed',
        price: 45,
        availableKg: 150,
      ),
    ];
  }

  Widget _buildBuyOrderCard({
    required String material,
    required String grade,
    required String status,
    required int price,
    required int currentKg,
    required int totalKg,
    required String zone,
  }) {
    final progress = currentKg / totalKg;
    final statusColor = status == 'Active'
        ? AppTheme.primary
        : status == 'Paused'
            ? Colors.amber
            : Colors.grey;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                material,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppTheme.darkGreen,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  grade,
                  style: const TextStyle(
                    color: AppTheme.darkGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'KSh $price',
                style: const TextStyle(
                  color: AppTheme.tertiary,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'per kg',
                style: TextStyle(
                  color: AppTheme.darkGreen.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$currentKg kg of $totalKg kg needed',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.darkGreen.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.primary.withOpacity(0.15),
              valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 80,
                height: 54,
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.map_outlined,
                  color: AppTheme.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Switch to Territory to view zone')),
                  );
                },
                child: Text(
                  'View zone →',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('View Responses coming soon')),
                  );
                },
                child: const Text('View Responses'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Edit Order coming soon')),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('Edit Order'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSellListingCard({
    required String material,
    required String grade,
    required int price,
    required int availableKg,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                material,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppTheme.darkGreen,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  grade,
                  style: const TextStyle(
                    color: AppTheme.darkGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'KSh $price',
                style: const TextStyle(
                  color: AppTheme.tertiary,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'per kg asking',
                style: TextStyle(
                  color: AppTheme.darkGreen.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$availableKg kg available',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.darkGreen.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('View Interest coming soon')),
                  );
                },
                child: const Text('View Interest'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Edit Listing coming soon')),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('Edit Listing'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
