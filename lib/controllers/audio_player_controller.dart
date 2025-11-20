// controllers/audio_player_controller.dart
import 'package:audio_player_app/services/storage_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:audio_service/audio_service.dart';
import '../services/audio_handler.dart';
import 'dart:async';
import '../models/audio_track.dart';

class AudioPlayerController extends ChangeNotifier {
  final AudioHandler audioHandler;

  AudioPlayer get _player => (audioHandler as MyAudioHandler).player;

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

  AudioPlayerController(this.audioHandler) {
    _setupAudioPlayer();
    _setupSystemVolumeListener();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    try {
      // Load playlist
      final savedPlaylist = await StorageService.loadPlaylist();
      if (savedPlaylist.isNotEmpty) {
        _playlist = savedPlaylist;

        // Load current index
        final savedIndex = await StorageService.loadCurrentIndex();
        _currentIndex = savedIndex.clamp(0, _playlist.length - 1);

        // Load the current track
        await loadTrack(_currentIndex);
      }

      // Load settings
      final settings = await StorageService.loadSettings();
      if (settings != null) {
        _volume = settings['volume'] ?? 0.8;
        _speed = settings['speed'] ?? 1.0;
        _isShuffleEnabled = settings['isShuffleEnabled'] ?? false;

        final loopModeString = settings['loopMode'] ?? 'off';
        _loopMode = loopModeString == 'one'
            ? LoopMode.one
            : loopModeString == 'all'
                ? LoopMode.all
                : LoopMode.off;

        // Apply loaded settings
        _player.setVolume(_volume);
        _player.setSpeed(_speed);
        _player.setLoopMode(_loopMode);
      }

      notifyListeners();
    } catch (e) {
      print('Error loading saved data: $e');
    }
  }

  Future<String> _persistFile(String sourcePath, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final newPath = '${directory.path}/$fileName';

    if (sourcePath == newPath) return newPath;

    final file = File(sourcePath);
    if (!await file.exists()) return sourcePath;

    // Check if file already exists at destination to prevent overwriting/duplication errors
    final newFileObj = File(newPath);
    if (await newFileObj.exists()) {
      // Optional: Generate unique name if needed, or just return existing
      // For now, we return the path which fits the "Update" fix
      return newPath;
    }

    // Copy to app documents folder
    final newFile = await file.copy(newPath);
    return newFile.path;
  }

  Future<void> _saveData() async {
    try {
      await StorageService.savePlaylist(_playlist);
      await StorageService.saveCurrentIndex(_currentIndex);
      await StorageService.saveSettings(
        volume: _volume,
        speed: _speed,
        isShuffleEnabled: _isShuffleEnabled,
        loopMode: _loopMode.toString().split('.').last,
      );
    } catch (e) {
      print('Error saving data: $e');
    }
  }

  void _setupAudioPlayer() async {
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
      final List<AudioTrack> newTracks = [];

      for (final file in result.files) {
        if (file.path == null) continue;
        if (!_isAudioFile(file.name)) continue;

        final storedPath = await _persistFile(file.path!, file.name);

        newTracks.add(
          AudioTrack(
            path: storedPath,
            fileName: file.name,
            artist: 'Unknown Artist',
            album: 'Unknown Album',
          ),
        );
      }

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

    try {
      // Only pick videos (which includes audio files)
      final XFile? file = await picker.pickVideo(source: ImageSource.gallery);

      if (file != null) {
        // Generate a better filename
        final String fileName = _generateBetterFileName(file.name);

        final savedPath = await _persistFile(file.path, fileName);

        final newTrack = AudioTrack(
          path: savedPath,
          fileName: fileName,
          artist: 'Photos',
          album: 'Media Library',
        );

        _playlist.add(newTrack);
        if (_playlist.length == 1) {
          _currentIndex = 0;
          await loadTrack(0);
        }
        notifyListeners();
      }
    } catch (e) {
      print('Error picking from photos: $e');
    }
  }

  String _generateBetterFileName(String originalName) {
    // If it starts with image_picker, generate a better name
    if (originalName.startsWith('image_picker')) {
      final now = DateTime.now();
      return 'Audio_${now.month}${now.day}_${now.hour}${now.minute}.m4a';
    }
    return originalName;
  }

  void renameTrack(int index, String newName) {
    if (index >= 0 && index < _playlist.length) {
      final extension = _playlist[index].fileName.split('.').last;
      _playlist[index].rename('$newName.$extension');

      _saveData();

      notifyListeners();
    }
  }

  Future<void> addSharedFile(String filePath) async {
    try {
      print('Attempting to add shared file: $filePath');

      final fileName = filePath.split('/').last;

      if (_isAudioFile(fileName)) {
        final original = File(filePath);
        if (!await original.exists()) return;

        final dir = await getApplicationDocumentsDirectory();
        final ts = DateTime.now().millisecondsSinceEpoch;
        final ext = fileName.split('.').last;
        final base = fileName.split('.').first;

        final uniqueName = '${base}_$ts.$ext';
        final uniquePath = '${dir.path}/$uniqueName';

        // *** THIS is the real fix ***
        final copied = await original.copy(uniquePath);

        final newTrack = AudioTrack(
          path: copied.path,
          fileName: uniqueName,
          artist: 'Voice Memo',
          album: 'Shared',
        );

        _playlist.add(newTrack);

        if (_playlist.length == 1) {
          _currentIndex = 0;
          await loadTrack(0);
        }

        notifyListeners();
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

      Duration? trackDuration = track.duration;
      if (trackDuration == null) {
        try {
          await _player.setAudioSource(AudioSource.uri(Uri.file(track.path)));
          trackDuration = _player.duration;
        } catch (e) {
          print('Could not get duration: $e');
        }
      }

      await _player.setAudioSource(
        AudioSource.uri(
          Uri.file(track.path),
        ),
      );

      final myHandler = audioHandler as MyAudioHandler;
      myHandler.updateMetadata(MediaItem(
        id: track.path,
        title: track.displayName,
        artist: track.artist ?? 'Unknown',
        album: track.album ?? 'Sahab Audio',
        duration: trackDuration,
        artUri:
            null, // You can add Uri.file(path_to_image) if you have album art
      ));

      notifyListeners();
      _saveData();
    } catch (e) {
      print('Error loading audio: $e');
    }
  }

  Future<void> play() async {
    await _player.play();
    notifyListeners();
  }

  Future<void> pause() async {
    await _player.pause();
    notifyListeners();
  }

  void addTrack(AudioTrack track) {
    _playlist.add(track);

    // If this is the first track, load it
    if (_playlist.length == 1) {
      _currentIndex = 0;
      loadTrack(0);
    }

    notifyListeners();
    _saveData();
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
    _saveData();
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
    _saveData();
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
    _saveData();
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
    _saveData();
  }

  void clearPlaylist() {
    _playlist.clear();
    _currentIndex = 0;
    _player.stop();
    notifyListeners();
    _saveData();
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
    VolumeController.instance.removeListener();
  }
}
