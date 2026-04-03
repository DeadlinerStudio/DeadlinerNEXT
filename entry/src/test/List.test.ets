import localUnitTest from './LocalUnit.test';
import syncServiceTests from './SyncService.test';
import taskStateMachineTests from './TaskStateMachine.test';

export default function testsuite() {
  localUnitTest();
  syncServiceTests();
  taskStateMachineTests();
}
