import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../Shared/theme/app_theme.dart';
import '../Components/index.dart';
import '../Models/index.dart';
import '../Services/heritage_providers.dart';
import '../heritage_theme.dart';

/// HeritageMediaScreen — Media tab showing images and audio files
/// Two tabs: Images and Audio
class HeritageMediaScreen extends StatefulWidget {
  final String orgId;

  const HeritageMediaScreen({
    required this.orgId,
    Key? key,
  }) : super(key: key);

  @override
  State<HeritageMediaScreen> createState() => _HeritageMediaScreenState();
}

class _HeritageMediaScreenState extends State<HeritageMediaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider =
          Provider.of<HeritageMediaProvider>(context, listen: false);
      provider.fetchMedia(widget.orgId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<HeritageMediaProvider>(context);
    final allMedia = provider.media;
    final isLoading = provider.isLoading;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final images = allMedia.where((m) => m.mediaType == 'image').toList();
    final audio = allMedia.where((m) => m.mediaType == 'audio').toList();

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: AppTheme.tertiary,
          unselectedLabelColor: AppTheme.darkGreen.withOpacity(0.4),
          indicatorColor: AppTheme.tertiary,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          tabs: [
            Tab(
              text: 'Images (${images.length})',
            ),
            Tab(
              text: 'Audio (${audio.length})',
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildImagesGrid(images),
              _buildAudioList(audio),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImagesGrid(List<CulturalMedia> images) {
    if (images.isEmpty) {
      return Center(
        child: Text(
          'No images yet',
          style: TextStyle(
            color: AppTheme.darkGreen.withOpacity(0.5),
            fontSize: 13,
          ),
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      padding: const EdgeInsets.all(16),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final media = images[index];
        return HeritageCard(
          margin: EdgeInsets.zero,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Container(
                    color: AppTheme.lightGreen.withOpacity(0.2),
                    child: Image.network(
                      media.fileUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.image_not_supported);
                      },
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
                child: Text(
                  media.caption ?? 'Untitled',
                  style: TextStyle(
                    color: AppTheme.darkGreen,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'Entry title',
                  style: TextStyle(
                    color: AppTheme.darkGreen.withOpacity(0.5),
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                child: ContentTypePill(
                  contentType: 'Place',
                  fontSize: 9,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAudioList(List<CulturalMedia> audio) {
    if (audio.isEmpty) {
      return Center(
        child: Text(
          'No audio files yet',
          style: TextStyle(
            color: AppTheme.darkGreen.withOpacity(0.5),
            fontSize: 13,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemCount: audio.length,
      itemBuilder: (context, index) {
        final media = audio[index];
        return HeritageCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.audio_file_outlined,
                    color: AppTheme.tertiary,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      media.fileName,
                      style: TextStyle(
                        color: AppTheme.darkGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.play_circle_outline,
                      color: AppTheme.tertiary,
                      size: 28,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
              if (media.caption != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    media.caption!,
                    style: TextStyle(
                      color: AppTheme.darkGreen.withOpacity(0.7),
                      fontSize: 12,
                    ),
                    maxLines: 2,
                  ),
                ),
              Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 10,
                    color: AppTheme.darkGreen.withOpacity(0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    media.durationString,
                    style: TextStyle(
                      color: AppTheme.darkGreen.withOpacity(0.5),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.translate,
                    size: 10,
                    color: AppTheme.darkGreen.withOpacity(0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    media.languageCode ?? 'Unknown',
                    style: TextStyle(
                      color: AppTheme.darkGreen.withOpacity(0.5),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
