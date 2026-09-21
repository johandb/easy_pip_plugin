import 'dart:async';
import 'dart:io';
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

  // StreamSubscriptions om netjes op te ruimen bij controller wissels of dispose
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _positionSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentController = widget.videoController;
    _initListeners();
  }

  void _initListeners() {
    // Ruim eventuele oude streams op bij een her-initialisatie
    _playingSub?.cancel();
    _positionSub?.cancel();

    // Luister naar de statusveranderingen vanuit de native OS-laag
    _pipPlugin.setPipStatusListener((bool isActive) async {
      if (mounted) {
        setState(() {
          _isPiPActive = isActive;
        });
        if (widget.onPipStatusChanged != null) {
          widget.onPipStatusChanged!(isActive);
        }
      }
    });

    // Luister naar de native play/pause klik vanuit het Picture-in-Picture venster
    _pipPlugin.setPlayPauseActionListener(() async {
      final player = _currentController.player;
      
      // Bereken direct de beoogde nieuwe status (omdraaien huidige status)
      final futurePlayingState = !player.state.playing;
      
      // Schakel de speler om
      await player.playOrPause();

      // Op Android dwingen we direct een native UI-update af zodat het icoon direct meeverandert
      if (Platform.isAndroid) {
        await _pipPlugin.updatePlaybackState(futurePlayingState);
      }

      if (widget.onPlayPauseToggle != null) {
        widget.onPlayPauseToggle!(futurePlayingState);
      }
    });

    // Luister naar de speler om de native knoppen up-to-date te houden en auto-PiP in te stellen
    _playingSub = _currentController.player.stream.playing.listen((bool isPlaying) {
      _syncNativePiP(isFromPositionStream: false);
    });

    // Luister ook naar positieveranderingen om de native iOS speler constant te voeden
    _positionSub = _currentController.player.stream.position.listen((Duration position) {
      if (_currentController.player.state.playing) {
        _syncNativePiP(isFromPositionStream: true);
      }
    });
  }

  void _syncNativePiP({bool isFromPositionStream = false}) async {
    // CRUCIAL ANDROID FIX: Voorkom dat Android continu overspoeld wordt met setupAutoPiP parameters.
    // Dit breekt anders de native toggle-animaties en stabiliteit van de RemoteActions.
    if (Platform.isAndroid && isFromPositionStream) {
      return;
    }

    final supported = await _pipPlugin.isPiPSupported();
    if (supported && widget.urlStr.isNotEmpty) {
      final currentPositionInSeconds = _currentController.player.state.position.inSeconds.toDouble();

      await _pipPlugin.setupAutoPiP(
        width: widget.pipWidth,
        height: widget.pipHeight,
        urlStr: widget.urlStr,
        startTimeInSeconds: currentPositionInSeconds,
      );
    }
  }

  @override
  void didUpdateWidget(covariant EasyPipWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoController != widget.videoController) {
      _currentController = widget.videoController;
      _initListeners(); // Herinitialiseer streams voor de nieuwe controller
    }

    if ((oldWidget.urlStr != widget.urlStr || oldWidget.videoController != widget.videoController) &&
        _currentController.player.state.playing) {
      _syncNativePiP(isFromPositionStream: false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playingSub?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      await _updateCurrentPiPStatus();

      final player = _currentController.player;

      // GEFIXT VOOR MEDIA_KIT + IOS: Geef de libmpv-laag een fractie van een seconde de tijd
      // om stabiel te initialiseren na een koude app-wissel vanuit de achtergrond.
      await Future.delayed(const Duration(milliseconds: 100));

      // GEFIXT VOOR IOS: Haal de exacte tijd op waar de native iOS PiP-speler is gebleven
      final nativeStatus = await _pipPlugin.getPiPStatus();
      if (nativeStatus.lastPositionSeconds != null && nativeStatus.lastPositionSeconds! > 0) {
        // Synchroniseer de Flutter-speler direct met de native tijd (VÓÓR player.play)
        await player.seek(Duration(seconds: nativeStatus.lastPositionSeconds!.toInt()));
      }

      // Reset native iOS speler status en start beeld live
      await _pipPlugin.updatePlaybackState(true);
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
        widget.onPipStatusChanged!(isActive);
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

    return widget.child;
  }
}
