import { TopSafeContainer } from "../../components/TopSafeContainer"
import { HabitRepository } from '../../../common/repository/HabitRepository';
import { Habit, HabitGoalType, HabitPeriod, HabitRecordStatus, HabitStatus } from '../../../model/DDLModels';
import { WeekRow, HabitRow, HabitWithDailyStatus, DayOverview, HabitProgress } from '../../components/HabitComponents'
import { HabitListController } from "./HabitListController";
import { ChipGroup, ChipGroupItemOptions, ChipSize, curves, promptAction } from '@kit.ArkUI'
import { VibrationUtils } from "../../../utils/VibrationUtils";
import { ConfettiController } from "../../components/confetti/ConfettiController";
import { FloatUpModifier } from "../../../utils/animation/FloatUpModifier";
import { HabitEditSheet } from "./modify/habit/HabitEditSheet";
import { HabitReminderDialog } from "../../components/HabitReminderDialog";
import { ReminderScheduler } from "../../../utils/notification/ReminderScheduler";
import { PressEffectModifier } from "../../../utils/animation/PressModifier";
import { ITheme } from "../../../common/theme/ThemeModel";
import { DDLStatus } from "../../../model/DDLStatus"

interface EbbinState {
  isDue: boolean;
  text: string;
}

@Component
export struct HabitListSection {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @Prop topAvoidHeight: number = 0;

  scroller: Scroller = new Scroller();
  confetti: ConfettiController = new ConfettiController();
  controller: HabitListController = new HabitListController();

  @State selectedDate: Date = new Date();
  @State searchQuery: string = "";
  @State weekOverview: DayOverview[] = [];
  @State displayHabits: HabitWithDailyStatus[] = [];

  // 内存缓存
  private allHabitsCache: HabitWithDailyStatus[] = [];

  // 交互模式状态（对应 selectionMode）
  @Link isSelectionMode: boolean;
  @State selectedDdlIds: Set<number> = new Set();

  private repo = HabitRepository.getInstance();

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
    console.debug('HabitListSection received sync_done event');
    this.refreshAll(this.selectedDate);
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
      promptAction.showToast({ message: '请选择一个待办来设置提醒' });
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

      const allHabits = await this.repo.getAllHabits();
      await ReminderScheduler.refreshHabits(allHabits);

      promptAction.showToast({ message: enabled ? `已设置提醒: ${timeStr}` : '提醒已关闭' });

