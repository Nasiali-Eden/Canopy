import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../Shared/theme/app_theme.dart';
import '../Components/index.dart';
import '../Models/index.dart';
import '../Services/heritage_providers.dart';
import '../heritage_theme.dart';

/// HeritageArchiveScreen — Archive tab showing all cultural entries
/// Displays entries as cards with cover images, titles, metadata, and filters
class HeritageArchiveScreen extends StatefulWidget {
  final String orgId;

  const HeritageArchiveScreen({
    required this.orgId,
    Key? key,
  }) : super(key: key);

  @override
  State<HeritageArchiveScreen> createState() => _HeritageArchiveScreenState();
}

class _HeritageArchiveScreenState extends State<HeritageArchiveScreen> {
  String _selectedCategory = 'All';
  String _selectedVisibility = 'All';

  static const List<String> _categories = [
    'All',
    'Stories',
    'Food',
    'Music',
    'Ceremony',
    'Craft',
    'Place',
    'Language',
    'Ingredients',
  ];

  static const List<String> _visibilities = [
    'All',
    'Public',
    'Community Only',
    'Restricted',
    'Sealed',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider =
          Provider.of<HeritageEntriesProvider>(context, listen: false);
      provider.fetchEntries(widget.orgId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<HeritageEntriesProvider>(context);
    final entries = provider.entries;
    final isLoading = provider.isLoading;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Apply filters
    final filteredEntries = _filterEntries(entries);

    // Calculate statistics
    final totalEntries = entries.length;
    final totalConnections = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.connectionCount,
    );
    final totalComments = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.commentCount,
    );

    return SingleChildScrollView(
      child: Column(
        children: [
          // Summary strip
          _buildSummaryStrip(totalEntries, totalConnections, totalComments),

          // Filter row
          _buildFilterRow(),

          // Entry list
          if (filteredEntries.isEmpty)
            _buildEmptyState()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemCount: filteredEntries.length,
              itemBuilder: (context, index) =>
                  _buildEntryCard(filteredEntries[index]),
            ),
        ],
      ),
    );
  }

  List<CulturalEntry> _filterEntries(List<CulturalEntry> entries) {
    return entries.where((entry) {
      final categoryMatch =
          _selectedCategory == 'All' || entry.contentType == _selectedCategory;
      final visibilityMatch = _selectedVisibility == 'All' ||
          _matchesVisibility(entry.visibility, _selectedVisibility);
      return categoryMatch && visibilityMatch;
    }).toList();
  }

  bool _matchesVisibility(String visibility, String selected) {
    final visibilityMap = {
      'public': 'Public',
      'community': 'Community Only',
      'restricted': 'Restricted',
      'sealed': 'Sealed',
    };
    return visibilityMap[visibility] == selected;
  }

  Widget _buildSummaryStrip(int total, int connections, int comments) {
    return HeritageCard(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryCell('$total', 'ENTRIES'),
          Container(
            width: 1,
            height: 30,
            color: AppTheme.darkGreen.withOpacity(0.15),
          ),
          _summaryCell('$connections', 'CONNECTIONS'),
          Container(
            width: 1,
            height: 30,
            color: AppTheme.darkGreen.withOpacity(0.15),
          ),
          _summaryCell('$comments', 'COMMENTS'),
        ],
      ),
    );
  }

  Widget _summaryCell(String number, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          number,
          style: TextStyle(
            color: AppTheme.darkGreen,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.darkGreen.withOpacity(0.5),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Category filter
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'CATEGORY',
              style: TextStyle(
                color: AppTheme.tertiary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((category) {
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategory = category);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? AppTheme.tertiary : Colors.transparent,
                        border: Border.all(
                          color: AppTheme.tertiary.withOpacity(0.3),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(
                            HeritageTheme.pillBorderRadius),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppTheme.darkGreen.withOpacity(0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          // Visibility filter
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'VISIBILITY',
              style: TextStyle(
                color: AppTheme.tertiary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _visibilities.map((visibility) {
                final isSelected = _selectedVisibility == visibility;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedVisibility = visibility);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? AppTheme.tertiary : Colors.transparent,
                        border: Border.all(
                          color: AppTheme.tertiary.withOpacity(0.3),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(
                            HeritageTheme.pillBorderRadius),
                      ),
                      child: Text(
                        visibility,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppTheme.darkGreen.withOpacity(0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(CulturalEntry entry) {
    return HeritageCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
      leftBorder: entry.hasActiveDispute
          ? const BorderSide(color: Colors.amber, width: 4)
          : null,
      child: Column(
        children: [
          if (entry.hasActiveDispute)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Dispute pending',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          Row(
            children: [
              // Cover image
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color:
                      _getContentTypeColor(entry.contentType).withOpacity(0.15),
                  image: entry.imageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(entry.imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: entry.imageUrl == null
                    ? Center(
                        child: Text(
                          _getContentTypeEmoji(entry.contentType),
                          style: const TextStyle(fontSize: 28),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              // Right side content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: TextStyle(
                        color: AppTheme.darkGreen,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ContentTypePill(contentType: entry.contentType),
                        if (entry.subcategory != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            entry.subcategory!,
                            style: TextStyle(
                              color: AppTheme.darkGreen.withOpacity(0.55),
                              fontSize: 11,
                            ),
                          ),
                        ]
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (entry.locality != null)
                      Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 11,
                            color: AppTheme.darkGreen.withOpacity(0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            entry.locality!,
                            style: TextStyle(
                              color: AppTheme.darkGreen.withOpacity(0.5),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        VisibilityDot(
                          visibility: entry.visibility,
                          labelFontSize: 10,
                        ),
                        const Spacer(),
                        _buildCountChip(
                            Icons.chat_bubble_outline, entry.commentCount),
                        const SizedBox(width: 12),
                        _buildCountChip(Icons.link, entry.connectionCount),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCountChip(IconData icon, int count) {
    return Row(
      children: [
        Icon(
          icon,
          size: 10,
          color: AppTheme.darkGreen.withOpacity(0.5),
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            color: AppTheme.darkGreen.withOpacity(0.5),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(
              Icons.archive_outlined,
              size: 48,
              color: AppTheme.tertiary.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No entries match these filters',
              style: TextStyle(
                color: AppTheme.darkGreen.withOpacity(0.5),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getContentTypeColor(String contentType) {
    return HeritageTheme.contentTypePillColours[contentType] ??
        AppTheme.tertiary;
  }

  String _getContentTypeEmoji(String contentType) {
    const emojis = {
      'Stories': '📖',
      'Food': '🍳',
      'Music': '🎵',
      'Ceremony': '🕯️',
      'Craft': '🛠️',
      'Place': '📍',
      'Language': '🗣️',
      'Ingredients': '🌿',
    };
    return emojis[contentType] ?? '📝';
  }
}
