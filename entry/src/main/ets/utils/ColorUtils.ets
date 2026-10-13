import { AppLog } from '../common/logging/AppLog';
import { Context } from '@kit.AbilityKit';
import { ThemeManager } from '../common/theme/ThemeManager';

export class ColorUtils {
  /**
   * 简单的透明度处理函数，接受一个颜色和透明度值，并返回带透明度的颜色。
   * @param color - 原始颜色（支持十六进制色值）
   * @param alpha - 透明度，范围从 0（完全透明）到 1（完全不透明）
   * @returns 带透明度的颜色
   */
  static addAlpha(color: ResourceColor, alpha: number, ctx: Context | undefined = undefined): ResourceColor | string {
    // 如果颜色是十六进制格式 (#RRGGBB)，则增加透明度
    if (typeof color === 'string' && color.startsWith('#') && color.length === 7) {
      // 从 #RRGGBB 获取 R、G、B 值
      let r = parseInt(color.substring(1, 3), 16);
      let g = parseInt(color.substring(3, 5), 16);
      let b = parseInt(color.substring(5, 7), 16);

      // 将透明度（alpha）值转换为 2 位十六进制字符串
      let a = Math.round(alpha * 255).toString(16).padStart(2, '0');

      // 返回带透明度的颜色（#RRGGBBAA）
      return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}${a}`;
    } else if (ctx) {
      return ColorUtils.applyAlpha(ctx, color, alpha)
    }

    // 如果颜色已经是 ResourceColor 类型，直接返回
    return color;
  }

  /**
   * 给 ResourceColor 添加透明度
   * @param context 组件上下文 (getContext(this))
   * @param color 颜色 (Resource, Color, string, number)
   * @param alpha 透明度 0.0 - 1.0
   * @returns rgba 字符串，可直接用于属性赋值
   */
  static applyAlpha(context: Context, color: ResourceColor, alpha: number): string {
    const config = context.resourceManager.getConfigurationSync();
    AppLog.debug('Native', 'ColorUtils: Current ColorMode is ' + config.colorMode);

    let colorValue: number;

    try {
      if (typeof color === 'object' &&  (color as Resource).id) {
        // 1. 如果是 Resource ($r)，使用 ResourceManager 解析
        // 注意：getColorSync 返回的是十进制整数 (通常是 AARRGGBB 或 RRGGBB)
        const resourceManager = context.resourceManager;
        colorValue = resourceManager.getColorSync(color as Resource);
      } else if (typeof color === 'number') {
        // 2. 如果是 Color 枚举或 Hex 数字
        colorValue = color;
      } else if (typeof color === 'string') {
        // 3. 如果是字符串，建议直接返回 rgba 拼接 (简单处理 hex 字符串)
        // 这里为了简化逻辑，暂不处理复杂的颜色名解析，建议主要使用 Resource 或 Hex
        return color; // 字符串处理比较复杂，建议优先用 Resource
      } else {
        const resourceManager = context.resourceManager;
        colorValue = resourceManager.getColorSync($r('app.color.background_primary'));
      }

      // 解析 ARGB / RGB
      // 鸿蒙 getColorSync 返回的一般是带 Alpha 的整数，我们需要提取 RGB 重新组合
      const r = (colorValue >> 16) & 0xFF;
      const g = (colorValue >> 8) & 0xFF;
      const b = colorValue & 0xFF;

      // 使用 CSS 样式的 rgba 语法，ArkTS 支持这种写法
      return `rgba(${r}, ${g}, ${b}, ${alpha})`;

    } catch (e) {
      AppLog.error('Native', 'ColorUtils parse error:', e);
      return '#000000'; // 失败回退
    }
  }

  /**
   * 将 hex 字符串转为 mpcharts 需要的 number
   * @param colorStr 例如 "#FF0000" 或 "#80FF0000"
   */
  static parseColor(colorStr: string): number {
    if (!colorStr) return Color.Black; // 兜底

    let raw = colorStr;
    if (raw.startsWith('#')) {
      raw = raw.substring(1);
    }

    // 处理 6 位 (#RRGGBB) -> 补全为 8 位 (FFRRGGBB)
    if (raw.length === 6) {
      return parseInt('FF' + raw, 16);
    }
    // 处理 8 位 (#AARRGGBB)
    else if (raw.length === 8) {
      return parseInt(raw, 16);
    }

    return Color.Black; // 格式不对时的默认色
  }

  static getTransparentColorStr(hex: string, alphaStr: string = '80'): string {
    if (!hex) return '#00000000';
    let cleanHex = hex.startsWith('#') ? hex.substring(1) : hex;
    // 如果是 6 位 (RRGGBB)，加前缀
    if (cleanHex.length === 6) {
      return `#${alphaStr}${cleanHex}`;
    }
    // 如果是 8 位 (AARRGGBB)，替换前两位
    if (cleanHex.length === 8) {
      return `#${alphaStr}${cleanHex.substring(2)}`;
    }
    return hex;
  }
}

export function getHexColorSync(context: Context, color: ResourceColor): string {
  // 1. 如果是字符串 (例如 "#FF0000" 或 "#FF5B8C5A")
  // 这是自定义主题最常见的情况
  if (typeof color === 'string') {
    return color;
  }

  // 2. 如果是数字 (例如 Color.Red 或 0xFF0000)
  if (typeof color === 'number') {
    try {
      // & 0xFFFFFF 确保只取 RGB，忽略 Alpha，保持和你原有逻辑一致
      let hex = ((color as number) & 0xFFFFFF).toString(16).toUpperCase();
      while (hex.length < 6) {
        hex = "0" + hex;
      }
      return "#" + hex;
    } catch (e) {
      return "#000000";
    }
  }

  // 3. 如果是 Resource (例如 $r('app.color.chart_green'))
  // 需要 Context 解析
  if (typeof color === 'object') {
    try {
      const colorVal = context.resourceManager.getColorSync(color as Resource);
      // getColorSync 返回的是 ARGB int
      let hex = (colorVal & 0xFFFFFF).toString(16).toUpperCase();
      while (hex.length < 6) {
        hex = "0" + hex;
      }
      return "#" + hex;
    } catch (e) {
      AppLog.error('Native', `Color conversion failed: ${e}`);
      return "#000000";
    }
  }

  return "#000000";
}
