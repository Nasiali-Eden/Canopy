// lib/Organization/Events/create_event_screen.dart
//
// Host event + live QR + ended (ORG_HANDOFF §3.2).
//   Create: landscape cover slot, title, date/time, meeting point, points per
//     check-in stepper (gold numerals), spots → "Publish event". The form
//     draft autosaves on this phone until published.
//   Live (EventLiveScreen): white screen, org, title, "+N pts per check-in",
//     EventQr (#000 on #FFF even in dark), "Scan with the Canopy app", live
//     count in 48pt numerals, quiet danger "End event" (confirm).
//   Ended: labels, metrics (checked in · points given), check-in list,
//     primary "Post a recap with photos".
// Points are awarded only by the checkInToEvent Cloud Function.

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Services/Events/events_service.dart';
import '../../Shared/Activities/create_article.dart';
import '../../theme/canopy_components.dart';
import '../org_ui.dart';

class CreateEventScreen extends StatefulWidget {
  final String orgId;
  final String orgName;
  const CreateEventScreen({super.key, required this.orgId, required this.orgName});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _service = EventsService();
  final _title = TextEditingController();
  final _place = TextEditingController();
  final _spots = TextEditingController();
  DateTime? _when;
  int _points = 10;
  File? _cover;
  bool _publishing = false;
  bool _showErrors = false;
  bool _failed = false;
  bool _draftRestored = false;

  String get _draftKey => 'event_draft_${widget.orgId}';

  @override
  void initState() {
    super.initState();
    _restoreDraft();
    for (final c in [_title, _place, _spots]) {
      c.addListener(_saveDraft);
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _place, _spots]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _restoreDraft() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_draftKey);
      if (raw == null) return;
      final d = jsonDecode(raw) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _title.text = d['title'] as String? ?? '';
        _place.text = d['place'] as String? ?? '';
        _spots.text = d['spots'] as String? ?? '';
        _points = d['points'] as int? ?? 10;
        final w = d['when'] as String?;
        _when = w == null ? null : DateTime.tryParse(w);
        _draftRestored = _title.text.isNotEmpty;
      });
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    try {
      await (await SharedPreferences.getInstance()).setString(
          _draftKey,
          jsonEncode({
            'title': _title.text,
            'place': _place.text,
            'spots': _spots.text,
            'points': _points,
            'when': _when?.toIso8601String(),
          }));
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    try {
      await (await SharedPreferences.getInstance()).remove(_draftKey);
    } catch (_) {}
  }

  Future<void> _pickWhen() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _when ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_when ?? now));
    if (t == null) return;
    setState(() => _when = DateTime(d.year, d.month, d.day, t.hour, t.minute));
    _saveDraft();
  }

  Future<void> _publish() async {
    setState(() => _showErrors = true);
    if (_title.text.trim().isEmpty) return;
    setState(() {
      _publishing = true;
      _failed = false;
    });
    try {
      String? coverUrl;
      if (_cover != null) {
        final ref = FirebaseStorage.instance
            .ref('events/${widget.orgId}/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_cover!);
        coverUrl = await ref.getDownloadURL();
      }
      final event = await _service.createEvent(
        orgId: widget.orgId,
        orgName: widget.orgName,
        title: _title.text.trim(),
        pointsPerCheckin: _points,
        scheduledAt: _when,
        meetingPoint: _place.text.trim(),
        spots: int.tryParse(_spots.text.trim()),
        coverImageUrl: coverUrl,
      );
      await _clearDraft();
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => EventLiveScreen(eventId: event.id)));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Host an event'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            CanopySpace.gutter, CanopySpace.s4, CanopySpace.gutter, CanopySpace.s32),
        children: [
          if (_draftRestored) ...[
            Text('Draft restored from this phone.',
                style: CanopyType.caption.copyWith(color: p.inkMuted)),
            const SizedBox(height: CanopySpace.s8),
          ],
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _cover == null
                ? DashedBorder(
                    color: p.outlineStrong,
                    radius: CanopyRadius.md,
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: () async {
                          final x = await ImagePicker()
                              .pickImage(source: ImageSource.gallery, imageQuality: 82);
                          if (x != null) setState(() => _cover = File(x.path));
                        },
                        child: Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.add_photo_alternate_outlined, color: p.ink),
                            const SizedBox(height: CanopySpace.s4),
                            Text('Add a cover photo (landscape)',
                                style: CanopyType.label.copyWith(color: p.ink)),
                          ]),
                        ),
                      ),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(CanopyRadius.md),
                    child: Stack(fit: StackFit.expand, children: [
                      Image.file(_cover!, fit: BoxFit.cover),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: CanopyIconButton(
                            icon: Icons.close,
                            tooltip: 'Remove cover',
                            onImage: true,
                            onPressed: () => setState(() => _cover = null)),
                      ),
                    ]),
                  ),
          ),
          const SizedBox(height: CanopySpace.s16),
          CanopyTextField(
            label: 'Title',
            hint: 'Saturday riverbank clean-up',
            controller: _title,
            error: _showErrors && _title.text.trim().isEmpty ? 'Give the event a title.' : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: CanopySpace.s16),
          CanopyPickerField(
            label: 'Date & time',
            value: _when == null ? null : DateFormat('EEE d MMM · HH:mm').format(_when!),
            placeholder: 'Now',
            icon: Icons.calendar_today_outlined,
            onTap: _pickWhen,
          ),
          const SizedBox(height: CanopySpace.s16),
          CanopyTextField(label: 'Meeting point', hint: 'Gate B, Karura Forest', controller: _place),
          const SizedBox(height: CanopySpace.s16),
          Text('Points per check-in', style: CanopyType.label.copyWith(color: p.ink)),
          const SizedBox(height: CanopySpace.s4),
          Row(children: [
            CanopyIconButton(
              icon: Icons.remove,
              tooltip: 'Fewer points',
              filled: true,
              onPressed: _points <= 5
                  ? null
                  : () {
                      setState(() => _points -= 5);
                      _saveDraft();
                    },
            ),
            Expanded(
              child: Center(
                  child: Text('+$_points',
                      style: CanopyType.hero.copyWith(color: p.goldInk, fontSize: 36))),
            ),
            CanopyIconButton(
              icon: Icons.add,
              tooltip: 'More points',
              filled: true,
              onPressed: _points >= 100
                  ? null
                  : () {
                      setState(() => _points += 5);
                      _saveDraft();
                    },
            ),
          ]),
          const SizedBox(height: CanopySpace.s16),
          CanopyTextField(
            label: 'Spots (optional)',
            hint: 'No limit',
            controller: _spots,
            keyboardType: TextInputType.number,
          ),
          if (_failed) ...[
            const SizedBox(height: CanopySpace.s16),
            const CanopyCallout(
                kind: CalloutKind.danger,
                text: "The event didn't publish. Your draft is still here — try again."),
          ],
        ],
      ),
      sticky: StickyActionBar(children: [
        CanopyButton(
            label: 'Publish event', expand: true, loading: _publishing, onPressed: _publish),
        Text('Publishing opens check-in and shows the QR code.',
            textAlign: TextAlign.center, style: CanopyType.caption.copyWith(color: p.inkMuted)),
      ]),
    );
  }
}

