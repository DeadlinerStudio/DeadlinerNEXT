#include "napi/native_api.h"

#include <dlfcn.h>
#include <string>
#include <vector>

namespace {

using InitializeFunction = int (*)(const char*, const char*);
using ImportLegacyV2Function = int (*)(const char*, const char*);
using ImportJsonFunction = int (*)(const char*);
using DiagnosticsJsonFunction = int (*)(char*, int);
using MergeLegacyV2JsonFunction = int (*)(const char*, const char*, char*, int);
using SyncWebDavChangeLogJsonFunction = int (*)(const char*, const char*, const char*, char*, int);
using TaskListViewModelJsonFunction = int (*)(char*, int);
using TaskMutationJsonFunction = int (*)(const char*, char*, int);
using TaskKeyMutationJsonFunction = int (*)(const char*, const char*, char*, int);
using LifiProcessInputFunction = int (*)(const char*, const char*);
using LifiSubmitToolResultFunction = int (*)(const char*, const char*, const char*);
using ZeroArgumentFunction = int (*)();

struct PersistenceApi {
    void* handle = nullptr;
    std::string loadError;
    InitializeFunction initialize = nullptr;
    TaskListViewModelJsonFunction lastInitializationError = nullptr;
    ImportLegacyV2Function importLegacyV2 = nullptr;
    ImportJsonFunction importCapturesJson = nullptr;
    DiagnosticsJsonFunction diagnosticsJson = nullptr;
    MergeLegacyV2JsonFunction mergeLegacyV2Json = nullptr;
    SyncWebDavChangeLogJsonFunction syncWebDavChangeLogJson = nullptr;
    TaskListViewModelJsonFunction taskListViewModelJson = nullptr;
    TaskListViewModelJsonFunction categoryCatalogJson = nullptr;
    TaskMutationJsonFunction categoryCreateJson = nullptr;
    TaskMutationJsonFunction categoryUpdateJson = nullptr;
    TaskKeyMutationJsonFunction categoryDeleteJson = nullptr;
    TaskListViewModelJsonFunction categoryRestorePresetsJson = nullptr;
    TaskListViewModelJsonFunction overviewViewModelJson = nullptr;
    TaskMutationJsonFunction taskCreateJson = nullptr;
    TaskMutationJsonFunction taskUpdateJson = nullptr;
    TaskKeyMutationJsonFunction taskActionJson = nullptr;
    TaskKeyMutationJsonFunction taskDeleteJson = nullptr;
    TaskListViewModelJsonFunction habitStateJson = nullptr;
    TaskMutationJsonFunction habitCreateJson = nullptr;
    TaskMutationJsonFunction habitUpdateJson = nullptr;
    TaskMutationJsonFunction habitCategoryUpdateJson = nullptr;
    TaskKeyMutationJsonFunction habitStatusActionJson = nullptr;
    TaskKeyMutationJsonFunction habitToggleRecordJson = nullptr;
    TaskMutationJsonFunction habitSaveRecordJson = nullptr;
    TaskKeyMutationJsonFunction habitClearRecordsJson = nullptr;
    TaskKeyMutationJsonFunction habitDeleteJson = nullptr;
    TaskListViewModelJsonFunction captureStateJson = nullptr;
    TaskMutationJsonFunction captureCreateJson = nullptr;
    TaskMutationJsonFunction captureUpdateJson = nullptr;
    TaskKeyMutationJsonFunction captureDeleteJson = nullptr;
    TaskListViewModelJsonFunction memoryProfileStateJson = nullptr;
    ImportJsonFunction importMemoryProfileJson = nullptr;
    TaskMutationJsonFunction memorySaveJson = nullptr;
    TaskKeyMutationJsonFunction memoryDeleteJson = nullptr;
    TaskMutationJsonFunction profileSaveJson = nullptr;
    LifiProcessInputFunction lifiProcessInput = nullptr;
    LifiSubmitToolResultFunction lifiSubmitToolResult = nullptr;
    MergeLegacyV2JsonFunction lifiExtractTasksJson = nullptr;
    MergeLegacyV2JsonFunction lifiExtractHabitsJson = nullptr;
    MergeLegacyV2JsonFunction lifiGenerateMonthlyAnalysisJson = nullptr;
    TaskListViewModelJsonFunction lifiDrainEventsJson = nullptr;
    ZeroArgumentFunction lifiPendingEventCount = nullptr;
    ZeroArgumentFunction lifiReset = nullptr;
    ZeroArgumentFunction close = nullptr;
    ZeroArgumentFunction health = nullptr;
    ZeroArgumentFunction bridgeVersion = nullptr;
};

PersistenceApi& GetPersistenceApi()
{
    static PersistenceApi api;
    if (api.handle != nullptr || !api.loadError.empty()) {
        return api;
    }

    api.handle = dlopen("libDeadlinerCore.so", RTLD_NOW | RTLD_LOCAL);
    if (api.handle == nullptr) {
        const char* error = dlerror();
        api.loadError = error == nullptr ? "Unable to load libDeadlinerCore.so" : error;
        return api;
    }

    api.initialize = reinterpret_cast<InitializeFunction>(dlsym(api.handle, "deadliner_persistence_initialize"));
    api.lastInitializationError = reinterpret_cast<TaskListViewModelJsonFunction>(dlsym(api.handle, "deadliner_persistence_last_initialization_error"));
    api.importLegacyV2 = reinterpret_cast<ImportLegacyV2Function>(dlsym(api.handle, "deadliner_persistence_import_legacy_v2"));
    api.importCapturesJson = reinterpret_cast<ImportJsonFunction>(dlsym(api.handle, "deadliner_persistence_import_captures_json"));
    api.diagnosticsJson = reinterpret_cast<DiagnosticsJsonFunction>(dlsym(api.handle, "deadliner_persistence_diagnostics_json"));
    api.mergeLegacyV2Json = reinterpret_cast<MergeLegacyV2JsonFunction>(dlsym(api.handle, "deadliner_persistence_merge_legacy_v2_json"));
    api.syncWebDavChangeLogJson = reinterpret_cast<SyncWebDavChangeLogJsonFunction>(dlsym(api.handle, "deadliner_persistence_sync_webdav_changelog_json"));
    api.taskListViewModelJson = reinterpret_cast<TaskListViewModelJsonFunction>(dlsym(api.handle, "deadliner_persistence_task_list_view_model_json"));
    api.categoryCatalogJson = reinterpret_cast<TaskListViewModelJsonFunction>(dlsym(api.handle, "deadliner_persistence_category_catalog_json"));
    api.categoryCreateJson = reinterpret_cast<TaskMutationJsonFunction>(dlsym(api.handle, "deadliner_persistence_category_create_json"));
    api.categoryUpdateJson = reinterpret_cast<TaskMutationJsonFunction>(dlsym(api.handle, "deadliner_persistence_category_update_json"));
    api.categoryDeleteJson = reinterpret_cast<TaskKeyMutationJsonFunction>(dlsym(api.handle, "deadliner_persistence_category_delete_json"));
    api.categoryRestorePresetsJson = reinterpret_cast<TaskListViewModelJsonFunction>(dlsym(api.handle, "deadliner_persistence_category_restore_presets_json"));
    api.overviewViewModelJson = reinterpret_cast<TaskListViewModelJsonFunction>(dlsym(api.handle, "deadliner_persistence_overview_view_model_json"));
    api.taskCreateJson = reinterpret_cast<TaskMutationJsonFunction>(dlsym(api.handle, "deadliner_persistence_task_create_json"));
    api.taskUpdateJson = reinterpret_cast<TaskMutationJsonFunction>(dlsym(api.handle, "deadliner_persistence_task_update_json"));
    api.taskActionJson = reinterpret_cast<TaskKeyMutationJsonFunction>(dlsym(api.handle, "deadliner_persistence_task_action_json"));
    api.taskDeleteJson = reinterpret_cast<TaskKeyMutationJsonFunction>(dlsym(api.handle, "deadliner_persistence_task_delete_json"));
    api.habitStateJson = reinterpret_cast<TaskListViewModelJsonFunction>(dlsym(api.handle, "deadliner_persistence_habit_state_json"));
    api.habitCreateJson = reinterpret_cast<TaskMutationJsonFunction>(dlsym(api.handle, "deadliner_persistence_habit_create_json"));
    api.habitUpdateJson = reinterpret_cast<TaskMutationJsonFunction>(dlsym(api.handle, "deadliner_persistence_habit_update_json"));
    api.habitCategoryUpdateJson = reinterpret_cast<TaskMutationJsonFunction>(dlsym(api.handle, "deadliner_persistence_habit_category_update_json"));
    api.habitStatusActionJson = reinterpret_cast<TaskKeyMutationJsonFunction>(dlsym(api.handle, "deadliner_persistence_habit_status_action_json"));
    api.habitToggleRecordJson = reinterpret_cast<TaskKeyMutationJsonFunction>(dlsym(api.handle, "deadliner_persistence_habit_toggle_record_json"));
    api.habitSaveRecordJson = reinterpret_cast<TaskMutationJsonFunction>(dlsym(api.handle, "deadliner_persistence_habit_save_record_json"));
    api.habitClearRecordsJson = reinterpret_cast<TaskKeyMutationJsonFunction>(dlsym(api.handle, "deadliner_persistence_habit_clear_records_json"));
    api.habitDeleteJson = reinterpret_cast<TaskKeyMutationJsonFunction>(dlsym(api.handle, "deadliner_persistence_habit_delete_json"));
    api.captureStateJson = reinterpret_cast<TaskListViewModelJsonFunction>(dlsym(api.handle, "deadliner_persistence_capture_state_json"));
    api.captureCreateJson = reinterpret_cast<TaskMutationJsonFunction>(dlsym(api.handle, "deadliner_persistence_capture_create_json"));
    api.captureUpdateJson = reinterpret_cast<TaskMutationJsonFunction>(dlsym(api.handle, "deadliner_persistence_capture_update_json"));
    api.captureDeleteJson = reinterpret_cast<TaskKeyMutationJsonFunction>(dlsym(api.handle, "deadliner_persistence_capture_delete_json"));
    api.memoryProfileStateJson = reinterpret_cast<TaskListViewModelJsonFunction>(dlsym(api.handle, "deadliner_persistence_memory_profile_state_json"));
    api.importMemoryProfileJson = reinterpret_cast<ImportJsonFunction>(dlsym(api.handle, "deadliner_persistence_import_memory_profile_json"));
    api.memorySaveJson = reinterpret_cast<TaskMutationJsonFunction>(dlsym(api.handle, "deadliner_persistence_memory_save_json"));
    api.memoryDeleteJson = reinterpret_cast<TaskKeyMutationJsonFunction>(dlsym(api.handle, "deadliner_persistence_memory_delete_json"));
    api.profileSaveJson = reinterpret_cast<TaskMutationJsonFunction>(dlsym(api.handle, "deadliner_persistence_profile_save_json"));
    api.lifiProcessInput = reinterpret_cast<LifiProcessInputFunction>(dlsym(api.handle, "deadliner_lifi_process_input"));
    api.lifiSubmitToolResult = reinterpret_cast<LifiSubmitToolResultFunction>(dlsym(api.handle, "deadliner_lifi_submit_tool_result"));
    api.lifiExtractTasksJson = reinterpret_cast<MergeLegacyV2JsonFunction>(dlsym(api.handle, "deadliner_lifi_extract_tasks_json"));
    api.lifiExtractHabitsJson = reinterpret_cast<MergeLegacyV2JsonFunction>(dlsym(api.handle, "deadliner_lifi_extract_habits_json"));
    api.lifiGenerateMonthlyAnalysisJson = reinterpret_cast<MergeLegacyV2JsonFunction>(dlsym(api.handle, "deadliner_lifi_generate_monthly_analysis_json"));
    api.lifiDrainEventsJson = reinterpret_cast<TaskListViewModelJsonFunction>(dlsym(api.handle, "deadliner_lifi_drain_events_json"));
    api.lifiPendingEventCount = reinterpret_cast<ZeroArgumentFunction>(dlsym(api.handle, "deadliner_lifi_pending_event_count"));
    api.lifiReset = reinterpret_cast<ZeroArgumentFunction>(dlsym(api.handle, "deadliner_lifi_reset"));
    api.close = reinterpret_cast<ZeroArgumentFunction>(dlsym(api.handle, "deadliner_persistence_close"));
    api.health = reinterpret_cast<ZeroArgumentFunction>(dlsym(api.handle, "deadliner_persistence_health"));
    api.bridgeVersion = reinterpret_cast<ZeroArgumentFunction>(dlsym(api.handle, "deadliner_persistence_bridge_version"));

    if (api.initialize == nullptr || api.importLegacyV2 == nullptr || api.importCapturesJson == nullptr || api.diagnosticsJson == nullptr || api.mergeLegacyV2Json == nullptr || api.syncWebDavChangeLogJson == nullptr || api.taskListViewModelJson == nullptr || api.overviewViewModelJson == nullptr || api.taskCreateJson == nullptr || api.taskUpdateJson == nullptr || api.taskActionJson == nullptr || api.taskDeleteJson == nullptr || api.habitStateJson == nullptr || api.habitCreateJson == nullptr || api.habitUpdateJson == nullptr || api.habitStatusActionJson == nullptr || api.habitToggleRecordJson == nullptr || api.habitSaveRecordJson == nullptr || api.habitClearRecordsJson == nullptr || api.habitDeleteJson == nullptr || api.captureStateJson == nullptr || api.captureCreateJson == nullptr || api.captureUpdateJson == nullptr || api.captureDeleteJson == nullptr || api.memoryProfileStateJson == nullptr || api.importMemoryProfileJson == nullptr || api.memorySaveJson == nullptr || api.memoryDeleteJson == nullptr || api.profileSaveJson == nullptr || api.lifiProcessInput == nullptr || api.lifiSubmitToolResult == nullptr || api.lifiExtractTasksJson == nullptr || api.lifiExtractHabitsJson == nullptr || api.lifiGenerateMonthlyAnalysisJson == nullptr || api.lifiDrainEventsJson == nullptr || api.lifiPendingEventCount == nullptr || api.lifiReset == nullptr || api.close == nullptr || api.health == nullptr || api.bridgeVersion == nullptr) {
        dlclose(api.handle);
        PersistenceApi unavailable;
        unavailable.loadError = "libDeadlinerCore.so is missing a required persistence symbol";
        api = unavailable;
    }
    return api;
}

bool ReadUtf8Argument(napi_env env, napi_value value, std::string& output)
{
    size_t size = 0;
    if (napi_get_value_string_utf8(env, value, nullptr, 0, &size) != napi_ok) {
        return false;
    }
    output.resize(size);
    size_t copied = 0;
    return napi_get_value_string_utf8(env, value, output.data(), size + 1, &copied) == napi_ok;
}

napi_value CreateIntResult(napi_env env, int result)
{
    napi_value value = nullptr;
    napi_create_int32(env, result, &value);
    return value;
}

napi_value Initialize(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value arguments[2] = { nullptr, nullptr };
    if (napi_get_cb_info(env, info, &argc, arguments, nullptr, nullptr) != napi_ok || argc != 2) {
        return CreateIntResult(env, 0);
    }

    std::string directory;
    std::string installationId;
    if (!ReadUtf8Argument(env, arguments[0], directory) || !ReadUtf8Argument(env, arguments[1], installationId)) {
        return CreateIntResult(env, 0);
    }

    PersistenceApi& api = GetPersistenceApi();
    return CreateIntResult(env, api.initialize == nullptr ? 0 : api.initialize(directory.c_str(), installationId.c_str()));
}

napi_value ImportLegacyV2(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value arguments[2] = { nullptr, nullptr };
    if (napi_get_cb_info(env, info, &argc, arguments, nullptr, nullptr) != napi_ok || argc != 2) {
        return CreateIntResult(env, -1);
    }

    std::string taskPayload;
    std::string habitPayload;
    if (!ReadUtf8Argument(env, arguments[0], taskPayload) || !ReadUtf8Argument(env, arguments[1], habitPayload)) {
        return CreateIntResult(env, -1);
    }

    PersistenceApi& api = GetPersistenceApi();
    return CreateIntResult(env, api.importLegacyV2 == nullptr ? -1 : api.importLegacyV2(taskPayload.c_str(), habitPayload.c_str()));
}

napi_value ImportCapturesJson(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value arguments[1] = { nullptr };
    std::string payload;
    PersistenceApi& api = GetPersistenceApi();
    if (api.importCapturesJson == nullptr || napi_get_cb_info(env, info, &argc, arguments, nullptr, nullptr) != napi_ok || argc != 1 || !ReadUtf8Argument(env, arguments[0], payload)) return CreateIntResult(env, -1);
    return CreateIntResult(env, api.importCapturesJson(payload.c_str()));
}

napi_value DiagnosticsJson(napi_env env, napi_callback_info info)
{
    size_t argc = 0;
    if (napi_get_cb_info(env, info, &argc, nullptr, nullptr, nullptr) != napi_ok || argc != 0) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }

