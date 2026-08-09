import { uiMaterial } from '@kit.ArkUI';
import { Available, deviceInfo } from '@kit.BasicServicesKit';

export enum ImmersiveMaterialPreset {
  REGULAR = 0,
  THICK = 1,
  ULTRA_THICK = 2
}

export const DefaultSheetMaterial: ImmersiveMaterialPreset = ImmersiveMaterialPreset.ULTRA_THICK;
export const DefaultCustomDialogMaterial: ImmersiveMaterialPreset = ImmersiveMaterialPreset.THICK;
export const DefaultBackgroundImmersiveMaterial: ImmersiveMaterialPreset = DefaultSheetMaterial;
export const DefaultFloatingToolbarMaterial: ImmersiveMaterialPreset = ImmersiveMaterialPreset.REGULAR;

export interface ImmersiveMaterialOptions {
  style?: uiMaterial.ImmersiveStyle;
  preset?: ImmersiveMaterialPreset;
  interactive?: boolean;
  lightEffect?: boolean;
  materialColor?: ResourceColor;
}

export function canUseSystemMaterial(): boolean {
  return deviceInfo.apiAvailable('26.0.0');
}

@Available({ minApiVersion: '26.0.0' })
function resolveImmersiveStyle(preset: ImmersiveMaterialPreset): uiMaterial.ImmersiveStyle {
  if (preset === ImmersiveMaterialPreset.REGULAR) {
    return uiMaterial.ImmersiveStyle.REGULAR;
  }
  if (preset === ImmersiveMaterialPreset.THICK) {
    return uiMaterial.ImmersiveStyle.THICK;
  }
  return uiMaterial.ImmersiveStyle.ULTRA_THICK;
}

@Available({ minApiVersion: '26.0.0' })
export function buildImmersiveMaterial(options?: ImmersiveMaterialOptions): uiMaterial.Material {
  let style: uiMaterial.ImmersiveStyle | undefined = options?.style;
  if (options !== undefined && options.preset !== undefined) {
    style = resolveImmersiveStyle(options.preset);
  }
  return new uiMaterial.ImmersiveMaterial({
    style: style,
    interactive: options?.interactive,
    lightEffect: options?.lightEffect ? { color: undefined } : undefined,
    materialColor: options?.materialColor
  });
}

export class ImmersiveMaterialModifier implements AttributeModifier<CommonAttribute> {
  private options?: ImmersiveMaterialOptions;
  private enabled: boolean;

  constructor(options?: ImmersiveMaterialOptions, enabled: boolean = true) {
    this.options = options;
    this.enabled = enabled;
  }

  applyNormalAttribute(instance: CommonAttribute): void {
    if (!this.enabled || !canUseSystemMaterial()) {
      return;
    }

    instance.systemMaterial(buildImmersiveMaterial(this.options));
  }
}

export class BackgroundImmersiveMaterialModifier implements AttributeModifier<CommonAttribute> {
  private fallbackBlurStyle: BlurStyle;
  private preset: ImmersiveMaterialPreset;

  constructor(
    fallbackBlurStyle: BlurStyle = BlurStyle.Regular,
    preset: ImmersiveMaterialPreset = DefaultBackgroundImmersiveMaterial
  ) {
    this.fallbackBlurStyle = fallbackBlurStyle;
    this.preset = preset;
  }

  applyNormalAttribute(instance: CommonAttribute): void {
    instance.backgroundColor(Color.Transparent);
    if (canUseSystemMaterial()) {
      instance.systemMaterial(buildImmersiveMaterial({ preset: this.preset }));
      return;
    }
    instance.backgroundBlurStyle(this.fallbackBlurStyle);
  }
}

export class MaterialPresets {
  static surface(
    enabled: boolean = true,
    style?: uiMaterial.ImmersiveStyle,
    color?: ResourceColor
  ): ImmersiveMaterialModifier {
    return new ImmersiveMaterialModifier({ style: style, materialColor: color }, enabled);
  }

  static surfacePreset(
    preset: ImmersiveMaterialPreset,
    enabled: boolean = true,
    color?: ResourceColor
  ): ImmersiveMaterialModifier {
    return new ImmersiveMaterialModifier({ preset: preset, materialColor: color }, enabled);
  }

  static surfaceGlowPreset(
    preset: ImmersiveMaterialPreset,
    enabled: boolean = true,
    color?: ResourceColor
  ): ImmersiveMaterialModifier {
    return new ImmersiveMaterialModifier({
      preset: preset,
      interactive: true,
      lightEffect: true,
      materialColor: color
    }, enabled);
  }

  static backgroundImmersive(
    fallbackBlurStyle: BlurStyle = BlurStyle.Regular,
    preset: ImmersiveMaterialPreset = DefaultBackgroundImmersiveMaterial
  ): BackgroundImmersiveMaterialModifier {
    return new BackgroundImmersiveMaterialModifier(fallbackBlurStyle, preset);
  }

  static surfaceInteractive(
    enabled: boolean = true,
    style?: uiMaterial.ImmersiveStyle,
    color?: ResourceColor
  ): ImmersiveMaterialModifier {
    return new ImmersiveMaterialModifier({
      style: style,
      interactive: true,
      materialColor: color
    }, enabled);
  }

  static surfaceGlow(
    enabled: boolean = true,
    style?: uiMaterial.ImmersiveStyle,
    color?: ResourceColor
  ): ImmersiveMaterialModifier {
    return new ImmersiveMaterialModifier({
      style: style,
      interactive: true,
      lightEffect: true,
      materialColor: color
    }, enabled);
  }

  static buttonInteractive(
    enabled: boolean = true,
    style?: uiMaterial.ImmersiveStyle,
    color?: ResourceColor
  ): ImmersiveMaterialModifier {
    return new ImmersiveMaterialModifier({
      style: style,
      interactive: true,
      materialColor: color
    }, enabled);
  }

  static buttonGlow(
    enabled: boolean = true,
    style?: uiMaterial.ImmersiveStyle,
    color?: ResourceColor
  ): ImmersiveMaterialModifier {
    return new ImmersiveMaterialModifier({
      style: style,
      interactive: true,
      lightEffect: true,
      materialColor: color
    }, enabled);
  }
}
