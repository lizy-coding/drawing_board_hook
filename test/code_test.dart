import 'package:flutter_test/flutter_test.dart';
import 'package:code/code.dart';
import 'package:code/code_platform_interface.dart';
import 'package:code/code_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockCodePlatform
    with MockPlatformInterfaceMixin
    implements CodePlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final CodePlatform initialPlatform = CodePlatform.instance;

  test('$MethodChannelCode is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelCode>());
  });

  test('getPlatformVersion', () async {
    Code codePlugin = Code();
    MockCodePlatform fakePlatform = MockCodePlatform();
    CodePlatform.instance = fakePlatform;

    expect(await codePlugin.getPlatformVersion(), '42');
  });
}
