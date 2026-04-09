import { LengthMetrics, mediaquery, promptAction, SymbolGlyphModifier } from '@kit.ArkUI';
import { LocalValues } from '../common/local/LocalValues';
import { PrivacyDialog } from './components/PrivacyDialog';
import { MainHomePage } from './routes/main/MainHomePage';
import { OverviewPage } from './routes/overview/OverviewPage';
import { UserPage } from './routes/user/UserPage';
import { common } from '@kit.AbilityKit';
import { WebParams } from './common/WebBrowserPage';
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
  private isDialogOpened: boolean = false;
  private isCheckingPrivacyDialog: boolean = false;

  dialogController: CustomDialogController | null = new CustomDialogController({
    builder: PrivacyDialog({
      onConfirm: async () => {
        await LocalValues.getInstance().setPrivacyAgreed();
        this.isBlocking = false;
        this.isDialogOpened = false;
        console.info('User agreed to privacy policy.');
      },
      onCancel: () => {
        this.context.terminateSelf().catch(() => {
          console.error('Terminate failed');
        });
      },
      onJumpToWeb: () => {
        this.isDialogOpened = false;
        this.openPrivacyWeb();
      },
    }),
    autoCancel: false,
    alignment: DialogAlignment.Center,
    cancel: () => {
      if (this.isBlocking) {
        this.context.terminateSelf().catch(() => {
          console.error('Terminate failed');
        });
      }
    }
  })

  onDataReady() {
    if (this.isAppDataReady) {
      animateTo({ duration: 600, curve: Curve.EaseOut }, () => {
        this.isShowUI = true;
      });

      this.checkAndShowDialog();
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
      this.checkAndShowDialog();
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

  async checkAndShowDialog() {
    if (!this.isAppDataReady) {
      console.info('App data is not ready, skip privacy check.');
      return;
    }

    if (this.isCheckingPrivacyDialog) {
      return;
    }

    if (this.appPathStack.size() > 0) {
      console.info('Current stack has pages, skip privacy check.');
      return;
    }

    if (this.privacyAgreed) {
      this.isBlocking = false;
      return;
    }

    this.isCheckingPrivacyDialog = true;

    try {
      const isAgreed = await LocalValues.getInstance().getIsPrivacyAgreed();
      if (!isAgreed && !this.isDialogOpened) {
        this.isBlocking = true;
        this.isDialogOpened = true;
        this.dialogController?.open();
      } else if (isAgreed) {
        this.isBlocking = false;
      }
    } finally {
      this.isCheckingPrivacyDialog = false;
    }
  }

  openPrivacyWeb() {
    const params: WebParams = {
      url: this.privacyUrl,
      title: '隐私协议',
      onClose: () => {
        console.info('WebBrowserPage is closing, re-checking privacy...');
        setTimeout(() => {
          this.checkAndShowDialog();
        }, 100);
      }
    };

    this.appPathStack.pushPath({
      name: 'webBrowser',
      param: params,
    });
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
    { title: '灵感', icon: $r('sys.symbol.quote'), index: 2 },
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
            }
          }) {
            // --- Tab 1: 主页 ---
            TabContent() {
              if (!(this.isWideScreen && this.tabletUi)) {
                MainHomePage({ currentTabIndex: this.currentIndex })
                  .width("100%")
                  .height("100%")
                  .attributeModifier(new TabAnimModifier(0, this.currentIndex))
                  .animation({
                    duration: 300, // 保持与 Tabs 动画时长一致
                    curve: Curve.EaseInOut
                  })
              } else {
                MainHomePageTablet()
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
  }
}
