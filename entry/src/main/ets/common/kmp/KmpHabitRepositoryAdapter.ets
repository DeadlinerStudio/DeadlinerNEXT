import { FocusTimerUiStatePayload } from '../../model/FocusModels';
import { FocusChangeConfirmation } from '../../pages/routes/focus/FocusChangeConfirmation';
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { Habit, HabitGoalType, HabitPeriod, HabitRecord, HabitRecordStatus, HabitStatus } from '../../model/DDLModels';
import { KmpPersistenceService } from './KmpPersistenceService';
import { KmpTaskRepositoryAdapter } from './KmpTaskRepositoryAdapter';

interface KmpHabitReminderPayload {
  localTime: string;
  isEnabled: boolean;
}

interface KmpHabitSchedulePayload {
  kind: string;
  startOn: string;
  endOn: string | null;
  weekdaysMask: number | null;
  algorithmKey: string | null;
}

interface KmpHabitGoalPayload {
  window: string;
  targetCount: number;
}

interface KmpHabitTrackingPayload {
  mode: string;
  unit: string | null;
  defaultIncrement: number;
}

interface KmpHabitPayload {
  uid: string;
  name: string;
  description: string | null;
  color: number | null;
  iconKey: string | null;
  categoryUid: string | null;
  schedule: KmpHabitSchedulePayload;
  goal: KmpHabitGoalPayload;
  tracking: KmpHabitTrackingPayload;
  status: HabitStatus;
  sortOrder: number;
  reminder: KmpHabitReminderPayload | null;
  createdAt: string;
  updatedAt: string;
  isDeleted: boolean;
}

interface KmpHabitRecordPayload {
  uid: string;
  habitUid: string;
  occurredOn: string;
  count: number;
  status: HabitRecordStatus;
  createdAt: string;
  updatedAt: string;
  isDeleted: boolean;
}

interface KmpHabitPrimaryActionPayload {
  kind: string;
  amount: number;
}

interface KmpHabitScheduleStatePayload {
  isDue: boolean;
  reason: string;
  hintKind: string | null;
  nextDueOn: string | null;
  daysUntil: number | null;
}

interface KmpHabitDayStatusPayload {
  habit: KmpHabitPayload;
  doneCount: number;
  targetCount: number;
  isCompleted: boolean;
  canApplyPrimaryAction: boolean;
  primaryAction: KmpHabitPrimaryActionPayload;
  scheduleState: KmpHabitScheduleStatePayload;
}

interface KmpHabitDayOverviewPayload {
  date: string;
  completedCount: number;
  totalCount: number;
  completionRatio: number;
}

interface KmpHabitReminderPlanPayload {
  habitUid: string;
  scheduledLocalDateTimes: string[];
}

interface KmpHabitStatePayload {
  habits: KmpHabitPayload[];
  records: KmpHabitRecordPayload[];
  selectedDate: string;
  visibleHabits: KmpHabitDayStatusPayload[];
  upcomingReviews: KmpHabitDayStatusPayload[];
  weekOverview: KmpHabitDayOverviewPayload[];
  reminderPlans: KmpHabitReminderPlanPayload[];
}

export interface HabitPresentationItem {
  habit: Habit;
  doneCount: number;
  targetCount: number;
  progressText: string;
  scheduleLabel: string;
  isCompleted: boolean;
  canApplyPrimaryAction: boolean;
  primaryActionKind: string;
  primaryActionAmount: number;
  isDue: boolean;
  scheduleReason: string;
  scheduleHintKind: string | null;
  nextDueOn: string | null;
  daysUntil: number | null;
}

export interface HabitPresentationDay {
  date: string;
  completedCount: number;
  totalCount: number;
  completionRatio: number;
}

export interface HabitReminderPlan {
  habit: Habit;
  scheduledLocalDateTimes: string[];
}

export interface HabitPresentationState {
  selectedDate: string;
  visibleHabits: HabitPresentationItem[];
  weekOverview: HabitPresentationDay[];
  reminderPlans: HabitReminderPlan[];
}

