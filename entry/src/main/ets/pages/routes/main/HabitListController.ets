import { DDLListController } from './DDLListController'

export class HabitListController implements DDLListController {
  requestBatchComplete: () => void = () => {};
  requestBatchArchive: () => void = () => {};
  requestBatchDelete: () => void = () => {};
  requestBatchEdit: () => void = () => {};
  requestExitSelection: () => void = () => {};
  requestSetAlarm: () => void = () => {};
  loadData: () => void = () => {};
  onScroll: (offset: number) => void = () => {};
}
