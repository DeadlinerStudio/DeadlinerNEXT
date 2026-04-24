import { hdsMaterial, HdsTabs } from '@kit.UIDesignKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { ConfigurationConstant } from '@kit.AbilityKit';

/**
 * HdsMiniBarButton 浮动迷你栏按钮组件
 * 基于 HdsTabs 的沉浸光感浮动按钮
 */
@Component
export struct HdsMiniBarButton {
  // ==================== 尺寸参数 ====================
  @Prop barWidth: number = 50;
  @Prop barHeight: number = 50;
  @Prop contentPadding: number = 8;
  @Prop containerSize: SizeOptions | undefined = undefined;

  // ==================== 图标与内容 ====================
  @Prop iconResource: Resource | undefined = undefined;
  @Prop iconSize: number = 27;
  @Prop iconColor: ResourceColor[] = [Color.Gray];

  // ==================== 材质与样式 ====================
  @Prop maskColor: ResourceColor = Color.Transparent;
  @Prop barBottomMargin: number = 0;
  @Prop barPosition: BarPosition = BarPosition.End;
  @Prop barOverlap: boolean = true;
  @Prop activeThemeId: string = 'default';

  @StorageLink('isHdsTabsEnabled') isHdsTabsEnabled: boolean = true;
  @StorageLink('currentColorMode') currentColorMode: number = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;

  // ==================== 事件回调 ====================
  public onButtonClick: (() => void) | undefined = undefined;

  // ==================== 自定义内容槽位 ====================
  @Builder
  defaultButtonBuilder() {
    if (this.iconResource) {
      SymbolGlyph(this.iconResource)
        .fontSize(this.iconSize)
        .fontColor(this.iconColor)
    }
  }

  @BuilderParam buttonContent: () => void = this.defaultButtonBuilder;
  @StorageLink('materialLevel') materialLevel: number = 10;
  @StorageLink('materialType') materialType: number = 100;
  // ==================== 私有方法 ====================
  private getComputedContainerSize(): SizeOptions {
    if (this.containerSize !== undefined) {
      return this.containerSize;
    }
    return {
      width: this.barWidth + 30 + this.contentPadding * 2,
      height: this.barHeight + 10 + this.contentPadding * 2
    };
  }

  build() {

      Row() {
        if (this.isHdsTabsEnabled && deviceInfo.distributionOSApiVersion >= 60100) {
          Row(){
            HdsTabs() {
              TabContent()
                .tabBar(this.buttonContent())
            }
            .height(this.barHeight)
            .barWidth(this.barWidth)
            .barHeight(this.barHeight-10)
            .barOverlap(this.barOverlap)
            .barPosition(this.barPosition)
            .barFloatingStyle({
              gradientMask: {
                maskColor: this.maskColor
              },
              barBottomMargin: this.barBottomMargin+5,

              systemMaterialEffect: {
                materialType: this.materialType,
                materialLevel: this.materialLevel
              }
            })
            .onTabBarClick(() => {
              if (this.onButtonClick) {
                this.onButtonClick();
              }
            })
          }
          .alignItems(VerticalAlign.Center)

        } else {
          // 向下兼容：简单平铺按钮
          Row() {
            this.buttonContent()
          }
          .width(this.barWidth)
          .height(this.barHeight-10)
          .backgroundColor(this.currentColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT ?
            'rgba(0,0,0,0.05)' : 'rgba(255,255,255,0.1)')
          .borderRadius(30)
          .onClick(() => {
            if (this.onButtonClick) {
              this.onButtonClick();
            }
          })
        }
      }
      .size(this.getComputedContainerSize())
      .padding(this.contentPadding)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)


  }
}
