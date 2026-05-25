import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../Shared/theme/app_theme.dart';
import '../Components/index.dart';
import '../Models/index.dart';
import '../Services/heritage_providers.dart';
import '../heritage_theme.dart';

/// HeritageConnectionsScreen — Connections tab showing entry relationships
/// Two tabs: Confirmed and Suggested connections
class HeritageConnectionsScreen extends StatefulWidget {
  final String orgId;

  const HeritageConnectionsScreen({
    required this.orgId,
    Key? key,
  }) : super(key: key);

  @override
  State<HeritageConnectionsScreen> createState() =>
      _HeritageConnectionsScreenState();
}

class _HeritageConnectionsScreenState extends State<HeritageConnectionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<OrgEntryIdsProvider>(context, listen: false);
      provider.fetchEntryIds(widget.orgId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: AppTheme.tertiary,
          unselectedLabelColor: AppTheme.darkGreen.withOpacity(0.4),
          indicatorColor: AppTheme.tertiary,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Confirmed'),
            Tab(text: 'Suggested'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildConnectionsList('confirmed'),
              _buildConnectionsList('suggested'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionsList(String status) {
    final provider = Provider.of<OrgEntryIdsProvider>(context);
    final entryIds = provider.entryIds;
    final isLoading = provider.isLoading;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.link_outlined,
                size: 48,
                color: AppTheme.tertiary.withOpacity(0.4),
              ),
              const SizedBox(height: 12),
              Text(
                status == 'confirmed'
                    ? 'No confirmed connections yet.'
                    : 'No suggested connections.',
                style: TextStyle(
                  color: AppTheme.darkGreen.withOpacity(0.5),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {},
                child: Text(
                  'Propose a connection',
                  style: TextStyle(
                    color: AppTheme.tertiary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
