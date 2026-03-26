import localUnitTest from './LocalUnit.test';
import syncServiceTests from './SyncService.test';

export default function testsuite() {
  localUnitTest();
  syncServiceTests();
}
