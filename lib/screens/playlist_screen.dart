// screens/playlist_screen.dart
import 'package:flutter/material.dart';
import '../controllers/audio_player_controller.dart';
import '../models/audio_track.dart';

class PlaylistScreen extends StatelessWidget {
  final AudioPlayerController controller;

  const PlaylistScreen({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: Text(
              'Playlist (${controller.playlist.length} tracks)',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.transparent,
            iconTheme: IconThemeData(color: Colors.white),
            actions: [
              if (controller.playlist.isNotEmpty)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) {
                    switch (value) {
                      case 'clear_all':
                        _showClearPlaylistDialog(context);
                        break;
                      case 'add_files':
                        _showFileSourceOptions(context);
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem(
                      value: 'add_files',
                      child: Row(
                        children: [
                          Icon(Icons.add, color: Colors.white70),
                          SizedBox(width: 8),
                          Text('Add More Files'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'clear_all',
                      child: Row(
                        children: [
                          Icon(Icons.clear_all, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Clear Playlist',
                              style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.deepPurple.shade900.withOpacity(0.3),
                  Colors.black,
                  Colors.indigo.shade900.withOpacity(0.2),
                ],
              ),
            ),
            child: controller.playlist.isEmpty
                ? _buildEmptyPlaylist(context)
                : _buildPlaylist(context),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showFileSourceOptions(context),
            backgroundColor: Colors.deepPurpleAccent,
            child: Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _buildEmptyPlaylist(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.queue_music,
            size: 80,
            color: Colors.white54,
          ),
          SizedBox(height: 20),
          Text(
            'No tracks in playlist',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Add some audio files to get started',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () => _showFileSourceOptions(context),
            icon: Icon(Icons.library_music),
            label: Text('Add Audio Files'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurpleAccent,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylist(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: controller.playlist.length,
      itemBuilder: (context, index) {
        final track = controller.playlist[index];
        final isCurrentTrack = index == controller.currentIndex;

        return AnimatedContainer(
          duration: Duration(milliseconds: 300),
          margin: EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isCurrentTrack
                ? Colors.deepPurpleAccent.withOpacity(0.2)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: isCurrentTrack
                ? Border.all(color: Colors.deepPurpleAccent, width: 1)
                : null,
          ),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isCurrentTrack
                    ? Colors.deepPurpleAccent
                    : Colors.deepPurple.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isCurrentTrack ? Icons.music_note : Icons.audio_file,
                color: Colors.white,
                size: isCurrentTrack ? 28 : 24,
              ),
            ),
            title: Text(
              track.displayName,
              style: TextStyle(
                color: isCurrentTrack ? Colors.white : Colors.white70,
                fontWeight:
                    isCurrentTrack ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              track.artistAlbum,
              style: TextStyle(
                color: isCurrentTrack ? Colors.white70 : Colors.white60,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCurrentTrack)
                  StreamBuilder(
                    stream: controller.player.playerStateStream,
                    builder: (context, snapshot) {
                      final isPlaying = snapshot.data?.playing ?? false;
                      return Icon(
                        isPlaying ? Icons.volume_up : Icons.pause,
                        color: Colors.deepPurpleAccent,
                        size: 20,
                      );
                    },
                  ),
                SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: Colors.white70,
                    size: 20,
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'play':
                        controller.loadTrack(index);
                        controller.player.play();
                        break;
                      case 'rename':
                        _showRenameDialog(context, index, track);
                        break;
                      case 'remove':
                        _showRemoveTrackDialog(context, index, track);
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem(
                      value: 'play',
                      child: Row(
                        children: [
                          Icon(Icons.play_arrow,
                              color: Colors.white70, size: 20),
                          SizedBox(width: 8),
                          Text('Play', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.white70, size: 20),
                          SizedBox(width: 8),
                          Text('Rename', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Remove',
                              style:
                                  TextStyle(color: Colors.red, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            onTap: () {
              controller.loadTrack(index);
              controller.player.play();
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }

  void _showFileSourceOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose Audio Source',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),

              // Files App
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.folder, color: Colors.blue),
                ),
                title: Text('Files App', style: TextStyle(color: Colors.white)),
                subtitle: Text('Browse files and folders',
                    style: TextStyle(color: Colors.white70)),
                onTap: () {
                  Navigator.pop(context);
                  controller.pickAudioFiles();
                },
              ),

              // Photos App
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.photo_library, color: Colors.green),
                ),
                title: Text('Photos', style: TextStyle(color: Colors.white)),
                subtitle: Text('Audio files from Photos app',
                    style: TextStyle(color: Colors.white70)),
                onTap: () {
                  Navigator.pop(context);
                  controller.pickFromPhotos();
                },
              ),

              SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context, int index, AudioTrack track) {
    final TextEditingController controller =
        TextEditingController(text: track.displayName);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title:
              const Text('Rename Track', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter new name',
              hintStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.deepPurpleAccent),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.deepPurpleAccent),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  this.controller.renameTrack(index, controller.text.trim());
                  Navigator.pop(context);
                }
              },
              child: const Text('Save',
                  style: TextStyle(color: Colors.deepPurpleAccent)),
            ),
          ],
        );
      },
    );
  }

  void _showRemoveTrackDialog(
      BuildContext context, int index, AudioTrack track) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: Text('Remove Track', style: TextStyle(color: Colors.white)),
          content: Text(
            'Remove "${track.displayName}" from playlist?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                controller.removeTrack(index);
                Navigator.pop(context);
              },
              child: Text('Remove', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showClearPlaylistDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: Text('Clear Playlist', style: TextStyle(color: Colors.white)),
          content: Text(
            'Remove all tracks from playlist?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                controller.clearPlaylist();
                Navigator.pop(context);
              },
              child: Text('Clear All', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
