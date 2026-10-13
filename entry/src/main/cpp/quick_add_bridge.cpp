#include "quick_add_bridge.h"
#include <dlfcn.h>
#include <mutex>
#include <string>
#include <vector>

namespace {
using ParseFunction = int (*)(const char*, char*, int);
using ExtractFunction = int (*)(const char*, const char*, char*, int);
std::mutex extractionMutex;
void* CoreHandle() {
    static void* handle = dlopen("libDeadlinerCore.so", RTLD_NOW | RTLD_LOCAL);
    return handle;
}
bool ReadString(napi_env env, napi_value value, std::string& result) {
    size_t size = 0;
    if (napi_get_value_string_utf8(env, value, nullptr, 0, &size) != napi_ok) return false;
    std::vector<char> buffer(size + 1);
    if (napi_get_value_string_utf8(env, value, buffer.data(), buffer.size(), &size) != napi_ok) return false;
    result.assign(buffer.data(), size);
    return true;
}
napi_value Parse(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argument;
    std::string request;
    if (napi_get_cb_info(env, info, &argc, &argument, nullptr, nullptr) != napi_ok || argc != 1 ||
        !ReadString(env, argument, request)) {
        napi_throw_type_error(env, nullptr, "quickAddParseJson requires a JSON string"); return nullptr;
    }
    auto handle = CoreHandle();
    auto function = handle ? reinterpret_cast<ParseFunction>(dlsym(handle, "deadliner_quick_add_parse_json")) : nullptr;
    if (!function) { napi_throw_error(env, nullptr, "Please update DeadlinerCore to use quick add"); return nullptr; }
    const int size = function(request.c_str(), nullptr, 0);
    if (size <= 1) { napi_throw_error(env, nullptr, "Quick add parsing failed"); return nullptr; }
    std::vector<char> buffer(size);
    if (function(request.c_str(), buffer.data(), size) != size) {
        napi_throw_error(env, nullptr, "Quick add parsing failed"); return nullptr;
    }
    napi_value result;
    napi_create_string_utf8(env, buffer.data(), NAPI_AUTO_LENGTH, &result);
    return result;
}
struct ExtractContext {
    std::string config, request, result;
    napi_async_work work = nullptr;
    napi_deferred deferred = nullptr;
};
void Execute(napi_env, void* data) {
    auto* context = static_cast<ExtractContext*>(data);
    std::lock_guard<std::mutex> guard(extractionMutex);
    auto handle = CoreHandle();
    auto function = handle ? reinterpret_cast<ExtractFunction>(dlsym(handle, "deadliner_quick_add_extract_json")) : nullptr;
    if (!function) return;
    const int size = function(context->config.c_str(), context->request.c_str(), nullptr, 0);
    if (size <= 1) return;
    std::vector<char> buffer(size);
    if (function(context->config.c_str(), context->request.c_str(), buffer.data(), size) == size)
        context->result.assign(buffer.data());
}
void Complete(napi_env env, napi_status status, void* data) {
    auto* context = static_cast<ExtractContext*>(data);
    napi_value value;
    if (status != napi_ok || context->result.empty()) {
        napi_value message;
        napi_create_string_utf8(env, "Quick add AI extraction failed", NAPI_AUTO_LENGTH, &message);
        napi_create_error(env, nullptr, message, &value);
        napi_reject_deferred(env, context->deferred, value);
    } else {
        napi_create_string_utf8(env, context->result.c_str(), NAPI_AUTO_LENGTH, &value);
        napi_resolve_deferred(env, context->deferred, value);
    }
    napi_delete_async_work(env, context->work);
    delete context;
}
napi_value Extract(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value arguments[2];
    auto* context = new ExtractContext();
    if (napi_get_cb_info(env, info, &argc, arguments, nullptr, nullptr) != napi_ok || argc != 2 ||
        !ReadString(env, arguments[0], context->config) || !ReadString(env, arguments[1], context->request)) {
        delete context;
        napi_throw_type_error(env, nullptr, "quickAddExtractJsonAsync requires config and request JSON"); return nullptr;
    }
    napi_value promise, name;
    napi_create_promise(env, &context->deferred, &promise);
    napi_create_string_utf8(env, "deadlinerQuickAdd", NAPI_AUTO_LENGTH, &name);
    if (napi_create_async_work(env, nullptr, name, Execute, Complete, context, &context->work) != napi_ok ||
        napi_queue_async_work(env, context->work) != napi_ok) {
        if (context->work) napi_delete_async_work(env, context->work);
        napi_value message, error;
        napi_create_string_utf8(env, "Unable to schedule quick add", NAPI_AUTO_LENGTH, &message);
        napi_create_error(env, nullptr, message, &error);
        napi_reject_deferred(env, context->deferred, error);
        delete context;
    }
    return promise;
}
}
void RegisterQuickAddBridge(napi_env env, napi_value exports) {
    RegisterQuickAddModelBridge(env, exports);
    napi_property_descriptor descriptors[] = {
        { "quickAddParseJson", nullptr, Parse, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "quickAddExtractJsonAsync", nullptr, Extract, nullptr, nullptr, nullptr, napi_default, nullptr },
    };
    napi_define_properties(env, exports, 2, descriptors);
}
