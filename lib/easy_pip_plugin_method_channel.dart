import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'easy_pip_plugin_platform_interface.dart';

/// An implementation of [EasyPipPluginPlatform] that uses method channels.
class MethodChannelEasyPipPlugin extends EasyPipPluginPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('easy_pip_plugin');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
