import { LengthMetrics, mediaquery, promptAction, SymbolGlyphModifier } from '@kit.ArkUI';
import { LocalValues } from '../common/local/LocalValues';
import { MainHomePage } from './routes/main/MainHomePage';
import { OverviewPage } from './routes/overview/OverviewPage';
import { UserPage } from './routes/user/UserPage';
import { common } from '@kit.AbilityKit';
import { TabAnimModifier } from '../utils/animation/TabAnimModifier';
import { AiFlowBackground } from './common/AIFlowBackground';
import { HuaweiAccountUtils } from '../utils/account/HuaweiAccountUtils';
import { MainHomePageTablet } from './routes/main/MainHomePageTablet';
import { OverviewPageTablet } from './routes/overview/OverviewPageTablet';
import { SettingsConstants as C } from '../common/local/SettingsConstants';
import { ITheme } from '../common/theme/ThemeModel';
import { TaskRepository } from '../common/repository/TaskRepository';
import { hdsMaterial, HdsNavigation, HdsTabs, HdsTabsController } from '@kit.UIDesignKit';
import { AdaptedHdsTabs } from './components/AdaptedHdsTabs';
import { deviceInfo } from '@kit.BasicServicesKit';
import { CapturePage } from './routes/capture/CapturePage';
import { LottieOnboardingSheet } from './common/LottieOnboardingSheet';
import { AISheetController } from './components/AISheetController';

interface TabData {
  title: string,
  icon: Resource,
  index: number
}

const TAB_VERTICAL_PADDING = 86;

@Entry
@Component
struct Index {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  @StorageProp('customBackgroundImage') customBg: string = '';
  @StorageProp('customBackgroundBlur') isBgBlurred: boolean = false;

  // 全局路由栈
  @Provide('appPathStack') appPathStack: NavPathStack = new NavPathStack();
  @Provide('isAiFlowShown') isAiFlowShown: boolean = false;

  @StorageProp('IsAppDataReady') @Watch('onDataReady') isAppDataReady: boolean = false;
  @StorageProp(C.KEY_PRIVACY_AGREE) privacyAgreed: boolean = false;
  @StorageLink(C.KEY_SHOW_GUIDE_NEXT_LAUNCH) showGuideNextLaunch: boolean = false;
  @State isShowUI: boolean = false;

  @StorageLink('isLoggedIn') @Watch('onLoginStatusChange') isLoggedIn: boolean = false;
  @State hasCheckedProfile: boolean = false;

  @StorageLink('QuickAddTaskTrigger') @Watch('onQuickAddTrigger') quickAddTrigger: boolean = false;

  onQuickAddTrigger() {
    if (this.quickAddTrigger === true) {
      this.currentIndex = 0;
    }
  }

  @StorageLink('isWideScreen') isWideScreen: boolean = false;
  @StorageLink(C.KEY_ENABLE_TABLET_UI) tabletUi: boolean = true;
  @StorageProp(C.KEY_ENABLE_API23) enableApi23: boolean = false;

  getFloatingTabs(): boolean {
    return (deviceInfo.distributionOSApiVersion >= 60100) && this.enableApi23
  }

  listener = mediaquery.matchMediaSync('(min-width: 840vp)');

  onPortrait(mediaQueryResult: mediaquery.MediaQueryResult) {
    AppStorage.setOrCreate('isWideScreen', mediaQueryResult.matches);
  }

  private context = getContext(this) as common.UIAbilityContext;
  private privacyUrl: string = 'resource://rawfile/privacy_agreement.html';

  @State isBlocking: boolean = false;
  @State isGuideSheetShow: boolean = false;
  private hasPresentedGuideSheet: boolean = false;

  onDataReady() {
    if (this.isAppDataReady) {
      animateTo({ duration: 600, curve: Curve.EaseOut }, () => {
        this.isShowUI = true;
      });

      void this.maybeShowGuideSheet();
    }
  }

