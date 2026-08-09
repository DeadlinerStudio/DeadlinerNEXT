import {
  ImmersiveMaterialPreset,
  MaterialPresets,
  canUseSystemMaterial
} from '../style/SystemMaterialCompat';

@Component
export struct ImmersivePopupSurface {
  @BuilderParam content: () => void;

  @Prop paddingValue: number = 16;
  @Prop radius: number = 16;
  @Prop widthValue: number = 0;
  @Prop maxWidthValue: number = 0;
  @Prop alignStart: boolean = true;
  @Prop fallbackBlurStyle: BlurStyle = BlurStyle.Regular;
  @Prop materialPreset: ImmersiveMaterialPreset = ImmersiveMaterialPreset.REGULAR;
  @Prop enableLightEffect: boolean = false;

  build() {
    if (canUseSystemMaterial()) {
      if (this.widthValue > 0 && this.maxWidthValue > 0) {
        Column() {
          if (this.content) {
            this.content()
          }
        }
        .width(this.widthValue)
        .constraintSize({ maxWidth: this.maxWidthValue })
        .padding(this.paddingValue)
        .borderRadius(this.radius)
        .backgroundColor(Color.Transparent)
        .attributeModifier(this.enableLightEffect
          ? MaterialPresets.surfaceGlowPreset(this.materialPreset)
          : MaterialPresets.surfacePreset(this.materialPreset))
        .clip(true)
        .alignItems(this.alignStart ? HorizontalAlign.Start : HorizontalAlign.Center)
      } else if (this.widthValue > 0) {
        Column() {
          if (this.content) {
            this.content()
          }
        }
        .width(this.widthValue)
        .padding(this.paddingValue)
        .borderRadius(this.radius)
        .backgroundColor(Color.Transparent)
        .attributeModifier(this.enableLightEffect
          ? MaterialPresets.surfaceGlowPreset(this.materialPreset)
          : MaterialPresets.surfacePreset(this.materialPreset))
        .clip(true)
        .alignItems(this.alignStart ? HorizontalAlign.Start : HorizontalAlign.Center)
      } else if (this.maxWidthValue > 0) {
        Column() {
          if (this.content) {
            this.content()
          }
        }
        .constraintSize({ maxWidth: this.maxWidthValue })
        .padding(this.paddingValue)
        .borderRadius(this.radius)
        .backgroundColor(Color.Transparent)
        .attributeModifier(this.enableLightEffect
          ? MaterialPresets.surfaceGlowPreset(this.materialPreset)
          : MaterialPresets.surfacePreset(this.materialPreset))
        .clip(true)
        .alignItems(this.alignStart ? HorizontalAlign.Start : HorizontalAlign.Center)
      } else {
        Column() {
          if (this.content) {
            this.content()
          }
        }
        .padding(this.paddingValue)
        .borderRadius(this.radius)
        .backgroundColor(Color.Transparent)
        .attributeModifier(this.enableLightEffect
          ? MaterialPresets.surfaceGlowPreset(this.materialPreset)
          : MaterialPresets.surfacePreset(this.materialPreset))
        .clip(true)
        .alignItems(this.alignStart ? HorizontalAlign.Start : HorizontalAlign.Center)
      }
    } else {
      if (this.widthValue > 0 && this.maxWidthValue > 0) {
        Column() {
          if (this.content) {
            this.content()
          }
        }
        .width(this.widthValue)
        .constraintSize({ maxWidth: this.maxWidthValue })
        .padding(this.paddingValue)
        .borderRadius(this.radius)
        .backgroundColor(Color.Transparent)
        .backgroundBlurStyle(this.fallbackBlurStyle)
        .clip(true)
        .alignItems(this.alignStart ? HorizontalAlign.Start : HorizontalAlign.Center)
      } else if (this.widthValue > 0) {
        Column() {
          if (this.content) {
            this.content()
          }
        }
        .width(this.widthValue)
        .padding(this.paddingValue)
        .borderRadius(this.radius)
        .backgroundColor(Color.Transparent)
        .backgroundBlurStyle(this.fallbackBlurStyle)
        .clip(true)
        .alignItems(this.alignStart ? HorizontalAlign.Start : HorizontalAlign.Center)
      } else if (this.maxWidthValue > 0) {
        Column() {
          if (this.content) {
            this.content()
          }
        }
        .constraintSize({ maxWidth: this.maxWidthValue })
        .padding(this.paddingValue)
        .borderRadius(this.radius)
        .backgroundColor(Color.Transparent)
        .backgroundBlurStyle(this.fallbackBlurStyle)
        .clip(true)
        .alignItems(this.alignStart ? HorizontalAlign.Start : HorizontalAlign.Center)
      } else {
        Column() {
          if (this.content) {
            this.content()
          }
        }
        .padding(this.paddingValue)
        .borderRadius(this.radius)
        .backgroundColor(Color.Transparent)
        .backgroundBlurStyle(this.fallbackBlurStyle)
        .clip(true)
        .alignItems(this.alignStart ? HorizontalAlign.Start : HorizontalAlign.Center)
      }
    }
  }
}
