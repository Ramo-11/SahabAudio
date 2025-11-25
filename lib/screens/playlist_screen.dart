import 'package:flutter/material.dart';
import '../controllers/audio_player_controller.dart';
import '../models/audio_track.dart';
import './audio_edit_screen.dart';
import './audio_player_screen.dart';
import 'recording_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
  List<PlaylistFolder> folders = [];
  List<AudioTrack> unfolderedTracks = [];

  @override
  void initState() {
    super.initState();
    _initializeFolders();
    widget.controller.addListener(_onControllerUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFolderStructure());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) _syncTracksWithController();
  }

  void _initializeFolders() {
    unfolderedTracks = List.from(widget.controller.playlist);
  }

  Future<void> _saveFolderStructure() async {
    final prefs = await SharedPreferences.getInstance();
    final foldersJson = folders
        .map((folder) => {
              'id': folder.id,
              'name': folder.name,
              'isExpanded': folder.isExpanded,
              'trackFileNames':
                  folder.tracks.map((t) => t.physicalFileName).toList(),
            })
        .toList();
    await prefs.setString('playlist_folders_v2', jsonEncode(foldersJson));
  }

  Future<void> _loadFolderStructure() async {
    final prefs = await SharedPreferences.getInstance();
    final foldersString = prefs.getString('playlist_folders_v2');

    if (foldersString != null) {
      try {
        final List<dynamic> foldersJson = jsonDecode(foldersString);
        final allTracks = widget.controller.playlist;

        setState(() {
          folders = foldersJson.map((data) {
            final folder = PlaylistFolder(
              id: data['id'],
              name: data['name'],
              isExpanded: data['isExpanded'] ?? true,
            );

            final savedNames = List<String>.from(
                data['trackFileNames'] ?? data['trackPaths'] ?? []);
            for (var name in savedNames) {
              final fileName = name.split('/').last;
              try {
                final track =
                    allTracks.firstWhere((t) => t.physicalFileName == fileName);
                folder.tracks.add(track);
              } catch (_) {}
            }
            return folder;
          }).toList();
        });

        _syncTracksWithController();
      } catch (e) {
        print('Error loading folder structure: $e');
      }
    } else {
      _syncTracksWithController();
    }
  }

  void _syncTracksWithController() {
    final folderedPaths = <String>{};
    for (var folder in folders) {
      for (var track in folder.tracks) {
        folderedPaths.add(track.path);
      }
    }

    final controllerTracks = widget.controller.playlist;
    final newUnfoldered =
        controllerTracks.where((t) => !folderedPaths.contains(t.path)).toList();

    setState(() {
      unfolderedTracks = newUnfoldered;
    });

    final controllerPaths = controllerTracks.map((t) => t.path).toSet();
    for (var folder in folders) {
      folder.tracks.removeWhere((t) => !controllerPaths.contains(t.path));
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
          backgroundColor: const Color(0xFF0F0F1A),
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 120,
                floating: false,
                pinned: true,
                backgroundColor: const Color(0xFF0F0F1A),
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    'Library',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                    ),
                  ),
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                ),
                actions: [
                  if (totalTrackCount > 0)
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Color(0xFF8B5CF6)),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AudioPlayerScreen(controller: widget.controller),
                        ),
                      ),
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded,
                        color: Colors.white54),
                    color: const Color(0xFF1A1A2E),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (value) {
                      switch (value) {
                        case 'new_folder':
                          _showCreateFolderDialog();
                          break;
                        case 'clear_all':
                          _showClearPlaylistDialog();
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      _buildPopupItem(Icons.create_new_folder_rounded,
                          'New Folder', 'new_folder'),
                      if (totalTrackCount > 0)
                        _buildPopupItem(Icons.delete_outline_rounded,
                            'Clear All', 'clear_all',
                            isDestructive: true),
                    ],
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              if (totalTrackCount == 0)
                SliverFillRemaining(child: _buildEmptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      ...folders.map((f) => _buildFolder(f)),
                      if (unfolderedTracks.isNotEmpty) ...[
                        if (folders.isNotEmpty) const SizedBox(height: 24),
                        _buildSectionHeader(
                            'All Tracks', unfolderedTracks.length),
                        const SizedBox(height: 12),
                        ...unfolderedTracks
                            .map((t) => _buildTrackItem(t, null)),
                      ],
                    ]),
                  ),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddSourceSheet(),
            backgroundColor: const Color(0xFF8B5CF6),
            elevation: 8,
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        );
      },
    );
  }

  PopupMenuItem<String> _buildPopupItem(
      IconData icon, String title, String value,
      {bool isDestructive = false}) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon,
              color: isDestructive ? const Color(0xFFEF4444) : Colors.white70,
              size: 20),
          const SizedBox(width: 12),
          Text(title,
              style: TextStyle(
                  color:
                      isDestructive ? const Color(0xFFEF4444) : Colors.white)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(Icons.library_music_rounded,
                size: 48, color: Color(0xFF8B5CF6)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Your library is empty',
            style: TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Add audio files to get started',
            style:
                TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 15),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _showAddSourceSheet(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Audio'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style:
                TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildFolder(PlaylistFolder folder) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => folder.isExpanded = !folder.isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      folder.isExpanded
                          ? Icons.folder_open_rounded
                          : Icons.folder_rounded,
                      color: const Color(0xFF8B5CF6),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      folder.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${folder.tracks.length}',
                      style: const TextStyle(
                          color: Color(0xFF8B5CF6),
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    folder.isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Colors.white38,
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded,
                        color: Colors.white38, size: 20),
                    color: const Color(0xFF1A1A2E),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (value) {
                      switch (value) {
                        case 'rename':
                          _showRenameFolderDialog(folder);
                          break;
                        case 'delete':
                          _showDeleteFolderDialog(folder);
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      _buildPopupItem(Icons.edit_rounded, 'Rename', 'rename'),
                      _buildPopupItem(
                          Icons.delete_outline_rounded, 'Delete', 'delete',
                          isDestructive: true),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (folder.isExpanded)
            folder.tracks.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('Empty folder',
                        style: TextStyle(color: Colors.white.withOpacity(0.3))),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Column(
                        children: folder.tracks
                            .map((t) => _buildTrackItem(t, folder))
                            .toList()),
                  ),
        ],
      ),
    );
  }

  Widget _buildTrackItem(AudioTrack track, PlaylistFolder? folder) {
    final actualIndex = widget.controller.playlist.indexOf(track);
    final isCurrentTrack = actualIndex == widget.controller.currentIndex;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (actualIndex != -1) {
            widget.controller.loadTrack(actualIndex, autoPlay: true);
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      AudioPlayerScreen(controller: widget.controller)),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isCurrentTrack
                ? const Color(0xFF8B5CF6).withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isCurrentTrack
                ? Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3))
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isCurrentTrack
                      ? const Color(0xFF8B5CF6)
                      : const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCurrentTrack
                      ? Icons.play_arrow_rounded
                      : Icons.music_note_rounded,
                  color: isCurrentTrack
                      ? Colors.white
                      : const Color(0xFF8B5CF6).withOpacity(0.7),
                  size: isCurrentTrack ? 26 : 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.displayName,
                      style: TextStyle(
                        color: isCurrentTrack
                            ? Colors.white
                            : Colors.white.withOpacity(0.85),
                        fontWeight:
                            isCurrentTrack ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (track.artist != null)
                      Text(
                        track.artist!,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.4), fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded,
                    color: Colors.white.withOpacity(0.3), size: 20),
                color: const Color(0xFF1A1A2E),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (value) async {
                  switch (value) {
                    case 'play':
                      if (actualIndex != -1) {
                        widget.controller
                            .loadTrack(actualIndex, autoPlay: true);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => AudioPlayerScreen(
                                    controller: widget.controller)));
                      }
                      break;
                    case 'edit':
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => AudioEditScreen(
                                  track: track,
                                  controller: widget.controller)));
                      break;
                    case 'move':
                      _showMoveToFolderDialog(track, folder);
                      break;
                    case 'share':
                      await SharePlus.instance
                          .share(ShareParams(files: [XFile(track.path)]));
                      break;
                    case 'rename':
                      _showRenameDialog(actualIndex, track);
                      break;
                    case 'remove':
                      _showRemoveTrackDialog(actualIndex, track, folder);
                      break;
                  }
                },
                itemBuilder: (_) => [
                  _buildPopupItem(Icons.play_arrow_rounded, 'Play', 'play'),
                  _buildPopupItem(Icons.edit_rounded, 'Edit Audio', 'edit'),
                  _buildPopupItem(
                      Icons.drive_file_move_rounded, 'Move', 'move'),
                  _buildPopupItem(Icons.share_rounded, 'Share', 'share'),
                  _buildPopupItem(
                      Icons.text_fields_rounded, 'Rename', 'rename'),
                  _buildPopupItem(
                      Icons.delete_outline_rounded, 'Remove', 'remove',
                      isDestructive: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            const Text('Add Audio',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            _buildSourceOption(
              icon: Icons.mic_rounded,
              title: 'Record',
              subtitle: 'Create a voice recording',
              color: const Color(0xFFEF4444),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            RecordingScreen(controller: widget.controller)));
              },
            ),
            const SizedBox(height: 12),
            _buildSourceOption(
              icon: Icons.folder_rounded,
              title: 'Files',
              subtitle: 'Browse your files',
              color: const Color(0xFF3B82F6),
              onTap: () {
                Navigator.pop(context);
                widget.controller.pickAudioFiles();
              },
            ),
            const SizedBox(height: 12),
            _buildSourceOption(
              icon: Icons.photo_library_rounded,
              title: 'Photos',
              subtitle: 'Import from photo library',
              color: const Color(0xFF10B981),
              onTap: () {
                Navigator.pop(context);
                widget.controller.pickFromPhotos();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500)),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New Folder', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Folder name',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  folders.add(PlaylistFolder(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: controller.text.trim(),
                  ));
                });
                _saveFolderStructure();
                Navigator.pop(context);
              }
            },
            child: const Text('Create',
                style: TextStyle(color: Color(0xFF8B5CF6))),
          ),
        ],
      ),
    );
  }

  void _showRenameFolderDialog(PlaylistFolder folder) {
    final controller = TextEditingController(text: folder.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:
            const Text('Rename Folder', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(color: Colors.white.withOpacity(0.5)))),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() => folder.name = controller.text.trim());
                _saveFolderStructure();
                Navigator.pop(context);
              }
            },
            child:
                const Text('Save', style: TextStyle(color: Color(0xFF8B5CF6))),
          ),
        ],
      ),
    );
  }

  void _showDeleteFolderDialog(PlaylistFolder folder) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:
            const Text('Delete Folder?', style: TextStyle(color: Colors.white)),
        content: Text('Tracks will be moved to All Tracks.',
            style: TextStyle(color: Colors.white.withOpacity(0.6))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(color: Colors.white.withOpacity(0.5)))),
          TextButton(
            onPressed: () {
              setState(() {
                unfolderedTracks.addAll(folder.tracks);
                folders.remove(folder);
              });
              _saveFolderStructure();
              Navigator.pop(context);
            },
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }

  void _showMoveToFolderDialog(
      AudioTrack track, PlaylistFolder? currentFolder) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Move to',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            if (currentFolder != null)
              ListTile(
                leading:
                    const Icon(Icons.music_note_rounded, color: Colors.white54),
                title: const Text('All Tracks',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  setState(() {
                    currentFolder.tracks.remove(track);
                    unfolderedTracks.add(track);
                  });
                  _saveFolderStructure();
                  Navigator.pop(context);
                },
              ),
            ...folders.where((f) => f != currentFolder).map((f) => ListTile(
                  leading: const Icon(Icons.folder_rounded,
                      color: Color(0xFF8B5CF6)),
                  title:
                      Text(f.name, style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    setState(() {
                      if (currentFolder != null) {
                        currentFolder.tracks.remove(track);
                      } else {
                        unfolderedTracks.remove(track);
                      }
                      f.tracks.add(track);
                    });
                    _saveFolderStructure();
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(int index, AudioTrack track) {
    final controller = TextEditingController(text: track.displayName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rename', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(color: Colors.white.withOpacity(0.5)))),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty && index != -1) {
                widget.controller.renameTrack(index, controller.text.trim());
                Navigator.pop(context);
              }
            },
            child:
                const Text('Save', style: TextStyle(color: Color(0xFF8B5CF6))),
          ),
        ],
      ),
    );
  }

  void _showRemoveTrackDialog(
      int index, AudioTrack track, PlaylistFolder? folder) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:
            const Text('Remove Track?', style: TextStyle(color: Colors.white)),
        content: Text(track.displayName,
            style: TextStyle(color: Colors.white.withOpacity(0.6))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(color: Colors.white.withOpacity(0.5)))),
          TextButton(
            onPressed: () {
              setState(() {
                if (folder != null) {
                  folder.tracks.remove(track);
                } else {
                  unfolderedTracks.remove(track);
                }
              });
              if (index != -1) widget.controller.removeTrack(index);
              Navigator.pop(context);
            },
            child: const Text('Remove',
                style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }

  void _showClearPlaylistDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:
            const Text('Clear Library?', style: TextStyle(color: Colors.white)),
        content: Text('This will remove all tracks and folders.',
            style: TextStyle(color: Colors.white.withOpacity(0.6))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(color: Colors.white.withOpacity(0.5)))),
          TextButton(
            onPressed: () {
              setState(() {
                folders.clear();
                unfolderedTracks.clear();
              });
              widget.controller.clearPlaylist();
              Navigator.pop(context);
            },
            child: const Text('Clear All',
                style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }
}
