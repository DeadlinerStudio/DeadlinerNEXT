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
import { PressEffectModifier } from "../../../utils/animation/PressModifier";
import { ITheme } from "../../../common/theme/ThemeModel";
import { TaskState, TaskStateAction } from "../../../model/TaskStateMachine";

export interface TaskUIModel {
  title: string;
  remainingTimeAlt: string;
  note: string;
  progress: number;
  isStarred: boolean;
  status: DDLStatus;
  dbId: number;
  taskState: TaskState;
}

@Component
export struct TaskListSection {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @StorageLink('isWideScreen') isWideScreen: boolean = false;

  scroller: Scroller = new Scroller();

  @State taskList: Array<TaskUIModel> = [];
  @State isRefreshing: boolean = false; // 控制下拉刷新状态

  @State isLoading: boolean = true;
  @Prop topAvoidHeight: number = 0;

  // 多选模式
  @Link isSelectionMode: boolean;
  @Require controller: TaskListController = new TaskListController();
  @State selectedIds: number[] = [];

  @Prop confetti: ConfettiController;

  @State isDetailSheetShow: boolean = false;
  @State detailTask: DDLItem | null = null;

  private repo = TaskRepository.getInstance();

  @StorageLink(C.KEY_PROGRESS_DIRECTION) @Watch('loadData') progressDir: boolean = false;

  async aboutToAppear() {
    this.bindController();

    await this.repo.checkAndAutoArchive();
    await this.loadData();
    // 监听同步完成事件，自动刷新
    getContext(this).eventHub.on('sync_done', () => {
      console.info('[Event] Received sync_done event, reloading...');
      this.loadData();
    });

    this.repo.syncNow().catch((e: Error) => console.error(e.message));
  }

  aboutToDisappear(): void {
    getContext(this).eventHub.off('sync_done');
  }

