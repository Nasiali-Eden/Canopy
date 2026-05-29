import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../Shared/theme/app_theme.dart';
import '../heritage_theme.dart';

class CommunitySelection {
  final String id;
  final String name;

  const CommunitySelection({required this.id, required this.name});
}

class LocalitySelectorSheet extends StatefulWidget {
  const LocalitySelectorSheet({super.key});

  @override
  State<LocalitySelectorSheet> createState() => _LocalitySelectorSheetState();
}

class _LocalitySelectorSheetState extends State<LocalitySelectorSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  List<_CommunityItem> _all = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('heritage_hierarchy')
          .where('node_type', isEqualTo: 'community')
          .orderBy('name')
          .get();

      final items = snap.docs.map((d) {
        final data = d.data();
        return _CommunityItem(
          id: d.id,
          name: (data['name'] as String?) ?? d.id,
          nameVariants: (data['name_variants'] as List?)?.cast<String>() ?? const [],
        );
      }).toList();

      setState(() {
        _all = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<_CommunityItem> get _filtered {
    if (_query.isEmpty) return _all;
    return _all.where((c) {
      return c.name.toLowerCase().contains(_query) ||
          c.nameVariants.any((v) => v.toLowerCase().contains(_query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              _buildHandle(),
              _buildHeader(),
              _buildSearchBar(),
              const Divider(height: 1),
              Expanded(child: _buildList(scrollController)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          Text(
            'Select Community',
            style: TextStyle(
              color: AppTheme.darkGreen,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFamily: 'Cormorant Garamond',
              fontStyle: FontStyle.italic,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            color: AppTheme.darkGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search communities…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                )
              : null,
          filled: true,
          fillColor: HeritageTheme.heritageBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildList(ScrollController scrollController) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(height: 8),
            Text('Failed to load communities', style: TextStyle(color: Colors.grey[600])),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final filtered = _filtered;

    return ListView.builder(
      controller: scrollController,
      itemCount: filtered.length + 1, // +1 for "unknown" pinned option
      itemBuilder: (context, index) {
        if (index == 0) return _buildUnknownOption();
        final item = filtered[index - 1];
        return _buildCommunityTile(item);
      },
    );
  }

  Widget _buildUnknownOption() {
    return Column(
      children: [
        ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.help_outline, color: Colors.grey[500], size: 20),
          ),
          title: const Text(
            'Community unknown',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
          subtitle: Text(
            "I can't identify the community",
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          onTap: () => Navigator.pop(context, null),
        ),
        const Divider(),
      ],
    );
  }

  Widget _buildCommunityTile(_CommunityItem item) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.people_outline, color: AppTheme.primary, size: 20),
      ),
      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: item.nameVariants.isNotEmpty
          ? Text(
              item.nameVariants.join(', '),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            )
          : null,
      onTap: () => Navigator.pop(
        context,
        CommunitySelection(id: item.id, name: item.name),
      ),
    );
  }
}

class _CommunityItem {
  final String id;
  final String name;
  final List<String> nameVariants;

  const _CommunityItem({
    required this.id,
    required this.name,
    required this.nameVariants,
  });
}
