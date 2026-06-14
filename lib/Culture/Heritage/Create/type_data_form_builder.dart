import 'package:flutter/material.dart';

import '../../../Shared/theme/app_theme.dart';
import '../heritage_theme.dart';

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

class TypeDataFormBuilder extends StatefulWidget {
  final String contentType;
  final Map<String, dynamic> typeData;
  final void Function(String key, dynamic value) onChanged;

  const TypeDataFormBuilder({
    required this.contentType,
    required this.typeData,
    required this.onChanged,
    super.key,
  });

  @override
  State<TypeDataFormBuilder> createState() => _TypeDataFormBuilderState();
}

class _TypeDataFormBuilderState extends State<TypeDataFormBuilder> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, TextEditingController> _tagInputControllers = {};

  List<_Field> get _fields => _schemas[widget.contentType] ?? const [];

  @override
  void initState() {
    super.initState();
    for (final field in _fields) {
      if (field.kind == _FieldKind.textSingle || field.kind == _FieldKind.textMulti) {
        final initial = widget.typeData[field.key];
        _controllers[field.key] = TextEditingController(
          text: initial is String ? initial : '',
        );
      }
      if (field.kind == _FieldKind.tagInput) {
        _tagInputControllers[field.key] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    for (final c in _tagInputControllers.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fields = _fields;
    if (fields.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final field in fields) ...[
          _buildField(field),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildField(_Field field) {
    switch (field.kind) {
      case _FieldKind.textSingle:
        return _buildTextSingle(field);
      case _FieldKind.textMulti:
        return _buildTextMulti(field);
      case _FieldKind.dropdown:
        return _buildDropdown(field);
      case _FieldKind.toggle:
        return _buildToggle(field);
      case _FieldKind.chipMulti:
        return _buildChipMulti(field);
      case _FieldKind.tagInput:
        return _buildTagInput(field);
    }
  }

  Widget _buildTextSingle(_Field field) {
    return TextField(
      controller: _controllers[field.key],
      decoration: InputDecoration(
        labelText: field.label,
        hintText: field.hint,
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) => widget.onChanged(field.key, v.isEmpty ? null : v),
    );
  }

  Widget _buildTextMulti(_Field field) {
    return TextField(
      controller: _controllers[field.key],
      decoration: InputDecoration(
        labelText: field.label,
        hintText: field.hint,
        border: const OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
      maxLines: 5,
      minLines: 3,
      onChanged: (v) => widget.onChanged(field.key, v.isEmpty ? null : v),
    );
  }

  Widget _buildDropdown(_Field field) {
    final value = widget.typeData[field.key] as String?;
    final options = field.options ?? const [];
    return DropdownButtonFormField<String>(
      value: options.contains(value) ? value : null,
      decoration: InputDecoration(
        labelText: field.label,
        border: const OutlineInputBorder(),
      ),
      items: options.map((o) {
        final display = o.replaceAll('_', ' ');
        return DropdownMenuItem(
          value: o,
          child: Text(
            '${display[0].toUpperCase()}${display.substring(1)}',
            style: const TextStyle(fontSize: 14),
          ),
        );
      }).toList(),
      onChanged: (v) => widget.onChanged(field.key, v),
    );
  }

  Widget _buildToggle(_Field field) {
    final value = (widget.typeData[field.key] as bool?) ?? false;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.tertiary.withOpacity(0.22)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SwitchListTile(
        title: Text(field.label),
        subtitle: field.hint != null ? Text(field.hint!, style: const TextStyle(fontSize: 12)) : null,
        value: value,
        activeColor: AppTheme.tertiary,
        onChanged: (v) => widget.onChanged(field.key, v),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }

  Widget _buildChipMulti(_Field field) {
    final selected = ((widget.typeData[field.key] as List?) ?? const []).cast<String>().toSet();
    final options = field.options ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.label,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: options.map((o) {
            final active = selected.contains(o);
            return FilterChip(
              label: Text(
                '${o[0].toUpperCase()}${o.substring(1)}',
                style: TextStyle(fontSize: 13, color: active ? Colors.white : AppTheme.darkGreen),
              ),
              selected: active,
              selectedColor: AppTheme.tertiary,
              checkmarkColor: Colors.white,
              backgroundColor: HeritageTheme.heritageBackground,
              side: BorderSide(color: active ? AppTheme.tertiary : AppTheme.tertiary.withOpacity(0.22)),
              onSelected: (v) {
                final next = Set<String>.from(selected);
                if (v) next.add(o); else next.remove(o);
                widget.onChanged(field.key, next.toList());
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTagInput(_Field field) {
    final tags = ((widget.typeData[field.key] as List?) ?? const []).cast<String>();
    final controller = _tagInputControllers[field.key]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.label,
          style: TextStyle(color: Colors.grey[700], fontSize: 14, fontWeight: FontWeight.w500),
        ),
        if (field.hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: Text(field.hint!, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          )
        else
          const SizedBox(height: 8),
        if (tags.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: tags.map((t) => Chip(
              label: Text(t, style: const TextStyle(fontSize: 13)),
              backgroundColor: HeritageTheme.heritageCardBackground,
              side: BorderSide(color: AppTheme.tertiary.withOpacity(0.4)),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () {
                final next = List<String>.from(tags)..remove(t);
                widget.onChanged(field.key, next);
              },
            )).toList(),
          ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Add item, press Enter',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.tertiary.withOpacity(0.22)),
                  ),
                ),
                onSubmitted: (v) {
                  final trimmed = v.trim();
                  if (trimmed.isNotEmpty && !tags.contains(trimmed)) {
                    widget.onChanged(field.key, [...tags, trimmed]);
                  }
                  controller.clear();
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: AppTheme.tertiary),
              onPressed: () {
                final trimmed = controller.text.trim();
                if (trimmed.isNotEmpty && !tags.contains(trimmed)) {
                  widget.onChanged(field.key, [...tags, trimmed]);
                }
                controller.clear();
              },
            ),
          ],
        ),
      ],
    );
  }
}
