// screens/audio_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/audio_track.dart';
import '../controllers/audio_player_controller.dart';
import 'dart:async';
import 'dart:io';

class AudioEditScreen extends StatefulWidget {
  final AudioTrack track;
  final AudioPlayerController controller;

  const AudioEditScreen({
    Key? key,
    required this.track,
    required this.controller,
  }) : super(key: key);

  @override
  State<AudioEditScreen> createState() => _AudioEditScreenState();
}

class _AudioEditScreenState extends State<AudioEditScreen> {
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isProcessing = false;
  bool _isInitialized = false;
  double _processingProgress = 0.0;

  Duration? _trimStart;
  Duration? _trimEnd;
  List<TimeRange> _cutSections = [];

  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final player = widget.controller.player;

      // Set up listeners for the existing player
      _durationSub = player.durationStream.listen((d) {
        if (d != null) {
          setState(() {
            _duration = d;
            _isInitialized = true;
          });
        }
      });

      _positionSub = player.positionStream.listen((p) {
        if (mounted) {
          setState(() {
            _position = p;
          });
          // Only skip cut sections during actual playback, not seeking
          if (_isPlaying && !(_stateSub?.isPaused ?? false)) {
            _skipCutSections();
          }
        }
      });

      _stateSub = player.playerStateStream.listen((state) {
        setState(() {
          _isPlaying = state.playing;
        });
      });

