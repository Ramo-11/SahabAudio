// widgets/control_buttons_widget.dart
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../controllers/audio_player_controller.dart';

class ControlButtonsWidget extends StatelessWidget {
  final AudioPlayerController controller;

  const ControlButtonsWidget({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: controller.player.playerStateStream,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;
        final processingState =
            snapshot.data?.processingState ?? ProcessingState.idle;

        return ListenableBuilder(
          listenable: controller,
          builder: (context, child) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Previous track
                IconButton(
                  icon: Icon(Icons.skip_previous, size: 36),
                  color: controller.playlist.length > 1
                      ? Colors.white
                      : Colors.white38,
                  onPressed: controller.playlist.length > 1
                      ? controller.playPrevious
                      : null,
                ),

                // Rewind 15 seconds
                IconButton(
                  icon: Icon(Icons.replay_10, size: 32),
                  color: Colors.white70,
                  onPressed: () {
                    final newPosition =
                        controller.player.position - Duration(seconds: 10);
                    controller.player.seek(newPosition < Duration.zero
                        ? Duration.zero
                        : newPosition);
                  },
                ),

                // Play/Pause with loading indicator
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.deepPurpleAccent, Colors.purpleAccent],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurpleAccent.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: processingState == ProcessingState.loading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            playing ? Icons.pause : Icons.play_arrow,
                            size: 36,
                            color: Colors.white,
                          ),
                    onPressed: controller.currentTrack != null
                        ? () => playing
                            ? controller.player.pause()
                            : controller.player.play()
                        : null,
                  ),
                ),

                // Forward 10 seconds
                IconButton(
                  icon: Icon(Icons.forward_10, size: 32),
                  color: Colors.white70,
                  onPressed: () {
                    final duration =
                        controller.player.duration ?? Duration.zero;
                    final newPosition =
                        controller.player.position + Duration(seconds: 10);
                    controller.player
                        .seek(newPosition > duration ? duration : newPosition);
                  },
                ),

                // Next track
                IconButton(
                  icon: Icon(Icons.skip_next, size: 36),
                  color: controller.playlist.length > 1
                      ? Colors.white
                      : Colors.white38,
                  onPressed: controller.playlist.length > 1
                      ? controller.playNext
                      : null,
                ),
              ],
            );
          },
        );
      },
    );
  }
}
