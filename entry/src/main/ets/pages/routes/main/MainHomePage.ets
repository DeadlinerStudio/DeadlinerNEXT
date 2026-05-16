import { ItemRestriction,
  SegmentButtonTextItem,
  Theme } from '@kit.ArkUI'
import { HomeFloatingToolbar } from '../../components/HomeFloatingToolbar'
import { HabitListSection } from './HabitListSection'
import { TaskListSection } from './TaskListSection'
import { DividerShowType, HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit'
import { TaskListController } from './TaskListController'
import { ConfettiController } from '../../components/confetti/ConfettiController'
import { ConfettiView } from '../../components/confetti/ConfettiView'
import { AIPanelView } from '../../common/AIPanelView'
import { HabitListController } from './HabitListController'
import { SettingsConstants as C } from '../../../common/local/SettingsConstants'
import { ArchivePanelView } from '../../common/ArchivePanelView'
import { AddTaskPage } from './modify/task/AddTaskPage'
import { AddTaskSheet } from './modify/task/AddTaskSheet'
import { AddHabitSheet } from './modify/habit/AddHabitSheet'
import { LocalValues } from '../../../common/local/LocalValues'
import { MainButtonType } from '../../../common/local/LocalModels'
import { getImmersiveTitleBarStyle } from '../../../common/style/NavStyles'
import { HdsTitleBarMenuButton } from '../../components/HdsTitleBarMenuButton'
import { HdsTitleBarSegment } from '../../components/HdsTitleBarSegment'
import { AISheetController } from '../../components/AISheetController'

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
  @StorageProp('currentThemeKey') currentThemeKey: string = 'vibrant';

  @State currentIndex: number = MainTabIndex.TASKS
  @State @Watch('onSegmentChange') selectedIndexes: number[] = [MainTabIndex.TASKS]

  @State isTaskSelectionMode: boolean = false;
  private taskController: TaskListController = new TaskListController();

  @State isHabitSelectionMode: boolean = false
  private habitController: HabitListController = new HabitListController();

  @State confettiController: ConfettiController = new ConfettiController();

  @StorageLink('QuickAddTaskTrigger') @Watch('onQuickAddTaskChange') quickAddTrigger: boolean = false;

  @ObjectLink aiSheetController: AISheetController;

  @State scrollY: number = 0;

  bindController() {
    this.aiSheetController._triggerAction = () => {
      this.openAiPanel();
    }
    this.taskController.onScroll = (offset: number) => {
      this.scrollY = offset;
    }
  }

  /**
   * 监听回调函数
   */
  onQuickAddTaskChange() {
    // 只有当值为 true 时才执行，防止重置为 false 时再次触发
    if (this.quickAddTrigger === true) {
      console.info('[MainHomePage] Widget trigger received, opening AddTask...');

      // A. 执行你原本的添加逻辑
      if (!LocalValues.getInstance().getFullScreenAdd()) this.isAddShow = true;
      else this.appPathStack.pushPathByName('addTask', null);

      // B. 【重要】执行完后立马重置为 false
      // 这样下次点击小组件时，状态才能再次从 false 变为 true，触发 @Watch
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
  @StorageProp('statusBarHeight') statusBarHeight: number = 38;

  // readonly TITLE_BAR_CONTENT_HEIGHT: number = 74 + this.SEGMENT_HEIGHT;
  @State topContentHeight: number = 74;

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
      icon: $r('sys.symbol.square'),
      onClick: () => {}
    }
  ]

  mapMainHomePageButton(type: MainButtonType): MainHomePageButton {
    switch (type) {
      case MainButtonType.ARCHIVE: return this.mainHomePageButtons[0];
      case MainButtonType.SEARCH: return this.mainHomePageButtons[1];
      case MainButtonType.AI: return this.mainHomePageButtons[2];
      default: return this.mainHomePageButtons[3];
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

  @Builder topSegment() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.titleMode === HdsNavigationTitleMode.FULL) {
        Row() {
          HdsTitleBarMenuButton({
            icon: this.leftBtn.icon,
            onButtonClick: this.leftBtn.onClick,
            isImage: this.leftBtn.isImage,
            isEnabled: ((this.leftBtnType === MainButtonType.AI) && !this.isBasicMode) ||
              (this.leftBtnType !== MainButtonType.AI)
          })
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
            experimentalWidth: 196,
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
        HdsTitleBarMenuButton({
          icon: this.rightBtn.icon,
          onButtonClick: this.rightBtn.onClick,
          isImage: this.rightBtn.isImage,
          isEnabled: ((this.rightBtnType === MainButtonType.AI) && !this.isBasicMode) || (this.rightBtnType !== MainButtonType.AI)
        })
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
  @Builder
  archiveSheet() {
    ArchivePanelView()
      .width('100%')
      .height('100%')
  }

  @State isAddShow: boolean = false;
  onAddSheetQuit: () => void = () => {
    this.isAddShow = false
  }

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

  @State titleMode: HdsNavigationTitleMode = HdsNavigationTitleMode.FULL;

  build() {
    HdsNavigation() {
        RelativeContainer() {
          // 列表内容：铺满整个容器
          if (this.currentIndex === MainTabIndex.TASKS) {
            TaskListSection({
              scroller: this.scroller,
              topAvoidHeight: this.statusBarHeight + this.topContentHeight,
              isSelectionMode: $isTaskSelectionMode,
              controller: this.taskController,
              confetti: this.confettiController
            })
              .id('content')
              .alignRules({
                top: { anchor: '__container__', align: VerticalAlign.Top },
                bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
                left: { anchor: '__container__', align: HorizontalAlign.Start },
                right: { anchor: '__container__', align: HorizontalAlign.End },
              })
          } else {
            HabitListSection({
              scroller: this.dummyScroller,
              topAvoidHeight: this.statusBarHeight + this.topContentHeight,
              isSelectionMode: $isHabitSelectionMode,
              controller: this.habitController,
              confetti: this.confettiController
            })
              .id('content')
              .alignRules({
                top: { anchor: '__container__', align: VerticalAlign.Top },
                bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
                left: { anchor: '__container__', align: HorizontalAlign.Start },
                right: { anchor: '__container__', align: HorizontalAlign.End },
              })
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

          if (this.currentIndex === MainTabIndex.TASKS) {
            HomeFloatingToolbar({
              isSelectionMode: this.isTaskSelectionMode,
              selectedTask: true,

              // 主按钮逻辑：多选时为关闭，平时为添加
              onClickAdd: () => {
                if (this.isTaskSelectionMode) {
                  this.taskController.requestExitSelection();
                } else {
                  if (!LocalValues.getInstance().getFullScreenAdd()) this.isAddShow = true;
                  else this.appPathStack.pushPathByName('addTask', null);
                }
              },

              // 批量操作代理到 Controller
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
    .id(`main_navigation_${this.currentThemeKey}`)
    .titleBar({
      style: getImmersiveTitleBarStyle(false),
      content: {
        title: {
          mainTitle: 'Deadliner'
        },
        stackBuilder: () => {
          this.topSegment();
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
