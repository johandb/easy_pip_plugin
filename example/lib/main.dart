import 'package:easy_pip_plugin/easy_pip_plugin.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

void main() {
  // Verplichte initialisatie voor Flutter en media_kit
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
  // 1. Initialiseer de media_kit componenten
  late final Player _player = Player();
  late final VideoController _videoController = VideoController(_player);

  // De IPTV demo video URL
  final String _videoUrl = 'https://www.jdbs.nl/iptv/movie/demo/demo/20301.mp4';

  // Status om de replay knop te tonen wanneer de video klaar is
  bool _isVideoCompleted = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    // Luister of de video het einde heeft bereikt voor de replay knop
    _player.stream.completed.listen((bool isCompleted) {
      if (mounted) {
        setState(() {
          _isVideoCompleted = isCompleted;
        });
      }
    });

    // Start de video direct op met de juiste User-Agent headers
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
    _player.dispose(); // Netjes afsluiten om geheugenlekken te voorkomen
    super.dispose();
  }

  /// Start de video opnieuw vanaf seconde nul
  Future<void> _restartVideo() async {
    await _player.seek(Duration.zero);
    await _player.play();
    setState(() {
      _isVideoCompleted = false;
    });
  }

  /// Handmatige trigger om naar PiP te gaan wanneer er op een knop wordt geklikt
  Future<void> _triggerManualPiP() async {
    final supported = await EasyPipPlugin().isPiPSupported();
    if (supported) {
      // Start PiP met de standaard 16:9 breedbeeldverhouding
      await EasyPipPlugin().enterPiP(width: 16, height: 9);
    }
  }

  @override
  Widget build(BuildContext context) {
    // We houden de MaterialApp als basis
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // HIER GEBRUIKEN WE HET GLOEDNIEUWE WIDGET UIT JE PLUGIN:
      home: EasyPipWidget(
        videoController: _videoController,
        pipWidth: 16,
        pipHeight: 9,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Easy PiP IPTV Player'),
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_in_picture_alt),
                onPressed: _triggerManualPiP,
                tooltip: 'Start PiP Modus',
              ),
            ],
          ),
          backgroundColor: Colors.black,
          body: Column(
            children: [
              // Videospeler in 16:9 verhouding met een replay overlay voor het grote scherm
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

              // Informatie en extra handmatige knop onder de video op het grote scherm
              Expanded(
                child: Container(
                  color: Colors.white,
                  width: double.infinity,
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                      const SizedBox(height: 16),
                      Text(
                        _isVideoCompleted ? 'De video is afgelopen!' : 'De IPTV demo video speelt nu af!',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Dankzij het EasyPipWidget schakelt deze app nu automatisch over naar pure video zodra PiP start.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: _triggerManualPiP,
                        icon: const Icon(Icons.picture_in_picture_alt),
                        label: const Text('Handmatig naar PiP Modus'),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
