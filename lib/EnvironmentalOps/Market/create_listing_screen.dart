// lib/EnvironmentalOps/Market/create_listing_screen.dart
//
// Post a listing (ENVOPS_HANDOFF §3.3) — five steps with the WizardStepper:
//   1 What      Sell / One-time buy / Recurring buy
//   2 Material  category + type (taxonomy) + grade
//   3 Amount    quantity (big number + keypad) + price per kg, or open to
//               negotiation (+ total) + logistics
//   4 Place     area + exact spot from the phone + photo + contact number
//   5 Review    → "Post listing"
// Money is shown, never moved — payment is handled outside the app. People who
// want the material contact the poster directly on the number given here.

import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../Models/environmental/enums/material_category.dart';
import '../../Models/environmental/models/market_order.dart';
import '../../Services/Environmental/environment_ops_service.dart';
import '../../Services/Geo/geo_registry.dart';
import '../../theme/canopy_components.dart';
import '../../theme/tokens/services_tokens.dart' show CanopyFees;
import '../envops_ui.dart';

enum _Kind { sell, buyOnce, buyRecurring }

class CreateListingScreen extends StatefulWidget {
  final String? orgId;
  final Map<String, dynamic>? orgData;

  const CreateListingScreen({this.orgId, this.orgData, super.key});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  static const _steps = ['What', 'Material', 'Amount', 'Place', 'Review'];

  int _step = 0;
  _Kind? _kind;
  List<Map<String, dynamic>> _categories = const [];
  bool _taxonomyFailed = false;
  Map<String, dynamic>? _category, _subType;
  String? _grade;
  String _qty = '';
  final _price = TextEditingController();
  final _notes = TextEditingController();
  bool _canCollect = true, _canDeliver = false;
  String? _place;
  bool _countyWide = false;
  File? _image;
  final _phone = TextEditingController();
  bool _negotiable = false;
  double? _lat, _lng;
  bool _locating = false;
  bool _saving = false, _showErrors = false;

  @override
  void initState() {
    super.initState();
    _loadTaxonomy();
  }

  @override
  void dispose() {
    _price.dispose();
    _notes.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _loadTaxonomy() async {
    try {
      final json = jsonDecode(await rootBundle.loadString('assets/environmental/material_types.json')) as Map<String, dynamic>;
      if (mounted) setState(() => _categories = (json['categories'] as List).cast<Map<String, dynamic>>());
    } catch (_) {
      if (mounted) setState(() => _taxonomyFailed = true);
    }
  }

  bool get _selling => _kind == _Kind.sell;
  double get _qtyKg => double.tryParse(_qty) ?? 0;
  double get _pricePerKg => double.tryParse(_price.text.trim()) ?? 0;
  /// Kenyan mobile → +254XXXXXXXXX, or null if it isn't one.
  String? get _contact {
    var d = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('254')) d = d.substring(3);
    if (d.startsWith('0')) d = d.substring(1);
    return d.length == 9 ? '+254$d' : null;
  }

  List<String> get _grades => ((_subType?['grades'] as List?) ?? const []).map((e) => '$e').toList();

  String? _errorFor(int s) => switch (s) {
        0 => _kind == null ? 'Choose what you are posting.' : null,
        1 => _subType == null ? 'Choose the material.' : null,
        2 => _qtyKg <= 0 ? 'Enter how many kg.' : (!_canCollect && !_canDeliver ? 'Choose how the material moves.' : null),
        3 => _place == null ? 'Choose where.' : (_contact == null ? 'Add a Kenyan mobile number people can reach you on.' : null),
        _ => null,
      };

