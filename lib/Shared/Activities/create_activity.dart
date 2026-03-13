import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

import '../../../Models/user.dart';
import '../../../Services/Activities/activity_service.dart';
import '../../../Shared/theme/app_theme.dart';
import 'activity.dart';

class CreateActivityScreen extends StatefulWidget {
  const CreateActivityScreen({super.key});

  @override
  State<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends State<CreateActivityScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // ── Form fields ──────────────────────────────────────────────────────────
  ActivityType _type = ActivityType.event;
  RegistrationState _registrationState = RegistrationState.open;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _venueController = TextEditingController();
  final _requiredParticipantsController = TextEditingController(text: '10');

  // Location
  String? _selectedCity;
  String? _selectedArea;
  double _lat = 0, _lng = 0;
  Map<String, List<Map<String, dynamic>>> _kenyaCities = {};

  DateTime? _date;
  TimeOfDay? _time;

  // Images — max 4 slots
  final List<XFile?> _images = [null, null, null, null];

  bool _saving = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        duration: const Duration(milliseconds: 400), vsync: this)
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadCities();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    _requiredParticipantsController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    try {
      final json =
          await rootBundle.loadString('assets/Cities/African/KenyaCities.json');
      final data = jsonDecode(json) as Map<String, dynamic>;
      final map = data['kenyaCitiesAndLocations'] as Map<String, dynamic>;
      final parsed = <String, List<Map<String, dynamic>>>{};
      for (final e in map.entries) {
        parsed[e.key] = (e.value as List).cast<Map<String, dynamic>>();
      }
      setState(() {
        _kenyaCities = parsed;
        _selectedCity = parsed.keys.contains('Nairobi')
            ? 'Nairobi'
            : (parsed.keys.isNotEmpty ? parsed.keys.first : null);
      });
    } catch (e) {
      debugPrint('KenyaCities load error: $e');
    }
  }

  // ── Area lookup ──────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _areas =>
      (_selectedCity != null && _kenyaCities[_selectedCity!] != null)
          ? _kenyaCities[_selectedCity!]!
          : [];

  Map<String, dynamic>? get _selectedAreaData => _selectedArea == null
      ? null
      : _areas.firstWhere(
          (a) => a['area'] == _selectedArea,
          orElse: () => {},
        );

  void _onAreaSelected(String? area) {
    setState(() {
      _selectedArea = area;
      final areaData = _selectedAreaData;
      if (areaData != null) {
        final coords = areaData['coordinates'] as Map<String, dynamic>? ?? {};
        _lat = (coords['lat'] as num?)?.toDouble() ?? 0;
        _lng = (coords['lng'] as num?)?.toDouble() ?? 0;
      }
    });
  }

  // ── Date / time ──────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              Theme.of(context).colorScheme.copyWith(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              Theme.of(context).colorScheme.copyWith(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (mounted) setState(() => _time = picked);
  }

  // ── Image picking ────────────────────────────────────────────────────────
  Future<void> _pickImage(int slot) async {
    final file =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (!mounted) return;
    setState(() => _images[slot] = file);
  }

  void _removeImage(int slot) => setState(() => _images[slot] = null);

  // ── Submit ───────────────────────────────────────────────────────────────
  Future<void> _create() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_date == null || _time == null) {
      _showSnack('Please select date and time');
      return;
    }
    if (_selectedCity == null) {
      _showSnack('Please select a city');
      return;
    }

    final dateTime = DateTime(
      _date!.year,
      _date!.month,
      _date!.day,
      _time!.hour,
      _time!.minute,
    );

    setState(() => _saving = true);

    try {
      final user = Provider.of<F_User?>(context, listen: false);
      final location = ActivityLocation(
        area: _selectedArea ?? _selectedCity!,
        city: _selectedCity!,
        venue: _venueController.text.trim(),
        lat: _lat,
        lng: _lng,
      );

      final id = await ActivityService().createActivity(
        type: _type.label,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        location: location.toMap(),
        dateTime: dateTime,
        requiredParticipants:
            int.tryParse(_requiredParticipantsController.text.trim()) ?? 10,
        createdBy: user?.uid,
        coverImage: _images.whereType<XFile>().isNotEmpty
            ? _images.whereType<XFile>().first
            : null,
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/activities/$id');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cities = _kenyaCities.keys.toList()..sort();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.lightGreen.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.close, size: 18, color: AppTheme.darkGreen),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text('Create Activity',
            style: TextStyle(
                color: AppTheme.darkGreen,
                fontWeight: FontWeight.w800,
                fontSize: 18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
              height: 1, color: AppTheme.lightGreen.withOpacity(0.18)),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Form(
          key: _formKey,
          child: Column(children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Activity Type selector ──────────────────────
                      _SectionLabel(
                          icon: Icons.category_outlined,
                          label: 'Activity Type',
                          color: AppTheme.primary),
                      const SizedBox(height: 10),
                      Row(
                        children: ActivityType.values.map((t) {
                          final cfg = ActivityTypeConfig.forType(t);
                          final selected = _type == t;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _type = t),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                margin: EdgeInsets.only(
                                    right: t != ActivityType.task ? 8 : 0),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? cfg.color
                                      : cfg.color.withOpacity(0.07),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected
                                        ? cfg.color
                                        : cfg.color.withOpacity(0.2),
                                  ),
                                ),
                                child: Column(children: [
                                  Icon(cfg.icon,
                                      size: 20,
                                      color:
                                          selected ? Colors.white : cfg.color),
                                  const SizedBox(height: 4),
                                  Text(t.label,
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: selected
                                              ? Colors.white
                                              : cfg.color)),
                                ]),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 22),

                      // ── Basic info ──────────────────────────────────
                      _SectionLabel(
                          icon: Icons.edit_outlined,
                          label: 'Basic Info',
                          color: AppTheme.primary),
                      const SizedBox(height: 10),

                      _StyledField(
                        controller: _titleController,
                        label: 'Title',
                        icon: Icons.title,
                        accentColor: AppTheme.primary,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Title is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _StyledTextArea(
                        controller: _descriptionController,
                        label: 'Description',
                        accentColor: AppTheme.primary,
                      ),

                      const SizedBox(height: 22),

                      // ── Location ─────────────────────────────────────
                      _SectionLabel(
                          icon: Icons.map_outlined,
                          label: 'Location',
                          color: AppTheme.accent),
                      const SizedBox(height: 10),

                      _StyledDropdown(
                        value: _selectedCity,
                        items: cities,
                        label: 'City / County',
                        icon: Icons.location_city_outlined,
                        accentColor: AppTheme.accent,
                        onChanged: (val) => setState(() {
                          _selectedCity = val;
                          _selectedArea = null;
                          _lat = 0;
                          _lng = 0;
                        }),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'City is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _StyledDropdown(
                        value: _selectedArea,
                        items: _areas.map((a) => a['area'] as String).toList(),
                        label: 'Area / Neighbourhood',
                        icon: Icons.pin_drop_outlined,
                        accentColor: AppTheme.lightGreen,
                        onChanged: _onAreaSelected,
                      ),
                      const SizedBox(height: 12),
                      _StyledField(
                        controller: _venueController,
                        label: 'Venue (e.g. Gate 2, Karura Forest)',
                        icon: Icons.place_outlined,
                        accentColor: AppTheme.accent,
                      ),

                      // Coords preview
                      if (_lat != 0 || _lng != 0) ...[
                        const SizedBox(height: 8),
                        Row(children: [
                          Icon(Icons.my_location,
                              size: 12,
                              color: AppTheme.accent.withOpacity(0.6)),
                          const SizedBox(width: 5),
                          Text(
                            'Coordinates: ${_lat.toStringAsFixed(4)}, ${_lng.toStringAsFixed(4)}',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.accent.withOpacity(0.7)),
                          ),
                        ]),
                      ],

                      const SizedBox(height: 22),

                      // ── Schedule ──────────────────────────────────────
                      _SectionLabel(
                          icon: Icons.schedule_outlined,
                          label: 'Schedule',
                          color: AppTheme.secondary),
                      const SizedBox(height: 10),

                      Row(children: [
                        Expanded(
                          child: _DateTimeButton(
                            icon: Icons.calendar_today_outlined,
                            label: _date == null
                                ? 'Pick Date'
                                : _formatDate(_date!),
                            color: AppTheme.secondary,
                            onTap: _pickDate,
                            filled: _date != null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DateTimeButton(
                            icon: Icons.access_time_rounded,
                            label: _time == null
                                ? 'Pick Time'
                                : _time!.format(context),
                            color: AppTheme.secondary,
                            onTap: _pickTime,
                            filled: _time != null,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      _StyledField(
                        controller: _requiredParticipantsController,
                        label: 'Required Participants',
                        icon: Icons.people_outline,
                        accentColor: AppTheme.secondary,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          return (n == null || n <= 0)
                              ? 'Enter a valid number'
                              : null;
                        },
                      ),

                      const SizedBox(height: 22),

                      // ── Registration ──────────────────────────────────
                      _SectionLabel(
                          icon: Icons.how_to_reg_outlined,
                          label: 'Registration',
                          color: AppTheme.tertiary),
                      const SizedBox(height: 10),

                      Row(
                        children: RegistrationState.values.map((s) {
                          final isSelected = _registrationState == s;
                          final isOpen = s == RegistrationState.open;
                          final color = isOpen
                              ? const Color(0xFF2E7D32)
                              : Colors.red.shade600;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _registrationState = s),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                margin: EdgeInsets.only(
                                    right: s == RegistrationState.open ? 8 : 0),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 14),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? color.withOpacity(0.08)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? color
                                        : Colors.grey.shade200,
                                    width: isSelected ? 2 : 1.2,
                                  ),
                                ),
                                child: Row(children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? color
                                          : Colors.grey.shade300,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(s.label,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? color
                                              : Colors.black54)),
                                  if (isSelected) ...[
                                    const Spacer(),
                                    Icon(Icons.check_circle,
                                        size: 16, color: color),
                                  ],
                                ]),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 22),

                      // ── Photos (4 slots) ──────────────────────────────
                      _SectionLabel(
                          icon: Icons.photo_library_outlined,
                          label:
                              'Photos  (${_images.where((i) => i != null).length}/4)',
                          color: AppTheme.darkGreen),
                      const SizedBox(height: 10),

                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.5,
                        ),
                        itemCount: 4,
                        itemBuilder: (context, i) => _ImageSlot(
                          index: i,
                          file: _images[i],
                          onPick: () => _pickImage(i),
                          onRemove: () => _removeImage(i),
                          isFirst: i == 0,
                        ),
                      ),

                      const SizedBox(height: 8),
                      Text(
                        'First photo will be used as the cover image',
                        style: TextStyle(fontSize: 11, color: Colors.black38),
                      ),

                      const SizedBox(height: 24),
                    ]),
              ),
            ),

            // ── Action row ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  )
                ],
              ),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.darkGreen,
                      side: BorderSide(
                          color: AppTheme.lightGreen.withOpacity(0.5)),
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppTheme.darkGreen,
                          AppTheme.primary,
                          AppTheme.secondary
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.28),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: _saving ? null : _create,
                        borderRadius: BorderRadius.circular(14),
                        child: Center(
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_circle_outline,
                                        color: Colors.white, size: 18),
                                    SizedBox(width: 8),
                                    Text('Create Activity',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IMAGE SLOT
// ─────────────────────────────────────────────────────────────────────────────
class _ImageSlot extends StatelessWidget {
  final int index;
  final XFile? file;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final bool isFirst;

  const _ImageSlot({
    required this.index,
    required this.file,
    required this.onPick,
    required this.onRemove,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: file == null ? onPick : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: file != null
              ? Colors.transparent
              : AppTheme.lightGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: file != null
                ? AppTheme.primary.withOpacity(0.3)
                : AppTheme.lightGreen.withOpacity(0.3),
            width: isFirst && file == null ? 2 : 1.2,
            // Dashed look via style isn't native; using solid
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: file == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      index == 0
                          ? Icons.add_photo_alternate_outlined
                          : Icons.add_photo_alternate_outlined,
                      size: 26,
                      color: isFirst
                          ? AppTheme.primary.withOpacity(0.5)
                          : AppTheme.lightGreen.withOpacity(0.6),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      index == 0 ? 'Cover Photo' : 'Photo ${index + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isFirst
                            ? AppTheme.primary.withOpacity(0.6)
                            : Colors.black38,
                      ),
                    ),
                    if (isFirst) ...[
                      const SizedBox(height: 2),
                      Text('Required',
                          style: TextStyle(
                              fontSize: 9,
                              color: AppTheme.primary.withOpacity(0.5))),
                    ]
                  ],
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    // Preview — on real device use Image.file(File(file.path))
                    Container(
                      color: AppTheme.lightGreen.withOpacity(0.15),
                      child: const Center(
                        child: Icon(Icons.image_outlined,
                            size: 30, color: AppTheme.primary),
                      ),
                    ),
                    // Remove button
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: onRemove,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 4)
                            ],
                          ),
                          child: const Icon(Icons.close,
                              size: 12, color: Colors.red),
                        ),
                      ),
                    ),
                    // Cover badge
                    if (isFirst)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Cover',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE FORM WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionLabel(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
      const SizedBox(width: 8),
      Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2)),
      const SizedBox(width: 10),
      Expanded(child: Container(height: 1, color: color.withOpacity(0.12))),
    ]);
  }
}

