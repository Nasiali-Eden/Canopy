import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../Shared/theme/app_theme.dart';
import '../heritage_theme.dart';
import 'create_entry_provider.dart';
import 'locality_selector_sheet.dart';
import 'media_upload_item.dart';
import 'type_data_form_builder.dart';

// ─── Entry point ─────────────────────────────────────────────────────────────

class CreateEntryScreen extends StatelessWidget {
  final String orgId;

  const CreateEntryScreen({required this.orgId, super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CreateEntryProvider(orgId: orgId),
      child: const _CreateEntryView(),
    );
  }
}

// ─── Main view ───────────────────────────────────────────────────────────────

class _CreateEntryView extends StatefulWidget {
  const _CreateEntryView();

  @override
  State<_CreateEntryView> createState() => _CreateEntryViewState();
}

class _CreateEntryViewState extends State<_CreateEntryView> {
  late final PageController _pageController;

  static const _stepTitles = [
    'Step 1 of 6 · Content Type',
    'Step 2 of 6 · Locality',
    'Step 3 of 6 · Name',
    'Step 4 of 6 · Knowledge',
    'Step 5 of 6 · Media',
    'Step 6 of 6 · Visibility',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToStep(int step, CreateEntryProvider prov) {
    prov.goToStep(step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _submit(CreateEntryProvider prov) async {
    await prov.submit();
    if (!mounted) return;
    if (prov.submitError == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Entry added to archive'),
          backgroundColor: AppTheme.primary,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(prov.submitError!), backgroundColor: Colors.red[700]),
      );
    }
  }

  Future<void> _confirmExit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard entry?'),
        content: const Text('Your progress will not be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CreateEntryProvider>(
      builder: (context, prov, _) {
        return Scaffold(
          backgroundColor: HeritageTheme.heritageBackground,
          appBar: AppBar(
            backgroundColor: HeritageTheme.heritageBackground,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            foregroundColor: AppTheme.darkGreen,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: _confirmExit,
            ),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add to Archive',
                  style: TextStyle(
                    color: AppTheme.darkGreen,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Cormorant Garamond',
                    fontStyle: FontStyle.italic,
                  ),
                ),
                Text(
                  _stepTitles[prov.currentStep],
                  style: TextStyle(
                    color: AppTheme.tertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              _StepIndicator(currentStep: prov.currentStep),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _StepTypeSelector(onGoNext: () => _goToStep(1, prov)),
                    const _StepLocality(),
                    const _StepName(),
                    const _StepKnowledge(),
                    const _StepMedia(),
                    _StepVisibility(onSubmit: () => _submit(prov)),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: _BottomBar(
            currentStep: prov.currentStep,
            canProceed: prov.canProceedFromStep(prov.currentStep),
            isSubmitting: prov.isSubmitting,
            consentChecked: prov.consentChecked,
            onBack: prov.currentStep > 0 ? () => _goToStep(prov.currentStep - 1, prov) : null,
            onNext: () => _goToStep(prov.currentStep + 1, prov),
            onSubmit: () => _submit(prov),
          ),
        );
      },
    );
  }
}

// ─── Step indicator ──────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int currentStep;

  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: List.generate(6, (i) {
          final done = i < currentStep;
          final active = i == currentStep;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: 3,
              decoration: BoxDecoration(
                color: (done || active)
                    ? AppTheme.tertiary
                    : AppTheme.tertiary.withOpacity(0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Bottom action bar ───────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final int currentStep;
  final bool canProceed;
  final bool isSubmitting;
  final bool consentChecked;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

  const _BottomBar({
    required this.currentStep,
    required this.canProceed,
    required this.isSubmitting,
    required this.consentChecked,
    required this.onBack,
    required this.onNext,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = currentStep == 5;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (onBack != null)
                OutlinedButton(
                  onPressed: onBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.darkGreen,
                    side: BorderSide(color: AppTheme.darkGreen.withOpacity(0.35)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    // Override theme's Size.fromHeight(48) which forces infinite width in a Row.
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Back'),
                ),
              const Spacer(),
              if (!isLast)
                FilledButton(
                  onPressed: canProceed ? onNext : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.tertiary,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Continue'),
                )
              else
                FilledButton(
                  onPressed: (consentChecked && !isSubmitting) ? onSubmit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Add to Archive'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Step 1: Content type selector ───────────────────────────────────────────

class _StepTypeSelector extends StatelessWidget {
  final VoidCallback onGoNext;

  const _StepTypeSelector({required this.onGoNext});

  static const _types = [
    ('oral_tradition', 'Oral Tradition', Icons.menu_book_outlined),
    ('food_tradition', 'Food Tradition', Icons.restaurant_outlined),
    ('ingredient', 'Ingredient', Icons.eco_outlined),
    ('music_tradition', 'Music', Icons.music_note_outlined),
    ('instrument', 'Instrument', Icons.piano_outlined),
    ('ceremony', 'Ceremony', Icons.celebration_outlined),
    ('craft_technique', 'Craft Technique', Icons.handyman_outlined),
    ('clothing_tradition', 'Clothing', Icons.checkroom_outlined),
    ('language_entry', 'Language', Icons.translate_outlined),
    ('place_knowledge', 'Place', Icons.place_outlined),
    ('medicine_knowledge', 'Medicine', Icons.local_hospital_outlined),
    ('person', 'Person', Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<CreateEntryProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What kind of knowledge are you archiving?',
            style: TextStyle(
              color: AppTheme.darkGreen,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.2,
            ),
            itemCount: _types.length,
            itemBuilder: (context, i) {
              final (key, label, icon) = _types[i];
              final selected = prov.selectedContentType == key;
              return _TypeCard(
                key: ValueKey(key),
                typeKey: key,
                label: label,
                icon: icon,
                selected: selected,
                onTap: () {
                  context.read<CreateEntryProvider>().setContentType(key);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String typeKey;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeCard({
    super.key,
    required this.typeKey,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected ? AppTheme.tertiary.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.tertiary : Colors.grey[200]!,
            width: selected ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? AppTheme.tertiary : AppTheme.darkGreen.withOpacity(0.6),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? AppTheme.tertiary : AppTheme.darkGreen,
                ),
                maxLines: 2,
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, size: 16, color: AppTheme.tertiary),
          ],
        ),
      ),
    );
  }
}

// ─── Step 2: Locality ────────────────────────────────────────────────────────

class _StepLocality extends StatelessWidget {
  const _StepLocality();

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<CreateEntryProvider>();
    final loc = prov.locality;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Where does this knowledge belong?',
            style: TextStyle(
              color: AppTheme.darkGreen,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Be as specific as you can. If the community is unknown, that is fine — select the option below.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),

          // Community selector
          GestureDetector(
            onTap: loc.communityUnknown
                ? null
                : () async {
                    final result = await showModalBottomSheet<CommunitySelection?>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const LocalitySelectorSheet(),
                    );
                    if (result != null && context.mounted) {
                      context.read<CreateEntryProvider>().setCommunity(result.id, result.name);
                    } else if (result == null && context.mounted) {
                      // User tapped "Community unknown" inside the sheet
                      context.read<CreateEntryProvider>().setCommunityUnknown(true);
                    }
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: loc.communityUnknown ? Colors.grey[100] : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: loc.communityId != null
                      ? AppTheme.tertiary
                      : Colors.grey[300]!,
                  width: loc.communityId != null ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 20,
                    color: loc.communityId != null
                        ? AppTheme.tertiary
                        : Colors.grey[500],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      loc.communityId != null
                          ? (loc.communityName ?? loc.communityId!)
                          : 'Select community…',
                      style: TextStyle(
                        fontSize: 14,
                        color: loc.communityId != null
                            ? AppTheme.darkGreen
                            : Colors.grey[500],
                      ),
                    ),
                  ),
                  if (!loc.communityUnknown)
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Community unknown toggle
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
              color: Colors.white,
            ),
            child: SwitchListTile(
              title: const Text(
                'Community unknown',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                "I can't identify which community this belongs to",
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              value: loc.communityUnknown,
              activeColor: AppTheme.tertiary,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              onChanged: (v) => context.read<CreateEntryProvider>().setCommunityUnknown(v),
            ),
          ),
          const SizedBox(height: 20),

          // Locality notes
          TextField(
            decoration: InputDecoration(
              labelText: 'Locality notes',
              hintText: 'e.g. Practiced in the Kibera Luo diaspora, not the Nyanza homeland',
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
            onChanged: (v) => context.read<CreateEntryProvider>().setLocalityNotes(v),
          ),
        ],
      ),
    );
  }
}

// ─── Step 3: Name & language ──────────────────────────────────────────────────

class _StepName extends StatefulWidget {
  const _StepName();

  @override
  State<_StepName> createState() => _StepNameState();
}

class _StepNameState extends State<_StepName> with AutomaticKeepAliveClientMixin {
  late final TextEditingController _title;
  late final TextEditingController _titleSw;
  late final TextEditingController _titleEn;
  late final TextEditingController _lang;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final p = context.read<CreateEntryProvider>();
    _title = TextEditingController(text: p.title)
      ..addListener(() => context.read<CreateEntryProvider>().setTitle(_title.text));
    _titleSw = TextEditingController(text: p.titleSwahili)
      ..addListener(() => context.read<CreateEntryProvider>().setTitleSwahili(_titleSw.text));
    _titleEn = TextEditingController(text: p.titleEnglish)
      ..addListener(() => context.read<CreateEntryProvider>().setTitleEnglish(_titleEn.text));
    _lang = TextEditingController(text: p.primaryLanguage)
      ..addListener(() => context.read<CreateEntryProvider>().setPrimaryLanguage(_lang.text));
  }

  @override
  void dispose() {
    _title.dispose();
    _titleSw.dispose();
    _titleEn.dispose();
    _lang.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Name this entry',
            style: TextStyle(color: AppTheme.darkGreen, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'The title in the original language is required. Translations are optional but help with discovery.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Title *',
              hintText: 'In the original language',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleSw,
            decoration: const InputDecoration(
              labelText: 'Title (Swahili)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleEn,
            decoration: const InputDecoration(
              labelText: 'Title (English)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          TextField(
            controller: _lang,
            decoration: const InputDecoration(
              labelText: 'Primary language',
              hintText: 'e.g. Luhya, Dholuo, or ISO 639-3 code (luy, luo)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 4: Knowledge & type-specific fields ─────────────────────────────────

class _StepKnowledge extends StatefulWidget {
  const _StepKnowledge();

  @override
  State<_StepKnowledge> createState() => _StepKnowledgeState();
}

class _StepKnowledgeState extends State<_StepKnowledge> with AutomaticKeepAliveClientMixin {
  late final TextEditingController _desc;
  late final TextEditingController _descSw;
  late final TextEditingController _descEn;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final p = context.read<CreateEntryProvider>();
    _desc = TextEditingController(text: p.description)
      ..addListener(() => context.read<CreateEntryProvider>().setDescription(_desc.text));
    _descSw = TextEditingController(text: p.descriptionSwahili)
      ..addListener(() => context.read<CreateEntryProvider>().setDescriptionSwahili(_descSw.text));
    _descEn = TextEditingController(text: p.descriptionEnglish)
      ..addListener(() => context.read<CreateEntryProvider>().setDescriptionEnglish(_descEn.text));
  }

  @override
  void dispose() {
    _desc.dispose();
    _descSw.dispose();
    _descEn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final prov = context.watch<CreateEntryProvider>();
    final descLen = prov.description.trim().length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Describe the knowledge',
            style: TextStyle(color: AppTheme.darkGreen, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'The main description in the original language. Minimum 50 characters. Translations are optional.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),

          // Description
          TextField(
            controller: _desc,
            decoration: InputDecoration(
              labelText: 'Description *',
              hintText: 'Write in the original language',
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
              helperText: descLen < 50 ? '${50 - descLen} more characters needed' : null,
              helperStyle: const TextStyle(color: Colors.orange),
            ),
            maxLines: 7,
            minLines: 4,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descSw,
            decoration: const InputDecoration(
              labelText: 'Description (Swahili)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 5,
            minLines: 3,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descEn,
            decoration: const InputDecoration(
              labelText: 'Description (English)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 5,
            minLines: 3,
          ),

          if (prov.selectedContentType != null) ...[
            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 20),
            Text(
              'Type-specific details',
              style: TextStyle(color: AppTheme.darkGreen, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TypeDataFormBuilder(
              contentType: prov.selectedContentType!,
              typeData: prov.typeData,
              onChanged: (key, value) =>
                  context.read<CreateEntryProvider>().setTypeDataField(key, value),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Step 5: Media ────────────────────────────────────────────────────────────

class _StepMedia extends StatelessWidget {
  const _StepMedia();

  static final _picker = ImagePicker();

  static const _imageRoles = [
    'cover_image',
    'documentation_image',
    'process_image',
    'artefact_image',
    'context_image',
    'historical_image',
    'pattern_detail',
  ];

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<CreateEntryProvider>();
    final images = prov.mediaFiles.where((m) => m.mediaType == 'image').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add media',
            style: TextStyle(color: AppTheme.darkGreen, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Images help tell the story. The first image you add becomes the cover. All media is optional.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),

          // Image section
          Row(
            children: [
              Text(
                'Images',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkGreen,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _pickImage(context, prov),
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text('Add image'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.tertiary),
              ),
            ],
          ),

          if (images.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: HeritageTheme.heritageCardBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.grey[200]!,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.photo_library_outlined, size: 36, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text('No images added yet', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _MediaCard(
                item: images[i],
                roles: _imageRoles,
                onRemove: () => context.read<CreateEntryProvider>().removeMediaFile(images[i].localId),
                onSetPrimary: () => context.read<CreateEntryProvider>().setMediaPrimary(images[i].localId),
                onSetRole: (r) => context.read<CreateEntryProvider>().setMediaRole(images[i].localId, r),
                onSetCaption: (c) => context.read<CreateEntryProvider>().setMediaCaption(images[i].localId, c),
              ),
            ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),

          // Audio section (placeholder — requires file_picker package)
          Row(
            children: [
              Text(
                'Audio',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkGreen,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              Tooltip(
                message: 'Audio upload coming soon',
                child: TextButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.audio_file_outlined, size: 18),
                  label: const Text('Add audio'),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey),
                ),
              ),
            ],
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(
              'Audio upload requires additional package configuration',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(BuildContext context, CreateEntryProvider prov) async {
    final xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (xFile == null || !context.mounted) return;
    await prov.addMediaFile(
      File(xFile.path),
      'image',
      prov.mediaFiles.where((m) => m.mediaType == 'image').isEmpty
          ? 'cover_image'
          : 'documentation_image',
    );
  }
}

class _MediaCard extends StatelessWidget {
  final MediaUploadItem item;
  final List<String> roles;
  final VoidCallback onRemove;
  final VoidCallback onSetPrimary;
  final void Function(String role) onSetRole;
  final void Function(String caption) onSetCaption;

  const _MediaCard({
    required this.item,
    required this.roles,
    required this.onRemove,
    required this.onSetPrimary,
    required this.onSetRole,
    required this.onSetCaption,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.isPrimary ? AppTheme.tertiary : Colors.grey[200]!,
          width: item.isPrimary ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // Preview + status
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
            child: Stack(
              children: [
                SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: item.uploadState == MediaUploadState.uploaded
                      ? Image.file(item.file, fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey[100],
                          child: Center(
                            child: item.uploadState == MediaUploadState.uploading
                                ? const CircularProgressIndicator(strokeWidth: 2)
                                : Icon(Icons.error_outline, color: Colors.red[300]),
                          ),
                        ),
                ),
                if (item.isPrimary)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.tertiary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Cover',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(4),
                    ),
                    onPressed: onRemove,
                  ),
                ),
              ],
            ),
          ),

          // Controls
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: roles.contains(item.mediaRole) ? item.mediaRole : null,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: roles.map((r) {
                          final label = r.replaceAll('_', ' ');
                          return DropdownMenuItem(
                            value: r,
                            child: Text(
                              '${label[0].toUpperCase()}${label.substring(1)}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (r) { if (r != null) onSetRole(r); },
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!item.isPrimary)
                      TextButton(
                        onPressed: onSetPrimary,
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.tertiary,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        child: const Text('Set cover', style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Caption',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  style: const TextStyle(fontSize: 13),
                  onChanged: onSetCaption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 6: Visibility & submit ──────────────────────────────────────────────

class _StepVisibility extends StatelessWidget {
  final VoidCallback onSubmit;

  const _StepVisibility({required this.onSubmit});

  static const _visibilityOptions = [
    ('public', 'Public', 'Visible to anyone in the Canopy network', Icons.public),
    ('community_only', 'Community only', 'Only visible to members of the associated community', Icons.group),
    ('restricted', 'Restricted', 'Only visible to verified org members', Icons.lock_outline),
    ('sealed', 'Sealed', 'Hidden — existence recorded, content not shown', Icons.lock),
  ];

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<CreateEntryProvider>();
    final needsReason = prov.visibility == 'restricted' || prov.visibility == 'sealed';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Who can see this entry?',
            style: TextStyle(color: AppTheme.darkGreen, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          // Visibility options
          ...(_visibilityOptions.map((opt) {
            final (key, label, desc, icon) = opt;
            final selected = prov.visibility == key;
            return GestureDetector(
              onTap: () => context.read<CreateEntryProvider>().setVisibility(key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.tertiary.withOpacity(0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? AppTheme.tertiary : Colors.grey[200]!,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: selected ? AppTheme.tertiary : Colors.grey[500]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: selected ? AppTheme.darkGreen : AppTheme.darkGreen.withOpacity(0.8),
                            ),
                          ),
                          Text(
                            desc,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_circle, size: 18, color: AppTheme.tertiary),
                  ],
                ),
              ),
            );
          })),

          if (needsReason) ...[
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Visibility reason *',
                hintText: 'Explain why this content is restricted',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              onChanged: (v) => context.read<CreateEntryProvider>().setVisibilityReason(v),
            ),
          ],

          const SizedBox(height: 20),

          // Seeking contributors toggle
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
              color: Colors.white,
            ),
            child: SwitchListTile(
              title: const Text('Seeking contributors', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: Text(
                'Others can add their knowledge and perspectives to this entry',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              value: prov.isSeekingContributors,
              activeColor: AppTheme.tertiary,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              onChanged: (v) => context.read<CreateEntryProvider>().setIsSeekingContributors(v),
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Review summary
          _ReviewSummary(prov: prov),

          const SizedBox(height: 20),

          // Consent
          Container(
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
            ),
            child: CheckboxListTile(
              title: const Text(
                'I confirm this knowledge is shared with the consent of the community or individual it belongs to, and I take responsibility for its accuracy.',
                style: TextStyle(fontSize: 13),
              ),
              value: prov.consentChecked,
              activeColor: AppTheme.primary,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (v) => context.read<CreateEntryProvider>().setConsentChecked(v ?? false),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  final CreateEntryProvider prov;

  const _ReviewSummary({required this.prov});

  @override
  Widget build(BuildContext context) {
    final mediaCount = prov.mediaFiles.where((m) => m.uploadState == MediaUploadState.uploaded).length;
    final typeDisplay = prov.selectedContentType?.replaceAll('_', ' ') ?? '—';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HeritageTheme.heritageCardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review',
            style: TextStyle(
              color: AppTheme.darkGreen,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          _ReviewRow('Type', '${typeDisplay[0].toUpperCase()}${typeDisplay.substring(1)}'),
          _ReviewRow('Title', prov.title.isEmpty ? '—' : prov.title),
          _ReviewRow(
            'Community',
            prov.locality.communityUnknown
                ? 'Unknown'
                : (prov.locality.communityName ?? 'Not specified'),
          ),
          _ReviewRow('Description', '${prov.description.trim().length} characters'),
          _ReviewRow('Media', '$mediaCount file${mediaCount == 1 ? '' : 's'} uploaded'),
          _ReviewRow('Visibility', prov.visibility.replaceAll('_', ' ')),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReviewRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
