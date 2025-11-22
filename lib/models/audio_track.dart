class AudioTrack {
  String path;
  String fileName;
  String? artist;
  String? album;
  Duration? duration;
  String? originalFileName; // NEW: Track the original base name
  int? versionTimestamp; // NEW: Track version for edited files

  AudioTrack({
    required this.path,
    required this.fileName,
    this.artist,
    this.album,
    this.duration,
    this.originalFileName,
    this.versionTimestamp,
  });

  // NEW: Get base name without version suffix
  String get baseFileName {
    if (originalFileName != null) return originalFileName!;

    // Extract base name by removing version suffix if present
    final match = RegExp(r'^(.+?)_v\d+(\.\w+)$').firstMatch(fileName);
    if (match != null) {
      return '${match.group(1)}${match.group(2)}';
    }
    return fileName;
  }

  String get displayName => fileName.replaceAll(RegExp(r'\.[^.]*$'), '');
  String get artistAlbum =>
      '${artist ?? 'Unknown Artist'} • ${album ?? 'Unknown Album'}';

  void rename(String newName) {
    fileName = newName;
  }

  AudioTrack copyWith({
    String? path,
    String? fileName,
    String? artist,
    String? album,
    Duration? duration,
    String? originalFileName,
    int? versionTimestamp,
  }) {
    return AudioTrack(
      path: path ?? this.path,
      fileName: fileName ?? this.fileName,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      originalFileName: originalFileName ?? this.originalFileName,
      versionTimestamp: versionTimestamp ?? this.versionTimestamp,
    );
  }

  // NEW: Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'fileName': path.split('/').last, // Store only filename
      'displayName': fileName,
      'artist': artist,
      'album': album,
      'originalFileName': originalFileName,
      'versionTimestamp': versionTimestamp,
    };
  }

  // NEW: Create from JSON
  static AudioTrack fromJson(Map<String, dynamic> json, String fullPath) {
    return AudioTrack(
      path: fullPath,
      fileName: json['displayName'] ?? json['fileName'],
      artist: json['artist'],
      album: json['album'],
      originalFileName: json['originalFileName'],
      versionTimestamp: json['versionTimestamp'],
    );
  }
}
