import { AppLog } from '../../common/logging/AppLog';
import { common } from '@kit.AbilityKit';
import { ITheme } from '../../common/theme/ThemeModel';
import { SettingsConstants as C } from '../../common/local/SettingsConstants';
import { TaskRepository } from '../../common/repository/TaskRepository';
import { HabitRepository } from '../../common/repository/HabitRepository';
import { DDLItem, DeadlineType, Habit, HabitStatus } from '../../model/DDLModels';
import { TaskState } from '../../model/TaskStateMachine';

export enum HomeFocusSegment {
  TASKS = 'tasks',
  HABITS = 'habits',
  ALL = 'all'
}

export enum HomeFocusLayout {
  HERO = 'hero',
  RAIL = 'rail'
}

export enum HomeFocusRailMode {
  MEDIUM = 'medium',
  WIDE = 'wide'
}

enum HomeFocusTone {
  ACCENT = 'accent',
  WARNING = 'warning',
  DANGER = 'danger',
  SUCCESS = 'success'
}

interface HomeFocusMetric {
  id: string;
  label: string;
  value: string;
}

interface HomeFocusSnapshot {
  eyebrow: string;
  badge: string;
  title: string;
  primaryValue: string;
  secondaryText: string;
  progress: number;
  progressLabel: string;
  metrics: HomeFocusMetric[];
  nextLabel: string;
  nextValue: string;
  nextCaption: string;
  nextSymbol: Resource;
  nextIsAlert: boolean;
  monthLabel: string;
  dayLabel: string;
  weekdayLabel: string;
  yearProgress: number;
  tone: HomeFocusTone;
}

interface TaskProgressStats {
  done: number;
  total: number;
  progress: number;
  label: string;
}

const EMPTY_SNAPSHOT: HomeFocusSnapshot = {
  eyebrow: '主页焦点',
  badge: '今日',
  title: '摘要',
  primaryValue: '--',
  secondaryText: '正在准备主页摘要',
  progress: 0,
  progressLabel: '',
  metrics: [],
  nextLabel: '下一项聚焦',
  nextValue: '暂无数据',
  nextCaption: '',
  nextSymbol: $r('sys.symbol.hourglass'),
  nextIsAlert: false,
  monthLabel: '--',
  dayLabel: '--',
  weekdayLabel: '--',
  yearProgress: 0,
  tone: HomeFocusTone.ACCENT
};

@Component
export struct HomeFocusPanel {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  @StorageProp(C.KEY_ENGLISH_SOMEWHERE) @Watch('onConfigChanged') englishEnable: boolean = false;
  @StorageProp('IsAppDataReady') @Watch('onConfigChanged') _initialized: boolean = false;

  @Prop @Watch('onSegmentChanged') segment: HomeFocusSegment = HomeFocusSegment.TASKS;
  @Prop layout: HomeFocusLayout = HomeFocusLayout.RAIL;
  @Prop railMode: HomeFocusRailMode = HomeFocusRailMode.MEDIUM;

  @State private snapshot: HomeFocusSnapshot = EMPTY_SNAPSHOT;
  @State private currentDate: Date = new Date();
  @State private heroWidth: number = 0;
  private readonly auxCardRadius: number = 22;

  private isRefreshing: boolean = false;

  aboutToAppear(): void {
    this.refreshData();

    const context = getContext(this) as common.UIAbilityContext;
    context.eventHub.on('sync_done', this.onDataChanged);
    context.eventHub.on('refresh_dashboard', this.onDataChanged);
  }

  aboutToDisappear(): void {
    const context = getContext(this) as common.UIAbilityContext;
    context.eventHub.off('sync_done', this.onDataChanged);
    context.eventHub.off('refresh_dashboard', this.onDataChanged);
  }

  private onDataChanged = (): void => {
    this.refreshData();
  }

  private onSegmentChanged(): void {
    this.refreshData();
  }

  private onConfigChanged(): void {
    this.refreshData();
  }

