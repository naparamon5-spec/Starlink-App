import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

const _portal = 'https://starlink.ardentnetworks.com.ph/pdf';
// www.starlink.com serves its website (HTML) for the video paths; the files
// themselves are on the API host.
const _starlink = 'https://api.starlink.com/public-files';
const _pdfUrl = '$_portal/user_guide.pdf';

class _GuideVideo {
  const _GuideVideo({
    required this.name,
    required this.subtitle,
    required this.url,
    required this.thumb,
    required this.poster,
  });

  /// A video from Starlink's public files. [poster] defaults to [thumb].
  const _GuideVideo.starlink({
    required this.name,
    required this.subtitle,
    required String video,
    required String thumb,
    String? poster,
  }) : url = '$_starlink/videos/base/$video.mp4',
       thumb = '$_starlink/video_thumbnail_list_${thumb}_m.jpg',
       poster = '$_starlink/video_thumbnail_player_${poster ?? thumb}_d.webp';

  final String name;
  final String subtitle;
  final String url;
  final String thumb;
  final String poster;
}

/// Same list and order as the web portal
/// (ardent_starlink_client: app/pages/user-guide.vue).
const _videos = <_GuideVideo>[
  _GuideVideo(
    name: 'Ardent Starlink Guide (previous portal)',
    subtitle:
        'Walkthrough of the previous Ardent portal. An updated guide for this portal is on the way.',
    url: '$_portal/user_guide.mp4',
    thumb: '$_portal/user_guide.jpg',
    poster: '$_portal/user_guide.webp',
  ),
  _GuideVideo.starlink(
    name: 'What is Starlink?',
    subtitle: 'High-speed internet is available almost anywhere in the world.',
    video: 'Starlink_What_Is_Starlink',
    thumb: 'what_is_starlink',
  ),
  _GuideVideo.starlink(
    name: 'Blockers',
    subtitle: 'Set up Starlink with an unobstructed view of the sky.',
    video: 'Starlink_Obstructions_Video',
    thumb: 'obstructions',
  ),
  _GuideVideo.starlink(
    name: 'Mini Quickstart',
    subtitle: 'Get online in a few minutes.',
    video: 'Starlink_Mini_Quick_Start_Video',
    thumb: 'mini_quick_start',
  ),
  _GuideVideo.starlink(
    name: 'Quick Start For Standard',
    subtitle: 'It is easy to get online in just a few minutes.',
    video: 'Starlink_Standard_Quick_Start_Video',
    thumb: 'standard_quick_start',
  ),
  _GuideVideo.starlink(
    name: 'Installation For Standard',
    subtitle: 'Learn how to install Starlink for best performance.',
    video: 'Starlink_Standard_Install_Video',
    thumb: 'standard_install',
    poster: 'standard_actuated_install',
  ),
  _GuideVideo.starlink(
    name: 'Permanent Installation For Standard Actuated',
    subtitle: 'Learn how to install Starlink for best performance.',
    video: 'Starlink_Standard_Actuated_Install_Video',
    thumb: 'standard_actuated_install',
  ),
  _GuideVideo.starlink(
    name: 'Wall Mount For Standard',
    subtitle: 'Best for installation on the side of your house.',
    video: 'Starlink_Standard_Install_Wall_Mount_Video',
    thumb: 'standard_install_wall_mount',
  ),
  _GuideVideo.starlink(
    name: 'Pivot Mount For Standard',
    subtitle: 'Best for direct installation on the sloping roof of the house.',
    video: 'Starlink_Standard_Install_Pivot_Mount_Video',
    thumb: 'standard_install_pivot_mount',
  ),
  _GuideVideo.starlink(
    name: 'Pipe Adapter For Standard',
    subtitle: 'It is best suited for installation on an existing pole.',
    video: 'Starlink_Standard_Install_Pipe_Adapter_Video',
    thumb: 'standard_install_pipe_adapter',
  ),
  _GuideVideo.starlink(
    name: 'Alignment',
    subtitle: "Adjust Starlink's position for the best performance.",
    video: 'Starlink_Alignment_Video',
    thumb: 'alignment',
  ),
  _GuideVideo.starlink(
    name: 'Rebooting',
    subtitle: 'How to reboot your Starlink and router.',
    video: 'Starlink_How_To_Reboot_Video',
    thumb: 'how_to_reboot',
  ),
  _GuideVideo.starlink(
    name: 'Factory Reset',
    subtitle: 'How to reset your Starlink router.',
    video: 'Starlink_How_To_Reset_Video',
    thumb: 'how_to_reset',
  ),
];

/// Videos and the PDF walkthrough, matching the web portal's User Guide.
class UserGuidePage extends StatefulWidget {
  const UserGuidePage({super.key});

  @override
  State<UserGuidePage> createState() => _UserGuidePageState();
}

class _UserGuidePageState extends State<UserGuidePage> {
  int _current = 0;
  VideoPlayerController? _video;
  ChewieController? _chewie;
  bool _loading = false;
  bool _failed = false;
  bool _endHandled = false;

