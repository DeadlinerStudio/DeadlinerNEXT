import localUnitTest from './LocalUnit.test';
import reminderSchedulerTests from './ReminderScheduler.test';
import syncServiceTests from './SyncService.test';
import taskStateMachineTests from './TaskStateMachine.test';

export default function testsuite() {
  localUnitTest();
  reminderSchedulerTests();
  syncServiceTests();
  taskStateMachineTests();
}
