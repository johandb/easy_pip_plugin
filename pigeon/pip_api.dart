//import 'package:pigeon/pigeon.dart';
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/pip_api.g.dart',
  dartPackageName: 'easy_pip_plugin',
  kotlinOut: 'android/src/main/kotlin/com/jdbs/iptv/easy_pip_plugin/PipApi.g.kt',
  kotlinOptions: KotlinOptions(package: 'com.jdbs.iptv.easy_pip_plugin'),
  swiftOut: 'ios/Classes/PipApi.g.swift',
))

class PipStatus {
  bool isSupported;
  bool isActive;
}

// Communicatie van Flutter naar Native (Host)
@HostApi()
abstract class EasyPipApi {
  bool isPiPSupported();
  void enterPiP(int width, int height);
  PipStatus getPiPStatus();
  
  // NIEUW: Bereidt iOS voor op automatisch in PiP gaan bij swipen naar home
  void setupAutoPiP(int width, int height); 
}

// Communicatie van Native naar Flutter (Events)
@FlutterApi()
abstract class EasyPipFlutterApi {
  void onPiPStatusChanged(bool isActive);
}
