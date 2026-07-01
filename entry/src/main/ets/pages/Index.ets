import { LengthMetrics, mediaquery, promptAction, SymbolGlyphModifier, display } from '@kit.ArkUI';
import { LocalValues } from '../common/local/LocalValues';
import { MainHomePage } from './routes/main/MainHomePage';
import { OverviewPage } from './routes/overview/OverviewPage';
import { UserPage } from './routes/user/UserPage';
import { common } from '@kit.AbilityKit';
import { TabAnimModifier } from '../utils/animation/TabAnimModifier';
import { AiFlowBackground } from './common/AIFlowBackground';
import { HuaweiAccountUtils } from '../utils/account/HuaweiAccountUtils';
import { SettingsConstants as C } from '../common/local/SettingsConstants';
import { ITheme } from '../common/theme/ThemeModel';
import { TaskRepository } from '../common/repository/TaskRepository';
import { hdsMaterial, HdsNavigation, HdsTabs, HdsTabsController } from '@kit.UIDesignKit';
import { AdaptedHdsTabs } from './components/AdaptedHdsTabs';
import { deviceInfo } from '@kit.BasicServicesKit';
import { CapturePage } from './routes/capture/CapturePage';
import { LottieOnboardingSheet } from './common/LottieOnboardingSheet';
import { AISheetController } from './components/AISheetController';
import { AIPage } from './routes/ai/AIPage';
import {
  AppBreakpoint,
  APP_BREAKPOINT_DEFAULT,
  APP_BREAKPOINT_ORDER,
  APP_BREAKPOINT_STORAGE_KEY,
  AppBreakpointUtils
} from '../common/layout/AppBreakpoints';

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

  @StorageLink('isWideScreen') @Watch('syncTopAvoidExtraHeight') isWideScreen: boolean = false;
  @StorageLink(APP_BREAKPOINT_STORAGE_KEY) @Watch('syncTopAvoidExtraHeight')
  currentBreakpoint: string = APP_BREAKPOINT_DEFAULT;
  @StorageProp('statusBarHeight') @Watch('syncTopAvoidExtraHeight') statusBarHeight: number = 38;
  @StorageProp('topAvoidExtraHeight') topAvoidExtraHeight: number = 0;
  @StorageLink(C.KEY_ENABLE_TABLET_UI) tabletUi: boolean = true;
  @StorageProp(C.KEY_ENABLE_API23) enableApi23: boolean = false;
  @StorageLink('NotificationPermissionRequestInProgress') @Watch('onNotificationPermissionFlowChange')
  isNotificationPermissionRequestInProgress: boolean = false;

  getFloatingTabs(): boolean {
    return (deviceInfo.distributionOSApiVersion >= 60100) && this.enableApi23
  }

  private breakpointListeners: mediaquery.MediaQueryListener[] = [];

  private syncTopAvoidExtraHeight(): void {
    const nextTopAvoidExtraHeight = AppBreakpointUtils.isWide(this.currentBreakpoint) ? this.statusBarHeight + 8 : 0;
    if (this.topAvoidExtraHeight !== nextTopAvoidExtraHeight) {
      AppStorage.setOrCreate('topAvoidExtraHeight', nextTopAvoidExtraHeight);
    }
  }

  private applyBreakpoint(nextBreakpoint: AppBreakpoint): void {
    AppStorage.setOrCreate(APP_BREAKPOINT_STORAGE_KEY, nextBreakpoint);
    AppStorage.setOrCreate('isWideScreen', AppBreakpointUtils.isWide(nextBreakpoint));
  }

  private registerBreakpointListeners(): void {
    this.unregisterBreakpointListeners();
    const mediaQuery = this.getUIContext().getMediaQuery();

    APP_BREAKPOINT_ORDER.forEach((breakpoint: AppBreakpoint) => {
      const listener = mediaQuery.matchMediaSync(AppBreakpointUtils.mediaCondition(breakpoint));
      listener.on('change', (result: mediaquery.MediaQueryResult) => {
        if (result.matches) {
          this.applyBreakpoint(breakpoint);
        }
      });
      this.breakpointListeners.push(listener);

      if (listener.matches) {
        this.applyBreakpoint(breakpoint);
      }
    });
  }

  private unregisterBreakpointListeners(): void {
    this.breakpointListeners.forEach((listener: mediaquery.MediaQueryListener) => {
      listener.off('change');
    });
    this.breakpointListeners = [];
  }

  private context = getContext(this) as common.UIAbilityContext;
  private privacyUrl: string = 'resource://rawfile/privacy_agreement.html';

  @State isBlocking: boolean = false;
  @State isGuideSheetShow: boolean = false;
  private hasPresentedGuideSheet: boolean = false;
  private isGuideSheetPresentationPending: boolean = false;
  private shouldConsumeGuideNextLaunch: boolean = false;
  private shouldConsumeFirstLaunch: boolean = false;
  private guideOpenedForFirstLaunch: boolean = false;

  @State deviceWidth: string | number = '100%';
  @State deviceHeight: string | number = '100%';

  private logGuideState(stage: string, extra?: string): void {
    const message: string = `[GuideDebug][Index] ${stage} | dataReady=${this.isAppDataReady} ` +
      `privacyAgreed=${this.privacyAgreed} showGuideNextLaunch=${this.showGuideNextLaunch} ` +
      `isGuideSheetShow=${this.isGuideSheetShow} hasPresented=${this.hasPresentedGuideSheet} ` +
      `pending=${this.isGuideSheetPresentationPending} blocking=${this.isBlocking} ` +
      `notifRequesting=${this.isNotificationPermissionRequestInProgress} ` +
      `pathStackSize=${this.appPathStack.size()} wideScreen=${this.isWideScreen} ` +
      `breakpoint=${this.currentBreakpoint} tabletUi=${this.tabletUi}` +
      `${extra ? ` | ${extra}` : ''}`;
    console.info(message);
  }

  onNotificationPermissionFlowChange(): void {
    this.logGuideState('onNotificationPermissionFlowChange', `value=${this.isNotificationPermissionRequestInProgress}`);
    if (!this.isNotificationPermissionRequestInProgress && this.isAppDataReady) {
      void this.maybeShowGuideSheet();
    }
  }

  private initDisplayInfo() {
    try {
      const d = display.getDefaultDisplaySync();
      this.deviceWidth = d.width;
      this.deviceHeight = d.height;
    } catch (e) {

    }
  }

  onDataReady() {
    if (this.isAppDataReady) {
      this.logGuideState('onDataReady:begin');
      animateTo({ duration: 600, curve: Curve.EaseOut }, () => {
        this.isShowUI = true;
      });

      void this.maybeShowGuideSheet();
    }
  }

  aboutToAppear() {
    this.registerBreakpointListeners();
    this.syncTopAvoidExtraHeight();
    this.logGuideState('aboutToAppear');

    if (this.isAppDataReady) {
      this.onDataReady();
    }

    this.initDisplayInfo();

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
    this.logGuideState('onPageShow:enter');
    if (this.isGuideSheetShow && !this.hasPresentedGuideSheet) {
      this.logGuideState('onPageShow:resetHalfShownSheet');
      this.isGuideSheetShow = false;
    }

    if (this.isAppDataReady) {
      void this.maybeShowGuideSheet();
    }

    if (this.isLoggedIn && !this.hasCheckedProfile) {
      this.checkAndRepairUserProfile();
    }
  }

  aboutToDisappear(): void {
    this.unregisterBreakpointListeners();
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
    if (!this.isAppDataReady || this.hasPresentedGuideSheet || this.isGuideSheetShow || this.isGuideSheetPresentationPending) {
      this.logGuideState(
        'maybeShowGuideSheet:skip',
        `reason=dataReady:${this.isAppDataReady},presented:${this.hasPresentedGuideSheet},shown:${this.isGuideSheetShow},pending:${this.isGuideSheetPresentationPending}`
      );
      return;
    }

    const localValues = LocalValues.getInstance();
    
    // 强制同步本地状态，避免异步导致组件先渲染
    const isAgreed = await localValues.getIsPrivacyAgreed();
    this.privacyAgreed = isAgreed;
    
    const isFirstLaunch = await localValues.getIsAppFirstLaunch();
    const shouldShowForGuide = this.showGuideNextLaunch || isFirstLaunch;

    const shouldShowForPrivacy = !this.privacyAgreed;
    this.logGuideState(
      'maybeShowGuideSheet:evaluated',
      `isFirstLaunch=${isFirstLaunch} shouldShowForGuide=${shouldShowForGuide} shouldShowForPrivacy=${shouldShowForPrivacy}`
    );

    if (this.isNotificationPermissionRequestInProgress) {
      this.logGuideState('maybeShowGuideSheet:deferForNotificationPermission');
      return;
    }

    if (!shouldShowForPrivacy && !shouldShowForGuide) {
      this.isBlocking = false;
      this.logGuideState('maybeShowGuideSheet:noNeedToShow');
      return;
    }

    if (!this.privacyAgreed || this.appPathStack.size() > 0) {
      if (!shouldShowForPrivacy) {
        this.logGuideState('maybeShowGuideSheet:skipByPathOrPrivacy', 'reason=guideOnlyButPrivacy/pathCheckBlocked');
        return;
      }
    } else if (!shouldShowForPrivacy && this.appPathStack.size() > 0) {
      this.logGuideState('maybeShowGuideSheet:skipByPath', 'reason=pathStackNotEmpty');
      return;
    }

    if (shouldShowForPrivacy) {
        this.isBlocking = true;
    }

    this.guideOpenedForFirstLaunch = isFirstLaunch;
    this.isGuideSheetPresentationPending = true;
    this.shouldConsumeGuideNextLaunch = this.showGuideNextLaunch;
    this.shouldConsumeFirstLaunch = isFirstLaunch;
    this.logGuideState(
      'maybeShowGuideSheet:scheduleShow',
      `consumeGuideNext=${this.shouldConsumeGuideNextLaunch} consumeFirstLaunch=${this.shouldConsumeFirstLaunch}`
    );

    setTimeout(() => {
      this.isGuideSheetPresentationPending = false;
      this.logGuideState(
        'maybeShowGuideSheet:timeoutFired',
        `shouldShowForPrivacy=${shouldShowForPrivacy} shouldShowForGuide=${shouldShowForGuide}`
      );
      if ((shouldShowForPrivacy || shouldShowForGuide) && this.appPathStack.size() === 0) {
        this.isGuideSheetShow = true;
        this.logGuideState('maybeShowGuideSheet:setGuideSheetShowTrue');
      } else {
        this.logGuideState('maybeShowGuideSheet:timeoutSkipShow', `pathStackSize=${this.appPathStack.size()}`);
      }
    }, 100); // 缩短延迟，尽快弹出
  }

  private async onGuideSheetPresented(): Promise<void> {
    if (this.hasPresentedGuideSheet) {
      this.logGuideState('onGuideSheetPresented:skipAlreadyPresented');
      return;
    }

    this.logGuideState('onGuideSheetPresented:begin');
    this.guideOpenedForFirstLaunch = this.shouldConsumeFirstLaunch;
    this.hasPresentedGuideSheet = true;
    const localValues = LocalValues.getInstance();

    if (this.shouldConsumeGuideNextLaunch) {
      this.shouldConsumeGuideNextLaunch = false;
      await localValues.setShowGuideNextLaunch(false);
    }

    if (this.shouldConsumeFirstLaunch) {
      this.shouldConsumeFirstLaunch = false;
      await localValues.setAppFirstLaunch(false);
    }

    this.logGuideState('onGuideSheetPresented:done');
  }

  @Builder
  onboardingSheet() {
    LottieOnboardingSheet({
      privacyRequired: !this.privacyAgreed,
      openedForFirstLaunch: this.guideOpenedForFirstLaunch,
      onPresented: (): void => {
        void this.onGuideSheetPresented();
      },
      onAgreePrivacy: async () => {
        this.logGuideState('onboarding:onAgreePrivacy:before');
        await LocalValues.getInstance().setPrivacyAgreed();
        this.privacyAgreed = true;
        this.isBlocking = false;
        this.logGuideState('onboarding:onAgreePrivacy:after');
      },
      onDeclinePrivacy: () => {
        this.logGuideState('onboarding:onDeclinePrivacy');
        this.context.terminateSelf().catch(() => {
          console.error('Terminate failed');
        });
      },
      privacyUrl: this.privacyUrl,
      onClose: () => {
        this.logGuideState('onboarding:onClose:before');
        this.isGuideSheetShow = false;
        this.isBlocking = false;
        this.logGuideState('onboarding:onClose:after');
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
    { title: 'AI', icon: $r('app.media.lifi'), index: 3 },
    { title: '我的', icon: $r('sys.symbol.person_crop_circle_fill_1'), index: 4 },
  ]

  private getTabBarStyle(item: TabData, isImage?: boolean): BottomTabBarStyle {
    let symbol: boolean = true;
    if (isImage === true) {
      symbol = false;
    }

    let style = BottomTabBarStyle.of(
      symbol ? this.getTabBarSymbol(item.icon) : item.icon,
      item.title
    );

    style.iconStyle({
      selectedColor: this.theme.tabIcon,
      unselectedColor: $r('app.color.font_secondary')
    });

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
                .padding({ left: (this.isWideScreen && !this.getFloatingTabs()) ? TAB_VERTICAL_PADDING : 0 })
            }
            .tabBar(this.getTabBarStyle(this.tabs[0]))
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
            // .backgroundColor(this.theme.bgPrimary)

            // --- Tab 2: 概览 ---
            TabContent() {
              OverviewPage({ currentTabIndex: this.currentIndex })
                .attributeModifier(new TabAnimModifier(1, this.currentIndex))
                .animation({
                  duration: 300, // 保持与 Tabs 动画时长一致
                  curve: Curve.EaseInOut
                })
                .padding({ left: (this.isWideScreen && !this.getFloatingTabs()) ? TAB_VERTICAL_PADDING : 0 })
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

            // --- Tab 4: Lifi ---
            TabContent() {
              AIPage({ currentTabIndex: this.currentIndex })
                .attributeModifier(new TabAnimModifier(3, this.currentIndex))
                .animation({
                  duration: 300, // 保持与 Tabs 动画时长一致
                  curve: Curve.EaseInOut
                })
                .padding({ left: (this.isWideScreen && this.tabletUi && !this.getFloatingTabs()) ? TAB_VERTICAL_PADDING : 0 })
            }
            .tabBar(this.getTabBarStyle(this.tabs[3], true))
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

            // --- Tab 5: 我的 ---
            TabContent() {
              UserPage()
                .attributeModifier(new TabAnimModifier(4, this.currentIndex))
                .animation({
                  duration: 300, // 保持与 Tabs 动画时长一致
                  curve: Curve.EaseInOut
                })
                .padding({ left: (this.isWideScreen && this.tabletUi && !this.getFloatingTabs()) ? TAB_VERTICAL_PADDING : 0 })
            }
            .tabBar(this.getTabBarStyle(this.tabs[4]))
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
          .height('100%')
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
        this.logGuideState('bindSheet:onDisappear:before');
        if (!this.privacyAgreed) {
          this.isGuideSheetShow = true;
          this.isBlocking = true;
          this.logGuideState('bindSheet:onDisappear:reopenBecausePrivacyRequired');
          return;
        }
        this.isGuideSheetShow = false;
        this.logGuideState('bindSheet:onDisappear:after');
      },
      onWillDismiss: () => {
      }
    })
  }
}
