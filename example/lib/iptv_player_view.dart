import 'package:easy_pip_plugin/easy_pip_plugin.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class IptvPlayerView extends StatefulWidget {
  final String streamUrl;

  const IptvPlayerView({super.key, required this.streamUrl});

  @override
  State<IptvPlayerView> createState() => _IptvPlayerViewState();
}

class _IptvPlayerViewState extends State<IptvPlayerView> {
  // Initialiseer de media_kit speler en de controller
  late final Player _player = Player();
  late final VideoController _videoController = VideoController(_player);

  // Initialiseer jouw eigen gemaakte PiP plugin
  final _pipPlugin = EasyPipPlugin();
  bool _isPiPActive = false;

  @override
  void initState() {
    super.initState();
    _initPlayerAndPiP();
  }

  Future<void> _initPlayerAndPiP() async {
    // 1. Luister naar statusveranderingen van de PiP-modus via Pigeon
    _pipPlugin.setPipStatusListener((bool isActive) {
      if (mounted) {
        setState(() {
          _isPiPActive = isActive;
        });
      }
    });

    // 2. Luister naar de status van de media_kit speler
    // We willen pas PiP activeren als de stream daadwerkelijk 'speelt' (playing == true)
    _player.stream.playing.listen((bool isPlaying) async {
      if (isPlaying) {
        final supported = await _pipPlugin.isPiPSupported();
        if (supported) {
          // Registreer de onzichtbare video-layer op iOS voor de automatische swipe-to-home
          // We gebruiken een standaard IPTV breedbeeldverhouding (16:9)
          await _pipPlugin.setupAutoPiP(width: 16, height: 9);
        }
      }
    });

    // 3. Open en start de IPTV live stream
    await _player.open(Media(widget.streamUrl));
  }

  @override
  Future<void> dispose() async {
    // Netjes de speler afsluiten om geheugenlekken te voorkomen
    await _player.dispose();
    super.dispose();
  }

  /// Handmatige trigger voor als de gebruiker op een PiP-knop in de UI klikt
  Future<void> _triggerManualPiP() async {
    final supported = await _pipPlugin.isPiPSupported();
    if (supported) {
      await _pipPlugin.enterPiP(width: 16, height: 9);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Als PiP actief is, tonen we ALLEEN de video zonder knoppen of AppBars
    if (_isPiPActive) {
      return Video(controller: _videoController);
    }

    // De normale weergave binnen de app (groot scherm)
    return Scaffold(
      appBar: AppBar(title: const Text('IPTV Live Stream')),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // De media_kit videospeler
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Video(controller: _videoController),
          ),

          // Bedieningselementen onder de video
          Expanded(
            child: Container(
              color: Colors.white,
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const Text(
                    'Je kijkt nu naar een live IPTV stream.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Swipe nu naar je homescherm of klik op de knop hieronder om Picture-in-Picture te testen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _triggerManualPiP,
                    icon: const Icon(Icons.picture_in_picture_alt),
                    label: const Text('Handmatig naar PiP Modus'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