/// The organiser's live QR screen; flips to the ended summary when ended.
class EventLiveScreen extends StatefulWidget {
  final String eventId;
  const EventLiveScreen({super.key, required this.eventId});

  @override
  State<EventLiveScreen> createState() => _EventLiveScreenState();
}

class _EventLiveScreenState extends State<EventLiveScreen> {
  final _service = EventsService();
  late final _event = _service.watchEvent(widget.eventId);
  late final _checkins = _service.watchCheckins(widget.eventId).asBroadcastStream();
  bool _ending = false;

  Future<void> _end() async {
    final ok = await showCanopyConfirm(
      context,
      title: 'End this event?',
      message: 'The QR code stops working straight away. Members who haven\'t checked in can\'t anymore.',
      confirmLabel: 'End event',
      cancelLabel: 'Keep it open',
      danger: true,
    );
    if (!ok) return;
    setState(() => _ending = true);
    try {
      await _service.endEvent(widget.eventId);
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't end the event. Try again.", error: true);
    } finally {
      if (mounted) setState(() => _ending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CanopyEvent?>(
      stream: _event,
      builder: (context, snap) {
        final e = snap.data;
        if (e == null) {
          return CanopyScaffold(
            appBar: canopyAppBar(context),
            body: snap.hasError
                ? const CanopyErrorState(title: "Couldn't load this event")
                : const Center(child: CircularProgressIndicator()),
          );
        }
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _checkins,
          builder: (context, cs) {
            final list = cs.data ?? const [];
            return e.active ? _live(e, list) : _ended(e, list);
          },
        );
      },
    );
  }

  Widget _live(CanopyEvent e, List<Map<String, dynamic>> checkins) {
    // Always white with black ink so the code reads in daylight, whatever
    // the app theme.
    const light = CanopyPalette.light;
    return Theme(
      data: Theme.of(context).copyWith(brightness: Brightness.light, extensions: const [light]),
      child: Builder(builder: (context) {
        return Scaffold(
          backgroundColor: CanopyWorkspace.qrBackground,
          appBar: canopyAppBar(context, title: 'Check-in open'),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
                CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
            children: [
              Text(e.orgName.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: CanopyType.eyebrow.copyWith(color: light.inkMuted)),
              const SizedBox(height: CanopySpace.s4),
              Text(e.title,
                  textAlign: TextAlign.center, style: CanopyType.title.copyWith(color: light.ink)),
              Center(child: PointsLabel(e.pointsPerCheckin, fontSize: 18)),
              Text('per check-in',
                  textAlign: TextAlign.center, style: CanopyType.caption.copyWith(color: light.inkMuted)),
              const SizedBox(height: CanopySpace.s16),
              Center(child: EventQr(data: e.qrPayload)),
              const SizedBox(height: CanopySpace.s12),
              Text('Scan with the Canopy app · Home → Log work',
                  textAlign: TextAlign.center, style: CanopyType.body.copyWith(color: light.ink)),
              const SizedBox(height: CanopySpace.s24),
              Center(
                child: CanopyCountUp(
                  value: checkins.length,
                  style: CanopyType.hero.copyWith(fontSize: 48, height: 1, color: light.ink),
                ),
              ),
              Text('checked in${e.spots != null ? ' of ${e.spots}' : ''}',
                  textAlign: TextAlign.center, style: CanopyType.body.copyWith(color: light.inkMuted)),
            ],
          ),
          bottomNavigationBar: StickyActionBar(children: [
            CanopyButton.quietDanger(
                label: 'End event', expand: true, loading: _ending, onPressed: _end),
          ]),
        );
      }),
    );
  }

