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
      // Extract just the filename from the full path
      final fileName = track.path.split('/').last;

      // Verify file still exists before saving
      final filePath = '${directory.path}/$fileName';
      if (await File(filePath).exists()) {
        playlistJson.add({
          // NEVER save the full path - only the filename
          'fileName': fileName,
          'displayName': track.fileName, // Keep the display name separate
          'artist': track.artist,
          'album': track.album,
        });
      }
    }

    await prefs.setString(_playlistKey, jsonEncode(playlistJson));
    print(
        '[StorageService] Saved ${playlistJson.length} tracks to persistent storage');
  }

  static Future<List<AudioTrack>> loadPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    final directory = await getApplicationDocumentsDirectory();

    // First, attempt migration if needed
    await _migrateOldPlaylistIfNeeded();

    final playlistString = prefs.getString(_playlistKey);
    if (playlistString == null) {
      print('[StorageService] No saved playlist found');
      return [];
    }

    try {
      final List<dynamic> playlistJson = jsonDecode(playlistString);
      final tracks = <AudioTrack>[];
      final missingFiles = <String>[];

      for (var trackJson in playlistJson) {
        // Get the filename (not path!)
        final String fileName = trackJson['fileName'] as String;
        final String displayName = trackJson['displayName'] ?? fileName;

        // Build the current valid path
        final String currentPath = '${directory.path}/$fileName';
        final File file = File(currentPath);

        if (await file.exists()) {
          tracks.add(AudioTrack(
            path: currentPath,
            fileName: displayName,
            artist: trackJson['artist'] as String?,
            album: trackJson['album'] as String?,
          ));
        } else {
          missingFiles.add(fileName);
          print('[StorageService] Warning: File not found: $fileName');
        }
      }

      if (missingFiles.isNotEmpty) {
        print('[StorageService] Missing files: ${missingFiles.join(', ')}');
        // Optionally, clean up the playlist to remove missing files
        await savePlaylist(tracks);
      }

      print('[StorageService] Loaded ${tracks.length} tracks from storage');
      return tracks;
    } catch (e) {
      print('[StorageService] Error loading playlist: $e');
      return [];
    }
  }

  // Migration method to fix any existing playlists with full paths
  static Future<void> _migrateOldPlaylistIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if we've already migrated
    final hasMigrated = prefs.getBool(_migrationKey) ?? false;
    if (hasMigrated) return;

    final playlistString = prefs.getString(_playlistKey);
    if (playlistString == null) {
      // No playlist to migrate
      await prefs.setBool(_migrationKey, true);
      return;
    }

    try {
      print('[StorageService] Starting migration of old playlist format...');
      final List<dynamic> oldPlaylistJson = jsonDecode(playlistString);
      final directory = await getApplicationDocumentsDirectory();
      final newPlaylistJson = <Map<String, dynamic>>[];

      for (var trackJson in oldPlaylistJson) {
        String fileName = '';

        // Handle old format with 'path' field
        if (trackJson.containsKey('path') && trackJson['path'] != null) {
          // Extract filename from the old full path
          final String oldPath = trackJson['path'] as String;
          fileName = oldPath.split('/').last;
        } else if (trackJson.containsKey('fileName')) {
          // Already has fileName, might be partially migrated
          fileName = trackJson['fileName'] as String;
        }

        if (fileName.isNotEmpty) {
          // Check if file exists in current documents directory
          final currentPath = '${directory.path}/$fileName';
          if (await File(currentPath).exists()) {
            newPlaylistJson.add({
              'fileName': fileName,
              'displayName': trackJson['fileName'] ?? fileName,
              'artist': trackJson['artist'],
              'album': trackJson['album'],
            });
          } else {
            print(
                '[StorageService] Migration: File not found during migration: $fileName');
          }
        }
      }

      // Save migrated playlist
      await prefs.setString(_playlistKey, jsonEncode(newPlaylistJson));
      await prefs.setBool(_migrationKey, true);

      print(
          '[StorageService] Migration complete. Migrated ${newPlaylistJson.length} tracks');
    } catch (e) {
      print('[StorageService] Migration failed: $e');
      // Don't mark as migrated so we can try again next time
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