    PersistenceApi& api = GetPersistenceApi();
    if (api.diagnosticsJson == nullptr) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }

    const int requiredCapacity = api.diagnosticsJson(nullptr, 0);
    if (requiredCapacity <= 1) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }

    std::vector<char> buffer(static_cast<size_t>(requiredCapacity));
    const int actualCapacity = api.diagnosticsJson(buffer.data(), requiredCapacity);
    if (actualCapacity != requiredCapacity) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }

    napi_value value = nullptr;
    napi_create_string_utf8(env, buffer.data(), NAPI_AUTO_LENGTH, &value);
    return value;
}

napi_value MergeLegacyV2Json(
    napi_env env,
    napi_callback_info info,
    MergeLegacyV2JsonFunction mergeFunction)
{
    size_t argc = 2;
    napi_value arguments[2] = { nullptr, nullptr };
    if (mergeFunction == nullptr || napi_get_cb_info(env, info, &argc, arguments, nullptr, nullptr) != napi_ok || argc != 2) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }

    std::string taskPayload;
    std::string habitPayload;
    if (!ReadUtf8Argument(env, arguments[0], taskPayload) || !ReadUtf8Argument(env, arguments[1], habitPayload)) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }

    const int requiredCapacity = mergeFunction(taskPayload.c_str(), habitPayload.c_str(), nullptr, 0);
    if (requiredCapacity <= 1) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }

    std::vector<char> buffer(static_cast<size_t>(requiredCapacity));
    const int actualCapacity = mergeFunction(taskPayload.c_str(), habitPayload.c_str(), buffer.data(), requiredCapacity);
    if (actualCapacity != requiredCapacity) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }

    napi_value value = nullptr;
    napi_create_string_utf8(env, buffer.data(), NAPI_AUTO_LENGTH, &value);
    return value;
}

