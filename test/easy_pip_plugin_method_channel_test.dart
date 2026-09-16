import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_pip_plugin/easy_pip_plugin_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelEasyPipPlugin platform = MethodChannelEasyPipPlugin();
  const MethodChannel channel = MethodChannel('easy_pip_plugin');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return '42';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
