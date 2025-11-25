import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer player;

  MyAudioHandler(this.player) {
    player.playbackEventStream.listen(_broadcastState);

    player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _broadcastState(player.playbackEvent);
      }
    });
  }

  void updateMetadata(MediaItem item) {
    mediaItem.add(item);
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = player.playing;

    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.rewind,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
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

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> seekBackward(bool begin) async {
    if (!begin) return;
    final pos = player.position - const Duration(seconds: 10);
    await player.seek(pos < Duration.zero ? Duration.zero : pos);
  }

  @override
  Future<void> seekForward(bool begin) async {
    if (!begin) return;
    final pos = player.position + const Duration(seconds: 10);
    final duration = player.duration;
    if (duration != null && pos > duration) {
      await player.seek(duration);
    } else {
      await player.seek(pos);
    }
  }
}
