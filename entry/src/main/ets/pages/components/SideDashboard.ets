import { Theme } from '@kit.ArkUI'
import { DeadlineType, DDLItem, HabitStatus, Habit } from '../../model/DDLModels';
import { common } from '@kit.AbilityKit';
import { TaskRepository } from '../../common/repository/TaskRepository';
import { HabitRepository } from '../../common/repository/HabitRepository';
import { SettingsConstants as C } from '../../common/local/SettingsConstants';
import { ITheme } from '../../common/theme/ThemeModel';

@Component
export struct SideDashboard {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @State currentDate: Date = new Date();

  // 改为 @State，由内部逻辑驱动
  @State todayProgress: number = 0;

  // 数据展示
  @State nextDeadlineTime: string = "No Due";
  @State nextDeadlineTask: string = "Relax";
  @State hasNextDue: boolean = false; // 控制是否显示 Next Due 的样式

  // 配色变量
  @State colorMonth: ResourceColor = this.theme.accent
  @State colorDay: ResourceColor = $r('app.color.font_primary')
  @State colorWeek: ResourceColor = $r('app.color.font_secondary')

  @State colorRing: ResourceColor = this.theme.brand
  @State colorYearBar: ResourceColor = $r('app.color.func_manual')
  @State colorNextDue: ResourceColor = $r('app.color.chart_red')

  @State cardBg: ResourceColor = $r('app.color.background_secondary')
  @State dashboardBg: ResourceColor = this.theme.bgPrimary

  @StorageProp(C.KEY_ENGLISH_SOMEWHERE) @Watch('onLangModeChange') englishEnable: boolean = true;
  @StorageProp('IsAppDataReady') @Watch('onLangModeChange') _initialized: boolean = false;

  // 刷新防抖
  private isRefreshing: boolean = false;

  onWillApplyTheme(theme: Theme) {
    // 主题适配逻辑
  }

  @State langTag: string = 'en-US';

  private onLangModeChange() {
    this.langTag = this.englishEnable ? 'en-US' : 'zh-CN';
    this.refreshData();
  }

  aboutToAppear() {
    // 1. 初始化加载数据
    this.refreshData();

    // 2. 监听数据变更事件 (来自 TaskRepository 的 notifyDataChange)
    // 假设 eventHub 事件名为 'sync_done' 或 'data_changed'
    const context = getContext(this) as common.UIAbilityContext;
    context.eventHub.on('sync_done', this.onDataChanged);
    context.eventHub.on('refresh_dashboard', this.onDataChanged); // 如果有专门的刷新事件
  }

  aboutToDisappear() {
    const context = getContext(this) as common.UIAbilityContext;
    context.eventHub.off('sync_done', this.onDataChanged);
    context.eventHub.off('refresh_dashboard', this.onDataChanged);
  }

  private onDataChanged = () => {
    this.refreshData();
  }

  /**
   * 核心逻辑：刷新所有面板数据
   */
  private async refreshData() {
    if (this.isRefreshing) return;
    this.isRefreshing = true;

    try {
      this.currentDate = new Date(); // 更新时间显示

      const taskRepo = TaskRepository.getInstance();
      const habitRepo = HabitRepository.getInstance();

      // --- 并行获取数据 ---
      const GeneratedDestructArray_1 = await Promise.all([
        taskRepo.getAllDDLs(),
        habitRepo.getAllHabits(),
        habitRepo.getCompletedIdsForDate(this.currentDate)
      ]);
      const allDDLs = GeneratedDestructArray_1[0];
      const allHabits = GeneratedDestructArray_1[1];
      const completedHabitIds = GeneratedDestructArray_1[2];

      // 1. 计算今日进度
      this.calculateTodayProgress(allDDLs, allHabits, completedHabitIds);

      // 2. 寻找 Next Due
      this.findNextDeadline(allDDLs);

    } catch (e) {
      console.error('[SideDashboard] Refresh failed:', e);
    } finally {
      this.isRefreshing = false;
    }
  }

