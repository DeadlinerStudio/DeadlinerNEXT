import { preferences } from '@kit.ArkData';
import { SettingsConstants as C } from './SettingsConstants';
import { SecureStorage } from './SecureStorage';
import { MainButtonType } from './LocalModels';
import { deviceInfo } from '@kit.BasicServicesKit';

interface WebDavAuthInterface {
  user: string;
  pass: string;
}

export interface DailySummaryConfig {
  enable: boolean;
  time: string; // 格式 "HH:mm"
}

export class LocalValues {
  private static instance: LocalValues;
  private pref: preferences.Preferences | null = null;

  private constructor() {}

  public static getInstance(): LocalValues {
    if (!LocalValues.instance) {
      LocalValues.instance = new LocalValues();
    }
    return LocalValues.instance;
  }

  async init(context: Context): Promise<void> {
    try {
      this.pref = await preferences.getPreferences(context, C.PREF_NAME);

      const basicMode = await this.pref.get(C.KEY_BASIC_MODE, false);
      AppStorage.setOrCreate(C.KEY_BASIC_MODE, basicMode);

      // --- 1. 普通数据 (Preferences) ---
      const syncEnable = await this.pref.get(C.KEY_CLOUD_SYNC_ENABLE, false);
      AppStorage.setOrCreate(C.KEY_CLOUD_SYNC_ENABLE, syncEnable);

      const syncMode = await this.pref.get(C.KEY_CLOUD_SYNC_MODE, 'cloud');
      AppStorage.setOrCreate(C.KEY_CLOUD_SYNC_MODE, syncMode);

      const url = await this.pref.get(C.KEY_WEBDAV_URL, '');
      AppStorage.setOrCreate(C.KEY_WEBDAV_URL, url);

      const username = await this.pref.get(C.KEY_WEBDAV_USERNAME, '');
      AppStorage.setOrCreate(C.KEY_WEBDAV_USERNAME, username);

      const autoArchiveDays = await this.pref.get(C.KEY_AUTO_ARCHIVE_DAYS, 3);
      AppStorage.setOrCreate(C.KEY_AUTO_ARCHIVE_DAYS, autoArchiveDays);

      const tombstoneRetentionDays = await this.pref.get(C.KEY_TOMBSTONE_RETENTION_DAYS, 30);
      AppStorage.setOrCreate(C.KEY_TOMBSTONE_RETENTION_DAYS, tombstoneRetentionDays);

      const vibration = await this.pref.get(C.KEY_VIBRATION_ENABLE, true);
      AppStorage.setOrCreate(C.KEY_VIBRATION_ENABLE, vibration);

      const progressDir = await this.pref.get(C.KEY_PROGRESS_DIRECTION, false);
      AppStorage.setOrCreate(C.KEY_PROGRESS_DIRECTION, progressDir);

      const excitementText = await this.pref.get(C.KEY_EXCITEMENT_TEXT, true);
      AppStorage.setOrCreate(C.KEY_EXCITEMENT_TEXT, excitementText);

      const confetti = await this.pref.get(C.KEY_CONFETTI_AFTER_FINISHED, true);
      AppStorage.setOrCreate(C.KEY_CONFETTI_AFTER_FINISHED, confetti);

      const fullScreenAdd = await this.pref.get(C.KEY_FULL_SCREEN_ADD, false);
      AppStorage.setOrCreate(C.KEY_FULL_SCREEN_ADD, fullScreenAdd);

      const widgetBg = await this.pref.get(C.KEY_WIDGET_BG_IMAGE, '');
      AppStorage.setOrCreate(C.KEY_WIDGET_BG_IMAGE, widgetBg);

      const widgetTextWhite = await this.pref.get(C.KEY_WIDGET_TEXT_WHITE, true);
      AppStorage.setOrCreate(C.KEY_WIDGET_TEXT_WHITE, widgetTextWhite);

      // --- 2. 敏感数据 (Asset Store Kit) ---
      // 从安全存储中读取密码，加载到内存 AppStorage 供业务逻辑使用
      const password = await SecureStorage.get(C.KEY_WEBDAV_PASSWORD);
      AppStorage.setOrCreate(C.KEY_WEBDAV_PASSWORD, password);

      // 默认提供商：DeepSeek
      const aiProvider = await this.pref.get(C.KEY_AI_PROVIDER, 'deepseek');
      AppStorage.setOrCreate(C.KEY_AI_PROVIDER, aiProvider);

      // 默认模型
      const aiModel = await this.pref.get(C.KEY_AI_MODEL, 'deepseek-chat');
      AppStorage.setOrCreate(C.KEY_AI_MODEL, aiModel);

      // Base URL (DeepSeek 默认地址)
      const aiBaseUrl = await this.pref.get(C.KEY_AI_BASE_URL, 'https://api.deepseek.com');
      AppStorage.setOrCreate(C.KEY_AI_BASE_URL, aiBaseUrl);

      // 读取 API Key (敏感数据)
      const dsApiKey = await SecureStorage.get(C.KEY_AI_DEEPSEEK_API_KEY);
      AppStorage.setOrCreate(C.KEY_AI_DEEPSEEK_API_KEY, dsApiKey);

      const leftBtn = await this.pref.get(C.KEY_MAIN_LEFT_BUTTON, MainButtonType.ARCHIVE);
      AppStorage.setOrCreate(C.KEY_MAIN_LEFT_BUTTON, leftBtn);

      const rightBtn = await this.pref.get(C.KEY_MAIN_RIGHT_BUTTON, MainButtonType.SEARCH);
      AppStorage.setOrCreate(C.KEY_MAIN_RIGHT_BUTTON, rightBtn);

      // --- 新增：通知设置 ---
      const ddlWarning = await this.pref.get(C.KEY_NOTIFY_DDL_WARNING, true);
      AppStorage.setOrCreate(C.KEY_NOTIFY_DDL_WARNING, ddlWarning);

      const habitReminder = await this.pref.get(C.KEY_NOTIFY_HABIT_REMINDER, true);
      AppStorage.setOrCreate(C.KEY_NOTIFY_HABIT_REMINDER, habitReminder);

      const summaryEnable = await this.pref.get(C.KEY_NOTIFY_SUMMARY_ENABLE, false);
      AppStorage.setOrCreate(C.KEY_NOTIFY_SUMMARY_ENABLE, summaryEnable);

      const summaryTime = await this.pref.get(C.KEY_NOTIFY_SUMMARY_TIME, '21:00');
      AppStorage.setOrCreate(C.KEY_NOTIFY_SUMMARY_TIME, summaryTime);

      const startupPage = await this.pref.get(C.KEY_STARTUP_PAGE, 0);
      AppStorage.setOrCreate(C.KEY_STARTUP_PAGE, startupPage);

      const english = await this.pref.get(C.KEY_ENGLISH_SOMEWHERE, true);
      AppStorage.setOrCreate(C.KEY_ENGLISH_SOMEWHERE, english);

      const habitPs = await this.pref.get(C.KEY_HABIT_PROGRESS_STYLE, 'ellipse');
      AppStorage.setOrCreate(C.KEY_HABIT_PROGRESS_STYLE, habitPs);

      const addWeight = await this.pref.get(C.KEY_ADD_SYMBOL_WEIGHT, 600);
      AppStorage.setOrCreate(C.KEY_ADD_SYMBOL_WEIGHT, addWeight);

      const tabletMode = await this.pref.get(C.KEY_ENABLE_TABLET_UI, true);
      AppStorage.setOrCreate(C.KEY_ENABLE_TABLET_UI, tabletMode);

      const tabletSideDashboard = await this.pref.get(C.KEY_TABLET_SIDE_DASHBOARD, true);
      AppStorage.setOrCreate(C.KEY_TABLET_SIDE_DASHBOARD, tabletSideDashboard);

      const showAiInput = await this.pref.get(C.KEY_SHOW_AI_INPUT, true);
      AppStorage.setOrCreate(C.KEY_SHOW_AI_INPUT, showAiInput);

      const directAddOnAi = await this.pref.get(C.KEY_DIRECT_ADD_ON_AI, true);
      AppStorage.setOrCreate(C.KEY_DIRECT_ADD_ON_AI, directAddOnAi);

      const enableApi23 = await this.pref.get(C.KEY_ENABLE_API23, true);
      AppStorage.setOrCreate(C.KEY_ENABLE_API23, enableApi23);

      const materialLevel = await this.pref.get(C.KEY_API23_MATERIAL_LEVEL, 'EXQUISITE');
      AppStorage.setOrCreate(C.KEY_API23_MATERIAL_LEVEL, materialLevel)

      const overviewOrder = await this.pref.get(C.KEY_OVERVIEW_CARD_ORDER, []) as string[];
      AppStorage.setOrCreate(C.KEY_OVERVIEW_CARD_ORDER, overviewOrder);

      const trendOrder = await this.pref.get(C.KEY_TREND_CARD_ORDER, []) as string[];
      AppStorage.setOrCreate(C.KEY_TREND_CARD_ORDER, trendOrder);

      AppStorage.setOrCreate('IsAppDataReady', true);

      console.info('SettingsValue initialized successfully');
    } catch (err) {
      console.error(`Failed to load settings: ${JSON.stringify(err)}`);
      AppStorage.setOrCreate('IsAppDataReady', true);
    }
  }

