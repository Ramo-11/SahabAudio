// widgets/album_art_widget.dart
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AlbumArtWidget extends StatelessWidget {
  final AnimationController rotationController;
  final AnimationController waveController;
  final AudioPlayer player;

  const AlbumArtWidget({
    Key? key,
    required this.rotationController,
    required this.waveController,
    required this.player,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Rotating album art
        AnimatedBuilder(
          animation: rotationController,
          builder: (context, child) {
            return Transform.rotate(
              angle: rotationController.value * 2 * 3.14159,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepPurple.shade300,
                      Colors.deepPurple.shade700,
                      Colors.indigo.shade800,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.music_note,
                  size: 80,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            );
          },
        ),
        
        SizedBox(height: 20),
        
        // Wave animation
        Container(
          height: 50,
          child: AnimatedBuilder(
            animation: waveController,
            builder: (context, child) {
              return StreamBuilder<PlayerState>(
                stream: player.playerStateStream,
                builder: (context, snapshot) {
                  final isPlaying = snapshot.data?.playing ?? false;
                  if (!isPlaying) return SizedBox.shrink();
                  
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final height = 20 + (30 * (waveController.value + index * 0.2) % 1);
                      return Container(
                        margin: EdgeInsets.symmetric(horizontal: 2),
                        width: 4,
                        height: height,
                        decoration: BoxDecoration(
                          color: Colors.deepPurpleAccent.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}