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
import {
  DividerShowType,
  hdsMaterial,
  HdsNavigation,
  HdsNavigationTitleMode,
  HdsTabs,
  HdsTabsController
} from '@kit.UIDesignKit';
import { AdaptedHdsTabs } from './components/AdaptedHdsTabs';
import { CategoryFilterSideBar } from './components/CategoryFilterSideBar';
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
import { Toast } from '../common/ui/Toast';
import { API23_UI_DEFAULT } from '../common/local/ExperimentalComponentsPolicy';
import { getImmersiveTitleBarStyle } from '../common/style/NavStyles';
import { HdsTabDescriptor, HdsTabId, HdsTabsCustomization } from '../model/HdsTabsCustomization';
import { CategoryFilter } from '../common/category/CategoryFilter';
import { SheetCompat } from '../common/ui/SheetCompat';

const TAB_VERTICAL_PADDING = 86;

@Entry
@Component
struct Index {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  @StorageProp('currentThemeKey') currentThemeKey: string = 'vibrant';
  @StorageProp('customBackgroundImage') customBg: string = '';
  @StorageProp('customBackgroundBlur') isBgBlurred: boolean = false;

  // 全局路由栈
  @Provide('appPathStack') appPathStack: NavPathStack = new NavPathStack();
  @Provide('isAiFlowShown') isAiFlowShown: boolean = false;
  @Provide('searchRouteOpacity') searchRouteOpacity: number = 1;
  @Provide('isEnteringSearchRoute') isEnteringSearchRoute: boolean = true;

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
  @StorageProp(C.KEY_ENABLE_API23) enableApi23: boolean = API23_UI_DEFAULT;
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

