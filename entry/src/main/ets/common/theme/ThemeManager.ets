import { UIThemePalette, IndicatorSet, createUITheme, INDICATORS_IOS, ITheme, ThemeMap, IndicatorMap,
  THEME_DEFAULT_INDICATOR_MAP,
  INDICATORS_VIBRANT} from "./ThemeModel";
import { ThemeControl } from "@kit.ArkUI";
import { DeadlinerTheme } from "../../AppTheme";
import { preferences } from '@kit.ArkData';

export interface CustomThemeConfig {
  hue: number;
  styleStrength: number;
  isCustom: boolean;
  brand: string;
  accent: string;
  indicatorKey: string;
}

export class ThemeManager {
  private static pref: preferences.Preferences | undefined = undefined;
  private static readonly STORE_NAME = 'deadliner_theme_config';

  // 两个独立的存储 Key
  private static readonly KEY_THEME_UI = 'key_current_theme_ui';        // 存 'classic', 'custom', 'lavender' 等
  private static readonly KEY_THEME_INDICATOR = 'key_current_theme_indicator'; // 存 'morandi', 'vibrant'

  private static readonly KEY_CUSTOM_BACKGROUND = 'key_custom_background';
  private static readonly KEY_CUSTOM_BACKGROUND_BLUR = 'key_custom_background_blur';

  // 自定义 UI 相关的 Key
  private static readonly KEY_CUSTOM_BRAND = 'key_custom_brand';
  private static readonly KEY_CUSTOM_ACCENT = 'key_custom_accent';
  private static readonly KEY_CUSTOM_TAB_ICON = 'key_custom_tab_icon';
  private static readonly KEY_PARAM_HUE = 'key_param_hue';
  private static readonly KEY_PARAM_STYLE = 'key_param_style';
  private static readonly KEY_THEME_WHITE_GLOW_PREFIX = 'key_theme_white_glow_';

  // 兼容旧 Key
  private static readonly KEY_THEME_LEGACY = 'key_current_theme';

  static async init(context: Context) {
    try {
      ThemeManager.pref = await preferences.getPreferences(context, ThemeManager.STORE_NAME);

      let bgUri = await ThemeManager.pref.get(ThemeManager.KEY_CUSTOM_BACKGROUND, '') as string;
      AppStorage.setOrCreate('customBackgroundImage', bgUri);

      let bgBlur = await ThemeManager.pref.get(ThemeManager.KEY_CUSTOM_BACKGROUND_BLUR, false) as boolean;
      AppStorage.setOrCreate('customBackgroundBlur', bgBlur);

      // 1. 读取配置
      let uiKey = await ThemeManager.pref.get(ThemeManager.KEY_THEME_UI, '') as string;
      let indicatorKey = await ThemeManager.pref.get(ThemeManager.KEY_THEME_INDICATOR, '') as string;

      // 兼容老数据迁移
      if (!uiKey) {
        uiKey = await ThemeManager.pref.get(ThemeManager.KEY_THEME_LEGACY, 'vibrant') as string;
      }

      if (!indicatorKey) {
        indicatorKey = THEME_DEFAULT_INDICATOR_MAP[uiKey] || 'vibrant';
      }

      // 2. 初始化 AppStorage
      AppStorage.setOrCreate('currentThemeKey', uiKey);
      AppStorage.setOrCreate('currentIndicatorKey', indicatorKey);

      // 3. 合并并应用
      await ThemeManager.combineAndApplyTheme(uiKey, indicatorKey);

    } catch (err) {
      console.error('[ThemeManager] Init failed:', err);
      // 兜底：Vibrant + iOS
      ThemeManager.updateAppState(ThemeManager.mergeTheme(ThemeMap['vibrant'], INDICATORS_VIBRANT));
    }
  }

  static async setCustomBackground(uri: string, isBlur: boolean) {
    console.info('[ThemeManager] Setting custom background:', uri);
    // 立即更新内存，触发 UI 刷新
    AppStorage.setOrCreate('customBackgroundImage', uri);
    AppStorage.setOrCreate('customBackgroundBlur', isBlur);

    // 异步持久化到本地
    if (ThemeManager.pref) {
      try {
        await ThemeManager.pref.put(ThemeManager.KEY_CUSTOM_BACKGROUND, uri);
        await ThemeManager.pref.put(ThemeManager.KEY_CUSTOM_BACKGROUND_BLUR, isBlur);
        await ThemeManager.pref.flush();
      } catch (e) {
        console.error('[ThemeManager] Failed to save custom background', e);
      }
    }
  }