export interface LegacyHabitIdentifier {
  habitId: number;
  taskUid: string;
}

/** ArkTS-compatible numeric projection of the KMP Habit ViewModel and repository state. */
export class KmpHabitRepositoryAdapter {
  private static readonly PREFERENCE_NAME: string = 'kmp_habit_compatibility';
  private static readonly HABIT_ID_PREFIX: string = 'habit_uid:';
  private static readonly RECORD_ID_PREFIX: string = 'record_uid:';
  private static readonly NEXT_ID_KEY: string = 'next_synthetic_id';
  private static readonly FIRST_SYNTHETIC_ID: number = 1200000000;

  private readonly persistence: KmpPersistenceService = KmpPersistenceService.getInstance();
  private readonly taskAdapter: KmpTaskRepositoryAdapter;
  private store: preferences.Preferences | null = null;
  private stateCache: KmpHabitStatePayload | null = null;
  private stateRevision: number = -1;

  constructor(taskAdapter: KmpTaskRepositoryAdapter) {
    this.taskAdapter = taskAdapter;
  }

  public async initialize(context: common.Context): Promise<void> {
    if (this.store !== null) return;
    this.store = await preferences.getPreferences(context, KmpHabitRepositoryAdapter.PREFERENCE_NAME);
    const state: KmpHabitStatePayload = this.currentState();
    for (let index = 0; index < state.habits.length; index++) {
      await this.taskAdapter.markHabitUid(state.habits[index].uid);
    }
  }

  /** Called only by the one-time legacy migration. */
  public async importLegacyNumericIds(context: common.Context, identifiers: LegacyHabitIdentifier[]): Promise<void> {
    await this.initialize(context);
    await this.bindLegacyNumericIds(identifiers);
  }

  public async listActive(): Promise<Habit[]> {
    return this.projectHabits(false);
  }

  public async listArchived(): Promise<Habit[]> {
    return this.projectHabits(true);
  }

  public async presentationForDate(selectedDate: string): Promise<HabitPresentationState> {
    const state: KmpHabitStatePayload = this.readState(this.persistence.habitStateForDateJson(selectedDate));
    const visibleHabits: HabitPresentationItem[] = [];
    for (let index: number = 0; index < state.visibleHabits.length; index += 1) {
      const item: KmpHabitDayStatusPayload = state.visibleHabits[index];
      visibleHabits.push({
        habit: await this.toHabit(item.habit),
        doneCount: item.doneCount,
        targetCount: item.targetCount,
        progressText: this.progressText(item),
        scheduleLabel: this.scheduleLabel(item.habit),
        isCompleted: item.isCompleted,
        canApplyPrimaryAction: item.canApplyPrimaryAction,
        primaryActionKind: item.primaryAction.kind,
        primaryActionAmount: item.primaryAction.amount,
        isDue: item.scheduleState.isDue,
        scheduleReason: item.scheduleState.reason,
        scheduleHintKind: item.scheduleState.hintKind,
        nextDueOn: item.scheduleState.nextDueOn,
        daysUntil: item.scheduleState.daysUntil
      });
    }
    const weekOverview: HabitPresentationDay[] = [];
    for (let index: number = 0; index < state.weekOverview.length; index += 1) {
      const day: KmpHabitDayOverviewPayload = state.weekOverview[index];
      weekOverview.push({
        date: day.date,
        completedCount: day.completedCount,
        totalCount: day.totalCount,
        completionRatio: day.completionRatio
      });
    }
    const reminderPlans: HabitReminderPlan[] = [];
    for (let planIndex: number = 0; planIndex < state.reminderPlans.length; planIndex += 1) {
      const plan: KmpHabitReminderPlanPayload = state.reminderPlans[planIndex];
      for (let habitIndex: number = 0; habitIndex < state.habits.length; habitIndex += 1) {
        const habit: KmpHabitPayload = state.habits[habitIndex];
        if (habit.uid !== plan.habitUid) continue;
        reminderPlans.push({
          habit: await this.toHabit(habit),
          scheduledLocalDateTimes: plan.scheduledLocalDateTimes
        });
        break;
      }
    }
    return {
      selectedDate: state.selectedDate,
      visibleHabits: visibleHabits,
      weekOverview: weekOverview,
      reminderPlans: reminderPlans
    };
  }

