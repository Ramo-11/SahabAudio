class AudioTrack {
  String path;
  String fileName;
  String? artist;
  String? album;
  Duration? duration;

  AudioTrack({
    required this.path,
    required this.fileName,
    this.artist,
    this.album,
    this.duration,
  });

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
  }) {
    return AudioTrack(
      path: path ?? this.path,
      fileName: fileName ?? this.fileName,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
    );
  }
}
