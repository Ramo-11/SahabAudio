// screens/audio_player_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../controllers/audio_player_controller.dart';
import '../widgets/album_art_widget.dart';
import '../widgets/control_buttons_widget.dart';
import '../widgets/progress_slider_widget.dart';
import '../widgets/volume_speed_controls.dart';
import 'playlist_screen.dart';
import '../main.dart';
import 'recording_screen.dart';

class AudioPlayerScreen extends StatefulWidget {
  // ✅ Require the shared controller
  final AudioPlayerController controller;
  const AudioPlayerScreen({Key? key, required this.controller})
      : super(key: key);

  @override
  _AudioPlayerScreenState createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen>
    with TickerProviderStateMixin {
  late AudioPlayerController _controller;
  late AnimationController _rotationController;
  late AnimationController _waveController;
  StreamSubscription? _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    // ✅ Use the injected controller instead of creating a new one
    _controller = widget.controller;

    _rotationController = AnimationController(
      duration: Duration(seconds: 20),
      vsync: this,
    );
    _waveController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _setupAnimations();

    // Keep your shared file handler behavior
    SharedFileHandler.instance.registerController(_controller);
  }

  void _setupAnimations() {
    _playerStateSubscription =
        _controller.player.playerStateStream.listen((state) {
      if (mounted) {
        if (state.playing) {
          _rotationController.repeat();
          _waveController.repeat(reverse: true);
        } else {
          _rotationController.stop();
          _waveController.stop();
        }
      }
    });
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel(); // Cancel the stream subscription
    SharedFileHandler.instance.unregisterController();
    _rotationController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _showFileSourceOptions() {
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
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white54,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Choose Audio Source',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),

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
                          RecordingScreen(controller: _controller),
                    ),
                  );
                },
              ),

              // Files App
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.folder, color: Colors.blue, size: 24),
                ),
                title: Text('Files App',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500)),
                subtitle: Text('Browse files and folders',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  _controller.pickAudioFiles();
                },
              ),

              // Photos App
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      Icon(Icons.photo_library, color: Colors.green, size: 24),
                ),
                title: Text('Photos',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500)),
                subtitle: Text('Audio files from Photos app',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  _controller.pickFromPhotos();
                },
              ),

              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showSleepTimerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: Text('Sleep Timer', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title:
                    Text('15 minutes', style: TextStyle(color: Colors.white)),
                onTap: () {
                  _controller.setSleepTimer(Duration(minutes: 15));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title:
                    Text('30 minutes', style: TextStyle(color: Colors.white)),
                onTap: () {
                  _controller.setSleepTimer(Duration(minutes: 30));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text('1 hour', style: TextStyle(color: Colors.white)),
                onTap: () {
                  _controller.setSleepTimer(Duration(hours: 1));
                  Navigator.pop(context);
                },
              ),
              if (_controller.sleepDuration != null)
                ListTile(
                  title:
                      Text('Cancel Timer', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    _controller.cancelSleepTimer();
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showAudioInfoDialog() {
    final currentTrack = _controller.currentTrack;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title:
              Text('Audio Information', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('File: ${currentTrack?.fileName ?? 'No file selected'}',
                  style: TextStyle(color: Colors.white)),
              SizedBox(height: 8),
              Text('Artist: ${currentTrack?.artist ?? 'Unknown'}',
                  style: TextStyle(color: Colors.white70)),
              SizedBox(height: 4),
              Text('Album: ${currentTrack?.album ?? 'Unknown'}',
                  style: TextStyle(color: Colors.white70)),
              SizedBox(height: 4),
              StreamBuilder<Duration?>(
                stream: _controller.player.durationStream,
                builder: (context, snapshot) {
                  final duration = snapshot.data;
                  return Text(
                    'Duration: ${duration != null ? _controller.formatDuration(duration) : 'Unknown'}',
                    style: TextStyle(color: Colors.white70),
                  );
                },
              ),
              SizedBox(height: 4),
              Text('Playlist: ${_controller.playlist.length} tracks',
                  style: TextStyle(color: Colors.white70)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close',
                  style: TextStyle(color: Colors.deepPurpleAccent)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSecondaryControls() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Playlist button
            IconButton(
              icon: Stack(
                children: [
                  Icon(Icons.queue_music, color: Colors.white70),
                  if (_controller.playlist.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.deepPurpleAccent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_controller.playlist.length}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PlaylistScreen(controller: _controller),
                  ),
                );
              },
            ),

            // Shuffle
            IconButton(
              icon: Icon(
                Icons.shuffle,
                color: _controller.isShuffleEnabled
                    ? Colors.deepPurpleAccent
                    : Colors.white38,
              ),
              onPressed: _controller.toggleShuffle,
            ),

            // Loop mode
            IconButton(
              icon: Icon(
                _controller.loopMode == LoopMode.off
                    ? Icons.repeat
                    : _controller.loopMode == LoopMode.one
                        ? Icons.repeat_one
                        : Icons.repeat,
                color: _controller.loopMode != LoopMode.off
                    ? Colors.deepPurpleAccent
                    : Colors.white38,
              ),
              onPressed: _controller.toggleLoop,
            ),

            // Sleep timer
            IconButton(
              icon: Icon(
                Icons.bedtime,
                color: _controller.sleepDuration != null
                    ? Colors.deepPurpleAccent
                    : Colors.white38,
              ),
              onPressed: _showSleepTimerDialog,
            ),

            // More options
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.white70),
              onSelected: (value) {
                switch (value) {
                  case 'audio_info':
                    _showAudioInfoDialog();
                    break;
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem(
                  value: 'audio_info',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.white70),
                      SizedBox(width: 8),
                      Text('Audio Info'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Sahab Audio Player',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Sleep timer display
          ListenableBuilder(
            listenable: _controller,
            builder: (context, child) {
              if (_controller.sleepDuration != null) {
                return Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Center(
                    child: Text(
                      'Sleep: ${_controller.formatDuration(_controller.sleepDuration!)}',
                      style:
                          TextStyle(color: Colors.orangeAccent, fontSize: 12),
                    ),
                  ),
                );
              }
              return SizedBox.shrink();
            },
          ),
          // Add files button
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.deepPurpleAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.deepPurpleAccent.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: IconButton(
              onPressed: _showFileSourceOptions,
              icon: Icon(
                Icons.add,
                color: Colors.deepPurpleAccent,
                size: 24,
              ),
              tooltip: 'Add Audio Files',
            ),
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
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(height: 40),

                      // Album art with rotation animation
                      AlbumArtWidget(
                        rotationController: _rotationController,
                        waveController: _waveController,
                        player: _controller.player,
                      ),

                      SizedBox(height: 40),

                      // Track info
                      // Track info
                      ListenableBuilder(
                        listenable: _controller,
                        builder: (context, child) {
                          final currentTrack = _controller.currentTrack;
                          if (currentTrack == null) {
                            return Column(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.library_music,
                                        size: 64,
                                        color: Colors.white38,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'Import Your First Audio',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Tap the + button to add audio files\nfrom Files or Photos',
                                        style: TextStyle(
                                          color: Colors.white60,
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      SizedBox(height: 20),
                                      ElevatedButton.icon(
                                        onPressed: _showFileSourceOptions,
                                        icon: Icon(Icons.add),
                                        label: Text('Add Audio Files'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.deepPurpleAccent,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 24, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(25),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }

                          return Column(
                            children: [
                              Text(
                                currentTrack.displayName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 8),
                              Text(
                                currentTrack.artistAlbum,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          );
                        },
                      ),

                      SizedBox(height: 30),

                      // Progress slider
                      ProgressSliderWidget(
                        player: _controller.player,
                        formatDuration: _controller.formatDuration,
                      ),

                      SizedBox(height: 30),

                      // Main control buttons
                      ControlButtonsWidget(
                        controller: _controller,
                      ),

                      SizedBox(height: 20),

                      // Secondary controls
                      _buildSecondaryControls(),

                      SizedBox(height: 30),

                      // Volume and speed controls
                      VolumeSpeedControls(
                        controller: _controller,
                      ),

                      SizedBox(height: 30),
                    ],
                  ),
                ),
              ),

              // Sahab Solutions branding (moved to bottom)
              Container(
                padding: EdgeInsets.all(20),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.deepPurpleAccent.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_outlined,
                        size: 16,
                        color: Colors.deepPurpleAccent,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Powered by Sahab Solutions',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