  /**
   * 普通设置通用方法
   */
  async setValue<T extends preferences.ValueType>(key: string, value: T): Promise<void> {
    if (!this.pref) return;
    AppStorage.set(key, value); // 更新内存
    try {
      await this.pref.put(key, value); // 更新磁盘
      await this.pref.flush();
    } catch (err) {
      console.error(`Failed to save ${key}: ${JSON.stringify(err)}`);
    }
  }

  getCloudSyncEnable(): boolean {
    return AppStorage.get<boolean>(C.KEY_CLOUD_SYNC_ENABLE) ?? false;
  }

  async setCloudSyncEnable(enable: boolean) {
    await this.setValue(C.KEY_CLOUD_SYNC_ENABLE, enable);
  }

  getWebDavUrl(): string {
    return AppStorage.get<string>(C.KEY_WEBDAV_URL) ?? '';
  }

  async setWebDavUrl(url: string) {
    await this.setValue(C.KEY_WEBDAV_URL, url);
  }

  getWebDavAuth(): WebDavAuthInterface {
    return {
      user: AppStorage.get<string>(C.KEY_WEBDAV_USERNAME) ?? '',
      pass: AppStorage.get<string>(C.KEY_WEBDAV_PASSWORD) ?? ''
    };
  }

  /**
   * 修改：WebDAV 认证信息设置
   * 用户名存 Prefs，密码存 Asset Store
   */
  async setWebDavAuth(user: string, pass: string) {
    // 1. 更新内存状态 (UI)
    AppStorage.set(C.KEY_WEBDAV_USERNAME, user);
    AppStorage.set(C.KEY_WEBDAV_PASSWORD, pass);

    // 2. 用户名 -> Preferences
    await this.setValue(C.KEY_WEBDAV_USERNAME, user);

    // 3. 密码 -> Asset Store Kit
    if (pass && pass.length > 0) {
      await SecureStorage.save(C.KEY_WEBDAV_PASSWORD, pass);
    } else {
      // 如果密码为空，视为删除
      await SecureStorage.delete(C.KEY_WEBDAV_PASSWORD);
    }
  }

