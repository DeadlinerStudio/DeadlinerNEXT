#include "overview_bridge.h"
#include <dlfcn.h>
#include <string>
#include <vector>
namespace {
using Query = int (*)(const char*, char*, int);
using List = int (*)(char*, int);
napi_value Read(napi_env env, napi_callback_info info, const char* symbol, bool argument) {
    napi_value value;
    napi_create_string_utf8(env, "", 0, &value);
    static void* handle = dlopen("libDeadlinerCore.so", RTLD_NOW | RTLD_LOCAL);
    if (!handle) return value;
    void* function = dlsym(handle, symbol);
    if (!function) return value;
    std::vector<char> input;
    if (argument) {
        size_t count = 1, length = 0;
        napi_value arg;
        if (napi_get_cb_info(env, info, &count, &arg, nullptr, nullptr) != napi_ok || count != 1 ||
            napi_get_value_string_utf8(env, arg, nullptr, 0, &length) != napi_ok) return value;
        input.resize(length + 1);
        napi_get_value_string_utf8(env, arg, input.data(), input.size(), &length);
    }
    auto query = reinterpret_cast<Query>(function);
    auto list = reinterpret_cast<List>(function);
    int capacity = argument ? query(input.data(), nullptr, 0) : list(nullptr, 0);
    if (capacity <= 1) return value;
    std::vector<char> output(capacity);
    int written = argument ? query(input.data(), output.data(), capacity) : list(output.data(), capacity);
    if (written != capacity) return value;
    napi_create_string_utf8(env, output.data(), NAPI_AUTO_LENGTH, &value);
    return value;
}
napi_value Month(napi_env env, napi_callback_info info) { return Read(env, info, "deadliner_persistence_overview_month_json", true); }
napi_value FocusQuery(napi_env env, napi_callback_info info) { return Read(env, info, "deadliner_persistence_overview_focus_query_json", true); }
napi_value Sessions(napi_env env, napi_callback_info info) { return Read(env, info, "deadliner_persistence_overview_focus_sessions_json", false); }
}
void RegisterOverviewBridge(napi_env env, napi_value exports) {
    napi_property_descriptor descriptors[] = {
        {"overviewMonthJson", nullptr, Month, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"overviewFocusQueryJson", nullptr, FocusQuery, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"overviewFocusSessionsJson", nullptr, Sessions, nullptr, nullptr, nullptr, napi_default, nullptr}
    };
    napi_define_properties(env, exports, 3, descriptors);
}
