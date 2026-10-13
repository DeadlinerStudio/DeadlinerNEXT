import { HabitSwipeActions } from './HabitSwipeActions';
import { KmpFocusTimerRepository } from '../../../common/kmp/KmpFocusTimerRepository';
import { FocusTimerSheet } from '../focus/FocusTimerSheet';
import { AppLog } from '../../../common/logging/AppLog';
import { TopSafeContainer } from "../../components/TopSafeContainer"
import { HabitRepository } from '../../../common/repository/HabitRepository';
import { Habit, HabitStatus } from '../../../model/DDLModels';
import {
  HabitPresentationDay,
  HabitPresentationItem,
  HabitPresentationState
} from '../../../common/kmp/KmpHabitRepositoryAdapter';
import { WeekRow, HabitRow, HabitWithDailyStatus, DayOverview, HabitProgress } from '../../components/HabitComponents'
import { HabitListController } from "./HabitListController";
import { ChipGroup, ChipGroupItemOptions, ChipSize, curves, promptAction } from '@kit.ArkUI'
import { VibrationUtils } from "../../../utils/VibrationUtils";
import { ConfettiController } from "../../components/confetti/ConfettiController";
import { FloatUpModifier } from "../../../utils/animation/FloatUpModifier";
import { HabitEditSheet } from "./modify/habit/HabitEditSheet";
import { HabitReminderDialog } from "../../components/HabitReminderDialog";
import { PressEffectModifier } from "../../../utils/animation/PressModifier";
import { ITheme } from "../../../common/theme/ThemeModel";
import { DDLStatus } from "../../../model/DDLStatus"
import { DialogCompat } from "../../../common/ui/DialogCompat";
import { Toast } from '../../../common/ui/Toast';
import { CategoryFilter, CategoryFilterResolver } from '../../../common/category/CategoryFilter';
import { CategoryRepository } from '../../../common/repository/CategoryRepository';
import { CategoryDisplayModel } from '../../../common/kmp/KmpCategoryRepositoryAdapter';
import { SheetCompat } from '../../../common/ui/SheetCompat';
import { PageToneResolver } from '../../../common/semantic/PageToneResolver';
import {
  HabitSemanticInput,
  SemanticPageKind,
  SemanticSnapshot
} from '../../../common/semantic/SemanticContract';
import { WidgetRefreshBridge, WidgetUpdateReason } from '../../../utils/WidgetRefreshBridge';

@Component
export struct HabitListSection {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @Prop topAvoidHeight: number = 0;
  @Prop @Watch('onCategoryFilterChange') categoryFilter: CategoryFilter = CategoryFilter.all();

  scroller: ListScroller = new ListScroller();
  private openSwipeHabitId: number = -1;
  confetti: ConfettiController = new ConfettiController();
  controller: HabitListController = new HabitListController();

  @State private isFocusTimerShow: boolean = false;
  @State private focusedHabit: Habit | null = null;
  @StorageLink('FocusTimerRevision') @Watch('onFocusChanged') focusRevision: number = 0;
  private onFocusChanged(): void { this.refreshAll(this.selectedDate); }
  @Builder private focusSheet() { FocusTimerSheet({ isShow: $isFocusTimerShow, initialHabit: this.focusedHabit }) }

  @State selectedDate: Date = new Date();
  @State searchQuery: string = "";
  @State weekOverview: DayOverview[] = [];
  @State displayHabits: HabitWithDailyStatus[] = [];
  @State semanticSnapshot: SemanticSnapshot = SemanticSnapshot.empty(SemanticPageKind.HABITS);
  onSemanticSnapshotChanged: (snapshot: SemanticSnapshot) => void = (_snapshot: SemanticSnapshot): void => {};

  // 内存缓存
  private allHabitsCache: HabitWithDailyStatus[] = [];
  private togglingHabitIds: Set<number> = new Set();

  // 交互模式状态（对应 selectionMode）
  @Link @Watch('closeSwipeActions') isSelectionMode: boolean;
  @State selectedDdlIds: Set<number> = new Set();

