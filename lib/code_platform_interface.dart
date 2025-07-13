import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'code_method_channel.dart';

abstract class CodePlatform extends PlatformInterface {
  /// Constructs a CodePlatform.
  CodePlatform() : super(token: _token);

  static final Object _token = Object();

  static CodePlatform _instance = MethodChannelCode();

  /// The default instance of [CodePlatform] to use.
  ///
  /// Defaults to [MethodChannelCode].
  static CodePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [CodePlatform] when
  /// they register themselves.
  static set instance(CodePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
