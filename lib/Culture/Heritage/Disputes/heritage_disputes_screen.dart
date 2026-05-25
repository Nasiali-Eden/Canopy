import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../Shared/theme/app_theme.dart';
import '../Components/index.dart';
import '../Models/index.dart';
import '../Services/heritage_providers.dart';
import '../heritage_theme.dart';

/// HeritageDisputesScreen — Disputes tab showing community council reviews
/// Disputes are reviewed privately and not visible until resolved
class HeritageDisputesScreen extends StatefulWidget {
  final String orgId;

  const HeritageDisputesScreen({
    required this.orgId,
    Key? key,
  }) : super(key: key);

  @override
  State<HeritageDisputesScreen> createState() => _HeritageDisputesScreenState();
}

class _HeritageDisputesScreenState extends State<HeritageDisputesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<OrgEntryIdsProvider>(context, listen: false);
      provider.fetchEntryIds(widget.orgId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrgEntryIdsProvider>(context);
    final isLoading = provider.isLoading;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Explanatory note
          HeritageCard(
            margin: const EdgeInsets.all(16),
            leftBorder: BorderSide(
              color: Colors.amber.shade700,
              width: 3,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: Colors.amber.shade700,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Disputes are reviewed privately by the community council. '
                    'They are not visible to other users until resolved.',
                    style: TextStyle(
                      color: AppTheme.darkGreen.withOpacity(0.65),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Placeholder for dispute cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildEmptyState(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 48,
            color: AppTheme.primary.withOpacity(0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'No active disputes on your submissions.',
            style: TextStyle(
              color: AppTheme.darkGreen.withOpacity(0.5),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