  private progressText(item: KmpHabitDayStatusPayload): string {
    const base: string = item.doneCount.toString() + '/' + item.targetCount.toString();
    const unit: string | null = item.habit.tracking.unit;
    return unit !== null && unit.length > 0 ? base + ' ' + unit : base;
  }

  private scheduleLabel(habit: KmpHabitPayload): string {
    let scheduleText: string = '';
    if (habit.schedule.kind === 'ONCE') {
      scheduleText = '一次';
    } else if (habit.schedule.kind === 'ALGORITHM') {
      scheduleText = '艾宾浩斯';
    } else {
      const mask: number = habit.schedule.weekdaysMask === null ? 127 : habit.schedule.weekdaysMask;
      if (mask === 127) scheduleText = '每天';
      else if (mask === 31) scheduleText = '工作日';
      else if (mask === 96) scheduleText = '周末';
      else scheduleText = this.customWeekdayLabel(mask);
    }

    let goalText: string = '';
    if (habit.goal.window === 'WEEK') goalText = '每周';
    else if (habit.goal.window === 'MONTH') goalText = '每月';
    else if (habit.goal.window === 'LIFETIME') goalText = '总目标 ' + habit.goal.targetCount.toString();

    if (scheduleText.length > 0 && goalText.length > 0 && scheduleText !== goalText) {
      return scheduleText + ' · ' + goalText;
    }
    return goalText.length > 0 ? goalText : scheduleText;
  }

  private customWeekdayLabel(mask: number): string {
    const labels: string[] = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    const selected: string[] = [];
    for (let index: number = 0; index < labels.length; index += 1) {
      if ((mask & (1 << index)) !== 0) selected.push(labels[index]);
    }
    return selected.join('/');
  }

  public async findById(id: number): Promise<Habit | null> {
    const state: KmpHabitStatePayload = this.currentState();
    for (let index = 0; index < state.habits.length; index++) {
      const habit: KmpHabitPayload = state.habits[index];
      if (!habit.isDeleted && await this.habitIdFor(habit.uid) === id) return this.toHabit(habit);
    }
    return null;
  }

  public async findByDdlId(ddlId: number): Promise<Habit | null> {
    const state: KmpHabitStatePayload = this.currentState();
    for (let index = 0; index < state.habits.length; index++) {
      const habit: KmpHabitPayload = state.habits[index];
      if (!habit.isDeleted && await this.taskAdapter.legacyTaskIdForUid(habit.uid) === ddlId) return this.toHabit(habit);
    }
    return null;
  }

  public async create(
    name: string,
    period: HabitPeriod,
    timesPerPeriod: number,
    goalType: HabitGoalType,
    totalTarget: number | null,
    description: string,
    color: number | null,
    iconKey: string | null,
    sortOrder: number,
    alarmTime: string | null,
    existingUid: string | null = null,
    categoryUid: string | null = null,
    weekdaysMask: number = 127
  ): Promise<number> {
    const now: string = new Date().toISOString();
    const uid: string = existingUid === null ? util.generateRandomUUID(true) : existingUid;
    const habit: KmpHabitPayload = {
      uid: uid,
      name: name,
      description: description.length > 0 ? description : null,
      color: color,
      iconKey: iconKey,
      categoryUid: categoryUid,
      schedule: this.scheduleForLegacy(period, now.substring(0, 10), weekdaysMask),
      goal: this.goalForLegacy(period, timesPerPeriod, goalType, totalTarget),
      tracking: this.trackingForTarget(goalType === HabitGoalType.TOTAL ? totalTarget : timesPerPeriod),
      status: HabitStatus.ACTIVE,
      sortOrder: sortOrder,
      reminder: alarmTime === null ? null : { localTime: alarmTime, isEnabled: true },
      createdAt: now,
      updatedAt: now,
      isDeleted: false
    };
    this.persistence.habitCreateJson(JSON.stringify(habit));
    this.invalidateState();
    await this.taskAdapter.markHabitUid(uid);
    return this.habitIdFor(uid);
  }

