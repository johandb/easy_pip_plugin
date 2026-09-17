export 'src/easy_pip_widget.dart';

import 'package:flutter/services.dart'; // VERPLICHT voor MethodChannel
import 'src/pip_api.g.dart';

class EasyPipPlugin {
  final _api = EasyPipApi();
  
  // De klassieke, onfeilbare MethodChannel brug
  static const MethodChannel _bridgeChannel = MethodChannel('com.jdbs.iptv.easy_pip_plugin.bridge');
  
  static void Function(bool isActive)? _onStatusChanged;
  static VoidCallback? _onPlayPauseTriggered;

  EasyPipPlugin() {
    EasyPipFlutterApi.setUp(_FlutterApiHandler());
    
    // Luister naar de handmatige native platform-thread signalen
    _bridgeChannel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'onPiPStatusChanged':
          final bool isActive = call.arguments as bool;
          if (_onStatusChanged != null) _onStatusChanged!(isActive);
          break;
        case 'onPlayPauseActionTriggered':
          if (_onPlayPauseTriggered != null) _onPlayPauseTriggered!();
          break;
      }
    });
  }

  Future<bool> isPiPSupported() async => _api.isPiPSupported();

  Future<void> enterPiP({required int width, required int height}) async {
    await _api.enterPiP(width, height);
  }

  Future<void> setupAutoPiP({required int width, required int height, required String urlStr}) async {
    await _api.setupAutoPiP(width, height, urlStr);
  }

  Future<PipStatus> getPiPStatus() async => _api.getPiPStatus();

  Future<void> updatePlaybackState(bool isPlaying) async {
    await _api.updatePlaybackState(isPlaying);
  }

  void setPipStatusListener(void Function(bool isActive) callback) {
    _onStatusChanged = callback;
  }

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

  @override
  void onPlayPauseActionTriggered() {
    if (EasyPipPlugin._onPlayPauseTriggered != null) {
      EasyPipPlugin._onPlayPauseTriggered!();
    }
  }
}