napi_value MergeLegacyV2PayloadsJson(napi_env env, napi_callback_info info)
{
    PersistenceApi& api = GetPersistenceApi();
    return MergeLegacyV2Json(env, info, api.mergeLegacyV2Json);
}

napi_value SyncWebDavChangeLogJson(napi_env env, napi_callback_info info)
{
    size_t argc = 3;
    napi_value arguments[3] = { nullptr, nullptr, nullptr };
    PersistenceApi& api = GetPersistenceApi();
    if (api.syncWebDavChangeLogJson == nullptr || napi_get_cb_info(env, info, &argc, arguments, nullptr, nullptr) != napi_ok || argc != 3) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }
    std::string baseUrl;
    std::string username;
    std::string password;
    if (!ReadUtf8Argument(env, arguments[0], baseUrl) || !ReadUtf8Argument(env, arguments[1], username) || !ReadUtf8Argument(env, arguments[2], password)) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }
    const int requiredCapacity = api.syncWebDavChangeLogJson(baseUrl.c_str(), username.c_str(), password.c_str(), nullptr, 0);
    if (requiredCapacity <= 1) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }
    std::vector<char> buffer(static_cast<size_t>(requiredCapacity));
    const int actualCapacity = api.syncWebDavChangeLogJson(baseUrl.c_str(), username.c_str(), password.c_str(), buffer.data(), requiredCapacity);
    if (actualCapacity != requiredCapacity) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }
    napi_value value = nullptr;
    napi_create_string_utf8(env, buffer.data(), NAPI_AUTO_LENGTH, &value);
    return value;
}

