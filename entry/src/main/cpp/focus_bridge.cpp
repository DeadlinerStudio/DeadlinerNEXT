#include "focus_bridge.h"
#include <dlfcn.h>
#include <string>
#include <vector>
namespace {
using JsonWithArgument = int (*)(const char*, char*, int);
using JsonWithoutArgument = int (*)(char*, int);
void* CoreHandle() { static void* handle = dlopen("libDeadlinerCore.so", RTLD_NOW | RTLD_LOCAL); return handle; }
napi_value Empty(napi_env env) { napi_value value; napi_create_string_utf8(env, "", 0, &value); return value; }
napi_value TargetState(napi_env env, napi_callback_info info) {
    size_t count=1; napi_value argument; napi_get_cb_info(env, info, &count, &argument, nullptr, nullptr);
    if (count!=1 || CoreHandle()==nullptr) return Empty(env);
    size_t size=0; if (napi_get_value_string_utf8(env, argument, nullptr, 0, &size)!=napi_ok) return Empty(env);
    std::vector<char> input(size+1); napi_get_value_string_utf8(env, argument, input.data(), input.size(), &size);
    auto call=reinterpret_cast<JsonWithArgument>(dlsym(CoreHandle(), "deadliner_persistence_focus_target_state_json"));
    if (call==nullptr) return Empty(env);
    int capacity=call(input.data(), nullptr, 0); if(capacity<=0) return Empty(env);
    std::vector<char> result(capacity); if(call(input.data(),result.data(),capacity)<=0) return Empty(env);
    napi_value value; napi_create_string_utf8(env,result.data(),NAPI_AUTO_LENGTH,&value); return value;
}
napi_value Overview(napi_env env,napi_callback_info) {
    if(CoreHandle()==nullptr) return Empty(env);
    auto call=reinterpret_cast<JsonWithoutArgument>(dlsym(CoreHandle(),"deadliner_persistence_focus_overview_json"));
    if(call==nullptr) return Empty(env);
    int capacity=call(nullptr,0); if(capacity<=0) return Empty(env);
    std::vector<char> result(capacity); if(call(result.data(),capacity)<=0) return Empty(env);
    napi_value value; napi_create_string_utf8(env,result.data(),NAPI_AUTO_LENGTH,&value); return value;
}
}
void RegisterFocusBridge(napi_env env,napi_value exports) {
    napi_property_descriptor descriptors[]={
        {"focusTargetStateJson",nullptr,TargetState,nullptr,nullptr,nullptr,napi_default,nullptr},
        {"focusOverviewJson",nullptr,Overview,nullptr,nullptr,nullptr,napi_default,nullptr}
    };
    napi_define_properties(env,exports,2,descriptors);
}
