import { promptAction, SegmentButton, SegmentButtonOptions, SegmentButtonItemTuple, ItemRestriction,
  SegmentButtonTextItem } from '@kit.ArkUI';
import { TaskRepository } from '../../common/repository/TaskRepository';
import { HabitRepository } from '../../common/repository/HabitRepository';
import { DDLItem, Habit, HabitPeriod, HabitGoalType } from '../../model/DDLModels';
import { ArchivedDDLItemCard } from '../components/TaskItemCard';
import { ITheme } from '../../common/theme/ThemeModel';
import { TaskStateAction, TaskStateMachine } from '../../model/TaskStateMachine';

@Component
export struct ArchivePanelView {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  // [修改点 1] 添加 @Watch 监听器，一旦选中项改变，自动触发 onTabChange
  @State @Watch('onTabChange') selectedIndexes: number[] = [0];

  // 分段按钮的配置选项
  @State tabOptions: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [{ text: '任务' }, { text: '习惯' }] as ItemRestriction<SegmentButtonTextItem>,
    backgroundBlurStyle: BlurStyle.NONE,
    selectedBackgroundColor: $r('sys.color.segment_button_v2_tab_selected_item_background'),
    buttonPadding: 8
  })

  @State archivedTasks: DDLItem[] = [];
  @State archivedHabits: Habit[] = [];
  @State isLoading: boolean = true;

  private taskRepo = TaskRepository.getInstance();
  private habitRepo = HabitRepository.getInstance();

  aboutToAppear() {
    this.refreshData();
  }

  // [修改点 2] 监听器回调方法
  onTabChange() {
    // 确保有选中项才刷新（防止异常情况）
    if (this.selectedIndexes.length > 0) {
      this.refreshData();
    }
  }

  async refreshData() {
    this.isLoading = true;
    try {
      if (this.selectedIndexes[0] === 0) {
        this.archivedTasks = await this.taskRepo.getArchivedDDLs();
      } else {
        this.archivedHabits = await this.habitRepo.getArchivedHabits();
      }

    } catch (e) {
      console.error(`[ArchivePanel] Load failed: ${e}`);
    } finally {
      this.isLoading = false;
    }
  }

  async handleDeleteTask(item: DDLItem) {
    this.showDeleteDialog('任务', item.name, async () => {
      await this.taskRepo.deleteDDL(item.id);
      const index = this.archivedTasks.indexOf(item);
      if (index !== -1) this.archivedTasks.splice(index, 1);
    });
  }

  async handleRestoreTask(item: DDLItem) {
    try {
      await this.taskRepo.transitionDDL(item.id, TaskStateAction.UNARCHIVE);
      await this.refreshData();
      promptAction.showToast({ message: '已恢复到主列表' });
    } catch (e) {
      console.error(`Restore task failed: ${e}`);
      promptAction.showToast({ message: '恢复失败' });
    }
  }

  async handleDeleteHabit(item: Habit) {
    this.showDeleteDialog('习惯', item.name, async () => {
      // [关键] 使用 HabitListSection 中的删除 API
      await this.habitRepo.deleteHabitByDdlId(item.ddlId);
      const index = this.archivedHabits.indexOf(item);
      if (index !== -1) this.archivedHabits.splice(index, 1);
    });
  }

  async handleRestoreHabit(item: Habit) {
    try {
      await this.habitRepo.unarchiveHabit(item.id);
      await this.refreshData();
      promptAction.showToast({ message: '习惯已恢复到主列表' });
    } catch (e) {
      console.error(`Restore habit failed: ${e}`);
      promptAction.showToast({ message: '恢复失败' });
    }
  }

  // 抽离通用的删除弹窗逻辑
  showDeleteDialog(type: string, name: string, deleteAction: () => Promise<void>) {
    AlertDialog.show({
      title: '永久删除',
      message: `确定要永久删除${type}“${name}”吗？此操作不可恢复。`,
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      offset: { dx: 0, dy: -20 }, // 微调位置
      gridCount: 4, // 弹窗宽度占用栅格数
      backgroundBlurStyle: BlurStyle.Regular,
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
            await deleteAction();
            promptAction.showToast({ message: '已删除' });
          } catch (e) {
            console.error(`Delete failed: ${e}`);
            promptAction.showToast({ message: '删除失败' });
          }
        }
      }
    });
  }

  private formatDate(dateStr?: string): string {
    if (!dateStr) return '未知时间';
    try {
      const date = new Date(dateStr);
      const month = (date.getMonth() + 1).toString().padStart(2, '0');
      const day = date.getDate().toString().padStart(2, '0');
      const hour = date.getHours().toString().padStart(2, '0');
      const minute = date.getMinutes().toString().padStart(2, '0');
      return `${month}-${day} ${hour}:${minute}`;
    } catch (e) {
      return dateStr;
    }
  }

  // [新增] 格式化习惯的描述信息
  private formatHabitDetail(habit: Habit): string {
    let periodStr = '';
    switch (habit.period) {
      case HabitPeriod.DAILY: periodStr = '每日'; break;
      case HabitPeriod.WEEKLY: periodStr = '每周'; break;
      case HabitPeriod.MONTHLY: periodStr = '每月'; break;
    }

    let goalStr = '';
    if (habit.goalType === HabitGoalType.TOTAL) {
      goalStr = `总目标 ${habit.totalTarget}`;
    } else {
      goalStr = `${habit.timesPerPeriod}次`;
    }

    return `${periodStr} · ${goalStr}`;
  }

  @Builder EmptyView(text: string) {
    Column({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.archivebox'))
        .fontSize(64)
        .fontColor([$r('sys.color.ohos_id_color_text_tertiary')])

      Text(text)
        .fontSize(16)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
    }
    // [修改点 1] 不要写 height('100%')，改用 layoutWeight(1)
    // 这样它只会占据“按钮下方”的剩余空间，绝不会覆盖到按钮上面
    .layoutWeight(1)
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ bottom: 48 })
  }

  build() {
    Column() {
      // 顶部 SegmentButton
      Column() {
        SegmentButton({
          options: this.tabOptions,
          selectedIndexes: $selectedIndexes // 这里使用了双向绑定，配合 @Watch 即可
        })
          .width('80%')
          .margin({ top: 12, bottom: 12 })
      }

      if (this.isLoading) {
        Column() {
          LoadingProgress().width(48).height(48)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        // 这里会自动根据 @State 的 selectedIndexes 更新视图
        if (this.selectedIndexes[0] === 0) {
          // ================== 任务列表 ==================
          if (this.archivedTasks.length === 0) {
            this.EmptyView("没有归档的任务")
          } else {
            List({ space: 12 }) {
              ForEach(this.archivedTasks, (item: DDLItem) => {
                ListItem() {
                  ArchivedDDLItemCard({
                    title: item.name,
                    startTime: this.formatDate(item.startTime),
                    completeTime: this.formatDate(item.completeTime),
                    note: item.note,
                    badgeText: TaskStateMachine.archiveBadgeText(item.state),
                    showRestore: true,
                    onRestore: () => {
                      this.handleRestoreTask(item);
                    },
                    onDelete: () => {
                      this.handleDeleteTask(item);
                    }
                  })
                }
              }, (item: DDLItem) => item.id.toString())

              ListItem() {
                Column() { Blank() }.height(70)
              }
            }
            .width('100%')
            .layoutWeight(1)
            .padding({ left: 16, right: 16 })
            .scrollBar(BarState.Auto)
          }
        } else {
          // ================== 习惯列表 ==================
          if (this.archivedHabits.length === 0) {
            this.EmptyView("没有归档的习惯")
          } else {
            List({ space: 12 }) {
              ForEach(this.archivedHabits, (item: Habit) => {
                ListItem() {
                  ArchivedDDLItemCard({
                    title: item.name,
                    startTime: this.formatHabitDetail(item),
                    completeTime: `归档于 ${this.formatDate(item.updatedAt)}`,
                    note: item.description || "无备注",
                    badgeText: '习惯归档',
                    showRestore: true,
                    onRestore: () => {
                      this.handleRestoreHabit(item);
                    },
                    onDelete: () => {
                      this.handleDeleteHabit(item);
                    }
                  })
                }
              }, (item: Habit) => item.id.toString())

              ListItem() {
                Column() { Blank() }.height(70)
              }
            }
            .width('100%')
            .layoutWeight(1)
            .padding({ left: 16, right: 16 })
            .scrollBar(BarState.Auto)
          }
        }
      }
    }
    .width('100%')
    .height('100%')
  }
}
