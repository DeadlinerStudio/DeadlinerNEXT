import { AppLog } from '../common/logging/AppLog';
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

export interface ArchivedSearchModel {
  id: string;
  title: string;
  detail1: string;
  detail2: string;
  note: string;
  badgeText: string;
  originalType: 'task' | 'habit';
  originalItem: DDLItem | Habit;
}

export enum SearchScope {
  ALL = 'all',
  ACTIVE = 'active',
  ARCHIVE = 'archive'
}

export enum SearchBrowseCategory {
  TODAY = 'today',
  UPCOMING = 'upcoming',
  STARRED = 'starred',
  ARCHIVED = 'archived',
  TASKS = 'tasks',
  HABITS = 'habits'
}

export interface EbbinghausState {
  isDue: boolean;
  text: string;
}

export interface SearchResult {
  tasks: TaskUIModel[];
  habits: HabitWithDailyStatus[];
  inspirations: InspirationItem[];
  archivedTasks: ArchivedSearchModel[];
  archivedHabits: ArchivedSearchModel[];
}

interface ScoredTaskMatch {
  item: DDLItem;
  score: number;
}

interface ScoredHabitMatch {
  habit: Habit;
  score: number;
}

interface ScoredInspirationMatch {
  item: InspirationItem;
  score: number;
}

export class SearchUtils {
  private static readonly SEARCH_YIELD_INTERVAL: number = 24;
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
      this.allTasksCache = tasks.filter(t => !t.deleted);

      const habits = await this.habitRepo.getAllHabits();
      this.allHabitsCache = habits;