  private async refreshData(): Promise<void> {
    if (this.isRefreshing) {
      return;
    }
    this.isRefreshing = true;

    try {
      this.currentDate = new Date();
      const taskRepo = TaskRepository.getInstance();
      const habitRepo = HabitRepository.getInstance();

      const resultList = await Promise.all([
        taskRepo.getAllDDLs(),
        habitRepo.getAllHabits(),
        habitRepo.getCompletedIdsForDate(this.currentDate)
      ]);
      const allDDLs = resultList[0] as DDLItem[];
      const allHabits = resultList[1] as Habit[];
      const completedHabitIds = resultList[2] as Set<number>;

      this.snapshot = this.buildSnapshot(allDDLs, allHabits, completedHabitIds);
    } catch (e) {
      AppLog.error('Native', '[HomeFocusPanel] Refresh failed:', e);
    } finally {
      this.isRefreshing = false;
    }
  }

  private buildSnapshot(ddls: DDLItem[], habits: Habit[], completedHabitIds: Set<number>): HomeFocusSnapshot {
    switch (this.segment) {
      case HomeFocusSegment.HABITS:
        return this.buildHabitSnapshot(ddls, habits, completedHabitIds);
      case HomeFocusSegment.ALL:
        return this.buildAllSnapshot(ddls, habits, completedHabitIds);
      case HomeFocusSegment.TASKS:
      default:
        return this.buildTaskSnapshot(ddls, habits, completedHabitIds);
    }
  }

  private buildTaskSnapshot(ddls: DDLItem[], _habits: Habit[], _completedHabitIds: Set<number>): HomeFocusSnapshot {
    const activeTasks = this.getActiveTasks(ddls);
    const openTasks = activeTasks.filter((item) => this.isTaskPending(item));
    const overdueTasks = openTasks.filter((item) => this.isTaskOverdue(item));
    const nearTasks = openTasks.filter((item) => this.isTaskNear(item));
    const doneToday = activeTasks.filter((item) => this.wasTaskCompletedToday(item)).length;
    const progressStats = this.getTaskProgressStats(activeTasks);
    const nextTask = this.getNextTask(openTasks);

    let secondaryText = this.englishEnable ? 'Your board is ready.' : '列表已经准备好，可以直接开干。';
    let tone = HomeFocusTone.ACCENT;
    if (overdueTasks.length > 0) {
      secondaryText = this.englishEnable ? 'Clear the riskiest tasks first.' : '今天先清掉最危险的几项。';
      tone = HomeFocusTone.DANGER;
    } else if (nearTasks.length > 0) {
      secondaryText = this.englishEnable ? 'A few tasks are getting close.' : '先收一轮快到期任务，列表会轻很多。';
      tone = HomeFocusTone.WARNING;
    } else if (openTasks.length === 0) {
      secondaryText = this.englishEnable ? 'All clear for now.' : '当前没有待推进任务。';
      tone = HomeFocusTone.SUCCESS;
    }

    return {
      eyebrow: this.englishEnable ? 'TODAY BOARD' : '今日看板',
      badge: this.englishEnable ? 'Tasks' : '任务',
      title: this.englishEnable ? 'Open tasks' : '待推进',
      primaryValue: openTasks.length === 0
        ? (this.englishEnable ? '0 tasks' : '0 个任务')
        : (this.englishEnable ? `${openTasks.length} tasks` : `${openTasks.length} 个任务`),
      secondaryText: secondaryText,
      progress: progressStats.progress,
      progressLabel: progressStats.label,
      metrics: [
        { id: 'overdue', label: this.englishEnable ? 'Overdue' : '逾期', value: `${overdueTasks.length}` },
        { id: 'near', label: this.englishEnable ? 'Soon' : '临期', value: `${nearTasks.length}` },
        { id: 'done', label: this.englishEnable ? 'Done today' : '今日完成', value: `${doneToday}` }
      ],
      nextLabel: this.englishEnable ? 'NEXT TASK' : '下一项任务',
      nextValue: nextTask ? nextTask.name : (this.englishEnable ? 'All clear' : '已全部清空'),
      nextCaption: nextTask ? this.formatTimeDiff(Date.now(), this.parseDate(nextTask.endTime)) : '',
      nextSymbol: $r('sys.symbol.hourglass'),
      nextIsAlert: nextTask ? this.isTaskOverdue(nextTask) || this.isTaskNear(nextTask) : false,
      monthLabel: this.currentDate.toLocaleString(this.getLangTag(), { month: 'short' }).toUpperCase(),
      dayLabel: this.currentDate.getDate().toString(),
      weekdayLabel: this.currentDate.toLocaleString(this.getLangTag(), { weekday: 'short' }),
      yearProgress: this.getYearProgress(),
      tone: tone
    };
  }