  public async repairLegacyTaskCarriers(): Promise<number> {
    const state: KmpHabitStatePayload = this.currentState();
    let repaired: number = 0;
    for (let index = 0; index < state.habits.length; index++) {
      const habit: KmpHabitPayload = state.habits[index];
      if (!habit.isDeleted && await this.taskAdapter.deleteHabitCarrierIfPresent(habit.uid)) repaired += 1;
    }
    return repaired;
  }

  private async guardActiveFocus(uid: string, deleting: boolean = false): Promise<boolean> {
    const state: FocusTimerUiStatePayload = JSON.parse(this.persistence.focusStateJson(''));
    if (state.timer?.target?.kind === 'HABIT' && state.timer.target.uid === uid) {
      if (!await FocusChangeConfirmation.request(uid, true, deleting)) throw new Error('操作已取消或会话已变化');
      this.invalidateState();
      return true;
    }
    return false;
  }

  public async update(habit: Habit): Promise<boolean> {
    const current: KmpHabitPayload | null = await this.rawHabitForId(habit.id);
    if (current === null) return false;
    if (habit.status !== current.status && habit.status === HabitStatus.ARCHIVED && await this.guardActiveFocus(current.uid)) return true;
    const categoryChanged: boolean = habit.categoryUid !== current.categoryUid;
    const updated: KmpHabitPayload = {
      uid: current.uid,
      name: habit.name,
      description: habit.description,
      color: habit.color,
      iconKey: habit.iconKey,
      categoryUid: current.categoryUid,
      schedule: this.scheduleForUpdate(habit, current),
      goal: this.goalForLegacy(habit.period, habit.timesPerPeriod, habit.goalType, habit.totalTarget),
      tracking: this.trackingForUpdate(habit, current.tracking),
      status: habit.status,
      sortOrder: habit.sortOrder,
      reminder: habit.alarmTime === null ? null : { localTime: habit.alarmTime, isEnabled: true },
      createdAt: current.createdAt,
      updatedAt: new Date().toISOString(),
      isDeleted: false
    };
    this.persistence.habitUpdateJson(JSON.stringify(updated));
    if (categoryChanged) {
      this.persistence.habitCategoryUpdateJson(JSON.stringify({ uid: current.uid, categoryUid: habit.categoryUid }));
    }
    this.invalidateState();
    return true;
  }

  public async updateCategory(habitId: number, categoryUid: string | null): Promise<boolean> {
    const habit: KmpHabitPayload | null = await this.rawHabitForId(habitId);
    if (habit === null) return false;
    this.persistence.habitCategoryUpdateJson(JSON.stringify({ uid: habit.uid, categoryUid: categoryUid }));
    this.invalidateState();
    return true;
  }

  public async deleteByDdlId(ddlId: number): Promise<boolean> {
    const habit: Habit | null = await this.findByDdlId(ddlId);
    return habit === null ? false : this.deleteById(habit.id);
  }

  public async deleteById(id: number): Promise<boolean> {
    const habit: KmpHabitPayload | null = await this.rawHabitForId(id);
    if (habit === null) return false;
    if (await this.guardActiveFocus(habit.uid, true)) return true;
    this.persistence.habitDeleteJson(habit.uid, new Date().toISOString());
    this.invalidateState();
    return true;
  }

  public async setArchived(id: number, archived: boolean): Promise<boolean> {
    const habit: KmpHabitPayload | null = await this.rawHabitForId(id);
    if (habit === null) return false;
    if (archived && await this.guardActiveFocus(habit.uid)) return true;
    const payload: string = JSON.stringify({
      action: archived ? 'ARCHIVE' : 'RESTORE',
      occurredAt: new Date().toISOString()
    });
    this.persistence.habitStatusActionJson(habit.uid, payload);
    this.invalidateState();
    return true;
  }

