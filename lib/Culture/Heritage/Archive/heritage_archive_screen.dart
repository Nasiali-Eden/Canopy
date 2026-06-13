import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../Shared/theme/app_theme.dart';
import '../Components/index.dart';
import '../Models/index.dart';
import '../Services/heritage_providers.dart';
import '../heritage_theme.dart';
import '../Create/country_completeness_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  HeritageArchiveScreen
//
//  Shows all cultural entries uploaded by this org with:
//    · Category + visibility filter chips
//    · Edit button per card (opens edit stub)
//    · Empty state with call to action
// ─────────────────────────────────────────────────────────────────────────────

class HeritageArchiveScreen extends StatefulWidget {
  final String orgId;

  const HeritageArchiveScreen({required this.orgId, Key? key}) : super(key: key);

  @override
  State<HeritageArchiveScreen> createState() => _HeritageArchiveScreenState();
}

class _HeritageArchiveScreenState extends State<HeritageArchiveScreen> {
  String _selectedCategory = 'All';
  String _selectedVisibility = 'All';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  static const _categories = [
    'All', 'oral_tradition', 'food_tradition', 'ingredient',
    'music_tradition', 'instrument', 'ceremony', 'craft_technique',
    'clothing_tradition', 'language_entry', 'place_knowledge',
    'medicine_knowledge', 'person',
  ];

  static const _categoryLabels = {
    'All': 'All',
    'oral_tradition': 'Oral Tradition',
    'food_tradition': 'Food',
    'ingredient': 'Ingredient',
    'music_tradition': 'Music',
    'instrument': 'Instrument',
    'ceremony': 'Ceremony',
    'craft_technique': 'Craft',
    'clothing_tradition': 'Clothing',
    'language_entry': 'Language',
    'place_knowledge': 'Place',
    'medicine_knowledge': 'Medicine',
    'person': 'Person',
  };

  static const _visibilities = ['All', 'public', 'community_only', 'restricted', 'sealed'];