  Widget _ended(CanopyEvent e, List<Map<String, dynamic>> checkins) {
    final p = context.canopy;
    final points = checkins.fold<int>(0, (t, c) => t + ((c['pointsAwarded'] as num?)?.toInt() ?? 0));
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Event ended'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            CanopySpace.gutter, CanopySpace.s4, CanopySpace.gutter, CanopySpace.s32),
        children: [
          LabelRow(children: [
            StatusLabel('Ended', color: p.inkMuted),
            if (e.endedAt != null)
              StatusLabel(DateFormat('d MMM · HH:mm').format(e.endedAt!), color: p.inkMuted),
          ]),
          const SizedBox(height: CanopySpace.s4),
          Text(e.title, style: CanopyType.display.copyWith(color: p.ink)),
          const SizedBox(height: CanopySpace.s16),
          Row(children: [
            Expanded(child: MetricTile(value: '${checkins.length}', label: 'Checked in')),
            const SizedBox(width: CanopySpace.s16),
            Expanded(child: MetricTile(value: '$points', label: 'Points given')),
          ]),
          const SizedBox(height: CanopySpace.section),
          const CanopySectionHeader(title: 'Check-ins', padding: EdgeInsets.zero),
          if (checkins.isEmpty)
            const CanopyEmptyState(
                boxed: true, icon: Icons.qr_code_2, title: 'Nobody checked in')
          else
            CanopyListGroup(children: [
              for (final c in checkins)
                FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance.collection('Users').doc(c['id'] as String).get(),
                  builder: (_, u) {
                    final name = (u.data?.data()?['name'] as String?) ?? 'Member';
                    final at = (c['checkedInAt'] as Timestamp?)?.toDate();
                    return DenseRow(
                      leading: CanopyAvatar(name: name, size: 32),
                      title: name,
                      subtitle: at == null ? null : DateFormat('HH:mm').format(at),
                      trailing: PointsLabel((c['pointsAwarded'] as num?)?.toInt() ?? 0),
                    );
                  },
                ),
            ]),
        ],
      ),
      sticky: StickyActionBar(children: [
        CanopyButton(
          label: 'Post a recap with photos',
          expand: true,
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const CreateArticleScreen())),
        ),
      ]),
    );
  }
}
