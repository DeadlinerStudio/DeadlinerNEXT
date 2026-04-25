import { DividerMode, hdsMaterial, HdsTabs, HdsTabsController } from '@kit.UIDesignKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { ITheme } from '../../common/theme/ThemeModel';
import { LocalValues } from '../../common/local/LocalValues';
import { getHdsMaterialLevel } from '../../common/style/MaterialLevel';
import { ThemeManager } from '../../common/theme/ThemeManager';

@Component
export struct AdaptedHdsTabs {
  // 核心数据的双向绑定
  @Link currentIndex: number;

  // 布局控制参数
  @Prop isWideScreen: boolean;
  @Prop tabletUi: boolean;
  @Prop theme: ITheme;

  // 控制器
  controller: HdsTabsController = new HdsTabsController();

  // 接收外部传入的 TabContent 内容
  @BuilderParam content: () => void;

  // 点击事件回调（把业务逻辑抛给父组件）
  onTabClick?: (index: number) => void;

  build() {
    if (deviceInfo.distributionOSApiVersion >= 60100 && LocalValues.getInstance().getApi23Enable()) {

      HdsTabs({
        barPosition: BarPosition.End,
        index: this.currentIndex,
        controller: this.controller
      }) {
        this.content()
      }
        .barMode(BarMode.Fixed)
        .barOverlap(true)
        // .background(this.theme.bgPrimary)
        .animationDuration(300)
        .scrollable(false)
        .height('100%')
        .width('100%')
        .onChange((index: number) => {
          this.currentIndex = index;
        })
        .onTabBarClick((index: number) => {
          if (this.onTabClick) {
            this.onTabClick(index);
          }
        })
        .clip(false)
        .barFloatingStyle({
          barSideMargin: 24,
          barBottomMargin: this.isWideScreen ? 24 : 0,
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.IMMERSIVE,
            materialLevel: getHdsMaterialLevel()
          },
          gradientMask: {
            maskColor: $r('app.color.background_primary_50'),
            maskHeight: 42
          },
          lightColor: this.theme.useWhiteGlow ? Color.White : this.theme.brand50,
          adaptToHandedness: this.isWideScreen
        })
    } else {
      if (this.isWideScreen && this.tabletUi) {
        HdsTabs({
          barPosition: BarPosition.Start,
          index: this.currentIndex,
          controller: this.controller
        }) {
          this.content()
        }
        .vertical(true)
        .barMode(BarMode.Fixed)
        .barOverlap(true)
        // .background(this.theme.bgPrimary)
        .animationDuration(300)
        .scrollable(false)
        .height('100%')
        .width('100%')
        .onChange((index: number) => {
          this.currentIndex = index;
        })
        .onTabBarClick((index: number) => {
          if (this.onTabClick) {
            this.onTabClick(index);
          }
        })
        .clip(false)
        .divider({ mode: DividerMode.NONE })
        .barBackgroundEffect({
          radius: 0,
          color: this.theme.bgPrimary
        })
      } else {
        HdsTabs({
          barPosition: BarPosition.End,
          index: this.currentIndex,
          controller: this.controller
        }) {
          this.content()
        }
        .vertical(false)
        .barMode(BarMode.Fixed)
        .barOverlap(true)
        // .background(this.theme.bgPrimary)
        .animationDuration(300)
        .scrollable(false)
        .height('100%')
        .width('100%')
        .onChange((index: number) => {
          this.currentIndex = index;
        })
        .onTabBarClick((index: number) => {
          if (this.onTabClick) {
            this.onTabClick(index);
          }
        })
        .clip(false)
        .divider({ mode: DividerMode.NONE })
      }
    }
  }
}
