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
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _checkPermissions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.microphone.status;
    if (status.isDenied || status.isRestricted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Microphone permission required'),
            backgroundColor: const Color(0xFFEF4444),
            action:
                SnackBarAction(label: 'Settings', onPressed: openAppSettings),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<String> _getRecordingPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${directory.path}/recording_$timestamp.m4a';
  }

  Future<void> _startRecording() async {
    try {
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
          path: _recordingPath!,
        );

        setState(() {
          _isRecording = true;
          _isPaused = false;
          _recordingDuration = Duration.zero;
        });

        _pulseController.repeat(reverse: true);

        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted)
            setState(() => _recordingDuration = Duration(seconds: timer.tick));
        });
      }
    } catch (e) {
      _showError('Failed to start recording');
    }
  }

  Future<void> _pauseRecording() async {
    try {
      await _recorder.pause();
      setState(() => _isPaused = true);
      _pulseController.stop();
      _timer?.cancel();
    } catch (e) {
      print('Error pausing: $e');
    }
  }

  Future<void> _resumeRecording() async {
    try {
      await _recorder.resume();
      setState(() => _isPaused = false);
      _pulseController.repeat(reverse: true);

      final currentSeconds = _recordingDuration.inSeconds;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted)
          setState(() => _recordingDuration =
              Duration(seconds: currentSeconds + timer.tick));
      });
    } catch (e) {
      print('Error resuming: $e');
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
      _timer?.cancel();

      if (save && path != null && _recordingDuration.inSeconds > 0) {
        _showSaveDialog(path);
      } else if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
    } catch (e) {
      _showError('Failed to stop recording');
    }
  }

  void _showSaveDialog(String filePath) {
    final now = DateTime.now();
    final controller = TextEditingController(
      text:
          'Recording ${now.month}/${now.day} ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 24),
              const Text('Save Recording',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                'Duration: ${_formatDuration(_recordingDuration)}',
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Recording name',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  prefixIcon:
                      const Icon(Icons.mic_rounded, color: Color(0xFF8B5CF6)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          await File(filePath).delete();
                        } catch (_) {}
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Discard',
                          style: TextStyle(
                              color: Color(0xFFEF4444), fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = controller.text.trim();
                        if (name.isNotEmpty) {
                          Navigator.pop(context);
                          await _saveRecording(filePath, name);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveRecording(String filePath, String name) async {
    try {
      final track = AudioTrack(
        path: filePath,
        fileName: name,
        artist: 'Voice Recording',
        album: 'Recordings',
      );

      widget.controller.addTrack(track);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved: $name'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Failed to save recording');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(message), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white54),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Record',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          if (_isRecording)
            TextButton(
              onPressed: () => _stopRecording(save: false),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFFEF4444))),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // Duration
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _formatDuration(_recordingDuration),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Status
            Text(
              _isRecording
                  ? (_isPaused ? 'Paused' : 'Recording')
                  : 'Ready to record',
              style: TextStyle(
                color: _isRecording
                    ? (_isPaused
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFEF4444))
                    : Colors.white.withOpacity(0.5),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),

            const Spacer(),

            // Animated mic
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale:
                      _isRecording && !_isPaused ? _pulseAnimation.value : 1.0,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _isRecording
                            ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                            : [
                                const Color(0xFF8B5CF6),
                                const Color(0xFF7C3AED)
                              ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_isRecording
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF8B5CF6))
                              .withOpacity(0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.mic_rounded,
                        size: 80, color: Colors.white),
                  ),
                );
              },
            ),

            const Spacer(flex: 2),

            // Controls
            Padding(
              padding: const EdgeInsets.all(40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Main button
                  GestureDetector(
                    onTap: () {
                      if (!_isRecording) {
                        _startRecording();
                      } else if (_isPaused) {
                        _resumeRecording();
                      } else {
                        _pauseRecording();
                      }
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _isRecording
                              ? [
                                  const Color(0xFFF59E0B),
                                  const Color(0xFFD97706)
                                ]
                              : [
                                  const Color(0xFFEF4444),
                                  const Color(0xFFDC2626)
                                ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_isRecording
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFFEF4444))
                                .withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isRecording
                            ? (_isPaused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded)
                            : Icons.fiber_manual_record_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // Stop button
                  if (_isRecording) ...[
                    const SizedBox(width: 40),
                    GestureDetector(
                      onTap: () => _stopRecording(save: true),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(Icons.stop_rounded,
                            size: 32, color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