  static const _visibilityLabels = {
    'All': 'All',
    'public': 'Public',
    'community_only': 'Community Only',
    'restricted': 'Restricted',
    'sealed': 'Sealed',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HeritageEntriesProvider>().fetchEntries(widget.orgId);
    });
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CulturalEntry> _filter(List<CulturalEntry> entries) {
    return entries.where((e) {
      final catMatch =
          _selectedCategory == 'All' || e.contentType == _selectedCategory;
      final visMatch =
          _selectedVisibility == 'All' || e.visibility == _selectedVisibility;
      final searchMatch = _searchQuery.isEmpty ||
          e.title.toLowerCase().contains(_searchQuery) ||
          (e.locality?.toLowerCase().contains(_searchQuery) ?? false);
      return catMatch && visMatch && searchMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HeritageEntriesProvider>();
    final entries = provider.entries;
    final isLoading = provider.isLoading;

    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.tertiary),
      );
    }

    final filtered = _filter(entries);

    return CustomScrollView(
      slivers: [
        // Stats strip
        SliverToBoxAdapter(
          child: _buildStatsStrip(entries),
        ),

        // Per-country "missing features" checklist (Phase 5.3)
        SliverToBoxAdapter(
          child: CountryCompletenessCard(orgId: widget.orgId),
        ),

        // Search bar
        SliverToBoxAdapter(
          child: _buildSearchBar(),
        ),

        // Category filter
        SliverToBoxAdapter(
          child: _buildFilterRow(),
        ),

        // Entry list or empty state
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(entries.isEmpty),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildEntryCard(filtered[i]),
                ),
                childCount: filtered.length,
              ),
            ),
          ),
      ],
    );
  }

  // ── Stats strip ──────────────────────────────────────────────────────────

  Widget _buildStatsStrip(List<CulturalEntry> entries) {
    final public = entries.where((e) => e.visibility == 'public').length;
    final communities = entries
        .map((e) => e.locality)
        .where((l) => l != null && l.isNotEmpty)
        .toSet()
        .length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: HeritageTheme.heritageCardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1FC4A961)),
        boxShadow: [HeritageTheme.heritageCardShadow],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statCell(entries.length.toString(), 'ENTRIES'),
          _divider(),
          _statCell(communities.toString(), 'COMMUNITIES'),
          _divider(),
          _statCell(public.toString(), 'PUBLIC'),
        ],
      ),
    );
  }

  Widget _statCell(String number, String label) {
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
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.darkGreen.withOpacity(0.45),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 28,
        color: const Color(0x1FC4A961),
      );

  // ── Search bar ───────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search entries…',
          hintStyle: TextStyle(color: AppTheme.darkGreen.withOpacity(0.35), fontSize: 14),
          prefixIcon: Icon(Icons.search, color: AppTheme.darkGreen.withOpacity(0.4), size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, size: 18, color: AppTheme.darkGreen.withOpacity(0.4)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: HeritageTheme.heritageCardBackground,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0x1FC4A961)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0x1FC4A961)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.tertiary.withOpacity(0.5)),
          ),
        ),
      ),
    );
  }

  // ── Filter row ───────────────────────────────────────────────────────────

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _filterLabel('TYPE'),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final active = _selectedCategory == cat;
                return _filterChip(
                  label: _categoryLabels[cat] ?? cat,
                  active: active,
                  onTap: () => setState(() => _selectedCategory = cat),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          _filterLabel('VISIBILITY'),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _visibilities.map((vis) {
                final active = _selectedVisibility == vis;
                return _filterChip(
                  label: _visibilityLabels[vis] ?? vis,
                  active: active,
                  onTap: () => setState(() => _selectedVisibility = vis),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterLabel(String text) => Text(
        text,
        style: TextStyle(
          color: AppTheme.tertiary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      );

  Widget _filterChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppTheme.tertiary : Colors.transparent,
          border: Border.all(
            color: active ? AppTheme.tertiary : AppTheme.tertiary.withOpacity(0.3),
          ),
          borderRadius: BorderRadius.circular(HeritageTheme.pillBorderRadius),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppTheme.darkGreen.withOpacity(0.6),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ── Entry card ───────────────────────────────────────────────────────────

  Widget _buildEntryCard(CulturalEntry entry) {
    return HeritageCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Active dispute banner
          if (entry.hasActiveDispute)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF3CD),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_outlined,
                      size: 13, color: Colors.amber),
                  const SizedBox(width: 6),
                  Text(
                    'Dispute pending',
                    style: TextStyle(
                      color: Colors.amber[800],
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover image / emoji
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: _typeColor(entry.contentType).withOpacity(0.12),
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
                            _typeEmoji(entry.contentType),
                            style: const TextStyle(fontSize: 28),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),

                // Content
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
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          ContentTypePill(contentType: entry.contentType),
                          if (entry.subcategory != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              entry.subcategory!,
                              style: TextStyle(
                                color: AppTheme.darkGreen.withOpacity(0.5),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (entry.locality != null)
                        Row(
                          children: [
                            Icon(Icons.place_outlined,
                                size: 11,
                                color: AppTheme.darkGreen.withOpacity(0.45)),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                entry.locality!,
                                style: TextStyle(
                                  color: AppTheme.darkGreen.withOpacity(0.5),
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                          _countChip(Icons.chat_bubble_outline,
                              entry.commentCount),
                          const SizedBox(width: 10),
                          _countChip(Icons.link, entry.connectionCount),
                        ],
                      ),
                    ],
                  ),
                ),

                // Edit button
                const SizedBox(width: 4),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _onEditTapped(entry),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppTheme.tertiary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.tertiary.withOpacity(0.2)),
                      ),
                      child: Icon(Icons.edit_outlined,
                          size: 16, color: AppTheme.tertiary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onEditTapped(CulturalEntry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditOptionsSheet(entry: entry),
    );
  }

  Widget _countChip(IconData icon, int count) => Row(
        children: [
          Icon(icon, size: 11, color: AppTheme.darkGreen.withOpacity(0.45)),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: TextStyle(
              color: AppTheme.darkGreen.withOpacity(0.45),
              fontSize: 10,
            ),
          ),
        ],
      );

  // ── Empty state ──────────────────────────────────────────────────────────

  Widget _buildEmptyState(bool noEntries) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFC4A961).withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFC4A961).withOpacity(0.2)),
            ),
            child: const Center(
              child: Text('📜', style: TextStyle(fontSize: 36)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            noEntries ? 'Your archive is empty' : 'No entries match these filters',
            style: TextStyle(
              color: AppTheme.darkGreen,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'Cormorant Garamond',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            noEntries
                ? 'Tap the Add Entry tab to begin documenting\ncultural knowledge for your community.'
                : 'Try removing some filters to see more entries.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.darkGreen.withOpacity(0.55),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          if (!noEntries) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() {
                _selectedCategory = 'All';
                _selectedVisibility = 'All';
                _searchController.clear();
              }),
              child: const Text('Clear filters'),
            ),
          ],
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Color _typeColor(String type) {
    return HeritageTheme.contentTypePillColours[type] ?? AppTheme.tertiary;
  }

  String _typeEmoji(String type) {
    const map = {
      'oral_tradition': '📖', 'food_tradition': '🍳', 'ingredient': '🌿',
      'music_tradition': '🎵', 'instrument': '🥁', 'ceremony': '🕯️',
      'craft_technique': '🛠️', 'clothing_tradition': '👘',
      'language_entry': '🗣️', 'place_knowledge': '📍',
      'medicine_knowledge': '🌱', 'person': '👤',
    };
    return map[type] ?? '📝';
  }
}

// ─── Edit options sheet ───────────────────────────────────────────────────────

class _EditOptionsSheet extends StatelessWidget {
  final CulturalEntry entry;

  const _EditOptionsSheet({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Entry title
          Row(
            children: [
              Text(
                entry.title,
                style: TextStyle(
                  color: AppTheme.darkGreen,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Cormorant Garamond',
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _option(
            context,
            icon: Icons.edit_note_outlined,
            label: 'Edit content',
            subtitle: 'Update title, description, and knowledge',
            onTap: () {
              Navigator.pop(context);
              _showSoon(context, 'Edit content');
            },
          ),
          _option(
            context,
            icon: Icons.photo_library_outlined,
            label: 'Manage media',
            subtitle: 'Add or remove images and audio',
            onTap: () {
              Navigator.pop(context);
              _showSoon(context, 'Media management');
            },
          ),
          _option(
            context,
            icon: Icons.visibility_outlined,
            label: 'Change visibility',
            subtitle: 'Control who can see this entry',
            onTap: () {
              Navigator.pop(context);
              _showSoon(context, 'Visibility settings');
            },
          ),
          _option(
            context,
            icon: Icons.place_outlined,
            label: 'Edit locality',
            subtitle: 'Update community and location details',
            onTap: () {
              Navigator.pop(context);
              _showSoon(context, 'Locality edit');
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _confirmDelete(context);
            },
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete entry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red[700],
              side: BorderSide(color: Colors.red.withOpacity(0.4)),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _option(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.tertiary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: AppTheme.tertiary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkGreen)),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.darkGreen.withOpacity(0.5))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: AppTheme.darkGreen.withOpacity(0.3)),
            ],
          ),
        ),
      ),
    );
  }

  void _showSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — coming soon'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text(
            'This action cannot be undone. The entry will be permanently removed from the archive.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Delete — coming soon'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