  private searchRouteFadeTransition(from: NavContentInfo, to: NavContentInfo): NavigationAnimatedTransition | undefined {
    if (from.name !== 'search' && to.name !== 'search') {
      return undefined;
    }

    const enteringSearch: boolean = to.name === 'search';
    const transitionTimeout: number = enteringSearch ? 600 : 350;
    const transitionDuration: number = enteringSearch ? 500 : 300;
    return {
      timeout: transitionTimeout,
      transition: (transitionProxy: NavigationTransitionProxy): void => {
        this.isEnteringSearchRoute = enteringSearch;
        this.searchRouteOpacity = enteringSearch ? 0 : 1;
        this.getUIContext().animateTo({
          duration: transitionDuration,
          curve: Curve.EaseInOut,
          onFinish: () => {
            transitionProxy.finishTransition();
          }
        }, () => {
          this.searchRouteOpacity = enteringSearch ? 1 : 0;
        });
      },
      onTransitionEnd: (_success: boolean): void => {
        if (!enteringSearch) {
          this.searchRouteOpacity = 1;
        }
      }
    };
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
          Toast.show({ message: '用户信息已同步' });
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
  @State categoryFilter: CategoryFilter = CategoryFilter.all();
  @State isCategorySideBarShown: boolean = false;
  @StorageLink(C.KEY_HDS_TABS_ORDER) @Watch('repairCurrentTabIndex')
  tabOrder: string[] = HdsTabsCustomization.defaultOrder();
  @StorageLink(C.KEY_HDS_TABS_HIDDEN) @Watch('repairCurrentTabIndex')
  hiddenTabs: string[] = HdsTabsCustomization.defaultHiddenTabs();
  @StorageLink(C.KEY_HDS_TAB_SYMBOL_RENDERING)
  tabSymbolRendering: string = HdsTabsCustomization.defaultSymbolRendering();
  private tabsController: HdsTabsController = new HdsTabsController();

  private getVisibleTabs(): HdsTabDescriptor[] {
    return HdsTabsCustomization.getVisibleTabs(this.tabOrder, this.hiddenTabs);
  }

  private getVisibleTabIndex(tabId: string): number {
    const visibleTabs = this.getVisibleTabs();
    for (let index = 0; index < visibleTabs.length; index += 1) {
      if (visibleTabs[index].id === tabId) {
        return index;
      }
    }
    return 0;
  }

  private repairCurrentTabIndex(): void {
    if (this.currentIndex >= this.getVisibleTabs().length || this.currentIndex < 0) {
      this.currentIndex = 0;
    }
  }

  private getTabBarStyle(item: HdsTabDescriptor): BottomTabBarStyle {
    const symbol: boolean = !item.isImage;
    const displayIcon: Resource = HdsTabsCustomization.getDisplayIcon(item.id, this.tabSymbolRendering);
    const selectedColor: ResourceColor = this.currentThemeKey === 'colorful' ? item.color : this.theme.tabIcon;

    let style = BottomTabBarStyle.of(
      symbol ? this.getTabBarSymbol(displayIcon, selectedColor) : displayIcon,
      item.title
    );

    style.iconStyle({
      selectedColor: selectedColor,
      unselectedColor: $r('app.color.tab_bar_icon_unselected')
    });

    style.labelStyle({
      selectedColor: selectedColor,
      unselectedColor: $r('app.color.tab_bar_icon_unselected')
    })

    return style;
  }

  private getTabBarSymbol(icon: Resource, selectedColor: ResourceColor): TabBarSymbol {
    const renderingStrategy: SymbolRenderingStrategy = HdsTabsCustomization.isSingleSymbolRendering(
      this.tabSymbolRendering
    ) ? SymbolRenderingStrategy.SINGLE : SymbolRenderingStrategy.MULTIPLE_OPACITY;
    return {
      normal: new SymbolGlyphModifier(icon)
        .fontSize(24)
        .fontColor([$r('app.color.tab_bar_icon_unselected')])
        .renderingStrategy(renderingStrategy),

      selected: new SymbolGlyphModifier(icon)
        .fontSize(24)
        .fontColor([selectedColor])
        .renderingStrategy(renderingStrategy)
        .symbolEffect(
          new BounceSymbolEffect(EffectScope.WHOLE, EffectDirection.DOWN)
        )
    };
  }

  @State aiSheetController: AISheetController = new AISheetController();

  private closeCategorySideBar(): void {
    this.getUIContext().animateTo({
      duration: 260,
      curve: Curve.EaseInOut
    }, () => {
      this.isCategorySideBarShown = false;
    });
  }

  @Builder
  private categorySideBarNavigationBuilder() {
    HdsNavigation() {
      CategoryFilterSideBar({ categoryFilter: $categoryFilter })
    }
    .titleBar({
      style: getImmersiveTitleBarStyle(false),
      content: {
        title: { mainTitle: '分类' },
        subIcon: {
          content: {
            icon: $r('sys.symbol.open_sidebar'),
            action: (): void => {
              this.closeCategorySideBar();
            }
          }
        },
        divider: { showType: DividerShowType.OFF }
      }
    })
    .titleMode(HdsNavigationTitleMode.MINI)
    .mode(NavigationMode.Stack)
    .hideBackButton(true)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .backgroundColor(Color.Transparent)
    .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR)
  }

