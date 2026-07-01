import localUnitTest from './LocalUnit.test';
import deadlinerToolAdapterTests from './DeadlinerToolAdapter.test';
import reminderSchedulerTests from './ReminderScheduler.test';
import syncServiceTests from './SyncService.test';
import taskStateMachineTests from './TaskStateMachine.test';

export default function testsuite() {
  localUnitTest();
  deadlinerToolAdapterTests();
  reminderSchedulerTests();
  syncServiceTests();
  taskStateMachineTests();
}
