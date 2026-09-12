import 'src/pip_api.g.dart';

class EasyPipPlugin {
  final _api = EasyPipApi();
  static void Function(bool isActive)? _onStatusChanged;

  EasyPipPlugin() {
    EasyPipFlutterApi.setUp(_FlutterApiHandler());
  }

  Future<bool> isPiPSupported() async => _api.isPiPSupported();

  Future<void> enterPiP({required int width, required int height}) async {
    await _api.enterPiP(width, height);
  }

  // NIEUW: Roep dit aan zodra je media_kit IPTV stream start op iOS
  Future<void> setupAutoPiP({required int width, required int height}) async {
    await _api.setupAutoPiP(width, height);
  }

  Future<PipStatus> getPiPStatus() async => _api.getPiPStatus();

  void setPipStatusListener(void Function(bool isActive) callback) {
    _onStatusChanged = callback;
  }
}

class _FlutterApiHandler implements EasyPipFlutterApi {
  @override
  void onPiPStatusChanged(bool isActive) {
    if (EasyPipPlugin._onStatusChanged != null) {
      EasyPipPlugin._onStatusChanged!(isActive);
    }
  }
}