  void _next() {
    if (_errorFor(_step) != null) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() {
      _showErrors = false;
      _step++;
    });
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      setState(() {
        _showErrors = false;
        _step--;
      });
    }
  }

  Future<void> _pickPlace() async {
    await GeoRegistry.instance.ensureLoaded();
    if (!mounted) return;
    final picked = await showCanopySheet<(String, bool)>(context, tall: true, builder: (_) => const _PlaceSheet());
    if (picked != null) {
      setState(() {
        _place = picked.$1;
        _countyWide = picked.$2;
      });
    }
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) showCanopySnack(context, 'Allow location access to pin the exact spot.', error: true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
      if (mounted) setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't get your position. Try again outside.", error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickImage() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 82);
    if (f != null) setState(() => _image = File(f.path));
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final service = EnvironmentOpsService.instance;
      final ctx = await service.resolveContext();
      final uid = FirebaseAuth.instance.currentUser?.uid ?? ctx?.uid ?? '';
      final orgId = widget.orgId ?? ctx?.orgId ?? '';
      final orgName = ((widget.orgData?['org_name'] ?? widget.orgData?['name']) as String?) ?? ctx?.orgName ?? '';
      if (orgId.isEmpty) throw StateError('not linked');
      String? imageUrl;
      if (_image != null) {
        final ref = FirebaseStorage.instance.ref('market_listings/${DateTime.now().millisecondsSinceEpoch}_$uid.jpg');
        await ref.putFile(_image!);
        imageUrl = await ref.getDownloadURL();
      }
      final category = MaterialCategory.fromFirestoreKey((_category!['id'] as String?) ?? 'plastics');
      await service.createMarketOrder(
        orgId: orgId,
        uid: uid,
        orgName: orgName,
        orderType: _selling ? MarketOrderType.sell : MarketOrderType.buy,
        category: category,
        categoryLabel: (_category!['label'] as String?) ?? category.displayLabel,
        materialType: (_subType!['label'] as String?) ?? 'Material',
        materialSubTypeId: (_subType!['id'] as String?) ?? '',
        grade: _grade,
        quantityKg: _qtyKg,
        unit: (_subType!['units'] as String?) ?? 'kg',
        pricePerUnit: _pricePerKg,
        negotiable: _negotiable || _pricePerKg <= 0,
        contactPhone: _contact ?? '',
        lat: _lat,
        lng: _lng,
        notes: _notes.text.trim(),
        locationText: _place ?? '',
        canCollect: _canCollect,
        canDeliver: _canDeliver,
        imageUrl: imageUrl,
        isRecurring: _kind == _Kind.buyRecurring,
      );
      if (!mounted) return;
      showCanopySnack(context, _kind == _Kind.buyRecurring ? 'Standing order posted — collectors near you can find it.' : 'Listing posted.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showCanopySnack(context,
            e is StateError ? 'Link an organisation before posting.' : "Couldn't post the listing. Check your connection and try again.",
            error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final last = _step == _steps.length - 1;
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: CanopyScaffold(
        appBar: canopyAppBar(
          context,
          title: 'Post a listing',
          leading: IconButton(icon: Icon(_step == 0 ? Icons.close : Icons.arrow_back), tooltip: _step == 0 ? 'Close' : 'Back', onPressed: _back),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
          children: [
            CanopyStepper(step: _step + 1, total: _steps.length, label: _steps[_step], stepLabels: _steps),
            const SizedBox(height: CanopySpace.section),
            ..._body(p),
            if (_showErrors && _errorFor(_step) != null)
              Padding(
                padding: const EdgeInsets.only(top: CanopySpace.s16),
                child: Text(_errorFor(_step)!, style: CanopyType.body.copyWith(color: p.danger)),
              ),
          ],
        ),
        sticky: StickyActionBar(children: [
          FieldButton(label: last ? 'Post listing' : 'Continue', loading: _saving, onPressed: last ? _submit : _next),
        ]),
      ),
    );
  }

  List<Widget> _body(CanopyPalette p) {
    switch (_step) {
      case 0:
        Widget opt(_Kind k, IconData icon, String title, String line) => Padding(
              padding: const EdgeInsets.only(bottom: CanopySpace.s12),
              child: CanopyOptionCard(selected: _kind == k, icon: icon, title: title, caption: line, onTap: () => setState(() => _kind = k)),
            );
        return [
          Text('What are you posting?', style: CanopyType.title.copyWith(color: p.ink)),
          const SizedBox(height: CanopySpace.s16),
          opt(_Kind.sell, Icons.sell_outlined, 'Sell material', 'You have material and want a buyer'),
          opt(_Kind.buyOnce, Icons.shopping_cart_outlined, 'Buy once', 'You want a set amount, one time'),
          opt(_Kind.buyRecurring, Icons.autorenew, 'Recurring buy', 'You always buy this — a standing order collectors can rely on'),
        ];
      case 1:
        if (_taxonomyFailed) return [CanopyErrorState(inline: true, title: "Couldn't load materials.", onRetry: _loadTaxonomy)];
        if (_categories.isEmpty) return const [CanopyListSkeleton(rows: 4)];
        return [
          Text('Which material?', style: CanopyType.title.copyWith(color: p.ink)),
          const SizedBox(height: CanopySpace.s12),
          Wrap(spacing: CanopySpace.s8, runSpacing: CanopySpace.s8, children: [
            for (final c in _categories)
              CanopyFilterChip(
                label: c['label'] as String? ?? '',
                selected: _category?['id'] == c['id'],
                onTap: () => setState(() {
                  _category = c;
                  _subType = null;
                  _grade = null;
                }),
              ),
          ]),
          if (_category != null) ...[
            const SizedBox(height: CanopySpace.section),
            CanopyListGroup(children: [
              for (final s in (_category!['sub_types'] as List).cast<Map<String, dynamic>>())
                CanopyListRow(
                  title: s['label'] as String? ?? '',
                  subtitle: s['description'] as String?,
                  chevron: false,
                  trailing: _subType?['id'] == s['id'] ? Icon(Icons.check, color: p.ink) : null,
                  onTap: () => setState(() {
                    _subType = s;
                    _grade = null;
                  }),
                ),
            ]),
          ],
          if (_grades.isNotEmpty) ...[
            const SizedBox(height: CanopySpace.section),
            Text('Grade (optional)', style: CanopyType.label.copyWith(color: p.ink)),
            const SizedBox(height: CanopySpace.s8),
            Wrap(spacing: CanopySpace.s8, runSpacing: CanopySpace.s8, children: [
              for (final g in _grades)
                CanopyFilterChip(label: g, selected: _grade == g, onTap: () => setState(() => _grade = _grade == g ? null : g)),
            ]),
          ],
        ];
      case 2:
        final hint = _subType?['price_hint_ksh'] as Map?;
        final total = _qtyKg * _pricePerKg;
        return [
          Text(_selling ? 'How much do you have?' : 'How much do you want?', style: CanopyType.title.copyWith(color: p.ink)),
          const SizedBox(height: CanopySpace.s16),
          BigNumberInput(value: _qty, unit: 'kg', caption: _kind == _Kind.buyRecurring ? 'per collection' : null),
          const SizedBox(height: CanopySpace.s16),
          FieldKeypad(value: _qty, onChanged: (v) => setState(() => _qty = v)),
          const SizedBox(height: CanopySpace.section),
          CanopyTextField.money(
            label: _selling ? 'Your price per kg (optional)' : 'You will pay per kg (optional)',
            controller: _price,
            helper: hint == null ? 'Leave empty to negotiate with whoever contacts you.' : 'Usually ${CanopyFees.ksh((hint['min'] as num).round())}–${(hint['max'] as num).round()} per kg',
            onChanged: (_) => setState(() {}),
          ),
          CanopyCheckRow(
            label: 'Open to negotiation',
            value: _negotiable || _pricePerKg <= 0,
            onChanged: _pricePerKg <= 0 ? (_) {} : (v) => setState(() => _negotiable = v),
          ),
          if (total > 0) ...[
            const SizedBox(height: CanopySpace.s8),
            Text('About ${CanopyFees.ksh(total.round())} in total', style: CanopyType.bodyStrong.copyWith(color: p.ink)),
          ],
          const SizedBox(height: CanopySpace.section),
          Text('HOW IT MOVES', style: CanopyField.fieldEyebrow.copyWith(color: p.inkMuted)),
          const SizedBox(height: CanopySpace.s8),
          CanopyCheckRow(
            label: _selling ? 'We deliver' : 'Sellers deliver to us',
            value: _canDeliver,
            onChanged: (v) => setState(() => _canDeliver = v),
          ),
          CanopyCheckRow(
            label: _selling ? 'Buyer collects' : 'We collect',
            value: _canCollect,
            onChanged: (v) => setState(() => _canCollect = v),
          ),
          const SizedBox(height: CanopySpace.s16),
          CanopyTextField(label: 'Notes (optional)', hint: 'Condition, bagging, when it\'s available', controller: _notes, minLines: 2, maxLines: 4),
        ];
      case 3:
        return [
          Text('Where?', style: CanopyType.title.copyWith(color: p.ink)),
          const SizedBox(height: CanopySpace.s16),
          CanopyPickerField(
            label: 'Area',
            value: _place == null ? null : '$_place${_countyWide ? ' · county-wide' : ''}',
            placeholder: 'A local area or a whole county',
            icon: Icons.place_outlined,
            onTap: _pickPlace,
          ),
          const SizedBox(height: CanopySpace.s12),
          Row(children: [
            Expanded(
              child: Text(
                  _lat == null ? 'Add the exact spot so people can find you.' : 'Exact spot saved (${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}).',
                  style: CanopyType.caption.copyWith(color: p.inkMuted)),
            ),
            CanopyButton.secondary(
                label: _lat == null ? 'Use my location' : 'Update',
                size: CanopyButtonSize.compact,
                loading: _locating,
                onPressed: _locating ? null : _useMyLocation),
          ]),
          const SizedBox(height: CanopySpace.section),
          CanopyTextField.phone(label: 'Phone number to contact', controller: _phone, onChanged: (_) => setState(() {})),
          const SizedBox(height: CanopySpace.s4),
          Text('People call or message you on this number. Payment and handover are between you and them.',
              style: CanopyType.caption.copyWith(color: p.inkMuted)),
          const SizedBox(height: CanopySpace.section),
          Text('Photo (optional)', style: CanopyType.label.copyWith(color: p.ink)),
          const SizedBox(height: CanopySpace.s8),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(CanopyRadius.sm),
              child: Material(
                color: p.surfaceMuted,
                child: InkWell(
                  onTap: _pickImage,
                  child: _image != null
                      ? Image.file(_image!, fit: BoxFit.cover)
                      : Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.add_a_photo_outlined, color: p.inkMuted),
                            Text('A real photo gets more responses', style: CanopyType.caption.copyWith(color: p.inkMuted)),
                          ]),
                        ),
                ),
              ),
            ),
          ),
        ];
      default:
        return [
          Text('Check and post', style: CanopyType.title.copyWith(color: p.ink)),
          const SizedBox(height: CanopySpace.s16),
          CanopyListGroup(children: [
            CanopyFactRow(label: 'Posting', value: switch (_kind) { _Kind.sell => 'Selling', _Kind.buyOnce => 'Buy order', _ => 'Recurring buy' }),
            CanopyFactRow(label: 'Material', value: [_subType?['label'], _grade].whereType<String>().join(' · ')),
            CanopyFactRow(label: 'Quantity', value: '${_qtyKg % 1 == 0 ? _qtyKg.round() : _qtyKg} kg'),
            CanopyFactRow(
                label: 'Price',
                value: _pricePerKg > 0 ? '${CanopyFees.ksh(_pricePerKg.round())} per kg${_negotiable ? ' · negotiable' : ''}' : 'Open to negotiation'),
            CanopyFactRow(label: 'Contact', value: _contact ?? ''),
            CanopyFactRow(
              label: 'Moves by',
              value: [
                if (_canDeliver) _selling ? 'We deliver' : 'Sellers deliver',
                if (_canCollect) _selling ? 'Buyer collects' : 'We collect',
              ].join(' · '),
            ),
            CanopyFactRow(label: 'Where', value: _place ?? ''),
          ]),
          const SizedBox(height: CanopySpace.s16),
          Text('It shows to everyone in the area on the Canopy market. Payment is handled outside the app — people contact you directly.',
              style: CanopyType.caption.copyWith(color: p.inkMuted)),
        ];
    }
  }
}

