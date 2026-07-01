import { LocalValues } from "../common/local/LocalValues";
import { HabitRepository } from "../common/repository/HabitRepository";
import { InspirationRepository } from "../common/repository/InspirationRepository";
import { TaskRepository } from "../common/repository/TaskRepository";
import { DDLItem, DeadlineType, Habit, HabitGoalType, HabitRecordStatus, HabitStatus, HabitPeriod } from "../model/DDLModels";
import { InspirationItem } from "../model/InspirationModels";
import { DDLStatus } from "../model/DDLStatus";
import { HabitWithDailyStatus } from "../pages/components/HabitComponents";
import { TaskState, TaskStateMachine } from "../model/TaskStateMachine";

export interface TaskUIModel {
  title: string;
  remainingTimeAlt: string;
  note: string;
  progress: number;
  isStarred: boolean;
  status: DDLStatus;
  dbId: number;
  taskState: TaskState;
  originalItem: DDLItem;
}

// [新增] 统一归档搜索结果的数据模型，适配 ArchivedDDLItemCard
export interface ArchivedSearchModel {
  id: string;             // 唯一键
  title: string;
  detail1: string;        // 对应卡片的 startTime (左下角信息)
  detail2: string;        // 对应卡片的 completeTime (右下角信息)
  note: string;
  badgeText: string;
  originalType: 'task' | 'habit';
  originalItem: DDLItem | Habit;
}

interface SearchResult {
  tasks: TaskUIModel[];
  habits: HabitWithDailyStatus[];
  inspirations: InspirationItem[];
  archived: ArchivedSearchModel[]; // [新增] 归档结果集
}

export class SearchUtils {
  private static instance: SearchUtils;
  private taskRepo = TaskRepository.getInstance();
  private habitRepo = HabitRepository.getInstance();
  private inspirationRepo = InspirationRepository.getInstance();

  private allTasksCache: DDLItem[] = [];
  private allHabitsCache: Habit[] = [];
  private allInspirationsCache: InspirationItem[] = [];

  public static getInstance(): SearchUtils {
    if (!SearchUtils.instance) {
      SearchUtils.instance = new SearchUtils();
    }
    return SearchUtils.instance;
  }

  async preloadData(): Promise<void> {
    try {
      const tasks = await this.taskRepo.getDDLsByType(DeadlineType.TASK);
      this.allTasksCache = tasks.filter(t => !t.deleted); // 加载所有未彻底删除的任务

      const habits = await this.habitRepo.getAllHabits();
      this.allHabitsCache = habits; // 加载所有习惯

      const inspirations = await this.inspirationRepo.getAllInspirations();
      this.allInspirationsCache = inspirations;
    } catch (e) {
      console.error('[SearchLogic] Preload failed:', e);
    }
  }

  async executeSearch(query: string): Promise<SearchResult> {
    if (!query || query.trim() === '') {
      return { tasks: [], habits: [], inspirations: [], archived: [] };
    }

    const lowerValue = query.toLowerCase().trim();

    // ---------------------------------------------------------
    // 1. 筛选数据源
    // ---------------------------------------------------------

    // A. 任务
    const matchedTasks = this.allTasksCache.filter(item =>
    item.name.toLowerCase().includes(lowerValue) ||
      (item.note && item.note.toLowerCase().includes(lowerValue))
    );

    // B. 习惯
    const matchedHabits = this.allHabitsCache.filter(item =>
    item.name.toLowerCase().includes(lowerValue) ||
      (item.description && item.description.toLowerCase().includes(lowerValue))
    );

    const matchedInspirations = this.allInspirationsCache.filter(item =>
      item.text.toLowerCase().includes(lowerValue)
    );

    // ---------------------------------------------------------
    // 2. 分类处理 (活跃 vs 归档)
    // ---------------------------------------------------------

    // --- 活跃任务 ---
    const activeTasks = matchedTasks.filter(t => TaskStateMachine.isVisibleInMainList(t.state));
    activeTasks.sort((a, b) => this.taskPriority(a.state) - this.taskPriority(b.state));
    const taskResults = activeTasks.map(t => this.mapTaskToUI(t));

    // --- 活跃习惯 ---
    const activeHabits = matchedHabits.filter(h => h.status !== HabitStatus.ARCHIVED);
    const today = new Date();
    const habitResults = await Promise.all(
      activeHabits.map(h => this.buildHabitStatusForDate(h, today))
    );

    // --- 归档内容 (混合任务和习惯) ---
    const archivedTasks = matchedTasks.filter(t => TaskStateMachine.isVisibleInArchiveList(t.state));
    const archivedHabits = matchedHabits.filter(h => h.status === HabitStatus.ARCHIVED);

    const archivedResults: ArchivedSearchModel[] = [
      ...archivedTasks.map(t => this.mapArchivedTask(t)),
      ...archivedHabits.map(h => this.mapArchivedHabit(h))
    ];

    // 归档排序：最新的归档/完成时间在前 (模拟 ArchivePanel 逻辑)
    // 这里简单处理，如果需要更复杂的混合排序，可解析 detail2 中的日期
    archivedResults.sort((a, b) => b.id.localeCompare(a.id));

    return { tasks: taskResults, habits: habitResults, inspirations: matchedInspirations, archived: archivedResults };
  }

