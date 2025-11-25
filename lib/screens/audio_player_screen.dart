import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../controllers/audio_player_controller.dart';
import '../main.dart';
import 'recording_screen.dart';
import 'playlist_screen.dart';

class AudioPlayerScreen extends StatefulWidget {
  final AudioPlayerController controller;
  const AudioPlayerScreen({Key? key, required this.controller})
      : super(key: key);

  @override
  _AudioPlayerScreenState createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen>
    with TickerProviderStateMixin {
  late AudioPlayerController _controller;
  late AnimationController _rotationController;
  StreamSubscription? _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;

    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );

    _setupAnimations();
    SharedFileHandler.instance.registerController(_controller);
  }

  void _setupAnimations() {
    _playerStateSubscription =
        _controller.player.playerStateStream.listen((state) {
      if (mounted) {
        if (state.playing) {
          _rotationController.repeat();
        } else {
          _rotationController.stop();
        }
      }
    });
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    SharedFileHandler.instance.unregisterController();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.white54, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  const Text(
                    'Now Playing',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.queue_music_rounded,
                        color: Colors.white54),
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              PlaylistScreen(controller: _controller)),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, child) {
                  final currentTrack = _controller.currentTrack;

                  if (currentTrack == null) {
                    return _buildEmptyState();
                  }

                  return SingleChildScrollView(
                      child: Column(
                    children: [
                      const SizedBox(height: 40),

                      // Album Art
                      AnimatedBuilder(
                        animation: _rotationController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _rotationController.value * 2 * 3.14159,
                            child: Container(
                              width: 280,
                              height: 280,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF8B5CF6),
                                    Color(0xFF6366F1),
                                    Color(0xFF4F46E5),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF8B5CF6)
                                        .withOpacity(0.3),
                                    blurRadius: 40,
                                    spreadRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.music_note_rounded,
                                  size: 80, color: Colors.white),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 32),

                      // Track Info
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(
                          children: [
                            Text(
                              currentTrack.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currentTrack.artist ?? 'Unknown Artist',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Progress
                      _buildProgressBar(),

                      const SizedBox(height: 24),

                      // Controls
                      _buildControls(),

                      const SizedBox(height: 24),

                      // Secondary Controls
                      _buildSecondaryControls(),

                      const SizedBox(height: 32),

                      // Volume
                      _buildVolumeControl(),

                      const SizedBox(height: 20),
                    ],
                  ));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(Icons.library_music_rounded,
                size: 48, color: Color(0xFF8B5CF6)),
          ),
          const SizedBox(height: 24),
          const Text(
            'No track selected',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Add audio files to start playing',
            style: TextStyle(color: Colors.white.withOpacity(0.5)),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _showAddSourceSheet(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Audio'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return StreamBuilder<Duration?>(
      stream: _controller.player.durationStream,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: _controller.player.positionStream,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: const Color(0xFF8B5CF6),
                      inactiveTrackColor: Colors.white12,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      min: 0,
                      max: duration.inMilliseconds.toDouble(),
                      value: position.inMilliseconds
                          .clamp(0, duration.inMilliseconds)
                          .toDouble(),
                      onChanged: (v) => _controller.player
                          .seek(Duration(milliseconds: v.toInt())),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _controller.formatDuration(position),
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12),
                        ),
                        Text(
                          _controller.formatDuration(duration),
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildControls() {
    return StreamBuilder<PlayerState>(
      stream: _controller.player.playerStateStream,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;
        final processingState =
            snapshot.data?.processingState ?? ProcessingState.idle;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous_rounded),
              iconSize: 40,
              color: _controller.playlist.length > 1
                  ? Colors.white
                  : Colors.white24,
              onPressed: _controller.playlist.length > 1
                  ? _controller.playPrevious
                  : null,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.replay_10_rounded),
              iconSize: 32,
              color: Colors.white60,
              onPressed: () {
                final newPos =
                    _controller.player.position - const Duration(seconds: 10);
                _controller.player
                    .seek(newPos < Duration.zero ? Duration.zero : newPos);
              },
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: _controller.currentTrack != null
                  ? () => playing
                      ? _controller.player.pause()
                      : _controller.player.play()
                  : null,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: processingState == ProcessingState.loading
                    ? const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        ),
                      )
                    : Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 44,
                        color: Colors.white,
                      ),
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.forward_10_rounded),
              iconSize: 32,
              color: Colors.white60,
              onPressed: () {
                final duration = _controller.player.duration ?? Duration.zero;
                final newPos =
                    _controller.player.position + const Duration(seconds: 10);
                _controller.player.seek(newPos > duration ? duration : newPos);
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.skip_next_rounded),
              iconSize: 40,
              color: _controller.playlist.length > 1
                  ? Colors.white
                  : Colors.white24,
              onPressed:
                  _controller.playlist.length > 1 ? _controller.playNext : null,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSecondaryControls() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildControlButton(
              icon: Icons.shuffle_rounded,
              isActive: _controller.isShuffleEnabled,
              onTap: _controller.toggleShuffle,
            ),
            const SizedBox(width: 24),
            _buildControlButton(
              icon: _controller.loopMode == LoopMode.one
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              isActive: _controller.loopMode != LoopMode.off,
              onTap: _controller.toggleLoop,
            ),
            const SizedBox(width: 24),
            _buildControlButton(
              icon: Icons.speed_rounded,
              label: '${_controller.speed.toStringAsFixed(1)}x',
              isActive: _controller.speed != 1.0,
              onTap: () => _showSpeedSheet(),
            ),
            const SizedBox(width: 24),
            _buildControlButton(
              icon: Icons.bedtime_rounded,
              isActive: _controller.sleepDuration != null,
              onTap: () => _showSleepTimerSheet(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    String? label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF8B5CF6).withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isActive ? const Color(0xFF8B5CF6) : Colors.white38,
                size: 22),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? const Color(0xFF8B5CF6) : Colors.white38,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeControl() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            children: [
              Icon(Icons.volume_down_rounded,
                  color: Colors.white.withOpacity(0.4), size: 22),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 5),
                    activeTrackColor: Colors.white54,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: _controller.volume,
                    onChanged: _controller.setVolume,
                  ),
                ),
              ),
              Icon(Icons.volume_up_rounded,
                  color: Colors.white.withOpacity(0.4), size: 22),
            ],
          ),
        );
      },
    );
  }

  void _showSpeedSheet() {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const Text('Playback Speed',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: speeds.map((s) {
                final isSelected = _controller.speed == s;
                return GestureDetector(
                  onTap: () {
                    _controller.setSpeed(s);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF8B5CF6)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          isSelected ? null : Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      '${s}x',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showSleepTimerSheet() {
    final durations = [
      (const Duration(minutes: 15), '15 min'),
      (const Duration(minutes: 30), '30 min'),
      (const Duration(minutes: 45), '45 min'),
      (const Duration(hours: 1), '1 hour'),
      (const Duration(hours: 2), '2 hours'),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const Text('Sleep Timer',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            ...durations.map((d) => ListTile(
                  title:
                      Text(d.$2, style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    _controller.setSleepTimer(d.$1);
                    Navigator.pop(context);
                  },
                )),
            if (_controller.sleepDuration != null) ...[
              const Divider(color: Colors.white12),
              ListTile(
                leading:
                    const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444)),
                title: const Text('Cancel Timer',
                    style: TextStyle(color: Color(0xFFEF4444))),
                onTap: () {
                  _controller.cancelSleepTimer();
                  Navigator.pop(context);
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAddSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const Text('Add Audio',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            _buildSourceTile(
                Icons.mic_rounded, 'Record', const Color(0xFFEF4444), () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          RecordingScreen(controller: _controller)));
            }),
            _buildSourceTile(
                Icons.folder_rounded, 'Files', const Color(0xFF3B82F6), () {
              Navigator.pop(context);
              _controller.pickAudioFiles();
            }),
            _buildSourceTile(
                Icons.photo_library_rounded, 'Photos', const Color(0xFF10B981),
                () {
              Navigator.pop(context);
              _controller.pickFromPhotos();
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceTile(
      IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: Icon(Icons.chevron_right_rounded,
          color: Colors.white.withOpacity(0.3)),
      onTap: onTap,
    );
  }
}
