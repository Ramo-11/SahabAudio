// services/storage_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/audio_track.dart';

class StorageService {
  static const String _playlistKey = 'saved_playlist';
  static const String _currentIndexKey = 'current_index';
  static const String _settingsKey = 'app_settings';

  static Future<void> savePlaylist(List<AudioTrack> playlist) async {
    final prefs = await SharedPreferences.getInstance();

    // We still check if files exist before saving, but we use the current path logic
    final validTracks = <AudioTrack>[];

    for (var track in playlist) {
      if (await File(track.path).exists()) {
        validTracks.add(track);
      }
    }

    final playlistJson = validTracks
        .map((track) => {
              'path': track.path, // We keep saving this for legacy reasons
              'fileName': track.fileName, // THIS is the key field
              'artist': track.artist,
              'album': track.album,
            })
        .toList();

    await prefs.setString(_playlistKey, jsonEncode(playlistJson));
  }

  static Future<List<AudioTrack>> loadPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    final playlistString = prefs.getString(_playlistKey);

    if (playlistString == null) return [];

    try {
      final List<dynamic> playlistJson = jsonDecode(playlistString);
      final tracks = <AudioTrack>[];

      // 1. Get the CURRENT valid documents directory
      // This gives us the NEW UUID path (e.g., .../2222-2222/Documents)
      final directory = await getApplicationDocumentsDirectory();
      final String basePath = directory.path;

      for (var trackJson in playlistJson) {
        // We rely on the filename, which doesn't change between updates
        String fileName = trackJson['fileName'] as String;

        // 2. Construct the dynamic path
        final String dynamicPath = '$basePath/$fileName';
        final File file = File(dynamicPath);

        // 3. Check if file exists at the NEW location
        if (await file.exists()) {
          tracks.add(AudioTrack(
            path: dynamicPath, // Use the NEW valid path
            fileName: fileName,
            artist: trackJson['artist'] as String?,
            album: trackJson['album'] as String?,
          ));
        } else {
          print("File not found at $dynamicPath");
        }
      }

      return tracks;
    } catch (e) {
      print('Error loading playlist: $e');
      return [];
    }
  }

  static Future<void> saveCurrentIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentIndexKey, index);
  }

  static Future<int> loadCurrentIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_currentIndexKey) ?? 0;
  }

  static Future<void> saveSettings({
    required double volume,
    required double speed,
    required bool isShuffleEnabled,
    required String loopMode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final settings = {
      'volume': volume,
      'speed': speed,
      'isShuffleEnabled': isShuffleEnabled,
      'loopMode': loopMode,
    };
    await prefs.setString(_settingsKey, jsonEncode(settings));
  }

  static Future<Map<String, dynamic>?> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsString = prefs.getString(_settingsKey);

    if (settingsString == null) return null;

    try {
      return jsonDecode(settingsString) as Map<String, dynamic>;
    } catch (e) {
      print('Error loading settings: $e');
      return null;
    }
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_playlistKey);
    await prefs.remove(_currentIndexKey);
    await prefs.remove(_settingsKey);
  }
}
