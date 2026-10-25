// lib/Culture/Heritage/Create/type_data_form_builder.dart
//
// DynamicFields (ARCHIVE_HANDOFF 2): per-type fields from _schemas, drawn with
// v2 components. Original / Kiswahili / English variants share a segmented
// control with word counts; yes/no facts are Yes / No / Unsure (unsure is
// stored as null); restriction notes use the warning field. Consent for
// knowledge holders is asked once by the creator, not here.

import 'package:flutter/material.dart';

import '../../../theme/canopy_components.dart';
import '../../archive_ui.dart' show RestrictionNoteField;

enum _FieldKind { textSingle, textMulti, dropdown, toggle, chipMulti, tagInput }

class _Field {
  final String key;
  final String label;
  final _FieldKind kind;
  final bool required;
  final List<String>? options;
  final String? hint;

  const _Field({
    required this.key,
    required this.label,
    required this.kind,
    this.required = false,
    this.options,
    this.hint,
  });
}

const _schemas = <String, List<_Field>>{
  'oral_tradition': [
    _Field(key: 'subcategory', label: 'Subcategory *', kind: _FieldKind.dropdown, required: true, options: ['origin_myth', 'oral_history', 'fable', 'proverb_collection', 'praise_poem', 'historical_account']),
    _Field(key: 'body', label: 'The story (original language) *', kind: _FieldKind.textMulti, required: true, hint: 'Write the story as told in the original language'),
    _Field(key: 'body_swahili', label: 'Story (Swahili)', kind: _FieldKind.textMulti),
    _Field(key: 'body_english', label: 'Story (English)', kind: _FieldKind.textMulti),
    _Field(key: 'occasion', label: 'When is this told?', kind: _FieldKind.textSingle, hint: 'e.g. Fireside at night, Initiation season'),
    _Field(key: 'narrator_type', label: 'Who traditionally tells this?', kind: _FieldKind.textSingle, hint: 'e.g. Elders only, Grandmothers to grandchildren'),
    _Field(key: 'moral_or_meaning', label: 'Moral or meaning', kind: _FieldKind.textMulti),
    _Field(key: 'characters', label: 'Characters', kind: _FieldKind.tagInput, hint: 'Named characters in the story'),
    _Field(key: 'is_restricted', label: 'Restricted telling', kind: _FieldKind.toggle, hint: 'Only told in certain contexts or to certain people'),
  ],
  'food_tradition': [
    _Field(key: 'subcategory', label: 'Subcategory *', kind: _FieldKind.dropdown, required: true, options: ['staple_dish', 'ceremonial_food', 'fermented_or_brewed', 'preservation_technique', 'indigenous_ingredient_use', 'hospitality_tradition', 'street_food', 'harvest_food']),
    _Field(key: 'occasion', label: 'Occasion', kind: _FieldKind.textSingle),
    _Field(key: 'who_prepares', label: 'Who prepares this?', kind: _FieldKind.textSingle, hint: 'Is preparation gendered, age-specific, or role-specific?'),
    _Field(key: 'main_ingredients', label: 'Main ingredients', kind: _FieldKind.tagInput),
    _Field(key: 'preparation_notes', label: 'Preparation notes', kind: _FieldKind.textMulti),
    _Field(key: 'what_is_being_lost', label: 'What knowledge is being lost?', kind: _FieldKind.textMulti, hint: 'What is disappearing in urban settings?'),
    _Field(key: 'is_ceremonial_only', label: 'Ceremonial only', kind: _FieldKind.toggle),
    _Field(key: 'season', label: 'Season', kind: _FieldKind.textSingle),
  ],
  'ingredient': [
    _Field(key: 'subcategory', label: 'Subcategory *', kind: _FieldKind.dropdown, required: true, options: ['plant_leaf_vegetable', 'root_tuber', 'grain_seed', 'fruit', 'animal_protein', 'fungi', 'spice_herb', 'medicinal_plant', 'craft_material']),
    _Field(key: 'name_indigenous', label: 'Indigenous name *', kind: _FieldKind.textSingle, required: true, hint: 'Name in the original language'),
    _Field(key: 'name_swahili', label: 'Swahili name', kind: _FieldKind.textSingle),
    _Field(key: 'name_english', label: 'English name', kind: _FieldKind.textSingle),
    _Field(key: 'scientific_name', label: 'Scientific name', kind: _FieldKind.textSingle),
    _Field(key: 'uses', label: 'Uses *', kind: _FieldKind.chipMulti, required: true, options: ['food', 'medicine', 'ceremony', 'craft', 'dye', 'construction', 'other']),
    _Field(key: 'season', label: 'Season', kind: _FieldKind.textSingle),
    _Field(key: 'where_it_grows', label: 'Where it grows', kind: _FieldKind.textSingle),
    _Field(key: 'harvesting_knowledge', label: 'Harvesting knowledge', kind: _FieldKind.textMulti),
    _Field(key: 'is_endangered', label: 'Endangered', kind: _FieldKind.toggle),
  ],
  'music_tradition': [
    _Field(key: 'subcategory', label: 'Subcategory *', kind: _FieldKind.dropdown, required: true, options: ['ceremony_song', 'work_song', 'lullaby', 'praise_song', 'drumming_tradition', 'chant_recitation', 'dance_music', 'funeral_music', 'harvest_song']),
    _Field(key: 'occasion', label: 'Occasion *', kind: _FieldKind.textSingle, required: true),
    _Field(key: 'who_performs', label: 'Who performs this?', kind: _FieldKind.textSingle, hint: 'Is performance restricted by gender, age, or role?'),
    _Field(key: 'lyrics', label: 'Lyrics (original language)', kind: _FieldKind.textMulti),
    _Field(key: 'lyrics_swahili', label: 'Lyrics (Swahili)', kind: _FieldKind.textMulti),
    _Field(key: 'lyrics_english', label: 'Lyrics (English)', kind: _FieldKind.textMulti),
    _Field(key: 'instruments_used', label: 'Instruments used', kind: _FieldKind.tagInput),
    _Field(key: 'rhythm_notes', label: 'Rhythm notes', kind: _FieldKind.textMulti),
    _Field(key: 'is_restricted', label: 'Restricted performance', kind: _FieldKind.toggle),
  ],
  'instrument': [
    _Field(key: 'subcategory', label: 'Subcategory *', kind: _FieldKind.dropdown, required: true, options: ['drum', 'string_instrument', 'wind_instrument', 'idiophone', 'chordophone', 'other']),
    _Field(key: 'materials', label: 'Materials', kind: _FieldKind.textMulti),
    _Field(key: 'construction_notes', label: 'Construction notes', kind: _FieldKind.textMulti),
    _Field(key: 'who_plays', label: 'Who plays this?', kind: _FieldKind.textSingle),
    _Field(key: 'occasions', label: 'Occasions', kind: _FieldKind.tagInput),
    _Field(key: 'pitch_or_tuning', label: 'Pitch or tuning', kind: _FieldKind.textSingle),
    _Field(key: 'is_endangered', label: 'Endangered', kind: _FieldKind.toggle),
  ],
  'ceremony': [
    _Field(key: 'subcategory', label: 'Subcategory *', kind: _FieldKind.dropdown, required: true, options: ['rite_of_passage', 'wedding_marriage', 'funeral_mourning', 'harvest_agricultural', 'healing_medicine', 'naming_ceremony', 'seasonal_calendar', 'ancestral_spiritual']),
    _Field(key: 'when_it_occurs', label: 'When it occurs *', kind: _FieldKind.textSingle, required: true),
    _Field(key: 'duration', label: 'Duration', kind: _FieldKind.textSingle),
    _Field(key: 'participants', label: 'Participants *', kind: _FieldKind.textMulti, required: true, hint: 'Who takes part? Who may witness?'),
    _Field(key: 'objects_used', label: 'Objects used', kind: _FieldKind.tagInput),
    _Field(key: 'foods_used', label: 'Foods used', kind: _FieldKind.tagInput),
    _Field(key: 'music_used', label: 'Music used', kind: _FieldKind.tagInput),
    _Field(key: 'clothing_worn', label: 'Clothing worn', kind: _FieldKind.tagInput),
    _Field(key: 'site', label: 'Site', kind: _FieldKind.textSingle),
    _Field(key: 'is_restricted', label: 'Restricted', kind: _FieldKind.toggle, required: true),
    _Field(key: 'restriction_note', label: 'Restriction note', kind: _FieldKind.textMulti),
  ],
  'craft_technique': [
    _Field(key: 'subcategory', label: 'Subcategory *', kind: _FieldKind.dropdown, required: true, options: ['weaving_basketry', 'pottery_ceramics', 'metalwork_smithing', 'woodwork_carving', 'beadwork_jewellery', 'textile_cloth', 'leather_hide', 'paper_pulp', 'glass_mosaic']),
    _Field(key: 'materials', label: 'Materials *', kind: _FieldKind.tagInput, required: true),
    _Field(key: 'tools', label: 'Tools', kind: _FieldKind.tagInput),
    _Field(key: 'who_practises', label: 'Who practises this?', kind: _FieldKind.textSingle),
    _Field(key: 'learning_method', label: 'How is it learned?', kind: _FieldKind.textSingle, hint: 'e.g. Mother to daughter, Guild apprenticeship'),
    _Field(key: 'technique_steps', label: 'Technique overview', kind: _FieldKind.textMulti, hint: 'Overview of the making process'),
    _Field(key: 'is_endangered', label: 'Endangered', kind: _FieldKind.toggle),
  ],
  'clothing_tradition': [
    _Field(key: 'subcategory', label: 'Subcategory *', kind: _FieldKind.dropdown, required: true, options: ['everyday_dress', 'ceremonial_dress', 'mourning_dress', 'initiation_dress', 'restricted_sacred', 'body_adornment', 'pattern_symbolism']),
    _Field(key: 'occasion', label: 'Occasion', kind: _FieldKind.textSingle),
    _Field(key: 'who_wears', label: 'Who wears this? *', kind: _FieldKind.textSingle, required: true),
    _Field(key: 'materials', label: 'Materials', kind: _FieldKind.tagInput),
    _Field(key: 'pattern_meaning', label: 'Pattern meaning', kind: _FieldKind.textMulti),
    _Field(key: 'is_restricted', label: 'Restricted', kind: _FieldKind.toggle),
  ],
  'language_entry': [
    _Field(key: 'subcategory', label: 'Subcategory *', kind: _FieldKind.dropdown, required: true, options: ['full_language', 'dialect_variant', 'vocabulary_collection', 'phrases_greetings', 'proverbs_expressions', 'naming_conventions', 'tonal_notes']),
    _Field(key: 'endangerment_status', label: 'Endangerment status *', kind: _FieldKind.dropdown, required: true, options: ['thriving', 'stable', 'declining', 'endangered', 'critically_endangered', 'dormant']),
    _Field(key: 'iso_code', label: 'ISO 639-3 code', kind: _FieldKind.textSingle, hint: 'e.g. luy, luo, sw'),
    _Field(key: 'language_family', label: 'Language family', kind: _FieldKind.textSingle),
    _Field(key: 'speakers_approx', label: 'Approximate speaker count', kind: _FieldKind.textSingle, hint: 'e.g. 4 million'),
    _Field(key: 'script', label: 'Script', kind: _FieldKind.textSingle, hint: 'e.g. Latin alphabet, no dedicated script'),
    _Field(key: 'tonal', label: 'Tonal language', kind: _FieldKind.toggle),
  ],
  'place_knowledge': [
    _Field(key: 'subcategory', label: 'Subcategory *', kind: _FieldKind.dropdown, required: true, options: ['sacred_site', 'settlement_history', 'river_water', 'hill_mountain', 'traditional_boundary', 'migration_route', 'historical_event_site', 'informal_settlement_history']),
    _Field(key: 'traditional_name', label: 'Traditional name *', kind: _FieldKind.textSingle, required: true),
    _Field(key: 'modern_name', label: 'Modern name', kind: _FieldKind.textSingle),
    _Field(key: 'gps_lat', label: 'GPS latitude', kind: _FieldKind.textSingle, hint: 'e.g. -1.2921'),
    _Field(key: 'gps_lng', label: 'GPS longitude', kind: _FieldKind.textSingle, hint: 'e.g. 36.8219'),
    _Field(key: 'gps_accuracy_note', label: 'Location accuracy note', kind: _FieldKind.textSingle, hint: 'e.g. Approximate — site spans 2km radius'),
    _Field(key: 'cultural_significance', label: 'Cultural significance *', kind: _FieldKind.textMulti, required: true),
    _Field(key: 'what_has_changed', label: 'What has changed?', kind: _FieldKind.textMulti),
    _Field(key: 'communities_connected', label: 'Connected communities', kind: _FieldKind.tagInput),
    _Field(key: 'is_at_risk', label: 'At risk', kind: _FieldKind.toggle),
  ],
  'medicine_knowledge': [
    _Field(key: 'subcategory', label: 'Subcategory *', kind: _FieldKind.dropdown, required: true, options: ['medicinal_plant_use', 'healing_practice', 'healer_role', 'birth_midwifery', 'mental_health_tradition']),
    _Field(key: 'who_practises', label: 'Who practises this?', kind: _FieldKind.textSingle),
    _Field(key: 'plants_used', label: 'Plants used', kind: _FieldKind.tagInput),
    _Field(key: 'conditions_treated', label: 'Conditions treated', kind: _FieldKind.tagInput),
    _Field(key: 'is_restricted', label: 'Restricted', kind: _FieldKind.toggle),
  ],
  'person': [
    _Field(key: 'subcategory', label: 'Subcategory *', kind: _FieldKind.dropdown, required: true, options: ['elder_knowledge_holder', 'artisan_craftsperson', 'healer', 'storyteller', 'musician', 'historical_figure']),
    _Field(key: 'role', label: 'Role *', kind: _FieldKind.textSingle, required: true),
    _Field(key: 'bio', label: 'Biography *', kind: _FieldKind.textMulti, required: true),
    _Field(key: 'knowledge_areas', label: 'Knowledge areas', kind: _FieldKind.tagInput),
    _Field(key: 'consent_on_file', label: 'Consent on file', kind: _FieldKind.toggle, required: true),
    _Field(key: 'is_living', label: 'Still living', kind: _FieldKind.toggle, required: true),
    _Field(key: 'born_approx', label: 'Born (approximate)', kind: _FieldKind.textSingle, hint: 'e.g. 1948'),
    _Field(key: 'passed_approx', label: 'Passed (approximate)', kind: _FieldKind.textSingle),
  ],
};