  public async recordsForHabitOnDate(habitId: number, date: string): Promise<HabitRecord[]> {
    const state: KmpHabitStatePayload = this.currentState();
    const habit: KmpHabitPayload | null = await this.rawHabitForIdFromState(state, habitId);
    if (habit === null) return [];
    return this.projectRecords(state.records, habit.uid, date, date);
  }

  public async recordsForDate(date: string): Promise<HabitRecord[]> {
    const state: KmpHabitStatePayload = this.currentState();
    return this.projectRecords(state.records, '', date, date);
  }

  public async recordsForHabitInRange(habitId: number, startDate: string, endDate: string): Promise<HabitRecord[]> {
    const state: KmpHabitStatePayload = this.currentState();
    const habit: KmpHabitPayload | null = await this.rawHabitForIdFromState(state, habitId);
    if (habit === null) return [];
    return this.projectRecords(state.records, habit.uid, startDate, endDate);
  }

  public async insertRecord(habitId: number, date: string, count: number, status: HabitRecordStatus): Promise<number> {
    const habit: KmpHabitPayload | null = await this.rawHabitForId(habitId);
    if (habit === null) return -1;
    const now: string = new Date().toISOString();
    const record: KmpHabitRecordPayload = {
      uid: util.generateRandomUUID(true),
      habitUid: habit.uid,
      occurredOn: date,
      count: count,
      status: status,
      createdAt: now,
      updatedAt: now,
      isDeleted: false
    };
    this.persistence.habitSaveRecordJson(JSON.stringify(record));
    this.invalidateState();
    return this.recordIdFor(record.uid);
  }

  public async clearRecords(habitId: number, date: string): Promise<boolean> {
    const habit: KmpHabitPayload | null = await this.rawHabitForId(habitId);
    if (habit === null) return false;
    this.persistence.habitClearRecordsJson(habit.uid, JSON.stringify({ occurredOn: date, occurredAt: new Date().toISOString() }));
    this.invalidateState();
    return true;
  }

  public async toggleRecord(habitId: number, date: string): Promise<boolean> {
    const habit: KmpHabitPayload | null = await this.rawHabitForId(habitId);
    if (habit === null) return false;
    this.persistence.habitToggleRecordJson(habit.uid, JSON.stringify({ occurredOn: date, occurredAt: new Date().toISOString() }));
    this.invalidateState();
    return true;
  }

  private async projectHabits(archived: boolean): Promise<Habit[]> {
    const state: KmpHabitStatePayload = this.currentState();
    const result: Habit[] = [];
    for (let index = 0; index < state.habits.length; index++) {
      const habit: KmpHabitPayload = state.habits[index];
      if (!habit.isDeleted && (habit.status === HabitStatus.ARCHIVED) === archived) result.push(await this.toHabit(habit));
    }
    return result;
  }

  private async toHabit(habit: KmpHabitPayload): Promise<Habit> {
    const period: HabitPeriod = this.periodForPayload(habit);
    const goalType: HabitGoalType = habit.goal.window === 'LIFETIME' ? HabitGoalType.TOTAL : HabitGoalType.PER_PERIOD;
    return {
      uid: habit.uid,
      id: await this.habitIdFor(habit.uid),
      ddlId: await this.taskAdapter.legacyTaskIdForUid(habit.uid),
      name: habit.name,
      description: habit.description,
      color: habit.color,
      iconKey: habit.iconKey,
      categoryUid: habit.categoryUid,
      period: period,
      weekdaysMask: habit.schedule.weekdaysMask,
      timesPerPeriod: habit.goal.targetCount,
      goalType: goalType,
      totalTarget: goalType === HabitGoalType.TOTAL ? habit.goal.targetCount : null,
      createdAt: habit.createdAt,
      updatedAt: habit.updatedAt,
      status: habit.status,
      sortOrder: habit.sortOrder,
      alarmTime: habit.reminder === null ? null : habit.reminder.localTime
    };
  }