  static async clearCustomBackground() {
    AppStorage.setOrCreate('customBackgroundImage', '');
    if (ThemeManager.pref) {
      await ThemeManager.pref.put(ThemeManager.KEY_CUSTOM_BACKGROUND, '');
      await ThemeManager.pref.flush();
    }
  }

  /**
   * 获取当前生效的完整主题对象 (UI + Indicators)
   * 供业务逻辑同步调用
   */
  static getCurrentTheme(): ITheme {
    // 优先从 AppStorage 获取合并后的对象
    let theme = AppStorage.get<ITheme>('currentTheme');
    if (!theme) {
      // 如果未初始化，返回默认兜底
      return ThemeManager.mergeTheme(ThemeMap['vibrant'], INDICATORS_VIBRANT);
    }
    return theme;
  }

  /**
   * 应用自定义颜色
   * @param isMorandi - 用户在自定义面板切换 "莫兰迪/生动" 开关时传入
   */
  static async applyCustomColors(
    brand: string, accent: string,
    tabIcon: string | ResourceColor | undefined,
    indicatorKey: string,
    hue: number, styleStrength: number,
    saveToDisk: boolean = true
  ) {
    // 1. 创建 UI 部分 (内存中)
    const customUI = await ThemeManager.resolveThemeGlow(
      'custom',
      ThemeManager.createCustomUITheme(brand, accent, tabIcon, hue)
    );

    const targetIndicatorKey = indicatorKey;
    const indicatorSet = IndicatorMap[targetIndicatorKey];

    // 3. 合并
    const fullTheme = ThemeManager.mergeTheme(customUI, indicatorSet);

    // 4. 更新内存状态
    ThemeManager.updateAppState(fullTheme);
    AppStorage.set('currentThemeKey', 'custom');
    AppStorage.set('currentIndicatorKey', targetIndicatorKey); // ✅ 同步更新指示器 Key

    // 5. 持久化 (保存所有参数)
    if (saveToDisk && ThemeManager.pref) {
      try {
        await ThemeManager.pref.put(ThemeManager.KEY_THEME_UI, 'custom');

        await ThemeManager.pref.put(ThemeManager.KEY_THEME_INDICATOR, targetIndicatorKey);

        await ThemeManager.pref.put(ThemeManager.KEY_CUSTOM_BRAND, brand);
        await ThemeManager.pref.put(ThemeManager.KEY_CUSTOM_ACCENT, accent);
        await ThemeManager.pref.put(ThemeManager.KEY_CUSTOM_TAB_ICON, tabIcon ? tabIcon.toString() : '');

        await ThemeManager.pref.put(ThemeManager.KEY_PARAM_HUE, hue);
        await ThemeManager.pref.put(ThemeManager.KEY_PARAM_STYLE, styleStrength);

        await ThemeManager.pref.flush();
      } catch (e) {
        console.error('[ThemeManager] Failed to save custom UI', e);
      }
    }
  }

  /**
   * 获取自定义配置回显 (供 ColorCustomizer 初始化)
   */
  static async getCustomConfig(): Promise<CustomThemeConfig> {
    if (!ThemeManager.pref) return { hue: 210, styleStrength: 50, isCustom: false, brand: '', accent: '', indicatorKey: 'vibrant' };

    const uiKey = await ThemeManager.pref.get(ThemeManager.KEY_THEME_UI, 'vibrant') as string;
    const indKey = await ThemeManager.pref.get(ThemeManager.KEY_THEME_INDICATOR,
      THEME_DEFAULT_INDICATOR_MAP[uiKey] || 'vibrant') as string;

    const hue = await ThemeManager.pref.get(ThemeManager.KEY_PARAM_HUE, 210) as number;
    const style = await ThemeManager.pref.get(ThemeManager.KEY_PARAM_STYLE, 50) as number;
    const brand = await ThemeManager.pref.get(ThemeManager.KEY_CUSTOM_BRAND, '') as string;
    const accent = await ThemeManager.pref.get(ThemeManager.KEY_CUSTOM_ACCENT, '') as string;

    return {
      hue: hue,
      styleStrength: style,
      isCustom: uiKey === 'custom',
      brand: brand,
      accent: accent,
      indicatorKey: indKey
    };
  }

