// widgets/volume_speed_controls.dart
import 'package:flutter/material.dart';
import '../../controllers/audio_player_controller.dart';

class VolumeSpeedControls extends StatelessWidget {
  final AudioPlayerController controller;

  const VolumeSpeedControls({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return Column(
          children: [
            // Volume control
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.volume_down, color: Colors.white70),
                  Expanded(
                    child: Slider(
                      value: controller.volume,
                      onChanged: controller.setVolume,
                      activeColor: Colors.deepPurpleAccent,
                      inactiveColor: Colors.white24,
                    ),
                  ),
                  Icon(Icons.volume_up, color: Colors.white70),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Speed control
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.speed, color: Colors.white70),
                  Expanded(
                    child: Slider(
                      min: 0.25,
                      max: 3.0,
                      divisions: 11,
                      value: controller.speed,
                      label: '${controller.speed.toStringAsFixed(2)}x',
                      onChanged: controller.setSpeed,
                      activeColor: Colors.greenAccent,
                      inactiveColor: Colors.white24,
                    ),
                  ),
                  Text(
                    '${controller.speed.toStringAsFixed(1)}x',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
