import {
  HdsNavDestination
} from '@kit.UIDesignKit';
import { promptAction } from '@kit.ArkUI';
import { TopSafeContainer } from '../../../components/TopSafeContainer';
import { TaskRepository } from '../../../../common/repository/TaskRepository';
import { HabitRepository } from '../../../../common/repository/HabitRepository';
import { InspirationRepository } from '../../../../common/repository/InspirationRepository';
import { DDLStatus } from '../../../../model/DDLStatus';
import { DDLItemCardSwipeable, ArchivedDDLItemCard } from '../../../components/TaskItemCard'; // [导入] 归档卡片
import { HabitRow, HabitWithDailyStatus } from '../../../components/HabitComponents';
import { FloatUpModifier } from '../../../../utils/animation/FloatUpModifier';
import { VibrationUtils } from '../../../../utils/VibrationUtils';
import { ConfettiController } from '../../../components/confetti/ConfettiController';
import { SearchUtils, TaskUIModel, ArchivedSearchModel } from '../../../../utils/SearchUtils';
import { DDLItem, Habit } from '../../../../model/DDLModels';
import { InspirationItem } from '../../../../model/InspirationModels';
import { ITheme } from '../../../../common/theme/ThemeModel';
import { TaskState, TaskStateAction } from '../../../../model/TaskStateMachine';
import { InspirationEditSheet, InspirationSearchCard } from '../../capture/CaptureComponents';
import { AddTaskSheet } from '../modify/task/AddTaskSheet';
import { AddHabitSheet } from '../modify/habit/AddHabitSheet';
import { getImmersiveTitleBarStyle } from '../../../../common/style/NavStyles';
import { SettingsConstants as C } from '../../../../common/local/SettingsConstants';
import { getHdsMaterialLevelRaw } from '../../../../common/style/MaterialLevel';
import { HdsMiniBarButton } from '../../../components/infra/HdsMiniBarButton';

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
  @State inspirationResults: InspirationItem[] = [];
  @State archivedResults: ArchivedSearchModel[] = []; // [新增] 归档结果

  private logic = SearchUtils.getInstance();
  private taskRepo = TaskRepository.getInstance();
  private habitRepo = HabitRepository.getInstance();
  private inspirationRepo = InspirationRepository.getInstance();

  private scroller: Scroller = new Scroller();
  private confetti: ConfettiController = new ConfettiController();
  @State isFirstLoad: boolean = true;

  @State isInspirationSheetShow: boolean = false;
  @State editingInspiration: InspirationItem | null = null;
  @State inspirationDraftText: string = '';
  @State isAddTaskSheetShow: boolean = false;
  @State isAddHabitSheetShow: boolean = false;
  @State aiTargetText: string = '';
  @State directTaskName: string = '';
  @State directTaskNote: string = '';
  @State directHabitName: string = '';
  @State searchBarMeasuredWidth: number = 0;

  readonly SEARCH_INPUT_ID = 'search_input';
  @StorageLink(C.KEY_EXPERIMENTAL_COMPONENTS) experimentalComponents: boolean = true;
  @StorageProp(C.KEY_ENABLE_API23) api23: boolean = false;
  @StorageProp(C.KEY_API23_MATERIAL_LEVEL) materialLevel: string = 'EXQUISITE';

  async aboutToAppear() {
    await this.logic.preloadData();
    getContext(this).eventHub.on('sync_done', (): void => {
      void this.logic.preloadData().then(async (): Promise<void> => {
        if (this.searchText) {
          await this.handleSearch(this.searchText);
        }
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
      this.inspirationResults = [];
      this.archivedResults = [];
      return;
    }

    this.isSearching = true;
    const results = await this.logic.executeSearch(value);

    animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
      this.taskResults = results.tasks;
      this.habitResults = results.habits;
      this.inspirationResults = results.inspirations;
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

  private async saveInspirationDetail(): Promise<void> {
    if (!this.editingInspiration) {
      return;
    }

    const text = this.inspirationDraftText.trim();
    if (!text) {
      promptAction.showToast({ message: '留一点内容再保存吧' });
      return;
    }

    await this.inspirationRepo.updateInspiration({
      id: this.editingInspiration.id,
      text: text,
      createdAt: this.editingInspiration.createdAt,
      updatedAt: this.editingInspiration.updatedAt
    });
    this.isInspirationSheetShow = false;
    this.editingInspiration = null;
    await this.logic.preloadData();
    await this.handleSearch(this.searchText);
    getContext(this).eventHub.emit('sync_done');
  }

  private async deleteInspiration(item: InspirationItem): Promise<void> {
    await this.inspirationRepo.deleteInspiration(item.id);
    promptAction.showToast({ message: '已删除' });
    await this.logic.preloadData();
    await this.handleSearch(this.searchText);
    getContext(this).eventHub.emit('sync_done');
  }

  private openInspirationDetail(item: InspirationItem): void {
    this.editingInspiration = item;
    this.inspirationDraftText = item.text;
    this.isInspirationSheetShow = true;
  }

  private guessTitleFromText(text: string): string {
    const normalized = text.replace(/\n+/g, ' ').trim();
    if (!normalized) {
      return '未命名灵感';
    }
    return normalized.length > 24 ? normalized.slice(0, 24) : normalized;
  }

  private openAiTaskFromText(text: string): void {
    this.aiTargetText = text;
    this.isInspirationSheetShow = false;
    this.isAddTaskSheetShow = true;
  }

  private openAiHabitFromText(text: string): void {
    this.aiTargetText = text;
    this.isInspirationSheetShow = false;
    this.isAddHabitSheetShow = true;
  }

  private openDirectTaskFromText(text: string): void {
    this.aiTargetText = '';
    this.directTaskName = this.guessTitleFromText(text);
    this.directTaskNote = text;
    this.isInspirationSheetShow = false;
    this.isAddTaskSheetShow = true;
  }

  private openDirectHabitFromText(text: string): void {
    this.aiTargetText = '';
    this.directHabitName = this.guessTitleFromText(text);
    this.isInspirationSheetShow = false;
    this.isAddHabitSheetShow = true;
  }

  private resolveSearchBarWidth(): number {
    return this.searchBarMeasuredWidth > 0 ? this.searchBarMeasuredWidth : 320;
  }

  @Builder
  private searchInputContent(isTransparentBg: boolean = false) {
    if (isTransparentBg) {
      Search({ value: this.searchText, placeholder: '搜索任务、习惯或灵感...' })
        .searchButton('搜索', { fontColor: this.theme.brand })
        .id('search_input')
        .defaultFocus(true)
        .width('100%')
        .height(40)
        .backgroundColor(Color.Transparent)
        .placeholderColor($r('sys.color.ohos_id_color_text_secondary'))
        .onChange((value: string) => this.handleSearch(value))
        .margin({ top: 0 })
    } else {
      Search({ value: this.searchText, placeholder: '搜索任务、习惯或灵感...' })
        .searchButton('搜索', { fontColor: this.theme.brand })
        .id('search_input')
        .defaultFocus(true)
        .width('100%')
        .height(40)
        .placeholderColor($r('sys.color.ohos_id_color_text_secondary'))
        .onChange((value: string) => this.handleSearch(value))
    }
  }

  @Builder searchBuilder() {
    if (this.experimentalComponents && this.api23) {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          HdsMiniBarButton({
            barWidth: this.resolveSearchBarWidth(),
            barHeight: 52,
            materialLevel: getHdsMaterialLevelRaw(this.materialLevel)
          }) {
            this.searchInputContent(true)
          }
        }
        .width('100%')
        .height(52)
        .onAreaChange((_, area) => {
          if (typeof area.width === 'number' && area.width > 0) {
            this.searchBarMeasuredWidth = area.width;
          }
        })
      }
      .padding({ left: 64, right: 16 })
    } else {
      Row() {
        this.searchInputContent()
      }
      .padding({ left: 64, right: 16 })
    }
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
        Text('支持搜索任务、习惯和灵感内容')
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

  @Builder inspirationSheetBuilder() {
    InspirationEditSheet({
      isShow: $isInspirationSheetShow,
      draftText: $inspirationDraftText,
      item: this.editingInspiration,
      onSave: async (): Promise<void> => {
        await this.saveInspirationDetail();
      },
      onDelete: async (): Promise<void> => {
        if (this.editingInspiration) {
          await this.deleteInspiration(this.editingInspiration);
          this.isInspirationSheetShow = false;
        }
      },
      onAiTask: (): void => this.openAiTaskFromText(this.inspirationDraftText),
      onAiHabit: (): void => this.openAiHabitFromText(this.inspirationDraftText),
      onDirectTask: (): void => this.openDirectTaskFromText(this.inspirationDraftText),
      onDirectHabit: (): void => this.openDirectHabitFromText(this.inspirationDraftText)
    })
  }

  @Builder addTaskSheetBuilder() {
    AddTaskSheet({
      onDone: () => {
        this.isAddTaskSheetShow = false;
        this.aiTargetText = '';
        this.directTaskName = '';
        this.directTaskNote = '';
      },
      initialAiInputText: this.aiTargetText,
      autoTriggerAI: this.aiTargetText.length > 0,
      initialName: this.directTaskName,
      initialNote: this.directTaskNote
    })
  }

  @Builder addHabitSheetBuilder() {
    AddHabitSheet({
      onDone: () => {
        this.isAddHabitSheetShow = false;
        this.aiTargetText = '';
        this.directHabitName = '';
      },
      initialAiInputText: this.aiTargetText,
      autoTriggerAI: this.aiTargetText.length > 0,
      initialName: this.directHabitName
    })
  }

  build() {
    HdsNavDestination() {
      TopSafeContainer({
        topAvoidHeight: this.statusBarHeight,
        bgColor: this.bgColor
      }) {
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

              if (this.inspirationResults.length > 0) {
                ListItem() {
                  Text('灵感')
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                    .margin({ top: 16, bottom: -4, left: 12 })
                }
                ForEach(this.inspirationResults, (item: InspirationItem, index: number) => {
                  ListItem() {
                    InspirationSearchCard({
                      item: item,
                      onCardClick: (): void => this.openInspirationDetail(item),
                      onDelete: (): void => { void this.deleteInspiration(item); },
                      onAiTask: (): void => this.openAiTaskFromText(item.text),
                      onAiHabit: (): void => this.openAiHabitFromText(item.text)
                    })
                  }
                  .attributeModifier(new FloatUpModifier(index + 9, 15, false))
                }, (item: InspirationItem) => `inspiration_${item.id}`)
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
                this.inspirationResults.length === 0 &&
                this.archivedResults.length === 0) {
                ListItem() {
                  this.buildNoResultPlaceholder()
                }
              }

            ListItem().height(100)
          }
          .width('100%')
          .scrollBar(BarState.Off)
          .padding({ left: 12, right: 12 })
          .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        }

        Blank()
          .width(0)
          .height(0)
          .bindSheet($$this.isInspirationSheetShow, this.inspirationSheetBuilder(), {
            height: SheetSize.LARGE,
            blurStyle: BlurStyle.Regular,
            backgroundColor: Color.Transparent,
            showClose: false,
            onDisappear: () => {
              this.isInspirationSheetShow = false;
              this.editingInspiration = null;
            },
            title: {
              title: '编辑灵感',
              subtitle: '保留它的原始样子，之后再整理'
            }
          })

        Blank()
          .width(0)
          .height(0)
          .bindSheet($$this.isAddTaskSheetShow, this.addTaskSheetBuilder(), {
            height: SheetSize.LARGE,
            blurStyle: BlurStyle.Regular,
            backgroundColor: Color.Transparent,
            showClose: false,
            onDisappear: () => {
              this.isAddTaskSheetShow = false;
            }
          })

        Blank()
          .width(0)
          .height(0)
          .bindSheet($$this.isAddHabitSheetShow, this.addHabitSheetBuilder(), {
            height: SheetSize.LARGE,
            blurStyle: BlurStyle.Regular,
            backgroundColor: Color.Transparent,
            showClose: false,
            onDisappear: () => {
              this.isAddHabitSheetShow = false;
            }
          })
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
        },
      },
      style: getImmersiveTitleBarStyle(false, false)
    })
  }
}
