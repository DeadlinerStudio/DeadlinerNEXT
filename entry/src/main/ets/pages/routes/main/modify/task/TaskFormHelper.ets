import { AppLog } from '../../../../../common/logging/AppLog';
import { promptAction } from '@kit.ArkUI';
import { TaskRepository } from '../../../../../common/repository/TaskRepository';
import { DeadlineType } from '../../../../../model/DDLModels';
import { DateTimeUtils } from '../../../../../utils/DateTimeUtils';
import { AIService } from '../../../../../ai/AIServcice';
import { i18n } from '@kit.LocalizationKit';
import { Toast } from '../../../../../common/ui/Toast';

export interface AITaskParseResult {
  name: string;
  note: string;
  endTime?: Date;
}

export class TaskFormHelper {
  // —— 核心保存逻辑 ——
  static async saveNewTask(
    name: string,
    note: string,
    startTime: Date,
    endTime: Date,
    categoryUid: string | null = null
  ): Promise<boolean> {
    if (!name.trim()) {
      Toast.show({ message: '请输入任务名称' });
      return false;
    }

    try {
      await TaskRepository.getInstance().insertDDL({
        name: name,
        startTime: DateTimeUtils.toLocalISOString(startTime),
        endTime: DateTimeUtils.toLocalISOString(endTime),
        note: note,
        isCompleted: false,
        completeTime: "",
        isArchived: false,
        isStared: false,
        type: DeadlineType.TASK,
        calendarEventId: null,
        categoryUid: categoryUid
      });

      Toast.show({ message: '创建成功' });
      return true;
    } catch (e) {
      AppLog.error('Native', `Add task failed: ${e}`);
      Toast.show({ message: '创建失败: ' + (e.message || e) });
      return false;
    }
  }

  // —— AI 解析逻辑 ——
  static async parseAIInput(aiInputText: string): Promise<AITaskParseResult | null> {
    if (!aiInputText || !aiInputText.trim()) {
      Toast.show({ message: '请输入内容后再尝试' });
      return null;
    }

    try {
      const service = AIService.getInstance();
      const sysLang = i18n.System.getSystemLanguage();
      const results = await service.extractTasks(aiInputText, sysLang);

      if (results && results.length !== 0) {
        const task = results[0];
        const endDate = task.dueTime ? DateTimeUtils.parseDateString(task.dueTime) : new Date();
        return {
          name: task.name,
          note: task.note ?? "",
          endTime: endDate || undefined
        };
      } else {
        Toast.show({ message: '未能识别出任务，请尝试换种说法' });
      }
    } catch (err) {
      Toast.show({
        message: `抱歉，遇到了一些问题：${err.message || '网络连接失败'}`
      });
    }
    return null;
  }
}
