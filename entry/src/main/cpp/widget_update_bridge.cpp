#include "widget_update_bridge.h"

#include <mutex>

namespace {

napi_threadsafe_function widgetUpdateThreadsafeFunction = nullptr;
SetNativeWidgetUpdateCallbackFunction nativeCallbackSetter = nullptr;
std::mutex widgetUpdateMutex;

napi_value IntResult(napi_env env, int value)
{
    napi_value result = nullptr;
    napi_create_int32(env, value, &result);
    return result;
}

void CallArkTs(napi_env env, napi_value callback, void*, void* data)
{
    int* reason = static_cast<int*>(data);
    if (env != nullptr && callback != nullptr && reason != nullptr) {
        napi_value receiver = nullptr;
        napi_value argument = nullptr;
        napi_get_global(env, &receiver);
        napi_create_int32(env, *reason, &argument);
        napi_call_function(env, receiver, callback, 1, &argument, nullptr);
    }
    delete reason;
}

void OnNativeWidgetUpdate(int reason)
{
    std::lock_guard<std::mutex> lock(widgetUpdateMutex);
    if (widgetUpdateThreadsafeFunction == nullptr) return;
    int* payload = new int(reason);
    const napi_status status = napi_call_threadsafe_function(
        widgetUpdateThreadsafeFunction,
        payload,
        napi_tsfn_nonblocking);
    if (status != napi_ok) delete payload;
}

} // namespace

void ClearWidgetUpdateBridge()
{
    if (nativeCallbackSetter != nullptr) nativeCallbackSetter(nullptr);
    nativeCallbackSetter = nullptr;
    std::lock_guard<std::mutex> lock(widgetUpdateMutex);
    if (widgetUpdateThreadsafeFunction != nullptr) {
        napi_release_threadsafe_function(widgetUpdateThreadsafeFunction, napi_tsfn_abort);
        widgetUpdateThreadsafeFunction = nullptr;
    }
}

napi_value RegisterWidgetUpdateBridgeCallback(
    napi_env env,
    napi_callback_info info,
    SetNativeWidgetUpdateCallbackFunction setter)
{
    size_t argc = 1;
    napi_value arguments[1] = { nullptr };
    napi_valuetype argumentType = napi_undefined;
    if (setter == nullptr ||
        napi_get_cb_info(env, info, &argc, arguments, nullptr, nullptr) != napi_ok ||
        argc != 1 ||
        napi_typeof(env, arguments[0], &argumentType) != napi_ok ||
        argumentType != napi_function) {
        return IntResult(env, 0);
    }

    ClearWidgetUpdateBridge();
    napi_value resourceName = nullptr;
    napi_create_string_utf8(env, "deadlinerWidgetUpdate", NAPI_AUTO_LENGTH, &resourceName);
    napi_threadsafe_function newThreadsafeFunction = nullptr;
    const napi_status status = napi_create_threadsafe_function(
        env,
        arguments[0],
        nullptr,
        resourceName,
        0,
        1,
        nullptr,
        nullptr,
        nullptr,
        CallArkTs,
        &newThreadsafeFunction);
    if (status != napi_ok) {
        return IntResult(env, 0);
    }

    {
        std::lock_guard<std::mutex> lock(widgetUpdateMutex);
        widgetUpdateThreadsafeFunction = newThreadsafeFunction;
    }

    nativeCallbackSetter = setter;
    if (nativeCallbackSetter(OnNativeWidgetUpdate) != 1) {
        ClearWidgetUpdateBridge();
        return IntResult(env, 0);
    }
    return IntResult(env, 1);
}

napi_value UnregisterWidgetUpdateBridgeCallback(napi_env env)
{
    ClearWidgetUpdateBridge();
    return IntResult(env, 1);
}
