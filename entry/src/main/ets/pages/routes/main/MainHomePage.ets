import { ItemRestriction,
  SegmentButtonTextItem,
  Theme } from '@kit.ArkUI'
import auth from "@hw-agconnect/auth";
import { Context } from "@kit.AbilityKit";
import { HomeFloatingToolbar } from '../../components/HomeFloatingToolbar'
import { HabitListSection } from './HabitListSection'
import { TaskListSection } from './TaskListSection'
import {
  DividerShowType,
  HdsNavigation,
  HdsNavigationMenuItemOptions,
  HdsNavigationTitleMode,
  IconStyleMode
} from '@kit.UIDesignKit'
import { TaskListController } from './TaskListController'
import { ConfettiController } from '../../components/confetti/ConfettiController'
import { ConfettiView } from '../../components/confetti/ConfettiView'
import { AIPanelView } from '../../common/AIPanelView'
import { HabitListController } from './HabitListController'
import { SettingsConstants as C } from '../../../common/local/SettingsConstants'
import { ArchivePanelView } from '../../common/ArchivePanelView'
import { AddTaskSheet } from './modify/task/AddTaskSheet'
import { AddHabitSheet } from './modify/habit/AddHabitSheet'
import { LocalValues } from '../../../common/local/LocalValues'
import { MainButtonType } from '../../../common/local/LocalModels'
import { getImmersiveTitleBarStyle } from '../../../common/style/NavStyles'
import { HdsTitleBarMenuButton } from '../../components/HdsTitleBarMenuButton'
import { HdsTitleBarSegment } from '../../components/HdsTitleBarSegment'
import { AISheetController } from '../../components/AISheetController'
import { SideDashboard } from '../../components/SideDashboard'
import { SearchPage } from './search/SearchPage'
import { AddDialogTablet } from '../../components/AddDialogTablet'
import { MainProfileQuickSheet, ProfileAvatarMenuButton } from '../../components/MainProfileEntry'
import { HuaweiAccountUtils } from '../../../utils/account/HuaweiAccountUtils'
import {
  AppBreakpoint,
  AppBreakpointUtils,
  APP_BREAKPOINT_DEFAULT,
  APP_BREAKPOINT_STORAGE_KEY
} from '../../../common/layout/AppBreakpoints'

enum MainTabIndex {
  TASKS = 0,
  HABITS = 1,
  SUGGESTS = 2
}

interface MainHomePageButton {
  icon: Resource,
  onClick: () => void,
  isImage?: boolean
}

@Component
export struct MainHomePage {
  @Consume('appPathStack') appPathStack: NavPathStack;

  @StorageLink(C.KEY_BASIC_MODE) isBasicMode: boolean = false;
  @StorageLink(C.KEY_ENABLE_TABLET_UI) tabletUi: boolean = true;
  @StorageLink(C.KEY_TABLET_SIDE_DASHBOARD) sdEnabled: boolean = true;
  @StorageLink('isLoggedIn') @Watch('onLoginStatusChange') isLoggedIn: boolean = false;
  @StorageProp('currentThemeKey') currentThemeKey: string = 'vibrant';
  @StorageLink(APP_BREAKPOINT_STORAGE_KEY) currentBreakpoint: string = APP_BREAKPOINT_DEFAULT;

  @State currentIndex: number = MainTabIndex.TASKS
  @State @Watch('onSegmentChange') selectedIndexes: number[] = [MainTabIndex.TASKS]

  @State @Watch('onTaskSelectionChange') isTaskSelectionMode: boolean = false;
  private taskController: TaskListController = new TaskListController();

  @State @Watch('onHabitSelectionChange') isHabitSelectionMode: boolean = false
  private habitController: HabitListController = new HabitListController();

  @State confettiController: ConfettiController = new ConfettiController();

  @StorageLink('QuickAddTaskTrigger') @Watch('onQuickAddTaskChange') quickAddTrigger: boolean = false;

  @ObjectLink aiSheetController: AISheetController;

  @State scrollY: number = 0;
  @State profileAvatarUri: string = '';
  @State hasProfileAvatar: boolean = false;
  private readonly defaultProfileAvatar: ResourceStr = $r('sys.symbol.person_crop_circle_fill_1');

  bindController() {
    this.aiSheetController._triggerAction = () => {
      this.openAiPanel();
    }
    this.taskController.onScroll = (offset: number) => {
      this.scrollY = offset;
    }
  }

  onLoginStatusChange() {
    if (this.isLoggedIn) {
      this.refreshProfileAvatar();
    } else {
      this.profileAvatarUri = '';
      this.hasProfileAvatar = false;
    }
  }