  private buildHabitSnapshot(_ddls: DDLItem[], habits: Habit[], completedHabitIds: Set<number>): HomeFocusSnapshot {
    const activeHabits = habits.filter((habit) => habit.status === HabitStatus.ACTIVE);
    const completedCount = activeHabits.filter((habit) => completedHabitIds.has(habit.id)).length;
    const totalCount = activeHabits.length;
    const remainingCount = Math.max(0, totalCount - completedCount);
    const reminderCount = activeHabits.filter((habit) => !!habit.alarmTime && habit.alarmTime.length > 0).length;
    const nextHabit = this.getNextHabit(activeHabits, completedHabitIds);
    const progress = totalCount > 0 ? completedCount / totalCount : 0;

    let secondaryText = this.englishEnable ? 'Keep the rhythm going.' : '今天的节奏已经铺开了。';
    let tone = HomeFocusTone.ACCENT;
    if (totalCount === 0) {
      secondaryText = this.englishEnable ? 'No active habits yet.' : '今天还没有可见习惯。';
    } else if (progress >= 1) {
      secondaryText = this.englishEnable ? 'All habits checked in.' : '今天的习惯已经全部打卡。';
      tone = HomeFocusTone.SUCCESS;
    } else if (progress >= 0.66) {
      secondaryText = this.englishEnable ? 'You are close to a perfect day.' : '差一点就能把今天收满。';
    }

    return {
      eyebrow: this.englishEnable ? 'HABIT TRACKER' : '习惯追踪',
      badge: this.englishEnable ? 'Habits' : '习惯',
      title: this.englishEnable ? 'Today progress' : '今日完成',
      primaryValue: `${Math.round(progress * 100)}%`,
      secondaryText: secondaryText,
      progress: progress,
      progressLabel: this.englishEnable ? `${completedCount} / ${totalCount} checked in` : `已打卡 ${completedCount} / ${totalCount}`,
      metrics: [
        { id: 'done', label: this.englishEnable ? 'Done' : '已打卡', value: `${completedCount}` },
        { id: 'left', label: this.englishEnable ? 'Left' : '剩余', value: `${remainingCount}` },
        { id: 'alarms', label: this.englishEnable ? 'Reminders' : '提醒', value: `${reminderCount}` }
      ],
      nextLabel: this.englishEnable ? 'NEXT HABIT' : '下一项习惯',
      nextValue: nextHabit ? nextHabit.name : (this.englishEnable ? 'Everything is done' : '今天已经全部完成'),
      nextCaption: nextHabit
        ? (nextHabit.alarmTime ? this.formatAlarmTime(nextHabit.alarmTime) : (this.englishEnable ? 'Ready when you are' : '随时都可以开始'))
        : '',
      nextSymbol: $r('sys.symbol.leaf'),
      nextIsAlert: false,
      monthLabel: this.currentDate.toLocaleString(this.getLangTag(), { month: 'short' }).toUpperCase(),
      dayLabel: this.currentDate.getDate().toString(),
      weekdayLabel: this.currentDate.toLocaleString(this.getLangTag(), { weekday: 'short' }),
      yearProgress: this.getYearProgress(),
      tone: tone
    };
  }