/// Fields the creator renders itself (consent).
const _handledElsewhere = {'consent_on_file'};

String _humanise(String o) {
  final d = o.replaceAll('_', ' ');
  return d.isEmpty ? d : '${d[0].toUpperCase()}${d.substring(1)}';
}

String _cleanLabel(String l) => l.replaceAll(' *', '').replaceAll('*', '').trim();

class TypeDataFormBuilder extends StatefulWidget {
  final String contentType;
  final Map<String, dynamic> typeData;
  final void Function(String key, dynamic value) onChanged;

  const TypeDataFormBuilder({required this.contentType, required this.typeData, required this.onChanged, super.key});

  /// Required fields still empty — the creator lists these before Continue.
  static List<String> missingRequired(String contentType, Map<String, dynamic> data) => [
        for (final f in _schemas[contentType] ?? const <_Field>[])
          if (f.required && !_handledElsewhere.contains(f.key) && f.kind != _FieldKind.toggle && _isEmpty(data[f.key]))
            _cleanLabel(f.label),
      ];

  static bool _isEmpty(dynamic v) => v == null || (v is String && v.trim().isEmpty) || (v is List && v.isEmpty);

  @override
  State<TypeDataFormBuilder> createState() => _TypeDataFormBuilderState();
}

class _TypeDataFormBuilderState extends State<TypeDataFormBuilder> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, TextEditingController> _tagInputs = {};
  final Map<String, int> _langTab = {};

  List<_Field> get _fields =>
      (_schemas[widget.contentType] ?? const <_Field>[]).where((f) => !_handledElsewhere.contains(f.key)).toList();

  bool _hasVariants(String key) => _fields.any((g) => g.key == '${key}_swahili' || g.key == '${key}_english');

  Set<String> get _variantKeys => {
        for (final f in _fields)
          if (_hasVariants(f.key)) ...['${f.key}_swahili', '${f.key}_english'],
      };

  @override
  void initState() {
    super.initState();
    for (final f in _schemas[widget.contentType] ?? const <_Field>[]) {
      if (f.kind == _FieldKind.textSingle || f.kind == _FieldKind.textMulti) {
        final v = widget.typeData[f.key];
        _controllers[f.key] = TextEditingController(text: v is String ? v : '');
      }
      if (f.kind == _FieldKind.tagInput) _tagInputs[f.key] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in [..._controllers.values, ..._tagInputs.values]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final variants = _variantKeys;
    final fields = _fields.where((f) => !variants.contains(f.key)).toList();
    if (fields.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final f in fields) ...[_field(f), const SizedBox(height: CanopySpace.s16)],
    ]);
  }

  Widget _field(_Field f) {
    if (f.key == 'restriction_note') {
      return RestrictionNoteField(
        controller: _controllers[f.key]!,
        onChanged: (v) => widget.onChanged(f.key, v.trim().isEmpty ? null : v),
      );
    }
    if (_hasVariants(f.key)) return _bilingual(f);
    return switch (f.kind) {
      _FieldKind.textSingle => CanopyTextField(
          label: _cleanLabel(f.label),
          hint: f.hint,
          controller: _controllers[f.key],
          onChanged: (v) => widget.onChanged(f.key, v.trim().isEmpty ? null : v),
        ),
      _FieldKind.textMulti => CanopyTextField(
          label: _cleanLabel(f.label),
          hint: f.hint,
          controller: _controllers[f.key],
          minLines: 3,
          maxLines: 8,
          onChanged: (v) => widget.onChanged(f.key, v.trim().isEmpty ? null : v),
        ),
      _FieldKind.dropdown => _dropdown(f),
      _FieldKind.toggle => _yesNo(f),
      _FieldKind.chipMulti => _chips(f),
      _FieldKind.tagInput => _tags(f),
    };
  }

  Widget _bilingual(_Field f) {
    final p = context.canopy;
    final keys = [f.key, '${f.key}_swahili', '${f.key}_english'].where(_controllers.containsKey).toList();
    const names = ['Original', 'Kiswahili', 'English'];
    final tab = (_langTab[f.key] ?? 0).clamp(0, keys.length - 1);
    final key = keys[tab];
    int words(String k) {
      final t = _controllers[k]!.text.trim();
      return t.isEmpty ? 0 : t.split(RegExp(r'\s+')).length;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(_cleanLabel(f.label).replaceAll(RegExp(r'\s*\(.*\)'), ''), style: CanopyType.label.copyWith(color: p.ink)),
      const SizedBox(height: CanopySpace.s8),
      CanopySegmented<int>(
        options: [for (var i = 0; i < keys.length; i++) (i, '${names[i]} · ${words(keys[i])}')],
        value: tab,
        onChanged: (i) => setState(() => _langTab[f.key] = i),
      ),
      const SizedBox(height: CanopySpace.s8),
      CanopyTextField(
        key: ValueKey(key),
        hint: tab == 0 ? (f.hint ?? 'As told, in the original language') : 'Translation (optional)',
        controller: _controllers[key],
        minLines: 5,
        maxLines: 14,
        onChanged: (v) {
          widget.onChanged(key, v.trim().isEmpty ? null : v);
          setState(() {});
        },
      ),
    ]);
  }

  Widget _dropdown(_Field f) {
    final value = widget.typeData[f.key] as String?;
    final options = f.options ?? const <String>[];
    return CanopyPickerField(
      label: _cleanLabel(f.label),
      value: value == null ? null : _humanise(value),
      placeholder: 'Choose',
      onTap: () async {
        final picked = await showCanopySheet<String>(context, builder: (ctx) {
          return CanopySheetBody(title: _cleanLabel(f.label), children: [
            CanopyListGroup(children: [
              for (final o in options)
                CanopyListRow(
                  title: _humanise(o),
                  chevron: false,
                  trailing: o == value ? Icon(Icons.check, color: ctx.canopy.ink) : null,
                  onTap: () => Navigator.pop(ctx, o),
                ),
            ]),
          ]);
        });
        if (picked != null) widget.onChanged(f.key, picked);
      },
    );
  }

  Widget _yesNo(_Field f) {
    final p = context.canopy;
    final v = widget.typeData[f.key];
    final current = v == true ? 1 : (v == false ? 0 : 2);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(_cleanLabel(f.label), style: CanopyType.label.copyWith(color: p.ink)),
      if (f.hint != null) Text(f.hint!, style: CanopyType.caption.copyWith(color: p.inkMuted)),
      const SizedBox(height: CanopySpace.s8),
      CanopySegmented<int>(
        options: const [(1, 'Yes'), (0, 'No'), (2, 'Unsure')],
        value: current,
        onChanged: (i) => widget.onChanged(f.key, i == 2 ? null : i == 1),
      ),
    ]);
  }

  Widget _chips(_Field f) {
    final p = context.canopy;
    final selected = ((widget.typeData[f.key] as List?) ?? const []).cast<String>().toSet();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_cleanLabel(f.label), style: CanopyType.label.copyWith(color: p.ink)),
      const SizedBox(height: CanopySpace.s8),
      Wrap(spacing: CanopySpace.s8, runSpacing: CanopySpace.s8, children: [
        for (final o in f.options ?? const <String>[])
          CanopyFilterChip(
            label: _humanise(o),
            selected: selected.contains(o),
            onTap: () {
              final next = {...selected};
              if (!next.remove(o)) next.add(o);
              widget.onChanged(f.key, next.toList());
            },
          ),
      ]),
    ]);
  }

  Widget _tags(_Field f) {
    final p = context.canopy;
    final tags = ((widget.typeData[f.key] as List?) ?? const []).cast<String>();
    final c = _tagInputs[f.key]!;
    void add() {
      final t = c.text.trim();
      if (t.isNotEmpty && !tags.contains(t)) widget.onChanged(f.key, [...tags, t]);
      c.clear();
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_cleanLabel(f.label), style: CanopyType.label.copyWith(color: p.ink)),
      if (f.hint != null) Text(f.hint!, style: CanopyType.caption.copyWith(color: p.inkMuted)),
      if (tags.isNotEmpty) ...[
        const SizedBox(height: CanopySpace.s8),
        Wrap(spacing: CanopySpace.s8, runSpacing: CanopySpace.s8, children: [
          for (final t in tags) CanopyRemovableChip(label: t, onRemove: () => widget.onChanged(f.key, [...tags]..remove(t))),
        ]),
      ],
      const SizedBox(height: CanopySpace.s8),
      Row(children: [
        Expanded(child: CanopyTextField(hint: 'Add one, then Enter', controller: c, onSubmitted: (_) => add())),
        const SizedBox(width: CanopySpace.s8),
        CanopyIconButton(icon: Icons.add, tooltip: 'Add', onPressed: add),
      ]),
    ]);
  }
}