  private repo = HabitRepository.getInstance();
  private categoryRepository: CategoryRepository = CategoryRepository.getInstance();

  @State tempHabitName: string = "";
  @State tempIsEnabled: boolean = false;
  @State tempSelectedTime: Date = new Date();
  @State currentAlarmDdlId: number = -1;

  // 定义 CustomDialogController
  alarmDialogController: CustomDialogController = new CustomDialogController({
    builder: HabitReminderDialog({
      habitName: this.tempHabitName,
      isEnabled: this.tempIsEnabled,
      selectedTime: this.tempSelectedTime,
      onConfirm: (enabled, timeStr): Promise<void> => this.saveAlarmSetting(enabled, timeStr)
    }),
    alignment: DialogAlignment.Center,
    offset: { dx: 0, dy: 0 },
    autoCancel: true,
    customStyle: true
  });

  // —— 2. 生命周期 ——
  aboutToAppear() {
    this.refreshAll(this.selectedDate);

    if (this.controller) {
      this.bindController();
    }

    getContext(this).eventHub.on('sync_done', this.onSyncEvent);
  }

  aboutToDisappear() {
    getContext(this).eventHub.off('sync_done', this.onSyncEvent);
  }

  private onSyncEvent = () => {
    AppLog.debug('Native', 'HabitListSection received sync_done event');
    this.refreshAll(this.selectedDate);
  }

  onCategoryFilterChange(): void {
    void this.refreshAll(this.selectedDate);
  }

  private bindController() {
    this.controller.requestBatchComplete = (): Promise<void> => this.handleBatchComplete();
    this.controller.requestBatchArchive = (): Promise<void> => this.handleBatchArchive();
    this.controller.requestBatchDelete = (): Promise<void> => this.handleBatchDelete();
    this.controller.requestBatchEdit = (): void => this.handleBatchEdit();
    this.controller.requestExitSelection = (): void => this.exitSelectionMode();
    this.controller.requestSetAlarm = (): Promise<void> => this.handleRequestSetAlarm();
    this.controller.loadData = (): Promise<void> => this.refreshAll(this.selectedDate);
  }

  async handleRequestSetAlarm() {
    if (this.selectedDdlIds.size !== 1) {
      Toast.show({ message: '请选择一个待办来设置提醒' });
      return;
    }

    const ddlId = Array.from(this.selectedDdlIds)[0];
    this.currentAlarmDdlId = ddlId;

    const item = this.allHabitsCache.find(it => it.habit.ddlId === ddlId);
    if (!item) return;
    const habit = item.habit;

    this.tempHabitName = habit.name;

    if (habit.alarmTime && habit.alarmTime.length > 0) {
      this.tempIsEnabled = true;
      const parts = habit.alarmTime.split(':');
      const d = new Date();
      d.setHours(parseInt(parts[0]), parseInt(parts[1]));
      this.tempSelectedTime = d;
    } else {
      this.tempIsEnabled = false;
      const d = new Date();
      d.setHours(20, 0);
      this.tempSelectedTime = d;
    }

    this.alarmDialogController.open();
  }

  async saveAlarmSetting(enabled: boolean, timeStr: string) {
    if (this.currentAlarmDdlId === -1) return;

    try {
      const habitRaw = await this.repo.getHabitByDdlId(this.currentAlarmDdlId);
      if (!habitRaw) return;

      const updatedHabit = habitRaw;
      updatedHabit.alarmTime = enabled ? timeStr : null;

      await this.repo.updateHabit(updatedHabit);

      Toast.show({ message: enabled ? `已设置提醒: ${timeStr}` : '提醒已关闭' });

      await this.refreshAll(this.selectedDate);
      this.exitSelectionMode();

    } catch (e) {
      AppLog.error('Native', 'Set alarm failed:', e);
      Toast.show({ message: '设置失败' });
    }
  }

  @State isFirstLoad: boolean = true;