struct SyncWebDavAsyncContext {
    SyncWebDavChangeLogJsonFunction function = nullptr;
    napi_async_work work = nullptr;
    napi_deferred deferred = nullptr;
    std::string baseUrl;
    std::string username;
    std::string password;
    std::string result;
};

void ExecuteSyncWebDavChangeLog(napi_env, void* data)
{
    auto* context = static_cast<SyncWebDavAsyncContext*>(data);
    if (context->function == nullptr) {
        return;
    }
    const int required = context->function(
        context->baseUrl.c_str(), context->username.c_str(), context->password.c_str(), nullptr, 0);
    if (required <= 1) {
        return;
    }
    std::vector<char> buffer(static_cast<size_t>(required));
    if (context->function(
            context->baseUrl.c_str(), context->username.c_str(), context->password.c_str(), buffer.data(), required) != required) {
        return;
    }
    context->result.assign(buffer.data());
}

void CompleteSyncWebDavChangeLog(napi_env env, napi_status, void* data)
{
    auto* context = static_cast<SyncWebDavAsyncContext*>(data);
    napi_value result = nullptr;
    napi_create_string_utf8(env, context->result.c_str(), NAPI_AUTO_LENGTH, &result);
    napi_resolve_deferred(env, context->deferred, result);
    napi_delete_async_work(env, context->work);
    delete context;
}

napi_value SyncWebDavChangeLogJsonAsync(napi_env env, napi_callback_info info)
{
    size_t argc = 3;
    napi_value arguments[3] = { nullptr, nullptr, nullptr };
    PersistenceApi& api = GetPersistenceApi();
    if (api.syncWebDavChangeLogJson == nullptr ||
        napi_get_cb_info(env, info, &argc, arguments, nullptr, nullptr) != napi_ok || argc != 3) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }

    auto* context = new SyncWebDavAsyncContext();
    context->function = api.syncWebDavChangeLogJson;
    if (!ReadUtf8Argument(env, arguments[0], context->baseUrl) ||
        !ReadUtf8Argument(env, arguments[1], context->username) ||
        !ReadUtf8Argument(env, arguments[2], context->password)) {
        delete context;
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }

    napi_value promise = nullptr;
    napi_create_promise(env, &context->deferred, &promise);
    napi_value resourceName = nullptr;
    napi_create_string_utf8(env, "deadlinerWebDavSync", NAPI_AUTO_LENGTH, &resourceName);
    if (napi_create_async_work(env, nullptr, resourceName, ExecuteSyncWebDavChangeLog,
            CompleteSyncWebDavChangeLog, context, &context->work) != napi_ok ||
        napi_queue_async_work(env, context->work) != napi_ok) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        napi_resolve_deferred(env, context->deferred, empty);
        if (context->work != nullptr) napi_delete_async_work(env, context->work);
        delete context;
    }
    return promise;
}

napi_value TaskListViewModelJson(napi_env env, napi_callback_info info)
{
    size_t argc = 0;
    if (napi_get_cb_info(env, info, &argc, nullptr, nullptr, nullptr) != napi_ok || argc != 0) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }
    PersistenceApi& api = GetPersistenceApi();
    if (api.taskListViewModelJson == nullptr) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }
    const int requiredCapacity = api.taskListViewModelJson(nullptr, 0);
    if (requiredCapacity <= 1) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }
    std::vector<char> buffer(static_cast<size_t>(requiredCapacity));
    const int actualCapacity = api.taskListViewModelJson(buffer.data(), requiredCapacity);
    if (actualCapacity != requiredCapacity) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }
    napi_value value = nullptr;
    napi_create_string_utf8(env, buffer.data(), NAPI_AUTO_LENGTH, &value);
    return value;
}

napi_value RunZeroArgumentJson(napi_env env, napi_callback_info info, TaskListViewModelJsonFunction function)
{
    size_t argc = 0;
    if (function == nullptr || napi_get_cb_info(env, info, &argc, nullptr, nullptr, nullptr) != napi_ok || argc != 0) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }
    const int required = function(nullptr, 0);
    if (required <= 1) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }
    std::vector<char> buffer(static_cast<size_t>(required));
    if (function(buffer.data(), required) != required) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }
    napi_value value = nullptr;
    napi_create_string_utf8(env, buffer.data(), NAPI_AUTO_LENGTH, &value);
    return value;
}

napi_value OverviewViewModelJson(napi_env env, napi_callback_info info)
{
    return RunZeroArgumentJson(env, info, GetPersistenceApi().overviewViewModelJson);
}

napi_value CategoryCatalogJson(napi_env env, napi_callback_info info)
{
  return RunZeroArgumentJson(env, info, GetPersistenceApi().categoryCatalogJson);
}

napi_value LastInitializationError(napi_env env, napi_callback_info info)
{
    return RunZeroArgumentJson(env, info, GetPersistenceApi().lastInitializationError);
}

napi_value BridgeLoadError(napi_env env, napi_callback_info info)
{
    size_t argc = 0;
    if (napi_get_cb_info(env, info, &argc, nullptr, nullptr, nullptr) != napi_ok || argc != 0) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }
    PersistenceApi& api = GetPersistenceApi();
    napi_value value = nullptr;
    napi_create_string_utf8(env, api.loadError.c_str(), NAPI_AUTO_LENGTH, &value);
    return value;
}

struct ZeroArgumentJsonAsyncContext {
    TaskListViewModelJsonFunction function = nullptr;
    napi_async_work work = nullptr;
    napi_deferred deferred = nullptr;
    std::string result;
};