  onTaskSelectionChange() {
    if (this.usesWideSplitLayout() && this.isTaskSelectionMode && this.isHabitSelectionMode) {
      this.habitController.requestExitSelection();
    }
  }

  onHabitSelectionChange() {
    if (this.usesWideSplitLayout() && this.isHabitSelectionMode && this.isTaskSelectionMode) {
      this.taskController.requestExitSelection();
    }
  }

  /**
   * 监听回调函数
   */
  onQuickAddTaskChange() {
    // 只有当值为 true 时才执行，防止重置为 false 时再次触发
    if (this.quickAddTrigger === true) {
      console.info('[MainHomePage] Widget trigger received, opening AddTask...');

      if (this.usesWideSplitLayout()) {
        if (!LocalValues.getInstance().getFullScreenAdd()) this.isAddTaskShow = true;
        else this.appPathStack.pushPathByName('addTask', null);
      } else {
        if (!LocalValues.getInstance().getFullScreenAdd()) this.isAddShow = true;
        else this.appPathStack.pushPathByName('addTask', null);
      }

      this.quickAddTrigger = false;
    }
  }

  @Prop @Watch('onTabSwitch') currentTabIndex: number = 0;

  readonly TARGET_INDEX: number = 0;

  onTabSwitch() {
    if (this.currentTabIndex === this.TARGET_INDEX) {
      this.taskController.loadData();
      this.selectedIndexes[0] = MainTabIndex.TASKS;
      this.currentIndex = MainTabIndex.TASKS;
    } else {
    }
  }

  // 定义常量：SegmentButton 区域的高度 (标准高度 + 上下padding)
  readonly SEGMENT_HEIGHT: number = 48;

  // 获取状态栏高度
  @StorageLink('statusBarHeight') statusBarHeight: number = 38;
  @StorageLink('topAvoidExtraHeight') topAvoidExtraHeight: number = 0;

  // readonly TITLE_BAR_CONTENT_HEIGHT: number = 74 + this.SEGMENT_HEIGHT;
  @State topContentHeight: number = 74;
  readonly MINI_TOP_AVOID_HEIGHT: number = 18;

  // 这些 State 由主题驱动
  @State chipSelectedBg: ResourceColor = '#FFFFFF'
  @State chipSelectedFont: ResourceColor = '#000000'
  @State chipUnselectedFont: ResourceColor = '#00000099'
  @State pageBackground: ResourceColor = '#FFFFFFFF'
  @State fabBg: ResourceColor = '#6E8B74'
  @State fabIconColor: ResourceColor = '#FFFFFFFF'

  onWillApplyTheme(theme: Theme) {
    this.chipSelectedBg = theme.colors.interactiveSelect
    this.chipSelectedFont = theme.colors.fontPrimary
    this.chipUnselectedFont = theme.colors.fontSecondary
    this.pageBackground = theme.colors.backgroundPrimary
    this.fabBg = theme.colors.interactiveActive
    this.fabIconColor = theme.colors.iconEmphasize
  }

  @StorageProp(C.KEY_STARTUP_PAGE) @Watch('onStartupSettingLoaded') startupPageSetting: number = -1;

  onStartupSettingLoaded() {
    console.info(`[Startup] Detect change: ${this.startupPageSetting}`);

    if (this.startupPageSetting === -1) {
      return;
    }

    this.currentIndex = this.startupPageSetting;
    this.selectedIndexes = [this.startupPageSetting];
  }

  aboutToAppear(): void {
    this.updateButtons();

    this.onStartupSettingLoaded();

    this.bindController();

    if (this.isLoggedIn) {
      this.refreshProfileAvatar();
    } else {
      this.profileAvatarUri = '';
      this.hasProfileAvatar = false;
    }
  }

  async refreshProfileAvatar() {
    this.profileAvatarUri = '';
    this.hasProfileAvatar = false;

    try {
      const agcUser = await auth.getCurrentUser();
      const agcAvatar = agcUser?.getPhotoUrl() ?? '';
      if (agcAvatar.length > 0) {
        this.profileAvatarUri = agcAvatar;
        this.hasProfileAvatar = true;
      }

      const ctx = this.getUIContext().getHostContext();
      if (!ctx) {
        return;
      }

      try {
        const sysProfile = await HuaweiAccountUtils.getHuaweiAccountProfile(ctx as Context, false);
        if (sysProfile.avatar) {
          this.profileAvatarUri = sysProfile.avatar;
          this.hasProfileAvatar = true;
        }
      } catch (_err) {
      }
    } catch (_err) {
      this.profileAvatarUri = '';
      this.hasProfileAvatar = false;
    }
  }