  aboutToAppear() {
    AppStorage.setOrCreate('isWideScreen', this.listener.matches);
    this.listener.on('change', (result) => this.onPortrait(result));

    if (this.isAppDataReady) {
      this.onDataReady();
    }

    if (this.isLoggedIn) {
      this.checkAndRepairUserProfile();
    }

    TaskRepository.getInstance().checkAndAutoArchive().catch((e: Error) => {
      console.error(`[Index] checkAndAutoArchive failed: ${e.message}`);
    });

    if (this.isAppDataReady) {
      void this.maybeShowGuideSheet();
    }
  }

  onPageShow() {
    if (this.isLoggedIn && !this.hasCheckedProfile) {
      this.checkAndRepairUserProfile();
    }
  }

  onLoginStatusChange() {
    if (this.isLoggedIn) {
      this.checkAndRepairUserProfile();
    }
  }

  /**
   * 核心修复逻辑：
   * 检测是否属于“已登录但未授权”的用户，如果是，则强制弹窗。
   */
  async checkAndRepairUserProfile() {
    if (this.hasCheckedProfile) return;
    this.hasCheckedProfile = true;

    const ctx = this.getUIContext().getHostContext();
    if (!ctx) return;

    try {
      const sysProfile = await HuaweiAccountUtils.getHuaweiAccountProfile(ctx, false);

      if (!sysProfile.nickname || sysProfile.nickname.trim() === '') {
        console.info('[Fix] Detect logged-in user with missing profile. Triggering Force Auth...');

        const fixedProfile = await HuaweiAccountUtils.getHuaweiAccountProfile(ctx, true);

        if (fixedProfile.nickname) {
          console.info('[Fix] User repaired successfully.');
          promptAction.showToast({ message: '用户信息已同步' });
        }
      } else {
        console.info('[Fix] User profile is healthy.');
      }
    } catch (e) {
      console.error('[Fix] Profile check failed:', e);
    }
  }

  private async maybeShowGuideSheet(): Promise<void> {
    if (!this.isAppDataReady || this.hasPresentedGuideSheet || this.isGuideSheetShow) {
      return;
    }

    const localValues = LocalValues.getInstance();
    
    // 强制同步本地状态，避免异步导致组件先渲染
    const isAgreed = await localValues.getIsPrivacyAgreed();
    this.privacyAgreed = isAgreed;
    
    const isFirstLaunch = await localValues.getIsAppFirstLaunch();
    const shouldShowForGuide = this.showGuideNextLaunch || isFirstLaunch;

    const shouldShowForPrivacy = !this.privacyAgreed;

    if (!shouldShowForPrivacy && !shouldShowForGuide) {
      this.isBlocking = false;
      return;
    }

    if (!this.privacyAgreed || this.appPathStack.size() > 0) {
      if (!shouldShowForPrivacy) {
        return;
      }
    } else if (!shouldShowForPrivacy && this.appPathStack.size() > 0) {
      return;
    }

    this.hasPresentedGuideSheet = true;
    
    if (this.showGuideNextLaunch) {
      await localValues.setShowGuideNextLaunch(false);
    }
    
    if (isFirstLaunch) {
      await localValues.setAppFirstLaunch(false);
    }
    
    if (shouldShowForPrivacy) {
        this.isBlocking = true;
    }

    setTimeout(() => {
      if ((shouldShowForPrivacy || shouldShowForGuide) && this.appPathStack.size() === 0) {
        this.isGuideSheetShow = true;
      }
    }, 100); // 缩短延迟，尽快弹出
  }

  @Builder
  onboardingSheet() {
    LottieOnboardingSheet({
      privacyRequired: !this.privacyAgreed,
      onAgreePrivacy: async () => {
        await LocalValues.getInstance().setPrivacyAgreed();
        this.privacyAgreed = true;
        this.isBlocking = false;
      },
      onDeclinePrivacy: () => {
        this.context.terminateSelf().catch(() => {
          console.error('Terminate failed');
        });
      },
      privacyUrl: this.privacyUrl,
      onClose: () => {
        this.isGuideSheetShow = false;
        this.isBlocking = false;
      }
    })
  }