void ExecuteZeroArgumentJson(napi_env, void* data)
{
    auto* context = static_cast<ZeroArgumentJsonAsyncContext*>(data);
    if (context->function == nullptr) return;
    const int required = context->function(nullptr, 0);
    if (required <= 1) return;
    std::vector<char> buffer(static_cast<size_t>(required));
    if (context->function(buffer.data(), required) == required) context->result.assign(buffer.data());
}

void CompleteZeroArgumentJson(napi_env env, napi_status, void* data)
{
    auto* context = static_cast<ZeroArgumentJsonAsyncContext*>(data);
    napi_value result = nullptr;
    napi_create_string_utf8(env, context->result.c_str(), NAPI_AUTO_LENGTH, &result);
    napi_resolve_deferred(env, context->deferred, result);
    napi_delete_async_work(env, context->work);
    delete context;
}

napi_value RunZeroArgumentJsonAsync(napi_env env, napi_callback_info info,
    TaskListViewModelJsonFunction function, const char* resourceLabel)
{
    size_t argc = 0;
    if (function == nullptr || napi_get_cb_info(env, info, &argc, nullptr, nullptr, nullptr) != napi_ok || argc != 0) {
        napi_value empty = nullptr; napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty); return empty;
    }
    auto* context = new ZeroArgumentJsonAsyncContext();
    context->function = function;
    napi_value promise = nullptr;
    napi_create_promise(env, &context->deferred, &promise);
    napi_value resourceName = nullptr;
    napi_create_string_utf8(env, resourceLabel, NAPI_AUTO_LENGTH, &resourceName);
    if (napi_create_async_work(env, nullptr, resourceName, ExecuteZeroArgumentJson,
            CompleteZeroArgumentJson, context, &context->work) != napi_ok ||
        napi_queue_async_work(env, context->work) != napi_ok) {
        napi_value empty = nullptr; napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        napi_resolve_deferred(env, context->deferred, empty);
        if (context->work != nullptr) napi_delete_async_work(env, context->work);
        delete context;
    }
    return promise;
}

napi_value OverviewViewModelJsonAsync(napi_env env, napi_callback_info info)
{
    return RunZeroArgumentJsonAsync(env, info, GetPersistenceApi().overviewViewModelJson, "deadlinerOverviewState");
}

napi_value LifiProcessInput(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value arguments[2] = { nullptr, nullptr };
    std::string config;
    std::string text;
    PersistenceApi& api = GetPersistenceApi();
    if (api.lifiProcessInput == nullptr || napi_get_cb_info(env, info, &argc, arguments, nullptr, nullptr) != napi_ok || argc != 2 ||
        !ReadUtf8Argument(env, arguments[0], config) || !ReadUtf8Argument(env, arguments[1], text)) {
        return CreateIntResult(env, 0);
    }
    return CreateIntResult(env, api.lifiProcessInput(config.c_str(), text.c_str()));
}

struct TwoStringIntAsyncContext {
    LifiProcessInputFunction function = nullptr;
    napi_async_work work = nullptr;
    napi_deferred deferred = nullptr;
    std::string first;
    std::string second;
    int result = 0;
};

void ExecuteTwoStringInt(napi_env, void* data)
{
    auto* context = static_cast<TwoStringIntAsyncContext*>(data);
    if (context->function != nullptr) context->result = context->function(context->first.c_str(), context->second.c_str());
}

void CompleteTwoStringInt(napi_env env, napi_status, void* data)
{
    auto* context = static_cast<TwoStringIntAsyncContext*>(data);
    napi_value result = CreateIntResult(env, context->result);
    napi_resolve_deferred(env, context->deferred, result);
    napi_delete_async_work(env, context->work);
    delete context;
}

napi_value LifiProcessInputAsync(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value arguments[2] = { nullptr, nullptr };
    PersistenceApi& api = GetPersistenceApi();
    if (api.lifiProcessInput == nullptr || napi_get_cb_info(env, info, &argc, arguments, nullptr, nullptr) != napi_ok || argc != 2) {
        return CreateIntResult(env, 0);
    }
    auto* context = new TwoStringIntAsyncContext();
    context->function = api.lifiProcessInput;
    if (!ReadUtf8Argument(env, arguments[0], context->first) || !ReadUtf8Argument(env, arguments[1], context->second)) {
        delete context; return CreateIntResult(env, 0);
    }
    napi_value promise = nullptr;
    napi_create_promise(env, &context->deferred, &promise);
    napi_value resourceName = nullptr;
    napi_create_string_utf8(env, "deadlinerLifiProcess", NAPI_AUTO_LENGTH, &resourceName);
    if (napi_create_async_work(env, nullptr, resourceName, ExecuteTwoStringInt,
            CompleteTwoStringInt, context, &context->work) != napi_ok ||
        napi_queue_async_work(env, context->work) != napi_ok) {
        napi_value failed = CreateIntResult(env, 0);
        napi_resolve_deferred(env, context->deferred, failed);
        if (context->work != nullptr) napi_delete_async_work(env, context->work);
        delete context;
    }
    return promise;
}

napi_value LifiSubmitToolResult(napi_env env, napi_callback_info info)
{
    size_t argc = 3;
    napi_value arguments[3] = { nullptr, nullptr, nullptr };
    std::string id;
    std::string tool;
    std::string payload;
    PersistenceApi& api = GetPersistenceApi();
    if (api.lifiSubmitToolResult == nullptr || napi_get_cb_info(env, info, &argc, arguments, nullptr, nullptr) != napi_ok || argc != 3 ||
        !ReadUtf8Argument(env, arguments[0], id) || !ReadUtf8Argument(env, arguments[1], tool) || !ReadUtf8Argument(env, arguments[2], payload)) {
        return CreateIntResult(env, 0);
    }
    return CreateIntResult(env, api.lifiSubmitToolResult(id.c_str(), tool.c_str(), payload.c_str()));
}

struct ThreeStringIntAsyncContext {
    LifiSubmitToolResultFunction function = nullptr;
    napi_async_work work = nullptr;
    napi_deferred deferred = nullptr;
    std::string first;
    std::string second;
    std::string third;
    int result = 0;
};

void ExecuteThreeStringInt(napi_env, void* data)
{
    auto* context = static_cast<ThreeStringIntAsyncContext*>(data);
    if (context->function != nullptr) {
        context->result = context->function(context->first.c_str(), context->second.c_str(), context->third.c_str());
    }
}