  private periodForPayload(habit: KmpHabitPayload): HabitPeriod {
    if (habit.schedule.kind === 'ONCE') return HabitPeriod.ONCE;
    if (habit.schedule.kind === 'ALGORITHM' && habit.schedule.algorithmKey === 'EBBINGHAUS_CLASSIC_V1') {
      return HabitPeriod.EBBINGHAUS;
    }
    if (habit.goal.window === 'WEEK') return HabitPeriod.WEEKLY;
    if (habit.goal.window === 'MONTH') return HabitPeriod.MONTHLY;
    return HabitPeriod.DAILY;
  }

  private scheduleForLegacy(period: HabitPeriod, startOn: string, weekdaysMask: number = 127): KmpHabitSchedulePayload {
    if (period === HabitPeriod.ONCE) {
      return { kind: 'ONCE', startOn: startOn, endOn: null, weekdaysMask: null, algorithmKey: null };
    }
    if (period === HabitPeriod.EBBINGHAUS) {
      return {
        kind: 'ALGORITHM',
        startOn: startOn,
        endOn: null,
        weekdaysMask: null,
        algorithmKey: 'EBBINGHAUS_CLASSIC_V1'
      };
    }
    return {
      kind: 'WEEKLY_DAYS',
      startOn: startOn,
      endOn: null,
      weekdaysMask: this.normalizedWeekdaysMask(weekdaysMask),
      algorithmKey: null
    };
  }

  private scheduleForUpdate(habit: Habit, current: KmpHabitPayload): KmpHabitSchedulePayload {
    if (habit.period === HabitPeriod.ONCE || habit.period === HabitPeriod.EBBINGHAUS) {
      if (habit.period === this.periodForPayload(current)) return current.schedule;
      return this.scheduleForLegacy(habit.period, current.schedule.startOn);
    }
    const weekdaysMask: number = habit.weekdaysMask === null || habit.weekdaysMask === undefined
      ? current.schedule.weekdaysMask ?? 127
      : habit.weekdaysMask;
    return {
      kind: 'WEEKLY_DAYS',
      startOn: current.schedule.startOn,
      endOn: current.schedule.endOn,
      weekdaysMask: this.normalizedWeekdaysMask(weekdaysMask),
      algorithmKey: null
    };
  }

  private normalizedWeekdaysMask(value: number): number {
    const masked: number = value & 127;
    return masked === 0 ? 127 : masked;
  }

  private goalForLegacy(
    period: HabitPeriod,
    timesPerPeriod: number,
    goalType: HabitGoalType,
    totalTarget: number | null
  ): KmpHabitGoalPayload {
    let window: string = 'SCHEDULED_DAY';
    if (goalType === HabitGoalType.TOTAL) window = 'LIFETIME';
    else if (period === HabitPeriod.WEEKLY) window = 'WEEK';
    else if (period === HabitPeriod.MONTHLY) window = 'MONTH';
    const targetCount: number = goalType === HabitGoalType.TOTAL && totalTarget !== null
      ? Math.max(1, totalTarget)
      : Math.max(1, timesPerPeriod);
    return { window: window, targetCount: targetCount };
  }

  private trackingForTarget(target: number | null): KmpHabitTrackingPayload {
    return {
      mode: target === null || target <= 1 ? 'CHECK_OFF' : 'QUANTITY',
      unit: null,
      defaultIncrement: 1
    };
  }

  private trackingForUpdate(habit: Habit, current: KmpHabitTrackingPayload): KmpHabitTrackingPayload {
    const target: number | null = habit.goalType === HabitGoalType.TOTAL ? habit.totalTarget : habit.timesPerPeriod;
    const mode: string = target === null || target <= 1 ? 'CHECK_OFF' : 'QUANTITY';
    return {
      mode: mode,
      unit: current.unit,
      defaultIncrement: mode === 'CHECK_OFF' ? 1 : Math.max(1, current.defaultIncrement)
    };
  }