OutlineInputBorder _border(Color c, {double width = 1.2}) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: c, width: width));

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color accentColor;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _StyledField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.accentColor,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
          color: AppTheme.darkGreen, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(color: accentColor.withOpacity(0.75), fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 15, color: accentColor),
          ),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 52, minHeight: 52),
        border: _border(accentColor.withOpacity(0.2)),
        enabledBorder: _border(accentColor.withOpacity(0.22)),
        focusedBorder: _border(accentColor, width: 2),
        errorBorder: _border(Colors.red.shade300),
        focusedErrorBorder: _border(Colors.red.shade400, width: 2),
      ),
      validator: validator,
    );
  }
}

class _StyledTextArea extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final Color accentColor;

  const _StyledTextArea({
    required this.controller,
    required this.label,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: 4,
      style: const TextStyle(color: AppTheme.darkGreen, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        labelStyle:
            TextStyle(color: accentColor.withOpacity(0.75), fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(14),
        prefixIcon: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 68),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.notes, size: 15, color: accentColor),
          ),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 52, minHeight: 52),
        border: _border(accentColor.withOpacity(0.2)),
        enabledBorder: _border(accentColor.withOpacity(0.22)),
        focusedBorder: _border(accentColor, width: 2),
        errorBorder: _border(Colors.red.shade300),
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Description is required' : null,
    );
  }
}

