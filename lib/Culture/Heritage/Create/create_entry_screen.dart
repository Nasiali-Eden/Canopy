// lib/Culture/Heritage/Create/create_entry_screen.dart
//
// Create entry (ARCHIVE_HANDOFF §3.2, F). CreatorStepper: Type · Locality ·
// Name · Knowledge · Media · Visibility, with "Draft saved" in the app bar —
// the provider autosaves at every step. Leaving asks "Keep this as a draft?"
// (Keep draft / Discard entry). Success shows the visibility, where the
// entry lives, next steps, and Add another / Back to archive.

import 'dart:io';

import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../Shared/Inputs/pin_picker_screen.dart';
import '../../../theme/canopy_components.dart';
import '../../archive_ui.dart';
import '../Services/heritage_content_types.dart';
import '../Services/heritage_data_service.dart';
import 'create_entry_provider.dart';
import 'heritage_backgrounds_screen.dart';
import 'locality_selector_sheet.dart';
import 'media_upload_item.dart';
import 'type_data_form_builder.dart';

const _countries = [
  (id: 'country_kenya', label: 'Kenya', live: true),
  (id: 'country_uganda', label: 'Uganda', live: false),
  (id: 'country_nigeria', label: 'Nigeria', live: false),
  (id: 'country_ghana', label: 'Ghana', live: false),
  (id: 'country_tanzania', label: 'Tanzania', live: false),
  (id: 'country_south_africa', label: 'South Africa', live: false),
  (id: 'country_zambia', label: 'Zambia', live: false),
];

const _imageRoles = {
  'cover_image': 'Cover — card thumbnail',
  'story_background': 'Story background — behind the entry',
  'community_background': 'Community background',
  'food_image': 'Food — dish or ingredient',
  'ceremony_image': 'Ceremony — ritual or event',
  'documentation_image': 'Documentation — reference image',
  'process_image': 'Process — a craft step',
  'artefact_image': 'Artefact — object or tool',
  'context_image': 'Context — place or setting',
  'historical_image': 'Historical — archival photograph',
  'pattern_detail': 'Pattern or texture detail',
};

class CreateEntryScreen extends StatelessWidget {
  final String orgId;

  /// Resume an existing draft from the Archive.
  final String? draftId;

  const CreateEntryScreen({required this.orgId, this.draftId, super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CreateEntryProvider(orgId: orgId, draftId: draftId)..loadDraft(),
      child: const _Creator(),
    );
  }
}

class _Creator extends StatefulWidget {
  const _Creator();

  @override
  State<_Creator> createState() => _CreatorState();
}

class _CreatorState extends State<_Creator> {
  bool _showErrors = false;
  bool _done = false;

  CreateEntryProvider get _p => context.read<CreateEntryProvider>();

