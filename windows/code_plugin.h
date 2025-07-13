#ifndef FLUTTER_PLUGIN_CODE_PLUGIN_H_
#define FLUTTER_PLUGIN_CODE_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace code {

class CodePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  CodePlugin();

  virtual ~CodePlugin();

  // Disallow copy and assign.
  CodePlugin(const CodePlugin&) = delete;
  CodePlugin& operator=(const CodePlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace code

#endif  // FLUTTER_PLUGIN_CODE_PLUGIN_H_
