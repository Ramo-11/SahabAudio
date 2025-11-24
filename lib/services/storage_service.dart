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
  static const String _migrationKey = 'storage_migration_v2';

  // CRITICAL: Never save absolute paths - only save relative filenames
  static Future<void> savePlaylist(List<AudioTrack> playlist) async {
    final prefs = await SharedPreferences.getInstance();
    final directory = await getApplicationDocumentsDirectory();

    final playlistJson = <Map<String, dynamic>>[];

    for (var track in playlist) {
      // Get the physical filename on disk
      final physicalFileName = track.path.split('/').last;

      final filePath = '${directory.path}/$physicalFileName';

      // Only save if file actually exists
      if (await File(filePath).exists()) {
        playlistJson.add({
          'physicalFileName': physicalFileName, // The ugly system name
          'displayName': track
              .fileName, // The pretty user name (Track.fileName acts as display name in your model)
          'artist': track.artist,
          'album': track.album,
        });
      }
    }

    await prefs.setString(_playlistKey, jsonEncode(playlistJson));
  }

  static Future<List<AudioTrack>> loadPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    final directory = await getApplicationDocumentsDirectory();

    final playlistString = prefs.getString(_playlistKey);
    if (playlistString == null) return [];

    try {
      final List<dynamic> playlistJson = jsonDecode(playlistString);
      final tracks = <AudioTrack>[];

      for (var trackJson in playlistJson) {
        // Support both old format (migrated) and new format
        String physicalName;
        String visibleName;

        if (trackJson.containsKey('physicalFileName')) {
          // New Modern Format
          physicalName = trackJson['physicalFileName'];
          visibleName = trackJson['displayName'] ?? physicalName;
        } else {
          // Fallback for older data
          physicalName = trackJson['fileName'];
          visibleName = trackJson['displayName'] ?? physicalName;
        }

        final currentPath = '${directory.path}/$physicalName';

        if (await File(currentPath).exists()) {
          tracks.add(AudioTrack(
            path: currentPath,
            fileName: visibleName, // Load the PRETTY name into the model
            artist: trackJson['artist'],
            album: trackJson['album'],
          ));
        }
      }
      return tracks;
    } catch (e) {
      print('[StorageService] Error loading: $e');
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
      print('[StorageService] Error loading settings: $e');
      return null;
    }
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_playlistKey);
    await prefs.remove(_currentIndexKey);
    await prefs.remove(_settingsKey);
    await prefs.remove(_migrationKey);
  }

  // Utility method to recover orphaned files
  static Future<List<String>> findOrphanedAudioFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final orphanedFiles = <String>[];

    try {
      final files = await directory.list().toList();
      final audioExtensions = ['mp3', 'm4a', 'wav', 'flac', 'aac', 'mp4'];

      for (var file in files) {
        if (file is File) {
          final fileName = file.path.split('/').last;
          final extension = fileName.split('.').last.toLowerCase();

          if (audioExtensions.contains(extension)) {
            orphanedFiles.add(fileName);
          }
        }
      }
    } catch (e) {
      print('[StorageService] Error finding orphaned files: $e');
    }

    return orphanedFiles;
  }
}
