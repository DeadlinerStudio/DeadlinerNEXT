import { SemanticTone } from '../../../common/semantic/SemanticContract';
import { ITheme } from '../../../common/theme/ThemeModel';
import { HdsTabId } from '../../../model/HdsTabsCustomization';

@Component
export struct SemanticTopAtmosphere {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  @StorageProp('currentThemeKey') currentThemeKey: string = 'vibrant';
  @StorageProp('currentIndicatorKey') currentIndicatorKey: string = 'vibrant';
  @StorageLink('rootListSemanticTone') listSemanticToneKey: string = SemanticTone.ACCENT;
  @StorageLink('rootSemanticTabId') currentTabId: string = HdsTabId.LIST;
  @Prop visible: boolean = true;
  @Prop scrollProgress: number = 0;

  private progress(): number {
    return Math.max(0, Math.min(1, this.scrollProgress));
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
          ['#00000000', 0.6]
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
    } else if (this.currentThemeKey !== 'colorful') {
      this.colorLayer(this.theme.brand, 'brand-' + this.currentThemeKey)
    } else if (this.currentTabId === HdsTabId.OVERVIEW) {
      this.colorLayer($r('app.color.module_overview'), 'colorful-overview')
    } else if (this.currentTabId === HdsTabId.CAPTURE) {
      this.colorLayer($r('app.color.module_capture'), 'colorful-capture')
    } else if (this.currentTabId === HdsTabId.AI) {
      this.colorLayer($r('app.color.module_ai'), 'colorful-ai')
    } else {
      this.colorLayer($r('app.color.module_user'), 'colorful-user')
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
