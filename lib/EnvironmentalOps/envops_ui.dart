// lib/EnvironmentalOps/envops_ui.dart
//
// Environmental Ops field kit (ENVOPS_HANDOFF §1–2). Field mode is the main
// theme plus field rules: every control ≥ 56dp, key actions and numbers ink
// on canvas, a "field notebook" voice (uppercase eyebrow + hairline rule,
// ruled signals, monospaced times). Also: GPS chip, capture button, big
// number input + keypad, collector row, readiness checklist, legend, and
// the on-device draft store behind "Waiting to send".

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/canopy_components.dart';
import '../theme/tokens/envops_tokens.dart';

export '../theme/tokens/envops_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VOICE
// ─────────────────────────────────────────────────────────────────────────────

/// Uppercase eyebrow + hairline rule — the field-notebook section head.
class FieldEyebrow extends StatelessWidget {
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;
  const FieldEyebrow(this.text,
      {super.key, this.actionLabel, this.onAction, this.padding = const EdgeInsets.only(top: CanopySpace.section, bottom: CanopySpace.s12)});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return Padding(
      padding: padding,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(text.toUpperCase(), style: CanopyField.fieldEyebrow.copyWith(color: p.inkMuted))),
          if (actionLabel != null && onAction != null)
            CanopyButton.quiet(label: actionLabel!, size: CanopyButtonSize.compact, onPressed: onAction),
        ]),
        const SizedBox(height: CanopySpace.s4),
        Container(height: 1, color: p.outline),
      ]),
    );
  }
}

/// 2px ink rule, value 30, caption. Tappable.
class SignalCard extends StatelessWidget {
  final String value;
  final String caption;
  final VoidCallback? onTap;
  const SignalCard({super.key, required this.value, required this.caption, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return Semantics(
      button: onTap != null,
      label: '$value $caption',
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: CanopyField.minTarget),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: CanopySpace.s8, bottom: CanopySpace.s8),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: p.ink, width: CanopyField.signalRule))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: CanopyField.signalValue.copyWith(color: p.ink)),
              const SizedBox(height: CanopySpace.s2),
              Text(caption, style: CanopyType.caption.copyWith(color: p.inkMuted)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Two-column grid of signals.
class SignalGrid extends StatelessWidget {
  final List<SignalCard> signals;
  const SignalGrid({super.key, required this.signals});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < signals.length; i += 2) {
      rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: signals[i]),
        const SizedBox(width: CanopySpace.s16),
        Expanded(child: i + 1 < signals.length ? signals[i + 1] : const SizedBox.shrink()),
      ]));
      if (i + 2 < signals.length) rows.add(const SizedBox(height: CanopySpace.s12));
    }
    return Column(children: rows);
  }
}

/// 52px mono time column + what / where / who.
class FieldNoteRow extends StatelessWidget {
  final String time;
  final String what;
  final String? where;
  final String? who;
  final Widget? status;
  final VoidCallback? onTap;
  const FieldNoteRow({super.key, required this.time, required this.what, this.where, this.who, this.status, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: CanopyField.minTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: CanopySpace.s8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 52, child: Text(time, style: CanopyField.fieldNoteTime.copyWith(color: p.inkMuted))),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(what, style: CanopyType.bodyStrong.copyWith(color: p.ink)),
                if ((where ?? '').isNotEmpty || (who ?? '').isNotEmpty)
                  Text([where, who].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                      style: CanopyType.caption.copyWith(color: p.inkMuted)),
                if (status != null) ...[const SizedBox(height: CanopySpace.s2), status!],
              ]),
            ),
            if (onTap != null) Icon(Icons.chevron_right, color: p.inkFaint),
          ]),
        ),
      ),
    );
  }
}

