import { LengthMetrics, promptAction, Theme } from '@kit.ArkUI'
import { HomeFloatingToolbar } from '../../components/HomeFloatingToolbar'
import { HabitListSection } from './HabitListSection'
import { TaskListSection } from './TaskListSection'
import {
  DividerShowType,
  HdsNavigation,
  HdsNavigationAttribute,
  HdsNavigationTitleMode,
  ScrollEffectType
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
import { SideDashboard } from '../../components/SideDashboard'
import { SearchPage } from './search/SearchPage'
import { AddDialogTablet } from '../../components/AddDialogTablet'

interface MainHomePageButton {
  icon: Resource,
  onClick: () => void
}

@Component
export struct MainHomePageTablet {
  @Consume('appPathStack') appPathStack: NavPathStack;

  @StorageLink(C.KEY_BASIC_MODE) isBasicMode: boolean = false;
  @StorageLink(C.KEY_TABLET_SIDE_DASHBOARD) sdEnabled: boolean = true;

  // --- Controllers ---
  // 添加 Watch 监听，实现“互斥多选”逻辑
  @State @Watch('onTaskSelectionChange') isTaskSelectionMode: boolean = false;
  private taskController: TaskListController = new TaskListController();

  @State @Watch('onHabitSelectionChange') isHabitSelectionMode: boolean = false
  private habitController: HabitListController = new HabitListController();

  // 当任务进入多选，强制关闭习惯多选
  onTaskSelectionChange() {
    if (this.isTaskSelectionMode && this.isHabitSelectionMode) {
      this.habitController.requestExitSelection();
    }
  }

  // 当习惯进入多选，强制关闭任务多选
  onHabitSelectionChange() {
    if (this.isHabitSelectionMode && this.isTaskSelectionMode) {
      this.taskController.requestExitSelection();
    }
  }

  @State confettiController: ConfettiController = new ConfettiController();

  @StorageLink('QuickAddTaskTrigger') @Watch('onQuickAddTaskChange') quickAddTrigger: boolean = false;

  onQuickAddTaskChange() {
    if (this.quickAddTrigger === true) {
      console.info('[MainHomePageTablet] Widget trigger received, opening AddTask...');
      if (!LocalValues.getInstance().getFullScreenAdd()) this.isAddTaskShow = true;
      else this.appPathStack.pushPathByName('addTask', null);
      this.quickAddTrigger = false;
    }
  }

  // --- Layout Constants ---
  @StorageProp('statusBarHeight') statusBarHeight: number = 38;

  @State topContentHeight: number = 18;

  // --- Theme ---
  @State pageBackground: ResourceColor = '#FFFFFFFF'

  onWillApplyTheme(theme: Theme) {
    this.pageBackground = theme.colors.backgroundPrimary
  }

  aboutToAppear(): void {
    this.updateButtons();
  }

  private scrollerTask: Scroller = new Scroller();
  private scrollerHabit: Scroller = new Scroller();

  @StorageProp('Event_ScrollToTop_0')
  @Watch('onScrollToTopEvent')
  scrollToTopSignal: number = 0;

  onScrollToTopEvent() {
    this.scrollerTask.scrollTo({ xOffset: 0, yOffset: 0, animation: { duration: 300 } });
    this.scrollerHabit.scrollTo({ xOffset: 0, yOffset: 0, animation: { duration: 300 } });
  }

  // --- Buttons Logic ---
  readonly mainHomePageButtons: MainHomePageButton[] = [
    {
      icon: $r('sys.symbol.archivebox'),
      onClick: () => { this.isArchiveSheetShow = true; }
    },
    {
      icon: $r('sys.symbol.magnifyingglass'),
      onClick: () => { this.isSearchShow = true }
    },
    {
      icon: $r('app.media.lifi'),
      onClick: () => { this.openAiPanel() }
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
  }

  // --- AI Panel ---
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
    this.isAiFlowShown = false;
  }

  @Builder
  aiSheet() {
    AIPanelView({ onDismissPanel: () => { this.closeAiPanel(); } })
      .width('100%').height('100%')
  }

  // --- Sheets ---
  @State isArchiveSheetShow: boolean = false;
  @Builder
  archiveSheet() {
    ArchivePanelView().width('100%').height('100%')
  }

  @State isAddTaskShow: boolean = false;
  @State isAddHabitShow: boolean = false;

  onAddTaskQuit: () => void = () => { this.isAddTaskShow = false }
  onAddHabitQuit: () => void = () => { this.isAddHabitShow = false }

  @Builder
  addTaskSheetBuilder() {
    AddTaskSheet({ onDone: this.onAddTaskQuit }).width('100%')
  }

  @Builder
  addHabitSheetBuilder() {
    AddHabitSheet({ onDone: this.onAddHabitQuit }).width('100%')
  }

  addDialogController: CustomDialogController = new CustomDialogController({
    builder: AddDialogTablet({
      onAddTask: () => {
        // 处理新建任务逻辑
        if (!LocalValues.getInstance().getFullScreenAdd()) this.isAddTaskShow = true;
        else this.appPathStack.pushPathByName('addTask', null);
      },
      onAddHabit: () => {
        // 处理新建习惯逻辑
        if (!LocalValues.getInstance().getFullScreenAdd()) this.isAddHabitShow = true;
        else this.appPathStack.pushPathByName('addHabit', null);
      }
    }),
    alignment: DialogAlignment.Center, // 居中显示
    autoCancel: true, // 点击遮罩层关闭
  });

  // 统一的 FAB 点击处理
  handleFabAddClick() {
    // 如果处于多选模式，点击是退出多选
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

  @State isSearchShow: boolean = false;
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

  build() {
    HdsNavigation() {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Row() {
          // --- 左侧：任务 ---
          RelativeContainer() {
            TaskListSection({
              scroller: this.scrollerTask,
              topAvoidHeight: 0,
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

          // --- 右侧：习惯 ---
          RelativeContainer() {
            HabitListSection({
              scroller: this.scrollerHabit,
              topAvoidHeight: 0,
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
          // [绑定位置] 保持不变
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
          }
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.pageBackground)
        .padding({ top: this.statusBarHeight + this.topContentHeight })
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

        // --- 全局唯一的 FAB ---
        HomeFloatingToolbar({
          isHorizontal: false,
          // 只要任意一边进入多选，FAB 就变身
          isSelectionMode: this.isTaskSelectionMode || this.isHabitSelectionMode,
          // 如果是任务多选，左边按钮显示“完成”；否则（习惯多选）显示闹钟或其他
          selectedTask: this.isTaskSelectionMode,

          onClickAdd: (): void => this.handleFabAddClick(),

          // 根据当前是谁在多选，分发事件
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
    .titleBar({
      style: getImmersiveTitleBarStyle(true),
      content: {
        title: {
          mainTitle: '清单',
        },
        menu: {
          value: [
            {
              content: {
                icon: this.leftBtn.icon,
                action: () => { this.leftBtn.onClick(); },
                isEnabled: ((this.leftBtnType === MainButtonType.AI) && !this.isBasicMode) || (this.leftBtnType !== MainButtonType.AI)
              }
            },
            {
              content: {
                icon: this.rightBtn.icon,
                action: () => { this.rightBtn.onClick(); },
                isEnabled: ((this.rightBtnType === MainButtonType.AI) && !this.isBasicMode) || (this.rightBtnType !== MainButtonType.AI)
              }
            },
          ]
        },
        divider: { showType: DividerShowType.OFF }
      }
    })
    .titleMode(HdsNavigationTitleMode.MINI)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .mode(NavigationMode.Stack)
    .navBarWidth('100%')
    .bindSheet($$this.isAISheetShow, this.aiSheet(), {
      height: SheetSize.LARGE,
      dragBar: true,
      enableOutsideInteractive: false,
      onDisappear: () => { this.closeAiPanel(); },
      blurStyle: BlurStyle.Regular,
      backgroundColor: Color.Transparent,
      title: { title: 'Deadliner AI' }
    })
    .hideBackButton(true)
    .padding({ top: this.statusBarHeight })
  }
}