import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../Shared/theme/app_theme.dart';
import '../Components/index.dart';
import '../Models/index.dart';
import '../Services/heritage_providers.dart';
import '../heritage_theme.dart';

/// HeritageFeedbackScreen — Feedback tab showing comments from community
/// Organized by response status: All, Needs Response, Resolved
class HeritageFeedbackScreen extends StatefulWidget {
  final String orgId;

  const HeritageFeedbackScreen({
    required this.orgId,
    Key? key,
  }) : super(key: key);

  @override
  State<HeritageFeedbackScreen> createState() => _HeritageFeedbackScreenState();
}

class _HeritageFeedbackScreenState extends State<HeritageFeedbackScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final entryIdsProvider =
          Provider.of<OrgEntryIdsProvider>(context, listen: false);
      entryIdsProvider.fetchEntryIds(widget.orgId).then((_) {
        final commentsProvider =
            Provider.of<HeritageCommentsListProvider>(context, listen: false);
        commentsProvider.fetchCommentsList(entryIdsProvider.entryIds);
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entryIdsProvider = Provider.of<OrgEntryIdsProvider>(context);
    final commentsProvider = Provider.of<HeritageCommentsListProvider>(context);

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
            Tab(text: 'All'),
            Tab(text: 'Needs Response'),
            Tab(text: 'Resolved'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildCommentList(
                  commentsProvider.comments, commentsProvider.isLoading, null),
              _buildCommentList(
                  commentsProvider.comments, commentsProvider.isLoading, true),
              _buildCommentList(
                  commentsProvider.comments, commentsProvider.isLoading, false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommentList(
    List<CulturalComment> comments,
    bool isLoading,
    bool? needsResponse,
  ) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = needsResponse == null
        ? comments
        : needsResponse
            ? comments.where((c) => !c.hasReply).toList()
            : comments.where((c) => c.hasReply || c.isResolved).toList();

    if (filtered.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _buildCommentCard(filtered[index]),
    );
  }

  Widget _buildCommentCard(CulturalComment comment) {
    return HeritageCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Entry anchor
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppTheme.lightGreen.withOpacity(0.2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Entry title placeholder',
                  style: TextStyle(
                    color: AppTheme.darkGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppTheme.darkGreen.withOpacity(0.35),
              ),
            ],
          ),
          Divider(height: 14, color: AppTheme.darkGreen.withOpacity(0.1)),
          // Comment content
          Text(
            comment.commenterName,
            style: TextStyle(
              color: AppTheme.darkGreen,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            comment.commentBody,
            style: TextStyle(
              color: AppTheme.darkGreen.withOpacity(0.75),
              fontSize: 13,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ContentTypePill(contentType: comment.commentAction),
              const Spacer(),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  side: BorderSide(color: AppTheme.tertiary),
                  foregroundColor: AppTheme.tertiary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                ),
                child: const Text(
                  'Reply',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
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
            Icons.forum_outlined,
            size: 48,
            color: AppTheme.tertiary.withOpacity(0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'When community members respond to your submissions,\ntheir feedback appears here.',
            textAlign: TextAlign.center,
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