  private buildAllSnapshot(ddls: DDLItem[], habits: Habit[], completedHabitIds: Set<number>): HomeFocusSnapshot {
    const activeTasks = this.getActiveTasks(ddls);
    const openTasks = activeTasks.filter((item) => this.isTaskPending(item));
    const overdueTasks = openTasks.filter((item) => this.isTaskOverdue(item));
    const taskProgress = this.getTaskProgressStats(activeTasks);

    const activeHabits = habits.filter((habit) => habit.status === HabitStatus.ACTIVE);
    const completedHabitCount = activeHabits.filter((habit) => completedHabitIds.has(habit.id)).length;

    const total = taskProgress.total + activeHabits.length;
    const done = taskProgress.done + completedHabitCount;
    const progress = total > 0 ? done / total : 0;

    const nextTask = this.getNextTask(openTasks);
    const nextHabit = this.getNextHabit(activeHabits, completedHabitIds);
    const nextValue = nextTask ? nextTask.name : (nextHabit ? nextHabit.name : (this.englishEnable ? 'All clear' : '今天很清爽'));
    const nextCaption = nextTask
      ? this.formatTimeDiff(Date.now(), this.parseDate(nextTask.endTime))
      : (nextHabit
        ? (nextHabit.alarmTime ? this.formatAlarmTime(nextHabit.alarmTime) : (this.englishEnable ? 'Next habit ready' : '下一项习惯已经准备好'))
        : '');

    let tone = HomeFocusTone.ACCENT;
    let secondaryText = this.englishEnable ? 'Tasks and habits are both in view.' : '任务和习惯都已经进入主视野。';
    if (overdueTasks.length > 0) {
      tone = HomeFocusTone.DANGER;
      secondaryText = this.englishEnable ? 'There are overdue items to resolve.' : '还有逾期任务需要尽快处理。';
    } else if (progress >= 1 && total > 0) {
      tone = HomeFocusTone.SUCCESS;
      secondaryText = this.englishEnable ? 'The whole board is wrapped up.' : '今天这张主面板已经基本收完。';
    }

    return {
      eyebrow: this.englishEnable ? 'HOME FOCUS' : '主页焦点',
      badge: this.englishEnable ? 'Overview' : '总览',
      title: this.englishEnable ? 'Today progress' : '今日推进',
      primaryValue: `${Math.round(progress * 100)}%`,
      secondaryText: secondaryText,
      progress: progress,
      progressLabel: this.englishEnable ? `${done} / ${total} focus items` : `已推进 ${done} / ${total}`,
      metrics: [
        { id: 'tasks', label: this.englishEnable ? 'Open tasks' : '待推进', value: `${openTasks.length}` },
        { id: 'habits', label: this.englishEnable ? 'Checked habits' : '已打卡', value: `${completedHabitCount}` },
        { id: 'overdue', label: this.englishEnable ? 'Overdue' : '逾期', value: `${overdueTasks.length}` }
      ],
      nextLabel: this.englishEnable ? 'NEXT FOCUS' : '下一项聚焦',
      nextValue: nextValue,
      nextCaption: nextCaption,
      nextSymbol: nextTask ? $r('sys.symbol.hourglass') : $r('sys.symbol.leaf'),
      nextIsAlert: !!nextTask && (this.isTaskOverdue(nextTask) || this.isTaskNear(nextTask)),
      monthLabel: this.currentDate.toLocaleString(this.getLangTag(), { month: 'short' }).toUpperCase(),
      dayLabel: this.currentDate.getDate().toString(),
      weekdayLabel: this.currentDate.toLocaleString(this.getLangTag(), { weekday: 'short' }),
      yearProgress: this.getYearProgress(),
      tone: tone
    };
  }

  private getActiveTasks(ddls: DDLItem[]): DDLItem[] {
    return ddls.filter((item) =>
      !item.deleted &&
      !item.isArchived &&
      item.type === DeadlineType.TASK &&
      item.state !== TaskState.ARCHIVED &&
      item.state !== TaskState.ABANDONED_ARCHIVED
    );
  }

  private isTaskPending(item: DDLItem): boolean {
    return !item.isCompleted && item.state !== TaskState.ABANDONED && item.state !== TaskState.ABANDONED_ARCHIVED;
  }

  private isTaskOverdue(item: DDLItem): boolean {
    const end = this.parseDate(item.endTime);
    return end > 0 && end < Date.now();
  }

  private isTaskNear(item: DDLItem): boolean {
    const end = this.parseDate(item.endTime);
    if (end <= 0) {
      return false;
    }
    const diff = end - Date.now();
    return diff >= 0 && diff <= 24 * 60 * 60 * 1000;
  }

  private wasTaskCompletedToday(item: DDLItem): boolean {
    return item.isCompleted && item.completeTime.startsWith(this.formatDate(this.currentDate));
  }