      // Get current duration if already loaded
      final currentDuration = player.duration;
      if (currentDuration != null) {
        setState(() {
          _duration = currentDuration;
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('Error setting up edit player: $e');
      _showError('Failed to initialize audio editor');
    }
  }

  @override
  void dispose() {
    // Clean up
    _durationSub?.cancel();
    _positionSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  void _togglePlay() async {
    if (!_isInitialized) {
      _showError('Audio is still loading...');
      return;
    }

    try {
      if (_isPlaying) {
        await widget.controller.player.pause();
      } else {
        // If we have a trim start and we're before it, seek to it
        if (_trimStart != null && _position < _trimStart!) {
          await widget.controller.player.seek(_trimStart!);
        }
        await widget.controller.player.play();
      }
    } catch (e) {
      print('Error toggling playback: $e');
      _showError('Playback error');
    }
  }

  void _skipCutSections() {
    if (!_isPlaying) return;

    for (var cut in _cutSections) {
      if (_position >= cut.start && _position < cut.end) {
        widget.controller.player.seek(cut.end);
        break;
      }
    }
  }

  void _setTrimStart() {
    if (!_isInitialized) return;

    setState(() {
      _trimStart = _position;
      if (_trimEnd != null && _trimStart! >= _trimEnd!) {
        _trimEnd = null;
      }
    });
  }

  void _setTrimEnd() {
    if (!_isInitialized) return;

    setState(() {
      _trimEnd = _position;
      if (_trimStart != null && _trimEnd! <= _trimStart!) {
        _trimStart = null;
      }
    });
  }

  void _addCut() {
    if (_trimStart != null && _trimEnd != null) {
      setState(() {
        _cutSections.add(TimeRange(start: _trimStart!, end: _trimEnd!));
        _cutSections.sort((a, b) => a.start.compareTo(b.start));
        _trimStart = null;
        _trimEnd = null;
      });
    }
  }

  void _undoLastCut() {
    if (_cutSections.isNotEmpty) {
      setState(() => _cutSections.removeLast());
    }
  }

  void _resetAll() {
    setState(() {
      _trimStart = null;
      _trimEnd = null;
      _cutSections.clear();
    });
  }

  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    final ms =
        (d.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return '$m:$s.$ms';
  }

  Duration _effectiveDuration() {
    var total = Duration.zero;
    for (var c in _cutSections) {
      total += c.end - c.start;
    }
    return _duration - total;
  }

  String _formatSeconds(Duration d) {
    return (d.inMilliseconds / 1000.0).toStringAsFixed(3);
  }

  Future<String> _getOutputPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final baseName = path.basenameWithoutExtension(widget.track.fileName);
    final extension = path.extension(widget.track.fileName);
    return '${directory.path}/${baseName}_edited_$timestamp$extension';
  }

  Future<void> _processAudio({bool replaceOriginal = false}) async {
    if (_cutSections.isEmpty) {
      _showError('No edits to save');
      return;
    }

    setState(() => _isProcessing = true);
    await widget.controller.player.pause();

    try {
      // For replacement, create a proper temp file with correct extension
      final String outputPath;
      if (replaceOriginal) {
        // Keep the same extension as the original file
        final extension = path.extension(widget.track.path);
        final directory = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        outputPath = '${directory.path}/temp_edit_$timestamp$extension';
      } else {
        outputPath = await _getOutputPath();
      }

      // Merge overlapping cut sections
      final mergedCuts = _mergeCutSections(_cutSections);

      if (mergedCuts.isEmpty) {
        setState(() => _isProcessing = false);
        _showError('No valid cuts to process');
        return;
      }

      // Build FFmpeg filter
      await widget.controller.player.stop();
      String selectFilter = await _buildFilterComplex(mergedCuts);

      if (selectFilter.isEmpty) {
        setState(() => _isProcessing = false);
        _showError('No valid segments to keep');
        return;
      }

      // Build command
      List<String> arguments = [
        '-i',
        widget.track.path,
        '-af',
        'aselect=\'$selectFilter\',asetpts=N/SR/TB',
        '-c:a',
        'aac',
        '-b:a',
        '128k',
        '-y',
        outputPath
      ];

      print('FFmpeg arguments: ${arguments.join(' ')}');

      // Execute with arguments array
      final session = await FFmpegKit.executeWithArguments(arguments);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        if (replaceOriginal) {
          // --- START OF CHANGED CODE ---
          try {
            // Find the index of the track we are editing
            final index = widget.controller.playlist.indexOf(widget.track);

            if (index != -1) {
              // Call the NEW safe method in the controller
              // passing the path of the temp file FFmpeg just created
              await widget.controller
                  .replaceTrackWithEditedFile(index, outputPath);

              // Delete the temp file generated by FFmpeg as we have copied it safely
              final tempFile = File(outputPath);
              if (await tempFile.exists()) {
                await tempFile.delete();
              }

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Audio replaced and saved safely!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } else {
              _showError('Track not found in playlist');
            }
          } catch (e) {
            print('Error replacing file: $e');
            _showError('Failed to replace original file: $e');
          }
        } else {
          // Add as new track (existing code is fine)
          final newTrack = AudioTrack(
            path: outputPath,
            fileName: path.basename(outputPath),
            artist: widget.track.artist,
            album: '${widget.track.album ?? "Unknown"} (Edited)',
          );

          widget.controller.addTrack(newTrack);

          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Edited audio saved as new track'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        final logs = await session.getLogsAsString();
        print('FFmpeg error: $logs');
        _showError('Failed to process audio');
      }
    } catch (e) {
      print('Error processing audio: $e');
      _showError('An error occurred while processing');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  List<TimeRange> _mergeCutSections(List<TimeRange> cuts) {
    if (cuts.isEmpty) return [];

    List<TimeRange> sorted = List.from(cuts)
      ..sort((a, b) => a.start.compareTo(b.start));

    List<TimeRange> merged = [sorted.first];

    for (int i = 1; i < sorted.length; i++) {
      final last = merged.last;
      final current = sorted[i];

      if (current.start <= last.end) {
        merged[merged.length - 1] = TimeRange(
          start: last.start,
          end: Duration(
            milliseconds: current.end.inMilliseconds > last.end.inMilliseconds
                ? current.end.inMilliseconds
                : last.end.inMilliseconds,
          ),
        );
      } else {
        merged.add(current);
      }
    }

    return merged;
  }

  Future<String> _buildFilterComplex(List<TimeRange> cuts) async {
    if (cuts.isEmpty) return '';

    List<String> segments = [];
    Duration currentPos = Duration.zero;

    for (var cut in cuts) {
      if (currentPos < cut.start) {
        segments.add(
            'between(t,${_formatSeconds(currentPos)},${_formatSeconds(cut.start)})');
      }
      currentPos = cut.end;
    }

    if (currentPos < _duration) {
      segments.add(
          'between(t,${_formatSeconds(currentPos)},${_formatSeconds(_duration)})');
    }

    if (segments.isEmpty) {
      return '';
    }

    return segments.join('+');
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showSaveDialog() {
    if (_cutSections.isEmpty) {
      _showError('No edits to save');
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Text('Save Edited Audio', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Summary:',
              style:
                  TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.content_cut, color: Colors.red, size: 16),
                      SizedBox(width: 8),
                      Text(
                        '${_cutSections.length} section${_cutSections.length > 1 ? 's' : ''} to remove',
                        style: TextStyle(color: Colors.white60, fontSize: 14),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Original: ${_format(_duration)}',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  Text(
                    'New: ${_format(_effectiveDuration())}',
                    style: TextStyle(
                        color: Colors.green,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'How would you like to save?',
              style:
                  TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _processAudio(replaceOriginal: true);
            },
            child: Text('Replace Original',
                style: TextStyle(color: Colors.orange)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _processAudio(replaceOriginal: false);
            },
            child: Text('Save as New', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Audio',
                style: TextStyle(color: Colors.white, fontSize: 18)),
            Text(
              widget.track.displayName,
              style: TextStyle(color: Colors.white60, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (_cutSections.isNotEmpty)
            TextButton(
              onPressed: _resetAll,
              child: Text('Reset', style: TextStyle(color: Colors.orange)),
            ),
          IconButton(
            icon: Icon(Icons.check, color: Colors.green),
            onPressed:
                _isProcessing || !_isInitialized ? null : _showSaveDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // Loading indicator if not initialized
                if (!_isInitialized)
                  LinearProgressIndicator(
                    color: Colors.deepPurpleAccent,
                    backgroundColor: Colors.white12,
                  ),

                // Waveform visualization - FIXED: Removed Expanded widget
                Container(
                  height: 120,
                  margin: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Stack(
                    children: [
                      if (_isInitialized) _buildWaveformView(),
                      if (_duration.inMilliseconds > 0)
                        Positioned(
                          left: (MediaQuery.of(context).size.width - 32) *
                              (_position.inMilliseconds /
                                  _duration.inMilliseconds),
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 2,
                            color: Colors.white,
                          ),
                        ),
                      if (!_isInitialized)
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                  color: Colors.deepPurpleAccent),
                              SizedBox(height: 16),
                              Text('Loading audio...',
                                  style: TextStyle(color: Colors.white54)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Time and controls
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Time labels
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_format(_position),
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          if (_cutSections.isNotEmpty)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_cutSections.length} cuts',
                                style:
                                    TextStyle(color: Colors.red, fontSize: 11),
                              ),
                            ),
                          Text(_format(_duration),
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),

                      // Progress slider
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.deepPurpleAccent,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: Colors.white,
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: _duration.inMilliseconds > 0
                              ? _position.inMilliseconds.toDouble()
                              : 0,
                          max: _duration.inMilliseconds.toDouble(),
                          onChangeStart: (_) {
                            // Pause updates during dragging
                            _stateSub?.pause();
                          },
                          onChanged: _isInitialized
                              ? (v) {
                                  // Update position immediately for smooth UI
                                  setState(() {
                                    _position =
                                        Duration(milliseconds: v.toInt());
                                  });
                                }
                              : null,
                          onChangeEnd: _isInitialized
                              ? (v) async {
                                  // Seek and resume updates
                                  await widget.controller.player
                                      .seek(Duration(milliseconds: v.toInt()));
                                  _stateSub?.resume();
                                }
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),

                // Selection info
                if (_trimStart != null || _trimEnd != null)
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepPurpleAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.content_cut,
                            color: Colors.deepPurpleAccent, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _trimStart != null && _trimEnd != null
                                ? 'Selection: ${_format(_trimStart!)} - ${_format(_trimEnd!)}'
                                : _trimStart != null
                                    ? 'Start: ${_format(_trimStart!)}'
                                    : 'End: ${_format(_trimEnd!)}',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.clear,
                              color: Colors.white54, size: 18),
                          onPressed: () => setState(() {
                            _trimStart = null;
                            _trimEnd = null;
                          }),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                // Playback controls
                Column(
                  children: [
                    // Coarse controls (10s)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(Icons.replay_10, color: Colors.white70),
                          iconSize: 32,
                          onPressed: _isInitialized
                              ? () {
                                  final newPos =
                                      _position - Duration(seconds: 10);
                                  widget.controller.player.seek(
                                      newPos < Duration.zero
                                          ? Duration.zero
                                          : newPos);
                                }
                              : null,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.deepPurpleAccent,
                                Colors.deepPurple.shade700
                              ],
                            ),
                          ),
                          child: IconButton(
                            icon: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white),
                            iconSize: 40,
                            onPressed: _isInitialized ? _togglePlay : null,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.forward_10, color: Colors.white70),
                          iconSize: 32,
                          onPressed: _isInitialized
                              ? () {
                                  final newPos =
                                      _position + Duration(seconds: 10);
                                  widget.controller.player.seek(
                                      newPos > _duration ? _duration : newPos);
                                }
                              : null,
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    // Fine controls (1s and 5s)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: _isInitialized
                              ? () {
                                  final newPos =
                                      _position - Duration(seconds: 5);
                                  widget.controller.player.seek(
                                      newPos < Duration.zero
                                          ? Duration.zero
                                          : newPos);
                                }
                              : null,
                          icon: Icon(Icons.fast_rewind, size: 16),
                          label: Text('-5s'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white60,
                            textStyle: TextStyle(fontSize: 12),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _isInitialized
                              ? () {
                                  final newPos =
                                      _position - Duration(seconds: 1);
                                  widget.controller.player.seek(
                                      newPos < Duration.zero
                                          ? Duration.zero
                                          : newPos);
                                }
                              : null,
                          icon: Icon(Icons.chevron_left, size: 16),
                          label: Text('-1s'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white60,
                            textStyle: TextStyle(fontSize: 12),
                          ),
                        ),
                        SizedBox(width: 20),
                        TextButton.icon(
                          onPressed: _isInitialized
                              ? () {
                                  final newPos =
                                      _position + Duration(seconds: 1);
                                  widget.controller.player.seek(
                                      newPos > _duration ? _duration : newPos);
                                }
                              : null,
                          icon: Icon(Icons.chevron_right, size: 16),
                          label: Text('+1s'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white60,
                            textStyle: TextStyle(fontSize: 12),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _isInitialized
                              ? () {
                                  final newPos =
                                      _position + Duration(seconds: 5);
                                  widget.controller.player.seek(
                                      newPos > _duration ? _duration : newPos);
                                }
                              : null,
                          icon: Icon(Icons.fast_forward, size: 16),
                          label: Text('+5s'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white60,
                            textStyle: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Edit controls
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isInitialized ? _setTrimStart : null,
                              icon: Icon(Icons.vertical_align_top, size: 18),
                              label: Text('Mark Start'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _trimStart != null
                                    ? Colors.green.withOpacity(0.3)
                                    : Colors.white.withOpacity(0.1),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    Colors.white.withOpacity(0.05),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isInitialized ? _setTrimEnd : null,
                              icon: Icon(Icons.vertical_align_bottom, size: 18),
                              label: Text('Mark End'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _trimEnd != null
                                    ? Colors.green.withOpacity(0.3)
                                    : Colors.white.withOpacity(0.1),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    Colors.white.withOpacity(0.05),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (_isInitialized &&
                                      _trimStart != null &&
                                      _trimEnd != null)
                                  ? _addCut
                                  : null,
                              icon: Icon(Icons.content_cut, size: 18),
                              label: Text('Cut Section'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.withOpacity(0.7),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    Colors.white.withOpacity(0.05),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  (_isInitialized && _cutSections.isNotEmpty)
                                      ? _undoLastCut
                                      : null,
                              icon: Icon(Icons.undo, size: 18),
                              label: Text('Undo Cut'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.withOpacity(0.7),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    Colors.white.withOpacity(0.05),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_cutSections.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'New duration: ${_format(_effectiveDuration())}',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Processing overlay
          if (_isProcessing)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 200,
                      child: Column(
                        children: [
                          CircularProgressIndicator(
                            value: _processingProgress > 0
                                ? _processingProgress
                                : null,
                            color: Colors.deepPurpleAccent,
                            backgroundColor: Colors.white12,
                          ),
                          SizedBox(height: 20),
                          Text(
                            'Processing audio...',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          SizedBox(height: 8),
                          Text(
                            _processingProgress > 0
                                ? '${(_processingProgress * 100).toInt()}%'
                                : 'Preparing...',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 14),
                          ),
                          if (_processingProgress > 0)
                            Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: LinearProgressIndicator(
                                value: _processingProgress,
                                backgroundColor: Colors.white12,
                                color: Colors.deepPurpleAccent,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWaveformView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: WaveformPainter(
            duration: _duration,
            trimStart: _trimStart,
            trimEnd: _trimEnd,
            cutSections: _cutSections,
          ),
        );
      },
    );
  }
}

class TimeRange {
  final Duration start;
  final Duration end;

  TimeRange({required this.start, required this.end});
}

class WaveformPainter extends CustomPainter {
  final Duration duration;
  final Duration? trimStart;
  final Duration? trimEnd;
  final List<TimeRange> cutSections;

  WaveformPainter({
    required this.duration,
    this.trimStart,
    this.trimEnd,
    required this.cutSections,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (duration.inMilliseconds == 0) return;

    final paint = Paint()
      ..color = Colors.deepPurpleAccent.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final barCount = 100;
    final barWidth = size.width / barCount;

    for (int i = 0; i < barCount; i++) {
      final x = i * barWidth;
      final progress = i / barCount;
      final time =
          Duration(milliseconds: (duration.inMilliseconds * progress).toInt());

      bool isCut = false;
      for (var cut in cutSections) {
        if (time >= cut.start && time <= cut.end) {
          isCut = true;
          break;
        }
      }

      bool isSelected = false;
      if (trimStart != null && trimEnd != null) {
        isSelected = time >= trimStart! && time <= trimEnd!;
      }

      if (isCut) {
        paint.color = Colors.red.withOpacity(0.3);
      } else if (isSelected) {
        paint.color = Colors.green.withOpacity(0.4);
      } else {
        paint.color = Colors.deepPurpleAccent.withOpacity(0.3);
      }

      final height = (20 + (i * 7 + i * i * 3) % 60) * size.height / 100;
      final y = (size.height - height) / 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 1, y, barWidth - 2, height),
          Radius.circular(2),
        ),
        paint,
      );
    }

    if (trimStart != null) {
      final x =
          size.width * (trimStart!.inMilliseconds / duration.inMilliseconds);
      final markerPaint = Paint()
        ..color = Colors.green
        ..strokeWidth = 2;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), markerPaint);
    }

    if (trimEnd != null) {
      final x =
          size.width * (trimEnd!.inMilliseconds / duration.inMilliseconds);
      final markerPaint = Paint()
        ..color = Colors.green
        ..strokeWidth = 2;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), markerPaint);
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) => true;
}
