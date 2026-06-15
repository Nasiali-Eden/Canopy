// lib/Culture/Heritage/Create/heritage_backgrounds_screen.dart
//
// Org-facing editor to set the background image for EVERYTHING in the org's
// country: the Country screen backdrop and each of the 12 category screens
// (Stories, Food, Music, …). Writes to heritage_hierarchy/{nodeId}.bg_image_url
// — the exact nodes the public Country and Category screens read.

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../Shared/theme/app_theme.dart';
import '../Services/heritage_content_types.dart';
import '../Services/heritage_data_service.dart';

class HeritageBackgroundsScreen extends StatefulWidget {
  final String orgId;
  const HeritageBackgroundsScreen({super.key, required this.orgId});

  @override
  State<HeritageBackgroundsScreen> createState() =>
      _HeritageBackgroundsScreenState();
}

class _HeritageBackgroundsScreenState extends State<HeritageBackgroundsScreen> {
  final _service = HeritageDataService();
  bool _loading = true;
  String? _countryId;
  String? _countryName;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      // From the org's `country`, else inferred from its entries' locality.
      final country = await _service.resolveOrgCountry(widget.orgId);
      if (country != null) {
        _countryId = country.id;
        _countryName = country.name;
      }
    } catch (_) {
      // leave unresolved
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5EDE0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5EDE0),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.darkGreen,
        title: const Text('Backgrounds',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(color: AppTheme.tertiary, strokeWidth: 2))
          : _countryId == null
              ? _noCountry()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    Text(
                      'Set the background image shown behind ${_countryName ?? 'your country'}\'s '
                      'Heritage pages. Each category can have its own.',
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: AppTheme.darkGreen.withOpacity(0.6)),
                    ),
                    const SizedBox(height: 16),
                    Text('COUNTRY IMAGES',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: AppTheme.darkGreen.withOpacity(0.5))),
                    const SizedBox(height: 10),
                    // Rectangular banner — country detail screen backdrop.
                    _BgRow(
                      nodeId: _countryId!,
                      field: 'bg_image_url',
                      label: 'Banner (wide) — country page',
                      icon: Icons.crop_landscape_outlined,
                      accent: AppTheme.primary,
                    ),
                    const SizedBox(height: 10),
                    // Square card — the Heritage-tab country card.
                    _BgRow(
                      nodeId: _countryId!,
                      field: 'card_image_url',
                      label: 'Card (square) — Heritage tab',
                      icon: Icons.crop_square_outlined,
                      accent: AppTheme.primary,
                    ),
                    const SizedBox(height: 18),
                    Text('CATEGORY BACKGROUNDS',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: AppTheme.darkGreen.withOpacity(0.5))),
                    const SizedBox(height: 10),
                    ...HeritageContentTypes.ordered.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _BgRow(
                          nodeId: HeritageDataService.categoryNodeId(
                              _countryId!, t.key),
                          label: t.label,
                          icon: t.icon,
                          accent: t.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('COMMUNITY BACKGROUNDS',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: AppTheme.darkGreen.withOpacity(0.5))),
                    const SizedBox(height: 10),
                    StreamBuilder<List<CommunitySummary>>(
                      stream:
                          _service.streamCommunitiesForCountry(_countryId!),
                      builder: (_, snap) {
                        final list =
                            snap.data ?? const <CommunitySummary>[];
                        if (list.isEmpty) {
                          return Text(
                            'Communities appear here once they have entries.',
                            style: TextStyle(
                                fontSize: 12.5,
                                color: AppTheme.darkGreen.withOpacity(0.45)),
                          );
                        }
                        return Column(
                          children: list
                              .map((c) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _BgRow(
                                      nodeId:
                                          HeritageDataService.communityNodeId(
                                              c.id),
                                      label: c.name,
                                      icon: Icons.groups_outlined,
                                      accent: HeritageContentTypes
                                          .communitiesAccent,
                                    ),
                                  ))
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
    );
  }

  Widget _noCountry() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.public_off_outlined,
                size: 40, color: AppTheme.darkGreen.withOpacity(0.4)),
            const SizedBox(height: 14),
            const Text('Set your country first',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkGreen)),
            const SizedBox(height: 6),
            Text(
              'Add your organisation\'s country in Edit Organisation, then come '
              'back to set backgrounds.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BgRow extends StatefulWidget {
  final String nodeId;
  final String label;
  final IconData icon;
  final Color accent;

  /// Which hierarchy field this row reads/writes (e.g. 'bg_image_url' for the
  /// rectangular banner, 'card_image_url' for the square heritage card).
  final String field;

  const _BgRow({
    required this.nodeId,
    required this.label,
    required this.icon,
    required this.accent,
    this.field = 'bg_image_url',
  });

  @override
  State<_BgRow> createState() => _BgRowState();
}

class _BgRowState extends State<_BgRow> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final ref = FirebaseStorage.instance.ref().child(
          'heritage_backgrounds/${widget.nodeId}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(File(file.path));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection(HeritageDataService.hierarchyCollection)
          .doc(widget.nodeId)
          .set({widget.field: url}, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<({String? bg, String? card})>(
      stream: HeritageDataService().streamNodeImages(widget.nodeId),
      builder: (context, snap) {
        final url = widget.field == 'card_image_url'
            ? snap.data?.card
            : snap.data?.bg;
        final hasBg = url != null && url.isNotEmpty;
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.tertiary.withOpacity(0.22)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: hasBg
                      ? CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _ph(),
                        )
                      : _ph(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.label,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.darkGreen)),
                    const SizedBox(height: 2),
                    Text(hasBg ? 'Background set' : 'Not set',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: hasBg
                                ? AppTheme.primary
                                : AppTheme.darkGreen.withOpacity(0.45))),
                  ],
                ),
              ),
              _uploading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.tertiary),
                      ),
                    )
                  : TextButton(
                      onPressed: _pickAndUpload,
                      child: Text(hasBg ? 'Change' : 'Set',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary)),
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _ph() => Container(
        color: widget.accent.withOpacity(0.14),
        alignment: Alignment.center,
        child: Icon(widget.icon, color: widget.accent, size: 22),
      );
}