class _StyledDropdown extends StatelessWidget {
  final String? value;
  final List<String> items;
  final String label;
  final IconData icon;
  final Color accentColor;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  const _StyledDropdown({
    required this.value,
    required this.items,
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: Colors.white,
      menuMaxHeight: 280,
      style: const TextStyle(
          color: AppTheme.darkGreen, fontSize: 14, fontWeight: FontWeight.w500),
      icon: Icon(Icons.keyboard_arrow_down_rounded,
          color: accentColor.withOpacity(0.6), size: 20),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(color: accentColor.withOpacity(0.75), fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 15, color: accentColor),
          ),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 52, minHeight: 52),
        border: _border(accentColor.withOpacity(0.2)),
        enabledBorder: _border(accentColor.withOpacity(0.22)),
        focusedBorder: _border(accentColor, width: 2),
        errorBorder: _border(Colors.red.shade300),
      ),
      items: items
          .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
          .toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
}

class _DateTimeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  const _DateTimeButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: filled ? color.withOpacity(0.07) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: filled ? color : color.withOpacity(0.22),
            width: filled ? 1.5 : 1.2,
          ),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: filled ? color : Colors.black45),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }
}

// Re-export ActivityTypeConfig so placeholders file can import from one place
class ActivityTypeConfig {
  final Color color;
  final Color lightColor;
  final IconData icon;
  final List<Color> gradient;

  const ActivityTypeConfig({
    required this.color,
    required this.lightColor,
    required this.icon,
    required this.gradient,
  });

  static ActivityTypeConfig forType(ActivityType type) {
    switch (type) {
      case ActivityType.cleanup:
        return ActivityTypeConfig(
          color: AppTheme.accent,
          lightColor: AppTheme.accent.withOpacity(0.1),
          icon: Icons.cleaning_services_outlined,
          gradient: [AppTheme.accent, const Color(0xFF2EBFA5)],
        );
      case ActivityType.event:
        return ActivityTypeConfig(
          color: AppTheme.tertiary,
          lightColor: AppTheme.tertiary.withOpacity(0.1),
          icon: Icons.celebration_outlined,
          gradient: [AppTheme.tertiary, const Color(0xFFE8A020)],
        );
      case ActivityType.task:
        return ActivityTypeConfig(
          color: AppTheme.secondary,
          lightColor: AppTheme.secondary.withOpacity(0.1),
          icon: Icons.task_alt_outlined,
          gradient: [AppTheme.secondary, AppTheme.primary],
        );
    }
  }
}