void CompleteThreeStringInt(napi_env env, napi_status, void* data)
{
    auto* context = static_cast<ThreeStringIntAsyncContext*>(data);
    napi_value result = CreateIntResult(env, context->result);
    napi_resolve_deferred(env, context->deferred, result);
    napi_delete_async_work(env, context->work);
    delete context;
}

napi_value LifiSubmitToolResultAsync(napi_env env, napi_callback_info info)
{
    size_t argc = 3;
    napi_value arguments[3] = { nullptr, nullptr, nullptr };
    PersistenceApi& api = GetPersistenceApi();
    if (api.lifiSubmitToolResult == nullptr || napi_get_cb_info(env, info, &argc, arguments, nullptr, nullptr) != napi_ok || argc != 3) {
        return CreateIntResult(env, 0);
    }
    auto* context = new ThreeStringIntAsyncContext();
    context->function = api.lifiSubmitToolResult;
    if (!ReadUtf8Argument(env, arguments[0], context->first) ||
        !ReadUtf8Argument(env, arguments[1], context->second) ||
        !ReadUtf8Argument(env, arguments[2], context->third)) {
        delete context; return CreateIntResult(env, 0);
    }
    napi_value promise = nullptr;
    napi_create_promise(env, &context->deferred, &promise);
    napi_value resourceName = nullptr;
    napi_create_string_utf8(env, "deadlinerLifiContinue", NAPI_AUTO_LENGTH, &resourceName);
    if (napi_create_async_work(env, nullptr, resourceName, ExecuteThreeStringInt,
            CompleteThreeStringInt, context, &context->work) != napi_ok ||
        napi_queue_async_work(env, context->work) != napi_ok) {
        napi_value failed = CreateIntResult(env, 0);
        napi_resolve_deferred(env, context->deferred, failed);
        if (context->work != nullptr) napi_delete_async_work(env, context->work);
        delete context;
    }
    return promise;
}

napi_value LifiExtractTasksJson(napi_env env, napi_callback_info info)
{
    return MergeLegacyV2Json(env, info, GetPersistenceApi().lifiExtractTasksJson);
}

struct TwoStringJsonAsyncContext {
    MergeLegacyV2JsonFunction function = nullptr;
    napi_async_work work = nullptr;
    napi_deferred deferred = nullptr;
    std::string first;
    std::string second;
    std::string result;
};

void ExecuteTwoStringJson(napi_env, void* data)
{
    auto* context = static_cast<TwoStringJsonAsyncContext*>(data);
    if (context->function == nullptr) return;
    const int required = context->function(context->first.c_str(), context->second.c_str(), nullptr, 0);
    if (required <= 1) return;
    std::vector<char> buffer(static_cast<size_t>(required));
    if (context->function(context->first.c_str(), context->second.c_str(), buffer.data(), required) == required) {
        context->result.assign(buffer.data());
    }
}

void CompleteTwoStringJson(napi_env env, napi_status, void* data)
{
    auto* context = static_cast<TwoStringJsonAsyncContext*>(data);
    napi_value result = nullptr;
    napi_create_string_utf8(env, context->result.c_str(), NAPI_AUTO_LENGTH, &result);
    napi_resolve_deferred(env, context->deferred, result);
    napi_delete_async_work(env, context->work);
    delete context;
}

napi_value RunTwoStringJsonAsync(napi_env env, napi_callback_info info,
    MergeLegacyV2JsonFunction function, const char* resourceLabel)
{
    size_t argc = 2;
    napi_value arguments[2] = { nullptr, nullptr };
    if (function == nullptr || napi_get_cb_info(env, info, &argc, arguments, nullptr, nullptr) != napi_ok || argc != 2) {
        napi_value empty = nullptr; napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty); return empty;
    }
    auto* context = new TwoStringJsonAsyncContext();
    context->function = function;
    if (!ReadUtf8Argument(env, arguments[0], context->first) || !ReadUtf8Argument(env, arguments[1], context->second)) {
        delete context;
        napi_value empty = nullptr; napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty); return empty;
    }
    napi_value promise = nullptr;
    napi_create_promise(env, &context->deferred, &promise);
    napi_value resourceName = nullptr;
    napi_create_string_utf8(env, resourceLabel, NAPI_AUTO_LENGTH, &resourceName);
    if (napi_create_async_work(env, nullptr, resourceName, ExecuteTwoStringJson,
            CompleteTwoStringJson, context, &context->work) != napi_ok ||
        napi_queue_async_work(env, context->work) != napi_ok) {
        napi_value empty = nullptr; napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        napi_resolve_deferred(env, context->deferred, empty);
        if (context->work != nullptr) napi_delete_async_work(env, context->work);
        delete context;
    }
    return promise;
}

napi_value LifiExtractTasksJsonAsync(napi_env env, napi_callback_info info)
{
    return RunTwoStringJsonAsync(env, info, GetPersistenceApi().lifiExtractTasksJson, "deadlinerLifiTasks");
}

napi_value LifiExtractHabitsJsonAsync(napi_env env, napi_callback_info info)
{
    return RunTwoStringJsonAsync(env, info, GetPersistenceApi().lifiExtractHabitsJson, "deadlinerLifiHabits");
}

napi_value LifiGenerateMonthlyAnalysisJsonAsync(napi_env env, napi_callback_info info)
{
    return RunTwoStringJsonAsync(env, info, GetPersistenceApi().lifiGenerateMonthlyAnalysisJson, "deadlinerLifiMonthly");
}

napi_value LifiDrainEventsJson(napi_env env, napi_callback_info info)
{
    return RunZeroArgumentJson(env, info, GetPersistenceApi().lifiDrainEventsJson);
}

napi_value LifiPendingEventCount(napi_env env, napi_callback_info)
{
    PersistenceApi& api = GetPersistenceApi();
    return CreateIntResult(env, api.lifiPendingEventCount == nullptr ? 0 : api.lifiPendingEventCount());
}

napi_value LifiReset(napi_env env, napi_callback_info)
{
    PersistenceApi& api = GetPersistenceApi();
    return CreateIntResult(env, api.lifiReset == nullptr ? 0 : api.lifiReset());
}

