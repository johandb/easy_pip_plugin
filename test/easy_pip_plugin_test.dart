import 'package:flutter_test/flutter_test.dart';
import 'package:easy_pip_plugin/easy_pip_plugin.dart';
import 'package:easy_pip_plugin/easy_pip_plugin_platform_interface.dart';
import 'package:easy_pip_plugin/easy_pip_plugin_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockEasyPipPluginPlatform
    with MockPlatformInterfaceMixin
    implements EasyPipPluginPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final EasyPipPluginPlatform initialPlatform = EasyPipPluginPlatform.instance;

  test('$MethodChannelEasyPipPlugin is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelEasyPipPlugin>());
  });

  test('getPlatformVersion', () async {
    EasyPipPlugin easyPipPlugin = EasyPipPlugin();
    MockEasyPipPluginPlatform fakePlatform = MockEasyPipPluginPlatform();
    EasyPipPluginPlatform.instance = fakePlatform;

    expect(await easyPipPlugin.getPlatformVersion(), '42');
  });
}
