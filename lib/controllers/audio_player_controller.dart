// controllers/audio_player_controller.dart - ENHANCED VERSION
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
      // First, recover any orphaned files
      // await _recoverOrphanedFiles();

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
      print('[AudioPlayerController] Error loading saved data: $e');
    }
  }

  // NEW: Recover orphaned files that aren't in the playlist
  Future<void> _recoverOrphanedFiles() async {
    try {
      print('[AudioPlayerController] Checking for orphaned audio files...');

      final orphanedFileNames = await StorageService.findOrphanedAudioFiles();
      if (orphanedFileNames.isEmpty) {
        print('[AudioPlayerController] No orphaned files found');
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final currentPlaylist = await StorageService.loadPlaylist();

      // Get list of filenames already in playlist
      final playlistFileNames =
          currentPlaylist.map((track) => track.path.split('/').last).toSet();

      int recoveredCount = 0;
      for (var fileName in orphanedFileNames) {
        // Skip if already in playlist
        if (playlistFileNames.contains(fileName)) continue;

        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);

        if (await file.exists()) {
          // Add to playlist as recovered file
          final track = AudioTrack(
            path: filePath,
            fileName: fileName,
            artist: 'Recovered',
            album: 'Auto-recovered files',
          );

          _playlist.add(track);
          recoveredCount++;
          print('[AudioPlayerController] Recovered file: $fileName');
        }
      }

      if (recoveredCount > 0) {
        await saveData();
        print(
            '[AudioPlayerController] Recovered $recoveredCount orphaned files');
      }
    } catch (e) {
      print('[AudioPlayerController] Error recovering orphaned files: $e');
    }
  }

  // CRITICAL FIX: Always use filename-based persistence
  Future<String> _persistFile(String sourcePath, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();

      // Clean the filename to ensure it's valid
      final cleanFileName = _sanitizeFileName(fileName);
      final newPath = '${directory.path}/$cleanFileName';

      // If source and destination are the same, just return
      if (sourcePath == newPath) {
        print(
            '[AudioPlayerController] File already in correct location: $cleanFileName');
        return newPath;
      }

      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        print(
            '[AudioPlayerController] Source file does not exist: $sourcePath');
        return sourcePath;
      }

      // Check if destination file already exists
      final destFile = File(newPath);
      if (await destFile.exists()) {
        // Generate unique name to avoid overwriting
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final ext = cleanFileName.split('.').last;
        final baseName =
            cleanFileName.substring(0, cleanFileName.lastIndexOf('.'));
        final uniquePath = '${directory.path}/${baseName}_$timestamp.$ext';

        print(
            '[AudioPlayerController] File exists, creating unique copy: ${uniquePath.split('/').last}');
        final newFile = await sourceFile.copy(uniquePath);
        return newFile.path;
      }

      // Copy to app documents folder
      print(
          '[AudioPlayerController] Copying file to documents: $cleanFileName');
      final newFile = await sourceFile.copy(newPath);
      return newFile.path;
    } catch (e) {
      print('[AudioPlayerController] Error persisting file: $e');
      return sourcePath; // Return original path if copy fails
    }
  }

  // Helper to sanitize filenames
  String _sanitizeFileName(String fileName) {
    // Remove invalid characters and ensure proper extension
    return fileName
        .replaceAll(RegExp(r'[^\w\s\-\.]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
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
      print('[AudioPlayerController] Data saved successfully');
    } catch (e) {
      print('[AudioPlayerController] Error saving data: $e');
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

      await saveData();
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

        await saveData();
        notifyListeners();
      }
    } catch (e) {
      print('[AudioPlayerController] Error picking from photos: $e');
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

      saveData();
      notifyListeners();
    }
  }

  Future<void> addSharedFile(String filePath) async {
    try {
      print('[AudioPlayerController] Processing shared file...');

      final originalFile = File(filePath);
      if (!await originalFile.exists()) return;

      final dir = await getApplicationDocumentsDirectory();

      // 1. Determine Display Name (Clean)
      // If file is "My_Song_2023_v2.mp3", display name becomes "My Song 2023 v2"
      String rawName = filePath.split('/').last;
      String displayName = rawName;
      if (rawName.contains('.')) {
        displayName = rawName.substring(0, rawName.lastIndexOf('.'));
      }
      // Remove underscores for prettiness
      displayName = displayName.replaceAll('_', ' ');

      // 2. Determine Physical Name (Safe)
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = rawName.split('.').last;
      final uniquePhysicalName = 'shared_$timestamp.$extension';
      final uniquePath = '${dir.path}/$uniquePhysicalName';

      // 3. Copy
      await originalFile.copy(uniquePath);

      // 4. Add to Playlist
      final newTrack = AudioTrack(
        path: uniquePath,
        fileName: displayName, // Use the CLEAN name for display
        artist: 'Shared Audio',
        album: 'Imports',
      );

      _playlist.add(newTrack);

      if (_playlist.length == 1) {
        _currentIndex = 0;
        await loadTrack(0);
      }

      await saveData();
      notifyListeners();
    } catch (e) {
      print('[AudioPlayerController] Error adding shared file: $e');
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

      // Verify file exists before loading
      final file = File(track.path);
      if (!await file.exists()) {
        print('[AudioPlayerController] WARNING: File not found: ${track.path}');
        // Try to recover by rebuilding path
        final directory = await getApplicationDocumentsDirectory();
        final fileName = track.path.split('/').last;
        final recoveredPath = '${directory.path}/$fileName';

        if (await File(recoveredPath).exists()) {
          print('[AudioPlayerController] File recovered at: $recoveredPath');
          track.path = recoveredPath; // Update the track path
          saveData(); // Save the corrected path
        } else {
          print('[AudioPlayerController] Could not recover file');
          throw Exception('File not found and could not be recovered');
        }
      }

      Duration? trackDuration = track.duration;
      if (trackDuration == null) {
        try {
          await _player.setAudioSource(AudioSource.uri(Uri.file(track.path)));
          trackDuration = _player.duration;
        } catch (e) {
          print('[AudioPlayerController] Could not get duration: $e');
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
        artUri: null,
      ));

      notifyListeners();
      saveData();
    } catch (e) {
      print('[AudioPlayerController] Error loading audio: $e');
      // Remove invalid track from playlist
      _playlist.removeAt(index);
      if (_currentIndex >= _playlist.length) {
        _currentIndex = _playlist.length > 0 ? _playlist.length - 1 : 0;
      }
      saveData();
      notifyListeners();
    }
  }

  // Rest of the methods remain the same...
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
      print('[AudioPlayerController] Error setting system volume: $e');
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
      // If removing current track, load the next one (or previous if at end)
      if (_currentIndex >= _playlist.length) {
        _currentIndex = _playlist.length - 1;
      }
      loadTrack(_currentIndex);
    } else if (index < _currentIndex) {
      // Adjust current index if removing track before current
      _currentIndex--;
    }

    saveData();
    notifyListeners();
  }

  /// safely replaces a track with an edited version without data loss
  Future<void> replaceTrackWithEditedFile(
      int index, String editedTempPath) async {
    if (index < 0 || index >= _playlist.length) return;

    try {
      print('[AudioPlayerController] Starting safe file replacement...');

      // 1. Stop playback to release locks
      if (_currentIndex == index || _player.playing) {
        await _player.stop();
      }

      final oldTrack = _playlist[index];
      final directory = await getApplicationDocumentsDirectory();

      // 2. Generate PHYSICAL Filename (Hidden from user)
      // We MUST use a timestamp here to guarantee the OS doesn't lock the file.
      // But the user will never see this string.
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Get the extension (m4a, mp3, etc)
      final extension = editedTempPath.split('.').last;

      // Create a system-level unique name
      // e.g. "audio_file_1715002938.m4a"
      final newPhysicalName = 'audio_${timestamp}.$extension';
      final newPath = '${directory.path}/$newPhysicalName';

      // 3. Move the edited temp file to permanent storage
      final editedFile = File(editedTempPath);
      if (!await editedFile.exists()) {
        throw Exception('Edited source file not found');
      }

      await editedFile.copy(newPath);
      print('[AudioPlayerController] Saved physical file: $newPhysicalName');

      // 4. Create the New Track Object
      // CRITICAL: We preserve oldTrack.displayName here!
      final newTrack = AudioTrack(
        path: newPath,
        fileName: oldTrack.displayName, // KEEP THE OLD CLEAN NAME
        artist: oldTrack.artist,
        album: oldTrack.album,
      );

      // 5. Update Playlist & Save
      _playlist[index] = newTrack;
      await saveData();

      // 6. Reload Player
      if (index == _currentIndex) {
        await loadTrack(index);
      }

      // 7. Cleanup Old File
      // We run this *after* everything is safe.
      if (oldTrack.path != newPath) {
        _safelyDeleteFile(oldTrack.path);
      }

      notifyListeners();
    } catch (e) {
      print('[AudioPlayerController] Error replacing file: $e');
      throw e;
    }
  }

  Future<void> _safelyDeleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        print('[AudioPlayerController] Old file deleted successfully');
      }
    } catch (e) {
      print(
          '[AudioPlayerController] Note: Could not delete old file immediately (OS Lock). This is normal.');
      // We do NOT throw an error here. We let the file sit.
      // It is better to have a tiny waste of space than a crash.
    }
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
  }
}
