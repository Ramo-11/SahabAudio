class AudioTrack {
  String path;
  String _displayName;
  String? artist;
  String? album;
  Duration? duration;

  AudioTrack({
    required this.path,
    required String fileName,
    this.artist,
    this.album,
    this.duration,
  }) : _displayName = _cleanDisplayName(fileName);

  static String _cleanDisplayName(String name) {
    String clean = name;
    if (clean.contains('.')) {
      clean = clean.substring(0, clean.lastIndexOf('.'));
    }
    clean = clean.replaceAll('_', ' ');
    return clean.trim();
  }

  String get physicalFileName => path.split('/').last;

  String get displayName => _displayName;

  String get fileName => _displayName;

  String get artistAlbum =>
      '${artist ?? 'Unknown Artist'} • ${album ?? 'Unknown Album'}';

  void rename(String newName) {
    _displayName = newName.replaceAll(RegExp(r'\.[^.]*$'), '');
  }

  AudioTrack copyWith({
    String? path,
    String? fileName,
    String? artist,
    String? album,
    Duration? duration,
  }) {
    final track = AudioTrack(
      path: path ?? this.path,
      fileName: fileName ?? _displayName,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
    );
    if (fileName == null) {
      track._displayName = _displayName;
    }
    return track;
  }

  Map<String, dynamic> toJson() {
    return {
      'physicalFileName': physicalFileName,
      'displayName': _displayName,
      'artist': artist,
      'album': album,
    };
  }

  static AudioTrack fromJson(Map<String, dynamic> json, String basePath) {
    final physicalName = json['physicalFileName'] ?? json['fileName'] ?? '';
    final fullPath = '$basePath/$physicalName';

    final track = AudioTrack(
      path: fullPath,
      fileName: json['displayName'] ?? physicalName,
      artist: json['artist'],
      album: json['album'],
    );
    track._displayName = json['displayName'] ?? _cleanDisplayName(physicalName);
    return track;
  }
}
