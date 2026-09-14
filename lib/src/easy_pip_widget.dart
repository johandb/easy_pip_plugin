import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../easy_pip_plugin.dart';

/// Een herbruikbaar widget dat automatisch schakelt tussen de normale app-weergave
/// en een schone, geoptimaliseerde Picture-in-Picture modus zonder lay-outfouten.
class EasyPipWidget extends StatefulWidget {
  /// De videocontroller van media_kit die getoond moet worden.
  final VideoController videoController;

  /// De lay-out van je app wanneer deze op het grote scherm (normale modus) draait.
  final Widget child;

  /// Callback die wordt afgevuurd wanneer de video start of pauzeert.
  final void Function(bool isPlaying)? onPlayPauseToggle;

  /// De breedte-verhouding voor het PiP-venster (standaard 16).
  final int pipWidth;

  /// De hoogte-verhouding voor het PiP-venster (standaard 9).
  final int pipHeight;

  /// De url
  final String urlStr; 

  const EasyPipWidget({
    super.key,
    required this.videoController,
    required this.child,
    this.onPlayPauseToggle,
    this.pipWidth = 16,
    this.pipHeight = 9,
    required this.urlStr,
  });

  @override
  State<EasyPipWidget> createState() => _EasyPipWidgetState();
}

class _EasyPipWidgetState extends State<EasyPipWidget> with WidgetsBindingObserver {
  final _pipPlugin = EasyPipPlugin();
  bool _isPiPActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Luister naar de statusveranderingen vanuit de native OS-laag
    _pipPlugin.setPipStatusListener((bool isActive) {
      if (mounted) {
        setState(() {
          _isPiPActive = isActive;
        });
      }
    });

    // Luister naar de native play/pause klik vanuit het Picture-in-Picture venster
    _pipPlugin.setPlayPauseActionListener(() {
      final player = widget.videoController.player;
      player.playOrPause();
      
      // Vuur optionele callback af naar de hoofd-app indien gewenst
      if (widget.onPlayPauseToggle != null) {
        widget.onPlayPauseToggle!(player.state.playing);
      }
    });

    // Luister naar de speler om de native knoppen up-to-date te houden en auto-PiP (iOS) in te stellen
    widget.videoController.player.stream.playing.listen((bool isPlaying) async {
      if (_isPiPActive) {
        await _pipPlugin.updatePlaybackState(isPlaying);
      }
      
      final supported = await _pipPlugin.isPiPSupported();
      if (isPlaying && supported) {
        await _pipPlugin.setupAutoPiP(width: widget.pipWidth, height: widget.pipHeight, urlStr: widget.urlStr);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateCurrentPiPStatus();
    }
  }

  Future<void> _updateCurrentPiPStatus() async {
    final status = await _pipPlugin.getPiPStatus();
    if (mounted) {
      setState(() {
        _isPiPActive = status.isActive;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Als PiP actief is, omzeilen we de normale app-lay-out en tonen we pure video
    if (_isPiPActive) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Video(
              controller: widget.videoController,
              controls: NoVideoControls, // Geen verborgen controls om 4-pixel overflows te voorkomen
            ),
          ],
        ),
      );
    }

    // Anders tonen we gewoon de normale app-interface
    return widget.child;
  }
}
