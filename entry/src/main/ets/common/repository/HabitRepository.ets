import { AppLog } from '../logging/AppLog';
import { Habit, HabitPeriod, HabitGoalType, HabitRecord, HabitRecordStatus } from '../../model/DDLModels';
import { ReminderScheduler } from '../../utils/notification/ReminderScheduler';
import { TaskRepository } from './TaskRepository';
import { common } from '@kit.AbilityKit';
import { KmpTaskRepositoryAdapter } from '../kmp/KmpTaskRepositoryAdapter';
import {
  HabitPresentationState,
  KmpHabitRepositoryAdapter
} from '../kmp/KmpHabitRepositoryAdapter';
import { KmpMigrationService } from '../migration/KmpMigrationService';
import { KmpAutomaticSyncConfigurator } from '../kmp/KmpAutomaticSyncConfigurator';

/** KMP is the sole habit and record source; this class preserves the existing ArkTS API. */
export class HabitRepository {
  private static instance: HabitRepository;
  private context: common.Context | null = null;
  private readonly kmpTaskAdapter: KmpTaskRepositoryAdapter = new KmpTaskRepositoryAdapter();
  private readonly kmpHabits: KmpHabitRepositoryAdapter = new KmpHabitRepositoryAdapter(this.kmpTaskAdapter);
  private reminderUpdateTimer: number = -1;

  private constructor() {}

  public static getInstance(): HabitRepository {
    if (!HabitRepository.instance) HabitRepository.instance = new HabitRepository();
    return HabitRepository.instance;
  }

  public setContext(context: common.Context): void {
    this.context = context;
  }

  private async initializeKmp(): Promise<void> {
    if (this.context === null) throw new Error('HabitRepository context is required for KMP persistence');
    await KmpMigrationService.getInstance().awaitReady();
    await this.kmpTaskAdapter.initialize(this.context);
    await this.kmpHabits.initialize(this.context);
    KmpAutomaticSyncConfigurator.getInstance().configure();
  }

  private formatDate(date: Date): string {
    const year: string = date.getFullYear().toString();
    const month: string = (date.getMonth() + 1).toString().padStart(2, '0');
    const day: string = date.getDate().toString().padStart(2, '0');
    return year + '-' + month + '-' + day;
  }

  public async createHabitForDdl(
    ddlId: number,
    name: string,
    period: HabitPeriod,
    timesPerPeriod: number = 1,
    goalType: HabitGoalType = HabitGoalType.PER_PERIOD,
    totalTarget: number | null = null,
    description: string = '',
    color: number | null = null,
    iconKey: string | null = null,
    sortOrder: number = 0,
    alarmTime: string | null = null,
    categoryUid: string | null = null,
    weekdaysMask: number = 127
  ): Promise<number> {
    await this.initializeKmp();
    const uid: string | null = await this.kmpTaskAdapter.taskUidForLegacyId(ddlId);
    const id: number = await this.kmpHabits.create(
      name, period, timesPerPeriod, goalType, totalTarget, description, color, iconKey, sortOrder, alarmTime, uid,
      categoryUid, weekdaysMask
    );
    if (uid !== null) await this.kmpTaskAdapter.deleteHabitCarrierIfPresent(uid);
    this.scheduleReminderRefresh();
    this.triggerDataSync();
    return id;
  }

  public async repairLegacyTaskCarriers(): Promise<number> {
    await this.initializeKmp();
    const repaired: number = await this.kmpHabits.repairLegacyTaskCarriers();
    if (repaired > 0) {
      AppLog.info('Native', '[HabitRepo] Removed legacy task carriers: ' + repaired.toString());
      this.triggerDataSync();
    }
    return repaired;
  }

  public async createHabit(
    name: string,
    period: HabitPeriod,
    timesPerPeriod: number = 1,
    goalType: HabitGoalType = HabitGoalType.PER_PERIOD,
    totalTarget: number | null = null,
    description: string = '',
    color: number | null = null,
    iconKey: string | null = null,
    sortOrder: number = 0,
    alarmTime: string | null = null,
    categoryUid: string | null = null,
    weekdaysMask: number = 127
  ): Promise<number> {
    await this.initializeKmp();
    const id: number = await this.kmpHabits.create(
      name, period, timesPerPeriod, goalType, totalTarget, description, color, iconKey, sortOrder, alarmTime, null,
      categoryUid, weekdaysMask
    );
    this.scheduleReminderRefresh();
    this.triggerDataSync();
    return id;
  }

  public async getHabitByDdlId(ddlId: number): Promise<Habit | null> {
    await this.initializeKmp();
    return this.kmpHabits.findByDdlId(ddlId);
  }

  public async getHabitById(id: number): Promise<Habit | null> {
    await this.initializeKmp();
    return this.kmpHabits.findById(id);
  }

  public async getAllHabits(): Promise<Habit[]> {
    await this.initializeKmp();
    return this.kmpHabits.listActive();
  }

  public async getArchivedHabits(): Promise<Habit[]> {
    await this.initializeKmp();
    return this.kmpHabits.listArchived();
  }

  public async getPresentationForDate(date: Date): Promise<HabitPresentationState> {
    await this.initializeKmp();
    return this.kmpHabits.presentationForDate(this.formatDate(date));
  }

