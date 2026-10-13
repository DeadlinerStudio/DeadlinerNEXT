import { i18n } from '@kit.LocalizationKit';
import { quickAddParseJson } from 'libdeadliner_persistence.so';

export class QuickAddDraft {
  kind: string = 'TASK';
  title: string = '';
  dueAt: string | null = null;
  note: string = '';
  period: string = 'DAILY';
  targetCount: number = 1;
  weekdaysMask: number = 127;
  reminderTime: string | null = null;
  needsAI: boolean = false;
  ready: boolean = false;
  source: string = 'LOCAL';
  message: string = '';
}
export class QuickAddRequest {
  text: string;
  kind: string;
  timezone: string = i18n.getTimeZone().getID();
  now: string = new Date().toISOString();
  constructor(text: string, kind: string) { this.text = text; this.kind = kind; }
}
export class QuickAddModels {
  static parse(text: string, kind: string): QuickAddDraft {
    const draft: QuickAddDraft = JSON.parse(quickAddParseJson(JSON.stringify(new QuickAddRequest(text, kind))));
    return draft;
  }
  static detail(draft: QuickAddDraft): string {
    if (draft.kind === 'TASK') return '截止：' + (draft.dueAt ?? '未设置');
    const labels: string[] = ['一', '二', '三', '四', '五', '六', '日'];
    const days: string[] = [];
    for (let index: number = 0; index < labels.length; index++) {
      if ((draft.weekdaysMask & (1 << index)) !== 0) days.push(labels[index]);
    }
    const window: string = draft.period === 'WEEKLY' ? '每周' : draft.period === 'MONTHLY' ? '每月' :
      draft.period === 'TOTAL' ? '累计' : '每个执行日';
    return window + ' ' + draft.targetCount.toString() + ' 次 · 周' + days.join('、') +
      (draft.reminderTime ? ' · 提醒 ' + draft.reminderTime : '');
  }
}