  getVibration(): boolean {
    return AppStorage.get<boolean>(C.KEY_VIBRATION_ENABLE) ?? true;
  }

  async setVibration(status: boolean) {
    await this.setValue(C.KEY_VIBRATION_ENABLE, status);
  }

  getProgressDir(): boolean {
    return AppStorage.get<boolean>(C.KEY_PROGRESS_DIRECTION) ?? false;
  }

  async setProgressDir(value: boolean) {
    await this.setValue(C.KEY_PROGRESS_DIRECTION, value);
  }

  getExcitementText(): boolean {
    return AppStorage.get<boolean>(C.KEY_EXCITEMENT_TEXT) ?? true;
  }

  async setExcitementText(value: boolean) {
    await this.setValue(C.KEY_EXCITEMENT_TEXT, value);
  }

  getConfettiAfterFinished(): boolean {
    return AppStorage.get<boolean>(C.KEY_CONFETTI_AFTER_FINISHED) ?? true;
  }

  async setConfettiAfterFinished(value: boolean) {
    await this.setValue(C.KEY_CONFETTI_AFTER_FINISHED, value);
  }

  getFullScreenAdd(): boolean {
    return AppStorage.get<boolean>(C.KEY_FULL_SCREEN_ADD) ?? true;
  }

  async setFullScreenAdd(value: boolean) {
    await this.setValue(C.KEY_FULL_SCREEN_ADD, value);
  }

