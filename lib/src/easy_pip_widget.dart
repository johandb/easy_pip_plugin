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
  
  /// Callback for status
  final void Function(bool isActive)? onPipStatusChanged;

  /// De hoogte-verhouding voor het PiP-venster (standaard 9).
  final int pipHeight;

  /// De url
  final String urlStr; 

  const EasyPipWidget({
    super.key,
    required this.videoController,
    required this.child,
    this.onPlayPauseToggle,
	this.onPipStatusChanged,
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

  // Lokaal beheer van de controller en unieke sleutel om exceptions te voorkomen
  late VideoController _currentController;
  int _videoWidgetKeyCounter = 0;
  DateTime? _pipStartTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentController = widget.videoController;

    // Luister naar de statusveranderingen vanuit de native OS-laag
    _pipPlugin.setPipStatusListener((bool isActive) async { // Maak hier async van
      if (mounted) {
        // GEFIXT VOOR IOS: Herstel de positie zodra PiP actief wordt op de achtergrond
        if (isActive && _pipStartTime != null) {
          final player = _currentController.player;

          final DateTime pipEndTime = DateTime.now();
          final Duration elapsedPipTime = pipEndTime.difference(_pipStartTime!);

          final currentPosition = player.state.position;
          // Bereken de gecorrigeerde positie (huidige positie + de tijd die het minimaliseren kostte)
          final correctedPosition = currentPosition + elapsedPipTime;

          // Forceer de native iOS speler direct naar de juiste milliseconde
          await player.seek(correctedPosition);
          await _pipPlugin.updatePlaybackState(true);
          await player.play();

          // Reset de starttijd zodat dit niet dubbel wordt uitgevoerd bij het openen van de app
          _pipStartTime = null;
        }

        setState(() {
          _isPiPActive = isActive;
        });
        if (widget.onPipStatusChanged != null) {
          widget.onPipStatusChanged!(isActive);
        }
      }
    });
  
    // Luister naar de native play/pause klik vanuit het Picture-in-Picture venster
    _pipPlugin.setPlayPauseActionListener(() {
      final player = _currentController.player;
      player.playOrPause();
      
      if (widget.onPlayPauseToggle != null) {
        widget.onPlayPauseToggle!(player.state.playing);
      }
    });

    // Luister naar de speler om de native knoppen up-to-date te houden en auto-PiP (iOS) in te stellen
    _currentController.player.stream.playing.listen((bool isPlaying) async {
      if (_isPiPActive) {
        await _pipPlugin.updatePlaybackState(isPlaying);
      }

      final supported = await _pipPlugin.isPiPSupported();
      // GEFIXT: Extra controle of de urlStr wel gevuld is en overeenkomt met een actieve stream
      if (isPlaying && supported && widget.urlStr.isNotEmpty) {
        await _pipPlugin.setupAutoPiP(
          width: widget.pipWidth,
          height: widget.pipHeight,
          urlStr: widget.urlStr,
        );
      }
    });  }

  @override
  void didUpdateWidget(covariant EasyPipWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Zorg dat updates van buitenaf (bijv. een compleet nieuwe stream) nog steeds doorkomen
    if (oldWidget.videoController != widget.videoController) {
      _currentController = widget.videoController;
    }

    // GEFIXT VOOR IOS: Als de URL verandert, direct de Auto-PiP native bijwerken
    if (oldWidget.urlStr != widget.urlStr && _currentController.player.state.playing) {
      _pipPlugin.setupAutoPiP(
        width: widget.pipWidth,
        height: widget.pipHeight,
        urlStr: widget.urlStr,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    // Schakel native PiP status-sync in
    if (state == AppLifecycleState.resumed) {
      _updateCurrentPiPStatus();
    }

    // GOUDEN TIME-TRACKER LOGICA (Nu veilig ingekapseld in het widget)
    if (state == AppLifecycleState.paused) {
      _pipStartTime = DateTime.now();
    }

    if (state == AppLifecycleState.resumed) {
      final player = _currentController.player;
      if (_pipStartTime != null) {
        final DateTime pipEndTime = DateTime.now();
        final Duration elapsedPipTime = pipEndTime.difference(_pipStartTime!);

        final currentPosition = player.state.position;
        final correctedPosition = currentPosition + elapsedPipTime;

        // Synchroniseer de track-positie
        await player.seek(correctedPosition);

        // Reset native iOS speler status
        await _pipPlugin.updatePlaybackState(true);

        // Start beeld direct live
        await player.play();

        // Voorkom de 'deactivated widget' ancestor crash via een post frame callback
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _videoWidgetKeyCounter++;
              _currentController = VideoController(player);
            });
          }
        });

        _pipStartTime = null;
      }
    }
  }

  Future<void> _updateCurrentPiPStatus() async {
    final status = await _pipPlugin.getPiPStatus();
    if (mounted) {
      final isActive = status.isActive ?? false;
      setState(() {
        _isPiPActive = isActive;
      });
      if (widget.onPipStatusChanged != null) {
        widget.onPipStatusChanged!(isActive); // NIEUW
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isPiPActive) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Video(
              key: ValueKey('media_kit_pip_$_videoWidgetKeyCounter'),
              controller: _currentController,
              controls: NoVideoControls,
            ),
          ],
        ),
      );
    }

    // We geven het child widget de mogelijkheid om altijd de meest actuele, 
    // gefixte controller te gebruiken via een handigheidje (indien nodig), 
    // maar voor jouw opzet bouwt hij nu stabiel door.
    return widget.child;
  }
}