/// County → area picker. Pops (label, countyWide).
class _PlaceSheet extends StatefulWidget {
  const _PlaceSheet();

  @override
  State<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<_PlaceSheet> {
  String _q = '';
  GeoCounty? _county;

  @override
  Widget build(BuildContext context) {
    final geo = GeoRegistry.instance;
    final county = _county;
    return CanopySheetBody(
      title: county == null ? 'Choose a county' : county.name,
      children: [
        CanopyTextField.search(
          key: ValueKey(county?.id ?? 'counties'),
          hint: county == null ? 'Search counties' : 'Search areas in ${county.name}',
          onChanged: (v) => setState(() => _q = v),
        ),
        const SizedBox(height: CanopySpace.s12),
        if (county != null)
          Align(
            alignment: Alignment.centerLeft,
            child: CanopyButton.quiet(
              label: 'Back to counties',
              size: CanopyButtonSize.compact,
              onPressed: () => setState(() {
                _county = null;
                _q = '';
              }),
            ),
          ),
        CanopyListGroup(children: [
          if (county == null)
            for (final c in geo.searchCounties(_q).take(60))
              CanopyListRow(
                title: c.name,
                subtitle: '${c.regionName} · ${c.areas.length} areas',
                onTap: () => setState(() {
                  _county = c;
                  _q = '';
                }),
              )
          else ...[
            CanopyListRow(
              icon: Icons.select_all,
              title: 'All of ${county.name}',
              subtitle: 'County-wide',
              chevron: false,
              onTap: () => Navigator.pop(context, (county.name, true)),
            ),
            for (final a in geo.searchAreas(_q, countyId: county.id).take(80))
              CanopyListRow(title: a.name, chevron: false, onTap: () => Navigator.pop(context, ('${a.name}, ${county.name}', false))),
          ],
        ]),
      ],
    );
  }
}