  async refreshAll(date: Date) {
    const presentation: HabitPresentationState = await this.repo.getPresentationForDate(date);
    const categories: CategoryDisplayModel[] = await this.categoryRepository.listCategories();
    const statusList: HabitWithDailyStatus[] = [];
    for (let index: number = 0; index < presentation.visibleHabits.length; index += 1) {
      const item: HabitPresentationItem = presentation.visibleHabits[index];
      if (!CategoryFilterResolver.matches(this.categoryFilter, item.habit.categoryUid, categories)) continue;
      statusList.push({
        habit: item.habit,
        doneCount: item.doneCount,
        targetCount: item.targetCount,
        progressText: item.progressText,
        scheduleLabel: item.scheduleLabel,
        isCompleted: item.isCompleted,
        canApplyPrimaryAction: item.canApplyPrimaryAction,
        primaryActionKind: item.primaryActionKind,
        primaryActionAmount: item.primaryActionAmount,
        isDueToday: item.isDue,
        dueStateText: this.scheduleStateText(item)
      });
    }
    this.allHabitsCache = statusList;
    this.applyFilter();
    const week: DayOverview[] = [];
    for (let index: number = 0; index < presentation.weekOverview.length; index += 1) {
      const day: HabitPresentationDay = presentation.weekOverview[index];
      week.push({
        date: new Date(day.date + 'T00:00:00'),
        completedCount: day.completedCount,
        totalCount: day.totalCount,
        completionRatio: day.completionRatio
      });
    }
    this.weekOverview = week;

    if (this.isFirstLoad) {
      setTimeout(() => {
        this.isFirstLoad = false;
      }, 750)
    }
  }

  private scheduleStateText(item: HabitPresentationItem): string {
    if (item.isDue) return '';
    if (item.scheduleHintKind === 'STARTS_IN' && item.daysUntil !== null) {
      return item.daysUntil.toString() + ' 天后开始';
    }
    if (item.scheduleHintKind === 'NEXT_REVIEW_IN' && item.daysUntil !== null) {
      return item.daysUntil.toString() + ' 天后复习';
    }
    if (item.scheduleHintKind === 'COMPLETED_CYCLE') return '已完成记忆周期';
    if (item.scheduleReason === 'WEEKDAY_NOT_SELECTED') return '非计划日';
    return '当前日期不可打卡';
  }

  private applyFilter() {
    if (!this.searchQuery || this.searchQuery.trim() === "") {
      this.displayHabits = this.allHabitsCache;
    } else {
      const lowerQ = this.searchQuery.toLowerCase();
      this.displayHabits = this.allHabitsCache.filter(it =>
      it.habit.name.toLowerCase().includes(lowerQ)
      );
    }
    this.publishSemanticSnapshot();
  }

  private publishSemanticSnapshot(): void {
    const inputs: HabitSemanticInput[] = [];
    for (let index: number = 0; index < this.displayHabits.length; index++) {
      const item: HabitWithDailyStatus = this.displayHabits[index];
      inputs.push(new HabitSemanticInput(item.habit.id, item.isCompleted));
    }
    const snapshot: SemanticSnapshot = PageToneResolver.resolveHabits(inputs);
    this.semanticSnapshot = snapshot;
    this.onSemanticSnapshotChanged(snapshot);
  }

  onDateSelected(date: Date) {
    this.closeSwipeActions();
    this.selectedDate = date;
    this.refreshAll(date);
  }

  async onToggleHabit(item: HabitWithDailyStatus) {
    if (this.openSwipeHabitId === item.habit.id && !this.isSelectionMode) {
      this.closeSwipeActions(); return;
    }
    if (this.togglingHabitIds.has(item.habit.id)) {
      return;
    }

    this.togglingHabitIds.add(item.habit.id);

    try {
      if (this.isSelectionMode) {
        this.toggleSelection(item.habit.ddlId);
        return;
      }

      if (!item.canApplyPrimaryAction) {
        Toast.show({ message: item.dueStateText || '当前日期不可打卡' });
        return;
      }

      VibrationUtils.vibrateShort();

      const beforeRate = item.doneCount / item.targetCount;

      await this.repo.toggleRecord(item.habit.id, this.selectedDate);

      await this.refreshAll(this.selectedDate);

      const afterItem = this.allHabitsCache.find(it => it.habit.id === item.habit.id);
      if (afterItem) {
        const afterRate = afterItem.doneCount / afterItem.targetCount;
        if (beforeRate < 1 && afterRate >= 1) {
          AppLog.info('Native', "🎉 Habit Completed!");
          this.confetti.fire();
        }
      }
    } finally {
      this.togglingHabitIds.delete(item.habit.id);
    }
  }

