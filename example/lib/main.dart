import 'package:easy_pip_plugin/easy_pip_plugin.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _pipPlugin = EasyPipPlugin();
  bool _isPiPSupported = false;
  bool _isPiPActive = false;

  @override
  void initState() {
    super.initState();
    // Registreer de lifecycle observer om te luisteren naar app-resumes (maximaliseren)
    WidgetsBinding.instance.addObserver(this);
    _checkPiPSupport();

    // Luister naar statusveranderingen vanuit de native Kotlin laag
    _pipPlugin.setPipStatusListener((bool isActive) {
      if (mounted) {
        setState(() {
          _isPiPActive = isActive;
        });
      }
    });
  }

  @override
  void dispose() {
    // Netjes de observer verwijderen wanneer de state vernietigd wordt
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Dubbelcheck de PiP-status zodra de gebruiker de app weer volledig opent
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateCurrentPiPStatus();
    }
  }

  Future<void> _checkPiPSupport() async {
    final supported = await _pipPlugin.isPiPSupported();
    if (mounted) {
      setState(() {
        _isPiPSupported = supported;
      });
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

  Future<void> _triggerPiP() async {
    if (_isPiPSupported) {
      // We starten PiP met een 16:9 breedbeeldverhouding (ideaal voor IPTV)
      await _pipPlugin.enterPiP(width: 16, height: 9);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        // Verberg de AppBar automatisch als we in het kleine PiP-venster zitten
        appBar: _isPiPActive ? null : AppBar(title: const Text('Easy PiP IPTV Test')),
        body: Center(
          child: _isPiPActive
              ? const PipVideoView() // De compacte UI voor binnen het kleine PiP-venster
              : MainAppView(isSupported: _isPiPSupported, onEnterPiP: _triggerPiP),
        ),
      ),
    );
  }
}

/// De weergave wanneer de app in normale modus (groot scherm) draait
class MainAppView extends StatelessWidget {
  final bool isSupported;
  final VoidCallback onEnterPiP;

  const MainAppView({super.key, required this.isSupported, required this.onEnterPiP});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSupported ? Icons.check_circle_outline : Icons.error_outline,
            size: 80,
            color: isSupported ? Colors.green : Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            isSupported ? 'Picture-in-Picture wordt ondersteund!' : 'PiP is NIET ondersteund op dit toestel.',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Tip: Je kunt op de knop drukken óf direct naar je homescherm swipen om PiP te testen.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: isSupported ? onEnterPiP : null,
            icon: const Icon(Icons.picture_in_picture_alt),
            label: const Text('Enter PiP Mode'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          ),
        ],
      ),
    );
  }
}

/// De compacte weergave speciaal voor binnen het kleine PiP-venster
class PipVideoView extends StatelessWidget {
  const PipVideoView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tv, color: Colors.white, size: 40),
            SizedBox(height: 8),
            Text('IPTV Stream Actief...', style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