  onBackPress() {
    if (this.isBlocking) {
      return true; // 返回 true 表示“我已处理该事件”，系统不会执行默认的退出操作
    }
    return false;
  }

  @State currentIndex: number = 0;
  private tabsController: HdsTabsController = new HdsTabsController();

  // 用于控制三个 Tab 的动画触发状态 (0: 初始, 每次点击增加以触发动画)
  @State tabAnimationTriggers: number[] = [0, 0, 0, 0];

  // 定义 Tab 数据
  private tabs: Array<TabData> = [
    { title: '清单', icon: $r('sys.symbol.checkmark_circle_on_circle_fill'), index: 0 },
    { title: '概览', icon: $r('sys.symbol.data_proportion_fill'), index: 1 },
    { title: '灵感', icon: $r('sys.symbol.pencil_crcle_fill'), index: 2 },
    { title: '我的', icon: $r('sys.symbol.person_crop_circle_fill_1'), index: 3 },
  ]

  private getTabBarStyle(item: TabData): BottomTabBarStyle {
    let style = BottomTabBarStyle.of(
      this.getTabBarSymbol(item.icon),
      item.title
    );

    style.labelStyle({
      selectedColor: this.theme.tabIcon,
      unselectedColor: $r('app.color.font_secondary')
    })

    return style;
  }

