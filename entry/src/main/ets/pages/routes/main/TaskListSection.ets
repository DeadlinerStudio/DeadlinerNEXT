import { FocusTimerSheet } from '../focus/FocusTimerSheet';
import { AppLog } from '../../../common/logging/AppLog';
import { DDLStatus } from "../../../model/DDLStatus";
import { DDLItemCardSwipeable } from "../../components/TaskItemCard";
import { curves, LengthMetrics, promptAction } from "@kit.ArkUI";
import { DDLItem, DeadlineType } from "../../../model/DDLModels";
import { TaskRepository } from "../../../common/repository/TaskRepository";
import { VibrationUtils } from "../../../utils/VibrationUtils";
import { TopSafeContainer } from "../../components/TopSafeContainer";
import { TaskListController } from "./TaskListController"
import { ConfettiController } from "../../components/confetti/ConfettiController";
import { SettingsConstants as C } from "../../../common/local/SettingsConstants"
import { FloatUpModifier } from "../../../utils/animation/FloatUpModifier";
import { TaskDetailSheet } from "./modify/task/TaskDetailSheet";
import { TaskEditSheet } from "./modify/task/TaskEditSheet";
import { PressEffectModifier } from "../../../utils/animation/PressModifier";
import { ITheme } from "../../../common/theme/ThemeModel";
import { TaskState, TaskStateAction } from "../../../model/TaskStateMachine";
import { DialogCompat } from "../../../common/ui/DialogCompat";
import { Toast } from '../../../common/ui/Toast';
import { MaterialPresets } from '../../../common/style/SystemMaterialCompat';
import { ImmersiveMaterialScope } from '../../components/ImmersiveMaterialScope';
import { CategoryRepository } from '../../../common/repository/CategoryRepository';
import { CategoryDisplayModel } from '../../../common/kmp/KmpCategoryRepositoryAdapter';
import { CategoryFilter, CategoryFilterResolver } from '../../../common/category/CategoryFilter';
import { SheetCompat } from '../../../common/ui/SheetCompat';
import { DeadlineStatusResolver } from '../../../common/semantic/DeadlineStatusResolver';
import { PageToneResolver } from '../../../common/semantic/PageToneResolver';
import {
  DeadlineSemanticStatus,
  SemanticPageKind,
  SemanticSnapshot
} from '../../../common/semantic/SemanticContract';
import { WidgetRefreshBridge, WidgetUpdateReason } from '../../../utils/WidgetRefreshBridge';

export interface TaskUIModel {
  title: string;
  remainingTimeAlt: string;
  note: string;
  progress: number;
  isStarred: boolean;
  status: DDLStatus;
  dbId: number;
  taskState: TaskState;
  categoryUid: string | null;
  categoryName: string;
  categoryIconKey: string;
  categoryColorHex: string;
}

@Component
export struct TaskListSection {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @StorageLink('isWideScreen') isWideScreen: boolean = false;

  scroller: Scroller = new Scroller();

  @State taskList: Array<TaskUIModel> = [];
  @State semanticSnapshot: SemanticSnapshot = SemanticSnapshot.empty(SemanticPageKind.TASKS);
  @State isRefreshing: boolean = false; // 控制下拉刷新状态

  @State isLoading: boolean = true;
  @Prop topAvoidHeight: number = 0;
  @Prop @Watch('onCategoryFilterChange') categoryFilter: CategoryFilter = CategoryFilter.all();
  @Prop showSearchEntry: boolean = false;
  onSearchClick: () => void = () => {};

  // 多选模式
  @Link isSelectionMode: boolean;
  @Require controller: TaskListController = new TaskListController();
  @State selectedIds: number[] = [];

  @Prop confetti: ConfettiController;
  onSemanticSnapshotChanged: (snapshot: SemanticSnapshot) => void = (_snapshot: SemanticSnapshot): void => {};

