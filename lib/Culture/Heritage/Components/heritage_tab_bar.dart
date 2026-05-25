import 'package:flutter/material.dart';
import '../../../Shared/theme/app_theme.dart';

/// HeritageTabBar — five-tab navigation bar for Heritage section
/// Tabs: Archive · Feedback · Disputes · Connections · Media
/// With optional badge counts on Feedback, Disputes, and Connections
class HeritageTabBar extends StatelessWidget {
  final TabController controller;
  final int? feedbackBadgeCount;
  final int? disputesBadgeCount;
  final int? connectionsBadgeCount;

  const HeritageTabBar({
    required this.controller,
    this.feedbackBadgeCount,
    this.disputesBadgeCount,
    this.connectionsBadgeCount,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.tertiary.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: controller,
        labelColor: AppTheme.tertiary,
        unselectedLabelColor: AppTheme.darkGreen.withOpacity(0.4),
        indicatorColor: AppTheme.tertiary,
        indicatorWeight: 2,
        isScrollable: true,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        tabs: [
          Tab(
            text: 'Archive',
            icon: null,
          ),
          Tab(
            text: _buildTabLabel('Feedback', feedbackBadgeCount),
            icon: null,
          ),
          Tab(
            text: _buildTabLabel('Disputes', disputesBadgeCount),
            icon: null,
          ),
          Tab(
            text: _buildTabLabel('Connections', connectionsBadgeCount),
            icon: null,
          ),
          Tab(
            text: 'Media',
            icon: null,
          ),
        ],
      ),
    );
  }

  String _buildTabLabel(String name, int? badgeCount) {
    if (badgeCount == null || badgeCount == 0) {
      return name;
    }
    return '$name  ●';
  }
}