  private getTaskProgressStats(activeTasks: DDLItem[]): TaskProgressStats {
    const todayStr = this.formatDate(this.currentDate);
    const todayPool = activeTasks.filter((item) => {
      if (item.state === TaskState.ABANDONED || item.state === TaskState.ABANDONED_ARCHIVED) {
        return false;
      }
      if (item.isCompleted && item.completeTime) {
        return item.completeTime.startsWith(todayStr);
      }
      if (!item.isCompleted && item.endTime) {
        return item.endTime.startsWith(todayStr) || this.parseDate(item.endTime) < Date.now();
      }
      return false;
    });

    const done = todayPool.filter((item) => item.isCompleted).length;
    const total = todayPool.length;
    const progress = total > 0 ? done / total : (activeTasks.filter((item) => this.isTaskPending(item)).length === 0 ? 1 : 0);
    const label = this.englishEnable
      ? `Today ${done} / ${total}`
      : `今日推进 ${done} / ${total}`;
    return {
      done: done,
      total: total,
      progress: progress,
      label: label
    };
  }

  private getNextTask(tasks: DDLItem[]): DDLItem | null {
    if (tasks.length === 0) {
      return null;
    }
    const sorted = [...tasks].sort((lhs, rhs) => this.parseDate(lhs.endTime) - this.parseDate(rhs.endTime));
    return sorted[0];
  }

  private getNextHabit(habits: Habit[], completedHabitIds: Set<number>): Habit | null {
    const candidates = habits.filter((habit) => !completedHabitIds.has(habit.id));
    if (candidates.length === 0) {
      return null;
    }
    const withAlarm = [...candidates].sort((lhs, rhs) => this.parseAlarmTime(lhs.alarmTime) - this.parseAlarmTime(rhs.alarmTime));
    return withAlarm[0];
  }

  private parseAlarmTime(alarmTime: string | null): number {
    if (!alarmTime || alarmTime.length === 0) {
      return Number.MAX_SAFE_INTEGER;
    }
    const parts = alarmTime.split(':');
    if (parts.length < 2) {
      return Number.MAX_SAFE_INTEGER;
    }
    const hours = Number(parts[0]);
    const minutes = Number(parts[1]);
    return (hours * 60) + minutes;
  }

  private parseDate(value: string): number {
    const parsed = new Date(value).getTime();
    return isNaN(parsed) ? 0 : parsed;
  }