  @State isDetailSheetShow: boolean = false;
  @State detailTask: DDLItem | null = null;
  @State isEditSheetShow: boolean = false;
  @State editingTask: DDLItem | null = null;
  @State private focusedTask: DDLItem | null = null;
  @State private isFocusTimerShow: boolean = false;

  private repo = TaskRepository.getInstance();
  private categoryRepository: CategoryRepository = CategoryRepository.getInstance();

  @StorageLink(C.KEY_PROGRESS_DIRECTION) @Watch('loadData') progressDir: boolean = false;

  onCategoryFilterChange(): void {
    void this.loadData();
  }

  aboutToAppear(): void {
    this.bindController();

    // 监听同步完成事件，自动刷新
    getContext(this).eventHub.on('sync_done', () => {
      AppLog.info('Native', '[Event] Received sync_done event, reloading...');
      void this.loadData();
    });

    // Render the section immediately. The KMP read is coalesced in TaskRepository and runs after
    // ArkUI has received the first frame instead of serializing lifecycle startup behind it.
    void this.loadData();
    void this.runStartupMaintenance();
  }

  aboutToDisappear(): void {
    getContext(this).eventHub.off('sync_done');
  }

  private async runStartupMaintenance(): Promise<void> {
    try {
      await this.repo.checkAndAutoArchive();
      await this.loadData();
    } catch (error) {
      AppLog.error('Native', '[TaskList] Startup maintenance failed: ' + String(error));
    }
  }

  // 绑定逻辑到 Controller
  private bindController() {
    this.controller.requestBatchComplete = (): Promise<void> => this.handleBatchComplete();
    this.controller.requestBatchArchive = (): Promise<void> => this.handleBatchArchive();
    this.controller.requestBatchDelete = (): void => { this.handleBatchDelete(); };
    this.controller.requestBatchEdit = (): Promise<void> => this.handleBatchEdit();
    this.controller.requestExitSelection = (): void => this.exitSelectionMode();
    this.controller.loadData = (): Promise<void> => this.loadData();
  }

  @State isFirstLoad: boolean = true;

  // 加载数据：过滤 + 排序 + 映射
  async loadData() {
    try {
      this.isLoading = true;

      const dbItems = await this.repo.getMainListDDLsByType(DeadlineType.TASK);
      const categories: CategoryDisplayModel[] = await this.categoryRepository.listCategories();

      const now = new Date().getTime();

      const visibleItems: DDLItem[] = dbItems
        .filter((item) => !item.deleted && item.type !== DeadlineType.HABIT && this.matchesCategoryFilter(item.categoryUid, categories))
        .sort((lhs, rhs) => this.compareTaskOrder(lhs, rhs));

      const snapshot: SemanticSnapshot = PageToneResolver.resolveTasks(visibleItems, now);
      this.semanticSnapshot = snapshot;
      this.onSemanticSnapshotChanged(snapshot);
      this.taskList = visibleItems.map((item: DDLItem): TaskUIModel => {
        return this.mapToUI(item, now, categories, snapshot.statusForTask(item.id));
      });

      AppLog.info('Native', `[TaskList] Loaded ${this.taskList.length} items.`);
    } catch (e) {
      AppLog.error('Native', `[TaskList] Load data failed: ${e}`);
    } finally {
      // 无论成功失败，都要关闭刷新动画
      this.isRefreshing = false;
      this.isLoading = false;

      if (this.isFirstLoad) {
        setTimeout(() => {
          this.isFirstLoad = false;
        }, 750)
      }
    }
  }