  /**
   * 逻辑：计算今日进度
   * 定义：(今日完成的任务 + 今日完成的习惯) / (今日所有的任务 + 今日所有的习惯)
   */
  private calculateTodayProgress(ddls: DDLItem[], habits: Habit[], completedHabitIds: Set<number>) {
    const todayStr = this.formatDate(this.currentDate);

    // --- A. 任务部分 ---
    // 筛选条件：未归档 & (截止日期是今天 OR (已完成且完成时间是今天))
    const todayTasks = ddls.filter(task => {
      if (task.isArchived) return false;
      if (task.type !== DeadlineType.TASK) return false;

      // 简单判断：如果任务已完成，看完成时间是否是今天
      if (task.isCompleted && task.completeTime) {
        return task.completeTime.startsWith(todayStr);
      }

      // 如果未完成，看截止日期是否是今天 (或者之前，表示 overdue 也算进今天的进度压力)
      if (!task.isCompleted && task.endTime) {
        return task.endTime.startsWith(todayStr) || task.endTime < todayStr;
      }
      return false;
    });

    const totalTasks = todayTasks.length;
    const completedTasks = todayTasks.filter(t => t.isCompleted).length;

    // --- B. 习惯部分 ---
    // 筛选条件：Active 状态
    // 简化逻辑：所有 Active 的习惯都算作今天需要关注的事项
    const activeHabits = habits.filter(h => h.status === HabitStatus.ACTIVE);

    const totalHabits = activeHabits.length;
    const completedHabitsCount = activeHabits.filter(h => completedHabitIds.has(h.id)).length;

    // --- C. 汇总计算 ---
    const total = totalTasks + totalHabits;
    const done = completedTasks + completedHabitsCount;

    let progress = 0;
    if (total > 0) {
      progress = Math.round((done / total) * 100);
    }

    // 动画更新
    animateTo({ duration: 600, curve: Curve.EaseOut }, () => {
      this.todayProgress = progress;
    });
  }

  /**
   * 逻辑：寻找下一个 DDL
   */
  private findNextDeadline(ddls: DDLItem[]) {
    const now = new Date().getTime();

    // 筛选：Active, Uncompleted, Tasks, EndTime > Now
    const candidates = ddls.filter(t =>
    !t.isArchived &&
      !t.isCompleted &&
      t.type === DeadlineType.TASK &&
    t.endTime
    );

    if (candidates.length === 0) {
      this.hasNextDue = false;
      this.nextDeadlineTime = this.englishEnable ? "Done" : "已完成";
      this.nextDeadlineTask = this.englishEnable ? "All Clear" : "无剩余任务";
      return;
    }

    // 排序：按时间升序
    candidates.sort((a, b) => {
      return new Date(a.endTime).getTime() - new Date(b.endTime).getTime();
    });

    const nextTask = candidates[0];
    const dueTime = new Date(nextTask.endTime).getTime();

    this.hasNextDue = true;
    this.nextDeadlineTask = nextTask.name;
    this.nextDeadlineTime = this.formatTimeDiff(now, dueTime);
  }

  // ================= 辅助函数 =================

  // 格式化时间差： "2h 15m", "3 Days", "Overdue"
  private formatTimeDiff(now: number, due: number): string {
    const diffMs = due - now;

    if (diffMs < 0) {
      return this.englishEnable ? "Overdue" : "逾期";
    }

    const diffMins = Math.floor(diffMs / (1000 * 60));
    const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

    if (!this.englishEnable) {
      if (diffDays > 0) {
        return `${diffDays} 天`;
      }
      if (diffHours > 0) {
        const remainMins = diffMins % 60;
        return `${diffHours}小时 ${remainMins}分`;
      }
      return `${diffMins}分`;
    } else {
      if (diffDays > 0) {
        return `${diffDays} Days`;
      }
      if (diffHours > 0) {
        const remainMins = diffMins % 60;
        return `${diffHours}h ${remainMins}m`;
      }
      return `${diffMins}m`;
    }
  }

