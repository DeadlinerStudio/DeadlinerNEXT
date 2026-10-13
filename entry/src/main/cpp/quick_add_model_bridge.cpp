#include "quick_add_bridge.h"
#include <dlfcn.h>
#include <string>
#include <vector>

namespace {
struct Work {
    int mode = 0;
    std::string first, second, result;
    napi_async_work work = nullptr;
    napi_deferred deferred = nullptr;
};
bool Read(napi_env env, napi_value value, std::string& out) {
    size_t length = 0;
    if (napi_get_value_string_utf8(env, value, nullptr, 0, &length) != napi_ok) return false;
    std::vector<char> bytes(length + 1);
    if (napi_get_value_string_utf8(env, value, bytes.data(), bytes.size(), &length) != napi_ok) return false;
    out.assign(bytes.data(), length);
    return true;
}
void Execute(napi_env, void* data) {
    auto* work = static_cast<Work*>(data);
    static void* handle = dlopen("libDeadlinerCore.so", RTLD_NOW | RTLD_LOCAL);
    if (!handle) return;
    if (work->mode == 0) {
        using Prepare = int (*)(const char*, const char*);
        auto prepare = reinterpret_cast<Prepare>(dlsym(handle, "deadliner_quick_add_model_prepare"));
        if (prepare) work->result = prepare(work->first.c_str(), work->second.c_str()) == 1 ? "true" : "false";
    } else {
        using Recognize = char* (*)(const char*);
        using Free = void (*)(char*);
        auto recognize = reinterpret_cast<Recognize>(dlsym(handle, "deadliner_quick_add_model_recognize"));
        auto release = reinterpret_cast<Free>(dlsym(handle, "deadliner_quick_add_model_free"));
        if (recognize && release) {
            using Status = char* (*)();
            auto status = reinterpret_cast<Status>(dlsym(handle, "deadliner_quick_add_model_status"));
            char* json = work->mode == 2 ? (status ? status() : nullptr) : recognize(work->first.c_str());
            if (json) { work->result.assign(json); release(json); }
        }
    }
}
void Complete(napi_env env, napi_status status, void* data) {
    auto* work = static_cast<Work*>(data);
    napi_value value;
    if (status == napi_ok && !work->result.empty()) {
        napi_create_string_utf8(env, work->result.c_str(), NAPI_AUTO_LENGTH, &value);
        napi_resolve_deferred(env, work->deferred, value);
    } else {
        napi_value message;
        napi_create_string_utf8(env, "Quick add local model unavailable", NAPI_AUTO_LENGTH, &message);
        napi_create_error(env, nullptr, message, &value);
        napi_reject_deferred(env, work->deferred, value);
    }
    napi_delete_async_work(env, work->work);
    delete work;
}
napi_value Schedule(napi_env env, napi_callback_info info, int mode) {
    size_t count = 2;
    napi_value arguments[2];
    auto* work = new Work();
    work->mode = mode;
    const size_t expected = mode == 0 ? 2u : (mode == 1 ? 1u : 0u);
    if (napi_get_cb_info(env, info, &count, arguments, nullptr, nullptr) != napi_ok || count != expected ||
        (expected > 0 && !Read(env, arguments[0], work->first)) || (mode == 0 && !Read(env, arguments[1], work->second))) {
        delete work;
        napi_throw_type_error(env, nullptr, "Quick add model expects string arguments");
        return nullptr;
    }
    napi_value promise, name;
    napi_create_promise(env, &work->deferred, &promise);
    napi_create_string_utf8(env, "quickAddLocalModel", NAPI_AUTO_LENGTH, &name);
    if (napi_create_async_work(env, nullptr, name, Execute, Complete, work, &work->work) != napi_ok ||
        napi_queue_async_work(env, work->work) != napi_ok) {
        if (work->work) napi_delete_async_work(env, work->work);
        napi_value message, error;
        napi_create_string_utf8(env, "Cannot schedule local model", NAPI_AUTO_LENGTH, &message);
        napi_create_error(env, nullptr, message, &error);
        napi_reject_deferred(env, work->deferred, error);
        delete work;
    }
    return promise;
}
napi_value Prepare(napi_env env, napi_callback_info info) { return Schedule(env, info, 0); }
napi_value Recognize(napi_env env, napi_callback_info info) { return Schedule(env, info, 1); }
napi_value Status(napi_env env, napi_callback_info info) { return Schedule(env, info, 2); }
}
void RegisterQuickAddModelBridge(napi_env env, napi_value exports) {
    napi_property_descriptor descriptors[] = {
        { "quickAddModelPrepareAsync", nullptr, Prepare, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "quickAddModelRecognizeAsync", nullptr, Recognize, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "quickAddModelStatusAsync", nullptr, Status, nullptr, nullptr, nullptr, napi_default, nullptr },
    };
    napi_define_properties(env, exports, 3, descriptors);
}
