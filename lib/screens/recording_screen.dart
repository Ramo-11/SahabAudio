// screens/recording_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../controllers/audio_player_controller.dart';
import '../models/audio_track.dart';

class RecordingScreen extends StatefulWidget {
  final AudioPlayerController controller;

  const RecordingScreen({Key? key, required this.controller}) : super(key: key);

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with TickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isPaused = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _timer;
  String? _recordingPath;

  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    );
    _waveController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _checkPermissions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _waveController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.microphone.status;
    if (status.isDenied || status.isRestricted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Microphone permission is required for recording'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => openAppSettings(),
              ),
            ),
          );
          Navigator.pop(context);
        }
      }
    }
  }

  Future<String> _getRecordingPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return '${directory.path}/recording_$timestamp.m4a';
  }

  Future<void> _startRecording() async {
    try {
      // Double-check permission before recording
      final hasPermission = await Permission.microphone.isGranted;
      if (!hasPermission) {
        final result = await Permission.microphone.request();
        if (!result.isGranted) {
          _showError('Microphone permission denied');
          return;
        }
      }
      if (await _recorder.hasPermission()) {
        _recordingPath = await _getRecordingPath();

        await _recorder.start(
            const RecordConfig(
              encoder: AudioEncoder.aacLc,
              bitRate: 128000,
              sampleRate: 44100,
              autoGain: true,
              echoCancel: true,
              noiseSuppress: true,
            ),
            path: _recordingPath!);

        setState(() {
          _isRecording = true;
          _isPaused = false;
          _recordingDuration = Duration.zero;
        });

        _pulseController.repeat(reverse: true);
        _waveController.repeat(reverse: true);

        _timer = Timer.periodic(Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _recordingDuration = Duration(seconds: timer.tick);
            });
          }
        });
      }
    } catch (e) {
      print('Error starting recording: $e');
      _showError('Failed to start recording');
    }
  }

  Future<void> _pauseRecording() async {
    try {
      await _recorder.pause();
      setState(() {
        _isPaused = true;
      });
      _pulseController.stop();
      _waveController.stop();
      _timer?.cancel();
    } catch (e) {
      print('Error pausing recording: $e');
    }
  }

  Future<void> _resumeRecording() async {
    try {
      await _recorder.resume();
      setState(() {
        _isPaused = false;
      });
      _pulseController.repeat(reverse: true);
      _waveController.repeat(reverse: true);

      final currentSeconds = _recordingDuration.inSeconds;
      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration = Duration(seconds: currentSeconds + timer.tick);
          });
        }
      });
    } catch (e) {
      print('Error resuming recording: $e');
    }
  }

  Future<void> _stopRecording({bool save = true}) async {
    try {
      final path = await _recorder.stop();

      setState(() {
        _isRecording = false;
        _isPaused = false;
      });

      _pulseController.stop();
      _waveController.stop();
      _timer?.cancel();

      if (save && path != null && _recordingDuration.inSeconds > 0) {
        _showSaveDialog(path);
      } else if (path != null) {
        // Delete the file if not saving
        try {
          await File(path).delete();
        } catch (e) {
          print('Error deleting recording: $e');
        }
      }
    } catch (e) {
      print('Error stopping recording: $e');
      _showError('Failed to stop recording');
    }
  }

  void _showSaveDialog(String filePath) {
    final TextEditingController nameController = TextEditingController(
      text:
          'Recording ${DateTime.now().month}/${DateTime.now().day} ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: Text('Save Recording', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Duration: ${_formatDuration(_recordingDuration)}',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              SizedBox(height: 16),
              TextField(
                controller: nameController,
                autofocus: true,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Recording name',
                  hintStyle: TextStyle(color: Colors.white54),
                  prefixIcon: Icon(Icons.mic, color: Colors.deepPurpleAccent),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.deepPurpleAccent),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.deepPurpleAccent),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                // Delete the file
                try {
                  await File(filePath).delete();
                } catch (e) {
                  print('Error deleting recording: $e');
                }
                Navigator.pop(context);
              },
              child: Text('Discard', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(context);
                  await _saveRecording(filePath, name);
                }
              },
              child: Text('Save', style: TextStyle(color: Colors.green)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveRecording(String filePath, String name) async {
    try {
      // Create new track
      final track = AudioTrack(
        path: filePath,
        fileName: '$name.m4a',
        artist: 'Voice Recording',
        album: 'Recordings',
      );

      // Add to playlist
      widget.controller.addTrack(track);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recording saved: $name'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error saving recording: $e');
      _showError('Failed to save recording');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Voice Recording', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          if (_isRecording)
            TextButton(
              onPressed: () => _stopRecording(save: false),
              child: Text('Cancel', style: TextStyle(color: Colors.red)),
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Recording duration
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        _formatDuration(_recordingDuration),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),

                    SizedBox(height: 60),

                    // Recording status
                    Text(
                      _isRecording
                          ? (_isPaused ? 'Recording Paused' : 'Recording...')
                          : 'Ready to Record',
                      style: TextStyle(
                        color: _isRecording
                            ? (_isPaused ? Colors.orange : Colors.red)
                            : Colors.white70,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    SizedBox(height: 40),

                    // Animated microphone
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _isRecording && !_isPaused
                              ? _pulseAnimation.value
                              : 1.0,
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: _isRecording
                                    ? [Colors.red.shade400, Colors.red.shade600]
                                    : [
                                        Colors.deepPurpleAccent,
                                        Colors.purple.shade600
                                      ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isRecording
                                          ? Colors.red
                                          : Colors.deepPurpleAccent)
                                      .withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.mic,
                              size: 80,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: 60),

                    // Wave animation
                    if (_isRecording && !_isPaused)
                      Container(
                        height: 50,
                        child: AnimatedBuilder(
                          animation: _waveController,
                          builder: (context, child) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(7, (index) {
                                final height = 10 +
                                    (30 *
                                        (_waveController.value + index * 0.2) %
                                        1);
                                return Container(
                                  margin: EdgeInsets.symmetric(horizontal: 3),
                                  width: 4,
                                  height: height,
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),

              // Control buttons
              Container(
                padding: EdgeInsets.all(30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Main record/pause button (always centered)
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _isRecording
                              ? [Colors.orange, Colors.orange.shade700]
                              : [Colors.red, Colors.red.shade700],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_isRecording ? Colors.orange : Colors.red)
                                .withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isRecording
                              ? (_isPaused ? Icons.play_arrow : Icons.pause)
                              : Icons.fiber_manual_record,
                          color: Colors.white,
                          size: 40,
                        ),
                        onPressed: () {
                          if (!_isRecording) {
                            _startRecording();
                          } else if (_isPaused) {
                            _resumeRecording();
                          } else {
                            _pauseRecording();
                          }
                        },
                        iconSize: 80,
                      ),
                    ),

                    // Stop button appears to the right when recording
                    if (_isRecording) ...[
                      SizedBox(width: 40),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.stop, color: Colors.white, size: 32),
                          onPressed: () => _stopRecording(save: true),
                          iconSize: 60,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
