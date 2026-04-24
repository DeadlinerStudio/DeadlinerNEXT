import { common } from '@kit.AbilityKit';

/**
 * 纯 UI 皮肤配置 (Brand, Accent, Background)
 * 负责应用整体的视觉基调
 */
export interface UIThemePalette {
  brand: ResourceColor;
  brand50: ResourceColor;
  accent: ResourceColor;
  bgPrimary: ResourceColor;
  tabIcon: ResourceColor;
}

/**
 * 功能/指示器配置 (Undergo, Passed, Charts)
 * 负责进度条、状态圆环、图表颜色
 */
export interface IndicatorSet {
  // --- 图表配色 ---
  chartInfo: ResourceColor;
  chartCompleted: ResourceColor;
  chartTodo: ResourceColor;
  chartOverdue: ResourceColor;

  // --- 状态指示色 ---
  indicatorUndergo: ResourceColor;
  indicatorUndergo50: ResourceColor;
  indicatorUndergo70: ResourceColor;
  bgUndergo: ResourceColor;
  bgUndergo40: ResourceColor;

  indicatorNear: ResourceColor;
  indicatorNear50: ResourceColor;
  indicatorNear70: ResourceColor;
  bgNear: ResourceColor;
  bgNear40: ResourceColor;

  indicatorPassed: ResourceColor;
  indicatorPassed50: ResourceColor;
  indicatorPassed70: ResourceColor;
  bgPassed: ResourceColor;
  bgPassed40: ResourceColor;

  indicatorCompleted: ResourceColor;
  indicatorCompleted50: ResourceColor;
  indicatorCompleted70: ResourceColor;
  bgCompleted: ResourceColor;
  bgCompleted40: ResourceColor;
}

/**
 * 最终的应用主题接口 (合并了 UI 和 Indicator)
 * 保持这个接口不变，确保项目中 @StorageProp('currentTheme') 不会报错
 */
export interface ITheme extends UIThemePalette, IndicatorSet {}

export const INDICATORS_MORANDI: IndicatorSet = {
  chartInfo: $r('app.color.chart_blue'),
  chartCompleted: $r('app.color.chart_green'),
  chartTodo: $r('app.color.chart_orange'),
  chartOverdue: $r('app.color.chart_red'),

  indicatorUndergo: $r('app.color.indicator_morandi_undergo'),
  indicatorUndergo50: $r('app.color.indicator_morandi_undergo_50'),
  indicatorUndergo70: $r('app.color.indicator_morandi_undergo_70'),
  bgUndergo: $r('app.color.bg_morandi_undergo'),
  bgUndergo40: $r('app.color.bg_morandi_undergo_40'),

  indicatorNear: $r('app.color.indicator_morandi_near'),
  indicatorNear50: $r('app.color.indicator_morandi_near_50'),
  indicatorNear70: $r('app.color.indicator_morandi_near_70'),
  bgNear: $r('app.color.bg_morandi_near'),
  bgNear40: $r('app.color.bg_morandi_near_40'),

  indicatorPassed: $r('app.color.indicator_morandi_passed'),
  indicatorPassed50: $r('app.color.indicator_morandi_passed_50'),
  indicatorPassed70: $r('app.color.indicator_morandi_passed_70'),
  bgPassed: $r('app.color.bg_morandi_passed'),
  bgPassed40: $r('app.color.bg_morandi_passed_40'),

  indicatorCompleted: $r('app.color.indicator_morandi_completed'),
  indicatorCompleted50: $r('app.color.indicator_morandi_completed_50'),
  indicatorCompleted70: $r('app.color.indicator_morandi_completed_70'),
  bgCompleted: $r('app.color.bg_morandi_completed'),
  bgCompleted40: $r('app.color.bg_morandi_completed_40'),
};

