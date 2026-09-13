import 'package:easy_pip_plugin/easy_pip_plugin.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final Player _player = Player();
  late final VideoController _videoController = VideoController(_player);

  final String _videoUrl = 'https://www.jdbs.nl/iptv/movie/demo/demo/20301.mp4';
  bool _isVideoCompleted = false;
  bool _isPiPSupported = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final supported = await EasyPipPlugin().isPiPSupported();
    if (mounted) {
      setState(() {
        _isPiPSupported = supported;
      });
    }

    _player.stream.completed.listen((bool isCompleted) {
      if (mounted) {
        setState(() {
          _isVideoCompleted = isCompleted;
        });
      }
    });

    await _player.open(
      Media(
        _videoUrl,
        httpHeaders: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': '*/*',
        },
      ),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _restartVideo() async {
    await _player.seek(Duration.zero);
    await _player.play();
    setState(() {
      _isVideoCompleted = false;
    });
  }

  Future<void> _triggerManualPiP() async {
    if (_isPiPSupported) {
      await EasyPipPlugin().enterPiP(width: 16, height: 9);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: EasyPipWidget(
        videoController: _videoController,
        pipWidth: 16,
        pipHeight: 9,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Easy PiP IPTV Player'),
          ),
          backgroundColor: Colors.black,

          // HIER IS JOUW GELE PIP-KNOP WEER RETOUR:
          floatingActionButton: FloatingActionButton(
            onPressed: _triggerManualPiP, // Activeer direct de enterPiP() uit je Swift-laag
            tooltip: 'Start PiP Modus',
            backgroundColor: Colors.amber,
            child: const Icon(Icons.picture_in_picture_alt, color: Colors.black),
          ),

          body: SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    children: [
                      Video(controller: _videoController),
                      if (_isVideoCompleted)
                        Container(
                          color: Colors.black.withOpacity(0.6),
                          child: Center(
                            child: ElevatedButton.icon(
                              onPressed: _restartVideo,
                              icon: const Icon(Icons.replay),
                              label: const Text('Video opnieuw afspelen'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  color: Colors.white,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app, size: 48, color: Colors.amber),
                      SizedBox(height: 16),
                      Text(
                        'Druk op de gele knop rechtsonder!',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
