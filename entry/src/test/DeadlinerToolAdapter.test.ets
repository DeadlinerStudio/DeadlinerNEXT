import { describe, it, expect } from '@ohos/hypium';
import { DeadlinerToolAdapter } from '../main/ets/ai/core/DeadlinerToolAdapter';
import { TaskRepository } from '../main/ets/common/repository/TaskRepository';
import { HabitRepository } from '../main/ets/common/repository/HabitRepository';

class StaticRepoGuard {
  private readonly originalTaskGetInstance: Object;
  private readonly originalHabitGetInstance: Object;

  constructor(taskMock: Object, habitMock: Object) {
    this.originalTaskGetInstance = (TaskRepository as Object)['getInstance'];
    this.originalHabitGetInstance = (HabitRepository as Object)['getInstance'];
    (TaskRepository as Object)['getInstance'] = () => taskMock;
    (HabitRepository as Object)['getInstance'] = () => habitMock;
  }

  restore(): void {
    (TaskRepository as Object)['getInstance'] = this.originalTaskGetInstance;
    (HabitRepository as Object)['getInstance'] = this.originalHabitGetInstance;
  }
}

function buildTaskRepoMock(startId: number = 100): Object {
  let nextId = startId;
  return {
    async insertDDL(): Promise<number> {
      const id = nextId;
      nextId += 1;
      return id;
    }
  };
}

function buildRejectingTaskRepoMock(): Object {
  return {
    async insertDDL(): Promise<number> {
      throw new Error('create_habit must not create a task carrier');
    }
  };
}

function buildHabitRepoMock(startId: number = 500): Object {
  let nextId = startId;
  return {
    async createHabit(): Promise<number> {
      const id = nextId;
      nextId += 1;
      return id;
    }
  };
}

