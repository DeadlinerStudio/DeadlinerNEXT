import { describe, it, expect } from '@ohos/hypium';
import { buildActiveReminderScopeKey } from '../main/ets/model/ActiveReminder';
import { ReminderScheduler } from '../main/ets/utils/notification/ReminderScheduler';
import { DDLItem, DeadlineType } from '../main/ets/model/DDLModels';
import { TaskState } from '../main/ets/model/TaskStateMachine';

function makeTask(state: TaskState, deleted: boolean = false): DDLItem {
  return {
    id: 1,
    name: 'test',
    startTime: '2026-04-03T08:00:00.000Z',
    endTime: '2026-04-04T08:00:00.000Z',
    state: state,
    isCompleted: state === TaskState.COMPLETED || state === TaskState.ARCHIVED,
    completeTime: '',
    note: '',
    isArchived: state === TaskState.ARCHIVED || state === TaskState.ABANDONED_ARCHIVED,
    isStared: false,
    type: DeadlineType.TASK,
    habitCount: 0,
    habitTotalCount: 0,
    calendarEventId: null,
    timeStamp: '',
    uid: 'dev:1',
    deleted: deleted,
    verTs: '2026-04-03T08:00:00.000Z',
    verCtr: 0,
    verDev: 'dev'
  };
}

export default function reminderSchedulerTests() {
  describe('ReminderScheduler', () => {
    it('should build different scoped keys for task and habit with same target id', 0, () => {
      const ddlKey = buildActiveReminderScopeKey('DDL', '1');
      const habitKey = buildActiveReminderScopeKey('HABIT', '1');

      expect(ddlKey).assertEqual('DDL:1');
      expect(habitKey).assertEqual('HABIT:1');
      expect(ddlKey === habitKey).assertFalse();
    });

    it('should only schedule reminders for active tasks under snapshot v2 state model', 0, () => {
      expect(ReminderScheduler.shouldScheduleDDLReminder(makeTask(TaskState.ACTIVE))).assertTrue();
      expect(ReminderScheduler.shouldScheduleDDLReminder(makeTask(TaskState.COMPLETED))).assertFalse();
      expect(ReminderScheduler.shouldScheduleDDLReminder(makeTask(TaskState.ARCHIVED))).assertFalse();
      expect(ReminderScheduler.shouldScheduleDDLReminder(makeTask(TaskState.ABANDONED))).assertFalse();
      expect(ReminderScheduler.shouldScheduleDDLReminder(makeTask(TaskState.ABANDONED_ARCHIVED))).assertFalse();
      expect(ReminderScheduler.shouldScheduleDDLReminder(makeTask(TaskState.ACTIVE, true))).assertFalse();
    });
  });
}
