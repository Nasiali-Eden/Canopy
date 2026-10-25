// lib/Community/Profile/edit_profile.dart
//
// Edit profile (v2): photo, display name, location, phone. Password lives in
// Password & security. The photo uploads only on Save.

import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../Services/Profile/profile_service.dart';
import '../../theme/canopy_components.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _phone = TextEditingController();
  String? _photoUrl;
  File? _newPhoto;
  bool _loading = true, _failed = false, _saving = false, _showErrors = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _location, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (_uid == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final p = await ProfileService().getProfile(userId: _uid);
      _name.text = p?.name ?? '';
      _location.text = p?.location ?? '';
      _phone.text = p?.phone ?? '';
      _photoUrl = p?.photoUrl;
    } catch (_) {
      _failed = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pick() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 82, maxWidth: 800);
    if (f != null) setState(() => _newPhoto = File(f.path));
  }

  Future<void> _save() async {
    setState(() => _showErrors = true);
    if (_name.text.trim().isEmpty || _location.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      String? photo;
      if (_newPhoto != null) {
        final ref = FirebaseStorage.instance.ref('users/$_uid/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_newPhoto!);
        photo = await ref.getDownloadURL();
      }
      await ProfileService().updateProfile(
        userId: _uid!,
        name: _name.text.trim(),
        location: _location.text.trim(),
        phone: _phone.text.trim(),
        photoUrl: photo,
      );
      if (!mounted) return;
      showCanopySnack(context, 'Profile saved.');
      Navigator.pop(context);
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't save. Try again.", error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final bar = canopyAppBar(context, title: 'Edit profile');
    if (_uid == null) return CanopyScaffold(appBar: bar, body: const CanopySignedOutState());
    if (_loading) return CanopyScaffold(appBar: bar, body: const Center(child: CircularProgressIndicator()));
    if (_failed) return CanopyScaffold(appBar: bar, body: CanopyErrorState(title: "Couldn't load your profile", onRetry: _load));
    return CanopyScaffold(
      appBar: bar,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, CanopySpace.s32),
        children: [
          Center(
            child: Semantics(
              button: true,
              label: 'Change photo',
              child: GestureDetector(
                onTap: _pick,
                child: Column(children: [
                  _newPhoto != null
                      ? ClipOval(child: Image.file(_newPhoto!, width: 96, height: 96, fit: BoxFit.cover))
                      : CanopyAvatar(url: _photoUrl, name: _name.text, size: 96),
                  const SizedBox(height: CanopySpace.s8),
                  Text('Change photo', style: CanopyType.label.copyWith(color: p.primaryInk)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: CanopySpace.section),
          CanopyTextField(
            label: 'Display name',
            controller: _name,
            error: _showErrors && _name.text.trim().isEmpty ? 'Your name is needed.' : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: CanopySpace.s16),
          CanopyTextField(
            label: 'Where you are',
            hint: 'e.g. Kibera, Nairobi',
            controller: _location,
            error: _showErrors && _location.text.trim().isEmpty ? 'Add your area so nearby activities show.' : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: CanopySpace.s16),
          CanopyTextField.phone(label: 'Phone (optional)', controller: _phone),
          const SizedBox(height: CanopySpace.section),
          CanopyListGroup(children: [
            CanopyListRow(icon: Icons.lock_outline, title: 'Password & security', onTap: () => Navigator.pushNamed(context, '/security')),
          ]),
        ],
      ),
      sticky: StickyActionBar(children: [CanopyButton(label: 'Save', expand: true, loading: _saving, onPressed: _save)]),
    );
  }
}
