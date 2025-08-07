class AudioTrack {
  final String path;
  String fileName;
  final String? artist;
  final String? album;
  final Duration? duration;

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

  // Add rename method
  void rename(String newName) {
    fileName = newName;
  }
}
