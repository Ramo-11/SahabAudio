// services/storage_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audio_track.dart';

class StorageService {
  static const String _playlistKey = 'saved_playlist';
  static const String _currentIndexKey = 'current_index';
  static const String _settingsKey = 'app_settings';

  static Future<void> savePlaylist(List<AudioTrack> playlist) async {
    final prefs = await SharedPreferences.getInstance();

    // Only save tracks that still exist on disk
    final validTracks = <AudioTrack>[];
    for (var track in playlist) {
      if (await File(track.path).exists()) {
        validTracks.add(track);
      }
    }

    final playlistJson = validTracks
        .map((track) => {
              'path': track.path,
              'fileName': track.fileName,
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

      for (var trackJson in playlistJson) {
        final path = trackJson['path'] as String;
        // Only load tracks that still exist
        if (await File(path).exists()) {
          tracks.add(AudioTrack(
            path: path,
            fileName: trackJson['fileName'] as String,
            artist: trackJson['artist'] as String?,
            album: trackJson['album'] as String?,
          ));
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