  exitSelectionMode() {
    this.isSelectionMode = false;
    this.selectedDdlIds.clear();
  }

  async handleBatchComplete() {
    if (this.selectedDdlIds.size === 0) return;

    VibrationUtils.vibrateShort();

    const targets = this.allHabitsCache.filter(item =>
      this.selectedDdlIds.has(item.habit.ddlId) && item.canApplyPrimaryAction
    );

    if (targets.length === 0) {
      Toast.show({ message: '没有可打卡的待办' });
      this.exitSelectionMode();
      return;
    }

    try {
      await Promise.all(targets.map(item => this.repo.toggleRecord(item.habit.id, this.selectedDate)));

      Toast.show({ message: `已打卡 ${targets.length} 个待办` });
      this.refreshAll(this.selectedDate);
      this.exitSelectionMode();
    } catch (e) {
      AppLog.error('Native', 'Batch complete failed:', e);
      Toast.show({ message: '操作失败' });
    }
  }

  private async hasSelectedActiveFocus(): Promise<boolean> {
    const state = await KmpFocusTimerRepository.getInstance().state();
    if (state.timer?.target?.kind !== 'HABIT') return false;
    const uid: string = state.timer.target.uid;
    const found: boolean = this.allHabitsCache.some((item: HabitWithDailyStatus) =>
      this.selectedDdlIds.has(item.habit.ddlId) && item.habit.uid === uid);
    if (found) {
      AppStorage.setOrCreate('FocusResolutionMessage', '选中的习惯正在专注，请先结束计时，再进行批量操作。');
      AppStorage.setOrCreate('FocusTimerOpen', true);
    }
    return found;
  }

