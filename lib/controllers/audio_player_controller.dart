// controllers/audio_player_controller.dart
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:image_picker/image_picker.dart';
import 'package:volume_controller/volume_controller.dart';
import 'dart:async';
import '../models/audio_track.dart';

class AudioPlayerController extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  // State variables
  List<AudioTrack> _playlist = [];
  int _currentIndex = 0;
  double _speed = 1.0;
  bool _isShuffleEnabled = false;
  LoopMode _loopMode = LoopMode.off;
  double _volume = 0.8;
  bool _isEqEnabled = false;
  Timer? _sleepTimer;
  Duration? _sleepDuration;

  // Getters
  AudioPlayer get player => _player;
  List<AudioTrack> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  AudioTrack? get currentTrack =>
      _playlist.isNotEmpty ? _playlist[_currentIndex] : null;
  double get speed => _speed;
  bool get isShuffleEnabled => _isShuffleEnabled;
  LoopMode get loopMode => _loopMode;
  double get volume => _volume;
  bool get isEqEnabled => _isEqEnabled;
  Duration? get sleepDuration => _sleepDuration;

  AudioPlayerController() {
    _setupAudioPlayer();
    _setupSystemVolumeListener();
  }

  void _setupAudioPlayer() async {
    try {
      // Initialize background audio
      await JustAudioBackground.init(
        androidNotificationChannelId:
            'com.sahabsolutions.audio_player.channel.audio',
        androidNotificationChannelName: 'Sahab Audio',
        androidNotificationChannelDescription: 'Audio playback notifications',
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidShowNotificationBadge: true,
      );
    } catch (e) {
      print('Background audio initialization failed: $e');
    }

    // Set initial volume
    _player.setVolume(_volume);

    // Listen for when audio completes
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _handleAudioCompleted();
      }
    });
  }

  void _setupSystemVolumeListener() async {
    // Hide system volume UI when using app controls
    VolumeController.instance.showSystemUI = false;

    // Listen to system volume changes
    VolumeController.instance.addListener((volume) {
      if ((volume - _volume).abs() > 0.01) {
        // Avoid feedback loop
        _volume = volume;
        _player.setVolume(volume);
        notifyListeners();
      }
    }, fetchInitialVolume: true);
  }

  void _handleAudioCompleted() {
    if (_loopMode == LoopMode.one) {
      // Replay current track
      _player.seek(Duration.zero);
      _player.play();
    } else if (_loopMode == LoopMode.all ||
        _currentIndex < _playlist.length - 1) {
      // Play next track
      playNext();
    } else {
      // Stop at end of playlist
      _player.seek(Duration.zero);
      _player.stop();
    }
    notifyListeners();
  }

  Future<void> pickAudioFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final newTracks = result.files
          .where((file) => file.path != null)
          .where((file) => _isAudioFile(file.name)) // Filter after selection
          .map((file) => AudioTrack(
                path: file.path!,
                fileName: file.name,
                artist: 'Unknown Artist',
                album: 'Unknown Album',
              ))
          .toList();

      _playlist.addAll(newTracks);

      if (_playlist.length == newTracks.length) {
        _currentIndex = 0;
        await loadTrack(0);
      }

      notifyListeners();
    }
  }

  Future<void> pickFromPhotos() async {
    final ImagePicker picker = ImagePicker();

    // This opens Photos app and allows video selection (which includes audio)
    final XFile? file = await picker.pickVideo(source: ImageSource.gallery);

    if (file != null && _isAudioFile(file.name)) {
      final newTrack = AudioTrack(
        path: file.path,
        fileName: file.name,
        artist: 'Unknown Artist',
        album: 'Unknown Album',
      );

      _playlist.add(newTrack);
      if (_playlist.length == 1) {
        _currentIndex = 0;
        await loadTrack(0);
      }
      notifyListeners();
    }
  }

  Future<void> addSharedFile(String filePath) async {
    try {
      print('Attempting to add shared file: $filePath'); // Debug log

      // Extract filename from path
      final fileName = filePath.split('/').last;
      print('Extracted filename: $fileName'); // Debug log

      // Check if it's an audio file
      if (_isAudioFile(fileName)) {
        final newTrack = AudioTrack(
          path: filePath,
          fileName: fileName,
          artist: 'Voice Memo',
          album: 'Shared',
        );

        _playlist.add(newTrack);
        print(
            'Added track to playlist. Total tracks: ${_playlist.length}'); // Debug log

        // If this is the first track, load it
        if (_playlist.length == 1) {
          _currentIndex = 0;
          await loadTrack(0);
        }

        notifyListeners();
      } else {
        print('File is not recognized as audio: $fileName'); // Debug log
      }
    } catch (e) {
      print('Error adding shared file: $e');
    }
  }

  bool _isAudioFile(String fileName) {
    final audioExtensions = [
      'mp3',
      'm4a',
      'mp4',
      'wav',
      'flac',
      'aac',
      'caf',
      'aiff'
    ];
    final extension = fileName.toLowerCase().split('.').last;
    return audioExtensions.contains(extension);
  }

  Future<void> loadTrack(int index) async {
    if (index < 0 || index >= _playlist.length) return;

    try {
      _currentIndex = index;
      final track = _playlist[index];

      // Set audio source with metadata for background playback
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.file(track.path),
          tag: MediaItem(
            id: track.path,
            album: track.album ?? 'Unknown Album',
            title: track.displayName,
            artist: track.artist ?? 'Unknown Artist',
            artUri: null, // You can add album art URI here
          ),
        ),
      );

      notifyListeners();
    } catch (e) {
      print('Error loading audio: $e');
    }
  }

  Future<void> playNext() async {
    if (_playlist.isEmpty) return;

    int nextIndex;
    if (_isShuffleEnabled) {
      nextIndex = (_currentIndex + 1 + (DateTime.now().millisecond % 3)) %
          _playlist.length;
    } else {
      nextIndex = (_currentIndex + 1) % _playlist.length;
    }

    await loadTrack(nextIndex);
    _player.play();
  }

  Future<void> playPrevious() async {
    if (_playlist.isEmpty) return;

    final previousIndex =
        (_currentIndex - 1 + _playlist.length) % _playlist.length;
    await loadTrack(previousIndex);
    _player.play();
  }

  void toggleShuffle() {
    _isShuffleEnabled = !_isShuffleEnabled;
    notifyListeners();
  }

  void toggleLoop() {
    switch (_loopMode) {
      case LoopMode.off:
        _loopMode = LoopMode.one;
        break;
      case LoopMode.one:
        _loopMode = LoopMode.all;
        break;
      case LoopMode.all:
        _loopMode = LoopMode.off;
        break;
    }
    _player.setLoopMode(_loopMode);
    notifyListeners();
  }

  void setSpeed(double speed) {
    _speed = speed;
    _player.setSpeed(speed);
    notifyListeners();
  }

  void setVolume(double volume) async {
    _volume = volume;
    _player.setVolume(volume);
    try {
      await VolumeController.instance.setVolume(volume);
    } catch (e) {
      print('Error setting system volume: $e');
    }
    notifyListeners();
  }

  void setSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepDuration = duration;
    notifyListeners();

    _sleepTimer = Timer(duration, () {
      _player.pause();
      _sleepDuration = null;
      notifyListeners();
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepDuration = null;
    notifyListeners();
  }

  void removeTrack(int index) {
    if (index < 0 || index >= _playlist.length) return;

    _playlist.removeAt(index);

    if (_playlist.isEmpty) {
      _player.stop();
      _currentIndex = 0;
    } else if (index == _currentIndex) {
      // If removing current track, load the next one (or previous if at end)
      if (_currentIndex >= _playlist.length) {
        _currentIndex = _playlist.length - 1;
      }
      loadTrack(_currentIndex);
    } else if (index < _currentIndex) {
      // Adjust current index if removing track before current
      _currentIndex--;
    }

    notifyListeners();
  }

  void clearPlaylist() {
    _playlist.clear();
    _currentIndex = 0;
    _player.stop();
    notifyListeners();
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void dispose() {
    _player.dispose();
    _sleepTimer?.cancel();
    VolumeController.instance.removeListener(); // Clean up listener
    super.dispose();
  }
}
