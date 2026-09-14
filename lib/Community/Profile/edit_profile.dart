import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Models/user.dart';
import '../../Services/Profile/profile_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _phone = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _sendingReset = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = Provider.of<F_User?>(context, listen: false);
    if (user == null) {
      setState(() {
        _loading = false;
      });
      return;
    }

    final profile = await ProfileService().getProfile(userId: user.uid);
    if (!mounted) return;

    _name.text = profile?.name ?? '';
    _location.text = profile?.location ?? '';
    _phone.text = profile?.phone ?? '';

    setState(() {
      _loading = false;
    });
  }

  Future<void> _save() async {
    final user = Provider.of<F_User?>(context, listen: false);
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/welcome');
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      await ProfileService().updateProfile(
        userId: user.uid,
        name: _name.text.trim(),
        location: _location.text.trim(),
        phone: _phone.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Phase 2.4 — "password at minimum for every role". Sends a Firebase Auth
  /// reset-password email rather than an inline current/new-password form:
  /// it needs no re-authentication step here, and reuses the same reset flow
  /// login.dart already offers, so there's exactly one way this works.
  Future<void> _sendPasswordReset() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No email on file for this account to send a reset link to.'),
        ),
      );
      return;
    }
    setState(() => _sendingReset = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset link sent to $email')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send reset link: $e')),
      );
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<F_User?>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _name,
                                decoration: const InputDecoration(
                                    labelText: 'Display name'),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Name is required'
                                        : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _location,
                                decoration: const InputDecoration(
                                    labelText: 'Location / Zone'),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Location is required'
                                        : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _phone,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                    labelText: 'Phone number'),
                              ),
                              const SizedBox(height: 12),
                              Card(
                                child: ListTile(
                                  leading: _sendingReset
                                      ? const Padding(
                                          padding: EdgeInsets.all(2),
                                          child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2)),
                                        )
                                      : const Icon(Icons.lock_outline),
                                  title: const Text('Change password'),
                                  subtitle: const Text(
                                      'Sends a reset link to your account email'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: _sendingReset ? null : _sendPasswordReset,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Card(
                                child: ListTile(
                                  leading: const Icon(Icons.info_outline),
                                  title: const Text('Account'),
                                  subtitle: Text('UID: ${user?.uid ?? ''}'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
