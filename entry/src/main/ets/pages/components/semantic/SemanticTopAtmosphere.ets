import { ColorMetrics } from '@kit.ArkUI';
import { SemanticTone } from '../../../common/semantic/SemanticContract';
import { ITheme } from '../../../common/theme/ThemeModel';
import { HdsTabId } from '../../../model/HdsTabsCustomization';

@Component
export struct SemanticTopAtmosphere {
  @Prop theme: ITheme;
  @Prop currentThemeKey: string = 'vibrant';
  @StorageProp('currentIndicatorKey') currentIndicatorKey: string = 'vibrant';
  @StorageLink('rootListSemanticTone') listSemanticToneKey: string = SemanticTone.ACCENT;
  @Prop currentTabId: string = HdsTabId.LIST;
  @Prop visible: boolean = true;
  @Prop scrollProgress: number = 0;

  private progress(): number {
    return Math.max(0, Math.min(1, this.scrollProgress));
  }

  private transparentVersion(color: ResourceColor): ResourceColor {
    try {
      const resolvedColor: ColorMetrics = ColorMetrics.resourceColor(color);
      return ColorMetrics.rgba(resolvedColor.red, resolvedColor.green, resolvedColor.blue, 0).color;
    } catch {
      return '#00000000';
    }
  }

  @Builder
  private colorLayer(color: ResourceColor, layerKey: string) {
    Column()
      .id(layerKey)
      .width('100%')
      .height('100%')
      .linearGradient({
        direction: GradientDirection.Bottom,
        colors: [
          [color, 0.0],
          [this.transparentVersion(color), 0.6]
        ]
      })
      .opacity(0.18)
      .transition(TransitionEffect.OPACITY.animation({ duration: 420, curve: Curve.EaseInOut }))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  private atmosphereLayer() {
    if (this.currentTabId === HdsTabId.LIST) {
      if (this.listSemanticToneKey === SemanticTone.DANGER) {
        this.colorLayer(this.theme.indicatorPassed, 'list-danger-' + this.currentIndicatorKey)
      } else if (this.listSemanticToneKey === SemanticTone.WARNING) {
        this.colorLayer(this.theme.indicatorNear, 'list-warning-' + this.currentIndicatorKey)
      } else if (this.listSemanticToneKey === SemanticTone.SUCCESS) {
        this.colorLayer(this.theme.indicatorCompleted, 'list-success-' + this.currentIndicatorKey)
      } else {
        this.colorLayer(this.theme.indicatorUndergo, 'list-accent-' + this.currentIndicatorKey)
      }
    } else if (this.currentTabId === HdsTabId.OVERVIEW) {
      this.colorLayer(this.theme.brand, 'brand-' + this.currentThemeKey + '-overview')
    } else if (this.currentTabId === HdsTabId.CAPTURE) {
      this.colorLayer(this.theme.brand, 'brand-' + this.currentThemeKey + '-capture')
    } else if (this.currentTabId === HdsTabId.AI) {
      this.colorLayer(this.theme.brand, 'brand-' + this.currentThemeKey + '-ai')
    } else {
      this.colorLayer(this.theme.brand, 'brand-' + this.currentThemeKey + '-user')
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.atmosphereLayer()
    }
    .width('100%')
    .height('100%')
    .opacity(this.visible ? 1 - this.progress() * 0.16 : 0)
    .clip(false)
    .hitTestBehavior(HitTestMode.None)
    .animation({ duration: 280, curve: Curve.EaseInOut })
    .transition(TransitionEffect.OPACITY.animation({ duration: 280, curve: Curve.EaseInOut }))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