napi_value RunTaskMutation(napi_env env, napi_callback_info info, TaskMutationJsonFunction function)
{
    size_t argc = 1;
    napi_value arguments[1] = { nullptr };
    std::string payload;
    if (function == nullptr || napi_get_cb_info(env, info, &argc, arguments, nullptr, nullptr) != napi_ok || argc != 1 || !ReadUtf8Argument(env, arguments[0], payload)) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }
    const int required = function(payload.c_str(), nullptr, 0);
    if (required <= 1) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }
    std::vector<char> buffer(static_cast<size_t>(required));
    if (function(payload.c_str(), buffer.data(), required) != required) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }
    napi_value value = nullptr;
    napi_create_string_utf8(env, buffer.data(), NAPI_AUTO_LENGTH, &value);
    return value;
}

napi_value TaskCreateJson(napi_env env, napi_callback_info info) { return RunTaskMutation(env, info, GetPersistenceApi().taskCreateJson); }
napi_value TaskUpdateJson(napi_env env, napi_callback_info info) { return RunTaskMutation(env, info, GetPersistenceApi().taskUpdateJson); }
napi_value CategoryCreateJson(napi_env env, napi_callback_info info) { return RunTaskMutation(env, info, GetPersistenceApi().categoryCreateJson); }
napi_value CategoryUpdateJson(napi_env env, napi_callback_info info) { return RunTaskMutation(env, info, GetPersistenceApi().categoryUpdateJson); }

napi_value RunTaskKeyMutation(napi_env env, napi_callback_info info, TaskKeyMutationJsonFunction function)
{
    size_t argc = 2;
    napi_value arguments[2] = { nullptr, nullptr };
    std::string uid;
    std::string payload;
    if (function == nullptr || napi_get_cb_info(env, info, &argc, arguments, nullptr, nullptr) != napi_ok || argc != 2 ||
        !ReadUtf8Argument(env, arguments[0], uid) || !ReadUtf8Argument(env, arguments[1], payload)) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }
    const int required = function(uid.c_str(), payload.c_str(), nullptr, 0);
    if (required <= 1) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }
    std::vector<char> buffer(static_cast<size_t>(required));
    if (function(uid.c_str(), payload.c_str(), buffer.data(), required) != required) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }
    napi_value value = nullptr;
    napi_create_string_utf8(env, buffer.data(), NAPI_AUTO_LENGTH, &value);
    return value;
}

napi_value TaskActionJson(napi_env env, napi_callback_info info) { return RunTaskKeyMutation(env, info, GetPersistenceApi().taskActionJson); }
napi_value TaskDeleteJson(napi_env env, napi_callback_info info) { return RunTaskKeyMutation(env, info, GetPersistenceApi().taskDeleteJson); }
napi_value CategoryDeleteJson(napi_env env, napi_callback_info info) { return RunTaskKeyMutation(env, info, GetPersistenceApi().categoryDeleteJson); }
napi_value CategoryRestorePresetsJson(napi_env env, napi_callback_info info) { return RunZeroArgumentJson(env, info, GetPersistenceApi().categoryRestorePresetsJson); }

napi_value HabitStateJson(napi_env env, napi_callback_info info)
{
    size_t argc = 0;
    if (napi_get_cb_info(env, info, &argc, nullptr, nullptr, nullptr) != napi_ok || argc != 0) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }
    PersistenceApi& api = GetPersistenceApi();
    if (api.habitStateJson == nullptr) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }
    const int requiredCapacity = api.habitStateJson(nullptr, 0);
    if (requiredCapacity <= 1) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }
    std::vector<char> buffer(static_cast<size_t>(requiredCapacity));
    if (api.habitStateJson(buffer.data(), requiredCapacity) != requiredCapacity) {
        napi_value empty = nullptr;
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }
    napi_value value = nullptr;
    napi_create_string_utf8(env, buffer.data(), NAPI_AUTO_LENGTH, &value);
    return value;
}

napi_value HabitCreateJson(napi_env env, napi_callback_info info) { return RunTaskMutation(env, info, GetPersistenceApi().habitCreateJson); }
napi_value HabitUpdateJson(napi_env env, napi_callback_info info) { return RunTaskMutation(env, info, GetPersistenceApi().habitUpdateJson); }
napi_value HabitCategoryUpdateJson(napi_env env, napi_callback_info info) { return RunTaskMutation(env, info, GetPersistenceApi().habitCategoryUpdateJson); }
napi_value HabitStatusActionJson(napi_env env, napi_callback_info info) { return RunTaskKeyMutation(env, info, GetPersistenceApi().habitStatusActionJson); }
napi_value HabitToggleRecordJson(napi_env env, napi_callback_info info) { return RunTaskKeyMutation(env, info, GetPersistenceApi().habitToggleRecordJson); }
napi_value HabitSaveRecordJson(napi_env env, napi_callback_info info) { return RunTaskMutation(env, info, GetPersistenceApi().habitSaveRecordJson); }
napi_value HabitClearRecordsJson(napi_env env, napi_callback_info info) { return RunTaskKeyMutation(env, info, GetPersistenceApi().habitClearRecordsJson); }
napi_value HabitDeleteJson(napi_env env, napi_callback_info info) { return RunTaskKeyMutation(env, info, GetPersistenceApi().habitDeleteJson); }

napi_value CaptureStateJson(napi_env env, napi_callback_info info)
{
    size_t argc = 0;
    PersistenceApi& api = GetPersistenceApi();
    if (api.captureStateJson == nullptr || napi_get_cb_info(env, info, &argc, nullptr, nullptr, nullptr) != napi_ok || argc != 0) {
        napi_value empty = nullptr; napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty); return empty;
    }
    const int required = api.captureStateJson(nullptr, 0);
    if (required <= 1) { napi_value empty = nullptr; napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty); return empty; }
    std::vector<char> buffer(static_cast<size_t>(required));
    if (api.captureStateJson(buffer.data(), required) != required) { napi_value empty = nullptr; napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty); return empty; }
    napi_value value = nullptr; napi_create_string_utf8(env, buffer.data(), NAPI_AUTO_LENGTH, &value); return value;
}

napi_value CaptureCreateJson(napi_env env, napi_callback_info info) { return RunTaskMutation(env, info, GetPersistenceApi().captureCreateJson); }
napi_value CaptureUpdateJson(napi_env env, napi_callback_info info) { return RunTaskMutation(env, info, GetPersistenceApi().captureUpdateJson); }
napi_value CaptureDeleteJson(napi_env env, napi_callback_info info) { return RunTaskKeyMutation(env, info, GetPersistenceApi().captureDeleteJson); }