  // --- Helpers ---

  // [新增] 映射归档任务
  private mapArchivedTask(item: DDLItem): ArchivedSearchModel {
    return {
      id: `task_${item.id}`,
      title: item.name,
      detail1: this.formatDate(item.startTime),
      detail2: this.formatDate(item.completeTime),
      note: item.note || "",
      badgeText: TaskStateMachine.archiveBadgeText(item.state),
      originalType: 'task',
      originalItem: item
    };
  }

  // [新增] 映射归档习惯
  private mapArchivedHabit(item: Habit): ArchivedSearchModel {
    let periodStr = '';
    switch (item.period) {
      case HabitPeriod.DAILY: periodStr = '每日'; break;
      case HabitPeriod.WEEKLY: periodStr = '每周'; break;
      case HabitPeriod.MONTHLY: periodStr = '每月'; break;
    }
    let goalStr = item.goalType === HabitGoalType.TOTAL ? `总目标 ${item.totalTarget}` : `${item.timesPerPeriod}次`;

    return {
      id: `habit_${item.id}`,
      title: item.name,
      detail1: `${periodStr} · ${goalStr}`,
      detail2: `归档于 ${this.formatDate(item.updatedAt)}`,
      note: item.description || "无备注",
      badgeText: '习惯归档',
      originalType: 'habit',
      originalItem: item
    };
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

  // ... mapTaskToUI 和 buildHabitStatusForDate 保持原样 ...
  private mapTaskToUI(item: DDLItem): TaskUIModel {
    // (保留原有代码逻辑)
    const now = new Date().getTime();
    const start = item.startTime ? new Date(item.startTime).getTime() : 0;
    const end = item.endTime ? new Date(item.endTime).getTime() : 0;
    let status = DDLStatus.UNDERGO;
    if (item.state === TaskState.COMPLETED || item.state === TaskState.ARCHIVED) status = DDLStatus.COMPLETED;
    else if (item.state === TaskState.ABANDONED || item.state === TaskState.ABANDONED_ARCHIVED) status = DDLStatus.ABANDONED;
    else if (now > end) status = DDLStatus.PASSED;
    else if ((end - now) < 24 * 60 * 60 * 1000) status = DDLStatus.NEAR;

    let progress = 0.0;
    if (item.state === TaskState.COMPLETED || item.state === TaskState.ARCHIVED) progress = 1.0;
    else {
      const totalDuration = end - start;
      const elapsed = now - start;
      if (totalDuration > 0) progress = Math.max(0, Math.min(1, elapsed / totalDuration));
    }

    let timeText = "进行中";
    if (item.state === TaskState.COMPLETED || item.state === TaskState.ARCHIVED) timeText = "已完成";
    if (item.state === TaskState.ABANDONED || item.state === TaskState.ABANDONED_ARCHIVED) timeText = "已放弃";

    const progressDir = LocalValues.getInstance().getProgressDir();
    const displayProgress = progressDir ? progress : 1.0 - progress;

    return {
      title: item.name,
      remainingTimeAlt: timeText,
      note: item.note || "",
      progress: displayProgress,
      isStarred: item.isStared,
      status: status,
      dbId: item.id,
      taskState: item.state,
      originalItem: item
    };
  }

  private taskPriority(state: TaskState): number {
    if (state === TaskState.ACTIVE) return 0;
    if (state === TaskState.COMPLETED) return 1;
    if (state === TaskState.ABANDONED) return 2;
    return 9;
  }

  private async buildHabitStatusForDate(habit: Habit, date: Date): Promise<HabitWithDailyStatus> {
    const periodBounds = this.habitRepo.periodBounds(habit.period, date);
    const start = periodBounds[0];
    const end = periodBounds[1];
    const queryStart = habit.goalType === HabitGoalType.TOTAL ? new Date(0) : start;
    const queryEnd = habit.goalType === HabitGoalType.TOTAL ? date : end;
    const records = await this.habitRepo.getRecordsForHabitInRange(habit.id, queryStart, queryEnd);
    const done = records.filter(r => r.status === HabitRecordStatus.COMPLETED).reduce((sum, r) => sum + r.count, 0);
    let target = Math.max(1, habit.timesPerPeriod);
    if (habit.goalType === HabitGoalType.TOTAL) target = habit.totalTarget ? Math.max(1, habit.totalTarget) : Math.max(1, done);
    return { habit: habit, doneCount: done, targetCount: target, isCompleted: done >= target };
  }
}
