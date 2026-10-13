#pragma once

#include "napi/native_api.h"

using NativeWidgetUpdateCallback = void (*)(int);
using SetNativeWidgetUpdateCallbackFunction = int (*)(NativeWidgetUpdateCallback);

napi_value RegisterWidgetUpdateBridgeCallback(
    napi_env env,
    napi_callback_info info,
    SetNativeWidgetUpdateCallbackFunction setter);
napi_value UnregisterWidgetUpdateBridgeCallback(napi_env env);
void ClearWidgetUpdateBridge();