  public async updateHabit(habit: Habit): Promise<void> {
    await this.initializeKmp();
    if (!await this.kmpHabits.update(habit)) throw new Error('KMP habit not found for update');
    this.scheduleReminderRefresh();
    this.triggerDataSync();
  }

  public async updateHabitCategory(habitId: number, categoryUid: string | null): Promise<void> {
    await this.initializeKmp();
    if (!await this.kmpHabits.updateCategory(habitId, categoryUid)) {
      throw new Error('KMP habit not found for category update');
    }
    this.triggerDataSync();
  }

  public async deleteHabitByDdlId(ddlId: number): Promise<void> {
    await this.initializeKmp();
    if (!await this.kmpHabits.deleteByDdlId(ddlId)) throw new Error('KMP habit not found for deletion');
    this.scheduleReminderRefresh();
    this.triggerDataSync();
  }

  public async unarchiveHabit(habitId: number): Promise<void> {
    await this.initializeKmp();
    if (!await this.kmpHabits.setArchived(habitId, false)) throw new Error('KMP habit not found for restore');
    this.scheduleReminderRefresh();
    this.triggerDataSync();
  }

  public async archiveHabit(habitId: number): Promise<void> {
    await this.initializeKmp();
    if (!await this.kmpHabits.setArchived(habitId, true)) throw new Error('KMP habit not found for archive');
    this.scheduleReminderRefresh();
    this.triggerDataSync();
  }

  public async getRecordsForHabitOnDate(habitId: number, date: Date): Promise<HabitRecord[]> {
    await this.initializeKmp();
    return this.kmpHabits.recordsForHabitOnDate(habitId, this.formatDate(date));
  }

  public async getRecordsForDate(date: Date): Promise<HabitRecord[]> {
    await this.initializeKmp();
    return this.kmpHabits.recordsForDate(this.formatDate(date));
  }

  public async getRecordsForHabitInRange(habitId: number, startDate: Date, endDateInclusive: Date): Promise<HabitRecord[]> {
    await this.initializeKmp();
    return this.kmpHabits.recordsForHabitInRange(habitId, this.formatDate(startDate), this.formatDate(endDateInclusive));
  }

  public async insertRecord(
    habitId: number,
    date: Date,
    count: number = 1,
    status: HabitRecordStatus = HabitRecordStatus.COMPLETED
  ): Promise<number> {
    await this.initializeKmp();
    const id: number = await this.kmpHabits.insertRecord(habitId, this.formatDate(date), count, status);
    if (id > 0) this.triggerDataSync();
    return id;
  }

  public async deleteRecordsForHabitOnDate(habitId: number, date: Date): Promise<void> {
    await this.initializeKmp();
    if (!await this.kmpHabits.clearRecords(habitId, this.formatDate(date))) {
      throw new Error('KMP habit not found for record deletion');
    }
    this.triggerDataSync();
  }

  public async getCompletedIdsForDate(date: Date): Promise<Set<number>> {
    const records: HabitRecord[] = await this.getRecordsForDate(date);
    const completed: Set<number> = new Set<number>();
    for (let index = 0; index < records.length; index++) {
      if (records[index].status === HabitRecordStatus.COMPLETED) completed.add(records[index].habitId);
    }
    return completed;
  }

  public periodBounds(period: HabitPeriod, date: Date): [Date, Date] {
    const current: Date = new Date(date);
    current.setHours(0, 0, 0, 0);
    if (period === HabitPeriod.DAILY) return [current, current];
    if (period === HabitPeriod.WEEKLY) {
      const day: number = current.getDay();
      const diff: number = current.getDate() - day + (day === 0 ? -6 : 1);
      const monday: Date = new Date(current.setDate(diff));
      const sunday: Date = new Date(monday);
      sunday.setDate(monday.getDate() + 6);
      return [monday, sunday];
    }
    if (period === HabitPeriod.MONTHLY) {
      return [new Date(current.getFullYear(), current.getMonth(), 1), new Date(current.getFullYear(), current.getMonth() + 1, 0)];
    }
    return [current, current];
  }

  public async toggleRecord(habitId: number, date: Date): Promise<void> {
    await this.initializeKmp();
    if (!await this.kmpHabits.toggleRecord(habitId, this.formatDate(date))) throw new Error('KMP habit not found for record toggle');
    this.scheduleReminderRefresh();
    this.triggerDataSync();
  }

  public async initialReminderCheck(): Promise<void> {
    this.scheduleReminderRefresh();
  }

  private scheduleReminderRefresh(): void {
    if (this.reminderUpdateTimer !== -1) clearTimeout(this.reminderUpdateTimer);
    this.reminderUpdateTimer = setTimeout(() => {
      this.performReminderRefresh();
    }, 1000);
  }

  private triggerDataSync(): void {
    TaskRepository.getInstance().triggerExternalUpdates();
  }

  private async performReminderRefresh(): Promise<void> {
    try {
      const state: HabitPresentationState = await this.kmpHabits.presentationForDate(this.formatDate(new Date()));
      await ReminderScheduler.refreshHabits(state.reminderPlans);
    } catch (error) {
      AppLog.error('Native', '[HabitRepo] Reminder refresh failed: ' + String(error));
    } finally {
      this.reminderUpdateTimer = -1;
    }
  }
}
