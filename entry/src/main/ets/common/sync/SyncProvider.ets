import { HabitSnapshotRoot, SnapshotRoot } from './SyncService';

export interface SyncResultProvider {
  success: boolean;
  ddlSnapshot: SnapshotRoot | null;
  habitSnapshot: HabitSnapshotRoot | null;
}

export interface ISyncProvider {
  getRemoteSnapshot(): Promise<SyncResultProvider>;
  putMergedSnapshot(ddlMerged: SnapshotRoot, habitMerged: HabitSnapshotRoot): Promise<boolean>;
  triggerSync(): Promise<void>;
}
