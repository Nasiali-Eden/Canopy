// lib/Culture/Heritage/Create/edit_entry_screen.dart
//
// Edit an existing cultural entry: title, description, visibility, and cover
// image. Loads the live doc by id (so it reads the true written schema —
// cover_image_url etc.), saves back to cultural_entries/{id}. Cover is uploaded
// only on Save.

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../Shared/theme/app_theme.dart';

class HeritageEntryEditScreen extends StatefulWidget {
  final String entryId;
  const HeritageEntryEditScreen({super.key, required this.entryId});

  @override
  State<HeritageEntryEditScreen> createState() =>
      _HeritageEntryEditScreenState();
}

class _HeritageEntryEditScreenState extends State<HeritageEntryEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _visibility = 'public';
  String? _coverUrl;
  File? _newCover;
  String _contentTypeLabel = 'Entry';

  bool _loading = true;
  bool _saving = false;

  static const _visibilities = ['public', 'community', 'restricted', 'sealed'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('cultural_entries')
          .doc(widget.entryId)
          .get();
      final d = doc.data() ?? {};
      _titleCtrl.text = (d['title'] ?? '') as String;
      _descCtrl.text = (d['description'] ?? '') as String;
      final v = (d['visibility'] as String?) ?? 'public';
      _visibility = _visibilities.contains(v) ? v : 'public';
      _coverUrl = (d['cover_image_url'] ?? d['image_url']) as String?;
      _contentTypeLabel = _humanize((d['content_type'] as String?) ?? 'Entry');
    } catch (e) {
      debugPrint('EditEntry load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickCover() async {
    final f = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (f == null || !mounted) return;
    setState(() => _newCover = File(f.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      String? coverUrl = _coverUrl;
      if (_newCover != null) {
        final ref = FirebaseStorage.instance.ref().child(
            'cultural_entries/${widget.entryId}/cover_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_newCover!);
        coverUrl = await ref.getDownloadURL();
      }
      final now = Timestamp.now();
      await FirebaseFirestore.instance
          .collection('cultural_entries')
          .doc(widget.entryId)
          .update({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'visibility': _visibility,
        if (coverUrl != null) 'cover_image_url': coverUrl,
        'updated_at': now,
        'last_activity_at': now,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Entry updated'), backgroundColor: AppTheme.primary),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
        title: const Text('Edit entry',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppTheme.tertiary, strokeWidth: 2))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                children: [
                  // Cover
                  GestureDetector(
                    onTap: _pickCover,
                    child: Container(
                      height: 170,
                      width: double.infinity,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: AppTheme.lightGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppTheme.tertiary.withOpacity(0.3)),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_newCover != null)
                            Image.file(_newCover!, fit: BoxFit.cover)
                          else if ((_coverUrl ?? '').isNotEmpty)
                            CachedNetworkImage(
                                imageUrl: _coverUrl!, fit: BoxFit.cover)
                          else
                            _coverPrompt(),
                          Positioned(
                            right: 10,
                            top: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.45),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.photo_camera_outlined,
                                      size: 13, color: Colors.white),
                                  SizedBox(width: 5),
                                  Text('Cover',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(_contentTypeLabel.toUpperCase(),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: AppTheme.darkGreen.withOpacity(0.5))),
                  const SizedBox(height: 10),
                  _field(_titleCtrl, 'Title', Icons.title,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null),
                  _field(_descCtrl, 'Description', Icons.notes_outlined,
                      maxLines: 8),
                  const SizedBox(height: 4),
                  _visibilityField(),
                ],
              ),
            ),
      bottomSheet: _loading
          ? null
          : Container(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
              color: const Color(0xFFF5EDE0),
              child: SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white))
                      : const Text('Save changes',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
    );
  }

  Widget _coverPrompt() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 30, color: AppTheme.primary.withOpacity(0.7)),
            const SizedBox(height: 6),
            Text('Add a cover image',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkGreen.withOpacity(0.7))),
          ],
        ),
      );

  Widget _field(TextEditingController c, String label, IconData icon,
      {int maxLines = 1, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
        validator: validator,
        style: const TextStyle(
            fontSize: 14, color: AppTheme.darkGreen, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              TextStyle(fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.6)),
          filled: true,
          fillColor: Colors.white,
          prefixIcon: Icon(icon, size: 19, color: AppTheme.primary),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.tertiary.withOpacity(0.22)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.tertiary.withOpacity(0.22)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _visibilityField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.tertiary.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_outlined, size: 19, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _visibility,
                isExpanded: true,
                items: _visibilities
                    .map((v) => DropdownMenuItem(
                          value: v,
                          child: Text(_humanize(v),
                              style: const TextStyle(
                                  fontSize: 14, color: AppTheme.darkGreen)),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _visibility = v ?? _visibility),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _humanize(String s) => s.isEmpty
      ? s
      : s
          .replaceAll('_', ' ')
          .split(' ')
          .where((w) => w.isNotEmpty)
          .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
}