  /// Bumped on every load so a slow load can't overwrite a newer selection.
  int _loadId = 0;

  @override
  void dispose() {
    _loadId++;
    _video?.removeListener(_onVideoTick);
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
  }

  /// Detaches the current player from the tree, disposing it after the frame
  /// so the old player widgets never touch a disposed controller.
  void _releasePlayer() {
    final video = _video;
    final chewie = _chewie;
    video?.removeListener(_onVideoTick);
    _video = null;
    _chewie = null;
    if (video == null && chewie == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      chewie?.dispose();
      video?.dispose();
    });
  }

  Future<void> _play(int index) async {
    final id = ++_loadId;
    setState(() {
      _releasePlayer();
      _current = index;
      _loading = true;
      _failed = false;
      _endHandled = false;
    });

    final video = VideoPlayerController.networkUrl(
      Uri.parse(_videos[index].url),
    );
    try {
      await video.initialize();
    } catch (_) {
      await video.dispose();
      if (!mounted || id != _loadId) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    if (!mounted || id != _loadId) {
      await video.dispose();
      return;
    }

    final chewie = ChewieController(
      videoPlayerController: video,
      autoPlay: true,
      aspectRatio: video.value.aspectRatio,
      allowPlaybackSpeedChanging: false,
      deviceOrientationsOnEnterFullScreen: const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      deviceOrientationsAfterFullScreen: const [DeviceOrientation.portraitUp],
      materialProgressColors: ChewieProgressColors(
        playedColor: AppColors.brand,
        handleColor: AppColors.brand,
        bufferedColor: Colors.white38,
        backgroundColor: Colors.white24,
      ),
    );
    video.addListener(_onVideoTick);
    setState(() {
      _video = video;
      _chewie = chewie;
      _loading = false;
    });
  }

  /// Moves on to the next video when one finishes, like the web player.
  void _onVideoTick() {
    final video = _video;
    if (video == null || _endHandled) return;
    final value = video.value;
    final ended =
        value.isInitialized &&
        !value.isPlaying &&
        value.duration > Duration.zero &&
        value.position >= value.duration;
    if (!ended) return;
    _endHandled = true;
    // Leave the full-screen route alone; swapping its controller would break it.
    if (_chewie?.isFullScreen ?? false) return;
    if (_current < _videos.length - 1) _play(_current + 1);
  }

  Future<void> _openPdf() async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(_pdfUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // Reported below.
    }
    if (!opened && mounted) {
      AppToast.error(context, "Couldn't open the PDF guide.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final video = _videos[_current];
    return Scaffold(
      backgroundColor: AppColors.paperSubtle,
      appBar: AppBar(title: const Text('User Guide')),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: _video?.value.aspectRatio ?? 16 / 9,
            child: ColoredBox(color: AppColors.navyDark, child: _buildPlayer()),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: _videos.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return _buildIntro(video);
                final i = index - 1;
                return _VideoTile(
                  video: _videos[i],
                  selected: i == _current,
                  onTap: () => _play(i),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayer() {
    final chewie = _chewie;
    if (chewie != null) return Chewie(controller: chewie);
    if (_loading) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _Poster(url: _videos[_current].poster),
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      );
    }
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Couldn't load this video.",
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
            TextButton(
              onPressed: () => _play(_current),
              child: const Text(
                'Try again',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }
    // Nothing is streamed until the user asks for it.
    return GestureDetector(
      onTap: () => _play(_current),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Poster(url: _videos[_current].poster),
          const Center(
            child: Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white,
              size: 64,
              semanticLabel: 'Play video',
              shadows: [Shadow(color: Colors.black45, blurRadius: 12)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntro(_GuideVideo video) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          video.name,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          video.subtitle,
          style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: const Text(
            'The PDF guide and the Ardent walkthrough video still show the '
            'previous portal, so menus and screens look different here. An '
            'updated guide is on the way. The Starlink videos are current.',
            style: TextStyle(
              color: AppColors.warningInk,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _openPdf,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.brand,
            side: const BorderSide(color: AppColors.brand),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: const StadiumBorder(),
          ),
          icon: const Icon(Icons.description_outlined, size: 18),
          label: const Text('Open PDF guide (previous portal)'),
        ),
        const SizedBox(height: 20),
        Text(
          'Videos (${_videos.length})',
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) => Image.network(
    url,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
  );
}

class _VideoTile extends StatelessWidget {
  const _VideoTile({
    required this.video,
    required this.selected,
    required this.onTap,
  });

  final _GuideVideo video;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppColors.paper : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side:
              selected
                  ? BorderSide(color: AppColors.brand.withOpacity(0.4))
                  : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: SizedBox(
                    width: 112,
                    height: 63,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(
                          color: AppColors.paperMuted,
                          child: Image.network(
                            video.thumb,
                            fit: BoxFit.cover,
                            cacheWidth: 336,
                            errorBuilder:
                                (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                        if (selected)
                          const Center(
                            child: Icon(
                              Icons.play_circle_outline_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        video.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.inkMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
