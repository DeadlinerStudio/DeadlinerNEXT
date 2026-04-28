import { DividerShowType, HdsNavigation, HdsNavigationMenuItemOptions, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { promptAction } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { ITheme } from '../../common/theme/ThemeModel';
import { getImmersiveTitleBarStyle } from '../../common/style/NavStyles';
import { ManualDataManager } from '../../common/manual/ManualModel';
import { WebBrowserPageBuilder, WebParams } from './WebBrowserPage';
import { DEFAULT_LOTTIE_SCENES, buildGuidePageIds, loadGuideSceneConfigs } from './onboarding/OnboardingConfig';
import { IntroHeroPage, LottieScenePage, PrivacyAgreementPage } from './onboarding/OnboardingCorePages';
import { AiPage, ImmersiveEffectPage, NotificationPage, PersonalizationPage, SyncPage } from './onboarding/OnboardingSetupPages';
import { GuidePageId, LottieSceneMeta, PANEL_BG, RawFileResourceManager } from './onboarding/OnboardingTypes';
import { HelpDetailSheet } from '../routes/user/manual/HelpDetailSheet';

@Component
export struct LottieOnboardingSheet {
  onClose: () => void = () => {};
  onAgreePrivacy: () => void = () => {};
  onDeclinePrivacy: () => void = () => {};
  privacyRequired: boolean = false;
  privacyUrl: string = 'resource://rawfile/privacy_agreement.html';

  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  @Provide('onboardingLocalPathStack') onboardingNavStack: NavPathStack = new NavPathStack();
  @State private currentIndex: number = 0;
  @State private privacyAccepted: boolean = false;
  @State private lottieScenes: LottieSceneMeta[] = DEFAULT_LOTTIE_SCENES;
  @State private isHelpSheetShow: boolean = false;

  aboutToAppear(): void {
    this.privacyAccepted = this.privacyRequired ? false : true;
    void this.loadScenes();
  }

  private async loadScenes(): Promise<void> {
    const resourceManager: RawFileResourceManager = getContext(this).resourceManager as RawFileResourceManager;
    this.lottieScenes = await loadGuideSceneConfigs(resourceManager);
  }

  private pageIds(): GuidePageId[] {
    return buildGuidePageIds(deviceInfo.distributionOSApiVersion >= 60100);
  }

  private currentPageId(): GuidePageId {
    return this.pageIds()[this.currentIndex];
  }

  private lottieSceneById(id: GuidePageId): LottieSceneMeta {
    const scene: LottieSceneMeta | undefined = this.lottieScenes.find((item: LottieSceneMeta) => item.id === id);
    return scene ? scene : this.lottieScenes[0];
  }

  private canGoNext(): boolean {
    return this.currentIndex < this.pageIds().length - 1;
  }

  private canGoPrev(): boolean {
    return this.currentIndex > 0;
  }

  private openPrivacyWeb(): void {
    const params: WebParams = {
      url: this.privacyUrl,
      title: '隐私协议'
    };
    this.onboardingNavStack.pushPath({
      name: 'webBrowser',
      param: params
    });
  }

  private currentHelpManualId(): string {
    const pageId: GuidePageId = this.currentPageId();
    if (pageId === 'sync') {
      return 'webdav_config';
    }
    if (pageId === 'ai') {
      return 'ai_config';
    }
    return '';
  }

  private shouldShowHelpMenu(): boolean {
    return this.currentHelpManualId().length > 0;
  }

  private buildTitleMenus(): HdsNavigationMenuItemOptions[] {
    if (!this.shouldShowHelpMenu()) {
      return [];
    }
    return [
      {
        content: {
          icon: $r('sys.symbol.questionmark_circle'),
          action: (): void => {
            this.isHelpSheetShow = true;
          }
        }
      }
    ];
  }

  @Builder
  private helpSheetBuilder() {
    HelpDetailSheet({
      item: ManualDataManager.getInstance().getItemById(this.currentHelpManualId())
    })
  }

  @Builder
  private navDestination(name: string) {
    if (name === 'webBrowser') {
      WebBrowserPageBuilder();
    }
  }

  private handleNext(): void {
    const pageId: GuidePageId = this.currentPageId();

    if (pageId === 'privacy') {
      if (!this.privacyAccepted) {
        promptAction.showToast({ message: '请先勾选同意隐私协议' });
        return;
      }
      if (this.privacyRequired) {
        this.onAgreePrivacy();
      }
    }

    if (this.canGoNext()) {
      this.currentIndex += 1;
      return;
    }

    this.onClose();
  }

  private handlePrev(): void {
    if (this.canGoPrev()) {
      this.currentIndex -= 1;
    }
  }

  @Builder
  private pageBuilder(pageId: GuidePageId) {
    if (pageId === 'intro_welcome') {
      IntroHeroPage({
        icon: $r('sys.symbol.hand_tap_wave_2'),
        title: '欢迎使用 Deadliner',
        subtitle: '这是一段完整的新用户引导演示。我们会先完成基础确认，再做几项必要设置，最后介绍核心交互。'
      })
    } else if (pageId === 'privacy') {
      PrivacyAgreementPage({
        accepted: $privacyAccepted,
        onJumpToWeb: () => this.openPrivacyWeb()
      })
    } else if (pageId === 'intro_setup') {
      IntroHeroPage({
        icon: $r('sys.symbol.slider_horizontal_2'),
        title: '下面，我们来做一些必要的设置',
        subtitle: '这几步都尽量保持轻量，你可以先完成最关键的部分，后面也能随时在设置里继续调整。'
      })
    } else if (pageId === 'notifications') {
      NotificationPage()
    } else if (pageId === 'immersive') {
      ImmersiveEffectPage()
    } else if (pageId === 'sync') {
      SyncPage()
    } else if (pageId === 'ai') {
      AiPage()
    } else if (pageId === 'personalization') {
      PersonalizationPage()
    } else if (pageId === 'intro_interaction') {
      IntroHeroPage({
        icon: $r('sys.symbol.rectangle_on_rectangle'),
        title: '在开始您的任务管理体验之前，容许我为您介绍我们的交互',
        subtitle: '接下来这 5 个场景，覆盖了你最常用的进入方式和几个最高频的快捷操作。'
      })
    } else {
      LottieScenePage({
        scene: this.lottieSceneById(pageId),
        isActive: this.currentPageId() === pageId
      })
    }
  }

  build() {
    HdsNavigation(this.onboardingNavStack) {
      Column({ space: 18 }) {
        Swiper() {
          ForEach(this.pageIds(), (pageId: GuidePageId) => {
            this.pageBuilder(pageId)
          }, (pageId: GuidePageId) => pageId)
        }
        .index(this.currentIndex)
        .indicator(false)
        .itemSpace(0)
        .cachedCount(1)
        .loop(false)
        .curve(Curve.EaseInOut)
        .onChange((index: number) => {
          this.currentIndex = index;
        })
        .width('100%')
        .height(640)

        Row({ space: 10 }) {
          ForEach(this.pageIds(), (_pageId: GuidePageId, index: number) => {
            Row()
              .width(this.currentIndex === index ? 28 : 8)
              .height(8)
              .borderRadius(999)
              .backgroundColor(this.currentIndex === index ? this.theme.tabIcon : '#D6DCE8')
              .animation({ duration: 200, curve: Curve.EaseInOut })
          }, (_pageId: GuidePageId, index: number) => index.toString())
        }

        Row({ space: 12 }) {
          Button(this.currentPageId() === 'privacy' ? '不同意并退出' : '上一步')
            .type(ButtonType.Normal)
            .layoutWeight(1)
            .height(48)
            .enabled(this.currentPageId() === 'privacy' || this.canGoPrev())
            .fontSize(16)
            .backgroundColor(PANEL_BG)
            .fontColor(this.currentPageId() === 'privacy' ? $r('app.color.warning') : $r('app.color.font_secondary'))
            .borderRadius(24)
            .onClick(() => {
              if (this.currentPageId() === 'privacy') {
                this.onDeclinePrivacy();
                return;
              }
              this.handlePrev();
            })

          Button(this.canGoNext() ? '下一步' : '开始体验')
            .layoutWeight(1)
            .height(48)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .backgroundColor(this.theme.tabIcon)
            .fontColor(Color.White)
            .borderRadius(24)
            .onClick(() => this.handleNext())
        }
        .width('100%')

        Blank()
          .width(0)
          .height(0)
          .bindSheet($$this.isHelpSheetShow, this.helpSheetBuilder(), {
            title: {
              title: this.currentPageId() === 'sync' ? '同步配置指南' : '如何配置 DeepSeek API？'
            },
            detents: [SheetSize.FIT_CONTENT, SheetSize.MEDIUM, SheetSize.LARGE],
            height: SheetSize.FIT_CONTENT,
            enableOutsideInteractive: false,
            dragBar: true,
            backgroundColor: Color.Transparent,
            blurStyle: BlurStyle.Regular,
            onDisappear: () => {
              this.isHelpSheetShow = false;
            }
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 18, bottom: 26 })
      .backgroundColor(Color.Transparent)
    }
    .titleBar({
      style: getImmersiveTitleBarStyle(false, false),
      content: {
        title: {
          mainTitle: '功能引导'
        },
        menu: {
          value: this.buildTitleMenus()
        },
        divider: { showType: DividerShowType.OFF }
      }
    })
    .titleMode(HdsNavigationTitleMode.MODAL)
    .navDestination(this.navDestination)
    .hideBackButton(true)
    .backgroundColor(Color.Transparent)
    .mode(NavigationMode.Stack)
  }
}