  void _next() {
    final prov = _p;
    if (prov.blockerFor(prov.currentStep) != null ||
        (prov.currentStep == 3 && TypeDataFormBuilder.missingRequired(prov.selectedContentType ?? '', prov.typeData).isNotEmpty)) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() => _showErrors = false);
    prov.goToStep(prov.currentStep + 1);
  }

  void _back() {
    final prov = _p;
    if (prov.currentStep == 0) {
      _leave();
    } else {
      setState(() => _showErrors = false);
      prov.goToStep(prov.currentStep - 1);
    }
  }

  Future<void> _leave() async {
    final prov = _p;
    if (!prov.hasContent) {
      Navigator.pop(context);
      return;
    }
    final choice = await showCanopySheet<String>(context, builder: (ctx) {
      return CanopySheetBody(
        title: 'Keep this as a draft?',
        caption: 'Drafts stay in your Archive. Only your team can see them.',
        actions: [
          CanopyButton(label: 'Keep draft', expand: true, onPressed: () => Navigator.pop(ctx, 'keep')),
          CanopyButton.quietDanger(label: 'Discard entry', expand: true, onPressed: () => Navigator.pop(ctx, 'discard')),
        ],
      );
    });
    if (!mounted || choice == null) return;
    if (choice == 'keep') {
      await prov.saveDraft();
      if (mounted) {
        showCanopySnack(context, prov.saveFailed ? "Couldn't save the draft — check your connection." : 'Draft kept in your Archive.', error: prov.saveFailed);
        if (!prov.saveFailed) Navigator.pop(context);
      }
    } else {
      final ok = await showCanopyConfirm(context,
          title: 'Discard this entry?', message: 'Everything you added is deleted. This can\'t be undone.', confirmLabel: 'Discard', danger: true);
      if (!ok) return;
      await prov.discardDraft();
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _publish() async {
    final prov = _p;
    await prov.submit();
    if (!mounted) return;
    if (prov.submitError != null) {
      showCanopySnack(context, prov.submitError!, error: true);
    } else {
      setState(() => _done = true);
    }
  }

  String? _savedLabel(CreateEntryProvider prov) {
    if (prov.saveFailed) return 'Not saved';
    final t = prov.savedAt;
    if (t == null) return null;
    final m = DateTime.now().difference(t).inMinutes;
    return m < 1 ? 'Draft saved' : 'Saved $m min ago';
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<CreateEntryProvider>();
    final p = context.canopy;
    if (_done) return _Success(prov: prov);
    if (prov.loadingDraft) return CanopyScaffold(appBar: canopyAppBar(context, title: 'Add to archive'), body: const Center(child: CircularProgressIndicator()));
    final step = prov.currentStep;
    final saved = _savedLabel(prov);
    final blocker = _showErrors
        ? (prov.blockerFor(step) ??
            (step == 3
                ? () {
                    final missing = TypeDataFormBuilder.missingRequired(prov.selectedContentType ?? '', prov.typeData);
                    return missing.isEmpty ? null : 'Still needed: ${missing.join(', ')}.';
                  }()
                : null))
        : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: CanopyScaffold(
        appBar: canopyAppBar(
          context,
          title: 'Add to archive',
          leading: IconButton(icon: const Icon(Icons.close), tooltip: 'Leave', onPressed: _leave),
          actions: [
            if (saved != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: CanopySpace.gutter),
                  child: Text(saved, style: CanopyType.caption.copyWith(color: prov.saveFailed ? p.danger : p.inkMuted)),
                ),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
          children: [
            CanopyStepper(step: step + 1, total: 6, label: CanopyArchive.creatorSteps[step], stepLabels: CanopyArchive.creatorSteps),
            const SizedBox(height: CanopySpace.section),
            ...switch (step) {
              0 => _type(prov, p),
              1 => _locality(prov, p),
              2 => [_NameStep(prov: prov)],
              3 => [_KnowledgeStep(prov: prov)],
              4 => _media(prov, p),
              _ => _visibility(prov, p),
            },
            if (blocker != null)
              Padding(
                padding: const EdgeInsets.only(top: CanopySpace.s16),
                child: Text(blocker, style: CanopyType.body.copyWith(color: p.danger)),
              ),
          ],
        ),
        sticky: StickyActionBar(children: [
          Row(children: [
            if (step > 0) ...[
              CanopyButton.quiet(label: 'Back', onPressed: _back),
              const SizedBox(width: CanopySpace.s8),
            ],
            Expanded(
              child: CanopyButton(
                label: step == 5 ? 'Add to archive' : 'Continue to ${CanopyArchive.creatorSteps[step + 1 > 5 ? 5 : step + 1]}',
                expand: true,
                loading: prov.isSubmitting,
                onPressed: step == 5 ? _publish : _next,
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  // ── 1 · Type ──────────────────────────────────────────────────────────────

  List<Widget> _type(CreateEntryProvider prov, CanopyPalette p) => [
        Text('What kind of knowledge is this?', style: CanopyType.title.copyWith(color: p.ink)),
        const SizedBox(height: CanopySpace.s16),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: CanopySpace.s8,
          crossAxisSpacing: CanopySpace.s8,
          childAspectRatio: 1,
          children: [
            for (final t in HeritageContentTypes.ordered)
              Semantics(
                selected: prov.selectedContentType == t.key,
                button: true,
                label: t.label,
                child: Material(
                  color: p.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(CanopyRadius.sm),
                    side: BorderSide(color: prov.selectedContentType == t.key ? p.ink : p.outline, width: prov.selectedContentType == t.key ? 2 : 1),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(CanopyRadius.sm),
                    onTap: () => prov.setContentType(t.key),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(t.icon, color: contentTypeColor(context, t.key), size: 28),
                      const SizedBox(height: CanopySpace.s8),
                      Text(t.label, textAlign: TextAlign.center, maxLines: 2, style: CanopyType.label.copyWith(color: p.ink)),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ];

  // ── 2 · Locality ──────────────────────────────────────────────────────────

  List<Widget> _locality(CreateEntryProvider prov, CanopyPalette p) {
    final loc = prov.locality;
    final country = _countries.firstWhere((c) => c.id == loc.countryId, orElse: () => _countries.first);
    return [
      Text('Where does this knowledge belong?', style: CanopyType.title.copyWith(color: p.ink)),
      const SizedBox(height: CanopySpace.s16),
      CanopyPickerField(
        label: 'Country',
        value: country.label,
        placeholder: 'Choose',
        icon: Icons.public,
        onTap: () async {
          final picked = await showCanopySheet<String>(context, builder: (ctx) {
            return CanopySheetBody(title: 'Country', children: [
              CanopyListGroup(children: [
                for (final c in _countries)
                  CanopyListRow(
                    title: c.label,
                    subtitle: c.live ? null : 'Opening soon',
                    titleColor: c.live ? null : ctx.canopy.inkMuted,
                    chevron: false,
                    trailing: c.id == loc.countryId ? Icon(Icons.check, color: ctx.canopy.ink) : null,
                    onTap: c.live ? () => Navigator.pop(ctx, c.id) : null,
                  ),
              ]),
            ]);
          });
          if (picked != null) prov.setCountryId(picked);
        },
      ),
      _CountryImagesGate(countryId: country.id, countryLabel: country.label, orgId: prov.orgId),
      const SizedBox(height: CanopySpace.s16),
      CanopyPickerField(
        label: 'Community',
        value: loc.communityUnknown ? 'Not sure which community' : loc.communityName,
        placeholder: 'Choose community',
        icon: Icons.groups_outlined,
        onTap: () async {
          final r = await showCanopySheet<CommunitySelection>(context, tall: true, builder: (_) => const LocalitySelectorSheet());
          if (r == null) return;
          r.isUnknown ? prov.setCommunityUnknown(true) : prov.setCommunity(r.id, r.name);
        },
      ),
      const SizedBox(height: CanopySpace.s16),
      CanopyPickerField(
        label: 'Location on the map (required)',
        value: prov.mapPoint == null ? null : '${prov.mapPoint!.lat.toStringAsFixed(5)}, ${prov.mapPoint!.lng.toStringAsFixed(5)}',
        placeholder: 'Pin it on the map',
        icon: Icons.push_pin_outlined,
        onTap: () async {
          final mp = prov.mapPoint;
          final at = await pickPin(context, initial: mp == null ? null : LatLng(mp.lat, mp.lng), title: 'Where is this?');
          if (at != null) prov.setMapPoint(at.latitude, at.longitude);
        },
      ),
      const SizedBox(height: CanopySpace.s16),
      _NotesField(initial: loc.localityNotes ?? '', onChanged: prov.setLocalityNotes),
    ];
  }

  // ── 5 · Media ─────────────────────────────────────────────────────────────

  List<Widget> _media(CreateEntryProvider prov, CanopyPalette p) {
    final images = prov.mediaFiles.where((m) => m.mediaType == 'image').toList();
    final uncredited = prov.uncredited.length;
    return [
      Text('Photos', style: CanopyType.title.copyWith(color: p.ink)),
      Text('The cover shows on cards. Tap a photo to set its role, caption and credit.', style: CanopyType.body.copyWith(color: p.inkMuted)),
      if (uncredited > 0) ...[
        const SizedBox(height: CanopySpace.s12),
        CanopyCallout(
          kind: CalloutKind.warning,
          text: '$uncredited ${uncredited == 1 ? 'photo has' : 'photos have'} no credit. Credit is required before publishing.',
        ),
      ],
      const SizedBox(height: CanopySpace.s16),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: CanopySpace.s8,
        crossAxisSpacing: CanopySpace.s8,
        children: [
          for (final m in images) _MediaTile(item: m, onTap: () => _editMedia(prov, m), onRetry: () => prov.retryUpload(m.localId)),
          Material(
            color: p.surfaceMuted,
            borderRadius: BorderRadius.circular(CanopyRadius.sm),
            child: InkWell(
              borderRadius: BorderRadius.circular(CanopyRadius.sm),
              onTap: () async {
                final xs = await ImagePicker().pickMultiImage(imageQuality: 90);
                for (final x in xs) {
                  prov.addMediaFile(File(x.path), 'image', prov.mediaFiles.any((m) => m.mediaType == 'image') ? 'documentation_image' : 'cover_image');
                }
              },
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_photo_alternate_outlined, color: p.inkMuted),
                Text('Add photos', style: CanopyType.caption.copyWith(color: p.inkMuted)),
              ]),
            ),
          ),
        ],
      ),
      const SizedBox(height: CanopySpace.section),
      const CanopyComingSoon(
        boxed: true,
        icon: Icons.graphic_eq,
        label: 'Not built yet',
        title: 'Audio recordings',
        line: 'Recording songs and stories in the app is coming. For now, describe them in the Knowledge step.',
      ),
    ];
  }

  Future<void> _editMedia(CreateEntryProvider prov, MediaUploadItem m) async {
    await showCanopySheet(context, builder: (_) => ChangeNotifierProvider.value(value: prov, child: _MediaSheet(localId: m.localId)));
  }

  // ── 6 · Visibility ────────────────────────────────────────────────────────

  List<Widget> _visibility(CreateEntryProvider prov, CanopyPalette p) {
    final restrictedHint = prov.typeData['is_restricted'] == true || (prov.typeData['restriction_note'] as String?)?.isNotEmpty == true;
    final v = visibilityFrom(prov.visibility) ?? ArchiveVisibility.public;
    return [
      Text('Who can see it?', style: CanopyType.title.copyWith(color: p.ink)),
      const SizedBox(height: CanopySpace.s16),
      VisibilitySelector(
        value: v,
        suggested: restrictedHint ? ArchiveVisibility.restricted : null,
        onChanged: (nv) => prov.setVisibility(visibilityKey(nv)),
      ),
      if (v == ArchiveVisibility.restricted || v == ArchiveVisibility.sealed) ...[
        const SizedBox(height: CanopySpace.s8),
        _NotesField(
          label: 'Why (for your team)',
          hint: 'e.g. Sacred — elders asked it not be shown widely',
          initial: prov.visibilityReason ?? '',
          onChanged: prov.setVisibilityReason,
        ),
      ],
      const SizedBox(height: CanopySpace.s16),
      CanopyButton.secondary(
        label: 'Preview as a member',
        expand: true,
        onPressed: () async {
          await prov.saveDraft();
          if (!mounted || prov.draftId == null) return;
          openEntryPreview(context, prov.draftId!);
        },
      ),
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _NotesField extends StatefulWidget {
  final String initial;
  final ValueChanged<String> onChanged;
  final String label;
  final String hint;
  const _NotesField({
    required this.initial,
    required this.onChanged,
    this.label = 'Locality notes (optional)',
    this.hint = 'e.g. Practised by the Luo community in Kibera, not only in Nyanza',
  });

  @override
  State<_NotesField> createState() => _NotesFieldState();
}

class _NotesFieldState extends State<_NotesField> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CanopyTextField(label: widget.label, hint: widget.hint, controller: _c, minLines: 2, maxLines: 4, onChanged: widget.onChanged);
}

class _NameStep extends StatefulWidget {
  final CreateEntryProvider prov;
  const _NameStep({required this.prov});

  @override
  State<_NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<_NameStep> {
  late final _title = TextEditingController(text: widget.prov.title);
  late final _en = TextEditingController(text: widget.prov.titleEnglish);
  late final _sw = TextEditingController(text: widget.prov.titleSwahili);
  late final _lang = TextEditingController(text: widget.prov.primaryLanguage);

  @override
  void dispose() {
    for (final c in [_title, _en, _sw, _lang]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final prov = widget.prov;
    const gap = SizedBox(height: CanopySpace.s16);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('What is it called?', style: CanopyType.title.copyWith(color: p.ink)),
      const SizedBox(height: CanopySpace.s4),
      Text('Use the name the community uses.', style: CanopyType.body.copyWith(color: p.inkMuted)),
      gap,
      CanopyTextField(label: 'Name', controller: _title, autofocus: prov.title.isEmpty, maxLength: 120, onChanged: prov.setTitle),
      gap,
      CanopyTextField(label: 'English translation (optional)', controller: _en, onChanged: prov.setTitleEnglish),
      gap,
      CanopyTextField(label: 'Kiswahili (optional)', controller: _sw, onChanged: prov.setTitleSwahili),
      gap,
      CanopyTextField(label: 'Language it is known in (optional)', hint: 'e.g. Dholuo', controller: _lang, onChanged: prov.setPrimaryLanguage),
      gap,
      CanopySwitchRow(
        title: 'Seeking contributors',
        caption: 'Invite members who know more to add to it',
        value: prov.isSeekingContributors,
        onChanged: prov.setIsSeekingContributors,
      ),
    ]);
  }
}

class _KnowledgeStep extends StatefulWidget {
  final CreateEntryProvider prov;
  const _KnowledgeStep({required this.prov});

  @override
  State<_KnowledgeStep> createState() => _KnowledgeStepState();
}

class _KnowledgeStepState extends State<_KnowledgeStep> {
  late final _desc = TextEditingController(text: widget.prov.description);

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final prov = widget.prov;
    final n = _desc.text.trim().length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('What should people know?', style: CanopyType.title.copyWith(color: p.ink)),
      const SizedBox(height: CanopySpace.s16),
      CanopyTextField(
        label: 'Description',
        hint: 'What it is, where it comes from and why it matters',
        controller: _desc,
        minLines: 4,
        maxLines: 12,
        helper: n < 50 ? '${50 - n} more characters' : null,
        onChanged: (v) {
          prov.setDescription(v);
          setState(() {});
        },
      ),
      const SizedBox(height: CanopySpace.section),
      TypeDataFormBuilder(
        key: ValueKey(prov.selectedContentType),
        contentType: prov.selectedContentType ?? '',
        typeData: prov.typeData,
        onChanged: prov.setTypeDataField,
      ),
      if (prov.isPersonType)
        CanopyCheckRow(
          label: 'They agreed to be documented and named',
          caption: 'Or their family did, if they have passed',
          value: prov.consentChecked,
          onChanged: prov.setConsentChecked,
        ),
    ]);
  }
}

class _MediaTile extends StatelessWidget {
  final MediaUploadItem item;
  final VoidCallback onTap;
  final VoidCallback onRetry;
  const _MediaTile({required this.item, required this.onTap, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final cover = item.isPrimary;
    return Semantics(
      button: true,
      label: '${cover ? 'Cover photo' : 'Photo'}${(item.credit ?? '').isEmpty ? ', no credit' : ''}',
      child: GestureDetector(
        onTap: item.uploadState == MediaUploadState.failed ? onRetry : onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CanopyRadius.sm),
            border: cover ? Border.all(color: p.ink, width: CanopyArchive.coverRing) : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(CanopyRadius.sm - (cover ? 2 : 0)),
            child: Stack(fit: StackFit.expand, children: [
              if (item.file != null) Image.file(item.file!, fit: BoxFit.cover) else CanopyImage(url: item.storageUrl),
              if (item.uploadState == MediaUploadState.uploading)
                Container(
                  color: const Color(0x99000000),
                  child: Center(
                    child: Text('${(item.progress * 100).round()}%', style: CanopyType.label.copyWith(color: const Color(0xFFFFFFFF))),
                  ),
                ),
              if (item.uploadState == MediaUploadState.failed)
                Container(
                  color: p.danger.withValues(alpha: .78),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.refresh, color: Color(0xFFFFFFFF)),
                    Text('Retry', style: CanopyType.label.copyWith(color: const Color(0xFFFFFFFF))),
                  ]),
                ),
              if (item.uploadState == MediaUploadState.uploaded && (item.credit ?? '').trim().isEmpty)
                Positioned(
                  left: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: p.warning, borderRadius: BorderRadius.circular(4)),
                    child: Text('No credit', style: CanopyType.caption.copyWith(color: const Color(0xFF000000), fontSize: 10)),
                  ),
                ),
              if (cover)
                Positioned(
                  left: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(4)),
                    child: Text('Cover', style: CanopyType.caption.copyWith(color: p.canvas, fontSize: 10)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _MediaSheet extends StatefulWidget {
  final String localId;
  const _MediaSheet({required this.localId});

  @override
  State<_MediaSheet> createState() => _MediaSheetState();
}

class _MediaSheetState extends State<_MediaSheet> {
  late final CreateEntryProvider _prov = context.read<CreateEntryProvider>();
  late final MediaUploadItem _m = _prov.mediaFiles.firstWhere((x) => x.localId == widget.localId);
  late final _caption = TextEditingController(text: _m.caption ?? '');
  late final _credit = TextEditingController(text: _m.credit ?? '');

  @override
  void dispose() {
    _caption.dispose();
    _credit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<CreateEntryProvider>();
    final m = prov.mediaFiles.where((x) => x.localId == widget.localId).firstOrNull;
    if (m == null) return const SizedBox.shrink();
    return CanopySheetBody(
      title: m.isPrimary ? 'Cover photo' : 'Photo',
      children: [
        CanopyTextField(
          label: 'Credit',
          hint: 'Who took it — e.g. Photo: Achieng Otieno',
          controller: _credit,
          error: _credit.text.trim().isEmpty ? 'Required before publishing.' : null,
          onChanged: (v) {
            prov.setMediaCredit(m.localId, v);
            setState(() {});
          },
        ),
        const SizedBox(height: CanopySpace.s16),
        CanopyTextField(label: 'Caption (optional)', controller: _caption, onChanged: (v) => prov.setMediaCaption(m.localId, v)),
        const SizedBox(height: CanopySpace.s16),
        CanopyPickerField(
          label: 'Role',
          value: _imageRoles[m.mediaRole] ?? m.mediaRole,
          placeholder: 'Choose',
          onTap: () async {
            final r = await showCanopySheet<String>(context, builder: (ctx) {
              return CanopySheetBody(title: 'Role', children: [
                CanopyListGroup(children: [
                  for (final e in _imageRoles.entries)
                    CanopyListRow(
                      title: e.value,
                      chevron: false,
                      trailing: e.key == m.mediaRole ? Icon(Icons.check, color: ctx.canopy.ink) : null,
                      onTap: () => Navigator.pop(ctx, e.key),
                    ),
                ]),
              ]);
            });
            if (r != null) prov.setMediaRole(m.localId, r);
          },
        ),
      ],
      actions: [
        if (!m.isPrimary) CanopyButton.secondary(label: 'Make cover', expand: true, onPressed: () => prov.setMediaPrimary(m.localId)),
        CanopyButton.quietDanger(
          label: 'Remove photo',
          expand: true,
          onPressed: () {
            prov.removeMediaFile(m.localId);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

class _CountryImagesGate extends StatelessWidget {
  final String countryId;
  final String countryLabel;
  final String orgId;
  const _CountryImagesGate({required this.countryId, required this.countryLabel, required this.orgId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<({String? bg, String? card})>(
      stream: HeritageDataService().streamNodeImages(countryId),
      builder: (context, snap) {
        if (!snap.hasData || (snap.data!.bg ?? '').isNotEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: CanopySpace.s12),
          child: CanopyCallout(
            kind: CalloutKind.warning,
            title: "$countryLabel's page has no images yet",
            text: 'Add a banner and card so this entry displays properly on the country page and the Heritage tab.',
            action: CanopyButton.secondary(
              label: 'Set country images',
              size: CanopyButtonSize.compact,
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HeritageBackgroundsScreen(orgId: orgId))),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUCCESS
// ─────────────────────────────────────────────────────────────────────────────

class _Success extends StatelessWidget {
  final CreateEntryProvider prov;
  const _Success({required this.prov});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final v = visibilityFrom(prov.visibility);
    final where = [
      prov.locality.communityName,
      _countries.firstWhere((c) => c.id == prov.locality.countryId, orElse: () => _countries.first).label,
    ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: '', showBack: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, CanopySpace.s32),
        children: [
          VisibilityLabel(v),
          const SizedBox(height: CanopySpace.s8),
          Text('Entry added to the archive', style: CanopyType.display.copyWith(color: p.ink)),
          const SizedBox(height: CanopySpace.s8),
          Text(
            '"${prov.title.trim()}" is in your Archive${where.isEmpty ? '' : ' under $where'}.'
            '${v == ArchiveVisibility.public ? ' Members can find it on Heritage.' : ''}',
            style: CanopyType.body.copyWith(fontSize: 16, height: 1.5, color: p.ink),
          ),
          const CanopySectionHeader(title: 'Next', padding: EdgeInsets.only(top: CanopySpace.section)),
          CanopyListGroup(children: [
            if (prov.draftId != null)
              CanopyListRow(
                icon: Icons.visibility_outlined,
                title: 'See it as members do',
                onTap: () => openEntryPreview(context, prov.draftId!, published: true),
              ),
            CanopyListRow(
              icon: Icons.landscape_outlined,
              title: 'Add a community background',
              subtitle: 'So the community page looks right',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HeritageBackgroundsScreen(orgId: prov.orgId))),
            ),
          ]),
        ],
      ),
      sticky: StickyActionBar(children: [
        CanopyButton(
          label: 'Add another',
          expand: true,
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CreateEntryScreen(orgId: prov.orgId))),
        ),
        CanopyButton.quiet(label: 'Back to archive', expand: true, onPressed: () => Navigator.pop(context)),
      ]),
    );
  }
}
