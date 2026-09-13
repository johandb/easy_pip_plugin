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
          appBar: AppBar(title: const Text('Easy PiP IPTV Player')),
          backgroundColor: Colors.black,

          // De FloatingActionButton blijft behouden voor handmatige PiP activatie
          floatingActionButton: _isPiPSupported
              ? FloatingActionButton(
                  onPressed: _triggerManualPiP,
                  tooltip: 'Start PiP Modus',
                  backgroundColor: Colors.amber,
                  child: const Icon(Icons.picture_in_picture_alt, color: Colors.black),
                )
              : null,

          // FIX VOOR DE RENDERFLEX OVERFLOW: De hoofd-body is nu een ListView
          body: SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // 1. De Video-sectie (blijft netjes 16:9)
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
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // 2. De Informatie-sectie onder de video (krijgt een witte achtergrond)
                Container(
                  color: Colors.white,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.screen_rotation, size: 48, color: Colors.green),
                      const SizedBox(height: 16),
                      Text(
                        _isVideoCompleted ? 'De video is afgelopen!' : 'De IPTV demo video speelt nu af!',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'De interface maakt nu gebruik van een ListView in plaats van een vaste Column. '
                        'Hierdoor schuift de tekst in landscape-modus netjes onder het scherm en is de overflow-fout permanent opgelost.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
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
