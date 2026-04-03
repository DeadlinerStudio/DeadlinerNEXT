import {
  HdsNavDestination,
  HdsNavDestinationAttribute
} from '@kit.UIDesignKit';
import { promptAction } from '@kit.ArkUI';
import { TopSafeContainer } from '../../../components/TopSafeContainer';
import { TaskRepository } from '../../../../common/repository/TaskRepository';
import { HabitRepository } from '../../../../common/repository/HabitRepository';
import { DDLStatus } from '../../../../model/DDLStatus';
import { DDLItemCardSwipeable, ArchivedDDLItemCard } from '../../../components/TaskItemCard'; // [导入] 归档卡片
import { HabitRow, HabitWithDailyStatus } from '../../../components/HabitComponents';
import { FloatUpModifier } from '../../../../utils/animation/FloatUpModifier';
import { VibrationUtils } from '../../../../utils/VibrationUtils';
import { ConfettiController } from '../../../components/confetti/ConfettiController';
import { SearchUtils, TaskUIModel, ArchivedSearchModel } from '../../../../utils/SearchUtils';
import { DDLItem, Habit } from '../../../../model/DDLModels';
import { ITheme } from '../../../../common/theme/ThemeModel';
import { TaskState, TaskStateAction } from '../../../../model/TaskStateMachine';

@Builder
export function SearchPageBuilder() {
  SearchPage()
}

@Component
export struct SearchPage {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageProp('statusBarHeight') statusBarHeight: number = 38;

  @State bgColor: Resource | Color | ResourceColor = this.theme.bgPrimary;
  backAction?: () => void

  @State searchText: string = '';
  @State isSearching: boolean = false;
  @State hasSearchTerm: boolean = false;

  @State taskResults: TaskUIModel[] = [];
  @State habitResults: HabitWithDailyStatus[] = [];
  @State archivedResults: ArchivedSearchModel[] = []; // [新增] 归档结果

  private logic = SearchUtils.getInstance();
  private taskRepo = TaskRepository.getInstance();
  private habitRepo = HabitRepository.getInstance();

  private scroller: Scroller = new Scroller();
  private confetti: ConfettiController = new ConfettiController();
  @State isFirstLoad: boolean = true;

  readonly SEARCH_INPUT_ID = 'search_input';

  async aboutToAppear() {
    await this.logic.preloadData();
    getContext(this).eventHub.on('sync_done', () => {
      this.logic.preloadData().then(() => {
        if (this.searchText) this.handleSearch(this.searchText);
      });
    });
    setTimeout(() => {
      focusControl.requestFocus(this.SEARCH_INPUT_ID);
    }, 500);
    setTimeout(() => { this.isFirstLoad = false; }, 750);
  }

  aboutToDisappear(): void {
    getContext(this).eventHub.off('sync_done');
  }