  /**
   * 将 UI 和 Indicator 显式合并 (解决 Spread 语法问题)
   */
  private static mergeTheme(ui: UIThemePalette, ind: IndicatorSet): ITheme {
    return {
      // UI 部分
      brand: ui.brand,
      brand50: ui.brand50,
      accent: ui.accent,
      bgPrimary: ui.bgPrimary,
      widgetBgStart: ui.widgetBgStart,
      widgetBgEnd: ui.widgetBgEnd,
      widgetDecor: ui.widgetDecor,
      tabIcon: ui.tabIcon,
      useWhiteGlow: ui.useWhiteGlow,

      chartInfo: ind.chartInfo,
      chartCompleted: ind.chartCompleted,
      chartTodo: ind.chartTodo,
      chartOverdue: ind.chartOverdue,

      indicatorUndergo: ind.indicatorUndergo,
      indicatorUndergo50: ind.indicatorUndergo50,
      indicatorUndergo70: ind.indicatorUndergo70,
      bgUndergo: ind.bgUndergo,
      bgUndergo40: ind.bgUndergo40,

      indicatorNear: ind.indicatorNear,
      indicatorNear50: ind.indicatorNear50,
      indicatorNear70: ind.indicatorNear70,
      bgNear: ind.bgNear,
      bgNear40: ind.bgNear40,

      indicatorPassed: ind.indicatorPassed,
      indicatorPassed50: ind.indicatorPassed50,
      indicatorPassed70: ind.indicatorPassed70,
      bgPassed: ind.bgPassed,
      bgPassed40: ind.bgPassed40,

      indicatorCompleted: ind.indicatorCompleted,
      indicatorCompleted50: ind.indicatorCompleted50,
      indicatorCompleted70: ind.indicatorCompleted70,
      bgCompleted: ind.bgCompleted,
      bgCompleted40: ind.bgCompleted40
    };
  }

  private static async combineAndApplyTheme(uiKey: string, indicatorKey: string) {
    let uiPalette: UIThemePalette;

    if (uiKey === 'custom') {
      uiPalette = await ThemeManager.loadCustomUIFromDisk();
    } else {
      uiPalette = ThemeMap[uiKey] || ThemeMap['vibrant'];
    }

    uiPalette = await ThemeManager.resolveThemeGlow(uiKey, uiPalette);

    const indicatorSet = IndicatorMap[indicatorKey] || IndicatorMap['vibrant'];
    const fullTheme = ThemeManager.mergeTheme(uiPalette, indicatorSet);

    ThemeManager.updateAppState(fullTheme);
  }

  private static updateAppState(theme: ITheme) {
    AppStorage.setOrCreate('currentTheme', theme);
    ThemeManager.applySystemTheme(theme);
  }

  private static applySystemTheme(theme: ITheme) {
    try {
      ThemeControl.setDefaultTheme(new DeadlinerTheme(theme));
    } catch (error) {
      console.error('[ThemeManager]', 'Failed to apply system theme', error);
    }
  }

  // =================================================================
  // 公共 API (切换逻辑)
  // =================================================================

  static async switchUITheme(uiKey: string) {
    console.info('[ThemeManager]', `Switching UI to: ${uiKey}`);

    const defaultIndicatorKey = THEME_DEFAULT_INDICATOR_MAP[uiKey] || 'vibrant';

    AppStorage.set('currentThemeKey', uiKey);
    AppStorage.set('currentIndicatorKey', defaultIndicatorKey);

    await ThemeManager.combineAndApplyTheme(uiKey, defaultIndicatorKey);

    if (ThemeManager.pref) {
      try {
        await ThemeManager.pref.put(ThemeManager.KEY_THEME_UI, uiKey);
        await ThemeManager.pref.put(ThemeManager.KEY_THEME_INDICATOR, defaultIndicatorKey);
        await ThemeManager.pref.flush();
      } catch (e) {
        console.error('[ThemeManager] Switch UI save failed', e);
      }
    }
  }