export default function deadlinerToolAdapterTests() {
  describe('DeadlinerToolAdapter create_task/create_habit compatibility', () => {
    it('create_task 单条旧格式成功', 0, async (done: Function) => {
      const guard = new StaticRepoGuard(buildTaskRepoMock(), buildHabitRepoMock());
      try {
        const result = await DeadlinerToolAdapter.getInstance().execute({
          id: 't1',
          toolName: 'create_task',
          argsJson: JSON.stringify({ name: '任务A', dueTime: '2026-06-01 10:30', note: '备注A' })
        });
        const payload = result.payload as any;
        expect(payload['ok']).assertEqual(true);
        expect(payload['task']['name']).assertEqual('任务A');
        expect(payload['createdTasks'].length).assertEqual(1);
        expect(payload['summary']['successCount']).assertEqual(1);
        expect(payload['summary']['failCount']).assertEqual(0);
      } finally {
        guard.restore();
        done();
      }
    });

    it('create_task 批量新格式成功(>=2)', 0, async (done: Function) => {
      const guard = new StaticRepoGuard(buildTaskRepoMock(), buildHabitRepoMock());
      try {
        const result = await DeadlinerToolAdapter.getInstance().execute({
          id: 't2',
          toolName: 'create_task',
          argsJson: JSON.stringify({
            tasks: [
              { name: '任务B1', dueTime: '2026-06-01 11:00' },
              { name: '任务B2', dueTime: '2026-06-02 12:00', note: 'n2' }
            ]
          })
        });
        const payload = result.payload as any;
        expect(payload['ok']).assertEqual(true);
        expect(payload['createdTasks'].length).assertEqual(2);
        expect(payload['summary']['successCount']).assertEqual(2);
        expect(payload['summary']['failCount']).assertEqual(0);
      } finally {
        guard.restore();
        done();
      }
    });

    it('create_habit 单条旧格式成功', 0, async (done: Function) => {
      const guard = new StaticRepoGuard(buildRejectingTaskRepoMock(), buildHabitRepoMock());
      try {
        const result = await DeadlinerToolAdapter.getInstance().execute({
          id: 'h1',
          toolName: 'create_habit',
          argsJson: JSON.stringify({
            name: '习惯A',
            period: 'DAILY',
            timesPerPeriod: 2,
            goalType: 'PER_PERIOD'
          })
        });
        const payload = result.payload as any;
        expect(payload['ok']).assertEqual(true);
        expect(payload['habit']['name']).assertEqual('习惯A');
        expect(payload['createdHabits'].length).assertEqual(1);
        expect(payload['summary']['successCount']).assertEqual(1);
      } finally {
        guard.restore();
        done();
      }
    });

    it('create_habit 批量新格式成功(>=2)', 0, async (done: Function) => {
      const guard = new StaticRepoGuard(buildRejectingTaskRepoMock(), buildHabitRepoMock());
      try {
        const result = await DeadlinerToolAdapter.getInstance().execute({
          id: 'h2',
          toolName: 'create_habit',
          argsJson: JSON.stringify({
            habits: [
              { name: '习惯B1', period: 'WEEKLY', timesPerPeriod: 3, goalType: 'PER_PERIOD' },
              { name: '习惯B2', period: 'MONTHLY', timesPerPeriod: 1, goalType: 'TOTAL', totalTarget: 10 }
            ]
          })
        });
        const payload = result.payload as any;
        expect(payload['ok']).assertEqual(true);
        expect(payload['createdHabits'].length).assertEqual(2);
        expect(payload['summary']['successCount']).assertEqual(2);
        expect(payload['summary']['failCount']).assertEqual(0);
      } finally {
        guard.restore();
        done();
      }
    });

    it('批量里某条非法时返回部分失败', 0, async (done: Function) => {
      const guard = new StaticRepoGuard(buildTaskRepoMock(), buildHabitRepoMock());
      try {
        const result = await DeadlinerToolAdapter.getInstance().execute({
          id: 't3',
          toolName: 'create_task',
          argsJson: JSON.stringify({
            tasks: [
              { name: '任务C1', dueTime: '2026-06-03 12:00' },
              { name: '', dueTime: '2026-06-03 13:00' },
              { name: '任务C3', dueTime: '2026-06-03 14:00' }
            ]
          })
        });
        const payload = result.payload as any;
        expect(payload['ok']).assertEqual(false);
        expect(payload['summary']['successCount']).assertEqual(2);
        expect(payload['summary']['failCount']).assertEqual(1);
        expect(payload['items'][1]['ok']).assertEqual(false);
      } finally {
        guard.restore();
        done();
      }
    });

    it('空数组时报错', 0, async (done: Function) => {
      const guard = new StaticRepoGuard(buildTaskRepoMock(), buildHabitRepoMock());
      try {
        const taskResult = await DeadlinerToolAdapter.getInstance().execute({
          id: 't4',
          toolName: 'create_task',
          argsJson: JSON.stringify({ tasks: [] })
        });
        expect(taskResult.payload['ok']).assertEqual(false);
        expect(taskResult.payload['errorCode']).assertEqual('INVALID_ARGS');

        const habitResult = await DeadlinerToolAdapter.getInstance().execute({
          id: 'h4',
          toolName: 'create_habit',
          argsJson: JSON.stringify({ habits: [] })
        });
        expect(habitResult.payload['ok']).assertEqual(false);
        expect(habitResult.payload['errorCode']).assertEqual('INVALID_ARGS');
      } finally {
        guard.restore();
        done();
      }
    });

    it('缺关键字段时报错', 0, async (done: Function) => {
      const guard = new StaticRepoGuard(buildTaskRepoMock(), buildHabitRepoMock());
      try {
        const taskResult = await DeadlinerToolAdapter.getInstance().execute({
          id: 't-missing',
          toolName: 'create_task',
          argsJson: JSON.stringify({ name: '任务缺时间' })
        });
        expect(taskResult.payload['ok']).assertEqual(false);
        expect(taskResult.payload['errorCode']).assertEqual('INVALID_ARGS');

        const habitResult = await DeadlinerToolAdapter.getInstance().execute({
          id: 'h-missing',
          toolName: 'create_habit',
          argsJson: JSON.stringify({ period: 'DAILY', timesPerPeriod: 1, goalType: 'PER_PERIOD' })
        });
        expect(habitResult.payload['ok']).assertEqual(false);
        expect(habitResult.payload['errorCode']).assertEqual('INVALID_ARGS');
      } finally {
        guard.restore();
        done();
      }
    });

    it('dueTime 格式校验仍生效', 0, async (done: Function) => {
      const guard = new StaticRepoGuard(buildTaskRepoMock(), buildHabitRepoMock());
      try {
        const result = await DeadlinerToolAdapter.getInstance().execute({
          id: 't5',
          toolName: 'create_task',
          argsJson: JSON.stringify({ name: '任务D', dueTime: '2026/06/01 10:30' })
        });
        expect(result.payload['ok']).assertEqual(false);
        expect(result.payload['errorCode']).assertEqual('INVALID_ARGS');
      } finally {
        guard.restore();
        done();
      }
    });

    it('goalType=TOTAL 且缺 totalTarget 报错', 0, async (done: Function) => {
      const guard = new StaticRepoGuard(buildTaskRepoMock(), buildHabitRepoMock());
      try {
        const result = await DeadlinerToolAdapter.getInstance().execute({
          id: 'h5',
          toolName: 'create_habit',
          argsJson: JSON.stringify({
            name: '习惯D',
            period: 'DAILY',
            timesPerPeriod: 1,
            goalType: 'TOTAL'
          })
        });
        expect(result.payload['ok']).assertEqual(false);
        expect(result.payload['errorCode']).assertEqual('INVALID_ARGS');
      } finally {
        guard.restore();
        done();
      }
    });
  });
}
