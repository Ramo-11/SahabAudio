import 'package:audio_player_app/screens/playlist_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'controllers/audio_player_controller.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_player_app/services/audio_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(AudioPlayer()),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.sahabsolutions.audio_player',
      androidNotificationChannelName: 'Sahab Audio Player',
      androidNotificationOngoing: true,
    ),
  );

  runApp(AudioPlayerApp(audioHandler: audioHandler));
}

class AudioPlayerApp extends StatefulWidget {
  final AudioHandler audioHandler;

  const AudioPlayerApp({Key? key, required this.audioHandler})
      : super(key: key);

  @override
  _AudioPlayerAppState createState() => _AudioPlayerAppState();
}

class _AudioPlayerAppState extends State<AudioPlayerApp> {
  static const platform = MethodChannel('app.channel.shared.data');
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  late final AudioPlayerController _audioController;

  @override
  void initState() {
    super.initState();
    _audioController = AudioPlayerController(widget.audioHandler);
    _setupMethodChannel();
    _handleInitialSharedFiles();
    SharedFileHandler.instance.registerController(_audioController);
  }

  @override
  void dispose() {
    SharedFileHandler.instance.unregisterController();
    super.dispose();
  }

  void _setupMethodChannel() {
    platform.setMethodCallHandler((call) async {
      if (call.method == "onSharedFile") {
        final String? filePath = call.arguments as String?;
        if (filePath != null) {
          await _handleSharedFile(filePath);
        }
      }
    });
  }

  void _handleInitialSharedFiles() async {
    try {
      final dynamic sharedData = await platform.invokeMethod('getSharedData');

      if (sharedData is List) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          for (var filePath in sharedData) {
            if (filePath is String) {
              await _handleSharedFile(filePath);
            }
          }
        });
      }
    } on PlatformException catch (e) {
      print('Error getting shared data: ${e.message}');
    }
  }

  Future<void> _handleSharedFile(String filePath) async {
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adding audio file...'),
          backgroundColor: Color(0xFF8B5CF6),
          duration: Duration(seconds: 2),
        ),
      );
    }

    await SharedFileHandler.instance.handleSharedFile(filePath);

    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio added to library'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AudioPlayerController>.value(
      value: _audioController,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Sahab Audio',
        navigatorKey: navigatorKey,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF8B5CF6),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF0F0F1A),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        ),
        home: PlaylistScreen(controller: _audioController),
      ),
    );
  }
}

class SharedFileHandler {
  static SharedFileHandler? _instance;
  static SharedFileHandler get instance {
    _instance ??= SharedFileHandler._internal();
    return _instance!;
  }

  SharedFileHandler._internal();

  AudioPlayerController? _controller;
  final List<String> _pendingFiles = [];

  void registerController(AudioPlayerController controller) {
    _controller = controller;

    if (_pendingFiles.isNotEmpty) {
      for (String filePath in _pendingFiles) {
        _controller!.addSharedFile(filePath);
      }
      _pendingFiles.clear();
    }
  }

  void unregisterController() {
    _controller = null;
  }

  Future<void> handleSharedFile(String filePath) async {
    if (_controller != null) {
      await _controller!.addSharedFile(filePath);
    } else {
      _pendingFiles.add(filePath);
    }
  }
}