napi_value MemoryProfileStateJson(napi_env env, napi_callback_info info)
{
    size_t argc = 0;
    PersistenceApi& api = GetPersistenceApi();
    if (api.memoryProfileStateJson == nullptr || napi_get_cb_info(env, info, &argc, nullptr, nullptr, nullptr) != napi_ok || argc != 0) {
        napi_value empty = nullptr; napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty); return empty;
    }
    const int required = api.memoryProfileStateJson(nullptr, 0);
    if (required <= 1) { napi_value empty = nullptr; napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty); return empty; }
    std::vector<char> buffer(static_cast<size_t>(required));
    if (api.memoryProfileStateJson(buffer.data(), required) != required) { napi_value empty = nullptr; napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &empty); return empty; }
    napi_value value = nullptr; napi_create_string_utf8(env, buffer.data(), NAPI_AUTO_LENGTH, &value); return value;
}

napi_value ImportMemoryProfileJson(napi_env env, napi_callback_info info)
{
    size_t argc = 1; napi_value arguments[1] = { nullptr }; std::string payload;
    PersistenceApi& api = GetPersistenceApi();
    if (api.importMemoryProfileJson == nullptr || napi_get_cb_info(env, info, &argc, arguments, nullptr, nullptr) != napi_ok || argc != 1 || !ReadUtf8Argument(env, arguments[0], payload)) return CreateIntResult(env, -1);
    return CreateIntResult(env, api.importMemoryProfileJson(payload.c_str()));
}

napi_value MemorySaveJson(napi_env env, napi_callback_info info) { return RunTaskMutation(env, info, GetPersistenceApi().memorySaveJson); }
napi_value MemoryDeleteJson(napi_env env, napi_callback_info info) { return RunTaskKeyMutation(env, info, GetPersistenceApi().memoryDeleteJson); }
napi_value ProfileSaveJson(napi_env env, napi_callback_info info) { return RunTaskMutation(env, info, GetPersistenceApi().profileSaveJson); }

napi_value Close(napi_env env, napi_callback_info)
{
    PersistenceApi& api = GetPersistenceApi();
    return CreateIntResult(env, api.close == nullptr ? 0 : api.close());
}

napi_value Health(napi_env env, napi_callback_info)
{
    PersistenceApi& api = GetPersistenceApi();
    return CreateIntResult(env, api.health == nullptr ? 0 : api.health());
}

napi_value BridgeVersion(napi_env env, napi_callback_info)
{
    PersistenceApi& api = GetPersistenceApi();
    return CreateIntResult(env, api.bridgeVersion == nullptr ? 0 : api.bridgeVersion());
}

} // namespace

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor descriptors[] = {
        { "initialize", nullptr, Initialize, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "lastInitializationError", nullptr, LastInitializationError, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "bridgeLoadError", nullptr, BridgeLoadError, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "importLegacyV2", nullptr, ImportLegacyV2, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "importCapturesJson", nullptr, ImportCapturesJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "diagnosticsJson", nullptr, DiagnosticsJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "mergeLegacyV2PayloadsJson", nullptr, MergeLegacyV2PayloadsJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "syncWebDavChangeLogJson", nullptr, SyncWebDavChangeLogJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "syncWebDavChangeLogJsonAsync", nullptr, SyncWebDavChangeLogJsonAsync, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "taskListViewModelJson", nullptr, TaskListViewModelJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "categoryCatalogJson", nullptr, CategoryCatalogJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "categoryCreateJson", nullptr, CategoryCreateJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "categoryUpdateJson", nullptr, CategoryUpdateJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "categoryDeleteJson", nullptr, CategoryDeleteJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "categoryRestorePresetsJson", nullptr, CategoryRestorePresetsJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "overviewViewModelJson", nullptr, OverviewViewModelJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "overviewViewModelJsonAsync", nullptr, OverviewViewModelJsonAsync, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "taskCreateJson", nullptr, TaskCreateJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "taskUpdateJson", nullptr, TaskUpdateJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "taskActionJson", nullptr, TaskActionJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "taskDeleteJson", nullptr, TaskDeleteJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "habitStateJson", nullptr, HabitStateJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "habitCreateJson", nullptr, HabitCreateJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "habitUpdateJson", nullptr, HabitUpdateJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "habitCategoryUpdateJson", nullptr, HabitCategoryUpdateJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "habitStatusActionJson", nullptr, HabitStatusActionJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "habitToggleRecordJson", nullptr, HabitToggleRecordJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "habitSaveRecordJson", nullptr, HabitSaveRecordJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "habitClearRecordsJson", nullptr, HabitClearRecordsJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "habitDeleteJson", nullptr, HabitDeleteJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "captureStateJson", nullptr, CaptureStateJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "captureCreateJson", nullptr, CaptureCreateJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "captureUpdateJson", nullptr, CaptureUpdateJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "captureDeleteJson", nullptr, CaptureDeleteJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "memoryProfileStateJson", nullptr, MemoryProfileStateJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "importMemoryProfileJson", nullptr, ImportMemoryProfileJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "memorySaveJson", nullptr, MemorySaveJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "memoryDeleteJson", nullptr, MemoryDeleteJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "profileSaveJson", nullptr, ProfileSaveJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "lifiProcessInput", nullptr, LifiProcessInput, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "lifiProcessInputAsync", nullptr, LifiProcessInputAsync, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "lifiSubmitToolResult", nullptr, LifiSubmitToolResult, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "lifiSubmitToolResultAsync", nullptr, LifiSubmitToolResultAsync, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "lifiExtractTasksJson", nullptr, LifiExtractTasksJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "lifiExtractTasksJsonAsync", nullptr, LifiExtractTasksJsonAsync, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "lifiExtractHabitsJsonAsync", nullptr, LifiExtractHabitsJsonAsync, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "lifiGenerateMonthlyAnalysisJsonAsync", nullptr, LifiGenerateMonthlyAnalysisJsonAsync, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "lifiDrainEventsJson", nullptr, LifiDrainEventsJson, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "lifiPendingEventCount", nullptr, LifiPendingEventCount, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "lifiReset", nullptr, LifiReset, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "close", nullptr, Close, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "health", nullptr, Health, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "bridgeVersion", nullptr, BridgeVersion, nullptr, nullptr, nullptr, napi_default, nullptr },
    };
    napi_define_properties(env, exports, sizeof(descriptors) / sizeof(descriptors[0]), descriptors);
    return exports;
}
EXTERN_C_END

static napi_module persistenceModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "deadliner_persistence",
    .nm_priv = nullptr,
    .reserved = { 0 },
};

extern "C" __attribute__((constructor)) void RegisterDeadlinerPersistenceModule()
{
    napi_module_register(&persistenceModule);
}
