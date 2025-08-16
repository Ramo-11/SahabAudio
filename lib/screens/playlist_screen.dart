// screens/playlist_screen.dart
import 'package:flutter/material.dart';
import '../controllers/audio_player_controller.dart';
import '../models/audio_track.dart';
import './audio_edit_screen.dart';
import './audio_player_screen.dart';
import 'recording_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

// Simple folder model
class PlaylistFolder {
  String id;
  String name;
  List<AudioTrack> tracks;
  bool isExpanded;

  PlaylistFolder({
    required this.id,
    required this.name,
    List<AudioTrack>? tracks,
    this.isExpanded = true,
  }) : tracks = tracks ?? [];
}

class PlaylistScreen extends StatefulWidget {
  final AudioPlayerController controller;

  const PlaylistScreen({Key? key, required this.controller}) : super(key: key);

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  // Folder management
  List<PlaylistFolder> folders = [];
  List<AudioTrack> unfolderedTracks = [];

  @override
  void initState() {
    super.initState();
    _initializeFolders();
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) {
      _syncTracksWithController();
    }
  }

  void _initializeFolders() {
    // Initialize with current tracks from controller
    unfolderedTracks = List.from(widget.controller.playlist);
  }

  void _syncTracksWithController() {
    // Get all tracks currently in folders
    Set<String> folderedTrackPaths = {};
    for (var folder in folders) {
      for (var track in folder.tracks) {
        folderedTrackPaths.add(track.path);
      }
    }

    // Get all tracks that should be in unfolderedTracks (not in any folder)
    List<AudioTrack> controllerTracks = widget.controller.playlist;
    List<AudioTrack> newUnfolderedTracks = [];

    for (var track in controllerTracks) {
      if (!folderedTrackPaths.contains(track.path)) {
        newUnfolderedTracks.add(track);
      }
    }

    setState(() {
      unfolderedTracks = newUnfolderedTracks;
    });

    // Remove tracks from folders that no longer exist in controller
    Set<String> controllerTrackPaths =
        controllerTracks.map((t) => t.path).toSet();

    for (var folder in folders) {
      folder.tracks
          .removeWhere((track) => !controllerTrackPaths.contains(track.path));
    }
  }

  int get totalTrackCount {
    int count = unfolderedTracks.length;
    for (var folder in folders) {
      count += folder.tracks.length;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: Text(
              'Playlist ($totalTrackCount tracks)',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.transparent,
            iconTheme: IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: Icon(Icons.play_circle_fill, color: Colors.white),
                tooltip: 'Open Player',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AudioPlayerScreen(controller: widget.controller),
                    ),
                  );
                },
              ),
              if (totalTrackCount > 0)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) {
                    switch (value) {
                      case 'new_folder':
                        _showCreateFolderDialog();
                        break;
                      case 'clear_all':
                        _showClearPlaylistDialog(context);
                        break;
                      case 'add_files':
                        _showFileSourceOptions(context, null);
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
                      value: 'new_folder',
                      child: Row(
                        children: [
                          Icon(Icons.create_new_folder, color: Colors.white70),
                          SizedBox(width: 8),
                          Text('New Folder'),
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
            child: totalTrackCount == 0
                ? _buildEmptyPlaylist(context)
                : _buildOrganizedPlaylist(context),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showFileSourceOptions(context, null),
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
            onPressed: () => _showFileSourceOptions(context, null),
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

  Widget _buildOrganizedPlaylist(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // Folders
        ...folders.map((folder) => _buildFolder(folder)),

        // Unfoldered tracks section
        if (unfolderedTracks.isNotEmpty) ...[
          if (folders.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: Colors.white24),
            ),

          // Unfoldered tracks header
          Container(
            margin: EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.music_note, color: Colors.white54, size: 20),
                SizedBox(width: 8),
                Text(
                  'All Tracks',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${unfolderedTracks.length}',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // Unfoldered tracks
          ...unfolderedTracks.asMap().entries.map((entry) {
            return _buildTrackItem(entry.value, entry.key, null);
          }).toList(),
        ],
      ],
    );
  }

  Widget _buildFolder(PlaylistFolder folder) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      child: Column(
        children: [
          // Folder header
          InkWell(
            onTap: () {
              setState(() {
                folder.isExpanded = !folder.isExpanded;
              });
            },
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.15),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(12),
                  bottom: Radius.circular(folder.isExpanded ? 0 : 12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    folder.isExpanded ? Icons.folder_open : Icons.folder,
                    color: Colors.deepPurpleAccent,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      folder.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.deepPurpleAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${folder.tracks.length}',
                      style: TextStyle(
                        color: Colors.deepPurpleAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    folder.isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white54,
                  ),
                  PopupMenuButton<String>(
                    icon:
                        Icon(Icons.more_vert, color: Colors.white54, size: 20),
                    onSelected: (value) {
                      switch (value) {
                        case 'add_to_folder':
                          _showAddToFolderDialog(folder);
                          break;
                        case 'rename':
                          _showRenameFolderDialog(folder);
                          break;
                        case 'delete':
                          _showDeleteFolderDialog(folder);
                          break;
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem(
                        value: 'add_to_folder',
                        child: Row(
                          children: [
                            Icon(Icons.add, color: Colors.white70, size: 20),
                            SizedBox(width: 8),
                            Text('Add Tracks', style: TextStyle(fontSize: 14)),
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
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text('Delete Folder',
                                style:
                                    TextStyle(color: Colors.red, fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Folder tracks (collapsible)
          if (folder.isExpanded && folder.tracks.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                children: folder.tracks.asMap().entries.map((entry) {
                  return _buildTrackItem(entry.value, entry.key, folder);
                }).toList(),
              ),
            ),

          // Empty folder message
          if (folder.isExpanded && folder.tracks.isEmpty)
            Container(
              padding: EdgeInsets.all(20),
              child: Text(
                'Empty folder - Add tracks to organize',
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrackItem(
      AudioTrack track, int localIndex, PlaylistFolder? folder) {
    // Find actual index in controller's playlist
    final actualIndex = widget.controller.playlist.indexOf(track);
    final isCurrentTrack = actualIndex == widget.controller.currentIndex;

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isCurrentTrack
            ? Colors.deepPurpleAccent.withOpacity(0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isCurrentTrack
            ? Border.all(color: Colors.deepPurpleAccent, width: 1)
            : null,
      ),
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCurrentTrack
                ? Colors.deepPurpleAccent
                : Colors.deepPurple.shade700.withOpacity(0.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            isCurrentTrack ? Icons.play_arrow : Icons.music_note,
            color: Colors.white,
            size: isCurrentTrack ? 24 : 20,
          ),
        ),
        title: Text(
          track.displayName,
          style: TextStyle(
            color: isCurrentTrack ? Colors.white : Colors.white70,
            fontWeight: isCurrentTrack ? FontWeight.bold : FontWeight.normal,
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: track.artistAlbum.isNotEmpty
            ? Text(
                track.artistAlbum,
                style: TextStyle(
                  color: isCurrentTrack ? Colors.white70 : Colors.white60,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: Colors.white54,
            size: 18,
          ),
          onSelected: (value) async {
            switch (value) {
              case 'play':
                if (actualIndex != -1) {
                  widget.controller.loadTrack(actualIndex);
                  widget.controller.player.play();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AudioPlayerScreen(controller: widget.controller),
                    ),
                  );
                }
                break;
              case 'move_to_folder':
                _showMoveToFolderDialog(track, folder);
                break;
              case 'edit':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AudioEditScreen(
                      track: track,
                      controller: widget.controller,
                    ),
                  ),
                );
                break;
              case 'share':
                final params = ShareParams(
                  text: 'Sharing: ${track.displayName}',
                  files: [XFile(track.path)],
                );
                await SharePlus.instance.share(params);
                break;
              case 'rename':
                _showRenameDialog(context, actualIndex, track);
                break;
              case 'remove':
                _showRemoveTrackDialog(context, actualIndex, track, folder);
                break;
            }
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem(
              value: 'play',
              child: Row(
                children: [
                  Icon(Icons.play_arrow, color: Colors.white70, size: 18),
                  SizedBox(width: 8),
                  Text('Play', style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'move_to_folder',
              child: Row(
                children: [
                  Icon(Icons.drive_file_move, color: Colors.white70, size: 18),
                  SizedBox(width: 8),
                  Text('Move to Folder', style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.white70, size: 18),
                  SizedBox(width: 8),
                  Text('Edit', style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.share, color: Colors.white70, size: 18),
                  SizedBox(width: 8),
                  Text('Share', style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.white70, size: 18),
                  SizedBox(width: 8),
                  Text('Rename', style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'remove',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Text('Remove',
                      style: TextStyle(color: Colors.red, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
        onTap: () {
          if (actualIndex != -1) {
            widget.controller.loadTrack(actualIndex);
            widget.controller.player.play();

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    AudioPlayerScreen(controller: widget.controller),
              ),
            );
          }
        },
      ),
    );
  }

  void _showCreateFolderDialog() {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title:
              Text('Create New Folder', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: nameController,
            autofocus: true,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Folder name',
              hintStyle: TextStyle(color: Colors.white54),
              prefixIcon: Icon(Icons.folder, color: Colors.deepPurpleAccent),
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
              child: Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  setState(() {
                    folders.add(PlaylistFolder(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameController.text.trim(),
                    ));
                  });
                  Navigator.pop(context);
                }
              },
              child: Text('Create',
                  style: TextStyle(color: Colors.deepPurpleAccent)),
            ),
          ],
        );
      },
    );
  }

  void _showRenameFolderDialog(PlaylistFolder folder) {
    final TextEditingController nameController =
        TextEditingController(text: folder.name);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: Text('Rename Folder', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: nameController,
            autofocus: true,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Folder name',
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
              child: Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  setState(() {
                    folder.name = nameController.text.trim();
                  });
                  Navigator.pop(context);
                }
              },
              child: Text('Save',
                  style: TextStyle(color: Colors.deepPurpleAccent)),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteFolderDialog(PlaylistFolder folder) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: Text('Delete Folder', style: TextStyle(color: Colors.white)),
          content: Text(
            'Delete "${folder.name}"? Tracks will be moved to All Tracks.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  // Move tracks back to unfoldered
                  unfolderedTracks.addAll(folder.tracks);
                  folders.remove(folder);
                });
                Navigator.pop(context);
              },
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showMoveToFolderDialog(
      AudioTrack track, PlaylistFolder? currentFolder) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: Text('Move to Folder', style: TextStyle(color: Colors.white)),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Option to move to root (All Tracks)
                if (currentFolder != null)
                  ListTile(
                    leading: Icon(Icons.music_note, color: Colors.white54),
                    title: Text('All Tracks',
                        style: TextStyle(color: Colors.white)),
                    onTap: () {
                      setState(() {
                        currentFolder.tracks.remove(track);
                        unfolderedTracks.add(track);
                      });
                      Navigator.pop(context);
                    },
                  ),

                // Available folders
                ...folders.where((f) => f != currentFolder).map((folder) =>
                    ListTile(
                      leading:
                          Icon(Icons.folder, color: Colors.deepPurpleAccent),
                      title: Text(folder.name,
                          style: TextStyle(color: Colors.white)),
                      trailing: Text('${folder.tracks.length}',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 12)),
                      onTap: () {
                        setState(() {
                          // Remove from current location
                          if (currentFolder != null) {
                            currentFolder.tracks.remove(track);
                          } else {
                            unfolderedTracks.remove(track);
                          }
                          // Add to new folder
                          folder.tracks.add(track);
                        });
                        Navigator.pop(context);
                      },
                    )),

                // Create new folder option
                Divider(color: Colors.white24),
                ListTile(
                  leading: Icon(Icons.create_new_folder, color: Colors.green),
                  title: Text('Create New Folder',
                      style: TextStyle(color: Colors.green)),
                  onTap: () {
                    Navigator.pop(context);
                    _showCreateFolderAndMoveDialog(track, currentFolder);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
          ],
        );
      },
    );
  }

  void _showCreateFolderAndMoveDialog(
      AudioTrack track, PlaylistFolder? currentFolder) {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: Text('Create Folder & Move',
              style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: nameController,
            autofocus: true,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Folder name',
              hintStyle: TextStyle(color: Colors.white54),
              prefixIcon: Icon(Icons.folder, color: Colors.deepPurpleAccent),
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
              child: Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  setState(() {
                    // Create new folder with the track
                    var newFolder = PlaylistFolder(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameController.text.trim(),
                      tracks: [track],
                    );
                    folders.add(newFolder);

                    // Remove from current location
                    if (currentFolder != null) {
                      currentFolder.tracks.remove(track);
                    } else {
                      unfolderedTracks.remove(track);
                    }
                  });
                  Navigator.pop(context);
                }
              },
              child: Text('Create & Move',
                  style: TextStyle(color: Colors.deepPurpleAccent)),
            ),
          ],
        );
      },
    );
  }

  void _showAddToFolderDialog(PlaylistFolder folder) {
    List<AudioTrack> availableTracks = List.from(unfolderedTracks);
    List<AudioTrack> selectedTracks = [];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey.shade900,
              title: Text('Add Tracks to ${folder.name}',
                  style: TextStyle(color: Colors.white)),
              content: Container(
                width: double.maxFinite,
                height: 400,
                child: availableTracks.isEmpty
                    ? Center(
                        child: Text('No tracks available to add',
                            style: TextStyle(color: Colors.white54)),
                      )
                    : ListView.builder(
                        itemCount: availableTracks.length,
                        itemBuilder: (context, index) {
                          final track = availableTracks[index];
                          final isSelected = selectedTracks.contains(track);

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  selectedTracks.add(track);
                                } else {
                                  selectedTracks.remove(track);
                                }
                              });
                            },
                            title: Text(
                              track.displayName,
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: track.artistAlbum.isNotEmpty
                                ? Text(
                                    track.artistAlbum,
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            checkColor: Colors.black,
                            activeColor: Colors.deepPurpleAccent,
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child:
                      Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                TextButton(
                  onPressed: selectedTracks.isEmpty
                      ? null
                      : () {
                          setState(() {
                            folder.tracks.addAll(selectedTracks);
                            unfolderedTracks
                                .removeWhere((t) => selectedTracks.contains(t));
                          });
                          Navigator.pop(context);
                        },
                  child: Text(
                    'Add (${selectedTracks.length})',
                    style: TextStyle(
                      color: selectedTracks.isEmpty
                          ? Colors.white30
                          : Colors.deepPurpleAccent,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showFileSourceOptions(
      BuildContext context, PlaylistFolder? targetFolder) {
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
              if (targetFolder != null)
                Container(
                  margin: EdgeInsets.only(top: 8),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepPurpleAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder,
                          color: Colors.deepPurpleAccent, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Adding to: ${targetFolder.name}',
                        style: TextStyle(
                            color: Colors.deepPurpleAccent, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 20),

              // Add this after the Photos ListTile in _showFileSourceOptions:

// Voice Recording
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.mic, color: Colors.red, size: 24),
                ),
                title: Text('Voice Recording',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500)),
                subtitle: Text('Record audio directly in app',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          RecordingScreen(controller: widget.controller),
                    ),
                  );
                },
              ),

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
                  _addFilesAndMoveToFolder(
                      targetFolder, () => widget.controller.pickAudioFiles());
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
                  _addFilesAndMoveToFolder(
                      targetFolder, () => widget.controller.pickFromPhotos());
                },
              ),

              SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addFilesAndMoveToFolder(PlaylistFolder? targetFolder,
      Future<void> Function() addFilesFunction) async {
    // Store current playlist length
    final int previousTrackCount = widget.controller.playlist.length;

    // Add the files
    await addFilesFunction();

    // If files were added and we have a target folder
    if (targetFolder != null &&
        widget.controller.playlist.length > previousTrackCount) {
      setState(() {
        // Get the newly added tracks (tracks at the end of the playlist)
        final newTracks =
            widget.controller.playlist.sublist(previousTrackCount);

        // Add them to the target folder
        targetFolder.tracks.addAll(newTracks);

        // Remove them from unfolderedTracks if they're there
        for (var track in newTracks) {
          unfolderedTracks.remove(track);
        }
      });
    } else {
      // Normal behavior - refresh the state to show new tracks
      setState(() {
        _syncTracksWithController();
      });
    }
  }

  bool _isTrackInAnyFolder(AudioTrack track) {
    for (var folder in folders) {
      if (folder.tracks.any((t) => t.path == track.path)) {
        return true;
      }
    }
    return false;
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
                if (controller.text.trim().isNotEmpty && index != -1) {
                  widget.controller.renameTrack(index, controller.text.trim());
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

  void _showRemoveTrackDialog(BuildContext context, int index, AudioTrack track,
      PlaylistFolder? folder) {
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
                setState(() {
                  // Remove from folder or unfoldered list
                  if (folder != null) {
                    folder.tracks.remove(track);
                  } else {
                    unfolderedTracks.remove(track);
                  }
                });
                // Remove from main controller
                if (index != -1) {
                  widget.controller.removeTrack(index);
                }
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
          content: const Text(
            'Remove all tracks and folders from playlist?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  folders.clear();
                  unfolderedTracks.clear();
                });
                widget.controller.clearPlaylist();
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
