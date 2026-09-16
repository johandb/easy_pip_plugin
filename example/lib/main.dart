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

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final Player _player = Player();
  late VideoController _videoController = VideoController(_player);

  final String _videoUrl = 'https://www.jdbs.nl/iptv/movie/demo/demo/20301.mp4';
  bool _isVideoCompleted = false;
  bool _isPiPSupported = false;

  int _videoWidgetKeyCounter = 0;

  // GOUDEN TIME-TRACKER TIMERS:
  DateTime? _pipStartTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPlayer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    // MOMENT A: App gaat naar de achtergrond (PiP start) -> start de stopwatch!
    if (state == AppLifecycleState.paused) {
      _pipStartTime = DateTime.now();
      print("PiP gestart op: $_pipStartTime");
    }

    // MOMENT B: App keert terug naar de voorgrond (PiP sluit) -> bereken het exacte verschil!
    if (state == AppLifecycleState.resumed) {
      print("========================================");
      print("FLUTTER LIFE-CYCLE: App hersteld uit PiP!");
      print("========================================");

      if (_player != null && _pipStartTime != null) {
        final DateTime pipEndTime = DateTime.now();

        // Bereken exact hoeveel tijd er verstreken is (ongeacht of dit 3 seconden of 5 minuten is)
        final Duration elapsedPipTime = pipEndTime.difference(_pipStartTime!);

        final currentPosition = _player.state.position;
        final correctedPosition = currentPosition + elapsedPipTime;

        print("========================================");
        print("PiP is exact ${elapsedPipTime.inSeconds} seconden actief geweest.");
        print("Flutter player springt vooruit van $currentPosition naar: $correctedPosition");
        print("========================================");

        // 1. Spoel de Flutter player exact vooruit met de verstreken tijd
        await _player.seek(correctedPosition);

        // 2. HARD REBOOT VAN DE FLUTTER VIDEO ENGINE:
        setState(() {
          _videoWidgetKeyCounter++;
          _videoController = VideoController(_player);
        });

        // 3. Reset de native iOS speler status zodat de VOLGENDE PiP ook direct automatisch start!
        await EasyPipPlugin().updatePlaybackState(true);

        // 4. Start het beeld direct live op het hoofdscherm
        await _player.play();

        // Reset de timer voor een volgende PiP-sessie
        _pipStartTime = null;
      }
    }
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

    if (_isPiPSupported) {
      print("EasyPipPlugin: Dynamische URL doorgeven : $_videoUrl");
      await EasyPipPlugin().setupAutoPiP(width: 16, height: 9, urlStr: _videoUrl);
    }
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
        urlStr: _videoUrl,
        child: Scaffold(
          appBar: AppBar(title: const Text('Easy PiP IPTV Player'), centerTitle: true),
          backgroundColor: Colors.black,

          floatingActionButton: FloatingActionButton(
            onPressed: _triggerManualPiP,
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
                      Video(key: ValueKey('media_kit_video_$_videoWidgetKeyCounter'), controller: _videoController),
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
                        'Press the yellow button!',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
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