  private async handleSearch(value: string) {
    this.searchText = value;
    const hasTerm = value.trim().length > 0;
    this.hasSearchTerm = hasTerm;

    if (!hasTerm) {
      this.taskResults = [];
      this.habitResults = [];
      this.archivedResults = [];
      return;
    }

    this.isSearching = true;
    const results = await this.logic.executeSearch(value);

    animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
      this.taskResults = results.tasks;
      this.habitResults = results.habits;
      this.archivedResults = results.archived; // [新增]
      this.isSearching = false;
    })
  }

  // —— 交互操作 ——

  private async onTaskPrimaryAction(taskUI: TaskUIModel) {
    VibrationUtils.vibrateShort();
    try {
      if (taskUI.taskState === TaskState.ACTIVE) {
        await this.taskRepo.transitionDDL(taskUI.dbId, TaskStateAction.MARK_COMPLETE);
        this.confetti.fire();
      } else {
        await this.taskRepo.transitionDDL(taskUI.dbId, TaskStateAction.RESTORE_ACTIVE);
      }
      this.handleSearch(this.searchText);
      getContext(this).eventHub.emit('sync_done');
    } catch (e) {
      console.error('Task complete failed', e);
    }
  }

  private onTaskSecondaryAction(taskUI: TaskUIModel) {
    if (taskUI.taskState === TaskState.ACTIVE) {
      AlertDialog.show({
        title: '放弃确认',
        message: `确定要放弃任务“${taskUI.title}”吗？`,
        primaryButton: {
          value: '取消',
          fontColor: this.theme.brand,
          action: () => {}
        },
        secondaryButton: {
          value: '放弃',
          fontColor: Color.Red,
          action: async () => {
            await this.taskRepo.transitionDDL(taskUI.dbId, TaskStateAction.MARK_GIVE_UP);
            this.handleSearch(this.searchText);
            getContext(this).eventHub.emit('sync_done');
          }
        }
      });
      return;
    }

    this.taskRepo.transitionDDL(taskUI.dbId, TaskStateAction.MARK_ARCHIVE).then(() => {
      this.handleSearch(this.searchText);
      getContext(this).eventHub.emit('sync_done');
    }).catch((e: Error) => {
      console.error('Task archive failed', e);
    });
  }

  private async onHabitToggle(item: HabitWithDailyStatus) {
    VibrationUtils.vibrateShort();
    try {
      const today = new Date();
      await this.habitRepo.toggleRecord(item.habit.id, today);
      if (!item.isCompleted && (item.doneCount + 1 >= item.targetCount)) {
        this.confetti.fire();
      }
      this.handleSearch(this.searchText);
      getContext(this).eventHub.emit('sync_done');
    } catch (e) {
      console.error('Habit toggle failed', e);
    }
  }

  // [新增] 处理归档项的删除
  private async onArchivedDelete(item: ArchivedSearchModel) {
    AlertDialog.show({
      title: '永久删除',
      message: '确定要永久删除此归档记录吗？',
      primaryButton: {
        value: '取消',
        fontColor: this.theme.brand,
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: Color.Red,
        action: async () => {
          try {
            if (item.originalType === 'task') {
              await this.taskRepo.deleteDDL((item.originalItem as DDLItem).id);
            } else {
              await this.habitRepo.deleteHabitByDdlId((item.originalItem as Habit).ddlId);
            }
            promptAction.showToast({ message: '已删除' });
            this.handleSearch(this.searchText); // 刷新搜索
            getContext(this).eventHub.emit('sync_done');
          } catch (e) {
            promptAction.showToast({ message: '删除失败' });
          }
        }
      }
    })
  }

  @Builder searchBuilder() {
    Row() {
      Search({ value: this.searchText, placeholder: '搜索任务或习惯...' })
        .searchButton('搜索', { fontColor: this.theme.brand })
        .id('search_input')
        .defaultFocus(true)
        .width('100%')
        .height(40)
        .placeholderColor($r('sys.color.ohos_id_color_text_secondary'))
        .onChange((value: string) => this.handleSearch(value))
    }
    .padding({ left: 64, right: 16 })
  }

  @Builder buildEmptyPlaceholder() {
    Column({ space: 16 }) {
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(80)
        .fontColor([$r('sys.color.ohos_id_color_text_tertiary')])
        .opacity(0.5)
      Column({ space: 4 }) {
        Text('输入关键词进行搜索')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        Text('支持搜索标题、备注和鼓励语')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
      }
    }
    .width('100%')
    .height('60%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder buildNoResultPlaceholder() {
    Column({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.nosign'))
        .fontSize(60)
        .fontColor([$r('sys.color.ohos_id_color_text_tertiary')])
      Text('未找到相关内容')
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
    }
    .width('100%')
    .height(300)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    HdsNavDestination() {
      TopSafeContainer({
        topAvoidHeight: this.statusBarHeight,
        scrollable: false,
        bgColor: this.bgColor
      }) {
        Column() {
          if (!this.hasSearchTerm) {
            this.buildEmptyPlaceholder()
          } else {
            List({ scroller: this.scroller, space: 10 }) {
              ListItem() { Column().height(8) }

              // A. 任务组
              if (this.taskResults.length > 0) {
                ListItem() {
                  Text('任务')
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                    .margin({ top: 16, bottom: -4, left: 12 })
                }
                ForEach(this.taskResults, (item: TaskUIModel, index: number) => {
                  ListItem() {
                    DDLItemCardSwipeable({
                      title: item.title,
                      remainingTimeAlt: item.remainingTimeAlt,
                      note: item.note,
                      progress: item.progress,
                      isStarred: item.isStarred,
                      status: item.status,
                      selectionMode: false,
                      selected: false,
                      primaryActionSymbol: item.taskState === TaskState.ACTIVE
                        ? $r('sys.symbol.checkmark_circle')
                        : $r('sys.symbol.arrowshape_turn_up_left'),
                      secondaryActionSymbol: item.taskState === TaskState.ACTIVE
                        ? $r('sys.symbol.flag')
                        : $r('sys.symbol.archivebox'),
                      secondaryActionColor: item.taskState === TaskState.ACTIVE
                        ? $r('app.color.chart_yellow')
                        : $r('app.color.chart_red'),
                      onPrimaryAction: (): Promise<void> => this.onTaskPrimaryAction(item),
                      onSecondaryAction: (): void => this.onTaskSecondaryAction(item)
                    })
                  }
                  .attributeModifier(new FloatUpModifier(index, 15, false))
                }, (item: TaskUIModel) => `task_${item.dbId}`)
              }

              // B. 习惯组
              if (this.habitResults.length > 0) {
                ListItem() {
                  Text('习惯')
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                    .margin({ top: 16, bottom: -4, left: 12 })
                }
                ForEach(this.habitResults, (item: HabitWithDailyStatus, index: number) => {
                  ListItem() {
                    HabitRow({
                      data: item,
                      status: item.isCompleted ? DDLStatus.COMPLETED : DDLStatus.UNDERGO,
                      isSelected: false,
                      canToggle: true,
                      remainingText: "",
                      onToggle: (): Promise<void> => this.onHabitToggle(item),
                      onLongPress: () => {}
                    })
                  }
                  .attributeModifier(new FloatUpModifier(index + 5, 15, false))
                }, (item: HabitWithDailyStatus) => `habit_${item.habit.id}`)
              }

              // [新增] C. 归档组
              if (this.archivedResults.length > 0) {
                ListItem() {
                  Text('归档内容')
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                    .margin({ top: 16, bottom: -4, left: 12 })
                }
                ForEach(this.archivedResults, (item: ArchivedSearchModel, index: number) => {
                  ListItem() {
                    // [新增] 使用归档卡片
                    ArchivedDDLItemCard({
                      title: item.title,
                      startTime: item.detail1,   // 对应左下
                      completeTime: item.detail2, // 对应右下
                      note: item.note,
                      badgeText: item.badgeText,
                      showRestore: false,
                      onDelete: (): Promise<void> => this.onArchivedDelete(item)
                    })
                  }
                  .attributeModifier(new FloatUpModifier(index + 10, 15, false))
                }, (item: ArchivedSearchModel) => item.id)
              }

              // D. 搜索无结果
              if (this.taskResults.length === 0 &&
                this.habitResults.length === 0 &&
                this.archivedResults.length === 0) {
                ListItem() {
                  this.buildNoResultPlaceholder()
                }
              }

              ListItem().height(100)
            }
            .width('100%')
            .layoutWeight(1)
            .scrollBar(BarState.Off)
            .padding({ left: 12, right: 12 })
            .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
          }
        }
        .width('100%')
        .height('100%')
      }
    }
    .backgroundColor(this.bgColor)
        .titleBar({
      content: {
        title: { mainTitle: '' },
        stackBuilder: () => {
          this.searchBuilder();
        },
        backIcon: {
          action: this.backAction
        }
      }
    })
  }
}
