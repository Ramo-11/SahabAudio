import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer player;

  MyAudioHandler(this.player) {
    // Broadcast playback state changes to the system
    player.playbackEventStream.listen(_broadcastState);

    // Also broadcast when the song finishes
    player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _broadcastState(player.playbackEvent);
      }
    });
  }

  // ✅ REQUIRED: This method allows the Controller to update the Lock Screen info
  void updateMetadata(MediaItem item) {
    mediaItem.add(item);
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = player.playing;

    playbackState.add(playbackState.value.copyWith(
      // ✅ CONTROLS: Defines the buttons on the Lock Screen
      // Using rewind/fastForward here triggers the +10s/-10s buttons on iOS
      controls: [
        MediaControl.rewind,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.fastForward,
      ],
      // ✅ SYSTEM ACTIONS: Tells iOS these actions are enabled
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      // For Android notification area
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[player.processingState]!,
      playing: playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: event.currentIndex,
    ));
  }

  // ✅ ACTIONS: Logic for the buttons
  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  // Skip Backward (e.g. -10s)
  @override
  Future<void> seekBackward(bool begin) async {
    if (!begin) return;
    // You can adjust the duration here (e.g., 10 or 15 seconds)
    final pos = player.position - const Duration(seconds: 10);
    await player.seek(pos < Duration.zero ? Duration.zero : pos);
  }

  // Skip Forward (e.g. +10s)
  @override
  Future<void> seekForward(bool begin) async {
    if (!begin) return;
    // You can adjust the duration here
    final pos = player.position + const Duration(seconds: 10);
    final duration = player.duration;
    if (duration != null && pos > duration) {
      await player.seek(duration);
    } else {
      await player.seek(pos);
    }
  }
}
