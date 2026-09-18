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

In your example/android/app/src/main/Manifest.xml add this code block to activate the buttons in the pip Windows

```
    <!-- Registered so Android knows where the clicks must going to -->
    <receiver 
        android:name="com.jdbs.iptv.easy_pip_plugin.PipActionReceiver"
        android:exported="true">
        <intent-filter>
            <action android:name="com.jdbs.iptv.easy_pip_plugin.ACTION_PLAY_PAUSE" />
        </intent-filter>
    </receiver>
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
  easy_pip_plugin: ^0.0.11
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

class _MyAppState extends State<MyApp> {
  late final Player _player = Player();
  late final VideoController _videoController = VideoController(_player);

  // Change to your url
  final String _videoUrl = 'https://my.stream.mp4';
  bool _isVideoCompleted = false;
  bool _isPiPSupported = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
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
      if (Theme.of(context).platform == TargetPlatform.iOS) {
        // GEFIXT VOOR IOS: Minimaliseer de app, iOS Auto-PiP handelt de rest flitsloos af!
        await EasyPipPlugin().minimizeApp();
      } else {
        // Voor Android behouden we de directe PiP-aanroep
        await EasyPipPlugin().enterPiP(width: 16, height: 9);
      }
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
            heroTag: null,
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
                      // Het widget handelt intern de engine-reboots en keys af, 
                      // dus we kunnen hier direct de basis controller meegeven.
                      Video(controller: _videoController),
                      if (_isVideoCompleted)
                        Container(
                          color: Colors.black.withValues(alpha: 0.6),
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
