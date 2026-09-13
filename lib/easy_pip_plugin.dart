export 'src/easy_pip_widget.dart';

import 'dart:ui';
import 'src/pip_api.g.dart';

class EasyPipPlugin {
  final _api = EasyPipApi();
  
  // Statische callbacks zodat de losstaande _FlutterApiHandler klasse erbij kan
  static void Function(bool isActive)? _onStatusChanged;
  static VoidCallback? _onPlayPauseTriggered;

  EasyPipPlugin() {
    // Registreer de API handler eenmalig bij het aanmaken van de plugin
    EasyPipFlutterApi.setUp(_FlutterApiHandler());
  }

  Future<bool> isPiPSupported() async => _api.isPiPSupported();

  Future<void> enterPiP({required int width, required int height}) async {
    await _api.enterPiP(width, height);
  }

  Future<void> setupAutoPiP({required int width, required int height}) async {
    await _api.setupAutoPiP(width, height);
  }

  Future<PipStatus> getPiPStatus() async => _api.getPiPStatus();

  // NIEUW: Sluis de afspeelstatus door naar de Native Host API via Pigeon
  Future<void> updatePlaybackState(bool isPlaying) async {
    await _api.updatePlaybackState(isPlaying);
  }

  void setPipStatusListener(void Function(bool isActive) callback) {
    _onStatusChanged = callback;
  }

  // NIEUW: Sla de luisteraar voor de native play/pause klik statisch op
  void setPlayPauseActionListener(VoidCallback callback) {
    _onPlayPauseTriggered = callback;
  }
}

class _FlutterApiHandler implements EasyPipFlutterApi {
  @override
  void onPiPStatusChanged(bool isActive) {
    if (EasyPipPlugin._onStatusChanged != null) {
      EasyPipPlugin._onStatusChanged!(isActive);
    }
  }

  // FIX: Implementeer de missende Pigeon methode die de compilerfout gaf!
  @override
  void onPlayPauseActionTriggered() {
    if (EasyPipPlugin._onPlayPauseTriggered != null) {
      EasyPipPlugin._onPlayPauseTriggered!();
    }
  }
}
