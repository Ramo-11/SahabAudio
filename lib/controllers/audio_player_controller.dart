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

  List<AudioTrack> _playlist = [];
  int _currentIndex = 0;
  double _speed = 1.0;
  bool _isShuffleEnabled = false;
  LoopMode _loopMode = LoopMode.off;
  double _volume = 0.8;
  Timer? _sleepTimer;
  Duration? _sleepDuration;
  bool _isLoading = true;

  AudioPlayer get player => _player;
  List<AudioTrack> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  AudioTrack? get currentTrack =>
      _playlist.isNotEmpty && _currentIndex < _playlist.length
          ? _playlist[_currentIndex]
          : null;
  double get speed => _speed;
  bool get isShuffleEnabled => _isShuffleEnabled;
  LoopMode get loopMode => _loopMode;
  double get volume => _volume;
  Duration? get sleepDuration => _sleepDuration;
  bool get isLoading => _isLoading;

  AudioPlayerController(this.audioHandler) {
    _init();
  }

  Future<void> _init() async {
    _setupAudioPlayer();
    _setupSystemVolumeListener();
    await _loadSavedData();
  }

  Future<String> get _documentsPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<void> _loadSavedData() async {
    try {
      _isLoading = true;
      notifyListeners();

      final savedPlaylist = await StorageService.loadPlaylist();

      if (savedPlaylist.isNotEmpty) {
        _playlist = savedPlaylist;

        final savedIndex = await StorageService.loadCurrentIndex();
        _currentIndex = savedIndex.clamp(0, _playlist.length - 1);

        await loadTrack(_currentIndex, autoPlay: false);
      }

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

        _player.setVolume(_volume);
        _player.setSpeed(_speed);
        _player.setLoopMode(_loopMode);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('[Controller] Error loading saved data: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> _copyToDocuments(String sourcePath, String desiredName) async {
    try {
      final basePath = await _documentsPath;
      final sourceFile = File(sourcePath);

      if (!await sourceFile.exists()) {
        throw Exception('Source file does not exist');
      }

      final ext = desiredName.split('.').last;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueName = 'audio_$timestamp.$ext';
      final destPath = '$basePath/$uniqueName';

      await sourceFile.copy(destPath);
      print('[Controller] Copied file to: $uniqueName');

      return destPath;
    } catch (e) {
      print('[Controller] Error copying file: $e');
      return sourcePath;
    }
  }

  Future<void> saveData() async {
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
      print('[Controller] Error saving data: $e');
    }
  }

  void _setupAudioPlayer() {
    _player.setVolume(_volume);

    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _handleAudioCompleted();
      }
    });
  }

  void _setupSystemVolumeListener() {
    VolumeController.instance.showSystemUI = false;

    VolumeController.instance.addListener((volume) {
      if ((volume - _volume).abs() > 0.01) {
        _volume = volume;
        _player.setVolume(volume);
        notifyListeners();
      }
    }, fetchInitialVolume: true);
  }

  void _handleAudioCompleted() {
    if (_loopMode == LoopMode.one) {
      _player.seek(Duration.zero);
      _player.play();
    } else if (_loopMode == LoopMode.all ||
        _currentIndex < _playlist.length - 1) {
      playNext();
    } else {
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
      for (final file in result.files) {
        if (file.path == null) continue;
        if (!_isAudioFile(file.name)) continue;

        final storedPath = await _copyToDocuments(file.path!, file.name);

        _playlist.add(AudioTrack(
          path: storedPath,
          fileName: file.name,
          artist: 'Unknown Artist',
          album: 'Unknown Album',
        ));
      }

      if (_playlist.length == result.files.length) {
        _currentIndex = 0;
        await loadTrack(0);
      }

      await saveData();
      notifyListeners();
    }
  }

  Future<void> pickFromPhotos() async {
    final ImagePicker picker = ImagePicker();

    try {
      final XFile? file = await picker.pickVideo(source: ImageSource.gallery);

      if (file != null) {
        final ext = file.name.split('.').last;
        final now = DateTime.now();
        final displayName =
            'Audio ${now.month}/${now.day} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

        final storedPath = await _copyToDocuments(file.path, 'audio.$ext');

        final track = AudioTrack(
          path: storedPath,
          fileName: displayName,
          artist: 'Photos',
          album: 'Media Library',
        );

        _playlist.add(track);

        if (_playlist.length == 1) {
          _currentIndex = 0;
          await loadTrack(0);
        }

        await saveData();
        notifyListeners();
      }
    } catch (e) {
      print('[Controller] Error picking from photos: $e');
    }
  }

  Future<void> addSharedFile(String filePath) async {
    try {
      print('[Controller] Processing shared file: $filePath');

      final originalFile = File(filePath);
      if (!await originalFile.exists()) {
        print('[Controller] Shared file does not exist');
        return;
      }

      final fileName = filePath.split('/').last;
      if (!_isAudioFile(fileName)) {
        print('[Controller] Not an audio file: $fileName');
        return;
      }

      final storedPath = await _copyToDocuments(filePath, fileName);

      final now = DateTime.now();
      final displayName =
          'Voice Memo ${now.month}/${now.day} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

      final track = AudioTrack(
        path: storedPath,
        fileName: displayName,
        artist: 'Voice Memo',
        album: 'Shared',
      );

      _playlist.add(track);

      if (_playlist.length == 1) {
        _currentIndex = 0;
        await loadTrack(0);
      }

      await saveData();
      notifyListeners();

      print('[Controller] Successfully added shared file');
    } catch (e) {
      print('[Controller] Error adding shared file: $e');
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

  Future<void> loadTrack(int index, {bool autoPlay = false}) async {
    if (index < 0 || index >= _playlist.length) return;

    try {
      _currentIndex = index;
      final track = _playlist[index];

      final file = File(track.path);
      if (!await file.exists()) {
        print('[Controller] File not found: ${track.path}');
        _playlist.removeAt(index);
        if (_currentIndex >= _playlist.length) {
          _currentIndex = _playlist.length > 0 ? _playlist.length - 1 : 0;
        }
        await saveData();
        notifyListeners();
        return;
      }

      await _player.setAudioSource(AudioSource.uri(Uri.file(track.path)));

      // -----------------------------
      // REQUIRED FOR LOCK SCREEN
      // -----------------------------
      final myHandler = audioHandler as MyAudioHandler;

      final mediaItem = MediaItem(
        id: track.path,
        title: track.displayName,
        artist: track.artist ?? 'Unknown',
        album: track.album ?? 'Sahab Audio',
        duration: _player.duration,
        artUri: null,
      );

      // Update queue (iOS lock screen requires a queue)
      myHandler.queue.add([mediaItem]);

      // Update currently playing metadata
      myHandler.mediaItem.add(mediaItem);
      // -----------------------------

      if (autoPlay) {
        await _player.play();
      }

      notifyListeners();
      await saveData();
    } catch (e) {
      print('[Controller] Error loading track: $e');
      _playlist.removeAt(index);
      if (_currentIndex >= _playlist.length) {
        _currentIndex = _playlist.length > 0 ? _playlist.length - 1 : 0;
      }
      await saveData();
      notifyListeners();
    }
  }

  void renameTrack(int index, String newName) {
    if (index >= 0 && index < _playlist.length) {
      _playlist[index].rename(newName);
      saveData();
      notifyListeners();
    }
  }

  Future<void> replaceTrackWithEditedFile(
      int index, String editedTempPath) async {
    if (index < 0 || index >= _playlist.length) return;

    try {
      print('[Controller] Replacing track at index $index');

      if (_currentIndex == index && _player.playing) {
        await _player.stop();
      }

      final oldTrack = _playlist[index];
      final basePath = await _documentsPath;

      final ext = editedTempPath.split('.').last;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newPhysicalName = 'edited_$timestamp.$ext';
      final newPath = '$basePath/$newPhysicalName';

      final editedFile = File(editedTempPath);
      if (!await editedFile.exists()) {
        throw Exception('Edited file not found');
      }

      await editedFile.copy(newPath);

      final newTrack = AudioTrack(
        path: newPath,
        fileName: oldTrack.displayName,
        artist: oldTrack.artist,
        album: oldTrack.album,
      );

      _playlist[index] = newTrack;
      await saveData();

      if (index == _currentIndex) {
        await loadTrack(index);
      }

      final oldFile = File(oldTrack.path);
      if (await oldFile.exists() && oldTrack.path != newPath) {
        try {
          await oldFile.delete();
        } catch (e) {
          print('[Controller] Could not delete old file: $e');
        }
      }

      notifyListeners();
      print('[Controller] Track replaced successfully');
    } catch (e) {
      print('[Controller] Error replacing track: $e');
      rethrow;
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

    if (_playlist.length == 1) {
      _currentIndex = 0;
      loadTrack(0);
    }

    saveData();
    notifyListeners();
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

    await loadTrack(nextIndex, autoPlay: true);
  }

  Future<void> playPrevious() async {
    if (_playlist.isEmpty) return;

    final previousIndex =
        (_currentIndex - 1 + _playlist.length) % _playlist.length;
    await loadTrack(previousIndex, autoPlay: true);
  }

  void toggleShuffle() {
    _isShuffleEnabled = !_isShuffleEnabled;
    notifyListeners();
    saveData();
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
    saveData();
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
      print('[Controller] Error setting system volume: $e');
    }
    notifyListeners();
    saveData();
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
      if (_currentIndex >= _playlist.length) {
        _currentIndex = _playlist.length - 1;
      }
      loadTrack(_currentIndex);
    } else if (index < _currentIndex) {
      _currentIndex--;
    }

    saveData();
    notifyListeners();
  }

  void clearPlaylist() {
    _playlist.clear();
    _currentIndex = 0;
    _player.stop();
    saveData();
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
    VolumeController.instance.removeListener();
    super.dispose();
  }
}