  private compareTaskOrder(lhs: DDLItem, rhs: DDLItem): number {
    const isLAbandoned = lhs.state === TaskState.ABANDONED;
    const isRAbandoned = rhs.state === TaskState.ABANDONED;
    if (isLAbandoned !== isRAbandoned) {
      return isLAbandoned ? 1 : -1;
    }

    if (lhs.isCompleted !== rhs.isCompleted) {
      return lhs.isCompleted ? 1 : -1;
    }
    if (lhs.isStared !== rhs.isStared) {
      return lhs.isStared ? -1 : 1;
    }

    const remainingDiff = this.parseTaskSortTime(lhs.endTime) - this.parseTaskSortTime(rhs.endTime);
    if (remainingDiff !== 0) {
      return remainingDiff;
    }

    return lhs.id - rhs.id;
  }

  private matchesCategoryFilter(categoryUid: string | null | undefined, categories: CategoryDisplayModel[]): boolean {
    return CategoryFilterResolver.matches(this.categoryFilter, categoryUid, categories);
  }

  private categoryForUid(uid: string | null | undefined, categories: CategoryDisplayModel[]): CategoryDisplayModel | null {
    if (uid === null || uid === undefined) return null;
    for (let index = 0; index < categories.length; index++) {
      if (categories[index].uid === uid) return categories[index];
    }
    return null;
  }

  private parseTaskSortTime(time: string): number {
    const parsed = new Date(time).getTime();
    return isNaN(parsed) ? Number.MAX_SAFE_INTEGER : parsed;
  }

