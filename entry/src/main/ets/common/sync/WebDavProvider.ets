import { ISyncProvider, SyncResultProvider } from './SyncProvider';
import { HabitSnapshotRoot, SnapshotRoot, SnapshotRootV1, SyncService } from './SyncService';
import { WebUtils, PreconditionFailedError } from '../network/WebUtils';
import { util } from '@kit.ArkTS';

export class WebDavProvider implements ISyncProvider {
  private web: WebUtils;
  private readonly v2Path = 'Deadliner/snapshot-v2.json';
  private readonly habitV2Path = 'Deadliner/habit-snapshot-v2.json';
  private readonly v1Path = 'Deadliner/snapshot-v1.json';
  private currentV2Etag: string | null = null;
  private currentHabitV2Etag: string | null = null;
  private currentV1Etag: string | null = null;
  private textDecoder = util.TextDecoder.create('utf-8');
  private textEncoder = new util.TextEncoder();

  constructor(web: WebUtils) {
    this.web = web;
  }

  async getRemoteSnapshot(): Promise<SyncResultProvider> {
    try {
      let ddlSnapshot: SnapshotRoot | null = null;
      let habitSnapshot: HabitSnapshotRoot | null = null;

      const v2Head = await this.web.head(this.v2Path);
      if (![404, 409, 410].includes(v2Head.code)) {
        const webBytes = await this.web.getBytes(this.v2Path);
        this.currentV2Etag = webBytes.etag;
        const jsonStr = this.textDecoder.decodeToString(webBytes.bytes);
        ddlSnapshot = SyncService.normalizeSnapshotV2(JSON.parse(jsonStr) as SnapshotRoot);
      }

      if (ddlSnapshot === null) {
        const v1Head = await this.web.head(this.v1Path);
        if (![404, 409, 410].includes(v1Head.code)) {
          const webBytes = await this.web.getBytes(this.v1Path);
          this.currentV1Etag = webBytes.etag;
          const jsonStr = this.textDecoder.decodeToString(webBytes.bytes);
          ddlSnapshot = SyncService.upgradeV1ToV2(JSON.parse(jsonStr) as SnapshotRootV1);
        }
      }

      const habitHead = await this.web.head(this.habitV2Path);
      if (![404, 409, 410].includes(habitHead.code)) {
        const webBytes = await this.web.getBytes(this.habitV2Path);
        this.currentHabitV2Etag = webBytes.etag;
        const jsonStr = this.textDecoder.decodeToString(webBytes.bytes);
        habitSnapshot = SyncService.normalizeHabitSnapshotV2(JSON.parse(jsonStr) as HabitSnapshotRoot);
      }

      return { success: true, ddlSnapshot, habitSnapshot };
    } catch (e) {
      return { success: false, ddlSnapshot: null, habitSnapshot: null };
    }
  }

  async putMergedSnapshot(ddlMerged: SnapshotRoot, habitMerged: HabitSnapshotRoot): Promise<boolean> {
    try {
      await this.web.ensureDir('Deadliner');

      const normalized = SyncService.normalizeSnapshotV2(ddlMerged);
      const v2Bytes = this.textEncoder.encodeInto(JSON.stringify(normalized));
      await this.web.putBytes(this.v2Path, v2Bytes, this.currentV2Etag, false);

      const v1Projection = SyncService.projectV2ToV1(normalized);
      const v1Bytes = this.textEncoder.encodeInto(JSON.stringify(v1Projection));
      await this.web.putBytes(this.v1Path, v1Bytes, this.currentV1Etag, false);

      const normalizedHabit = SyncService.normalizeHabitSnapshotV2(habitMerged);
      const habitBytes = this.textEncoder.encodeInto(JSON.stringify(normalizedHabit));
      await this.web.putBytes(this.habitV2Path, habitBytes, this.currentHabitV2Etag, false);
      return true;
    } catch (e) {
      if (e instanceof PreconditionFailedError) {
        console.warn('[WebDAV] Conflict 412');
      }
      return false;
    }
  }

  async triggerSync(): Promise<void> {
    // WebDAV 的同步完全由应用控制，不需要触发系统底层
  }
}
