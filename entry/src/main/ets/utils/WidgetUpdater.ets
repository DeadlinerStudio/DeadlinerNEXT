import { formBindingData, formProvider } from '@kit.FormKit';
import { preferences } from '@kit.ArkData';
import { TaskRepository } from '../common/repository/TaskRepository';
import { common } from '@kit.AbilityKit';
import { WidgetData, WidgetTaskItem } from '../widget/model/WidgetData';
import { CapsuleWidgetData } from '../widget/model/CapsuleWidgetData';
import { LocalValues } from '../common/local/LocalValues';
import { fileIo as fs } from '@kit.CoreFileKit';
import { HudWidgetData } from '../widget/model/HudWidgetData';
import { HabitRepository } from '../common/repository/HabitRepository';
import { Habit, HabitRecordStatus, HabitStatus } from '../model/DDLModels';

export class WidgetUpdater {

  /**
   * 刷新所有已知的卡片
   * @param context 必须要传 Context 才能读取 Preferences
   */
  public static async updateAllWidgets(context: common.Context) {
    try {
      // 1. 获取 Form IDs 和 Preferences 实例
      const pref = await preferences.getPreferences(context, 'widget_store');
      const formIds = (await pref.get('formIds', [])) as Array<string>;

      if (formIds.length === 0) {
        console.warn('[WidgetUpdater] No widgets to update.');
        return;
      }

      // 2. 准备通用业务数据 (Repo)
      const repo = TaskRepository.getInstance();
      repo.setContext(context);

      const allTasks = await repo.getAllDDLs();
      const now = new Date().getTime();

      // 过滤：未完成、未归档、未删除、非习惯
      const activeTasks = allTasks
        .filter(t => !t.isArchived && !t.deleted && t.type !== 'habit')
        .sort((a, b) => new Date(a.endTime).getTime() - new Date(b.endTime).getTime());

      const validTasks = activeTasks
        .filter(t => !t.isCompleted)
        .sort((a, b) => new Date(a.endTime).getTime() - new Date(b.endTime).getTime());

      const capsuleData = new CapsuleWidgetData();
      const currentThemeKey = AppStorage.get<string>('currentThemeKey') ?? 'vibrant';
      capsuleData.themeKey = currentThemeKey;

      // 1. activeCount: 所有活跃任务数 (即 validTasks 的总数)
      capsuleData.activeCount = activeTasks.length;
      capsuleData.remainingCount = validTasks.length;

      // 2. nearbyCount: 计算24小时内到期的任务数
      // 逻辑：endTime > now (未过期) 且 (endTime - now) <= 24小时
      const oneDayMillis = 24 * 60 * 60 * 1000;
      const nearbyTasks = validTasks.filter(t => {
        const tTime = new Date(t.endTime).getTime();
        return tTime > now && (tTime - now) <= oneDayMillis;
      });
      capsuleData.nearbyCount = nearbyTasks.length;

      // 简单的文案逻辑
      if (validTasks.length === 0) {
        capsuleData.summary = "今日无待办";
      } else {
        const firstTask = validTasks[0];
        const end = new Date(firstTask.endTime).getTime();
        const diffHours = (end - now) / (1000 * 60 * 60);

        if (diffHours < 0) capsuleData.summary = "有任务已逾期";
        else if (diffHours < 24) capsuleData.summary = "近期有DDL";
        else capsuleData.summary = `有任务待完成`;
      }

      console.log('[WidgetUpdater] validTask.length ', validTasks.length, ' | capsuleData ', capsuleData.remainingCount, capsuleData.summary)

      const bindingCapsule = formBindingData.createFormBindingData({
        'widgetData': capsuleData
      });

      const hudData = new HudWidgetData();

      // 1. 日期字符串
      const weekDays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
      const dateObj = new Date();

      // 2. 紧急任务逻辑 (复用 sorted validTasks，第一个就是最急的)
      if (validTasks.length > 0) {
        const firstTask = validTasks[0];
        hudData.hasUrgent = true;
        hudData.urgentTaskName = firstTask.name;

        hudData.dateStr = `今日 · ${weekDays[dateObj.getDay()]} / ${dateObj.getDate()}日`;
      } else {
        hudData.hasUrgent = false;
        hudData.urgentTaskName = '';

        hudData.dateStr = `今日 · ${weekDays[dateObj.getDay()]} / ${dateObj.getMonth()}月${dateObj.getDate()}日`;
      }

      // 3. 习惯
      const habitRepo = HabitRepository.getInstance();
      const allHabits = await habitRepo.getAllHabits();
      const activeHabits = allHabits.filter(h => h.status === HabitStatus.ACTIVE);

      let pendingHabitCount = 0;

      const habitChecks = activeHabits.map(async (habit) => {
        return await WidgetUpdater.isHabitPending(habit, habitRepo, dateObj);
      });

      const habitResults = await Promise.all(habitChecks);
      // 统计返回 true (即未达标/待打卡) 的数量
      pendingHabitCount = habitResults.filter(isPending => isPending).length;


      // 4. 统计数据
      hudData.imminentCount = nearbyTasks.length; // 临近 (24h内)
      hudData.todoCount = validTasks.length;      // 待办
      hudData.totalCount = activeTasks.length;    // 总共 (活跃)
      hudData.habitCount = pendingHabitCount;

      console.log(`[WidgetUpdater] todoCount: ${hudData.todoCount} | totalCount: ${hudData.totalCount}`)

      const bindingHud = formBindingData.createFormBindingData({ 'hudData': hudData });


      // --- B. 构建列表组件数据 (WidgetData) ---
      // 只有当存在列表组件时，才真正需要去处理图片（为了性能，其实可以先判断一下是否有 'widget' 类型的卡片，但这里为了逻辑清晰先直接构建）
      const widgetData = new WidgetData();
      widgetData.themeKey = currentThemeKey;
      widgetData.totalCount = validTasks.length;
      widgetData.updateTime = new Date().toLocaleTimeString();

      const localValues = LocalValues.getInstance();
      await localValues.init(context);

      widgetData.isWhiteText = localValues.getWidgetIsWhiteText();

      // 图片处理逻辑 (保持原有逻辑)
      const rawBgPath = localValues.getWidgetBackgroundImage();
      let file: fs.File | null = null;
      let formImageKey = 'bgImage';

      if (rawBgPath && rawBgPath.length > 0) {
        const fsPath = rawBgPath.startsWith('file://') ? rawBgPath.substring(7) : rawBgPath;
        try {
          const stat = fs.statSync(fsPath);
          if (stat.size > 1024 * 1024) {
            console.error('[WidgetUpdater] ⚠️ WARNING: Image size > 1MB');
          }
          file = fs.openSync(fsPath, fs.OpenMode.READ_ONLY);
          widgetData.backgroundImage = 'memory://' + formImageKey;
        } catch (err) {
          console.error(`[WidgetUpdater] Failed to open image: ${err}`);
          widgetData.backgroundImage = null;
        }
      }

      // 构建任务列表项
      widgetData.tasks = validTasks.slice(0, 5).map(item => {
        const end = new Date(item.endTime).getTime();
        const diffHours = (end - now) / (1000 * 60 * 60);

        let timeText = '';
        let isUrgent = false;

        if (diffHours < 0) {
          timeText = '已逾期';
          isUrgent = true;
        } else if (diffHours < 24) {
          timeText = Math.floor(diffHours) + '小时后';
          isUrgent = diffHours < 6;
        } else {
          timeText = Math.floor(diffHours / 24) + '天后';
        }

        const widgetItem = new WidgetTaskItem();
        widgetItem.title = item.name;
        widgetItem.timeDesc = timeText;
        widgetItem.isUrgent = isUrgent;
        return widgetItem;
      });

      // 封装 List 数据
      let formDataList: Record<string, Object> = {
        'widgetData': widgetData
      };

      if (file) {
        let images: Record<string, number> = {};
        images[formImageKey] = file.fd;
        formDataList['formImages'] = images;
      }

      const bindingList = formBindingData.createFormBindingData(formDataList);

      // ==========================================
      // 4. 循环推送更新
      // ==========================================

      for (const id of formIds) {
        const type = await pref.get(id, 'widget') as string;

        console.info(`[WidgetUpdater] Dispatching to ID: ${id} | Type: ${type}`);

        try {
          if (type === 'widget_capsule'|| type === 'widget_lock_capsule') {
            console.debug(`[WidgetUpdater] Updating CAPSULE form ${id}`);
            await formProvider.updateForm(id, bindingCapsule);
          } else if (type === 'widget_transparent_clock_card') {
            await formProvider.updateForm(id, bindingHud);
          } else {
            console.debug(`[WidgetUpdater] Updating LIST form ${id}`);
            await formProvider.updateForm(id, bindingList);
          }
        } catch (updateErr) {
          // 单个卡片更新失败不应阻断其他卡片
          console.error(`[WidgetUpdater] Failed to update form ${id} (${type}): ${updateErr}`);

          // 可选：如果更新报 16501001 (ID不存在)，可以在这里顺手清理 pref
          // await WidgetUpdater.cleanInvalidId(context, id);
        }
      }

      console.info(`[WidgetUpdater] Updated ${formIds.length} widgets.`);

    } catch (e) {
      console.error(`[WidgetUpdater] Update failed: ${e}`);
    }
  }

  /**
   * 辅助方法：判断一个习惯在当前周期内是否“待完成” (Pending)
   * 返回 true 表示还需要打卡，false 表示已达标
   */
  private static async isHabitPending(habit: Habit, repo: HabitRepository, now: Date): Promise<boolean> {
    const target = Math.max(1, habit.timesPerPeriod);

    const GeneratedDestructArray_1 = repo.periodBounds(habit.period, now);
    const startDate = GeneratedDestructArray_1[0];
    const endDate = GeneratedDestructArray_1[1];

    const records = await repo.getRecordsForHabitInRange(habit.id, startDate, endDate);

    const completedCount = records
      .filter(r => r.status === HabitRecordStatus.COMPLETED)
      .reduce((sum, r) => sum + r.count, 0);

    return completedCount < target;
  }
}