  // 核心逻辑：数据映射 (DB Model -> UI Model)
  private mapToUI(
    item: DDLItem,
    now: number,
    categories: CategoryDisplayModel[],
    semanticStatus: DeadlineSemanticStatus
  ): TaskUIModel {
    // 简单的日期解析容错
    const parseDate = (str: string): number => {
      const d = new Date(str);
      return isNaN(d.getTime()) ? 0 : d.getTime();
    };

    const end = parseDate(item.endTime);

    const status: DDLStatus = DeadlineStatusResolver.toDDLStatus(semanticStatus);
    const progress: number = DeadlineStatusResolver.resolveProgress(item, now);

    // 3. 计算剩余时间文本
    let timeText = "";
    if (semanticStatus === DeadlineSemanticStatus.COMPLETED) {
      timeText = "已完成";
    } else if (semanticStatus === DeadlineSemanticStatus.ABANDONED) {
      timeText = "已放弃";
    } else if (end <= 0) {
      timeText = "进行中";
    } else {
      const diffMs = end - now;
      if (diffMs < 0) {
        timeText = "已逾期 " + Math.abs(Math.floor(diffMs / (1000 * 60 * 60))) + " 小时";
      } else {
        const days = Math.floor(diffMs / (1000 * 60 * 60 * 24));
        const hours = Math.floor((diffMs % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
        if (days > 0) {
          timeText = `${days}天 ${hours}小时`;
        } else {
          timeText = `${hours}小时`;
        }
      }
    }

    const displayProgress = this.progressDir ? progress : 1.0 - progress
    const category: CategoryDisplayModel | null = this.categoryForUid(item.categoryUid, categories);

    return {
      title: item.name,
      remainingTimeAlt: timeText,
      note: item.note || "",
      progress: displayProgress,
      isStarred: item.isStared,
      status: status,
      dbId: item.id,
      taskState: item.state,
      categoryUid: item.categoryUid ?? null,
      categoryName: category === null ? '' : category.name,
      categoryIconKey: category === null ? '' : category.iconKey,
      categoryColorHex: category === null ? '' : category.colorHex
    };
  }

  private async performTaskAction(dbId: number, action: TaskStateAction, successMessage: string, fireConfetti: boolean = false) {
    VibrationUtils.vibrateShort();

    try {
      await this.repo.transitionDDL(dbId, action);
      if (fireConfetti) {
        this.confetti.fire();
      }
      await this.loadData();
      Toast.show({ message: successMessage });
    } catch (e) {
      if (String(e).includes('操作已取消')) return;
      AppLog.error('Native', `Task action failed: ${e}`);
      Toast.show({ message: '操作失败' });
    }
  }

  private handleStateAction(dbId: number, state: TaskState) {
    if (state === TaskState.ACTIVE) {
      this.performTaskAction(dbId, TaskStateAction.MARK_COMPLETE, '任务已完成', true);
      return;
    }
    if (state === TaskState.COMPLETED || state === TaskState.ABANDONED) {
      this.performTaskAction(dbId, TaskStateAction.RESTORE_ACTIVE, '任务已恢复');
      return;
    }
  }

  private handleSecondaryAction(dbId: number, title: string, state: TaskState) {
    if (state === TaskState.ACTIVE) {
      this.confirmGiveUp(dbId, title);
      return;
    }
    if (state === TaskState.COMPLETED || state === TaskState.ABANDONED) {
      this.performTaskAction(dbId, TaskStateAction.MARK_ARCHIVE, '任务已归档');
    }
  }

  private confirmGiveUp(dbId: number, title: string) {
    AlertDialog.show(DialogCompat.withAlertBlurStyle({
      title: '放弃确认',
      message: `确定要放弃任务“${title}”吗？`,
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      offset: { dx: 0, dy: -20 },
      primaryButton: {
        value: '取消',
        fontColor: this.theme.brand,
        action: () => {}
      },
      secondaryButton: {
        value: '放弃',
        fontColor: $r('app.color.warning'),
        action: async () => {
          await this.performTaskAction(dbId, TaskStateAction.MARK_GIVE_UP, '任务已放弃');
        }
      }
    }, BlurStyle.Thick));
  }

  private handleDelete(dbId: number, title: string) {
    VibrationUtils.vibrateMedium();

    // 弹出确认框
    AlertDialog.show(DialogCompat.withAlertBlurStyle({
      title: '删除确认',
      message: `确定要删除任务 "${title}" 吗？`,
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      offset: { dx: 0, dy: -20 },
      primaryButton: {
        value: '取消',
        action: () => {
          this.loadData();
        },
        fontColor: this.theme.brand
      },
      secondaryButton: {
        value: '删除',
        fontColor: $r('app.color.warning'),
        action: async () => {
          try {
            await this.repo.deleteDDL(dbId);
            await this.loadData();
            Toast.show({ message: $r('app.string.toast_deletion') });
          } catch (e) {
            AppLog.error('Native', `Delete failed: ${e}`);
            Toast.show({ message: '删除失败' });
          }
        }
      }
    }, BlurStyle.Thick))
  }

  // 进入多选模式
  private enterSelectionMode(firstId: number) {
    VibrationUtils.vibrateShort();
    this.isSelectionMode = true;
    this.selectedIds = [firstId];
  }

  // 退出多选模式
  private exitSelectionMode() {
    this.isSelectionMode = false;
    this.selectedIds = [];
  }

  // 切换单个选中状态
  private toggleSelection(dbId: number) {
    const index = this.selectedIds.indexOf(dbId);
    if (index >= 0) {
      // 已选中 -> 移除
      this.selectedIds.splice(index, 1);
      // 如果一个都没选了，是否自动退出？通常为了体验保留模式，直到点X
      if (this.selectedIds.length === 0) {
        // 可选：this.exitSelectionMode();
      }
    } else {
      // 未选中 -> 添加
      this.selectedIds.push(dbId);
    }
    // 触发 UI 更新（如果是简单的数组 push 可能需要重新赋值引用）
    this.selectedIds = [...this.selectedIds];

    if (this.selectedIds.length === 0) {
      this.exitSelectionMode();
    }
  }

  private async handleBatchComplete() {
    if (this.selectedIds.length === 0) return;

    VibrationUtils.vibrateShort();
    try {
      const allItems = await this.repo.getAllDDLs();
      // 找到所有选中的项目
      const targets = allItems.filter(item => this.selectedIds.includes(item.id));
      const completable = targets.filter(item => item.state === TaskState.ACTIVE);
      const skippedCount = targets.length - completable.length;

      for (const item of completable) {
        await this.repo.transitionDDL(item.id, TaskStateAction.MARK_COMPLETE);
      }

      let message = `已完成 ${completable.length} 项任务`;
      if (skippedCount > 0) {
        message += `，${skippedCount} 项当前状态无法完成`;
      }
      Toast.show({ message: message });
      this.exitSelectionMode();
      await this.loadData();
    } catch (e) {
      AppLog.error('Native', 'Batch complete failed:', e);
    }
  }

  private async handleBatchArchive() {
    if (this.selectedIds.length === 0) return;

    try {
      const allItems = await this.repo.getAllDDLs();
      const targets = allItems.filter(item => this.selectedIds.includes(item.id));

      const itemsToArchive: DDLItem[] = [];
      let skippedCount = 0;

      targets.forEach(item => {
        if (item.state === TaskState.COMPLETED || item.state === TaskState.ABANDONED) {
          itemsToArchive.push(item);
        } else {
          skippedCount++;
        }
      });

      const updatePromises = itemsToArchive.map(item => this.repo.transitionDDL(item.id, TaskStateAction.MARK_ARCHIVE));
      await Promise.all(updatePromises);

      let message = `已归档 ${itemsToArchive.length} 项任务`;

      if (skippedCount > 0) {
        message += `，${skippedCount} 项当前状态无法归档`;
      }

      Toast.show({ message: message });

      this.exitSelectionMode();
      await this.loadData();
    } catch (e) {
      AppLog.error('Native', 'Batch archive failed:', e);
      Toast.show({ message: '批量归档失败' });
    }
  }

  private async handleBatchDelete() {
    if (this.selectedIds.length === 0) return;

    VibrationUtils.vibrateMedium();
    AlertDialog.show(DialogCompat.withAlertBlurStyle({
      title: '批量删除',
      message: `确定要删除选中的 ${this.selectedIds.length} 个任务吗？此操作不可恢复。`,
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      offset: { dx: 0, dy: -20 },
      primaryButton: {
        value: '取消',
        fontColor: this.theme.brand,
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: $r('app.color.warning'),
        action: async () => {
          try {
            for (const id of this.selectedIds) {
              await this.repo.deleteDDL(id);
            }
            Toast.show({ message: '删除成功' });
            this.exitSelectionMode();
            await this.loadData();
          } catch (e) {
            AppLog.error('Native', 'Batch delete failed:', e);
          }
        }
      }
    }, BlurStyle.Regular));
  }

  private async openTaskDetail(taskId: number) {
    try {
      const task = await this.repo.getDDLById(taskId);
      if (!task) {
        Toast.show({ message: '找不到该任务' });
        return;
      }
      this.detailTask = task;
      this.isDetailSheetShow = true;
    } catch (e) {
      AppLog.error('Native', 'Open detail failed:', e);
      Toast.show({ message: '无法打开任务详情' });
    }
  }

  private async openTaskEdit(taskId: number): Promise<void> {
    try {
      const task = await this.repo.getDDLById(taskId);
      if (!task) {
        Toast.show({ message: '找不到该任务' });
        return;
      }
      this.editingTask = task;
      this.isEditSheetShow = true;
    } catch (e) {
      AppLog.error('Native', 'Open task edit failed:', e);
      Toast.show({ message: '无法打开任务编辑' });
    }
  }

  private async handleBatchEdit(): Promise<void> {
    if (this.selectedIds.length !== 1) {
      Toast.show({ message: '请选择一个任务进行编辑' });
      return;
    }

    try {
      const targetId = this.selectedIds[0];
      const task = await this.repo.getDDLById(targetId);
      if (!task) {
        Toast.show({ message: '找不到该任务' });
        return;
      }

      this.editingTask = task;
      this.exitSelectionMode();
      this.isEditSheetShow = true;
    } catch (e) {
      AppLog.error('Native', 'Open task edit failed:', e);
      Toast.show({ message: '无法打开任务编辑' });
    }
  }

  private async openTaskFocus(taskId: number): Promise<void> {
    const task: DDLItem | null = await this.repo.getDDLById(taskId);
    if (task === null || task.state !== TaskState.ACTIVE) return;
    this.focusedTask = task;
    this.isFocusTimerShow = true;
  }
  @Builder private focusSheet() { FocusTimerSheet({ isShow: $isFocusTimerShow, initialTask: this.focusedTask }) }

  @Builder
  taskDetailSheet() {
    TaskDetailSheet({
      isShow: $isDetailSheetShow,
      task: this.detailTask,
      onTaskChanged: async (): Promise<void> => {
        await this.loadData();
      }
    })
  }

  @Builder
  taskEditSheet() {
    TaskEditSheet({
      isShow: $isEditSheetShow,
      editingTask: this.editingTask,
      onSave: async (task: DDLItem): Promise<void> => {
        await this.repo.updateDDL(task);
        await this.loadData();
      }
    })
  }

  @Builder
  EmptyPlaceholder() {
    Column() {
      SymbolGlyph($r('sys.symbol.cup'))
        .fontSize(80)
        .fontColor([$r('app.color.font_secondary')])
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        .opacity(0.5)

      Text("暂无待办任务")
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.font_secondary'))
        .margin({ top: 16 })

      Text("享受美好的一天吧")
        .fontSize(14)
        .fontColor($r('app.color.font_secondary'))
        .opacity(0.6)
        .margin({ top: 8 })
    }
    .width('100%')
    // 这里的 height 设为 100% 会撑满 List 的可视区域
    // 减去一点顶部距离，视觉上更居中
    .height('80%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      if (this.isLoading && this.taskList.length === 0) {
        LoadingProgress()
          .width(50)
          .height(50)
          .margin({ top: 100 })
      } else {
        Column() {
          Refresh({ refreshing: $$this.isRefreshing }) {
            List({
              space: 8,
              scroller: this.scroller,
            }) {
              ListItem() {
                Column().height(this.topAvoidHeight).width('100%')
              }

              if (this.showSearchEntry) {
                ListItem() {
                  Column() {
                    ImmersiveMaterialScope({ scopeHeight: 32 }) {
                      Search({ value: '', placeholder: '搜索任务' })
                        .width('98%')
                        .height(40)
                        .focusable(false)
                        .enableKeyboardOnFocus(false)
                        .backgroundColor(Color.Transparent)
                        .placeholderColor($r('sys.color.ohos_id_color_text_secondary'))
                        .attributeModifier(MaterialPresets.buttonGlow())
                        .onClick(() => {
                          this.onSearchClick();
                        })
                        .margin({ bottom: 0, top: -8 })
                    }
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Center)
                }
              }
              if (this.taskList.length > 0) {
                  ForEach(this.taskList, (item: TaskUIModel, index: number) => {
                    ListItem() {
                      DDLItemCardSwipeable({
                        title: item.title,
                        remainingTimeAlt: item.remainingTimeAlt,
                        note: item.note,
                        progress: item.progress,
                        isStarred: item.isStarred,
                        status: item.status,
                        categoryName: item.categoryName,
                        categoryIconKey: item.categoryIconKey,
                        categoryColorHex: item.categoryColorHex,
                        swipeId: item.dbId,

                        selectionMode: this.isSelectionMode,
                        selected: this.selectedIds.includes(item.dbId),
                        primaryActionSymbol: item.taskState === TaskState.ACTIVE
                          ? $r('sys.symbol.checkmark_circle')
                          : $r('sys.symbol.arrowshape_turn_up_left'),
                        secondaryActionSymbol: item.taskState === TaskState.ACTIVE
                          ? $r('sys.symbol.flag')
                          : $r('sys.symbol.archivebox'),
                        secondaryActionColor: item.taskState === TaskState.ACTIVE
                          ? $r('app.color.chart_yellow')
                          : $r('app.color.chart_red'),
                        onPrimaryAction: async () => {
                          this.handleStateAction(item.dbId, item.taskState)
                        },
                        onSecondaryAction: async () => {
                          this.handleSecondaryAction(item.dbId, item.title, item.taskState)
                        },
                        onFocusAction: item.taskState === TaskState.ACTIVE ? (): void => { this.openTaskFocus(item.dbId); } : undefined,
                        onEditAction: () => {
                          void this.openTaskEdit(item.dbId);
                        },
                        onDeleteAction: () => {
                          this.handleDelete(item.dbId, item.title);
                        },
                        onClickItem: () => {
                          this.openTaskDetail(item.dbId);
                        },

                        onLongPressSelect: () => {
                          if (!this.isSelectionMode) {
                            this.enterSelectionMode(item.dbId);
                          }
                        },
                        onToggleSelect: () => {
                          this.toggleSelection(item.dbId);
                        }
                      })
                        .attributeModifier(new PressEffectModifier(0.98))
                        .animation({
                          curve: curves.responsiveSpringMotion(0.35, 0.60)
                        })
                    }
                    .attributeModifier(new FloatUpModifier(index, 15, this.isFirstLoad))
                  }, (item: TaskUIModel) => `${item.dbId}_${item.status}_${item.progress}`)

                  ListItem() {
                    Divider().color(Color.Transparent).height(80).width('100%')
                  }
                } else {
                  ListItem() {
                    this.EmptyPlaceholder()
                  }
                  .width('100%')
                  .height(this.isWideScreen ? '100%' : '60%')
                  .attributeModifier(new FloatUpModifier(2, 15))
                }
              }
              .onScroll((scrollOffset: number, scrollState: ScrollState) => {
                this.controller.onScroll(this.scroller.currentOffset().yOffset);
              })
              .onScrollStop(() => {
                this.controller.onScroll(this.scroller.currentOffset().yOffset);
              })
              .width("100%")
              .height("100%") // 撑满 TopSafeContainer 的剩余空间
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
              .nestedScroll({
                scrollForward: NestedScrollMode.PARENT_FIRST,
                scrollBackward: NestedScrollMode.PARENT_FIRST
              })
              .padding({
                start: LengthMetrics.vp(12), end: LengthMetrics.vp(12)
              })
              .cachedCount(6, true)
              .clip(false)
            }
            .onRefreshing(async () => {
              this.isRefreshing = true
              try {
                await this.repo.syncNow();
              } catch (e) {
                AppLog.error('Native', 'Manual sync failed');
              }
              await this.loadData();
              WidgetRefreshBridge.requestKmpUpdate(WidgetUpdateReason.USER_REFRESH);
              this.isRefreshing = false;
            })
            .clip(false)
          }
      }

      Blank()
        .width(0)
        .height(0)
        .bindSheet($$this.isEditSheetShow, this.taskEditSheet(), SheetCompat.immersive({
          height: SheetSize.FIT_CONTENT,
          dragBar: true,
          onDisappear: (): void => {
            this.isEditSheetShow = false;
            this.editingTask = null;
          },
          title: {
            title: '编辑任务',
            subtitle: '修改任务信息。'
          }
        }))
    }
    .width("100%")
    .height("100%")
    .bindSheet($$this.isDetailSheetShow, this.taskDetailSheet(), SheetCompat.immersive({
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      onDisappear: () => {
        this.isDetailSheetShow = false;
        this.detailTask = null;
      },
      showClose: false
    }))
    .bindSheet($$this.isFocusTimerShow, this.focusSheet(), SheetCompat.immersive({
      height: SheetSize.LARGE, enableOutsideInteractive: false, showClose: true, dragBar: true,
      onDisappear: (): void => { this.isFocusTimerShow = false; this.focusedTask = null; this.loadData(); }
    }))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM, SafeAreaEdge.TOP])
  }
}
