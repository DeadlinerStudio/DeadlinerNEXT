import { ISyncProvider, SyncResultProvider } from './SyncProvider';
import { HabitSnapshotRoot, SnapshotRoot, SnapshotRootV1, SyncService } from './SyncService';
import { cloudSync, fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';

export class CloudSyncProvider implements ISyncProvider {
  private readonly v2FileName = 'snapshot-v2.json';
  private readonly habitV2FileName = 'habit-snapshot-v2.json';
  private readonly v1FileName = 'snapshot-v1.json';
  private cloudBaseDir: string;
  private fileSync = new cloudSync.FileSync();

  constructor(context: common.Context) {
    this.cloudBaseDir = (context as common.UIAbilityContext).cloudFileDir;
  }

  private getFilePath(fileName: string): string {
    return `${this.cloudBaseDir}/${fileName}`;
  }

  async getRemoteSnapshot(): Promise<SyncResultProvider> {
    const v2Path = this.getFilePath(this.v2FileName);
    const habitV2Path = this.getFilePath(this.habitV2FileName);
    const v1Path = this.getFilePath(this.v1FileName);
    try {
      let ddlSnapshot: SnapshotRoot | null = null;
      let habitSnapshot: HabitSnapshotRoot | null = null;

      if (this.fileExists(v2Path)) {
        const fileContent = fs.readTextSync(v2Path);
        ddlSnapshot = SyncService.normalizeSnapshotV2(JSON.parse(fileContent) as SnapshotRoot);
      }

      if (ddlSnapshot === null && this.fileExists(v1Path)) {
        const fileContent = fs.readTextSync(v1Path);
        ddlSnapshot = SyncService.upgradeV1ToV2(JSON.parse(fileContent) as SnapshotRootV1);
      }

      if (this.fileExists(habitV2Path)) {
        const fileContent = fs.readTextSync(habitV2Path);
        habitSnapshot = SyncService.normalizeHabitSnapshotV2(JSON.parse(fileContent) as HabitSnapshotRoot);
      }

      return { success: true, ddlSnapshot, habitSnapshot };
    } catch (e) {
      console.error(`[CloudSync] Read remote snapshot failed: ${e}`);
      return { success: false, ddlSnapshot: null, habitSnapshot: null };
    }
  }

  async putMergedSnapshot(ddlMerged: SnapshotRoot, habitMerged: HabitSnapshotRoot): Promise<boolean> {
    try {
      const normalized = SyncService.normalizeSnapshotV2(ddlMerged);
      await this.writeFileAtomically(this.getFilePath(this.v2FileName), JSON.stringify(normalized));
      await this.writeFileAtomically(
        this.getFilePath(this.v1FileName),
        JSON.stringify(SyncService.projectV2ToV1(normalized))
      );
      await this.writeFileAtomically(
        this.getFilePath(this.habitV2FileName),
        JSON.stringify(SyncService.normalizeHabitSnapshotV2(habitMerged))
      );

      console.info('[CloudSync] Write merged snapshot success (Atomic)');
      return true;
    } catch (e) {
      console.error(`[CloudSync] Write merged snapshot failed: ${e}`);
      return false;
    }
  }

  async triggerSync(): Promise<void> {
    try {
      await this.fileSync.start();
    } catch (e) {
      console.warn(`[CloudSync] triggerSync failed: ${JSON.stringify(e)}`);
    }
  }

  private fileExists(filePath: string): boolean {
    try {
      return fs.accessSync(filePath);
    } catch (e) {
      return false;
    }
  }

  private async writeFileAtomically(filePath: string, content: string): Promise<void> {
    const tmpPath = `${filePath}.tmp`;
    const file = fs.openSync(tmpPath, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.WRITE_ONLY);
    fs.writeSync(file.fd, content);
    fs.closeSync(file);

    try {
      if (this.fileExists(filePath)) {
        fs.unlinkSync(filePath);
      }
    } catch (e) {
    }

    fs.renameSync(tmpPath, filePath);
  }
}