  /**
   * AI 配置相关 Getter
   */
  getAIProvider(): string {
    return AppStorage.get<string>(C.KEY_AI_PROVIDER) ?? 'deepseek';
  }

  getAIModel(): string {
    return AppStorage.get<string>(C.KEY_AI_MODEL) ?? 'deepseek-chat';
  }

  getAIBaseUrl(): string {
    return AppStorage.get<string>(C.KEY_AI_BASE_URL) ?? 'https://api.deepseek.com';
  }

  getDeepSeekApiKey(): string {
    return AppStorage.get<string>(C.KEY_AI_DEEPSEEK_API_KEY) ?? '';
  }

  /**
   * 设置 DeepSeek API Key
   */
  async setDeepSeekApiKey(key: string) {
    AppStorage.set(C.KEY_AI_DEEPSEEK_API_KEY, key);
    if (key && key.length > 0) {
      await SecureStorage.save(C.KEY_AI_DEEPSEEK_API_KEY, key);
    } else {
      await SecureStorage.delete(C.KEY_AI_DEEPSEEK_API_KEY);
    }
  }

  /**
   * 通用 AI 设置更新 (Provider, Model, Url)
   */
  async updateAIConfig(provider: string, model: string, baseUrl: string) {
    await this.setValue(C.KEY_AI_PROVIDER, provider);
    await this.setValue(C.KEY_AI_MODEL, model);
    await this.setValue(C.KEY_AI_BASE_URL, baseUrl);
  }

  /**
   * 隐私协议相关
   */
  async getIsPrivacyAgreed(): Promise<boolean> {
    if (!this.pref) return false;

    try {
      return await this.pref.get(C.KEY_PRIVACY_AGREE, false) as boolean;
    } catch (_) {
      return false;
    }
  }

  async setPrivacyAgreed(): Promise<void> {
    if (!this.pref) return;

    try {
      await this.pref.put(C.KEY_PRIVACY_AGREE, true);
      await this.pref?.flush();
    } catch (e) {
      console.error('Save preference failed', e);
    }
  }

  async revokePrivacy(): Promise<void> {
    if (!this.pref) return;

    try {
      await this.pref.put(C.KEY_PRIVACY_AGREE, false);
      await this.pref?.flush();
    } catch (e) {
      console.error('Save preference failed', e);
    }
  }

  async setBasicMode(enable: boolean) {
    await this.setValue(C.KEY_BASIC_MODE, enable);
  }

  getBasicMode(): boolean {
    return AppStorage.get<boolean>(C.KEY_BASIC_MODE) ?? false;
  }

  async clearAllAdvancedSettings() {
    if (!this.pref) {
      return;
    }

    try {
      // 1. 清除 AI 相关配置
      await this.pref.delete(C.KEY_AI_DEEPSEEK_API_KEY); // 核心敏感数据
      await this.pref.delete(C.KEY_AI_PROVIDER);
      await this.pref.delete(C.KEY_AI_MODEL);
      await this.pref.delete(C.KEY_AI_BASE_URL);

      // 2. 清除 WebDAV 相关配置
      await this.pref.delete(C.KEY_WEBDAV_URL);
      await this.pref.delete(C.KEY_WEBDAV_USERNAME);
      await this.pref.delete(C.KEY_WEBDAV_PASSWORD);
      await this.pref.delete(C.KEY_CLOUD_SYNC_ENABLE);

      // 3. 立即持久化更改
      await this.pref.flush();

      // 4. 同步更新 AppStorage，确保 UI 立即响应（清空）
      AppStorage.setOrCreate(C.KEY_AI_DEEPSEEK_API_KEY, '');
      AppStorage.setOrCreate(C.KEY_AI_PROVIDER, 'deepseek'); // 恢复默认值
      AppStorage.setOrCreate(C.KEY_AI_MODEL, 'deepseek-chat');
      AppStorage.setOrCreate(C.KEY_AI_BASE_URL, 'https://api.deepseek.com');

      // 如果你的 WebDAV 也有 AppStorage 绑定，也需要置空
      AppStorage.setOrCreate(C.KEY_WEBDAV_URL, '');
      AppStorage.setOrCreate(C.KEY_WEBDAV_USERNAME, '');
      AppStorage.setOrCreate(C.KEY_WEBDAV_PASSWORD, '');
      AppStorage.setOrCreate(C.KEY_CLOUD_SYNC_ENABLE, false);

      AppStorage.setOrCreate(C.KEY_NOTIFY_DDL_WARNING, true);
      AppStorage.setOrCreate(C.KEY_NOTIFY_HABIT_REMINDER, true);
      AppStorage.setOrCreate(C.KEY_NOTIFY_SUMMARY_ENABLE, false);
      AppStorage.setOrCreate(C.KEY_NOTIFY_SUMMARY_TIME, '21:00');

      console.info('LocalValues', 'All advanced settings cleared successfully.');
    } catch (e) {
      console.error('LocalValues', `Failed to clear advanced settings: ${e.message}`);
    }
  }