export const INDICATORS_VIBRANT: IndicatorSet = {
  chartInfo: $r('app.color.chart_vibrant_total'),
  chartCompleted: $r('app.color.chart_vibrant_completed'),
  chartTodo: $r('app.color.chart_vibrant_todo'),
  chartOverdue: $r('app.color.chart_vibrant_overdue'),

  indicatorUndergo: $r('app.color.indicator_vibrant_undergo'),
  indicatorUndergo50: $r('app.color.indicator_vibrant_undergo_50'),
  indicatorUndergo70: $r('app.color.indicator_vibrant_undergo_70'),
  bgUndergo: $r('app.color.bg_vibrant_undergo'),
  bgUndergo40: $r('app.color.bg_vibrant_undergo_40'),

  indicatorNear: $r('app.color.indicator_vibrant_near'),
  indicatorNear50: $r('app.color.indicator_vibrant_near_50'),
  indicatorNear70: $r('app.color.indicator_vibrant_near_70'),
  bgNear: $r('app.color.bg_vibrant_near'),
  bgNear40: $r('app.color.bg_vibrant_near_40'),

  indicatorPassed: $r('app.color.indicator_vibrant_passed'),
  indicatorPassed50: $r('app.color.indicator_vibrant_passed_50'),
  indicatorPassed70: $r('app.color.indicator_vibrant_passed_70'),
  bgPassed: $r('app.color.bg_vibrant_passed'),
  bgPassed40: $r('app.color.bg_vibrant_passed_40'),

  indicatorCompleted: $r('app.color.indicator_vibrant_completed'),
  indicatorCompleted50: $r('app.color.indicator_vibrant_completed_50'),
  indicatorCompleted70: $r('app.color.indicator_vibrant_completed_70'),
  bgCompleted: $r('app.color.bg_vibrant_completed'),
  bgCompleted40: $r('app.color.bg_vibrant_completed_40'),
};

export const INDICATORS_NATURE: IndicatorSet = {
  chartInfo: $r('app.color.chart_nature_total'),
  chartCompleted: $r('app.color.chart_nature_completed'),
  chartTodo: $r('app.color.chart_nature_todo'),
  chartOverdue: $r('app.color.chart_nature_overdue'),

  indicatorUndergo: $r('app.color.indicator_nature_undergo'),
  indicatorUndergo50: $r('app.color.indicator_nature_undergo_50'),
  indicatorUndergo70: $r('app.color.indicator_nature_undergo_70'),
  bgUndergo: $r('app.color.bg_nature_undergo'),
  bgUndergo40: $r('app.color.bg_nature_undergo_40'),

  indicatorNear: $r('app.color.indicator_nature_near'),
  indicatorNear50: $r('app.color.indicator_nature_near_50'),
  indicatorNear70: $r('app.color.indicator_nature_near_70'),
  bgNear: $r('app.color.bg_nature_near'),
  bgNear40: $r('app.color.bg_nature_near_40'),

  indicatorPassed: $r('app.color.indicator_nature_passed'),
  indicatorPassed50: $r('app.color.indicator_nature_passed_50'),
  indicatorPassed70: $r('app.color.indicator_nature_passed_70'),
  bgPassed: $r('app.color.bg_nature_passed'),
  bgPassed40: $r('app.color.bg_nature_passed_40'),

  indicatorCompleted: $r('app.color.indicator_nature_completed'),
  indicatorCompleted50: $r('app.color.indicator_nature_completed_50'),
  indicatorCompleted70: $r('app.color.indicator_nature_completed_70'),
  bgCompleted: $r('app.color.bg_nature_completed'),
  bgCompleted40: $r('app.color.bg_nature_completed_40'),
};