  /**
   * 切换 指示器/图表风格 (如 Morandi -> Vibrant)
   * 行为：保持当前 UI 皮肤不变，只换图表
   */
  static async switchIndicatorStyle(indicatorKey: string) {
    console.info('[ThemeManager]', `Switching Indicators to: ${indicatorKey}`);
    AppStorage.set('currentIndicatorKey', indicatorKey);

    const currentUIKey = AppStorage.get<string>('currentThemeKey') || 'vibrant';

    await ThemeManager.combineAndApplyTheme(currentUIKey, indicatorKey);

    if (ThemeManager.pref) {
      await ThemeManager.pref.put(ThemeManager.KEY_THEME_INDICATOR, indicatorKey);
      await ThemeManager.pref.flush();
    }
  }

  // 辅助方法：从磁盘读取自定义 UI 配置
  private static async loadCustomUIFromDisk(): Promise<UIThemePalette> {
    if (!ThemeManager.pref) return ThemeMap['vibrant'];

    const brand = await ThemeManager.pref.get(ThemeManager.KEY_CUSTOM_BRAND, '#FF0A59F7') as string;
    const accent = await ThemeManager.pref.get(ThemeManager.KEY_CUSTOM_ACCENT, '#FF0A59F7') as string;
    const tabIcon = await ThemeManager.pref.get(ThemeManager.KEY_CUSTOM_TAB_ICON, '') as string;
    const hue = await ThemeManager.pref.get(ThemeManager.KEY_PARAM_HUE, 210) as number;

    return ThemeManager.createCustomUITheme(brand, accent, tabIcon || undefined, hue);
  }

  // 纯内存操作：创建 UI 部分
  private static createCustomUITheme(
    brand: string,
    accent: string,
    tabIcon?: string | ResourceColor,
    hue?: number
  ): UIThemePalette {
    const withAlpha = (hex: string, alpha: string) => {
      if (hex.length === 9) return hex;
      return hex.replace('#', '#' + alpha);
    };

    const resolvedHue = hue ?? 210;
    return createUITheme(
      brand,
      withAlpha(brand, "80"),
      accent,
      $r('app.color.background_primary'),
      withAlpha(brand, "33"),
      $r('app.color.background_primary'),
      brand,
      tabIcon,
      ThemeManager.isCoolHue(resolvedHue)
    );
  }

  private static isCoolHue(hue: number): boolean {
    return hue >= 160 && hue <= 260;
  }

  private static async resolveThemeGlow(uiKey: string, uiPalette: UIThemePalette): Promise<UIThemePalette> {
    if (!ThemeManager.pref) {
      return uiPalette;
    }

    const prefKey = `${ThemeManager.KEY_THEME_WHITE_GLOW_PREFIX}${uiKey}`;
    const storedValue = await ThemeManager.pref.get(prefKey, uiPalette.useWhiteGlow) as boolean;
    return {
      brand: uiPalette.brand,
      brand50: uiPalette.brand50,
      accent: uiPalette.accent,
      bgPrimary: uiPalette.bgPrimary,
      widgetBgStart: uiPalette.widgetBgStart,
      widgetBgEnd: uiPalette.widgetBgEnd,
      widgetDecor: uiPalette.widgetDecor,
      tabIcon: uiPalette.tabIcon,
      useWhiteGlow: storedValue
    };
  }

  static async setCurrentThemeWhiteGlow(enable: boolean) {
    const currentUIKey = AppStorage.get<string>('currentThemeKey') || 'vibrant';
    const currentIndicatorKey = AppStorage.get<string>('currentIndicatorKey') || (THEME_DEFAULT_INDICATOR_MAP[currentUIKey] || 'vibrant');

    if (ThemeManager.pref) {
      await ThemeManager.pref.put(`${ThemeManager.KEY_THEME_WHITE_GLOW_PREFIX}${currentUIKey}`, enable);
      await ThemeManager.pref.flush();
    }

    await ThemeManager.combineAndApplyTheme(currentUIKey, currentIndicatorKey);
  }
}
