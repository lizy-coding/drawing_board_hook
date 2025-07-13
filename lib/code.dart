
import 'code_platform_interface.dart';

class Code {
  Future<String?> getPlatformVersion() {
    return CodePlatform.instance.getPlatformVersion();
  }
}
