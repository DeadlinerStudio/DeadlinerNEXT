import { DividerMode, HdsBarStyle, HdsTabsFloatingStyle, hdsMaterial, HdsTabs,
  HdsTabsBarChangeMode,
  HdsTabsController } from '@kit.UIDesignKit';
import { FocusTimerMiniBar } from '../routes/focus/FocusTimerMiniBar';
import { FocusMiniBarPolicy } from '../routes/focus/FocusUiState';
import { Available, deviceInfo } from '@kit.BasicServicesKit';
import { ITheme } from '../../common/theme/ThemeModel';
import { LocalValues } from '../../common/local/LocalValues';
import { getHdsMaterialLevel } from '../../common/style/MaterialLevel';
import { ThemeManager } from '../../common/theme/ThemeManager';
import { Symbol } from './infra/Symbol';
import { SettingsConstants as C } from '../../common/local/SettingsConstants'

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
  onTabChange?: (index: number) => void;

  onMiniBarClick?: () => void;

  @StorageLink('FocusTimerActive') @Watch('onFocusAvailabilityChanged') hasFocus: boolean = false;
  @StorageLink('FocusMiniBarExpanded') private miniBarExpanded: boolean = false;
  private onFocusAvailabilityChanged(): void { if (!this.hasFocus) this.miniBarExpanded = false; }
  @Available({ minApiVersion: '23' })
  @Builder private focusMiniBar() {
    FocusTimerMiniBar({ compact: true,
      onExpand: (): void => { this.expandFocusMiniBar(); },
      onOpen: (): void => { AppStorage.setOrCreate('FocusTimerOpen', true); } })
  }
  @Available({ minApiVersion: '23' })
  private expandFocusMiniBar(): void {
    if (!this.hasFocus || deviceInfo.distributionOSApiVersion < 60100) return;
    this.miniBarExpanded = true;
    this.controller.applyMiniBarStyle(HdsBarStyle.EXPAND);
  }
  @Available({ minApiVersion: '23' })
  private floatingStyle(): HdsTabsFloatingStyle {
    const style: HdsTabsFloatingStyle = {
      barSideMargin: 24,
      barBottomMargin: this.isWideScreen ? 24 : 0,
      systemMaterialEffect: { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: getHdsMaterialLevel() },
      gradientMask: { maskColor: $r('app.color.background_primary_50'), maskHeight: 42 },
      lightColor: this.theme.useWhiteGlow ? Color.White : this.theme.brand50,
      adaptToHandedness: this.isWideScreen
    };
    if (this.hasFocus) {
      // Default horizontal layout works from API23; do not reset to EXPAND on Tab recomposition.
      style.miniBar = { miniBarBuilder: (): void => { this.focusMiniBar(); },
        miniBarStyle: this.miniBarExpanded ? HdsBarStyle.EXPAND : HdsBarStyle.COLLAPSE,
        onBarStyleChange: (mini: HdsBarStyle, _tab: HdsBarStyle, _miniWidth: number,
          _tabWidth: number, mode: HdsTabsBarChangeMode): void => {
          this.miniBarExpanded = FocusMiniBarPolicy.nextExpanded(this.miniBarExpanded,
            mini === HdsBarStyle.EXPAND, mode === HdsTabsBarChangeMode.USER_CLICK);
        } };
    }
    return style;
  }

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
        .backgroundColor(Color.Transparent)
        .onChange((index: number) => {
          this.currentIndex = index;
          if (this.onTabChange) {
            this.onTabChange(index);
          }
        })
        .onTabBarClick((index: number) => {
          if (this.onTabClick) {
            this.onTabClick(index);
          }
        })
        .clip(false)
        .vertical(false)
        .barPosition(BarPosition.End)
        .barFloatingStyle(this.floatingStyle())
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
        .backgroundColor(Color.Transparent)
        .onChange((index: number) => {
          this.currentIndex = index;
          if (this.onTabChange) {
            this.onTabChange(index);
          }
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
        .backgroundColor(Color.Transparent)
        .onChange((index: number) => {
          this.currentIndex = index;
          if (this.onTabChange) {
            this.onTabChange(index);
          }
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