  private formatDate(date: Date): string {
    const y = date.getFullYear();
    const m = (date.getMonth() + 1).toString().padStart(2, '0');
    const d = date.getDate().toString().padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

  private getLangTag(): string {
    return this.englishEnable ? 'en-US' : 'zh-CN';
  }

  private formatTimeDiff(now: number, due: number): string {
    if (due <= 0) {
      return '';
    }

    const diffMs = due - now;
    if (diffMs < 0) {
      return this.englishEnable ? 'Overdue' : '已逾期';
    }

    const diffMins = Math.floor(diffMs / (1000 * 60));
    const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

    if (diffDays > 0) {
      return this.englishEnable ? `${diffDays} days left` : `还剩 ${diffDays} 天`;
    }
    if (diffHours > 0) {
      const remainMins = diffMins % 60;
      return this.englishEnable ? `${diffHours}h ${remainMins}m left` : `还剩 ${diffHours}小时 ${remainMins}分`;
    }
    return this.englishEnable ? `${diffMins}m left` : `还剩 ${diffMins} 分`;
  }

  private formatAlarmTime(value: string): string {
    return this.englishEnable ? `Reminder ${value}` : `提醒时间 ${value}`;
  }

  private getYearProgress(): number {
    const now = new Date();
    const start = new Date(now.getFullYear(), 0, 1);
    const end = new Date(now.getFullYear() + 1, 0, 1);
    const progress = (now.getTime() - start.getTime()) / (end.getTime() - start.getTime());
    return Math.round(progress * 100);
  }

  private getToneStartColor(): ResourceColor {
    switch (this.snapshot.tone) {
      case HomeFocusTone.DANGER:
        return this.theme.indicatorPassed;
      case HomeFocusTone.WARNING:
        return this.theme.indicatorNear;
      case HomeFocusTone.SUCCESS:
        return this.theme.indicatorCompleted;
      case HomeFocusTone.ACCENT:
      default:
        return this.theme.brand;
    }
  }

  private getToneEndColor(): ResourceColor {
    switch (this.snapshot.tone) {
      case HomeFocusTone.DANGER:
        return this.theme.bgPassed;
      case HomeFocusTone.WARNING:
        return this.theme.bgNear;
      case HomeFocusTone.SUCCESS:
        return this.theme.bgCompleted;
      case HomeFocusTone.ACCENT:
      default:
        return this.theme.brand50;
    }
  }

  private getTrackColor(): ResourceColor {
    return '#26FFFFFF';
  }

  private shouldUseHeroProgressFooter(): boolean {
    return this.segment !== HomeFocusSegment.TASKS;
  }

  private getAccentTextColor(): ResourceColor {
    return this.snapshot.nextIsAlert ? this.theme.chartOverdue : this.theme.accent;
  }

  @Builder
  private SummaryCard(compact: boolean = false) {
    Column({ space: compact ? 8 : 10 }) {
      Row() {
        Text(this.snapshot.eyebrow)
          .fontSize(compact ? 10 : 11)
          .fontWeight(FontWeight.Medium)
          .fontColor('#CCFFFFFF')
          .letterSpacing(1.2)

        Blank()

        Text(this.snapshot.badge)
          .fontSize(compact ? 11 : 12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F2FFFFFF')
          .padding({ left: compact ? 8 : 10, right: compact ? 8 : 10, top: 4, bottom: 4 })
          .backgroundColor('#26FFFFFF')
          .borderRadius(999)
      }
      .width('100%')

      Column({ space: compact ? 4 : 4 }) {
        Text(this.snapshot.title)
          .fontSize(compact ? 12 : 12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F2FFFFFF')

        Text(this.snapshot.primaryValue)
          .fontSize(compact ? 24 : 34)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.snapshot.secondaryText)
          .fontSize(compact ? 12 : 13)
          .lineHeight(compact ? 16 : 18)
          .fontColor('#CCFFFFFF')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.shouldUseHeroProgressFooter() && this.snapshot.progressLabel.length > 0) {
        Column({ space: 4 }) {
          Progress({ value: this.snapshot.progress * 100, total: 100, type: ProgressType.Linear })
            .width('100%')
            .height(8)
            .color(Color.White)
            .backgroundColor(this.getTrackColor())
            .style({ strokeRadius: 999 })

          Text(this.snapshot.progressLabel)
            .fontSize(compact ? 10 : 11)
            .fontWeight(FontWeight.Medium)
            .fontColor('#CCFFFFFF')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      } else if (this.snapshot.metrics.length > 0) {
        Row({ space: 8 }) {
          ForEach(this.snapshot.metrics, (metric: HomeFocusMetric, index: number) => {
            Text(`${metric.label} ${metric.value}`)
              .fontSize(compact ? 10 : 11)
              .fontWeight(FontWeight.Medium)
              .fontColor('#CCFFFFFF')
              .maxLines(1)

            if (index < this.snapshot.metrics.length - 1) {
              Row()
                .width(3)
                .height(3)
                .backgroundColor('#99FFFFFF')
                .borderRadius(999)
                .alignSelf(ItemAlign.Center)
            }
          }
          )
          Blank()
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding({ left: compact ? 14 : 18, right: compact ? 14 : 18, top: compact ? 14 : 18, bottom: compact ? 14 : 14 })
    .linearGradient({
      angle: 135,
      colors: [
        [this.getToneStartColor(), 0.0],
        [this.getToneEndColor(), 1.0]
      ]
    })
    .borderRadius(compact ? 20 : 34)
  }

  @Builder
  private DateCard(compact: boolean = false) {
    Column({ space: 2 }) {
      Text(this.snapshot.monthLabel)
        .fontSize(compact ? 13 : 15)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.accent)
        .letterSpacing(0.8)

      Text(this.snapshot.dayLabel)
        .fontSize(compact ? 30 : 38)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.font_primary'))

      Text(this.snapshot.weekdayLabel)
        .fontSize(compact ? 12 : 13)
        .fontColor($r('app.color.font_secondary'))
    }
    .width('100%')
    .padding({ top: compact ? 14 : 18, bottom: compact ? 14 : 18, left: compact ? 16 : 18, right: compact ? 16 : 18 })
    .backgroundColor($r('app.color.background_secondary'))
    .borderRadius(this.auxCardRadius)
  }

  @Builder
  private YearCard(compact: boolean = false) {
    Stack({ alignContent: Alignment.TopStart }) {
      Row() {
        Row()
          .height('100%')
          .width(`${Math.max(0, Math.min(100, this.snapshot.yearProgress))}%`)
          .backgroundColor(this.theme.accent)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_emphasize'))

      Column({ space: 4 }) {
        Row() {
          Text(this.englishEnable ? 'YEAR' : '年度进度')
            .fontSize(compact ? 10 : 11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.font_secondary'))

          Blank()

          Text(`${this.snapshot.yearProgress}%`)
            .fontSize(compact ? 10 : 11)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.accent)
        }
        .width('100%')

        Text(`${this.currentDate.getFullYear()}`)
          .fontSize(compact ? 11 : 12)
          .fontColor($r('app.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ left: compact ? 14 : 16, right: compact ? 14 : 16, top: compact ? 10 : 12, bottom: compact ? 10 : 12 })
    }
    .width('100%')
    .height(compact ? 70 : 76)
    .borderRadius(this.auxCardRadius)
    .clip(true)
  }

  @Builder
  private NextCard(compact: boolean = false) {
    Column({ space: compact ? 7 : 8 }) {
      Text(this.snapshot.nextLabel)
        .fontSize(compact ? 9 : 10)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.font_secondary'))
        .letterSpacing(1)

      Row({ space: compact ? 8 : 10 }) {
        SymbolGlyph(this.snapshot.nextSymbol)
          .fontSize(compact ? 18 : 20)
          .fontColor([this.getAccentTextColor()])

        Column({ space: 3 }) {
          Text(this.snapshot.nextValue)
            .fontSize(compact ? 13 : 14)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (this.snapshot.nextCaption.length > 0) {
            Text(this.snapshot.nextCaption)
              .fontSize(compact ? 10 : 11)
              .fontColor($r('app.color.font_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(compact ? 70 : 76)
    .padding({ top: compact ? 10 : 12, bottom: compact ? 10 : 12, left: compact ? 14 : 16, right: compact ? 14 : 16 })
    .backgroundColor($r('app.color.background_secondary'))
    .borderRadius(this.auxCardRadius)
  }

  @Builder
  private InlineYearProgress() {
    Column({ space: 4 }) {
      Row() {
        Text(this.englishEnable ? 'YEAR' : '年度进度')
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.font_secondary'))

        Blank()

        Text(`${this.snapshot.yearProgress}%`)
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.accent)
      }
      .width('100%')

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(6)
          .backgroundColor($r('app.color.background_emphasize'))
          .borderRadius(999)

        Row()
          .width(`${Math.max(0, Math.min(100, this.snapshot.yearProgress))}%`)
          .height(6)
          .backgroundColor(this.theme.accent)
          .borderRadius(999)
      }
      .width('100%')
    }
    .width('100%')
  }

  private getRailNarrowWidth(): string {
    return this.railMode === HomeFocusRailMode.WIDE ? '74%' : '82%';
  }

  private getRailCapsuleWidth(): string {
    return this.railMode === HomeFocusRailMode.WIDE ? '88%' : '92%';
  }

  @Builder
  private RailDateBlock() {
    Column({ space: 2 }) {
      Text(this.snapshot.monthLabel)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.accent)
        .letterSpacing(0.8)

      Text(this.snapshot.dayLabel)
        .fontSize(38)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.font_primary'))
        .height(42)

      Text(this.snapshot.weekdayLabel)
        .fontSize(13)
        .fontColor($r('app.color.font_secondary'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .margin({ top: 18, bottom: 8 })
  }

  @Builder
  private RailFocusCard() {
    Column({ space: 10 }) {
      Stack() {
        Progress({ value: 100, total: 100, type: ProgressType.Ring })
          .width(68)
          .height(68)
          .color($r('app.color.background_emphasize'))
          .style({ strokeWidth: 8 })

        Progress({ value: this.snapshot.progress * 100, total: 100, type: ProgressType.Ring })
          .width(68)
          .height(68)
          .color(this.theme.brand)
          .style({ strokeWidth: 8 })

        Text(`${Math.round(this.snapshot.progress * 100)}%`)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.font_primary'))
      }

      Column({ space: 4 }) {
        Text(this.snapshot.badge)
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.font_secondary'))

        Text(this.snapshot.primaryValue)
          .fontSize(this.railMode === HomeFocusRailMode.WIDE ? 16 : 18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)

        Text(this.railMode === HomeFocusRailMode.WIDE ? this.snapshot.progressLabel : this.snapshot.secondaryText)
          .fontSize(11)
          .fontColor($r('app.color.font_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .padding({ top: 16, bottom: 16, left: 12, right: 12 })
    .backgroundColor($r('app.color.background_secondary'))
    .borderRadius(22)
  }

  @Builder
  private RailYearStrip() {
    Column({ space: 6 }) {
      Row() {
        Text(this.currentDate.getFullYear().toString())
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.font_secondary'))

        Blank()

        Text(`${this.snapshot.yearProgress}%`)
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.accent)
      }
      .width('100%')

      Progress({ value: this.snapshot.yearProgress, total: 100, type: ProgressType.Linear })
        .width('100%')
        .height(6)
        .color(this.theme.accent)
        .backgroundColor($r('app.color.background_emphasize'))
        .style({ strokeRadius: 999 })
    }
    .width(this.getRailNarrowWidth())
  }

  @Builder
  private RailNextCard() {
    Column({ space: 8 }) {
      Text(this.snapshot.nextLabel)
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.font_secondary'))
        .opacity(0.7)
        .letterSpacing(1)

      Column({ space: 6 }) {
        SymbolGlyph(this.snapshot.nextSymbol)
          .fontSize(22)
          .fontColor([this.getAccentTextColor()])

        if (this.snapshot.nextCaption.length > 0) {
          Text(this.snapshot.nextCaption)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.Center)
        }

        Text(this.snapshot.nextValue)
          .fontSize(11)
          .fontColor($r('app.color.font_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding({ top: 16, bottom: 16, left: 10, right: 10 })
      .backgroundColor($r('app.color.background_secondary'))
      .borderRadius(18)
      .shadow({ radius: 20, color: '#16000000', offsetY: 4 })
    }
    .width(this.getRailCapsuleWidth())
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private CompactSummaryCard(compactRail: boolean = false) {
    Column({ space: compactRail ? 7 : 8 }) {
      Row() {
        Text(this.snapshot.badge)
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.font_secondary'))

        Blank()

        Text(`${Math.round(this.snapshot.progress * 100)}%`)
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getAccentTextColor())
      }
      .width('100%')

      Text(this.snapshot.primaryValue)
        .fontSize(compactRail ? 18 : 20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(compactRail ? this.snapshot.progressLabel : this.snapshot.secondaryText)
        .fontSize(11)
        .lineHeight(16)
        .fontColor($r('app.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (!compactRail) {
        Row() {
          ForEach(this.snapshot.metrics, (metric: HomeFocusMetric, index: number) => {
            Column({ space: 2 }) {
              Text(metric.label)
                .fontSize(9)
                .fontColor($r('app.color.font_secondary'))
              Text(metric.value)
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.font_primary'))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            if (index < this.snapshot.metrics.length - 1) {
              Divider()
                .vertical(true)
                .height(22)
                .strokeWidth(1)
                .color($r('sys.color.ohos_id_color_list_separator'))
                .opacity(0.5)
            }
          })
        }
        .width('100%')
      }

      this.InlineYearProgress()
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.background_secondary'))
    .borderRadius(this.auxCardRadius)
  }

  @Builder
  private HeroLayout() {
    if (this.heroWidth >= 520) {
      Row({ space: 10 }) {
        Column() {
          this.SummaryCard(false)
        }
        .layoutWeight(1.18)

        Column({ space: 10 }) {
          this.YearCard(false)
          this.NextCard(false)
        }
        .layoutWeight(0.92)
      }
      .width('100%')
    } else {
      Column({ space: 10 }) {
        this.SummaryCard(false)

        Row({ space: 10 }) {
          Column() {
            this.YearCard(false)
          }
          .layoutWeight(1)

          Column() {
            this.NextCard(false)
          }
          .layoutWeight(1)
        }
        .width('100%')
      }
      .width('100%')
    }
  }

  @Builder
  private RailLayout() {
    Column({ space: 22 }) {
      this.RailDateBlock()
      this.RailFocusCard()
      this.RailYearStrip()
      this.RailNextCard()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    if (this.layout === HomeFocusLayout.HERO) {
      Column() {
        this.HeroLayout()
      }
      .width('100%')
      .onAreaChange((_, area) => {
        if (typeof area.width === 'number' && area.width > 0) {
          this.heroWidth = area.width;
        }
      })
    } else {
      this.RailLayout()
    }
  }
}
