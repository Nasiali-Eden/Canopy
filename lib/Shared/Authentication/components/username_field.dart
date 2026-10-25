// lib/Shared/Authentication/components/username_field.dart
//
// Phase 3.2 — "standard uniqueness-check UX (debounced lookup, inline
// 'available'/'taken' state)". One shared widget so every registration flow
// (member, organisation, marketplace seller) gets the same behaviour rather
// than each screen re-implementing its own debounce/availability logic.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../Services/Authentication/username_service.dart';
import '../../../theme/canopy_components.dart';

enum _UsernameCheckState { idle, checking, available, taken, invalid }

class UsernameField extends StatefulWidget {
  final TextEditingController controller;

  /// Called whenever the checked availability state changes — registration
  /// screens use this to gate their submit button (only true once a check
  /// has actually resolved "available", not just "not yet known to be
  /// taken").
  final ValueChanged<bool> onAvailabilityChanged;

  const UsernameField({
    super.key,
    required this.controller,
    required this.onAvailabilityChanged,
  });

  @override
  State<UsernameField> createState() => _UsernameFieldState();
}

class _UsernameFieldState extends State<UsernameField> {
  final _service = UsernameService();
  Timer? _debounce;
  _UsernameCheckState _state = _UsernameCheckState.idle;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    final raw = widget.controller.text;
    final error = UsernameService.validationError(raw);
    if (error != null) {
      setState(() => _state =
          raw.trim().isEmpty ? _UsernameCheckState.idle : _UsernameCheckState.invalid);
      widget.onAvailabilityChanged(false);
      return;
    }
    setState(() => _state = _UsernameCheckState.checking);
    widget.onAvailabilityChanged(false);
    _debounce = Timer(const Duration(milliseconds: 450), () => _check(raw));
  }

  Future<void> _check(String raw) async {
    final myRequest = ++_requestId;
    final available = await _service.isAvailable(raw);
    if (!mounted || myRequest != _requestId) return; // superseded by newer input
    setState(
        () => _state = available ? _UsernameCheckState.available : _UsernameCheckState.taken);
    widget.onAvailabilityChanged(available);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final (String? helper, String? error, Widget? suffix) = switch (_state) {
      _UsernameCheckState.idle => ("Your unique handle. It can't be changed later.", null, null),
      _UsernameCheckState.checking => (
          'Checking…',
          null,
          const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
        ),
      _UsernameCheckState.available => ('Available', null, Icon(Icons.check_circle, color: p.success)),
      _UsernameCheckState.taken => (null, 'Already taken. Try another.', null),
      _UsernameCheckState.invalid => (null, '3–20 characters: letters, numbers and underscore only.', null),
    };
    return CanopyTextField(
      label: 'Username',
      controller: widget.controller,
      prefixText: '@',
      helper: helper,
      error: error,
      suffix: suffix,
    );
  }
}