  // 绑定逻辑到 Controller
  private bindController() {
    this.controller.requestBatchComplete = (): Promise<void> => this.handleBatchComplete();
    this.controller.requestBatchArchive = (): Promise<void> => this.handleBatchArchive();
    this.controller.requestBatchDelete = (): void => this.handleBatchDelete();
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

      const now = new Date().getTime();

      this.taskList = dbItems
        .filter((item) => !item.deleted && item.type !== DeadlineType.HABIT)
        .sort((lhs, rhs) => this.compareTaskOrder(lhs, rhs))
        .map((item) => {
        return this.mapToUI(item, now);
      });

      console.info(`[TaskList] Loaded ${this.taskList.length} items.`);
    } catch (e) {
      console.error(`[TaskList] Load data failed: ${e}`);
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

  private parseTaskSortTime(time: string): number {
    const parsed = new Date(time).getTime();
    return isNaN(parsed) ? Number.MAX_SAFE_INTEGER : parsed;
  }

  // 核心逻辑：数据映射 (DB Model -> UI Model)
  private mapToUI(item: DDLItem, now: number): TaskUIModel {
    // 简单的日期解析容错
    const parseDate = (str: string): number => {
      const d = new Date(str);
      return isNaN(d.getTime()) ? 0 : d.getTime();
    };

    const start = parseDate(item.startTime);
    const end = parseDate(item.endTime);

    // 1. 计算状态
    let status = DDLStatus.UNDERGO;
    if (item.state === TaskState.COMPLETED || item.state === TaskState.ARCHIVED) {
      status = DDLStatus.COMPLETED;
    } else if (item.state === TaskState.ABANDONED || item.state === TaskState.ABANDONED_ARCHIVED) {
      status = DDLStatus.ABANDONED;
    } else if (now > end) {
      status = DDLStatus.PASSED;
    } else if ((end - now) < 24 * 60 * 60 * 1000) {
      status = DDLStatus.NEAR;
    } else {
      status = DDLStatus.UNDERGO;
    }

    // 2. 计算进度
    let progress = 0.0;
    if (item.state === TaskState.COMPLETED || item.state === TaskState.ARCHIVED) {
      progress = 1.0;
    } else if (item.state === TaskState.ABANDONED || item.state === TaskState.ABANDONED_ARCHIVED) {
      progress = 0;
    } else {
      const totalDuration = end - start;
      const elapsed = now - start;
      if (totalDuration > 0) {
        progress = Math.max(0, Math.min(1, elapsed / totalDuration));
      } else {
        progress = 0;
      }
    }

    // 3. 计算剩余时间文本
    let timeText = "";
    if (item.state === TaskState.COMPLETED || item.state === TaskState.ARCHIVED) {
      timeText = "已完成";
    } else if (item.state === TaskState.ABANDONED || item.state === TaskState.ABANDONED_ARCHIVED) {
      timeText = "已放弃";
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

    return {
      title: item.name,
      remainingTimeAlt: timeText,
      note: item.note || "",
      progress: displayProgress,
      isStarred: item.isStared,
      status: status,
      dbId: item.id,
      taskState: item.state
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
      promptAction.showToast({ message: successMessage });
    } catch (e) {
      console.error(`Task action failed: ${e}`);
      promptAction.showToast({ message: '操作失败' });
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
    AlertDialog.show({
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
      },
      backgroundBlurStyle: BlurStyle.Thick
    });
  }

  private handleDelete(dbId: number, title: string) {
    VibrationUtils.vibrateMedium();

    // 弹出确认框
    AlertDialog.show({
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
            promptAction.showToast({ message: $r('app.string.toast_deletion') });
          } catch (e) {
            console.error(`Delete failed: ${e}`);
            promptAction.showToast({ message: '删除失败' });
          }
        }
      },
      backgroundBlurStyle: BlurStyle.Thick
    })
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
      promptAction.showToast({ message: message });
      this.exitSelectionMode();
      await this.loadData();
    } catch (e) {
      console.error('Batch complete failed:', e);
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

      promptAction.showToast({ message: message });

      this.exitSelectionMode();
      await this.loadData();
    } catch (e) {
      console.error('Batch archive failed:', e);
      promptAction.showToast({ message: '批量归档失败' });
    }
  }

  private handleBatchDelete() {
    if (this.selectedIds.length === 0) return;

    VibrationUtils.vibrateMedium();
    AlertDialog.show({
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
            promptAction.showToast({ message: '删除成功' });
            this.exitSelectionMode();
            await this.loadData();
          } catch (e) {
            console.error('Batch delete failed:', e);
          }
        }
      },
      backgroundBlurStyle: BlurStyle.Regular
    });
  }

  private async openTaskDetail(taskId: number) {
    try {
      const task = await this.repo.getDDLById(taskId);
      if (!task) {
        promptAction.showToast({ message: '找不到该任务' });
        return;
      }
      this.detailTask = task;
      this.isDetailSheetShow = true;
    } catch (e) {
      console.error('Open detail failed:', e);
      promptAction.showToast({ message: '无法打开任务详情' });
    }
  }

  private async handleBatchEdit() {
    if (this.selectedIds.length === 0) {
      promptAction.showToast({ message: '未选中任何任务' });
      return;
    }
    const targetId = this.selectedIds[0];
    await this.openTaskDetail(targetId);
    this.exitSelectionMode();
  }

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
        TopSafeContainer({ topAvoidHeight: this.topAvoidHeight, needBgTransparent: true }) {
          Column() {
            Refresh({ refreshing: $$this.isRefreshing }) {
              List({
                space: 8,
                scroller: this.scroller,
              }) {
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
              .clip(false)
            }
            .onRefreshing(async () => {
              this.isRefreshing = true
              try {
                await this.repo.syncNow();
              } catch (e) {
                console.error('Manual sync failed');
              }
              await this.loadData();
              this.isRefreshing = false;
            })
            .clip(false)
          }
        }
      }
    }
    .width("100%")
    .height("100%")
    .bindSheet($$this.isDetailSheetShow, this.taskDetailSheet(), {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      onDisappear: () => {
        this.isDetailSheetShow = false;
        this.detailTask = null;
      },
      showClose: false,
      blurStyle: BlurStyle.Regular,
      backgroundColor: Color.Transparent
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM, SafeAreaEdge.TOP])
  }
}
