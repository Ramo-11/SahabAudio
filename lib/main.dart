// main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/launch_screen.dart';
import 'controllers/audio_player_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AudioPlayerApp());
}

class AudioPlayerApp extends StatefulWidget {
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
    _audioController = AudioPlayerController();
    _setupMethodChannel();
    _handleInitialSharedFiles();

    // Register controller with shared file handler
    SharedFileHandler.instance.registerController(_audioController);
  }

  @override
  void dispose() {
    SharedFileHandler.instance.unregisterController();
    super.dispose();
  }

  void _setupMethodChannel() {
    // Set up method channel to receive shared files from iOS
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
      final String? sharedFilePath =
          await platform.invokeMethod('getSharedData');
      if (sharedFilePath != null && sharedFilePath.isNotEmpty) {
        // Wait for the app to fully load, then handle the shared file
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleSharedFile(sharedFilePath);
        });
      }
    } on PlatformException catch (e) {
      print('Error getting shared data: ${e.message}');
    }
  }

  Future<void> _handleSharedFile(String filePath) async {
    // Show immediate feedback
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice memo received! Adding to playlist...'),
          backgroundColor: Colors.deepPurpleAccent,
          duration: Duration(seconds: 2),
        ),
      );
    }

    // Use the SharedFileHandler singleton to process the file
    await SharedFileHandler.instance.handleSharedFile(filePath);

    // Show success feedback
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice memo added to playlist successfully!'),
          backgroundColor: Colors.green,
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
        title: 'Sahab Audio Player',
        navigatorKey: navigatorKey,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        ),
        home: LaunchScreen(),
      ),
    );
  }
}

// Singleton class to help with global controller access
class SharedFileHandler {
  static SharedFileHandler? _instance;
  static SharedFileHandler get instance {
    _instance ??= SharedFileHandler._internal();
    return _instance!;
  }

  SharedFileHandler._internal();

  AudioPlayerController? _controller;
  List<String> _pendingFiles = [];

  void registerController(AudioPlayerController controller) {
    _controller = controller;

    // Process any pending shared files
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