  private getTabBarSymbol(icon: Resource): TabBarSymbol {
    return {
      normal: new SymbolGlyphModifier(icon)
        .fontSize(24)
        .fontColor([$r('app.color.font_secondary')])
        .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY),

      selected: new SymbolGlyphModifier(icon)
        .fontSize(24)
        .fontColor([this.theme.tabIcon])
        .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY)
        .symbolEffect(
          new BounceSymbolEffect(EffectScope.WHOLE, EffectDirection.DOWN)
        )
    };
  }

  @State aiSheetController: AISheetController = new AISheetController();

  build() {
    Stack() {
      if (this.customBg) {
        Image(this.customBg)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .syncLoad(true)
          .interpolation(ImageInterpolation.High)
          .animation({ duration: 300, curve: Curve.EaseInOut })
          .blur(this.isBgBlurred ? 12 : 0)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

        Row()
          .width('100%')
          .height('100%')
          .backgroundColor(this.theme.bgPrimary)
          .opacity(0.15)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          .hitTestBehavior(HitTestMode.None)
      }

      if (this.isShowUI) {
        HdsNavigation(this.appPathStack) {
          AdaptedHdsTabs({
            currentIndex: $currentIndex,
            isWideScreen: this.isWideScreen,
            tabletUi: this.tabletUi,
            theme: this.theme,
            controller: this.tabsController,
            onTabClick: (index: number) => {
              this.tabAnimationTriggers[index] += 1;
              if (index === this.currentIndex) {
                console.debug(`[MainPage] 重复点击了第 ${index} 页，触发回到顶部`);
                AppStorage.setOrCreate(`Event_ScrollToTop_${index}`, Date.now());
              }
            },
            onMiniBarClick: () => {
              this.aiSheetController.showAI();
            }
          }) {
            // --- Tab 1: 主页 ---
            TabContent() {
              if (!(this.isWideScreen && this.tabletUi)) {
                MainHomePage({
                  currentTabIndex: this.currentIndex,
                  aiSheetController: this.aiSheetController
                })
                  .width("100%")
                  .height("100%")
                  .attributeModifier(new TabAnimModifier(0, this.currentIndex))
                  .animation({
                    duration: 300, // 保持与 Tabs 动画时长一致
                    curve: Curve.EaseInOut
                  })
              } else {
                MainHomePageTablet({
                  aiSheetController: this.aiSheetController
                })
                  .width("100%")
                  .height("100%")
                  .attributeModifier(new TabAnimModifier(0, this.currentIndex))
                  .animation({
                    duration: 300, // 保持与 Tabs 动画时长一致
                    curve: Curve.EaseInOut
                  })
                  .padding({ left: (this.isWideScreen && !this.getFloatingTabs()) ? TAB_VERTICAL_PADDING : 0 })
              }
            }
            .tabBar(this.getTabBarStyle(this.tabs[0]))
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
            // .backgroundColor(this.theme.bgPrimary)

            // --- Tab 2: 概览 ---
            TabContent() {
              if (!(this.isWideScreen && this.tabletUi)) {
                OverviewPage({ currentTabIndex: this.currentIndex })
                  .attributeModifier(new TabAnimModifier(1, this.currentIndex))
                  .animation({
                    duration: 300, // 保持与 Tabs 动画时长一致
                    curve: Curve.EaseInOut
                  })
              } else {
                OverviewPageTablet()
                  .attributeModifier(new TabAnimModifier(1, this.currentIndex))
                  .animation({
                    duration: 300, // 保持与 Tabs 动画时长一致
                    curve: Curve.EaseInOut
                  })
                  .padding({ left: (this.isWideScreen && !this.getFloatingTabs()) ? TAB_VERTICAL_PADDING : 0 })
              }
            }
            .tabBar(this.getTabBarStyle(this.tabs[1]))
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
            // .backgroundColor(this.theme.bgPrimary)

            // --- Tab 3: 灵感 ---
            TabContent() {
              CapturePage({ currentTabIndex: this.currentIndex })
                .attributeModifier(new TabAnimModifier(2, this.currentIndex))
                .animation({
                  duration: 300,
                  curve: Curve.EaseInOut
                })
                .padding({ left: (this.isWideScreen && this.tabletUi && !this.getFloatingTabs()) ? TAB_VERTICAL_PADDING : 0 })
            }
            .tabBar(this.getTabBarStyle(this.tabs[2]))
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

            // --- Tab 4: 我的 ---
            TabContent() {
              UserPage()
                .attributeModifier(new TabAnimModifier(3, this.currentIndex))
                .animation({
                  duration: 300, // 保持与 Tabs 动画时长一致
                  curve: Curve.EaseInOut
                })
                .padding({ left: (this.isWideScreen && this.tabletUi && !this.getFloatingTabs()) ? TAB_VERTICAL_PADDING : 0 })
            }
            .tabBar(this.getTabBarStyle(this.tabs[3]))
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
            // .backgroundColor(this.theme.bgPrimary)
          }
        }
        .mode(NavigationMode.Stack)
        .titleBar({
          avoidLayoutSafeArea: false,
          enableComponentSafeArea: false
        })
        .hideTitleBar(true)
      }

      if (this.isAiFlowShown) {
        AiFlowBackground()
          .height('110%')
          .width('100%')
          .hitTestBehavior(HitTestMode.None)
          .zIndex(999)
          .transition(TransitionEffect.OPACITY.animation({ duration: 500 }))
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      }
    }
    .height('100%')
    .width('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .backgroundColor(this.theme.bgPrimary)
    .bindSheet($$this.isGuideSheetShow, this.onboardingSheet(), {
      height: SheetSize.LARGE,
      dragBar: false,
      showClose: false,
      enableOutsideInteractive: false,
      shouldDismiss: (_sheetDismiss: SheetDismiss) => {
      },
      blurStyle: BlurStyle.Regular,
      backgroundColor: Color.Transparent,
      onDisappear: () => {
        if (!this.privacyAgreed) {
          this.isGuideSheetShow = true;
          this.isBlocking = true;
          return;
        }
        this.isGuideSheetShow = false;
      },
      onWillDismiss: () => {
      }
    })
  }
}
