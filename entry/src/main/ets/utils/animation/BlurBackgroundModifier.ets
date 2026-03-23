/**
 * 动态背景/模糊修改器
 * 逻辑：如果存在自定义背景，则将当前组件背景设为透明并加上毛玻璃；否则使用传入的主题纯色。
 */
export class BlurBackgroundModifier implements AttributeModifier<CommonAttribute> {
  private hasCustomBg: boolean;
  private fallbackColor: ResourceColor;
  private blurStyle: BlurStyle;

  constructor(hasCustomBg: boolean, fallbackColor: ResourceColor, blurStyle: BlurStyle = BlurStyle.Thin) {
    this.hasCustomBg = hasCustomBg;
    this.fallbackColor = fallbackColor;
    this.blurStyle = blurStyle;
  }

  // 实现正常状态下的属性修改
  applyNormalAttribute(instance: CommonAttribute): void {
    if (this.hasCustomBg) {
      // 有自定义背景：背景设为透明以透出底图，并开启毛玻璃
      instance.backgroundColor(Color.Transparent);
      instance.backgroundBlurStyle(this.blurStyle, { colorMode: ThemeColorMode.SYSTEM });
    } else {
      // 无自定义背景：使用传入的主题色，并关闭模糊
      instance.backgroundColor(this.fallbackColor);
      instance.backgroundBlurStyle(BlurStyle.NONE);
    }
  }
}