export const INDICATORS_OCEAN: IndicatorSet = {
  chartInfo: $r('app.color.chart_ocean_total'),
  chartCompleted: $r('app.color.chart_ocean_completed'),
  chartTodo: $r('app.color.chart_ocean_todo'),
  chartOverdue: $r('app.color.chart_ocean_overdue'),

  indicatorUndergo: $r('app.color.indicator_ocean_undergo'),
  indicatorUndergo50: $r('app.color.indicator_ocean_undergo_50'),
  indicatorUndergo70: $r('app.color.indicator_ocean_undergo_70'),
  bgUndergo: $r('app.color.bg_ocean_undergo'),
  bgUndergo40: $r('app.color.bg_ocean_undergo_40'),

  indicatorNear: $r('app.color.indicator_ocean_near'),
  indicatorNear50: $r('app.color.indicator_ocean_near_50'),
  indicatorNear70: $r('app.color.indicator_ocean_near_70'),
  bgNear: $r('app.color.bg_ocean_near'),
  bgNear40: $r('app.color.bg_ocean_near_40'),

  indicatorPassed: $r('app.color.indicator_ocean_passed'),
  indicatorPassed50: $r('app.color.indicator_ocean_passed_50'),
  indicatorPassed70: $r('app.color.indicator_ocean_passed_70'),
  bgPassed: $r('app.color.bg_ocean_passed'),
  bgPassed40: $r('app.color.bg_ocean_passed_40'),

  indicatorCompleted: $r('app.color.indicator_ocean_completed'),
  indicatorCompleted50: $r('app.color.indicator_ocean_completed_50'),
  indicatorCompleted70: $r('app.color.indicator_ocean_completed_70'),
  bgCompleted: $r('app.color.bg_ocean_completed'),
  bgCompleted40: $r('app.color.bg_ocean_completed_40'),
};

export const INDICATORS_RETRO: IndicatorSet = {
  chartInfo: $r('app.color.chart_retro_total'),
  chartCompleted: $r('app.color.chart_retro_completed'),
  chartTodo: $r('app.color.chart_retro_todo'),
  chartOverdue: $r('app.color.chart_retro_overdue'),

  indicatorUndergo: $r('app.color.indicator_retro_undergo'),
  indicatorUndergo50: $r('app.color.indicator_retro_undergo_50'),
  indicatorUndergo70: $r('app.color.indicator_retro_undergo_70'),
  bgUndergo: $r('app.color.bg_retro_undergo'),
  bgUndergo40: $r('app.color.bg_retro_undergo_40'),

  indicatorNear: $r('app.color.indicator_retro_near'),
  indicatorNear50: $r('app.color.indicator_retro_near_50'),
  indicatorNear70: $r('app.color.indicator_retro_near_70'),
  bgNear: $r('app.color.bg_retro_near'),
  bgNear40: $r('app.color.bg_retro_near_40'),

  indicatorPassed: $r('app.color.indicator_retro_passed'),
  indicatorPassed50: $r('app.color.indicator_retro_passed_50'),
  indicatorPassed70: $r('app.color.indicator_retro_passed_70'),
  bgPassed: $r('app.color.bg_retro_passed'),
  bgPassed40: $r('app.color.bg_retro_passed_40'),

  indicatorCompleted: $r('app.color.indicator_retro_completed'),
  indicatorCompleted50: $r('app.color.indicator_retro_completed_50'),
  indicatorCompleted70: $r('app.color.indicator_retro_completed_70'),
  bgCompleted: $r('app.color.bg_retro_completed'),
  bgCompleted40: $r('app.color.bg_retro_completed_40'),
};

export const INDICATORS_IOS: IndicatorSet = {
  chartInfo: $r('app.color.ios_blue'),
  chartCompleted: $r('app.color.ios_green'),
  chartTodo: $r('app.color.ios_orange'),
  chartOverdue: $r('app.color.ios_red'),

  indicatorUndergo: $r('app.color.indicator_ios_undergo'),
  indicatorUndergo50: $r('app.color.indicator_ios_undergo_50'),
  indicatorUndergo70: $r('app.color.indicator_ios_undergo_70'),
  bgUndergo: $r('app.color.bg_ios_undergo'),
  bgUndergo40: $r('app.color.bg_ios_undergo_40'),

  indicatorNear: $r('app.color.indicator_ios_near'),
  indicatorNear50: $r('app.color.indicator_ios_near_50'),
  indicatorNear70: $r('app.color.indicator_ios_near_70'),
  bgNear: $r('app.color.bg_ios_near'),
  bgNear40: $r('app.color.bg_ios_near_40'),

  indicatorPassed: $r('app.color.indicator_ios_passed'),
  indicatorPassed50: $r('app.color.indicator_ios_passed_50'),
  indicatorPassed70: $r('app.color.indicator_ios_passed_70'),
  bgPassed: $r('app.color.bg_ios_passed'),
  bgPassed40: $r('app.color.bg_ios_passed_40'),

  indicatorCompleted: $r('app.color.indicator_ios_completed'),
  indicatorCompleted50: $r('app.color.indicator_ios_completed_50'),
  indicatorCompleted70: $r('app.color.indicator_ios_completed_70'),
  bgCompleted: $r('app.color.bg_ios_completed'),
  bgCompleted40: $r('app.color.bg_ios_completed_40'),
};

