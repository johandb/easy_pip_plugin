import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'easy_pip_plugin_method_channel.dart';

abstract class EasyPipPluginPlatform extends PlatformInterface {
  /// Constructs a EasyPipPluginPlatform.
  EasyPipPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static EasyPipPluginPlatform _instance = MethodChannelEasyPipPlugin();

  /// The default instance of [EasyPipPluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelEasyPipPlugin].
  static EasyPipPluginPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [EasyPipPluginPlatform] when
  /// they register themselves.
  static set instance(EasyPipPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