String fieldNoteTime(DateTime? t) {
  if (t == null) return '—';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  String two(int n) => n.toString().padLeft(2, '0');
  if (diff == 0) return '${two(t.hour)}:${two(t.minute)}';
  if (diff == 1) return 'Yday';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${t.day} ${m[t.month - 1]}';
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTROLS
// ─────────────────────────────────────────────────────────────────────────────

/// 56 tall, radius 10, 16.5 text. Ink fill (primary) or 1.5 ink outline.
class FieldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool loading;
  final IconData? icon;
  final bool danger;
  const FieldButton(
      {super.key, required this.label, required this.onPressed, this.primary = true, this.loading = false, this.icon, this.danger = false});
  const FieldButton.secondary({super.key, required this.label, required this.onPressed, this.loading = false, this.icon})
      : primary = false,
        danger = false;

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final enabled = onPressed != null && !loading;
    final fg = primary ? p.canvas : (danger ? p.danger : p.ink);
    final bg = primary ? (enabled ? p.ink : p.inkFaint) : Colors.transparent;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CanopyField.buttonRadius),
          side: primary ? BorderSide.none : BorderSide(color: enabled ? fg : p.outlineStrong, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(CanopyField.buttonRadius),
          onTap: enabled ? onPressed : null,
          child: SizedBox(
            height: CanopyField.buttonHeight,
            child: Center(
              child: loading
                  ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      if (icon != null) ...[Icon(icon, size: 20, color: enabled ? fg : p.inkMuted), const SizedBox(width: CanopySpace.s8)],
                      Flexible(
                        child: Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CanopyField.buttonText.copyWith(color: enabled ? fg : p.inkMuted)),
                      ),
                    ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round capture button: ink fill, canvas text, double ring.
class CaptureButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double size;
  const CaptureButton({super.key, required this.label, required this.onPressed, this.size = CanopyField.captureSize});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: size + 12,
          height: size + 12,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: enabled ? p.ink : p.outlineStrong, width: 2)),
          child: Container(
            decoration: BoxDecoration(shape: BoxShape.circle, color: enabled ? p.ink : p.inkFaint),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(CanopySpace.s8),
            child: Text(label,
                textAlign: TextAlign.center, style: CanopyField.buttonText.copyWith(color: p.canvas, fontSize: size > 100 ? 17 : 15)),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GPS
// ─────────────────────────────────────────────────────────────────────────────

enum GpsState { finding, good, weak, blocked, failed }

GpsState gpsStateFor(double? accuracyM, {bool timedOut = false}) {
  if (accuracyM == null) return timedOut ? GpsState.failed : GpsState.finding;
  if (accuracyM <= CanopyField.gpsGood) return GpsState.good;
  if (accuracyM <= CanopyField.gpsWeakMax) return GpsState.weak;
  return GpsState.blocked;
}

/// 34 tall; dot + text + ±m. >25 m blocks capture with a reason.
class GpsChip extends StatelessWidget {
  final double? accuracyM;
  final bool timedOut;
  const GpsChip({super.key, this.accuracyM, this.timedOut = false});

  static String reasonFor(GpsState s) => switch (s) {
        GpsState.finding => 'Finding your location…',
        GpsState.good => 'Good signal',
        GpsState.weak => 'Weak signal — points are flagged',
        GpsState.blocked => 'Signal too weak to capture — move into the open',
        GpsState.failed => 'No GPS fix — try outdoors or place it by hand',
      };

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final s = gpsStateFor(accuracyM, timedOut: timedOut);
    final c = switch (s) {
      GpsState.finding => p.inkMuted,
      GpsState.good => p.success,
      GpsState.weak => p.warning,
      GpsState.blocked || GpsState.failed => p.danger,
    };
    final text = switch (s) {
      GpsState.finding => 'Finding GPS',
      GpsState.good => 'GPS good',
      GpsState.weak => 'GPS weak',
      GpsState.blocked => 'GPS too weak',
      GpsState.failed => 'No GPS fix',
    };
    return Semantics(
      label: '$text${accuracyM == null ? '' : ', plus or minus ${accuracyM!.round()} metres'}',
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: CanopySpace.s12),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: p.outlineStrong),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: s == GpsState.finding ? null : c,
              border: s == GpsState.finding ? Border.all(color: c, width: 2) : null,
            ),
          ),
          const SizedBox(width: CanopySpace.s8),
          Text(text, style: CanopyType.label.copyWith(color: p.ink)),
          if (accuracyM != null) ...[
            const SizedBox(width: CanopySpace.s4),
            Text('±${accuracyM!.round()} m',
                style: CanopyType.label.copyWith(color: p.inkMuted, fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NUMBERS
// ─────────────────────────────────────────────────────────────────────────────

/// Bricolage 56 value with unit, driven by [FieldKeypad].
class BigNumberInput extends StatelessWidget {
  final String value;
  final String unit;
  final String? caption;
  const BigNumberInput({super.key, required this.value, required this.unit, this.caption});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Text(value.isEmpty ? '0' : value, style: CanopyField.bigNumber.copyWith(color: value.isEmpty ? p.inkFaint : p.ink)),
        const SizedBox(width: CanopySpace.s8),
        Text(unit, style: CanopyType.title.copyWith(color: p.inkMuted)),
      ]),
      if (caption != null) Text(caption!, style: CanopyType.caption.copyWith(color: p.inkMuted)),
    ]);
  }
}