export const IndicatorMap: Record<string, IndicatorSet> = {
  'morandi': INDICATORS_MORANDI,
  'vibrant': INDICATORS_VIBRANT,
  'nature': INDICATORS_NATURE,
  'ocean': INDICATORS_OCEAN,
  'retro': INDICATORS_RETRO,
  'ios': INDICATORS_IOS
};

export function createUITheme(
  brand: ResourceColor,
  brand50: ResourceColor,
  accent: ResourceColor,
  bgPrimary: ResourceColor,
  tabIcon?: ResourceColor
): UIThemePalette {
  return {
    brand: brand,
    brand50: brand50,
    accent: accent,
    bgPrimary: bgPrimary,
    tabIcon: tabIcon ? tabIcon : brand,
  };
}

export const ThemeMap: Record<string, UIThemePalette> = {
  'classic': createUITheme(
    $r('app.color.brand'),
    $r('app.color.brand_50'),
    $r('app.color.accent'),
    $r('app.color.background_primary')
  ),
  'time': createUITheme(
    $r('app.color.brand'),
    $r('app.color.brand_50'),
    $r('app.color.accent'),
    $r('app.color.background_primary'),
    $r('app.color.cold')
  ),
  'vibrant': createUITheme(
    $r('app.color.brand_vibrant'),
    $r('app.color.brand_vibrant_50'),
    $r('app.color.accent_vibrant'),
    $r('app.color.background_primary')
  ),
  'nature': createUITheme(
    $r('app.color.brand_nature'),
    $r('app.color.brand_nature_50'),
    $r('app.color.accent_nature'),
    $r('app.color.background_primary')
  ),
  'sunset': createUITheme(
    $r('app.color.brand_sunset'),
    $r('app.color.brand_sunset_50'),
    $r('app.color.accent_sunset'),
    $r('app.color.background_primary')
  ),
  'lavender': createUITheme(
    $r('app.color.brand_lavender'),
    $r('app.color.brand_lavender_50'),
    $r('app.color.accent_lavender'),
    $r('app.color.background_primary')
  ),
  'harmony': createUITheme(
    $r('sys.color.ohos_id_color_emphasize'),
    '#800A59F7',
    $r('sys.color.ohos_id_color_emphasize_contrary'),
    $r('app.color.background_primary')
  ),
  'galaxy': createUITheme(
    $r('sys.color.ohos_id_color_emphasize'),
    '#800A59F7',
    $r('sys.color.ohos_id_color_emphasize_contrary'),
    $r('app.color.background_primary'),
    $r('app.color.cold')
  ),
  'glacier': createUITheme(
    $r('app.color.brand_glacier'),
    $r('app.color.brand_glacier_50'),
    $r('app.color.accent_glacier'),
    $r('app.color.background_primary'),
    $r('app.color.cold')
  ),
  'tiktick': createUITheme(
    $r('app.color.brand_tik'),
    $r('app.color.brand_tik_50'),
    $r('app.color.accent_tik'),
    $r('app.color.background_primary'),
    $r('app.color.cold')
  )
};

export const THEME_DEFAULT_INDICATOR_MAP: Record<string, string> = {
  'classic': 'morandi',
  'time': 'morandi',
  'vibrant': 'ios',
  'nature': 'nature',
  'sunset': 'retro',
  'lavender': 'morandi',
  'harmony': 'vibrant',
  'galaxy': 'vibrant',
  'glacier': 'ocean',
  'tiktick': 'vibrant'
};