      const inspirations = await this.inspirationRepo.getAllInspirations();
      this.allInspirationsCache = inspirations;
    } catch (e) {
      AppLog.error('Native', '[SearchLogic] Preload failed:', e);
    }
  }

  async executeSearch(query: string, scope: SearchScope = SearchScope.ALL): Promise<SearchResult> {
    if (!query || query.trim() === '') {
      return this.emptyResult();
    }

    const tokens = this.queryTokens(query);
    const activeTasks = scope === SearchScope.ARCHIVE
      ? []
      : await this.buildActiveTaskResults(tokens);
    await this.yieldToUiThread();

    const activeHabitsRaw = scope === SearchScope.ARCHIVE
      ? []
      : await this.buildActiveHabitMatches(tokens);

    const activeHabits = await Promise.all(
      activeHabitsRaw.map((item) => this.buildHabitStatusForDate(item.habit, new Date()))
    );
    await this.yieldToUiThread();

    const inspirations = scope === SearchScope.ARCHIVE
      ? []
      : await this.buildInspirationResults(tokens);
    await this.yieldToUiThread();

    const archivedTasks = scope === SearchScope.ACTIVE
      ? []
      : await this.buildArchivedTaskResults(tokens);
    await this.yieldToUiThread();

    const archivedHabits = scope === SearchScope.ACTIVE
      ? []
      : await this.buildArchivedHabitResults(tokens);

    return {
      tasks: activeTasks,
      habits: activeHabits,
      inspirations: inspirations,
      archivedTasks: archivedTasks,
      archivedHabits: archivedHabits
    };
  }

  private async yieldToUiThread(): Promise<void> {
    await new Promise<void>((resolve: () => void) => {
      setTimeout(() => resolve(), 0);
    });
  }

  private shouldYield(index: number): boolean {
    return index > 0 && index % SearchUtils.SEARCH_YIELD_INTERVAL === 0;
  }

  private async buildActiveTaskResults(tokens: string[]): Promise<TaskUIModel[]> {
    const matches: ScoredTaskMatch[] = [];

    for (let index = 0; index < this.allTasksCache.length; index++) {
      const item = this.allTasksCache[index];
      if (!TaskStateMachine.isVisibleInMainList(item.state)) {
        continue;
      }

      const score = this.scoreTask(item, tokens, false);
      if (score > 0) {
        matches.push({ item: item, score: score });
      }

      if (this.shouldYield(index)) {
        await this.yieldToUiThread();
      }
    }

    matches.sort((lhs, rhs) => this.compareScoredItems(lhs.score, lhs.item.name, rhs.score, rhs.item.name));
    return matches.map((item) => this.mapTaskToUI(item.item));
  }

  private async buildActiveHabitMatches(tokens: string[]): Promise<ScoredHabitMatch[]> {
    const matches: ScoredHabitMatch[] = [];

    for (let index = 0; index < this.allHabitsCache.length; index++) {
      const habit = this.allHabitsCache[index];
      if (habit.status === HabitStatus.ARCHIVED) {
        continue;
      }

      const score = this.scoreHabit(habit, tokens);
      if (score > 0) {
        matches.push({ habit: habit, score: score });
      }

      if (this.shouldYield(index)) {
        await this.yieldToUiThread();
      }
    }

    matches.sort((lhs, rhs) => this.compareScoredItems(lhs.score, lhs.habit.name, rhs.score, rhs.habit.name));
    return matches;
  }

  private async buildInspirationResults(tokens: string[]): Promise<InspirationItem[]> {
    const matches: ScoredInspirationMatch[] = [];

    for (let index = 0; index < this.allInspirationsCache.length; index++) {
      const item = this.allInspirationsCache[index];
      const score = this.scoreInspiration(item, tokens);
      if (score > 0) {
        matches.push({ item: item, score: score });
      }

      if (this.shouldYield(index)) {
        await this.yieldToUiThread();
      }
    }

    matches.sort((lhs, rhs) => this.compareScoredItems(lhs.score, lhs.item.text, rhs.score, rhs.item.text));
    return matches.map((item) => item.item);
  }

  private async buildArchivedTaskResults(tokens: string[]): Promise<ArchivedSearchModel[]> {
    const matches: ScoredTaskMatch[] = [];

    for (let index = 0; index < this.allTasksCache.length; index++) {
      const item = this.allTasksCache[index];
      if (!TaskStateMachine.isVisibleInArchiveList(item.state)) {
        continue;
      }

      const score = this.scoreTask(item, tokens, true);
      if (score > 0) {
        matches.push({ item: item, score: score });
      }

      if (this.shouldYield(index)) {
        await this.yieldToUiThread();
      }
    }

    matches.sort((lhs, rhs) => this.compareScoredItems(lhs.score, lhs.item.name, rhs.score, rhs.item.name));
    return matches.map((item) => this.mapArchivedTask(item.item));
  }

  private async buildArchivedHabitResults(tokens: string[]): Promise<ArchivedSearchModel[]> {
    const matches: ScoredHabitMatch[] = [];

    for (let index = 0; index < this.allHabitsCache.length; index++) {
      const habit = this.allHabitsCache[index];
      if (habit.status !== HabitStatus.ARCHIVED) {
        continue;
      }

      const score = this.scoreHabit(habit, tokens);
      if (score > 0) {
        matches.push({ habit: habit, score: score });
      }

      if (this.shouldYield(index)) {
        await this.yieldToUiThread();
      }
    }

    matches.sort((lhs, rhs) => this.compareScoredItems(lhs.score, lhs.habit.name, rhs.score, rhs.habit.name));
    return matches.map((item) => this.mapArchivedHabit(item.habit));
  }

  async browseCategory(category: SearchBrowseCategory): Promise<SearchResult> {
    const activeTasks = this.allTasksCache.filter((item) => TaskStateMachine.isVisibleInMainList(item.state));
    const activeHabits = this.allHabitsCache.filter((habit) => habit.status !== HabitStatus.ARCHIVED);
    const archivedTasks = this.allTasksCache.filter((item) => TaskStateMachine.isVisibleInArchiveList(item.state));
    const archivedHabits = this.allHabitsCache.filter((habit) => habit.status === HabitStatus.ARCHIVED);
    const today = new Date();

    switch (category) {
      case SearchBrowseCategory.TODAY:
        return {
          tasks: activeTasks
            .filter((item) => this.isSameDay(this.taskRelevantTime(item), today))
            .map((item) => this.mapTaskToUI(item)),
          habits: await Promise.all(
            activeHabits
              .filter((habit) => this.getEbbinghausState(habit, today).isDue)
              .map((habit) => this.buildHabitStatusForDate(habit, today))
          ),
          inspirations: [],
          archivedTasks: [],
          archivedHabits: []
        };
      case SearchBrowseCategory.UPCOMING:
        return {
          tasks: activeTasks
            .filter((item) => this.isUpcomingTask(item, today))
            .sort((lhs, rhs) => this.parseDate(lhs.endTime) - this.parseDate(rhs.endTime))
            .map((item) => this.mapTaskToUI(item)),
          habits: [],
          inspirations: [],
          archivedTasks: [],
          archivedHabits: []
        };
      case SearchBrowseCategory.STARRED:
        return {
          tasks: activeTasks.filter((item) => item.isStared).map((item) => this.mapTaskToUI(item)),
          habits: [],
          inspirations: [],
          archivedTasks: [],
          archivedHabits: []
        };
      case SearchBrowseCategory.ARCHIVED:
        return {
          tasks: [],
          habits: [],
          inspirations: [],
          archivedTasks: archivedTasks
            .sort((lhs, rhs) => this.archivedSortTime(rhs) - this.archivedSortTime(lhs))
            .map((item) => this.mapArchivedTask(item)),
          archivedHabits: archivedHabits
            .sort((lhs, rhs) => this.parseDate(rhs.updatedAt) - this.parseDate(lhs.updatedAt))
            .map((item) => this.mapArchivedHabit(item))
        };
      case SearchBrowseCategory.TASKS:
        return {
          tasks: activeTasks.map((item) => this.mapTaskToUI(item)),
          habits: [],
          inspirations: [],
          archivedTasks: [],
          archivedHabits: []
        };
      case SearchBrowseCategory.HABITS:
        return {
          tasks: [],
          habits: await Promise.all(activeHabits.map((habit) => this.buildHabitStatusForDate(habit, today))),
          inspirations: [],
          archivedTasks: [],
          archivedHabits: []
        };
    }
  }

  private mapArchivedTask(item: DDLItem): ArchivedSearchModel {
    return {
      id: `task_${item.id}`,
      title: item.name,
      detail1: this.formatDate(item.startTime),
      detail2: this.archivedTaskDetail(item),
      note: item.note || "",
      badgeText: TaskStateMachine.archiveBadgeText(item.state),
      originalType: 'task',
      originalItem: item
    };
  }

  private mapArchivedHabit(item: Habit): ArchivedSearchModel {
    return {
      id: `habit_${item.id}`,
      title: item.name,
      detail1: this.formatHabitDetail(item),
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
      if (isNaN(date.getTime())) {
        return dateStr;
      }
      const month = (date.getMonth() + 1).toString().padStart(2, '0');
      const day = date.getDate().toString().padStart(2, '0');
      const hour = date.getHours().toString().padStart(2, '0');
      const minute = date.getMinutes().toString().padStart(2, '0');
      return `${month}-${day} ${hour}:${minute}`;
    } catch (e) {
      return dateStr;
    }
  }

  private emptyResult(): SearchResult {
    return {
      tasks: [],
      habits: [],
      inspirations: [],
      archivedTasks: [],
      archivedHabits: []
    };
  }

  private queryTokens(query: string): string[] {
    return query
      .toLowerCase()
      .split(/\s+/)
      .map((item) => item.trim())
      .filter((item) => item.length > 0);
  }

  private compareScoredItems(
    lhsScore: number,
    lhsTitle: string,
    rhsScore: number,
    rhsTitle: string
  ): number {
    if (lhsScore !== rhsScore) {
      return rhsScore - lhsScore;
    }
    return lhsTitle.localeCompare(rhsTitle);
  }

  private scoreTask(item: DDLItem, tokens: string[], archived: boolean): number {
    return this.searchScore(
      item.name,
      this.taskSubtitle(item, archived),
      [item.note || '', item.endTime || '', item.startTime || '', item.completeTime || ''].join('\n'),
      tokens
    );
  }

  private scoreHabit(item: Habit, tokens: string[]): number {
    return this.searchScore(
      item.name,
      this.habitSubtitle(item),
      [item.description || '', item.updatedAt || '', item.createdAt || '', this.habitPeriodText(item)].join('\n'),
      tokens
    );
  }

  private scoreInspiration(item: InspirationItem, tokens: string[]): number {
    return this.searchScore(item.text, item.updatedAt, item.text, tokens);
  }

  private searchScore(title: string, subtitle: string, detail: string, tokens: string[]): number {
    if (tokens.length === 0) {
      return 0;
    }

    const titleLower = title.toLowerCase();
    const subtitleLower = subtitle.toLowerCase();
    const detailLower = detail.toLowerCase();
    let score = 0;

    for (const token of tokens) {
      if (!titleLower.includes(token) && !subtitleLower.includes(token) && !detailLower.includes(token)) {
        return 0;
      }

      if (titleLower === token) {
        score += 140;
      } else if (titleLower.startsWith(token)) {
        score += 100;
      } else if (titleLower.includes(token)) {
        score += 70;
      }

      if (subtitleLower.includes(token)) {
        score += 28;
      }

      if (detailLower.includes(token)) {
        score += 12;
      }
    }

    if (tokens.length > 1) {
      score += 16;
    }

    return score;
  }

  private taskSubtitle(item: DDLItem, archived: boolean): string {
    if (item.note && item.note.length > 0) {
      return item.note;
    }

    if (archived) {
      return this.archivedTaskDetail(item);
    }

    if (item.state === TaskState.ABANDONED || item.state === TaskState.ABANDONED_ARCHIVED) {
      return '已放弃';
    }

    return item.endTime || '无截止时间';
  }

  private habitSubtitle(item: Habit): string {
    if (item.description && item.description.length > 0) {
      return item.description;
    }
    return this.habitPeriodText(item);
  }

  private archivedTaskDetail(item: DDLItem): string {
    if (item.state === TaskState.ABANDONED_ARCHIVED) {
      return item.completeTime ? `放弃于 ${this.formatDate(item.completeTime)}` : '已放弃归档';
    }
    return this.formatDate(item.completeTime);
  }

  private habitPeriodText(item: Habit): string {
    switch (item.period) {
      case HabitPeriod.DAILY:
        return '每日';
      case HabitPeriod.WEEKLY:
        return '每周';
      case HabitPeriod.MONTHLY:
        return '每月';
      case HabitPeriod.EBBINGHAUS:
        return '艾宾浩斯';
      case HabitPeriod.ONCE:
        return '单次';
      default:
        return '习惯';
    }
  }

  private formatHabitDetail(item: Habit): string {
    return `${this.habitPeriodText(item)} · 创建于 ${this.formatDate(item.createdAt)}`;
  }

  private mapTaskToUI(item: DDLItem): TaskUIModel {
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
    if (item.state === TaskState.COMPLETED || item.state === TaskState.ARCHIVED) {
      timeText = "已完成";
    } else if (item.state === TaskState.ABANDONED || item.state === TaskState.ABANDONED_ARCHIVED) {
      timeText = "已放弃";
    } else if (end > 0) {
      const diffMs = end - now;
      if (diffMs < 0) {
        timeText = `已逾期 ${Math.abs(Math.floor(diffMs / (1000 * 60 * 60)))} 小时`;
      } else {
        const days = Math.floor(diffMs / (1000 * 60 * 60 * 24));
        const hours = Math.floor((diffMs % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
        timeText = days > 0 ? `${days}天 ${hours}小时` : (hours === 0 ? '不足1小时' : `${hours}小时`);
      }
    }

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

  public getEbbinghausState(habit: Habit, targetDate: Date): EbbinghausState {
    if (habit.period !== HabitPeriod.EBBINGHAUS) {
      return { isDue: true, text: '' };
    }

    const targetDay = new Date(targetDate);
    targetDay.setHours(0, 0, 0, 0);

    const createdAt = new Date(habit.createdAt);
    if (isNaN(createdAt.getTime())) {
      return { isDue: true, text: '' };
    }

    createdAt.setHours(0, 0, 0, 0);
    const diffDays = Math.floor((targetDay.getTime() - createdAt.getTime()) / (24 * 60 * 60 * 1000));
    const curve = [0, 1, 2, 4, 7, 15, 30, 60];

    if (diffDays < 0) {
      return { isDue: false, text: `${-diffDays} 天后开始` };
    }
    if (curve.includes(diffDays)) {
      return { isDue: true, text: '' };
    }

    const nextDay = curve.find((value) => value > diffDays);
    if (typeof nextDay === 'number') {
      return { isDue: false, text: `${nextDay - diffDays} 天后复习` };
    }

    return { isDue: false, text: '已完成记忆周期' };
  }

  private taskRelevantTime(item: DDLItem): number {
    const endTime = this.parseDate(item.endTime);
    if (endTime > 0) {
      return endTime;
    }
    return this.parseDate(item.startTime);
  }

  private isSameDay(time: number, targetDate: Date): boolean {
    if (time <= 0) {
      return false;
    }
    const date = new Date(time);
    return date.getFullYear() === targetDate.getFullYear()
      && date.getMonth() === targetDate.getMonth()
      && date.getDate() === targetDate.getDate();
  }

  private isUpcomingTask(item: DDLItem, today: Date): boolean {
    const end = this.parseDate(item.endTime);
    if (end <= 0) {
      return false;
    }

    const tomorrow = new Date(today);
    tomorrow.setHours(0, 0, 0, 0);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const upcomingEnd = new Date(today);
    upcomingEnd.setHours(23, 59, 59, 999);
    upcomingEnd.setDate(upcomingEnd.getDate() + 7);

    return end >= tomorrow.getTime() && end <= upcomingEnd.getTime();
  }

  private archivedSortTime(item: DDLItem): number {
    const completeTime = this.parseDate(item.completeTime);
    if (completeTime > 0) {
      return completeTime;
    }
    const endTime = this.parseDate(item.endTime);
    if (endTime > 0) {
      return endTime;
    }
    return this.parseDate(item.startTime);
  }

  private parseDate(value?: string): number {
    if (!value) {
      return 0;
    }
    const time = new Date(value).getTime();
    return isNaN(time) ? 0 : time;
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
    const dueState = this.getEbbinghausState(habit, date);
    return {
      habit: habit,
      doneCount: done,
      targetCount: target,
      isCompleted: done >= target,
      isDueToday: dueState.isDue,
      dueStateText: dueState.text
    };
  }
}