  private formatDate(date: Date): string {
    const y = date.getFullYear();
    const m = (date.getMonth() + 1).toString().padStart(2, '0');
    const d = date.getDate().toString().padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

  // 计算今年的进度 (0-100)
  getYearProgress(): number {
    const now = new Date();
    const start = new Date(now.getFullYear(), 0, 1);
    const end = new Date(now.getFullYear() + 1, 0, 1);
    const progress = (now.getTime() - start.getTime()) / (end.getTime() - start.getTime());
    return Math.round(progress * 100);
  }

  build() {
    Column() {
      // 1. 日历撕页
      Column() {
        Text(this.currentDate.toLocaleString(this.langTag, { month: 'short' }).toUpperCase())
          .fontSize(16)
          .fontColor(this.colorMonth) // Accent Color
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 2 })

        Text(this.currentDate.getDate().toString())
          .fontSize(42)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.colorDay)
          .height(46)

        Text(this.currentDate.toLocaleString(this.langTag, { weekday: 'short' }))
          .fontSize(14)
          .fontColor(this.colorWeek)
          .margin({ top: 4 })
      }
      .margin({ top: 32, bottom: 32 })

      // 2. 今日任务完成度
      Stack() {
        // 背景轨
        Progress({ value: 100, total: 100, type: ProgressType.Ring })
          .width(64)
          .height(64)
          .color($r('app.color.background_emphasize')) // 浅灰色底轨
          .style({ strokeWidth: 8 })

        // 进度轨
        Progress({ value: this.todayProgress, total: 100, type: ProgressType.Ring })
          .width(64)
          .height(64)
          .color(this.colorRing) // Brand Blue
          .style({ strokeWidth: 8 })

        Column() {
          Text(`${this.todayProgress}%`)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.colorDay)
        }
      }
      .margin({ bottom: 40 })

      // 3. 宏观时间进度 (Year Progress)
      Column() {
        Row() {
          Text(this.currentDate.getFullYear().toString())
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.colorWeek)
            .opacity(0.8)

          Text(`${this.getYearProgress()}%`)
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.colorYearBar) // 使用青色文字呼应进度条
        }
        .width('70%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ bottom: 6 })

        Progress({ value: this.getYearProgress(), total: 100, type: ProgressType.Linear })
          .width('70%')
          .height(6)
          .color(this.colorYearBar) // Func Manual (Teal/Green)
          .backgroundColor($r('app.color.background_emphasize'))
          .style({ strokeRadius: 3 })
      }
      .margin({ bottom: 40 })


      // 4. 最近的危机 (Next DDL)
      // 使用胶囊卡片，背景白色，内容红色
      Column() {
        Text(this.englishEnable ? 'NEXT DUE' : '下一项任务')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.colorWeek)
          .margin({ bottom: 8 })
          .opacity(0.6)
          .letterSpacing(1)

        Column() {
          // 沙漏图标
          SymbolGlyph($r('sys.symbol.hourglass'))
            .fontSize(24)
            .fontColor(this.hasNextDue ? [this.colorNextDue] : [this.colorWeek]) // 如果没有 DDL，图标变灰
            .margin({ bottom: 8 })

          // 时间
          Text(this.nextDeadlineTime)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.colorDay)

          // 任务名
          Text(this.nextDeadlineTask)
            .fontSize(10)
            .fontColor(this.colorWeek)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 4 })
            .opacity(0.8)
        }
        .padding({ top: 16, bottom: 16, left: 8, right: 8 })
        .backgroundColor(this.cardBg) // White Background
        .borderRadius(16)
        .width('85%')
        .shadow({ radius: 20, color: '#1A000000', offsetY: 4 }) // 极轻的阴影增加立体感
      }
    }
    .width('100%')
    .height('100%')
    .opacity(1)
  }
}