      await this.refreshAll(this.selectedDate);
      this.exitSelectionMode();

    } catch (e) {
      console.error('Set alarm failed:', e);
      promptAction.showToast({ message: '设置失败' });
    }
  }

  @State isFirstLoad: boolean = true;

  async refreshAll(date: Date) {
    const allHabitsRaw = await this.repo.getAllHabits();
    const allHabits = allHabitsRaw.filter(h => h.status !== HabitStatus.ARCHIVED);

    const statusListNullable = await Promise.all(allHabits.map(h => this.buildStatusForDate(h, date)));
    const statusList = statusListNullable.filter((item) => item !== null) as HabitWithDailyStatus[];
    this.allHabitsCache = statusList;
    this.applyFilter();

    this.calculateWeekOverview(date, allHabits);

    if (this.isFirstLoad) {
      setTimeout(() => {
        this.isFirstLoad = false;
      }, 750)
    }
  }

  private async buildStatusForDate(habit: Habit, date: Date): Promise<HabitWithDailyStatus | null> {
    if (!this.shouldShowHabitOnDate(habit, date)) {
      return null;
    }

    const bounds = this.getPeriodBounds(habit.period, date);
    const start = bounds[0];
    const end = bounds[1];

    const queryStart = habit.goalType === HabitGoalType.TOTAL ? new Date(0) : start;
    const queryEnd = habit.goalType === HabitGoalType.TOTAL ? date : end;

    const records = await this.repo.getRecordsForHabitInRange(habit.id, queryStart, queryEnd);

    const done = records
      .filter(r => r.status === HabitRecordStatus.COMPLETED)
      .reduce((sum, r) => sum + r.count, 0);

    let target = Math.max(1, habit.timesPerPeriod);
    if (habit.goalType === HabitGoalType.TOTAL) {
      target = habit.totalTarget ? Math.max(1, habit.totalTarget) : Math.max(1, done);
    }

    return {
      habit: habit,
      doneCount: done,
      targetCount: target,
      isCompleted: habit.totalTarget ? done >= habit.totalTarget : done >= target
    };
  }

  private shouldShowHabitOnDate(habit: Habit, date: Date): boolean {
    // 移除 ONCE，现有的 DAILY, WEEKLY, MONTHLY, EBBINGHAUS 均始终在列表中占位显示
    return true;
  }

  /**
   * 获取艾宾浩斯习惯在指定日期的状态
   * 返回 isDue: 是否是复习日, text: UI 提示文本
   */
  private getEbbinghausState(habit: Habit, targetDate: Date): EbbinState {
    if (habit.period !== HabitPeriod.EBBINGHAUS) {
      return { isDue: true, text: "" };
    }

    const tDate = new Date(targetDate);
    tDate.setHours(0, 0, 0, 0);

    const sDate = new Date(habit.createdAt);
    sDate.setHours(0, 0, 0, 0);

    const diffDays = Math.floor((tDate.getTime() - sDate.getTime()) / (1000 * 60 * 60 * 24));

    // 艾宾浩斯标准曲线
    const curve = [0, 1, 2, 4, 7, 15, 30, 60];

    if (diffDays < 0) {
      return { isDue: false, text: `${-diffDays} 天后开始` };
    }

    if (curve.includes(diffDays)) {
      return { isDue: true, text: "" }; // 今天是复习日
    }

    // 寻找下一个复习日
    const nextDay = curve.find(c => c > diffDays);
    if (nextDay !== undefined) {
      return { isDue: false, text: `${nextDay - diffDays} 天后复习` };
    } else {
      return { isDue: false, text: "已完成记忆周期" };
    }
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
  }

  private getPeriodBounds(period: HabitPeriod, date: Date): [Date, Date] {
    const d = new Date(date);
    d.setHours(0, 0, 0, 0);

    if (period === HabitPeriod.DAILY) {
      return [d, d];
    } else if (period === HabitPeriod.WEEKLY) {
      const day = d.getDay();
      const diff = d.getDate() - day + (day === 0 ? -6 : 1);
      const monday = new Date(d.setDate(diff));
      const sunday = new Date(monday);
      sunday.setDate(monday.getDate() + 6);
      return [monday, sunday];
    } else if (period === HabitPeriod.MONTHLY) {
      const firstDay = new Date(d.getFullYear(), d.getMonth(), 1);
      const lastDay = new Date(d.getFullYear(), d.getMonth() + 1, 0);
      return [firstDay, lastDay];
    }
    // 艾宾浩斯的周期就限定在当天
    return [d, d];
  }

  private async calculateWeekOverview(centerDate: Date, allHabits: Habit[]) {
    const d = new Date(centerDate);
    const day = d.getDay();
    const diff = d.getDate() - day + (day === 0 ? -6 : 1);
    const monday = new Date(d.setDate(diff));

    const week: DayOverview[] = [];
    for (let i = 0; i < 7; i++) {
      const current = new Date(monday);
      current.setDate(monday.getDate() + i);

      const statusesNullable = await Promise.all(allHabits.map(h => this.buildStatusForDate(h, current)));
      const activeStatuses = statusesNullable.filter((s) => s !== null) as HabitWithDailyStatus[];

      // 计算当天真实的分子和分母
      // 对于艾宾浩斯，只有当 isDue 为 true 时，才计入当天的完成率统计
      const validStatuses = activeStatuses.filter(s => {
        const ebState = this.getEbbinghausState(s.habit, current);
        return ebState.isDue;
      });

      const completedCount = validStatuses.filter(s => s.isCompleted).length;
      const totalCount = validStatuses.length;

      week.push({
        date: current,
        completedCount: completedCount,
        totalCount: totalCount,
        completionRatio: totalCount > 0 ? (completedCount / totalCount) : 0
      });
    }
    this.weekOverview = week;
  }

  onDateSelected(date: Date) {
    this.selectedDate = date;
    this.refreshAll(date);
  }

  async onToggleHabit(item: HabitWithDailyStatus) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const currentSel = new Date(this.selectedDate);
    currentSel.setHours(0, 0, 0, 0);

    if (currentSel.getTime() > today.getTime()) {
      return;
    }

    // 艾宾浩斯非复习日阻断打卡
    const ebState = this.getEbbinghausState(item.habit, this.selectedDate);
    if (!ebState.isDue) {
      promptAction.showToast({ message: '今天不是该记忆周期的复习日' });
      return;
    }

    if (this.isSelectionMode) {
      this.toggleSelection(item.habit.ddlId);
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
        console.info("🎉 Habit Completed!");
        this.confetti.fire();
      }
    }
  }

  exitSelectionMode() {
    this.isSelectionMode = false;
    this.selectedDdlIds.clear();
  }

  async handleBatchComplete() {
    if (this.selectedDdlIds.size === 0) return;

    VibrationUtils.vibrateShort();

    // 过滤出未完成 且 属于今天可打卡范围的待办（排除未到复习日的艾宾浩斯）
    const targets = this.allHabitsCache.filter(item => {
      const ebState = this.getEbbinghausState(item.habit, this.selectedDate);
      return this.selectedDdlIds.has(item.habit.ddlId) && !item.isCompleted && ebState.isDue;
    });

    if (targets.length === 0) {
      promptAction.showToast({ message: '没有可打卡的待办' });
      this.exitSelectionMode();
      return;
    }

    try {
      await Promise.all(targets.map(item => {
        return this.repo.insertRecord(item.habit.id, this.selectedDate, 1);
      }));

      promptAction.showToast({ message: `已打卡 ${targets.length} 个待办` });
      this.refreshAll(this.selectedDate);
      this.exitSelectionMode();
    } catch (e) {
      console.error('Batch complete failed:', e);
      promptAction.showToast({ message: '操作失败' });
    }
  }

  async handleBatchDelete() {
    if (this.selectedDdlIds.size === 0) return;

    VibrationUtils.vibrateMedium();

    AlertDialog.show({
      title: '删除待办',
      message: `确定要删除选中的 ${this.selectedDdlIds.size} 个待办吗？此操作不可恢复。`,
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      offset: { dx: 0, dy: -20 },
      gridCount: 4,
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
            const idsToDelete = Array.from(this.selectedDdlIds);
            await Promise.all(idsToDelete.map(ddlId => this.repo.deleteHabitByDdlId(ddlId)));

            promptAction.showToast({ message: '删除成功' });
            this.refreshAll(this.selectedDate);
            this.exitSelectionMode();
            getContext(this).eventHub.emit('sync_done');
          } catch (e) {
            console.error('Batch delete failed:', e);
            promptAction.showToast({ message: '删除失败' });
          }
        }
      }
    })
  }

  async handleBatchArchive() {
    if (this.selectedDdlIds.size === 0) return;

    try {
      const targets = this.allHabitsCache.filter(item => this.selectedDdlIds.has(item.habit.ddlId));

      await Promise.all(targets.map(item => {
        const updatedHabit = item.habit;
        updatedHabit.status = HabitStatus.ARCHIVED;
        return this.repo.updateHabit(updatedHabit);
      }));

      promptAction.showToast({ message: `已归档 ${targets.length} 个待办` });
      this.refreshAll(this.selectedDate);
      this.exitSelectionMode();
    } catch (e) {
      console.error('Batch archive failed:', e);
      promptAction.showToast({ message: '归档失败' });
    }
  }

  handleBatchEdit() {
    if (this.selectedDdlIds.size === 0) {
      promptAction.showToast({ message: '未选中任何待办' });
      return;
    }

    const ddlId: number = this.selectedDdlIds.values().next().value;
    const targetItem = this.allHabitsCache.find(it => it.habit.ddlId === ddlId);

    if (!targetItem) {
      promptAction.showToast({ message: '未找到待办数据' });
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
    const newDate = new Date(this.selectedDate);
    newDate.setDate(newDate.getDate() + (offset * 7));
    this.selectedDate = newDate;
    this.refreshAll(newDate);
    VibrationUtils.vibrateSoft();
  }

  build() {
    Column() {
      TopSafeContainer({ topAvoidHeight: this.topAvoidHeight, scrollable: false, needBgTransparent: true }) {
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
                      // 直接在传参时进行内联计算
                      canToggle: (new Date(this.selectedDate).setHours(0, 0, 0, 0) <= new Date().setHours(0, 0, 0, 0))
                        && this.getEbbinghausState(item.habit, this.selectedDate).isDue,
                      // 这里会重复调用一次 getEbbinghausState，但因为只有纯数学运算，对性能无影响
                      remainingText: this.getEbbinghausState(item.habit, this.selectedDate).text,
                      onToggle: (): Promise<void> => this.onToggleHabit(item),
                      onLongPress: (): void => this.onLongPress(item.habit.ddlId)
                    })
                  }
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
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
          }
          .onRefreshing(async () => {
            this.isRefreshing = true
            await this.refreshAll(this.selectedDate);
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
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.isEditSheetShow, this.habitEditSheet(), {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      onDisappear: () => {
        this.isEditSheetShow = false;
        this.currentEditingHabit = undefined;
      },
      blurStyle: BlurStyle.Regular,
      backgroundColor: Color.Transparent,
      title: {
        title: '编辑待办',
        subtitle: '修改待办信息。'
      }
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}