// widgets/progress_slider_widget.dart
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';

class ProgressSliderWidget extends StatefulWidget {
  final AudioPlayer player;
  final String Function(Duration) formatDuration;

  const ProgressSliderWidget({
    Key? key,
    required this.player,
    required this.formatDuration,
  }) : super(key: key);

  @override
  _ProgressSliderWidgetState createState() => _ProgressSliderWidgetState();
}

class _ProgressSliderWidgetState extends State<ProgressSliderWidget> {
  Timer? _seekTimer;
  bool _isDragging = false;
  double _dragValue = 0.0;

  void _onSliderChanged(double value) {
    setState(() {
      _isDragging = true;
      _dragValue = value;
    });

    _seekTimer?.cancel();
    _seekTimer = Timer(Duration(milliseconds: 200), () {
      widget.player.seek(Duration(milliseconds: value.toInt()));
      if (mounted) {
        setState(() {
          _isDragging = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _seekTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: widget.player.durationStream,
      builder: (context, snapshot) {
        final duration = snapshot.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: widget.player.positionStream,
          builder: (context, posSnapshot) {
            final position = posSnapshot.data ?? Duration.zero;
            final currentValue = _isDragging
                ? _dragValue
                : position.inMilliseconds
                    .clamp(0, duration.inMilliseconds)
                    .toDouble();

            return Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
                      overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
                    ),
                    child: Slider(
                      min: 0.0,
                      max: duration.inMilliseconds.toDouble(),
                      value: currentValue,
                      onChanged: _onSliderChanged,
                      activeColor: Colors.deepPurpleAccent,
                      inactiveColor: Colors.white24,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.formatDuration(position),
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        widget.formatDuration(duration),
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
