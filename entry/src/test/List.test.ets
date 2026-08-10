import localUnitTest from './LocalUnit.test';
import deadlinerToolAdapterTests from './DeadlinerToolAdapter.test';
import reminderSchedulerTests from './ReminderScheduler.test';
import taskStateMachineTests from './TaskStateMachine.test';
import semanticResolverTests from './SemanticResolver.test';

export default function testsuite() {
  localUnitTest();
  deadlinerToolAdapterTests();
  reminderSchedulerTests();
  taskStateMachineTests();
  semanticResolverTests();
}
