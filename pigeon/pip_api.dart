import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/pip_api.g.dart',
  dartPackageName: 'easy_pip_plugin',
  kotlinOut: 'android/src/main/kotlin/com/jdbs/iptv/easy_pip_plugin/PipApi.g.kt',
  kotlinOptions: KotlinOptions(package: 'com.jdbs.iptv.easy_pip_plugin'),
  swiftOut: 'ios/Classes/PipApi.g.swift',
))

class PipStatus {
  bool? isSupported;
  bool? isActive;
  double? lastPositionSeconds; // NIEUW: Stuurt de afspeeltijd van iOS terug naar Flutter
}

// Communicatie van Flutter naar Native (Host)
@HostApi()
abstract class EasyPipApi {
  bool isPiPSupported();
  void enterPiP(int width, int height);
  PipStatus getPiPStatus();
  
  // GEUPDATE: startTimeInSeconds toegevoegd om de starttijd native te synchroniseren
  void setupAutoPiP(int width, int height, String urlStr, double startTimeInSeconds); 
  
  void minimizeApp();
  
  // NIEUW: Geef de huidige afspeelstatus door aan Native voor de juiste knoppen (play vs pause)
  void updatePlaybackState(bool isPlaying);
}

// Communicatie van Native naar Flutter (Events)
@FlutterApi()
abstract class EasyPipFlutterApi {
  void onPiPStatusChanged(bool isActive);

  // NIEUW: Native meldt aan Flutter dat de gebruiker op de PiP-systeemknop heeft geklikt
  void onPlayPauseActionTriggered();
}

