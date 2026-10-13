import { AppLog } from '../../../../../common/logging/AppLog';
import { promptAction } from '@kit.ArkUI';
import { i18n } from '@kit.LocalizationKit';
import { HabitRepository } from '../../../../../common/repository/HabitRepository';
import { HabitGoalType, HabitPeriod } from '../../../../../model/DDLModels';
import { AIService } from '../../../../../ai/AIServcice';
import { Toast } from '../../../../../common/ui/Toast';

export interface AIParseResult {
  name: string;
  pIndex: number;
  gIndex: number;
  times: string;
  total: string;
}

export class HabitFormHelper {
  // —— 辅助映射函数 ——
  static getPeriodFromIndex(index: number): HabitPeriod {
    const map = [HabitPeriod.DAILY, HabitPeriod.WEEKLY, HabitPeriod.MONTHLY, HabitPeriod.EBBINGHAUS];
    return map[index] || HabitPeriod.DAILY;
  }

  static getGoalTypeFromIndex(index: number): HabitGoalType {
    const map = [HabitGoalType.PER_PERIOD, HabitGoalType.TOTAL];
    return map[index] || HabitGoalType.PER_PERIOD;
  }

  static isSimpleMode(pIndex: number): boolean {
    return pIndex === 3; // 3 代表艾宾浩斯
  }

  // —— 核心保存逻辑 ——
  static async saveNewHabit(
    name: string,
    pIndex: number,
    gIndex: number,
    timesPerPeriod: string,
    totalTarget: string,
    categoryUid: string | null = null,
    weekdaysMask: number = 127,
    reminderTime: string | null = null
  ): Promise<boolean> { // 返回 true 代表保存成功
    if (!name.trim()) {
      Toast.show({ message: '请输入习惯名称' });
      return false;
    }

    const currentPeriod = HabitFormHelper.getPeriodFromIndex(pIndex);
    let times = 1;
    let currentGoalType = HabitGoalType.PER_PERIOD;
    let total: number | null = null;

    if (!HabitFormHelper.isSimpleMode(pIndex)) {
      if ((weekdaysMask & 127) === 0) {
        Toast.show({ message: '请至少选择一个执行日' });
        return false;
      }
      times = parseInt(timesPerPeriod);
      if (isNaN(times) || times <= 0) {
        Toast.show({ message: '请输入有效的单次目标' });
        return false;
      }

      currentGoalType = HabitFormHelper.getGoalTypeFromIndex(gIndex);

      if (currentGoalType === HabitGoalType.TOTAL) {
        total = parseInt(totalTarget);
        if (isNaN(total) || total <= 0) {
          Toast.show({ message: '请输入有效的总目标' });
          return false;
        }
      }
    }

    try {
      await HabitRepository.getInstance().createHabit(
        name, currentPeriod, times, currentGoalType, total, '', null, null, 0, reminderTime, categoryUid, weekdaysMask
      );

      Toast.show({ message: '创建成功' });
      return true;
    } catch (e) {
      AppLog.error('Native', `Add habit failed: ${e}`);
      Toast.show({ message: '创建失败: ' + (e.message || e) });
      return false;
    }
  }

  // —— AI 解析逻辑 ——
  static async parseAIInput(aiInputText: string): Promise<AIParseResult | null> {
    if (!aiInputText || !aiInputText.trim()) {
      Toast.show({ message: '请输入内容后再尝试' });
      return null;
    }

    try {
      const service = AIService.getInstance();
      const sysLang = i18n.System.getSystemLanguage();
      const results = await service.extractHabits(aiInputText, sysLang);

      if (results && results.length !== 0) {
        const habit = results[0];

        let pIndex = 0;
        if (habit.period === 'WEEKLY') pIndex = 1;
        else if (habit.period === 'MONTHLY') pIndex = 2;

        let gIndex = 0;
        let total = "";
        if (habit.goalType === 'TOTAL') {
          gIndex = 1;
          if (habit.totalTarget) {
            total = habit.totalTarget.toString();
          }
        }

        return {
          name: habit.name,
          pIndex: pIndex,
          gIndex: gIndex,
          times: habit.timesPerPeriod.toString(),
          total: total
        };
      } else {
        Toast.show({ message: '未能识别出习惯，请尝试换种说法' });
      }
    } catch (err) {
      Toast.show({ message: `抱歉，遇到了一些问题：${err.message || '网络连接失败'}` });
    }
    return null;
  }
}
