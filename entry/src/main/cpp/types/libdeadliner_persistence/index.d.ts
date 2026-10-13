export declare function initialize(databaseDirectory: string, installationId: string): number
export declare function lastInitializationError(): string
export declare function bridgeLoadError(): string
export declare function importLegacyV2(taskPayload: string, habitPayload: string): number
export declare function importCapturesJson(capturePayload: string): number
export declare function diagnosticsJson(): string
export declare function coreVersion(): string
export declare function mergeLegacyV2PayloadsJson(taskPayload: string, habitPayload: string): string
export declare function syncWebDavChangeLogJson(baseUrl: string, username: string, password: string): string
export declare function syncWebDavChangeLogJsonAsync(baseUrl: string, username: string, password: string): Promise<string>
export declare function configureAutomaticWebDavSync(baseUrl: string, username: string, password: string): number
export declare function taskListViewModelJson(): string
export declare function categoryCatalogJson(): string
export declare function categoryCreateJson(payload: string): string
export declare function categoryUpdateJson(payload: string): string
export declare function categoryDeleteJson(uid: string, updatedAt: string): string
export declare function categoryRestorePresetsJson(): string
export declare function overviewViewModelJson(): string
export declare function overviewViewModelJsonAsync(): Promise<string>
export declare function taskCreateJson(taskPayload: string): string
export declare function taskUpdateJson(taskPayload: string): string
export declare function taskActionJson(uid: string, actionPayload: string): string
export declare function taskDeleteJson(uid: string, updatedAt: string): string
export declare function focusStateJson(selectedTaskUid: string): string
export declare function focusCommandJson(payload: string): string
export declare function habitStateJson(): string
export declare function habitStateForDateJson(selectedDate: string): string
export declare function habitCreateJson(habitPayload: string): string
export declare function habitUpdateJson(habitPayload: string): string
export declare function habitCategoryUpdateJson(payload: string): string
export declare function habitStatusActionJson(uid: string, actionPayload: string): string
export declare function habitToggleRecordJson(uid: string, recordPayload: string): string
export declare function habitSaveRecordJson(recordPayload: string): string
export declare function habitClearRecordsJson(uid: string, recordPayload: string): string
export declare function habitDeleteJson(uid: string, updatedAt: string): string
export declare function captureStateJson(): string
export declare function captureCreateJson(capturePayload: string): string
export declare function captureUpdateJson(capturePayload: string): string
export declare function captureDeleteJson(uid: string, updatedAt: string): string
export declare function memoryProfileStateJson(): string
export declare function importMemoryProfileJson(payload: string): number
export declare function memorySaveJson(payload: string): string
export declare function memoryDeleteJson(uid: string, updatedAt: string): string
export declare function profileSaveJson(payload: string): string
export declare function lifiProcessInput(configPayload: string, text: string): number
export declare function lifiProcessInputAsync(configPayload: string, text: string): Promise<number>
export declare function lifiSubmitToolResult(toolCallId: string, tool: string, payload: string): number
export declare function lifiSubmitToolResultAsync(toolCallId: string, tool: string, payload: string): Promise<number>
export declare function lifiExtractTasksJson(configPayload: string, text: string): string
export declare function lifiExtractTasksJsonAsync(configPayload: string, text: string): Promise<string>
export declare function lifiExtractHabitsJsonAsync(configPayload: string, text: string): Promise<string>
export declare function lifiGenerateMonthlyAnalysisJsonAsync(configPayload: string, requestPayload: string): Promise<string>
export declare function lifiDrainEventsJson(): string
export declare function lifiPendingEventCount(): number
export declare function lifiReset(): number
export declare function registerWidgetUpdateCallback(callback: (reason: number) => void): number
export declare function unregisterWidgetUpdateCallback(): number
export declare function requestWidgetUpdate(reason: number): number
export declare function close(): number
export declare function health(): number
export declare function bridgeVersion(): number

export declare function quickAddParseJson(request: string): string
export declare function quickAddExtractJsonAsync(config: string, request: string): Promise<string>

export declare function quickAddModelPrepareAsync(directory: string, manifest: string): Promise<string>
export declare function quickAddModelRecognizeAsync(request: string): Promise<string>

export declare function quickAddModelStatusAsync(): Promise<string>

export declare function focusTargetStateJson(payload: string): string
export declare function focusOverviewJson(): string

export declare function overviewMonthJson(monthStart: string): string
export declare function overviewFocusQueryJson(query: string): string
export declare function overviewFocusSessionsJson(): string
