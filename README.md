# easy_pip_plugin

A Flutter plugin that makes implementing **Picture-in-Picture (PiP) mode** simple and seamless for both Android and iOS.

## Features

- 📱 **Native PiP Support**: Smooth transition into Picture-in-Picture mode.
- ⚙️ **Easy Configuration**: Simple setup for native platforms with minimal code.
- 🔄 **State Lifecycle**: Listen to PiP enter/exit events inside your Flutter app.

---

## Platform Setup

To make Picture-in-Picture work correctly on mobile devices, you **must** configure the native files as shown below.

### 🤖 Android Configuration (`AndroidManifest.xml`)

Open your `android/app/src/main/AndroidManifest.xml` file. Locate the main `.MainActivity` tag and add the following attributes:

1. `android:supportsPictureInPicture="true"`
2. `android:configChanges="screenSize|smallestScreenSize|screenLayout|orientation"` (This prevents the activity from restarting when entering PiP mode).

**Example:**

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:theme="@style/LaunchTheme"
    android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
    android:hardwareAccelerated="true"
    android:windowSoftInputMode="adjustResize"
    android:supportsPictureInPicture="true"> <!-- Add this line -->
    
    <meta-data
      android:name="io.flutter.embedding.android.NormalTheme"
      android:resource="@style/NormalTheme"
      />
    <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>
</activity>
```

---

### 🍏 iOS Configuration (`Info.plist`)

For iOS, you need to enable Background Modes for audio and video playback, which is required for PiP to run when the app is in the background.

Open `ios/Runner/Info.plist` and add the following keys:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>processing</string>
</array>
```

> 💡 **Note:** If you are using Xcode, you can also enable this by going to your Target -> **Signing & Capabilities** -> click **+ Capability** -> select **Background Modes** -> check **Audio, AirPlay, and Picture in Picture**.

---

## Installation

Add `easy_pip_plugin` to your `pubspec.yaml` file:

```yaml
dependencies:
  easy_pip_plugin: ^0.0.2
```

Then run:
```bash
flutter pub get
```

---

## Usage

Here is a quick example of how to trigger Picture-in-Picture mode within your Flutter app.

```dart
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
    // FOR IOS : Experimental
    if (state == AppLifecycleState.paused) {
      _pipStartTime = DateTime.now();
      print("PiP started on: $_pipStartTime");
    }

    // MOMENT B: App keert terug naar de voorgrond (PiP sluit) -> bereken het exacte verschil!
    if (state == AppLifecycleState.resumed) {
      print("===========================================");
      print("FLUTTER LIFE-CYCLE: App recovered from PiP!");
      print("===========================================");

      if (_player != null && _pipStartTime != null) {
        final DateTime pipEndTime = DateTime.now();

        // Bereken exact hoeveel tijd er verstreken is (ongeacht of dit 3 seconden of 5 minuten is)
        final Duration elapsedPipTime = pipEndTime.difference(_pipStartTime!);

        final currentPosition = _player.state.position;
        final correctedPosition = currentPosition + elapsedPipTime;

        // Seek player to the correct position
        await _player.seek(correctedPosition);

        // Hard reboot VIDEO ENGINE:
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
      print("EasyPipPlugin: Dynamic URL : $_videoUrl");
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
                              label: const Text('Replay Video'),
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

``

---

## Additional Information

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com) on GitHub.
