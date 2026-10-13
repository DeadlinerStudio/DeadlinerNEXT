export class FocusPresentation {
  static clock(raw: number): string {
    const seconds: number = Math.max(0, Math.floor(raw));
    const h: number = Math.floor(seconds / 3600);
    const m: string = ('0' + Math.floor(seconds % 3600 / 60).toString()).slice(-2);
    const s: string = ('0' + (seconds % 60).toString()).slice(-2);
    return (h > 0 ? h.toString() + ':' : '') + m + ':' + s;
  }
  static duration(raw: number): string {
    const seconds: number = Math.max(0, Math.floor(raw));
    const h: number = Math.floor(seconds / 3600);
    const m: number = Math.floor(seconds % 3600 / 60);
    return h > 0 ? h.toString() + ' 小时 ' + m.toString() + ' 分' :
      (m > 0 ? m.toString() + ' 分钟' : seconds.toString() + ' 秒');
  }
  static outcome(value: string | null): string {
    if (value === null || value === 'APPLIED' || value === 'NO_OP') return '';
    if (value === 'HABIT_NOT_DUE') return '非计划日可以专注，但不能打卡。可选择仅结束专注。';
    if (value === 'HABIT_INVALID_AMOUNT') return '请填写有效的本次实际完成数量。';
    if (value === 'TIMER_ALREADY_ACTIVE') return '请先结束当前专注，再开始另一项。';
    if (value === 'HABIT_NOT_ACTIVE' || value === 'TASK_NOT_ACTIVE') return '目标已非进行中，不能开始或继续专注。';
    if (value === 'INVALID_DURATION') return '请输入有效时长，不超过会话真实跨度。';
    if (value === 'INVALID_STATE') return '目标或会话已变化，请重新确认操作。';
    if (value === 'CLOCK_ANOMALY') return '系统时间发生变化，请检查后重试，当前计时未结束。';
    if (value === 'TIMER_REQUIRES_RESOLUTION') return '该目标已有新的计时，请先处理当前会话。';
    return '本次操作未完成，请刷新后重试。';
  }
  static warning(value: string | null): string {
    if (value === 'CLOCK_ANOMALY') return '系统时间发生变化，请检查计时；异常时间不会自动保存。';
    if (value === 'LONG_RUNNING') return '本轮已超过 12 小时，请确认是否忘记结束计时。';
    if (value === 'EXCESSIVE_DURATION') return '本轮跨度过长，请核对有效时长，必要时向下更正。';
    if (value === 'ALARM_UNAVAILABLE') return '到点提醒不可用，计时仍会保存；请留意倒计时。';
    return '';
  }
}