  @Builder
  private mainTabContent(tab: HdsTabDescriptor) {
    if (tab.id === HdsTabId.LIST) {
      TabContent() {
        MainHomePage({
          currentTabIndex: this.currentIndex,
          aiSheetController: this.aiSheetController,
          categoryFilter: $categoryFilter,
          isCategorySideBarShown: $isCategorySideBarShown
        })
          .width('100%')
          .height('100%')
          .attributeModifier(new TabAnimModifier(this.getVisibleTabIndex(tab.id), this.currentIndex))
          .animation({ duration: 300, curve: Curve.EaseInOut })
          .padding({ left: (this.isWideScreen && !this.getFloatingTabs()) ? TAB_VERTICAL_PADDING : 0 })
      }
      .tabBar(this.getTabBarStyle(tab))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    } else if (tab.id === HdsTabId.OVERVIEW) {
      TabContent() {
        OverviewPage({ currentTabIndex: this.currentIndex })
          .attributeModifier(new TabAnimModifier(this.getVisibleTabIndex(tab.id), this.currentIndex))
          .animation({ duration: 300, curve: Curve.EaseInOut })
          .padding({ left: (this.isWideScreen && !this.getFloatingTabs()) ? TAB_VERTICAL_PADDING : 0 })
      }
      .tabBar(this.getTabBarStyle(tab))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    } else if (tab.id === HdsTabId.CAPTURE) {
      TabContent() {
        CapturePage({ currentTabIndex: this.currentIndex })
          .attributeModifier(new TabAnimModifier(this.getVisibleTabIndex(tab.id), this.currentIndex))
          .animation({ duration: 300, curve: Curve.EaseInOut })
          .padding({ left: (this.isWideScreen && this.tabletUi && !this.getFloatingTabs()) ? TAB_VERTICAL_PADDING : 0 })
      }
      .tabBar(this.getTabBarStyle(tab))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    } else if (tab.id === HdsTabId.AI) {
      TabContent() {
        AIPage({
          isHdsTabActive: this.currentIndex === this.getVisibleTabIndex(tab.id)
        })
          .attributeModifier(new TabAnimModifier(this.getVisibleTabIndex(tab.id), this.currentIndex))
          .animation({ duration: 300, curve: Curve.EaseInOut })
          .padding({ left: (this.isWideScreen && this.tabletUi && !this.getFloatingTabs()) ? TAB_VERTICAL_PADDING : 0 })
      }
      .tabBar(this.getTabBarStyle(tab))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    } else {
      TabContent() {
        UserPage()
          .attributeModifier(new TabAnimModifier(this.getVisibleTabIndex(tab.id), this.currentIndex))
          .animation({ duration: 300, curve: Curve.EaseInOut })
          .padding({ left: (this.isWideScreen && this.tabletUi && !this.getFloatingTabs()) ? TAB_VERTICAL_PADDING : 0 })
      }
      .tabBar(this.getTabBarStyle(tab))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
  }

  @Builder
  private mainTabsBuilder() {
    AdaptedHdsTabs({
      currentIndex: $currentIndex,
      isWideScreen: this.isWideScreen,
      tabletUi: this.tabletUi,
      theme: this.theme,
      controller: this.tabsController,
      onTabClick: (index: number) => {
        if (index === this.currentIndex) {
          console.debug('[MainPage] 重复点击了第 ' + index.toString() + ' 页，触发回到顶部');
          AppStorage.setOrCreate('Event_ScrollToTop_' + index.toString(), Date.now());
        }
      },
      onMiniBarClick: () => {
        this.aiSheetController.showAI();
      }
    }) {
      ForEach(this.getVisibleTabs(), (tab: HdsTabDescriptor) => {
        this.mainTabContent(tab);
      }, (tab: HdsTabDescriptor) => tab.id)
    }
  }

  @Builder
  private mainTabsWithSideBarScrimBuilder() {
    Stack() {
      this.mainTabsBuilder()

      if (this.isCategorySideBarShown) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#44000000')
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      }
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

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
          SideBarContainer(SideBarContainerType.Overlay) {
            this.categorySideBarNavigationBuilder()

            this.mainTabsWithSideBarScrimBuilder()
          }
          .showSideBar($$this.isCategorySideBarShown)
          .showControlButton(false)
          .sideBarWidth(290)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        }
        .mode(NavigationMode.Stack)
        .customNavContentTransition((from: NavContentInfo, to: NavContentInfo, _operation: NavigationOperation) => {
          return this.searchRouteFadeTransition(from, to);
        })
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
    .bindSheet($$this.isGuideSheetShow, this.onboardingSheet(), SheetCompat.immersive({
      height: SheetSize.LARGE,
      dragBar: false,
      showClose: false,
      enableOutsideInteractive: false,
      shouldDismiss: (_sheetDismiss: SheetDismiss) => {
      },
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
    }))
  }
}