  private async projectRecords(records: KmpHabitRecordPayload[], habitUid: string, startDate: string, endDate: string): Promise<HabitRecord[]> {
    const result: HabitRecord[] = [];
    for (let index = 0; index < records.length; index++) {
      const record: KmpHabitRecordPayload = records[index];
      if (record.isDeleted || (habitUid.length > 0 && record.habitUid !== habitUid) || record.occurredOn < startDate || record.occurredOn > endDate) continue;
      result.push({
        id: await this.recordIdFor(record.uid),
        habitId: await this.habitIdFor(record.habitUid),
        date: record.occurredOn,
        count: record.count,
        status: record.status,
        createdAt: record.createdAt
      });
    }
    return result;
  }

  private async rawHabitForId(id: number): Promise<KmpHabitPayload | null> {
    return this.rawHabitForIdFromState(this.currentState(), id);
  }

  private async rawHabitForIdFromState(state: KmpHabitStatePayload, id: number): Promise<KmpHabitPayload | null> {
    for (let index = 0; index < state.habits.length; index++) {
      const habit: KmpHabitPayload = state.habits[index];
      if (!habit.isDeleted && await this.habitIdFor(habit.uid) === id) return habit;
    }
    return null;
  }

  private readState(payload: string): KmpHabitStatePayload {
    const parsed: KmpHabitStatePayload = JSON.parse(payload) as KmpHabitStatePayload;
    return parsed;
  }

  private currentState(): KmpHabitStatePayload {
    const revision: number = AppStorage.get<number>('KmpDataRevision') ?? 0;
    if (this.stateCache === null || this.stateRevision !== revision) {
      this.stateCache = this.readState(this.persistence.habitStateJson());
      this.stateRevision = revision;
    }
    return this.stateCache;
  }

  private invalidateState(): void {
    this.stateCache = null;
  }

  private async bindLegacyNumericIds(identifiers: LegacyHabitIdentifier[]): Promise<void> {
    const store: preferences.Preferences = this.requireStore();
    let nextId: number = this.validNumber(await store.get(KmpHabitRepositoryAdapter.NEXT_ID_KEY, KmpHabitRepositoryAdapter.FIRST_SYNTHETIC_ID));
    for (let index = 0; index < identifiers.length; index++) {
      const identifier: LegacyHabitIdentifier = identifiers[index];
      await store.put(KmpHabitRepositoryAdapter.HABIT_ID_PREFIX + identifier.taskUid, identifier.habitId);
      await this.taskAdapter.markHabitUid(identifier.taskUid);
      if (identifier.habitId >= nextId) nextId = identifier.habitId + 1;
    }
    await store.put(KmpHabitRepositoryAdapter.NEXT_ID_KEY, nextId);
    await store.flush();
  }

  private async habitIdFor(uid: string): Promise<number> {
    return this.idFor(KmpHabitRepositoryAdapter.HABIT_ID_PREFIX, uid);
  }

  private async recordIdFor(uid: string): Promise<number> {
    return this.idFor(KmpHabitRepositoryAdapter.RECORD_ID_PREFIX, uid);
  }

  private async idFor(prefix: string, uid: string): Promise<number> {
    const store: preferences.Preferences = this.requireStore();
    const key: string = prefix + uid;
    const stored: preferences.ValueType = await store.get(key, 0);
    if (typeof stored === 'number' && stored > 0) return stored;
    const id: number = this.validNumber(await store.get(KmpHabitRepositoryAdapter.NEXT_ID_KEY, KmpHabitRepositoryAdapter.FIRST_SYNTHETIC_ID));
    await store.put(key, id);
    await store.put(KmpHabitRepositoryAdapter.NEXT_ID_KEY, id + 1);
    await store.flush();
    return id;
  }

  private requireStore(): preferences.Preferences {
    if (this.store === null) throw new Error('KMP habit compatibility store is not initialized');
    return this.store;
  }

  private validNumber(value: preferences.ValueType): number {
    return typeof value === 'number' && value > 0 ? value : KmpHabitRepositoryAdapter.FIRST_SYNTHETIC_ID;
  }
}