  private scroller: Scroller = new Scroller();
  private dummyScroller: Scroller = new Scroller();

  @StorageProp('Event_ScrollToTop_0')
  @Watch('onScrollToTopEvent')
  scrollToTopSignal: number = 0;

  onScrollToTopEvent() {
    console.debug('MainHomePage received scroll to top signal');
    // 只有当前页面显示时才滚动
    if (this.currentIndex === MainTabIndex.TASKS) { // 假设你想让任务列表回滚
      this.scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: { duration: 300 } });
    }
  }

  onSegmentChange() {
    if (this.selectedIndexes.length > 0) {
      const nextIndex = this.selectedIndexes[0];

      // 如果要切到习惯页，先把任务页的 Scroller 重置回 0
      // 这样 HdsNavigation 才会因为绑定的还是同一个 scroller 且 offset 为 0 而丝滑地展开，且不触发重绘
      if (nextIndex === MainTabIndex.HABITS) {
        this.scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
      }

      this.currentIndex = nextIndex;
      this.taskController.requestExitSelection();
      this.habitController.requestExitSelection();
    }
  }

  private usesMediumLayout(): boolean {
    return this.currentBreakpoint === AppBreakpoint.MD;
  }

  private usesWideSplitLayout(): boolean {
    return this.tabletUi && AppBreakpointUtils.isWide(this.currentBreakpoint);
  }

  readonly tabButtons: ItemRestriction<SegmentButtonTextItem> = [
    { text: '任务' },
    { text: '习惯' }
  ] as ItemRestriction<SegmentButtonTextItem>;

  readonly mainHomePageButtons: MainHomePageButton[] = [
    {
      icon: $r('sys.symbol.archivebox'),
      onClick: () => { this.isArchiveSheetShow = true; }
    },
    {
      icon: $r('sys.symbol.magnifyingglass'),
      onClick: () => { this.appPathStack.pushPath({ name: "search" }) }
    },
    {
      icon: $r('app.media.lifi'),
      onClick: () => { this.openAiPanel() },
      isImage: true
    },
    {
      icon: $r('sys.symbol.person_crop_circle_fill_1'),
      onClick: () => { this.openProfileSheet(); }
    },
    {
      icon: $r('sys.symbol.square'),
      onClick: () => {}
    }
  ]

  mapMainHomePageButton(type: MainButtonType): MainHomePageButton {
    switch (type) {
      case MainButtonType.ARCHIVE: return this.mainHomePageButtons[0];
      case MainButtonType.SEARCH: return this.mainHomePageButtons[1];
      case MainButtonType.AI: return this.mainHomePageButtons[2];
      case MainButtonType.PROFILE: return this.mainHomePageButtons[3];
      default: return this.mainHomePageButtons[4];
    }
  }

  @StorageLink(C.KEY_MAIN_LEFT_BUTTON) @Watch('updateButtons') leftBtnType: MainButtonType = MainButtonType.ARCHIVE;
  @StorageLink(C.KEY_MAIN_RIGHT_BUTTON) @Watch('updateButtons') rightBtnType: MainButtonType = MainButtonType.SEARCH;

  @State leftBtn: MainHomePageButton = this.mainHomePageButtons[0];
  @State rightBtn: MainHomePageButton = this.mainHomePageButtons[1];

  updateButtons() {
    this.leftBtn = this.mapMainHomePageButton(this.leftBtnType);
    this.rightBtn = this.mapMainHomePageButton(this.rightBtnType);
    console.info('HomePage buttons updated:', this.leftBtnType, this.rightBtnType);
  }

  private isButtonEnabled(type: MainButtonType): boolean {
    return (type !== MainButtonType.AI) || !this.isBasicMode;
  }

  private buildWideTitleMenus(): HdsNavigationMenuItemOptions[] {
    // TODO: md/lg 的 HdsNavigation.menu 头像仍受 icon slot 约束，后续再评估是否改成可裁切资源或支持自定义菜单项。
    return [
      {
        content: {
          icon: $r('sys.symbol.archivebox'),
          action: () => { this.isArchiveSheetShow = true; },
          isEnabled: true
        }
      },
      {
        content: {
          icon: $r('sys.symbol.magnifyingglass'),
          action: () => { this.isSearchShow = true; },
          isEnabled: true
        }
      },
      {
        content: {
          icon: this.hasProfileAvatar ? this.profileAvatarUri : this.defaultProfileAvatar,
          action: () => { this.openProfileSheet(); },
          isEnabled: true,
          type: IconStyleMode.LARGE
        }
      }
    ];
  }

  private isTaskTab(): boolean {
    return this.currentIndex === MainTabIndex.TASKS;
  }

  private getFreeTopAvoidHeight(): number {
    return this.statusBarHeight + this.topContentHeight;
  }

  private getMiniTopAvoidHeight(): number {
    return this.statusBarHeight + this.MINI_TOP_AVOID_HEIGHT;
  }

  private openProfileSheet(): void {
    this.isProfileSheetShow = false;
  }

  private closeProfileSheet(): void {
    this.isProfileSheetShow = false;
  }

  private openInteractionSettings(): void {
    this.closeProfileSheet();
    this.appPathStack.pushPath({ name: 'settingsInteraction' });
  }

  private openMainPageButtonsSettings(): void {
    this.closeProfileSheet();
    this.appPathStack.pushPath({ name: 'settingsMainPageButtons' });
  }

  @Builder
  private phoneTopSegment() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.titleMode === HdsNavigationTitleMode.FULL) {
        Row() {
          if (this.leftBtnType === MainButtonType.PROFILE) {
            ProfileAvatarMenuButton({
              avatarUri: this.profileAvatarUri,
              hasAvatar: this.hasProfileAvatar,
              onButtonClick: this.leftBtn.onClick
            })
          } else {
            HdsTitleBarMenuButton({
              icon: this.leftBtn.icon,
              onButtonClick: this.leftBtn.onClick,
              isImage: this.leftBtn.isImage,
              isEnabled: this.isButtonEnabled(this.leftBtnType)
            })
          }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Start)
        .padding({ left: 16 })
        .hitTestBehavior(HitTestMode.Transparent)
        .opacity(Math.max(0, 1 - this.scrollY / 40))
        .transition(TransitionEffect.asymmetric(
          TransitionEffect.OPACITY.combine(TransitionEffect.translate({ x: -20 })),
          TransitionEffect.OPACITY.combine(TransitionEffect.translate({ x: -20 }))
        ))

        Column() {
          HdsTitleBarSegment({
            buttons: this.tabButtons,
            selectedIndexes: $selectedIndexes,
            maxFontScale: 2,
            segmentHeight: this.SEGMENT_HEIGHT,
            normalWidth: '50%',
            experimentalWidth: '50%',
            experimentalHeight: 52
          })
            .align(Alignment.Center)
            .margin({ top: 8 })
        }
        .justifyContent(FlexAlign.Center)
        .hitTestBehavior(HitTestMode.None)
        .opacity(Math.max(0, 1 - this.scrollY / 40))
        .transition(TransitionEffect.asymmetric(
          TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.9, y: 0.9 })),
          TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.9, y: 0.9 }))
        ))
      }

      Row() {
        if (this.rightBtnType === MainButtonType.PROFILE) {
          ProfileAvatarMenuButton({
            avatarUri: this.profileAvatarUri,
            hasAvatar: this.hasProfileAvatar,
            onButtonClick: this.rightBtn.onClick
          })
        } else {
          HdsTitleBarMenuButton({
            icon: this.rightBtn.icon,
            onButtonClick: this.rightBtn.onClick,
            isImage: this.rightBtn.isImage,
            isEnabled: this.isButtonEnabled(this.rightBtnType)
          })
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
      .padding({ right: 16 })
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .id(`main_titlebar_${this.currentThemeKey}`)
    .height('100%')
    .width('100%')
  }

  @Builder
  private mediumTopSegment() {
    Column() {
      HdsTitleBarSegment({
        buttons: this.tabButtons,
        selectedIndexes: $selectedIndexes,
        maxFontScale: 2,
        segmentHeight: this.SEGMENT_HEIGHT,
        normalWidth: '33%',
        experimentalWidth: '33%',
        experimentalHeight: 52
      })
        .align(Alignment.Center)
        .margin({ top: 8 })
    }
    .id(`main_titlebar_md_${this.currentThemeKey}`)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private currentSingleColumnListBuilder(idSuffix: string, topAvoidHeight: number, useLayoutWeight: boolean = false) {
    if (this.isTaskTab()) {
      TaskListSection({
        scroller: this.scroller,
        topAvoidHeight: topAvoidHeight,
        isSelectionMode: $isTaskSelectionMode,
        controller: this.taskController,
        confetti: this.confettiController
      })
        .id(`main_task_content_${idSuffix}`)
        .height('100%')
        .layoutWeight(useLayoutWeight ? 1 : 0)
    } else {
      HabitListSection({
        scroller: this.dummyScroller,
        topAvoidHeight: topAvoidHeight,
        isSelectionMode: $isHabitSelectionMode,
        controller: this.habitController,
        confetti: this.confettiController
      })
        .id(`main_habit_content_${idSuffix}`)
        .height('100%')
        .layoutWeight(useLayoutWeight ? 1 : 0)
    }
  }

  @Builder
  private currentPhoneListBuilder() {
    if (this.isTaskTab()) {
      TaskListSection({
        scroller: this.scroller,
        topAvoidHeight: this.getFreeTopAvoidHeight(),
        isSelectionMode: $isTaskSelectionMode,
        controller: this.taskController,
        confetti: this.confettiController
      })
        .id('main_task_content_phone')
        .alignRules({
          top: { anchor: '__container__', align: VerticalAlign.Top },
          bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
          left: { anchor: '__container__', align: HorizontalAlign.Start },
          right: { anchor: '__container__', align: HorizontalAlign.End },
        })
    } else {
      HabitListSection({
        scroller: this.dummyScroller,
        topAvoidHeight: this.getFreeTopAvoidHeight(),
        isSelectionMode: $isHabitSelectionMode,
        controller: this.habitController,
        confetti: this.confettiController
      })
        .id('main_habit_content_phone')
        .alignRules({
          top: { anchor: '__container__', align: VerticalAlign.Top },
          bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
          left: { anchor: '__container__', align: HorizontalAlign.Start },
          right: { anchor: '__container__', align: HorizontalAlign.End },
        })
    }
  }

  @Builder
  private currentPhoneFabBuilder() {
    if (this.isTaskTab()) {
      HomeFloatingToolbar({
        isSelectionMode: this.isTaskSelectionMode,
        selectedTask: true,
        onClickAdd: () => {
          if (this.isTaskSelectionMode) {
            this.taskController.requestExitSelection();
          } else {
            if (!LocalValues.getInstance().getFullScreenAdd()) this.isAddShow = true;
            else this.appPathStack.pushPathByName('addTask', null);
          }
        },
        handleBatchComplete: () => this.taskController.requestBatchComplete(),
        handleBatchArchive: () => this.taskController.requestBatchArchive(),
        handleBatchDelete: () => this.taskController.requestBatchDelete(),
        handleBatchEdit: () => this.taskController.requestBatchEdit(),
        handleSetAlarm: () => this.taskController.requestSetAlarm()
      })
        .id('fab')
        .alignRules({
          bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
          middle: { anchor: '__container__', align: HorizontalAlign.Center },
        })
        .margin({ bottom: 48 })
        .hitTestBehavior(HitTestMode.Transparent)
    } else {
      HomeFloatingToolbar({
        isSelectionMode: this.isHabitSelectionMode,
        selectedTask: false,
        onClickAdd: () => {
          if (this.isHabitSelectionMode) {
            this.habitController.requestExitSelection();
          } else {
            if (!LocalValues.getInstance().getFullScreenAdd()) this.isAddShow = true;
            else this.appPathStack.pushPathByName('addHabit', null);
          }
        },
        handleBatchComplete: () => this.habitController.requestBatchComplete(),
        handleBatchArchive: () => this.habitController.requestBatchArchive(),
        handleBatchDelete: () => this.habitController.requestBatchDelete(),
        handleBatchEdit: () => this.habitController.requestBatchEdit(),
        handleSetAlarm: () => this.habitController.requestSetAlarm()
      })
        .id('fab_habit')
        .alignRules({
          bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
          middle: { anchor: '__container__', align: HorizontalAlign.Center },
        })
        .margin({ bottom: 48 })
        .hitTestBehavior(HitTestMode.Transparent)
    }
  }

  @Builder
  private mediumContentBuilder() {
    Row() {
      this.currentSingleColumnListBuilder('md', this.getMiniTopAvoidHeight(), true)

      Divider()
        .vertical(true)
        .height('100%')
        .strokeWidth(1)
        .color($r('sys.color.ohos_id_color_list_separator'))
        .opacity(0.5)

      SideDashboard()
        .width(132)
        .height('100%')
        .padding({ top: this.getMiniTopAvoidHeight(), left: 10, right: 10, bottom: 24 })
    }
    .id('content_md')
    .width('100%')
    .height('100%')
    .alignRules({
      top: { anchor: '__container__', align: VerticalAlign.Top },
      bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
      left: { anchor: '__container__', align: HorizontalAlign.Start },
      right: { anchor: '__container__', align: HorizontalAlign.End },
    })
  }

  @State isAISheetShow: boolean = false;
  @Consume('isAiFlowShown') isAiFlowShown: boolean;

  private flowTimerId: number = -1;

  openAiPanel() {
    clearTimeout(this.flowTimerId);

    this.isAISheetShow = true;

    this.isAiFlowShown = true;

    this.flowTimerId = setTimeout(() => {
      animateTo({ duration: 500, curve: Curve.EaseOut }, () => {
        this.isAiFlowShown = false;
      })
    }, 400);
  }

  closeAiPanel() {
    clearTimeout(this.flowTimerId);

    this.isAISheetShow = false;
    this.isAiFlowShown = false; // 立即关闭，不需要动画了，因为 Sheet 都要没了
  }

  @Builder
  aiSheet() {
    AIPanelView({
      onDismissPanel: () => {
        this.closeAiPanel();
      }
    })
      .width('100%')
      .height('100%')
  }

  @State isArchiveSheetShow: boolean = false;
  @State isProfileSheetShow: boolean = false;
  @Builder
  archiveSheet() {
    ArchivePanelView()
      .width('100%')
      .height('100%')
  }

  @Builder
  profileSheet() {
    MainProfileQuickSheet({
      onOpenInteraction: () => {
        this.openInteractionSettings();
      },
      onOpenMainButtons: () => {
        this.openMainPageButtonsSettings();
      },
      onOpenAi: () => {
        this.closeProfileSheet();
        this.openAiPanel();
      }
    })
  }

  @State isAddShow: boolean = false;
  @State isAddTaskShow: boolean = false;
  @State isAddHabitShow: boolean = false;
  @State isSearchShow: boolean = false;
  onAddSheetQuit: () => void = () => {
    this.isAddShow = false
  }
  onAddTaskQuit: () => void = () => { this.isAddTaskShow = false }
  onAddHabitQuit: () => void = () => { this.isAddHabitShow = false }

  @Builder
  addSheet() {
    if (this.currentIndex == MainTabIndex.TASKS) {
      AddTaskSheet({ onDone: this.onAddSheetQuit })
        .width('100%')
        .height('100%')
    } else {
      AddHabitSheet({ onDone: this.onAddSheetQuit })
        .width('100%')
        .height('100%')
    }
  }

  @Builder
  addTaskSheetBuilder() {
    AddTaskSheet({ onDone: this.onAddTaskQuit })
      .width('100%')
  }

  @Builder
  addHabitSheetBuilder() {
    AddHabitSheet({ onDone: this.onAddHabitQuit })
      .width('100%')
  }

  @Builder
  searchSheet() {
    SearchPage({
      bgColor: Color.Transparent,
      backAction: () => {
        this.isSearchShow = false;
      }
    })
      .width('100%')
      .height('100%')
  }

  addDialogController: CustomDialogController = new CustomDialogController({
    builder: AddDialogTablet({
      onAddTask: () => {
        if (!LocalValues.getInstance().getFullScreenAdd()) this.isAddTaskShow = true;
        else this.appPathStack.pushPathByName('addTask', null);
      },
      onAddHabit: () => {
        if (!LocalValues.getInstance().getFullScreenAdd()) this.isAddHabitShow = true;
        else this.appPathStack.pushPathByName('addHabit', null);
      }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: true,
  });

  private handleWideFabAddClick(): void {
    if (this.isTaskSelectionMode) {
      this.taskController.requestExitSelection();
      return;
    }
    if (this.isHabitSelectionMode) {
      this.habitController.requestExitSelection();
      return;
    }
    this.addDialogController.open();
  }

  @Builder
  private wideContentBuilder() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Row() {
        RelativeContainer() {
          TaskListSection({
            scroller: this.scroller,
            topAvoidHeight: this.getMiniTopAvoidHeight() + this.statusBarHeight,
            isSelectionMode: $isTaskSelectionMode,
            controller: this.taskController,
            confetti: this.confettiController
          })
            .id('task_content')
            .alignRules({
              top: { anchor: '__container__', align: VerticalAlign.Top },
              bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
              left: { anchor: '__container__', align: HorizontalAlign.Start },
              right: { anchor: '__container__', align: HorizontalAlign.End },
            })
        }
        .layoutWeight(1)
        .height('100%')
        .bindSheet($$this.isAddTaskShow, this.addTaskSheetBuilder(), {
          height: SheetSize.FIT_CONTENT,
          enableOutsideInteractive: false,
          onDisappear: () => { this.isAddTaskShow = false; },
          blurStyle: BlurStyle.Regular,
          backgroundColor: Color.Transparent,
          showClose: false
        })

        Divider()
          .vertical(true)
          .height('100%')
          .strokeWidth(1)
          .color($r('sys.color.ohos_id_color_list_separator'))
          .opacity(0.5)

        RelativeContainer() {
          HabitListSection({
            scroller: this.dummyScroller,
            topAvoidHeight: this.getMiniTopAvoidHeight() + this.statusBarHeight,
            isSelectionMode: $isHabitSelectionMode,
            controller: this.habitController,
            confetti: this.confettiController
          })
            .id('habit_content')
            .alignRules({
              top: { anchor: '__container__', align: VerticalAlign.Top },
              bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
              left: { anchor: '__container__', align: HorizontalAlign.Start },
              right: { anchor: '__container__', align: HorizontalAlign.End },
            })
        }
        .layoutWeight(1)
        .height('100%')
        .bindSheet($$this.isAddHabitShow, this.addHabitSheetBuilder(), {
          height: SheetSize.FIT_CONTENT,
          enableOutsideInteractive: false,
          onDisappear: () => { this.isAddHabitShow = false; },
          blurStyle: BlurStyle.Regular,
          backgroundColor: Color.Transparent,
          showClose: false
        })

        if (this.sdEnabled) {
          Divider()
            .vertical(true)
            .height('100%')
            .strokeWidth(1)
            .color($r('sys.color.ohos_id_color_list_separator'))
            .opacity(0.5)

          SideDashboard()
            .width(108)
            .height('100%')
            .padding({ top: this.getMiniTopAvoidHeight() + this.statusBarHeight })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.pageBackground)
      .bindSheet($$this.isSearchShow, this.searchSheet(), {
        height: SheetSize.FIT_CONTENT,
        enableOutsideInteractive: false,
        onDisappear: () => { this.isSearchShow = false; },
        blurStyle: BlurStyle.Regular,
        showClose: false
      })

      ConfettiView({
        controller: this.confettiController,
        colors: ['#fce18a', '#ff726d', '#f4306d', '#b48def']
      })
        .hitTestBehavior(HitTestMode.None)
        .zIndex(1)

      HomeFloatingToolbar({
        isHorizontal: false,
        isSelectionMode: this.isTaskSelectionMode || this.isHabitSelectionMode,
        selectedTask: this.isTaskSelectionMode,
        onClickAdd: (): void => this.handleWideFabAddClick(),
        handleBatchComplete: () => {
          if (this.isTaskSelectionMode) this.taskController.requestBatchComplete();
          else this.habitController.requestBatchComplete();
        },
        handleBatchArchive: () => {
          if (this.isTaskSelectionMode) this.taskController.requestBatchArchive();
          else this.habitController.requestBatchArchive();
        },
        handleBatchDelete: () => {
          if (this.isTaskSelectionMode) this.taskController.requestBatchDelete();
          else this.habitController.requestBatchDelete();
        },
        handleBatchEdit: () => {
          if (this.isTaskSelectionMode) this.taskController.requestBatchEdit();
          else this.habitController.requestBatchEdit();
        },
        handleSetAlarm: () => {
          if (this.isTaskSelectionMode) this.taskController.requestSetAlarm();
          else this.habitController.requestSetAlarm();
        }
      })
        .align(Alignment.Bottom)
        .margin({ bottom: 32 })
        .hitTestBehavior(HitTestMode.Transparent)
    }
    .bindSheet($$this.isArchiveSheetShow, this.archiveSheet(), {
      height: SheetSize.FIT_CONTENT,
      enableOutsideInteractive: false,
      dragBar: true,
      onDisappear: () => { this.isArchiveSheetShow = false; },
      blurStyle: BlurStyle.Regular,
      backgroundColor: Color.Transparent,
      title: { title: '归档', subtitle: '可以在此处管理你已完成的任务' }
    })
  }

  @Builder
  private mainContentBuilder() {
    RelativeContainer() {
      if (this.usesMediumLayout()) {
        this.mediumContentBuilder()
      } else {
        this.currentPhoneListBuilder()
      }

      ConfettiView({
        controller: this.confettiController,
        colors: ['#fce18a', '#ff726d', '#f4306d', '#b48def']
      })
        .hitTestBehavior(HitTestMode.None)
        .id('confetti')
        .alignRules({
          top: { anchor: '__container__', align: VerticalAlign.Top },
          bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
          left: { anchor: '__container__', align: HorizontalAlign.Start },
          right: { anchor: '__container__', align: HorizontalAlign.End },
        })
        .zIndex(1)
        .bindSheet($$this.isAddShow, this.addSheet(), {
          height: SheetSize.LARGE,
          onDisappear: () => {
            this.isAddShow = false;
          },
          blurStyle: BlurStyle.Regular,
          backgroundColor: Color.Transparent,
          showClose: false
        })
        .bindSheet($$this.isProfileSheetShow, this.profileSheet(), {
          height: SheetSize.FIT_CONTENT,
          dragBar: true,
          blurStyle: BlurStyle.Regular,
          backgroundColor: Color.Transparent,
          onDisappear: () => { this.closeProfileSheet(); },
          title: { title: '主页工作台' }
        })

      this.currentPhoneFabBuilder()

      Column()
        .bindSheet($$this.isSearchShow, this.searchSheet(), {
          height: SheetSize.FIT_CONTENT,
          enableOutsideInteractive: false,
          onDisappear: () => { this.isSearchShow = false; },
          blurStyle: BlurStyle.Regular,
          showClose: false
        })
    }
    .height('100%')
    .width('100%')
    .bindSheet($$this.isArchiveSheetShow, this.archiveSheet(), {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      onDisappear: () => {
        this.isArchiveSheetShow = false;
      },
      blurStyle: BlurStyle.Regular,
      backgroundColor: Color.Transparent,
      title: {
        title: '归档',
        subtitle: '可以在此处管理你已完成的任务'
      },
    })
  }

  @State titleMode: HdsNavigationTitleMode = HdsNavigationTitleMode.FULL;

  build() {
    if (this.usesWideSplitLayout()) {
      HdsNavigation() {
        this.wideContentBuilder()
      }
      .titleBar({
        style: getImmersiveTitleBarStyle(true),
        avoidLayoutSafeArea: true,
        content: {
          title: {
            mainTitle: 'Deadliner',
          },
          menu: {
            value: this.buildWideTitleMenus()
          },
          divider: { showType: DividerShowType.OFF }
        }
      })
      .titleMode(HdsNavigationTitleMode.MINI)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .mode(NavigationMode.Stack)
      .navBarWidth('100%')
      .bindSheet($$this.isProfileSheetShow, this.profileSheet(), {
        height: SheetSize.FIT_CONTENT,
        dragBar: true,
        blurStyle: BlurStyle.Regular,
        backgroundColor: Color.Transparent,
        onDisappear: () => { this.closeProfileSheet(); },
        title: { title: '主页工作台' }
      })
      .hideBackButton(true)
    } else if (this.usesMediumLayout()) {
      HdsNavigation() {
        this.mainContentBuilder()
      }
      .id(`main_navigation_${this.currentThemeKey}`)
      .titleBar({
        style: getImmersiveTitleBarStyle(true),
        content: {
          title: {
            mainTitle: 'Deadliner'
          },
          stackBuilder: () => {
            this.mediumTopSegment();
          },
          menu: {
            value: this.buildWideTitleMenus()
          },
          divider: { showType: DividerShowType.OFF }
        }
      })
      .titleMode(HdsNavigationTitleMode.MINI)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .mode(NavigationMode.Stack)
      .navBarWidth('100%')
      .hideBackButton(true)
    } else {
      HdsNavigation() {
        this.mainContentBuilder()
      }
      .id(`main_navigation_${this.currentThemeKey}`)
      .titleBar({
        style: getImmersiveTitleBarStyle(false),
        content: {
          title: {
            mainTitle: 'Deadliner'
          },
          stackBuilder: () => {
            this.phoneTopSegment();
          },
          divider: { showType: DividerShowType.OFF }
        }
      })
      .bindSheet($$this.isAISheetShow, this.aiSheet(), {
        height: SheetSize.LARGE,
        dragBar: true,
        onDisappear: () => {
          this.closeAiPanel();
        },
        blurStyle: BlurStyle.Regular,
        backgroundColor: Color.Transparent,
        title: {
          title: 'Lifi AI',
        }
      })
      .titleMode(HdsNavigationTitleMode.FREE)
      .bindToScrollable([this.scroller])
      .onTitleModeChange((titleMode) => {
        animateTo({ duration: 400, curve: Curve.Friction }, () => {
          this.titleMode = titleMode;
        })
      })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .mode(NavigationMode.Stack)
      .navBarWidth('100%')
    }
  }
}