  getMainLeftButton(): MainButtonType {
    return AppStorage.get<MainButtonType>(C.KEY_MAIN_LEFT_BUTTON) ?? MainButtonType.ARCHIVE;
  }

  async setMainLeftButton(type: MainButtonType) {
    await this.setValue(C.KEY_MAIN_LEFT_BUTTON, type);
  }

  getMainRightButton(): MainButtonType {
    return AppStorage.get<MainButtonType>(C.KEY_MAIN_RIGHT_BUTTON) ?? MainButtonType.SEARCH;
  }

  async setMainRightButton(type: MainButtonType) {
    await this.setValue(C.KEY_MAIN_RIGHT_BUTTON, type);
  }

  /**
   * 获取小组件背景图片的沙箱路径
   * 如果返回空字符串，则表示使用默认样式
   */
  getWidgetBackgroundImage(): string {
    if (!this.pref) return '';

    return AppStorage.get<string>(C.KEY_WIDGET_BG_IMAGE) ?? '';
  }

  /**
   * 设置小组件背景图片路径
   */
  async setWidgetBackgroundImage(path: string) {
    await this.setValue(C.KEY_WIDGET_BG_IMAGE, path);
  }

  getWidgetIsWhiteText(): boolean {
    return AppStorage.get<boolean>(C.KEY_WIDGET_TEXT_WHITE) ?? false;
  }

  // 设置
  async setWidgetIsWhiteText(isWhite: boolean) {
    await this.setValue(C.KEY_WIDGET_TEXT_WHITE, isWhite);
  }

  /**
   * 获取 DDL 临近预警开关状态
   */
  getDDLWarning(): boolean {
    return AppStorage.get<boolean>(C.KEY_NOTIFY_DDL_WARNING) ?? true;
  }

  /**
   * 设置 DDL 临近预警
   */
  async setDDLWarning(enable: boolean) {
    await this.setValue(C.KEY_NOTIFY_DDL_WARNING, enable);
  }

  /**
   * 获取习惯打卡提醒开关状态
   */
  getHabitReminder(): boolean {
    return AppStorage.get<boolean>(C.KEY_NOTIFY_HABIT_REMINDER) ?? true;
  }

  /**
   * 设置习惯打卡提醒
   */
  async setHabitReminder(enable: boolean) {
    await this.setValue(C.KEY_NOTIFY_HABIT_REMINDER, enable);
  }

  /**
   * 获取每日摘要配置
   */
  getDailySummaryConfig(): DailySummaryConfig {
    const enable = AppStorage.get<boolean>(C.KEY_NOTIFY_SUMMARY_ENABLE) ?? false;
    const time = AppStorage.get<string>(C.KEY_NOTIFY_SUMMARY_TIME) ?? '21:00';
    return { enable, time };
  }

  /**
   * 设置每日摘要配置
   * @param enable 开关
   * @param time 时间 (格式 "HH:mm")，如果 enable 为 false，此参数可不传或传空
   */
  async setDailySummaryConfig(enable: boolean, time: string | null) {
    await this.setValue(C.KEY_NOTIFY_SUMMARY_ENABLE, enable);
    if (time) {
      await this.setValue(C.KEY_NOTIFY_SUMMARY_TIME, time);
    }
  }

  getStartupPage(): number {
    return AppStorage.get<number>(C.KEY_STARTUP_PAGE) ?? 0;
  }

  async setStartupPage(index: number) {
    await this.setValue(C.KEY_STARTUP_PAGE, index);
  }

  /**
   * 获取概览页卡片顺序
   */
  getOverviewCardOrder(): string[] {
    return AppStorage.get<string[]>(C.KEY_OVERVIEW_CARD_ORDER) ?? [];
  }

