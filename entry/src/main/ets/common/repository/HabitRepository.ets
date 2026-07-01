import { DatabaseHelper } from '../data/DatabaseHelper';
import {
  Habit, HabitPeriod, HabitGoalType, HabitRecord, HabitRecordStatus, HabitStatus
} from '../../model/DDLModels'; // 假设你的路径
import { ReminderScheduler } from '../../utils/notification/ReminderScheduler';
import { TaskRepository } from './TaskRepository';

export class HabitRepository {
  private static instance: HabitRepository;
  private db: DatabaseHelper;

  private reminderUpdateTimer: number = -1;

  private constructor() {
    this.db = DatabaseHelper.getInstance();
  }

  public static getInstance(): HabitRepository {
    if (!HabitRepository.instance) {
      HabitRepository.instance = new HabitRepository();
    }
    return HabitRepository.instance;
  }

  // ================= Helper: Date Formatting =================
  private formatDate(date: Date): string {
    const y = date.getFullYear();
    const m = (date.getMonth() + 1).toString().padStart(2, '0');
    const d = date.getDate().toString().padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

  private nowISO(): string {
    return new Date().toISOString();
  }

  // ================= Habit 本体 =================

  async createHabitForDdl(
    ddlId: number,
    name: string,
    period: HabitPeriod,
    timesPerPeriod: number = 1,
    goalType: HabitGoalType = HabitGoalType.PER_PERIOD,
    totalTarget: number | null = null,
    description: string = "",
    color: number | null = null,
    iconKey: string | null = null,
    sortOrder: number = 0,
    alarmTime: string | null = null
  ): Promise<number> {
    const now = this.nowISO();
    const habit: Habit = {
      id: 0, // Auto-increment handled by DB
      ddlId: ddlId,
      name: name,
      description: description,
      color: color,
      iconKey: iconKey,
      period: period,
      timesPerPeriod: timesPerPeriod,
      goalType: goalType,
      totalTarget: totalTarget,
      createdAt: now,
      updatedAt: now,
      status: HabitStatus.ACTIVE,
      sortOrder: sortOrder,
      alarmTime: alarmTime
    };
    const id = await this.db.insertHabit(habit);
    this.scheduleReminderRefresh();
    this.triggerDataSync();
    return id;
  }

  async getHabitByDdlId(ddlId: number): Promise<Habit | null> {
    return await this.db.getHabitByDdlId(ddlId);
  }

  async getHabitById(id: number): Promise<Habit | null> {
    return await this.db.getHabitById(id);
  }

  async getAllHabits(): Promise<Habit[]> {
    return await this.db.getAllHabits();
  }

  async getArchivedHabits(): Promise<Habit[]> {
    return await this.db.getArchivedHabits();
  }

  async updateHabit(habit: Habit): Promise<void> {
    const now = this.nowISO();

    const updated: Habit = {
      id: habit.id,
      ddlId: habit.ddlId,
      name: habit.name,
      description: habit.description,
      color: habit.color,
      iconKey: habit.iconKey,
      period: habit.period,
      timesPerPeriod: habit.timesPerPeriod,
      goalType: habit.goalType,
      totalTarget: habit.totalTarget,
      createdAt: habit.createdAt,
      updatedAt: now,
      status: habit.status,
      sortOrder: habit.sortOrder,
      alarmTime: habit.alarmTime
    };

    await this.db.updateHabit(updated);
    this.scheduleReminderRefresh();
    this.triggerDataSync();
  }

  async deleteHabitByDdlId(ddlId: number): Promise<void> {
    await this.db.deleteHabitByDdlId(ddlId);
    this.scheduleReminderRefresh();
    this.triggerDataSync();
  }

  async unarchiveHabit(habitId: number): Promise<void> {
    const habit = await this.db.getHabitById(habitId);
    if (!habit) {
      throw new Error(`[HabitRepository] Habit not found: ${habitId}`);
    }

    const updated: Habit = {
      id: habit.id,
      ddlId: habit.ddlId,
      name: habit.name,
      description: habit.description,
      color: habit.color,
      iconKey: habit.iconKey,
      period: habit.period,
      timesPerPeriod: habit.timesPerPeriod,
      goalType: habit.goalType,
      totalTarget: habit.totalTarget,
      createdAt: habit.createdAt,
      updatedAt: this.nowISO(),
      status: HabitStatus.ACTIVE,
      sortOrder: habit.sortOrder,
      alarmTime: habit.alarmTime
    };

    await this.db.updateHabit(updated);
    this.scheduleReminderRefresh();
    this.triggerDataSync();
  }

  // ================= Habit 打卡记录 =================

  async getRecordsForHabitOnDate(habitId: number, date: Date): Promise<HabitRecord[]> {
    return await this.db.getHabitRecordsForHabitOnDate(habitId, this.formatDate(date));
  }

  async getRecordsForDate(date: Date): Promise<HabitRecord[]> {
    return await this.db.getHabitRecordsForDate(this.formatDate(date));
  }

  async getRecordsForHabitInRange(
    habitId: number,
    startDate: Date,
    endDateInclusive: Date
  ): Promise<HabitRecord[]> {
    return await this.db.getHabitRecordsForHabitInRange(
      habitId,
      this.formatDate(startDate),
      this.formatDate(endDateInclusive)
    );
  }

  async insertRecord(
    habitId: number,
    date: Date,
    count: number = 1,
    status: HabitRecordStatus = HabitRecordStatus.COMPLETED
  ): Promise<number> {
    const record: HabitRecord = {
      id: 0,
      habitId: habitId,
      date: this.formatDate(date),
      count: count,
      status: status,
      createdAt: this.nowISO()
    };
    const id = await this.db.insertHabitRecord(record);
    this.triggerDataSync();
    return id;
  }

  async deleteRecordsForHabitOnDate(habitId: number, date: Date): Promise<void> {
    await this.db.deleteHabitRecordsForHabitOnDate(habitId, this.formatDate(date));
    this.triggerDataSync();
  }

  async getCompletedIdsForDate(date: Date): Promise<Set<number>> {
    const records = await this.getRecordsForDate(date);
    const set = new Set<number>();
    records.forEach(r => {
      if (r.status === HabitRecordStatus.COMPLETED) {
        set.add(r.habitId);
      }
    });
    return set;
  }

  // ================= Logic: Period Calculation =================

  periodBounds(period: HabitPeriod, date: Date): [Date, Date] {
    const d = new Date(date); // Clone
    d.setHours(0, 0, 0, 0);

    if (period === HabitPeriod.DAILY) {
      return [d, d];
    } else if (period === HabitPeriod.WEEKLY) {
      // Find Monday. getDay(): 0 is Sunday, 1 is Monday...
      const day = d.getDay();
      const diff = d.getDate() - day + (day === 0 ? -6 : 1); // adjust when day is sunday
      const monday = new Date(d.setDate(diff));

      const sunday = new Date(monday);
      sunday.setDate(monday.getDate() + 6);
      return [monday, sunday];
    } else if (period === HabitPeriod.MONTHLY) {
      const firstDay = new Date(d.getFullYear(), d.getMonth(), 1);
      const lastDay = new Date(d.getFullYear(), d.getMonth() + 1, 0);
      return [firstDay, lastDay];
    }
    return [d, d];
  }

  // ================= Logic: Toggle =================

  /**
   * 切换某天某个习惯的完成状态
   * v2.0 更新：适配 ONCE (单次) 和 EBBINGHAUS (艾宾浩斯)
   */
  async toggleRecord(habitId: number, date: Date): Promise<void> {
    const habit = await this.db.getHabitById(habitId);
    if (!habit) return;

    const recordsToday = (await this.db.getHabitRecordsForHabitOnDate(habitId, this.formatDate(date)))
      .filter(r => r.status === HabitRecordStatus.COMPLETED);
    const todayCount = recordsToday.reduce((sum, r) => sum + r.count, 0);

    if (habit.period === HabitPeriod.DAILY) {
      // === DAILY: 每日累积模式 ===
      // 支持每日多次打卡（例如 timesPerPeriod=3），点击一次累加一次。
      const target = Math.max(1, habit.timesPerPeriod);
      if (todayCount >= target && habit.goalType === HabitGoalType.PER_PERIOD) {
        // 每日目标已达标：保持现有策略，不再继续累加
      } else {
        await this.db.insertHabitRecord({
          id: 0,
          habitId: habitId,
          date: this.formatDate(date),
          count: 1,
          status: HabitRecordStatus.COMPLETED,
          createdAt: new Date().toISOString()
        });
      }
    } else if (habit.period === HabitPeriod.ONCE ||
      habit.period === HabitPeriod.EBBINGHAUS) {

      // === 简单模式 (0/1) ===
      // ONCE: 一次性任务，打完即止（但在 Repo 层我们只管记录状态，UI 层负责隐藏）
      // EBBINGHAUS: 到了节点打一次

      if (todayCount > 0) {
        // 只有已经打卡了，取消打卡 (Toggle Off)
        await this.db.deleteHabitRecordsForHabitOnDate(habitId, this.formatDate(date));
      } else {
        // 还没打卡，打卡 (Toggle On)
        await this.db.insertHabitRecord({
          id: 0,
          habitId: habitId,
          date: this.formatDate(date),
          count: 1,
          status: HabitRecordStatus.COMPLETED,
          createdAt: new Date().toISOString()
        });
      }

    } else {
      // === 累积模式 (Weekly/Monthly) ===
      // 需要计算周期内的总数
      const target = Math.max(1, habit.timesPerPeriod);
      const periodBounds = this.periodBounds(habit.period, date);
      const start = periodBounds[0];
      const endInclusive = periodBounds[1];

      const recordsInPeriod = (await this.db.getHabitRecordsForHabitInRange(
        habitId,
        this.formatDate(start),
        this.formatDate(endInclusive)
      )).filter(r => r.status === HabitRecordStatus.COMPLETED);

      const totalInPeriod = recordsInPeriod.reduce((sum, r) => sum + r.count, 0);

      if (todayCount > 0) {
        // 今天打过卡 -> 撤销今天
        await this.db.deleteHabitRecordsForHabitOnDate(habitId, this.formatDate(date));
      } else {
        // 今天没打过卡
        if (totalInPeriod >= target && habit.goalType === HabitGoalType.PER_PERIOD) {
          // 目标已达标 -> 通常阻止打卡，或者允许超额打卡？
          // 现有逻辑：如果达标了就不操作 (no-op)。或者你可以允许它继续打卡。
          // 这里保持原逻辑：达标后若要强制打卡需改逻辑，目前是不操作。
        } else {
          // 未达标 -> 打卡
          await this.db.insertHabitRecord({
            id: 0,
            habitId: habitId,
            date: this.formatDate(date),
            count: 1,
            status: HabitRecordStatus.COMPLETED,
            createdAt: new Date().toISOString()
          });
        }
      }
    }

    // 触发提醒更新
    this.scheduleReminderRefresh();
    this.triggerDataSync();
  }

  public async initialReminderCheck() {
    console.info('[HabitRepo] Performing initial habit reminder check...');
    this.scheduleReminderRefresh();
  }

  private scheduleReminderRefresh() {
    if (this.reminderUpdateTimer !== -1) {
      clearTimeout(this.reminderUpdateTimer);
    }
    // 延迟 1 秒执行，合并短时间内的多次变更
    this.reminderUpdateTimer = setTimeout(() => {
      this.performReminderRefresh();
    }, 1000);
  }

  private triggerDataSync() {
    TaskRepository.getInstance().triggerExternalUpdates();
  }

  /**
   * 执行提醒刷新
   */
  private async performReminderRefresh() {
    try {
      console.info('[HabitRepo] Triggering Habit Reminder Scheduler...');

      // 1. 获取所有习惯
      // Scheduler 内部会负责过滤 active 状态和是否有 alarmTime
      const allHabits = await this.getAllHabits();

      // 2. 交给调度器刷新
      await ReminderScheduler.refreshHabits(allHabits);

    } catch (e) {
      console.error(`[HabitRepo] Habit reminder refresh failed: ${e}`);
    } finally {
      this.reminderUpdateTimer = -1;
    }
  }
}
