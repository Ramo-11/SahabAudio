import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/audio_track.dart';

class StorageService {
  static const String _playlistKey = 'saved_playlist_v3';
  static const String _currentIndexKey = 'current_index';
  static const String _settingsKey = 'app_settings';

  static Future<String> get _documentsPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  static Future<void> savePlaylist(List<AudioTrack> playlist) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final basePath = await _documentsPath;

      final playlistJson = <Map<String, dynamic>>[];

      for (var track in playlist) {
        final physicalName = track.physicalFileName;
        final filePath = '$basePath/$physicalName';

        if (await File(filePath).exists()) {
          playlistJson.add({
            'physicalFileName': physicalName,
            'displayName': track.displayName,
            'artist': track.artist,
            'album': track.album,
          });
        } else {
          print('[StorageService] Skipping missing file: $physicalName');
        }
      }

      await prefs.setString(_playlistKey, jsonEncode(playlistJson));
      print('[StorageService] Saved ${playlistJson.length} tracks');
    } catch (e) {
      print('[StorageService] Error saving playlist: $e');
    }
  }

  static Future<List<AudioTrack>> loadPlaylist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final basePath = await _documentsPath;

      final playlistString = prefs.getString(_playlistKey);
      if (playlistString == null || playlistString.isEmpty) {
        print('[StorageService] No saved playlist found');
        return [];
      }

      final List<dynamic> playlistJson = jsonDecode(playlistString);
      final tracks = <AudioTrack>[];

      for (var json in playlistJson) {
        final physicalName = json['physicalFileName'] ?? json['fileName'] ?? '';
        if (physicalName.isEmpty) continue;

        final filePath = '$basePath/$physicalName';

        if (await File(filePath).exists()) {
          final track = AudioTrack.fromJson(
            json as Map<String, dynamic>,
            basePath,
          );
          tracks.add(track);
        } else {
          print('[StorageService] File not found on load: $physicalName');
        }
      }

      print('[StorageService] Loaded ${tracks.length} tracks');
      return tracks;
    } catch (e) {
      print('[StorageService] Error loading playlist: $e');
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
  }
}