  /**
   * 保存概览页卡片顺序
   */
  async setOverviewCardOrder(order: string[]) {
    await this.setValue(C.KEY_OVERVIEW_CARD_ORDER, order);
  }

  /**
   * 获取趋势页卡片顺序
   */
  getTrendCardOrder(): string[] {
    return AppStorage.get<string[]>(C.KEY_TREND_CARD_ORDER) ?? [];
  }

  /**
   * 保存趋势页卡片顺序
   */
  async setTrendCardOrder(order: string[]) {
    await this.setValue(C.KEY_TREND_CARD_ORDER, order);
  }

  /**
   * 获取是否显示少量英语
   */
  getEnglishSomewhere(): boolean {
    return AppStorage.get<boolean>(C.KEY_ENGLISH_SOMEWHERE) ?? true;
  }

  /**
   * 保存是否显示少量英语
   */
  async setEnglishSomewhere(enable: boolean) {
    await this.setValue(C.KEY_ENGLISH_SOMEWHERE, enable);
  }

  getHabitProgressStyle(): string {
    return AppStorage.get<string>(C.KEY_HABIT_PROGRESS_STYLE) ?? 'ellipse';
  }

  async setHabitProgressStyle(style: string) {
    await this.setValue(C.KEY_HABIT_PROGRESS_STYLE, style);
  }

  getAddSymbolWeight(): number {
    return AppStorage.get<number>(C.KEY_ADD_SYMBOL_WEIGHT) ?? 600;
  }

  async setAddSymbolWeight(weight: number) {
    await this.setValue(C.KEY_ADD_SYMBOL_WEIGHT, weight);
  }

  getTabletUI(): boolean {
    return AppStorage.get<boolean>(C.KEY_ENABLE_TABLET_UI) ?? true;
  }

  async setTabletUI(enable: boolean) {
    await this.setValue(C.KEY_ENABLE_TABLET_UI, enable);
  }

  getSideDashboard(): boolean {
    return AppStorage.get<boolean>(C.KEY_TABLET_SIDE_DASHBOARD) ?? true;
  }

  async setSideDashboard(enable: boolean) {
    await this.setValue(C.KEY_TABLET_SIDE_DASHBOARD, enable);
  }

  getShowAiInput(): boolean {
    return AppStorage.get<boolean>(C.KEY_SHOW_AI_INPUT) ?? true;
  }

  async setShowAiInput(enable: boolean) {
    await this.setValue(C.KEY_SHOW_AI_INPUT, enable);
  }

  getDirectAddOnAi(): boolean {
    return AppStorage.get(C.KEY_DIRECT_ADD_ON_AI) ?? true;
  }

  async setDirectAddOnAi(enable: boolean) {
    await this.setValue(C.KEY_DIRECT_ADD_ON_AI, enable);
  }

  getAutoArchiveDays(): number {
    return AppStorage.get(C.KEY_AUTO_ARCHIVE_DAYS) ?? 3;
  }

  async setAutoArchiveDays(days: number) {
    await this.setValue(C.KEY_AUTO_ARCHIVE_DAYS, days);
  }

  getTombstoneRetentionDays(): number {
    return AppStorage.get(C.KEY_TOMBSTONE_RETENTION_DAYS) ?? 30;
  }

  async setTombstoneRetentionDays(days: number) {
    await this.setValue(C.KEY_TOMBSTONE_RETENTION_DAYS, days);
  }

  getApi23Enable(): boolean {
    return AppStorage.get(C.KEY_ENABLE_API23) ?? true;
  }

  async setApi23Enable(enable: boolean) {
    await this.setValue(C.KEY_ENABLE_API23, enable);
  }

  getSyncMode(): string {
    return AppStorage.get(C.KEY_CLOUD_SYNC_MODE) ?? 'cloud';
  }

  async setSyncMode(mode: string) {
    await this.setValue(C.KEY_CLOUD_SYNC_MODE, mode);
  }

  getMaterialLevel(): string {
    return AppStorage.get(C.KEY_API23_MATERIAL_LEVEL) ?? 'EXQUISITE';
  }

  async setMaterialLevel(level: string) {
    const levels = ['ADAPTIVE', 'SMOOTH', 'GENTLE', 'EXQUISITE'];
    const actual = (levels.includes(level)) ? level : 'ADAPTIVE';
    await this.setValue(C.KEY_API23_MATERIAL_LEVEL, actual);
  }
}
