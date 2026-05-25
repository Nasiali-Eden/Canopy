import 'package:flutter/material.dart';
import '../../Shared/theme/app_theme.dart';

class EnvFleetScreen extends StatefulWidget {
  const EnvFleetScreen({super.key});

  @override
  State<EnvFleetScreen> createState() => _EnvFleetScreenState();
}

class _EnvFleetScreenState extends State<EnvFleetScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildStatStrip(),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildCollectorCard(
                    name: 'James Odhiambo',
                    zone: 'Kibera Zone A',
                    status: CollectorStatus.active,
                    kgThisMonth: 84,
                    transactions: 12,
                    lastDelivery: 'Today',
                  ),
                  const SizedBox(height: 12),
                  _buildCollectorCard(
                    name: 'Aisha Mwangi',
                    zone: 'Mathare Zone',
                    status: CollectorStatus.offShift,
                    kgThisMonth: 61,
                    transactions: 9,
                    lastDelivery: 'Yesterday',
                  ),
                  const SizedBox(height: 12),
                  _buildCollectorCard(
                    name: 'Peter Kariuki',
                    zone: 'Kibera Zone B',
                    status: CollectorStatus.active,
                    kgThisMonth: 47,
                    transactions: 7,
                    lastDelivery: 'Today',
                  ),
                  const SizedBox(height: 20),
                  _buildLogCollectionButton(),
                  const SizedBox(height: 20),
                  _buildRouteLogSection(),
                ],
              ),
            ),
          ],
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
            child: _buildStatCard('Collectors Active', '3'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard('Collections This Week', '28'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard('Kg Verified This Month', '192'),
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

  Widget _buildCollectorCard({
    required String name,
    required String zone,
    required CollectorStatus status,
    required int kgThisMonth,
    required int transactions,
    required String lastDelivery,
  }) {
    Color statusColor;
    String statusLabel;

    switch (status) {
      case CollectorStatus.active:
        statusColor = AppTheme.primary;
        statusLabel = 'Active';
        break;
      case CollectorStatus.offShift:
        statusColor = Colors.grey;
        statusLabel = 'Off shift';
        break;
      case CollectorStatus.uncontactable:
        statusColor = Colors.amber;
        statusLabel = 'Uncontactable';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: AppTheme.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.darkGreen,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  zone,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.darkGreen.withOpacity(0.7),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('View profile coming soon')),
                  );
                },
                child: const Text(
                  'View profile →',
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: AppTheme.lightGreen.withOpacity(0.2)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat('$kgThisMonth kg', 'This month'),
              ),
              Expanded(
                child: _buildMiniStat('$transactions', 'Transactions'),
              ),
              Expanded(
                child: _buildMiniStat(lastDelivery, 'Last delivery'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: AppTheme.darkGreen,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.darkGreen.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildLogCollectionButton() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.darkGreen, AppTheme.primary],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Log Collection Handoff coming soon')),
          );
        },
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_box_outlined, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Log Collection Handoff',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteLogSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.route, size: 18, color: AppTheme.darkGreen),
            const SizedBox(width: 8),
            const Text(
              "Today's Routes",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppTheme.darkGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: AppTheme.lightGreen.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(
            child: Icon(
              Icons.map_outlined,
              color: AppTheme.accent,
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Route sharing is opt-in. Collectors share from their own device.',
          style: TextStyle(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: AppTheme.darkGreen.withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}

enum CollectorStatus { active, offShift, uncontactable }
