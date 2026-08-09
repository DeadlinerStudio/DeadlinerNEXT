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

interface KmpHabitPayload {
  uid: string;
  name: string;
  description: string | null;
  color: number | null;
  iconKey: string | null;
  categoryUid: string | null;
  period: HabitPeriod;
  timesPerPeriod: number;
  goalType: HabitGoalType;
  totalTarget: number | null;
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

interface KmpHabitStatePayload {
  habits: KmpHabitPayload[];
  records: KmpHabitRecordPayload[];
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
    categoryUid: string | null = null
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
      period: period,
      timesPerPeriod: timesPerPeriod,
      goalType: goalType,
      totalTarget: totalTarget,
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

  public async update(habit: Habit): Promise<boolean> {
    const current: KmpHabitPayload | null = await this.rawHabitForId(habit.id);
    if (current === null) return false;
    const categoryChanged: boolean = habit.categoryUid !== current.categoryUid;
    const updated: KmpHabitPayload = {
      uid: current.uid,
      name: habit.name,
      description: habit.description,
      color: habit.color,
      iconKey: habit.iconKey,
      categoryUid: current.categoryUid,
      period: habit.period,
      timesPerPeriod: habit.timesPerPeriod,
      goalType: habit.goalType,
      totalTarget: habit.totalTarget,
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
    this.persistence.habitDeleteJson(habit.uid, new Date().toISOString());
    this.invalidateState();
    return true;
  }

  public async setArchived(id: number, archived: boolean): Promise<boolean> {
    const habit: KmpHabitPayload | null = await this.rawHabitForId(id);
    if (habit === null) return false;
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
    return {
      id: await this.habitIdFor(habit.uid),
      ddlId: await this.taskAdapter.legacyTaskIdForUid(habit.uid),
      name: habit.name,
      description: habit.description,
      color: habit.color,
      iconKey: habit.iconKey,
      categoryUid: habit.categoryUid,
      period: habit.period,
      timesPerPeriod: habit.timesPerPeriod,
      goalType: habit.goalType,
      totalTarget: habit.totalTarget,
      createdAt: habit.createdAt,
      updatedAt: habit.updatedAt,
      status: habit.status,
      sortOrder: habit.sortOrder,
      alarmTime: habit.reminder === null ? null : habit.reminder.localTime
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