  async handleBatchDelete() {
    if (this.selectedDdlIds.size === 0) return;

    VibrationUtils.vibrateMedium();

    AlertDialog.show(DialogCompat.withAlertBlurStyle({
      title: '删除待办',
      message: `确定要删除选中的 ${this.selectedDdlIds.size} 个待办吗？此操作不可恢复。`,
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      offset: { dx: 0, dy: -20 },
      gridCount: 4,
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
            const idsToDelete = Array.from(this.selectedDdlIds);
            for (const ddlId of idsToDelete) await this.repo.deleteHabitByDdlId(ddlId);

            Toast.show({ message: '删除成功' });
            this.refreshAll(this.selectedDate);
            this.exitSelectionMode();
            getContext(this).eventHub.emit('sync_done');
          } catch (e) {
            if (String(e).includes('操作已取消')) { this.refreshAll(this.selectedDate); return; }
            AppLog.error('Native', 'Batch delete failed:', e);
            Toast.show({ message: '删除失败' });
          }
        }
      }
    }, BlurStyle.Regular))
  }

  async handleBatchArchive() {
    if (this.selectedDdlIds.size === 0) return;

    try {
      const targets = this.allHabitsCache.filter(item => this.selectedDdlIds.has(item.habit.ddlId));

      for (const item of targets) await this.repo.archiveHabit(item.habit.id);

      Toast.show({ message: `已归档 ${targets.length} 个待办` });
      this.refreshAll(this.selectedDate);
      this.exitSelectionMode();
    } catch (e) {
      if (String(e).includes('操作已取消')) { this.refreshAll(this.selectedDate); return; }
      AppLog.error('Native', 'Batch archive failed:', e);
      Toast.show({ message: '归档失败' });
    }
  }

  handleBatchEdit() {
    if (this.selectedDdlIds.size === 0) {
      Toast.show({ message: '未选中任何待办' });
      return;
    }

    const ddlId: number = this.selectedDdlIds.values().next().value;
    const targetItem = this.allHabitsCache.find(it => it.habit.ddlId === ddlId);

    if (!targetItem) {
      Toast.show({ message: '未找到待办数据' });
      return;
    }

    this.exitSelectionMode();
    this.currentEditingHabit = targetItem.habit;
    this.isEditSheetShow = true;
  }

  onLongPress(ddlId: number) {
    VibrationUtils.vibrateShort();
    this.isSelectionMode = true;
    this.toggleSelection(ddlId);
  }

  toggleSelection(ddlId: number) {
    if (this.selectedDdlIds.has(ddlId)) {
      this.selectedDdlIds.delete(ddlId);
      if (this.selectedDdlIds.size === 0) {
        this.isSelectionMode = false;
      }
    } else {
      this.selectedDdlIds.add(ddlId);
    }
  }

  isSelected(ddlId: number): boolean {
    return this.selectedDdlIds.has(ddlId);
  }

  private getTodayCompletionRatio(): number {
    const todayOverview = this.weekOverview.find(
      d => d.date.toDateString() === this.selectedDate.toDateString()
    );
    return todayOverview ? todayOverview.completionRatio : 0;
  }

  @State isEditSheetShow: boolean = false
  @State currentEditingHabit: Habit | undefined = undefined;

  @Builder
  habitEditSheet() {
    HabitEditSheet({
      isShow: $isEditSheetShow,
      editingHabit: this.currentEditingHabit,
      onSave: (habit): Promise<void> => this.handleSaveHabit(habit)
    })
  }

  async handleSaveHabit(updatedHabit: Habit) {
    await this.repo.updateHabit(updatedHabit);
    await this.refreshAll(this.selectedDate);
    getContext(this).eventHub.emit('sync_done');
  }

  @State isRefreshing: boolean = false;

  @Builder
  EmptyPlaceholder() {
    Column() {
      SymbolGlyph($r('sys.symbol.bicycle'))
        .fontSize(80)
        .fontColor([$r('app.color.font_secondary')])
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        .opacity(0.5)

      Text("暂无待打卡待办")
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.font_secondary'))
        .margin({ top: 16 })

      Text("一点一滴，养成好习惯")
        .fontSize(14)
        .fontColor($r('app.color.font_secondary'))
        .opacity(0.6)
        .margin({ top: 8 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  changeWeek(offset: number) {
    this.closeSwipeActions();
    const newDate = new Date(this.selectedDate);
    newDate.setDate(newDate.getDate() + (offset * 7));
    this.selectedDate = newDate;
    this.refreshAll(newDate);
    VibrationUtils.vibrateSoft();
  }

  private closeSwipeActions(): void {
    this.scroller.closeAllSwipeActions();
    this.openSwipeHabitId = -1;
  }

  private async archiveHabit(habit: Habit): Promise<void> {
    this.closeSwipeActions();
    try { await this.repo.archiveHabit(habit.id); await this.refreshAll(this.selectedDate); }
    catch (error) { if (!String(error).includes('操作已取消')) Toast.show({ message: '归档未完成，请重试' }); }
  }

  private deleteHabit(habit: Habit): void {
    this.closeSwipeActions();
    this.getUIContext().showAlertDialog({ title: '删除习惯？', message: '删除习惯不会撤销已有的专注记录。',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: { value: '删除', action: (): void => {
        this.repo.deleteHabitByDdlId(habit.ddlId).then(() => { this.refreshAll(this.selectedDate); })
          .catch((error: Error): void => { if (!error.message.includes('操作已取消')) Toast.show({ message: '删除未完成，请重试' }); });
      } }
    });
  }

  @Builder private habitSwipeActions(habit: Habit, leading: boolean) {
    HabitSwipeActions({ leading: leading, onArchive: (): void => { this.archiveHabit(habit); },
      onFocusAction: (): void => { this.closeSwipeActions(); this.focusedHabit = habit; this.isFocusTimerShow = true; },
      onEdit: (): void => { this.closeSwipeActions(); this.currentEditingHabit = habit; this.isEditSheetShow = true; },
      onDelete: (): void => { this.deleteHabit(habit); } })
  }

  build() {
    Column() {
      Blank().height(this.topAvoidHeight).width('100%')

      Column() {
        HabitProgress({ progress: this.getTodayCompletionRatio() })
          .margin({ top: 12, bottom: 12 })
          .align(Alignment.Center)
          .attributeModifier(new FloatUpModifier(0, 15, this.isFirstLoad))

        WeekRow({
          weekOverview: this.weekOverview,
          selectedDate: this.selectedDate,
          currentDate: new Date(),
          onChangeWeek: (offset: number): void => this.changeWeek(offset),
          onSelectDate: (d: Date): void => this.onDateSelected(d)
        })
          .margin({ bottom: 8 })
          .align(Alignment.Center)
          .attributeModifier(new FloatUpModifier(0, 15, this.isFirstLoad))

        Refresh({
          refreshing: $$this.isRefreshing
        }) {
          List({ scroller: this.scroller, space: 10 }) {
            if (this.displayHabits.length > 0) {
              ForEach(this.displayHabits, (item: HabitWithDailyStatus, index: number) => {
                ListItem() {
                  HabitRow({
                    data: item,
                    status: item.isCompleted ? DDLStatus.COMPLETED : DDLStatus.UNDERGO,
                    isSelected: this.isSelected(item.habit.ddlId),
                    canToggle: this.isSelectionMode || item.canApplyPrimaryAction,
                    remainingText: item.dueStateText || '',
                    onToggle: (): Promise<void> => this.onToggleHabit(item),
                    onLongPress: (): void => this.onLongPress(item.habit.ddlId)
                  })
                }
                .swipeAction(this.isSelectionMode ? undefined : {
                  start: { builder: () => { this.habitSwipeActions(item.habit, true); } },
                  end: { builder: () => { this.habitSwipeActions(item.habit, false); } },
                  edgeEffect: SwipeEdgeEffect.None,
                  onOffsetChange: (offset: number): void => { this.openSwipeHabitId = offset === 0 ? -1 : item.habit.id; }
                })
                .attributeModifier(new FloatUpModifier(index + 1, 15, this.isFirstLoad))
                .attributeModifier(new PressEffectModifier(0.98))
                .animation({
                  curve: curves.responsiveSpringMotion(0.35, 0.60)
                })
              }, (item: HabitWithDailyStatus) => {
                return `${item.habit.id}_${item.doneCount}_${item.habit.updatedAt}`;
              })

              ListItem() {
                Column() {
                  Blank().height(140)
                }
              }
            } else {
              ListItem() {
                this.EmptyPlaceholder()
              }
              .width('100%')
              .height('100%')
              .attributeModifier(new FloatUpModifier(2, 15))
            }
          }
          .width('100%')
          .height('100%')
          .layoutWeight(1)
          .padding({ left: 12, right: 12 })
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .onScroll((_scrollOffset: number, _scrollState: ScrollState) => {
            this.controller.onScroll(this.scroller.currentOffset().yOffset);
          })
          .onScrollStop(() => {
            this.controller.onScroll(this.scroller.currentOffset().yOffset);
          })
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
        }
        .onRefreshing(async () => {
          this.isRefreshing = true
          await this.refreshAll(this.selectedDate);
          WidgetRefreshBridge.requestKmpUpdate(WidgetUpdateReason.USER_REFRESH);
          this.isRefreshing = false;
        })
        .layoutWeight(1)
        .width('100%')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      }
      .height('100%')
      .width('100%')
      .layoutWeight(1)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.isFocusTimerShow, this.focusSheet(), SheetCompat.immersive({
      height: SheetSize.LARGE,
      enableOutsideInteractive: false, showClose: true, dragBar: true,
      onDisappear: () => { this.isFocusTimerShow = false; this.refreshAll(this.selectedDate); }
    }))
    .bindSheet($$this.isEditSheetShow, this.habitEditSheet(), SheetCompat.immersive({
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      onDisappear: () => {
        this.isEditSheetShow = false;
        this.currentEditingHabit = undefined;
      },
      title: {
        title: '编辑习惯',
        subtitle: '修改习惯信息。'
      }
    }))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM, SafeAreaEdge.TOP])
  }
}