/// On-screen keypad, keys 56. Edits a decimal string.
class FieldKeypad extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final bool decimal;
  final int maxLength;
  const FieldKeypad({super.key, required this.value, required this.onChanged, this.decimal = true, this.maxLength = 7});

  void _tap(String k) {
    if (k == '⌫') {
      if (value.isNotEmpty) onChanged(value.substring(0, value.length - 1));
      return;
    }
    if (value.length >= maxLength) return;
    if (k == '.') {
      if (!decimal || value.contains('.')) return;
      onChanged(value.isEmpty ? '0.' : '$value.');
      return;
    }
    if (value == '0') {
      onChanged(k);
      return;
    }
    onChanged('$value$k');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', '⌫'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: CanopySpace.s8,
      crossAxisSpacing: CanopySpace.s8,
      childAspectRatio: 2.2,
      children: [
        for (final k in keys)
          if (k == '.' && !decimal)
            const SizedBox.shrink()
          else
            Semantics(
              button: true,
              label: k == '⌫' ? 'Delete' : k,
              child: Material(
                color: p.surfaceMuted,
                borderRadius: BorderRadius.circular(CanopyField.buttonRadius),
                child: InkWell(
                  borderRadius: BorderRadius.circular(CanopyField.buttonRadius),
                  onTap: () => _tap(k),
                  child: SizedBox(
                    height: CanopyField.keypadKeyHeight,
                    child: Center(
                      child: k == '⌫'
                          ? Icon(Icons.backspace_outlined, color: p.ink)
                          : Text(k, style: CanopyType.title.copyWith(color: p.ink)),
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROWS & PANELS
// ─────────────────────────────────────────────────────────────────────────────

/// 64 tall: avatar, name, zone (+ phone), status label, 56dp round call.
class CollectorRow extends StatelessWidget {
  final String name;
  final String? zone;
  final String? phone;
  final Widget status;
  final VoidCallback? onCall;
  final VoidCallback? onTap;
  const CollectorRow({super.key, required this.name, this.zone, this.phone, required this.status, this.onCall, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CanopySpace.s16, vertical: CanopySpace.s8),
          child: Row(children: [
            CanopyAvatar(name: name, size: 40),
            const SizedBox(width: CanopySpace.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: CanopyType.bodyStrong.copyWith(color: p.ink)),
                Text([zone, phone].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                    style: CanopyType.caption.copyWith(color: p.inkMuted)),
                const SizedBox(height: CanopySpace.s2),
                status,
              ]),
            ),
            if (onCall != null)
              Semantics(
                button: true,
                label: 'Call $name',
                child: Material(
                  shape: CircleBorder(side: BorderSide(color: p.ink, width: 1.5)),
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onCall,
                    child: SizedBox(width: 56, height: 56, child: Icon(Icons.call_outlined, color: p.ink)),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

enum ReadinessState { done, todo, unavailable }

class ReadinessItem {
  final String title;
  final String? line;
  final ReadinessState state;
  final VoidCallback? onTap;
  const ReadinessItem(this.title, this.state, {this.line, this.onTap});
}

/// Rows 52: ink checkbox when done · empty · dashed "Not available yet".
class ReadinessChecklist extends StatelessWidget {
  final List<ReadinessItem> items;
  const ReadinessChecklist({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return Column(children: [
      for (final i in items)
        InkWell(
          onTap: i.onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: CanopySpace.s8),
              child: Row(children: [
                if (i.state == ReadinessState.unavailable)
                  DashedBorder(color: p.outlineStrong, radius: 4, child: const SizedBox(width: 22, height: 22))
                else
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: i.state == ReadinessState.done ? p.ink : null,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: p.ink, width: 1.5),
                    ),
                    child: i.state == ReadinessState.done ? Icon(Icons.check, size: 16, color: p.canvas) : null,
                  ),
                const SizedBox(width: CanopySpace.s12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(i.title,
                        style: CanopyType.body.copyWith(color: i.state == ReadinessState.unavailable ? p.inkMuted : p.ink)),
                    if (i.state == ReadinessState.unavailable)
                      Text('Not available yet', style: CanopyType.caption.copyWith(color: p.inkMuted))
                    else if (i.line != null)
                      Text(i.line!, style: CanopyType.caption.copyWith(color: p.inkMuted)),
                  ]),
                ),
                if (i.onTap != null) Icon(Icons.chevron_right, color: p.inkFaint),
              ]),
            ),
          ),
        ),
    ]);
  }
}

/// Swatches + counts ("3 zones · 6 dumpsites").
class MapLegend extends StatelessWidget {
  final List<(Color, String)> items;
  const MapLegend({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return Wrap(spacing: CanopySpace.s16, runSpacing: CanopySpace.s4, children: [
      for (final i in items)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: i.$1, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: CanopySpace.s4),
          Text(i.$2, style: CanopyType.caption.copyWith(color: p.inkMuted)),
        ]),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ON-DEVICE DRAFTS — "Waiting to send"
// ─────────────────────────────────────────────────────────────────────────────

/// A zone captured in the field but not yet saved to the server (offline,
/// not linked, or the save failed). Kept on this phone until sent.
class ZoneDraft {
  final String id;
  final String name;
  final List<LatLng> points;
  final String method; // tap · walk
  final DateTime capturedAt;
  final String? lastError;

  const ZoneDraft({required this.id, required this.name, required this.points, required this.method, required this.capturedAt, this.lastError});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'points': [for (final p in points) [p.latitude, p.longitude]],
        'method': method,
        'capturedAt': capturedAt.toIso8601String(),
        'lastError': lastError,
      };

  factory ZoneDraft.fromJson(Map<String, dynamic> j) => ZoneDraft(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        points: [for (final p in (j['points'] as List? ?? const [])) LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble())],
        method: j['method'] as String? ?? 'tap',
        capturedAt: DateTime.tryParse(j['capturedAt'] as String? ?? '') ?? DateTime.now(),
        lastError: j['lastError'] as String?,
      );

  ZoneDraft copyWith({String? name, String? lastError}) =>
      ZoneDraft(id: id, name: name ?? this.name, points: points, method: method, capturedAt: capturedAt, lastError: lastError);
}

class FieldDraftStore {
  FieldDraftStore._();
  static final instance = FieldDraftStore._();
  static const _key = 'envops_zone_drafts_v1';

  /// Bumps whenever drafts change so screens can refresh.
  final ValueNotifier<int> revision = ValueNotifier(0);

  Future<List<ZoneDraft>> zones() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return const [];
      return [for (final j in jsonDecode(raw) as List) ZoneDraft.fromJson(Map<String, dynamic>.from(j as Map))];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _write(List<ZoneDraft> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode([for (final d in list) d.toJson()]));
    revision.value++;
  }

  Future<void> putZone(ZoneDraft d) async {
    final list = [...await zones()]..removeWhere((x) => x.id == d.id);
    await _write([...list, d]);
  }

  Future<void> removeZone(String id) async {
    final list = [...await zones()]..removeWhere((x) => x.id == id);
    await _write(list);
  }
}

/// 2px ink box listing drafts captured offline, with Retry save / Open draft.
class WaitingToSend extends StatelessWidget {
  final List<ZoneDraft> drafts;
  final void Function(ZoneDraft) onRetry;
  final void Function(ZoneDraft) onDiscard;
  final bool busy;
  const WaitingToSend({super.key, required this.drafts, required this.onRetry, required this.onDiscard, this.busy = false});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return Container(
      padding: const EdgeInsets.all(CanopySpace.s16),
      decoration: BoxDecoration(border: Border.all(color: p.ink, width: 2), borderRadius: BorderRadius.circular(CanopyRadius.sm)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('WAITING TO SEND · ${drafts.length}', style: CanopyField.fieldEyebrow.copyWith(color: p.ink)),
        const SizedBox(height: CanopySpace.s4),
        Text('Kept on this phone. Nothing is lost if you close the app.', style: CanopyType.caption.copyWith(color: p.inkMuted)),
        for (final d in drafts) ...[
          const SizedBox(height: CanopySpace.s12),
          Text(d.name.isEmpty ? 'Unnamed zone' : d.name, style: CanopyType.bodyStrong.copyWith(color: p.ink)),
          Text('${d.points.length} points · ${d.method == 'walk' ? 'walked' : 'tapped'} · ${fieldNoteTime(d.capturedAt)}',
              style: CanopyType.caption.copyWith(color: p.inkMuted)),
          if (d.lastError != null) Text(d.lastError!, style: CanopyType.caption.copyWith(color: p.danger)),
          const SizedBox(height: CanopySpace.s8),
          Row(children: [
            Expanded(child: FieldButton(label: 'Retry save', loading: busy, onPressed: () => onRetry(d))),
            const SizedBox(width: CanopySpace.s8),
            Expanded(child: FieldButton.secondary(label: 'Discard', onPressed: busy ? null : () => onDiscard(d))),
          ]),
        ],
      ]),
    );
  }
}
