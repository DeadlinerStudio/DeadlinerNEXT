import { LengthMetrics } from '@kit.ArkUI';
import { hdsMaterial, HdsNavigationTitleBarStyle, ScrollEffectType, TitleBarStyleOptions } from '@kit.UIDesignKit';
import { ThemeManager } from '../theme/ThemeManager';
import { deviceInfo } from '@kit.BasicServicesKit';
import { LocalValues } from '../local/LocalValues';
import { getHdsMaterialLevel } from './MaterialLevel';

/**
 * 获取统一的沉浸式标题栏样式配置
 * @param isWideScreen 是否为宽屏模式（宽屏下通常不需要模糊，而是纯色背景）
 * @param disableMaterial 禁用新材质
 * @returns HdsNavigationTitleBarStyle
 */
export function getImmersiveTitleBarStyle(
  isWideScreen: boolean,
  disableMaterial: boolean = false,
  level?: string,
) : TitleBarStyleOptions {
  if (deviceInfo.distributionOSApiVersion >= 60100 && LocalValues.getInstance().getApi23Enable()) {
    return {
      scrollEffectOpts: {
        enableScrollEffect: !isWideScreen,
        scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
        blurEffectiveStartOffset: LengthMetrics.vp(0),
        blurEffectiveEndOffset: LengthMetrics.vp(10),
      },
      originalStyle: {
        backgroundStyle: {
          backgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
        },
        contentStyle: {
          titleStyle: {
            mainTitleColor: $r('app.color.font_primary'), subTitleColor: $r('app.color.font_secondary')
          },
          backIconStyle: { iconColor: $r('app.color.font_primary'), },
          subIconStyle: { iconColor: $r('app.color.font_primary'), },
          menuStyle: { iconColor: $r('app.color.font_primary') }
        }
      },
      scrollEffectStyle: {
        backgroundStyle: {
          backgroundColor: isWideScreen ?
            ThemeManager.getCurrentTheme().bgPrimary :
            // $r('sys.color.ohos_id_color_navigation_background_blur'),
            $r('app.color.background_primary_50'),
          // blurRadius: 32
        },
        contentStyle: {
          titleStyle: {
            mainTitleColor: $r('app.color.font_primary'), subTitleColor: $r('app.color.font_secondary')
          },
          backIconStyle: { iconColor: $r('app.color.font_primary'), },
          subIconStyle: { iconColor: $r('app.color.font_primary'), },
          menuStyle: { iconColor: $r('app.color.font_primary') }
        }
      },
      systemMaterialEffect: disableMaterial ? undefined : {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: getHdsMaterialLevel(level)
      },
    };
  } else {
    return {
      scrollEffectOpts: {
        enableScrollEffect: !isWideScreen,
        scrollEffectType: ScrollEffectType.COMMON_BLUR,
        blurEffectiveStartOffset: LengthMetrics.vp(0),
        blurEffectiveEndOffset: LengthMetrics.vp(10)
      },
      originalStyle: {
        backgroundStyle: {
          backgroundColor: isWideScreen ?
            ThemeManager.getCurrentTheme().bgPrimary :
            $r('sys.color.ohos_id_color_background_transparent'),
        },
      },
      scrollEffectStyle: {
        backgroundStyle: {
          backgroundColor: isWideScreen ?
            ThemeManager.getCurrentTheme().bgPrimary :
            $r('sys.color.ohos_id_color_navigation_background_blur'),
        },
      },
    };
  }
}