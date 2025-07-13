#include "include/code/code_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "code_plugin.h"

void CodePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  code::CodePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
