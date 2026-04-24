import { DatabaseHelper } from '../data/DatabaseHelper';
import { relationalStore, ValuesBucket } from '@kit.ArkData';
import {
  DeadlineType,
  HabitGoalType,
  HabitPeriod,
  HabitRecordStatus,
  HabitStatus
} from '../../model/DDLModels';
import { ISyncProvider } from './SyncProvider';
import { LocalValues } from '../local/LocalValues';

export interface SnapshotVer {
  ts: string;
  ctr: number;
  dev: string;
}

export type SnapshotState = 'active' | 'completed' | 'archived' | 'abandoned' | 'abandonedArchived';

export interface SnapshotSubTask {
  id: string;
  content: string;
  is_completed: number;
  sort_order: number;
  created_at?: string;
  updated_at?: string;
}

export interface SnapshotDoc {
  id: number;
  name: string;
  start_time: string;
  end_time: string;
  state: SnapshotState;
  complete_time: string;
  note: string;
  is_stared: number;
  type: string;
  habit_count: number;
  habit_total_count: number;
  calendar_event: number;
  timestamp: string;
  sub_tasks: SnapshotSubTask[];
}

export interface SnapshotItem {
  uid: string;
  ver: SnapshotVer;
  deleted: boolean;
  doc: SnapshotDoc | null;
}

interface SnapshotInterface {
  ts: string;
  dev: string;
}

export interface SnapshotRoot {
  version: SnapshotInterface;
  items: SnapshotItem[];
}

export interface SnapshotV1Doc {
  id: number;
  name: string;
  start_time: string;
  end_time: string;
  is_completed: number;
  complete_time: string;
  note: string;
  is_archived: number;
  is_stared: number;
  type: string;
  habit_count: number;
  habit_total_count: number;
  calendar_event: number;
  timestamp: string;
}

export interface SnapshotV1Item {
  uid: string;
  ver: SnapshotVer;
  deleted: boolean;
  doc: SnapshotV1Doc | null;
}

export interface SnapshotRootV1 {
  version: SnapshotInterface;
  items: SnapshotV1Item[];
}

export interface HabitSnapshotDoc {
  ddl_uid: string;
  habit: HabitSnapshotPayload;
  records: HabitRecordSnapshot[];
}

export interface HabitSnapshotPayload {
  name: string;
  description: string | null;
  color: number | null;
  icon_key: string | null;
  period: HabitPeriod;
  times_per_period: number;
  goal_type: HabitGoalType;
  total_target: number | null;
  created_at: string;
  updated_at: string;
  status: HabitStatus;
  sort_order: number;
  alarm_time: string | null;
}

export interface HabitRecordSnapshot {
  date: string;
  count: number;
  status: HabitRecordStatus;
  created_at: string;
}

export interface HabitSnapshotItem {
  uid: string;
  ver: SnapshotVer;
  deleted: boolean;
  doc: HabitSnapshotDoc | null;
}

export interface HabitSnapshotRoot {
  version: SnapshotInterface;
  items: HabitSnapshotItem[];
}

export interface SyncResult {
  success: boolean;
  hasLocalChanges: boolean;
}

interface LegacyFlags {
  is_completed: number;
  is_archived: number;
}

interface SnapshotMergeable {
  uid: string;
  ver: SnapshotVer;
  deleted: boolean;
}

interface CarrierLookupResult {
  id: number;
  deleted: boolean;
  ver: SnapshotVer;
  habitAppliedVer: SnapshotVer;
}

interface HabitLookupResult {
  id: number;
  status: HabitStatus;
  updatedAt: string;
}

export type LocalHabitSnapshotBuildMode = 'emit_doc' | 'emit_tombstone' | 'skip';

export class SyncService {
  private db: DatabaseHelper;
  private provider: ISyncProvider;

  constructor(db: DatabaseHelper, provider: ISyncProvider) {
    this.db = db;
    this.provider = provider;
  }

  public switchProvider(newProvider: ISyncProvider) {
    this.provider = newProvider;
  }

  onLocalInserted(newLocalId: number) {}
  onLocalUpdated(localId: number) {}
  onLocalDeleting(localId: number) {}

  async syncOnce(): Promise<SyncResult> {
    console.info('SyncService: snapshot syncOnce start');
    try {
      return await this.syncSnapshotOnce();
    } catch (e) {
      console.warn(`Sync Failed: ${e}`);
      return { success: false, hasLocalChanges: false };
    }
  }

  static normalizeSnapshotV2(snapshot: SnapshotRoot): SnapshotRoot {
    const items = Array.isArray(snapshot?.items) ? snapshot.items : [];
    const version = snapshot?.version ?? SyncService.createSnapshotInterface(new Date().toISOString(), '');

    return {
      version: SyncService.createSnapshotInterface(version.ts ?? new Date().toISOString(), version.dev ?? ''),
      items: SyncService.normalizeSnapshotItems(items)
    };
  }

  static normalizeHabitSnapshotV2(snapshot: HabitSnapshotRoot): HabitSnapshotRoot {
    const items = Array.isArray(snapshot?.items) ? snapshot.items : [];
    const version = snapshot?.version ?? SyncService.createSnapshotInterface(new Date().toISOString(), '');

    return {
      version: SyncService.createSnapshotInterface(version.ts ?? new Date().toISOString(), version.dev ?? ''),
      items: SyncService.normalizeHabitSnapshotItems(items)
    };
  }

  static upgradeV1ToV2(snapshot: SnapshotRootV1): SnapshotRoot {
    const items = Array.isArray(snapshot?.items) ? snapshot.items : [];
    return {
      version: snapshot?.version ?? SyncService.createSnapshotInterface(new Date().toISOString(), ''),
      items: SyncService.upgradeV1ItemsToV2(items)
    };
  }

  static projectV2ToV1(snapshot: SnapshotRoot): SnapshotRootV1 {
    const normalized = SyncService.normalizeSnapshotV2(snapshot);
    return {
      version: normalized.version,
      items: normalized.items.map((item) => SyncService.projectV2ItemToV1(item))
    };
  }

  private static createSnapshotInterface(ts: string, dev: string): SnapshotInterface {
    return {
      ts: ts,
      dev: dev
    };
  }

  private static upgradeV1ItemToV2(item: SnapshotV1Item): SnapshotItem {
    const deleted = item?.deleted === true;
    const doc = deleted || !item?.doc ? null : SyncService.upgradeV1DocToV2(item.doc);
    return {
      uid: item.uid,
      ver: SyncService.normalizeVersion(item.ver),
      deleted: deleted,
      doc: doc
    };
  }

  private static upgradeV1DocToV2(doc: SnapshotV1Doc): SnapshotDoc {
    return {
      id: doc.id,
      name: doc.name ?? '',
      start_time: doc.start_time ?? '',
      end_time: doc.end_time ?? '',
      state: SyncService.legacyFlagsToState(doc.is_completed, doc.is_archived),
      complete_time: doc.complete_time ?? '',
      note: doc.note ?? '',
      is_stared: doc.is_stared ?? 0,
      type: doc.type ?? DeadlineType.TASK,
      habit_count: doc.habit_count ?? 0,
      habit_total_count: doc.habit_total_count ?? 0,
      calendar_event: doc.calendar_event ?? -1,
      timestamp: doc.timestamp ?? doc.start_time ?? '',
      sub_tasks: []
    };
  }

  private static projectV2ItemToV1(item: SnapshotItem): SnapshotV1Item {
    const doc = item.doc;
    const projectedDoc = doc ? SyncService.projectV2DocToV1(doc) : null;
    return {
      uid: item.uid,
      ver: item.ver,
      deleted: item.deleted,
      doc: projectedDoc
    };
  }

  private static projectV2DocToV1(doc: SnapshotDoc): SnapshotV1Doc {
    const legacy = SyncService.stateToLegacyFlags(doc.state);
    return {
      id: doc.id,
      name: doc.name,
      start_time: doc.start_time,
      end_time: doc.end_time,
      is_completed: legacy.is_completed,
      complete_time: doc.complete_time,
      note: doc.note,
      is_archived: legacy.is_archived,
      is_stared: doc.is_stared,
      type: doc.type,
      habit_count: doc.habit_count,
      habit_total_count: doc.habit_total_count,
      calendar_event: doc.calendar_event,
      timestamp: doc.timestamp
    };
  }

  private static normalizeSnapshotItem(item: SnapshotItem): SnapshotItem {
    const deleted = item?.deleted === true;
    const normalizedDoc = deleted ? null : SyncService.normalizeSnapshotDoc(item?.doc);
    return {
      uid: item?.uid ?? '',
      ver: SyncService.normalizeVersion(item?.ver),
      deleted: deleted,
      doc: normalizedDoc
    };
  }

  private static normalizeHabitSnapshotItem(item: HabitSnapshotItem): HabitSnapshotItem {
    const deleted = item?.deleted === true;
    const normalizedDoc = deleted ? null : SyncService.normalizeHabitSnapshotDoc(item?.uid ?? '', item?.doc);
    return {
      uid: item?.uid ?? '',
      ver: SyncService.normalizeVersion(item?.ver),
      deleted: deleted,
      doc: normalizedDoc
    };
  }

  private static normalizeSnapshotDoc(doc: SnapshotDoc | null | undefined): SnapshotDoc | null {
    if (!doc) {
      return null;
    }

    return {
      id: doc.id ?? 0,
      name: doc.name ?? '',
      start_time: doc.start_time ?? '',
      end_time: doc.end_time ?? '',
      state: SyncService.validateState(doc.state),
      complete_time: doc.complete_time ?? '',
      note: doc.note ?? '',
      is_stared: doc.is_stared ?? 0,
      type: doc.type ?? DeadlineType.TASK,
      habit_count: doc.habit_count ?? 0,
      habit_total_count: doc.habit_total_count ?? 0,
      calendar_event: doc.calendar_event ?? -1,
      timestamp: doc.timestamp ?? '',
      sub_tasks: SyncService.normalizeSubTasks(doc.sub_tasks)
    };
  }

  private static normalizeHabitSnapshotDoc(uid: string, doc: HabitSnapshotDoc | null | undefined): HabitSnapshotDoc | null {
    if (!doc) {
      return null;
    }
    if (doc.ddl_uid !== uid) {
      throw new Error(`[Sync] Habit snapshot ddl_uid mismatch for ${uid}`);
    }

    return {
      ddl_uid: doc.ddl_uid,
      habit: SyncService.normalizeHabitPayload(doc.habit),
      records: SyncService.normalizeHabitRecords(doc.records)
    };
  }

  private static normalizeSubTasks(subTasks: SnapshotSubTask[] | null | undefined): SnapshotSubTask[] {
    if (!Array.isArray(subTasks)) {
      return [];
    }

    const normalized: SnapshotSubTask[] = [];
    for (let index = 0; index < subTasks.length; index++) {
      try {
        normalized.push(SyncService.normalizeSubTask(subTasks[index], index));
      } catch (e) {
        console.warn(`[Sync] Skip malformed sub-task at index=${index}: ${e}`);
      }
    }
    return normalized;
  }

  private static normalizeSubTask(subTask: SnapshotSubTask, index: number): SnapshotSubTask {
    return {
      id: `${subTask?.id ?? `sub-${index}`}`,
      content: subTask?.content ?? '',
      is_completed: subTask?.is_completed === 1 ? 1 : 0,
      sort_order: typeof subTask?.sort_order === 'number' ? subTask.sort_order : index,
      created_at: subTask?.created_at,
      updated_at: subTask?.updated_at
    };
  }

  private static normalizeHabitPayload(payload: HabitSnapshotPayload | null | undefined): HabitSnapshotPayload {
    if (!payload) {
      throw new Error('[Sync] Missing habit payload');
    }
    SyncService.validateHabitPeriod(payload.period);
    SyncService.validateHabitGoalType(payload.goal_type);
    SyncService.validateHabitStatus(payload.status);
    if ((payload.times_per_period ?? 0) <= 0) {
      throw new Error(`[Sync] Invalid habit times_per_period: ${payload.times_per_period}`);
    }

    return {
      name: payload.name ?? '',
      description: payload.description ?? null,
      color: payload.color ?? null,
      icon_key: payload.icon_key ?? null,
      period: payload.period,
      times_per_period: payload.times_per_period,
      goal_type: payload.goal_type,
      total_target: payload.total_target ?? null,
      created_at: payload.created_at ?? '',
      updated_at: payload.updated_at ?? '',
      status: payload.status,
      sort_order: payload.sort_order ?? 0,
      alarm_time: payload.alarm_time ?? null
    };
  }

  private static normalizeHabitRecords(records: HabitRecordSnapshot[] | null | undefined): HabitRecordSnapshot[] {
    if (!Array.isArray(records)) {
      return [];
    }

    const normalized: HabitRecordSnapshot[] = [];
    for (const record of records) {
      try {
        normalized.push(SyncService.normalizeHabitRecord(record));
      } catch (e) {
        console.warn(`[Sync] Skip malformed habit record: ${e}`);
      }
    }
    return normalized;
  }

  private static normalizeHabitRecord(record: HabitRecordSnapshot): HabitRecordSnapshot {
    SyncService.validateHabitRecordStatus(record.status);
    if ((record.count ?? 0) <= 0) {
      throw new Error(`[Sync] Invalid habit record count: ${record.count}`);
    }
    return {
      date: record.date ?? '',
      count: record.count,
      status: record.status,
      created_at: record.created_at ?? ''
    };
  }

  private static validateHabitPeriod(period: string): HabitPeriod {
    if (
      period === HabitPeriod.DAILY ||
      period === HabitPeriod.WEEKLY ||
      period === HabitPeriod.MONTHLY ||
      period === HabitPeriod.ONCE ||
      period === HabitPeriod.EBBINGHAUS
    ) {
      return period as HabitPeriod;
    }
    throw new Error(`[Sync] Invalid habit period: ${period}`);
  }

  private static validateHabitGoalType(goalType: string): HabitGoalType {
    if (goalType === HabitGoalType.PER_PERIOD || goalType === HabitGoalType.TOTAL) {
      return goalType as HabitGoalType;
    }
    throw new Error(`[Sync] Invalid habit goal_type: ${goalType}`);
  }

  private static validateHabitStatus(status: string): HabitStatus {
    if (status === HabitStatus.ACTIVE || status === HabitStatus.ARCHIVED) {
      return status as HabitStatus;
    }
    throw new Error(`[Sync] Invalid habit status: ${status}`);
  }

  private static validateHabitRecordStatus(status: string): HabitRecordStatus {
    if (
      status === HabitRecordStatus.COMPLETED ||
      status === HabitRecordStatus.SKIPPED ||
      status === HabitRecordStatus.FAILED
    ) {
      return status as HabitRecordStatus;
    }
    throw new Error(`[Sync] Invalid habit record status: ${status}`);
  }

  private static normalizeVersion(ver: SnapshotVer | null | undefined): SnapshotVer {
    return {
      ts: ver?.ts ?? '1970-01-01T00:00:00Z',
      ctr: ver?.ctr ?? 0,
      dev: ver?.dev ?? ''
    };
  }

  private static validateState(state: string | null | undefined): SnapshotState {
    if (
      state === 'active' ||
      state === 'completed' ||
      state === 'archived' ||
      state === 'abandoned' ||
      state === 'abandonedArchived'
    ) {
      return state;
    }
    throw new Error(`[Sync] Invalid snapshot state: ${state}`);
  }

  private static legacyFlagsToState(isCompleted: number, isArchived: number): SnapshotState {
    if (isArchived === 1) return 'archived';
    if (isCompleted === 1) return 'completed';
    return 'active';
  }

  private static stateToLegacyFlags(state: SnapshotState): LegacyFlags {
    switch (state) {
      case 'active':
        return { is_completed: 0, is_archived: 0 };
      case 'completed':
        return { is_completed: 1, is_archived: 0 };
      case 'abandoned':
        return { is_completed: 0, is_archived: 0 };
      case 'archived':
      case 'abandonedArchived':
        return { is_completed: 1, is_archived: 1 };
      default:
        throw new Error(`[Sync] Invalid snapshot state: ${state}`);
    }
  }

  static isHabitAppliedVersionInitialized(ver: SnapshotVer | null | undefined): boolean {
    if (!ver) {
      return false;
    }
    return !(ver.ts === '1970-01-01T00:00:00Z' && ver.ctr === 0 && ver.dev === '');
  }

  static shouldApplyHabitSnapshot(remoteVer: SnapshotVer, appliedVer: SnapshotVer | null | undefined): boolean {
    if (!SyncService.isHabitAppliedVersionInitialized(appliedVer)) {
      return true;
    }
    return SyncService.isVerNewerStatic(remoteVer, appliedVer as SnapshotVer);
  }

  static appliedHabitVersionAfterApply(itemVer: SnapshotVer): SnapshotVer {
    return SyncService.createSnapshotVersion(itemVer.ts, itemVer.ctr, itemVer.dev);
  }

  static resolveLocalHabitSnapshotBuildMode(
    isCarrierDeleted: boolean,
    hasHabitEntity: boolean,
    carrierWriterDev: string,
    localDeviceId: string
  ): LocalHabitSnapshotBuildMode {
    if (isCarrierDeleted) {
      return 'emit_tombstone';
    }
    if (hasHabitEntity) {
      return 'emit_doc';
    }
    if (carrierWriterDev === localDeviceId) {
      return 'emit_tombstone';
    }
    return 'skip';
  }

  static habitUpdatedAtForLocalPayloadChange(ver: SnapshotVer): string {
    if (ver.ctr <= 0) {
      return ver.ts;
    }

    const match = ver.ts.match(/^(.*?)(?:\.(\d+))?Z$/);
    if (!match) {
      return ver.ts;
    }

    const prefix = match[1];
    const fraction = (match[2] ?? '000').padEnd(3, '0');
    return `${prefix}.${fraction}${ver.ctr.toString().padStart(3, '0')}Z`;
  }

  static shouldEmitActiveLocalHabitDoc(
    carrierVer: SnapshotVer,
    appliedVer: SnapshotVer | null | undefined,
    habitUpdatedAt: string
  ): boolean {
    if (!SyncService.isHabitAppliedVersionInitialized(appliedVer)) {
      return SyncService.isHabitPayloadFreshForCarrier(carrierVer, habitUpdatedAt);
    }

    if (!SyncService.isVerNewerStatic(carrierVer, appliedVer as SnapshotVer)) {
      return true;
    }

    return SyncService.isHabitPayloadFreshForCarrier(carrierVer, habitUpdatedAt);
  }

  static shouldApplyHabitSnapshotByContent(
    item: HabitSnapshotItem,
    appliedVer: SnapshotVer | null | undefined,
    localHabit: HabitLookupResult | null
  ): boolean {
    if (SyncService.shouldApplyHabitSnapshot(item.ver, appliedVer)) {
      return true;
    }

    if (item.deleted) {
      return localHabit !== null;
    }

    const remoteHabit = item.doc?.habit;
    if (!remoteHabit) {
      return false;
    }

    if (localHabit === null) {
      return true;
    }

    if (localHabit.status !== remoteHabit.status) {
      return true;
    }

    return localHabit.updatedAt !== remoteHabit.updated_at;
  }

  private static isVerNewerStatic(aVer: SnapshotVer, bVer: SnapshotVer): boolean {
    if (aVer.ts !== bVer.ts) return aVer.ts > bVer.ts;
    if (aVer.ctr !== bVer.ctr) return aVer.ctr > bVer.ctr;
    return aVer.dev >= bVer.dev;
  }

  static isTombstoneExpired(ver: SnapshotVer, retentionDays: number, nowTs: string): boolean {
    if (retentionDays <= 0) {
      return false;
    }
    const tombstoneAt = Date.parse(ver.ts);
    const nowAt = Date.parse(nowTs);
    if (isNaN(tombstoneAt) || isNaN(nowAt)) {
      return false;
    }
    const retentionMs = retentionDays * 24 * 60 * 60 * 1000;
    const cutoff = nowAt - retentionMs;
    return tombstoneAt < cutoff;
  }

  static filterExpiredTombstones<T extends SnapshotMergeable>(
    items: T[],
    retentionDays: number,
    nowTs: string
  ): T[] {
    if (retentionDays <= 0) {
      return items;
    }
    const kept: T[] = [];
    for (const item of items) {
      if (item.deleted && SyncService.isTombstoneExpired(item.ver, retentionDays, nowTs)) {
        continue;
      }
      kept.push(item);
    }
    return kept;
  }

  static findExpiredTombstoneUids<T extends SnapshotMergeable>(
    items: T[],
    retentionDays: number,
    nowTs: string
  ): string[] {
    if (retentionDays <= 0) {
      return [];
    }
    const expired: string[] = [];
    for (const item of items) {
      if (item.deleted && SyncService.isTombstoneExpired(item.ver, retentionDays, nowTs)) {
        expired.push(item.uid);
      }
    }
    return expired;
  }

  private static createSnapshotVersion(ts: string, ctr: number, dev: string): SnapshotVer {
    return {
      ts: ts,
      ctr: ctr,
      dev: dev
    };
  }

  private static createSnapshotItem(uid: string, ver: SnapshotVer, deleted: boolean, doc: SnapshotDoc | null): SnapshotItem {
    return {
      uid: uid,
      ver: ver,
      deleted: deleted,
      doc: doc
    };
  }

  private static createHabitSnapshotDoc(
    uid: string,
    habit: HabitSnapshotPayload,
    records: HabitRecordSnapshot[]
  ): HabitSnapshotDoc {
    return {
      ddl_uid: uid,
      habit: habit,
      records: records
    };
  }

  private static createHabitSnapshotItem(
    uid: string,
    ver: SnapshotVer,
    deleted: boolean,
    doc: HabitSnapshotDoc | null
  ): HabitSnapshotItem {
    return {
      uid: uid,
      ver: ver,
      deleted: deleted,
      doc: doc
    };
  }

  private static createSnapshotSubTask(
    id: string,
    content: string,
    isCompleted: number,
    sortOrder: number
  ): SnapshotSubTask {
    return {
      id: id,
      content: content,
      is_completed: isCompleted,
      sort_order: sortOrder
    };
  }

  private static createHabitRecordSnapshot(
    date: string,
    count: number,
    status: HabitRecordStatus,
    createdAt: string
  ): HabitRecordSnapshot {
    return {
      date: date,
      count: count,
      status: status,
      created_at: createdAt
    };
  }

  private static normalizeSnapshotItems(items: SnapshotItem[]): SnapshotItem[] {
    const normalized: SnapshotItem[] = [];
    for (const item of items) {
      try {
        normalized.push(SyncService.normalizeSnapshotItem(item));
      } catch (e) {
        console.warn(`[Sync] Skip malformed DDL snapshot item: ${e}`);
      }
    }
    return normalized;
  }

  private static normalizeHabitSnapshotItems(items: HabitSnapshotItem[]): HabitSnapshotItem[] {
    const normalized: HabitSnapshotItem[] = [];
    for (const item of items) {
      try {
        normalized.push(SyncService.normalizeHabitSnapshotItem(item));
      } catch (e) {
        console.warn(`[Sync] Skip malformed Habit snapshot item: ${e}`);
      }
    }
    return normalized;
  }

  private static upgradeV1ItemsToV2(items: SnapshotV1Item[]): SnapshotItem[] {
    const normalized: SnapshotItem[] = [];
    for (const item of items) {
      try {
        normalized.push(SyncService.upgradeV1ItemToV2(item));
      } catch (e) {
        console.warn(`[Sync] Skip malformed v1 snapshot item: ${e}`);
      }
    }
    return normalized;
  }

  private static isHabitPayloadFreshForCarrier(carrierVer: SnapshotVer, habitUpdatedAt: string): boolean {
    const expectedUpdatedAt = SyncService.habitUpdatedAtForLocalPayloadChange(carrierVer);
    if (habitUpdatedAt === expectedUpdatedAt) {
      return true;
    }

    const actualMs = Date.parse(habitUpdatedAt);
    const expectedMs = Date.parse(expectedUpdatedAt);
    if (!isNaN(actualMs) && !isNaN(expectedMs)) {
      return actualMs >= expectedMs;
    }

    return false;
  }

  private async buildLocalSnapshot(retentionDays: number, nowTs: string): Promise<SnapshotRoot> {
    const store = this.db.getRdbStore();
    if (!store) throw new Error('DB not initialized');

    const sql = `
      SELECT
        uid,
        COALESCE(deleted,0) AS deleted,
        COALESCE(ver_ts,'1970-01-01T00:00:00Z') AS ver_ts,
        COALESCE(ver_ctr,0) AS ver_ctr,
        COALESCE(ver_dev,'') AS ver_dev,
        id, name, start_time, end_time, state, is_completed, complete_time, note,
        is_archived, is_stared, type, habit_count, habit_total_count, calendar_event, timestamp
      FROM ddl_items
    `;

    const resultSet = await store.querySql(sql);
    const items: SnapshotItem[] = [];

    while (resultSet.goToNextRow()) {
      const uid = resultSet.getString(resultSet.getColumnIndex('uid'));
      if (!uid) continue;

      const deleted = resultSet.getLong(resultSet.getColumnIndex('deleted')) !== 0;
      const localId = resultSet.getLong(resultSet.getColumnIndex('id'));
      const ver = SyncService.createSnapshotVersion(
        resultSet.getString(resultSet.getColumnIndex('ver_ts')),
        resultSet.getLong(resultSet.getColumnIndex('ver_ctr')),
        resultSet.getString(resultSet.getColumnIndex('ver_dev'))
      );

      let doc: SnapshotDoc | null = null;
      if (!deleted) {
        doc = {
          id: localId,
          name: resultSet.getString(resultSet.getColumnIndex('name')),
          start_time: resultSet.getString(resultSet.getColumnIndex('start_time')),
          end_time: resultSet.getString(resultSet.getColumnIndex('end_time')),
          state: this.readLocalState(resultSet),
          complete_time: resultSet.getString(resultSet.getColumnIndex('complete_time')),
          note: resultSet.getString(resultSet.getColumnIndex('note')),
          is_stared: resultSet.getLong(resultSet.getColumnIndex('is_stared')),
          type: resultSet.getString(resultSet.getColumnIndex('type')),
          habit_count: resultSet.getLong(resultSet.getColumnIndex('habit_count')),
          habit_total_count: resultSet.getLong(resultSet.getColumnIndex('habit_total_count')),
          calendar_event: resultSet.getLong(resultSet.getColumnIndex('calendar_event')),
          timestamp: resultSet.getString(resultSet.getColumnIndex('timestamp')),
          sub_tasks: await this.buildLocalSubTasks(store, localId)
        };
      }

      if (deleted && SyncService.isTombstoneExpired(ver, retentionDays, nowTs)) {
        console.info(`[Sync] Prune expired tombstone uid=${uid} ver=${ver.ts} during local DDL snapshot build.`);
        continue;
      }

      items.push(SyncService.createSnapshotItem(uid, ver, deleted, doc));
    }
    resultSet.close();

    const deviceId = await this.db.getDeviceId();
    const snapshotTs = new Date().toISOString();

    return {
      version: SyncService.createSnapshotInterface(snapshotTs, deviceId),
      items: items
    };
  }

  private async buildLocalHabitSnapshot(retentionDays: number, nowTs: string): Promise<HabitSnapshotRoot> {
    const store = this.db.getRdbStore();
    if (!store) throw new Error('DB not initialized');

    const sql = `
      SELECT
        d.id AS ddl_id,
        d.uid AS ddl_uid,
        d.deleted AS ddl_deleted,
        d.ver_ts AS ver_ts,
        d.ver_ctr AS ver_ctr,
        d.ver_dev AS ver_dev,
        d.habit_applied_ver_ts AS habit_applied_ver_ts,
        d.habit_applied_ver_ctr AS habit_applied_ver_ctr,
        d.habit_applied_ver_dev AS habit_applied_ver_dev,
        h.id AS habit_id,
        h.name AS habit_name,
        h.description AS habit_description,
        h.color AS habit_color,
        h.icon_key AS habit_icon_key,
        h.period AS habit_period,
        h.times_per_period AS habit_times_per_period,
        h.goal_type AS habit_goal_type,
        h.total_target AS habit_total_target,
        h.created_at AS habit_created_at,
        h.updated_at AS habit_updated_at,
        h.status AS habit_status,
        h.sort_order AS habit_sort_order,
        h.alarm_time AS habit_alarm_time
      FROM ddl_items d
      LEFT JOIN habits h ON h.ddl_id = d.id
      WHERE d.type = 'habit'
        AND d.uid IS NOT NULL
      ORDER BY d.id ASC
    `;

    const resultSet = await store.querySql(sql);
    const items: HabitSnapshotItem[] = [];
    const localDeviceId = await this.db.getDeviceId();
    while (resultSet.goToNextRow()) {
      const uid = resultSet.getString(resultSet.getColumnIndex('ddl_uid'));
      const ddlDeleted = resultSet.getLong(resultSet.getColumnIndex('ddl_deleted')) !== 0;
      const hasHabit = !resultSet.isColumnNull(resultSet.getColumnIndex('habit_id'));
      const ver = SyncService.createSnapshotVersion(
        resultSet.getString(resultSet.getColumnIndex('ver_ts')),
        resultSet.getLong(resultSet.getColumnIndex('ver_ctr')),
        resultSet.getString(resultSet.getColumnIndex('ver_dev'))
      );
      const habitAppliedVer = SyncService.createSnapshotVersion(
        resultSet.getString(resultSet.getColumnIndex('habit_applied_ver_ts')),
        resultSet.getLong(resultSet.getColumnIndex('habit_applied_ver_ctr')),
        resultSet.getString(resultSet.getColumnIndex('habit_applied_ver_dev'))
      );

      const buildMode = SyncService.resolveLocalHabitSnapshotBuildMode(
        ddlDeleted,
        hasHabit,
        ver.dev,
        localDeviceId
      );

      if (buildMode === 'emit_tombstone') {
        if (SyncService.isTombstoneExpired(ver, retentionDays, nowTs)) {
          console.info(`[Sync] Prune expired tombstone uid=${uid} ver=${ver.ts} during local Habit snapshot build.`);
          continue;
        }
        console.info(`[Sync] Emit local Habit tombstone for carrier=${uid}.`);
        items.push(SyncService.createHabitSnapshotItem(uid, ver, true, null));
        continue;
      }

      if (buildMode === 'skip') {
        console.info(`[Sync] Skip local Habit snapshot for carrier=${uid} because habit entity is missing and carrier came from remote.`);
        continue;
      }

      const habitId = resultSet.getLong(resultSet.getColumnIndex('habit_id'));
      const habitUpdatedAt = resultSet.getString(resultSet.getColumnIndex('habit_updated_at'));
      if (!SyncService.shouldEmitActiveLocalHabitDoc(ver, habitAppliedVer, habitUpdatedAt)) {
        console.info(`[Sync] Skip local Habit snapshot for carrier=${uid} because carrier version is ahead of local habit payload.`);
        continue;
      }

      const habitPayload: HabitSnapshotPayload = {
        name: resultSet.getString(resultSet.getColumnIndex('habit_name')),
        description: this.getNullableString(resultSet, 'habit_description'),
        color: this.getNullableNumber(resultSet, 'habit_color'),
        icon_key: this.getNullableString(resultSet, 'habit_icon_key'),
        period: SyncService.validateHabitPeriod(resultSet.getString(resultSet.getColumnIndex('habit_period'))),
        times_per_period: resultSet.getLong(resultSet.getColumnIndex('habit_times_per_period')),
        goal_type: SyncService.validateHabitGoalType(resultSet.getString(resultSet.getColumnIndex('habit_goal_type'))),
        total_target: this.getNullableNumber(resultSet, 'habit_total_target'),
        created_at: resultSet.getString(resultSet.getColumnIndex('habit_created_at')),
        updated_at: habitUpdatedAt,
        status: SyncService.validateHabitStatus(resultSet.getString(resultSet.getColumnIndex('habit_status'))),
        sort_order: resultSet.getLong(resultSet.getColumnIndex('habit_sort_order')),
        alarm_time: this.getNullableString(resultSet, 'habit_alarm_time')
      };

      const records = await this.buildHabitRecordSnapshots(store, habitId);
      const habitDoc = SyncService.createHabitSnapshotDoc(uid, habitPayload, records);
      items.push(SyncService.createHabitSnapshotItem(uid, ver, false, habitDoc));
    }
    resultSet.close();

    const deviceId = await this.db.getDeviceId();
    const snapshotTs = new Date().toISOString();
    return {
      version: SyncService.createSnapshotInterface(snapshotTs, deviceId),
      items
    };
  }

  private async buildLocalSubTasks(store: relationalStore.RdbStore, ddlId: number): Promise<SnapshotSubTask[]> {
    const predicates = new relationalStore.RdbPredicates('subtasks');
    predicates.equalTo('ddl_id', ddlId);
    predicates.equalTo('deleted', 0);
    predicates.orderByAsc('sort_order');

    const resultSet = await store.query(predicates);
    const subTasks: SnapshotSubTask[] = [];

    while (resultSet.goToNextRow()) {
      const uid = resultSet.getString(resultSet.getColumnIndex('uid'));
      const localId = resultSet.getLong(resultSet.getColumnIndex('id'));
      subTasks.push(SyncService.createSnapshotSubTask(
        uid ? uid : `sub-${localId}`,
        resultSet.getString(resultSet.getColumnIndex('content')),
        resultSet.getLong(resultSet.getColumnIndex('is_completed')) === 1 ? 1 : 0,
        resultSet.getLong(resultSet.getColumnIndex('sort_order'))
      ));
    }
    resultSet.close();

    return subTasks;
  }

  private async buildHabitRecordSnapshots(
    store: relationalStore.RdbStore,
    habitId: number
  ): Promise<HabitRecordSnapshot[]> {
    const predicates = new relationalStore.RdbPredicates('habit_records');
    predicates.equalTo('habit_id', habitId);
    predicates.orderByAsc('date');
    predicates.orderByAsc('id');

    const resultSet = await store.query(predicates);
    const records: HabitRecordSnapshot[] = [];
    while (resultSet.goToNextRow()) {
      records.push(SyncService.createHabitRecordSnapshot(
        resultSet.getString(resultSet.getColumnIndex('date')),
        resultSet.getLong(resultSet.getColumnIndex('count')),
        SyncService.validateHabitRecordStatus(resultSet.getString(resultSet.getColumnIndex('status'))),
        resultSet.getString(resultSet.getColumnIndex('created_at'))
      ));
    }
    resultSet.close();
    return records;
  }

  private mergeSnapshots<T extends SnapshotMergeable>(
    localItems: T[],
    remoteItems: T[],
    retentionDays: number,
    nowTs: string
  ): T[] {
    const map = new Map<string, T>();
    const localFiltered = SyncService.filterExpiredTombstones(localItems, retentionDays, nowTs);
    const remoteFiltered = SyncService.filterExpiredTombstones(remoteItems, retentionDays, nowTs);
    for (const item of localFiltered) {
      map.set(item.uid, item);
    }
    for (const item of remoteFiltered) {
      const existing = map.get(item.uid);
      if (!existing || this.isVerNewer(item.ver, existing.ver)) {
        map.set(item.uid, item);
      }
    }
    return Array.from(map.values());
  }

  private mergeDdlSnapshots(local: SnapshotRoot, remote: SnapshotRoot, retentionDays: number, nowTs: string): SnapshotRoot {
    return {
      version: local.version,
      items: this.mergeSnapshots(local.items, remote.items, retentionDays, nowTs)
    };
  }

  private mergeHabitSnapshots(local: HabitSnapshotRoot, remote: HabitSnapshotRoot, retentionDays: number, nowTs: string): HabitSnapshotRoot {
    return {
      version: local.version,
      items: this.mergeSnapshots(local.items, remote.items, retentionDays, nowTs)
    };
  }

  private isVerNewer(aVer: SnapshotVer, bVer: SnapshotVer): boolean {
    if (aVer.ts !== bVer.ts) return aVer.ts > bVer.ts;
    if (aVer.ctr !== bVer.ctr) return aVer.ctr > bVer.ctr;
    return aVer.dev >= bVer.dev;
  }

  private async applySnapshotToLocal(merged: SnapshotRoot): Promise<boolean> {
    const store = this.db.getRdbStore();
    if (!store || !merged.items) return false;

    store.beginTransaction();
    let changed = false;

    try {
      for (const rawItem of merged.items) {
        try {
          const item = SyncService.normalizeSnapshotItem(rawItem);
          const uid = item.uid;
          const mergedVer = item.ver;

          const predicates = new relationalStore.RdbPredicates('ddl_items');
          predicates.equalTo('uid', uid);
          const resultSet = await store.query(predicates);
          const exists = resultSet.goToFirstRow();

          let localId: number | null = null;
          let currentLocalVer: SnapshotVer | null = null;

          if (exists) {
            localId = resultSet.getLong(resultSet.getColumnIndex('id'));
            currentLocalVer = SyncService.createSnapshotVersion(
              resultSet.getString(resultSet.getColumnIndex('ver_ts')),
              resultSet.getLong(resultSet.getColumnIndex('ver_ctr')),
              resultSet.getString(resultSet.getColumnIndex('ver_dev'))
            );
          }
          resultSet.close();

          if (currentLocalVer && this.isVerNewer(currentLocalVer, mergedVer)) {
            continue;
          }

          const bucket: ValuesBucket = {
            ver_ts: mergedVer.ts,
            ver_ctr: mergedVer.ctr,
            ver_dev: mergedVer.dev
          };

          if (item.deleted) {
            bucket['deleted'] = 1;
            if (exists && localId !== null) {
              const upPred = new relationalStore.RdbPredicates('ddl_items');
              upPred.equalTo('id', localId);
              await store.update(bucket, upPred);
              await this.markAllSubTasksDeleted(store, localId, mergedVer);
              changed = true;
            } else {
              bucket['uid'] = uid;
              bucket['name'] = '(deleted)';
              bucket['start_time'] = '';
              bucket['end_time'] = '';
              bucket['state'] = 'archived';
              bucket['complete_time'] = '';
              bucket['note'] = '';
              bucket['type'] = DeadlineType.TASK;
              bucket['timestamp'] = mergedVer.ts;
              bucket['is_completed'] = 1;
              bucket['is_archived'] = 1;
              bucket['is_stared'] = 0;
              bucket['habit_count'] = 0;
              bucket['habit_total_count'] = 0;
              bucket['calendar_event'] = -1;
              await store.insert('ddl_items', bucket);
              changed = true;
            }
            continue;
          }

          const doc = item.doc;
          if (!doc) {
            throw new Error(`[Sync] Missing doc for non-deleted item ${uid}`);
          }

          const legacyState = SyncService.stateToLegacyFlags(doc.state);
          bucket['deleted'] = 0;
          bucket['name'] = doc.name;
          bucket['start_time'] = doc.start_time;
          bucket['end_time'] = doc.end_time;
          bucket['state'] = doc.state;
          bucket['is_completed'] = legacyState.is_completed;
          bucket['complete_time'] = doc.complete_time;
          bucket['note'] = doc.note;
          bucket['is_archived'] = legacyState.is_archived;
          bucket['is_stared'] = doc.is_stared;
          bucket['type'] = doc.type;
          bucket['habit_count'] = doc.habit_count;
          bucket['habit_total_count'] = doc.habit_total_count;
          bucket['calendar_event'] = doc.calendar_event;
          bucket['timestamp'] = doc.timestamp;

          let targetId: number;
          if (exists && localId !== null) {
            const upPred = new relationalStore.RdbPredicates('ddl_items');
            upPred.equalTo('id', localId);
            await store.update(bucket, upPred);
            targetId = localId;
          } else {
            bucket['uid'] = uid;
            targetId = await store.insert('ddl_items', bucket);
          }

          await this.syncSubTasksForDDL(store, targetId, doc.sub_tasks, mergedVer);
          changed = true;
        } catch (e) {
          console.warn(`[Sync] Skip malformed merged DDL item: ${e}`);
        }
      }

      store.commit();
      return changed;
    } catch (e) {
      store.rollBack();
      if (e instanceof Error) {
        throw e;
      }
      throw new Error(`${e}`);
    }
  }

  private async applyHabitSnapshotToLocal(merged: HabitSnapshotRoot): Promise<boolean> {
    const store = this.db.getRdbStore();
    if (!store || !merged.items) return false;

    store.beginTransaction();
    let changed = false;

    try {
      for (const rawItem of merged.items) {
        try {
          const item = SyncService.normalizeHabitSnapshotItem(rawItem);
          const carrier = await this.findCarrierDDLByUid(store, item.uid);
          if (!carrier) {
            if (item.deleted) {
              console.info(`[Sync] Ignore Habit tombstone for missing carrier=${item.uid} as idempotent no-op.`);
              continue;
            }
            throw new Error(`[Sync] Habit carrier DDL missing for ${item.uid}`);
          }
          if (carrier.deleted) {
            if (item.deleted) {
              continue;
            }
            throw new Error(`[Sync] Habit carrier DDL missing for ${item.uid}`);
          }

          const localHabit = await this.findHabitByDdlId(store, carrier.id);
          if (!SyncService.shouldApplyHabitSnapshotByContent(item, carrier.habitAppliedVer, localHabit)) {
            console.info(`[Sync] Skip Habit apply for carrier=${item.uid} because remote payload is already reflected locally.`);
            continue;
          }

          if (item.deleted) {
            await this.deleteLocalHabitByCarrier(store, carrier.id);
            await this.touchDDLVersion(store, carrier.id, item.ver);
            await this.touchHabitAppliedVersion(store, carrier.id, SyncService.appliedHabitVersionAfterApply(item.ver));
            console.info(`[Sync] Applied Habit tombstone for carrier=${item.uid}.`);
            changed = true;
            continue;
          }

          const doc = item.doc;
          if (!doc) {
            throw new Error(`[Sync] Missing habit doc for non-deleted item ${item.uid}`);
          }
          const habitId = await this.upsertLocalHabit(store, carrier.id, localHabit?.id ?? null, doc.habit);
          await this.replaceLocalHabitRecords(store, habitId, doc.records);
          await this.touchHabitAppliedVersion(store, carrier.id, SyncService.appliedHabitVersionAfterApply(item.ver));
          console.info(`[Sync] Applied Habit snapshot doc for carrier=${item.uid}.`);
          changed = true;
        } catch (e) {
          console.warn(`[Sync] Skip malformed merged Habit item: ${e}`);
        }
      }

      store.commit();
      return changed;
    } catch (e) {
      store.rollBack();
      if (e instanceof Error) {
        throw e;
      }
      throw new Error(`${e}`);
    }
  }

  private async syncSubTasksForDDL(
    store: relationalStore.RdbStore,
    ddlId: number,
    subTasks: SnapshotSubTask[],
    mergedVer: SnapshotVer
  ): Promise<void> {
    const incoming = SyncService.normalizeSubTasks(subTasks);
    const predicates = new relationalStore.RdbPredicates('subtasks');
    predicates.equalTo('ddl_id', ddlId);

    const resultSet = await store.query(predicates);
    const existingByUid = new Map<string, number>();
    while (resultSet.goToNextRow()) {
      const uid = resultSet.getString(resultSet.getColumnIndex('uid'));
      const localId = resultSet.getLong(resultSet.getColumnIndex('id'));
      if (uid) {
        existingByUid.set(uid, localId);
      }
    }
    resultSet.close();

    const seen = new Set<string>();
    for (const subTask of incoming) {
      const bucket: ValuesBucket = {
        ddl_id: ddlId,
        content: subTask.content,
        is_completed: subTask.is_completed,
        sort_order: subTask.sort_order,
        deleted: 0,
        ver_ts: mergedVer.ts,
        ver_ctr: mergedVer.ctr,
        ver_dev: mergedVer.dev
      };

      const existingId = existingByUid.get(subTask.id);
      if (existingId !== undefined) {
        const upPred = new relationalStore.RdbPredicates('subtasks');
        upPred.equalTo('id', existingId);
        await store.update(bucket, upPred);
      } else {
        bucket['uid'] = subTask.id;
        await store.insert('subtasks', bucket);
      }
      seen.add(subTask.id);
    }

    const existingEntries = Array.from(existingByUid.entries());
    for (const entry of existingEntries) {
      const uid = entry[0];
      const localId = entry[1];
      if (seen.has(uid)) continue;
      const deleteBucket: ValuesBucket = {
        deleted: 1,
        ver_ts: mergedVer.ts,
        ver_ctr: mergedVer.ctr,
        ver_dev: mergedVer.dev
      };
      const deletePred = new relationalStore.RdbPredicates('subtasks');
      deletePred.equalTo('id', localId);
      await store.update(deleteBucket, deletePred);
    }
  }

  private async markAllSubTasksDeleted(
    store: relationalStore.RdbStore,
    ddlId: number,
    mergedVer: SnapshotVer
  ): Promise<void> {
    const bucket: ValuesBucket = {
      deleted: 1,
      ver_ts: mergedVer.ts,
      ver_ctr: mergedVer.ctr,
      ver_dev: mergedVer.dev
    };
    const predicates = new relationalStore.RdbPredicates('subtasks');
    predicates.equalTo('ddl_id', ddlId);
    await store.update(bucket, predicates);
  }

  private async findCarrierDDLByUid(
    store: relationalStore.RdbStore,
    uid: string
  ): Promise<CarrierLookupResult | null> {
    const predicates = new relationalStore.RdbPredicates('ddl_items');
    predicates.equalTo('uid', uid);

    const resultSet = await store.query(predicates);
    if (resultSet.goToFirstRow()) {
      const carrier: CarrierLookupResult = {
        id: resultSet.getLong(resultSet.getColumnIndex('id')),
        deleted: resultSet.getLong(resultSet.getColumnIndex('deleted')) !== 0,
        ver: SyncService.createSnapshotVersion(
          resultSet.getString(resultSet.getColumnIndex('ver_ts')),
          resultSet.getLong(resultSet.getColumnIndex('ver_ctr')),
          resultSet.getString(resultSet.getColumnIndex('ver_dev'))
        ),
        habitAppliedVer: SyncService.createSnapshotVersion(
          resultSet.getString(resultSet.getColumnIndex('habit_applied_ver_ts')),
          resultSet.getLong(resultSet.getColumnIndex('habit_applied_ver_ctr')),
          resultSet.getString(resultSet.getColumnIndex('habit_applied_ver_dev'))
        )
      };
      resultSet.close();
      return carrier;
    }
    resultSet.close();
    return null;
  }

  private async findHabitByDdlId(
    store: relationalStore.RdbStore,
    ddlId: number
  ): Promise<HabitLookupResult | null> {
    const predicates = new relationalStore.RdbPredicates('habits');
    predicates.equalTo('ddl_id', ddlId);
    const resultSet = await store.query(predicates);
    if (resultSet.goToFirstRow()) {
      const habit: HabitLookupResult = {
        id: resultSet.getLong(resultSet.getColumnIndex('id')),
        status: SyncService.validateHabitStatus(resultSet.getString(resultSet.getColumnIndex('status'))),
        updatedAt: resultSet.getString(resultSet.getColumnIndex('updated_at'))
      };
      resultSet.close();
      return habit;
    }
    resultSet.close();
    return null;
  }

  private async upsertLocalHabit(
    store: relationalStore.RdbStore,
    ddlId: number,
    existingHabitId: number | null,
    habit: HabitSnapshotPayload
  ): Promise<number> {
    const bucket: ValuesBucket = {
      ddl_id: ddlId,
      name: habit.name,
      description: habit.description ?? '',
      color: habit.color,
      icon_key: habit.icon_key,
      period: habit.period,
      times_per_period: habit.times_per_period,
      goal_type: habit.goal_type,
      total_target: habit.total_target,
      created_at: habit.created_at,
      updated_at: habit.updated_at,
      status: habit.status,
      sort_order: habit.sort_order,
      alarm_time: habit.alarm_time
    };

    if (existingHabitId !== null) {
      const predicates = new relationalStore.RdbPredicates('habits');
      predicates.equalTo('id', existingHabitId);
      await store.update(bucket, predicates);
      return existingHabitId;
    }

    return await store.insert('habits', bucket);
  }

  private async replaceLocalHabitRecords(
    store: relationalStore.RdbStore,
    habitId: number,
    records: HabitRecordSnapshot[]
  ): Promise<void> {
    if (habitId <= 0) {
      return;
    }
    const deletePredicates = new relationalStore.RdbPredicates('habit_records');
    deletePredicates.equalTo('habit_id', habitId);
    await store.delete(deletePredicates);

    for (const record of records) {
      const bucket: ValuesBucket = {
        habit_id: habitId,
        date: record.date,
        count: record.count,
        status: record.status,
        created_at: record.created_at
      };
      await store.insert('habit_records', bucket);
    }
  }

  private async deleteLocalHabitByCarrier(store: relationalStore.RdbStore, ddlId: number): Promise<void> {
    const habit = await this.findHabitByDdlId(store, ddlId);
    if (!habit) {
      return;
    }
    const recordPredicates = new relationalStore.RdbPredicates('habit_records');
    recordPredicates.equalTo('habit_id', habit.id);
    await store.delete(recordPredicates);

    const habitPredicates = new relationalStore.RdbPredicates('habits');
    habitPredicates.equalTo('id', habit.id);
    await store.delete(habitPredicates);
  }

  private async touchDDLVersion(store: relationalStore.RdbStore, ddlId: number, ver: SnapshotVer): Promise<void> {
    const bucket: ValuesBucket = {
      ver_ts: ver.ts,
      ver_ctr: ver.ctr,
      ver_dev: ver.dev
    };
    const predicates = new relationalStore.RdbPredicates('ddl_items');
    predicates.equalTo('id', ddlId);
    await store.update(bucket, predicates);
  }

  private async touchHabitAppliedVersion(
    store: relationalStore.RdbStore,
    ddlId: number,
    ver: SnapshotVer
  ): Promise<void> {
    const bucket: ValuesBucket = {
      habit_applied_ver_ts: ver.ts,
      habit_applied_ver_ctr: ver.ctr,
      habit_applied_ver_dev: ver.dev
    };
    const predicates = new relationalStore.RdbPredicates('ddl_items');
    predicates.equalTo('id', ddlId);
    await store.update(bucket, predicates);
  }

  private getNullableString(resultSet: relationalStore.ResultSet, column: string): string | null {
    const index = resultSet.getColumnIndex(column);
    return resultSet.isColumnNull(index) ? null : resultSet.getString(index);
  }

  private getNullableNumber(resultSet: relationalStore.ResultSet, column: string): number | null {
    const index = resultSet.getColumnIndex(column);
    return resultSet.isColumnNull(index) ? null : resultSet.getLong(index);
  }

  private readLocalState(resultSet: relationalStore.ResultSet): SnapshotState {
    const stateIndex = resultSet.getColumnIndex('state');
    if (stateIndex >= 0) {
      const rawState = resultSet.getString(stateIndex);
      if (
        rawState === 'active' ||
        rawState === 'completed' ||
        rawState === 'archived' ||
        rawState === 'abandoned' ||
        rawState === 'abandonedArchived'
      ) {
        return rawState;
      }
      if (rawState && rawState.length > 0) {
        throw new Error(`[Sync] Invalid local state: ${rawState}`);
      }
    }

    return SyncService.legacyFlagsToState(
      resultSet.getLong(resultSet.getColumnIndex('is_completed')),
      resultSet.getLong(resultSet.getColumnIndex('is_archived'))
    );
  }

  private async syncSnapshotOnce(): Promise<SyncResult> {
    const nowTs = new Date().toISOString();
    const retentionDays = LocalValues.getInstance().getTombstoneRetentionDays();

    const localDdlSnapshot = await this.buildLocalSnapshot(retentionDays, nowTs);
    const localHabitSnapshot = await this.buildLocalHabitSnapshot(retentionDays, nowTs);

    const remoteRes = await this.provider.getRemoteSnapshot();
    if (!remoteRes.success) {
      console.error('[Sync] Failed to get remote snapshots.');
      return { success: false, hasLocalChanges: false };
    }

    const remoteDdlSnapshot = remoteRes.ddlSnapshot
      ? SyncService.normalizeSnapshotV2(remoteRes.ddlSnapshot)
      : null;
    const remoteHabitSnapshot = remoteRes.habitSnapshot
      ? SyncService.normalizeHabitSnapshotV2(remoteRes.habitSnapshot)
      : null;

    const mergedDdlSnapshot = remoteDdlSnapshot === null
      ? localDdlSnapshot
      : this.mergeDdlSnapshots(localDdlSnapshot, remoteDdlSnapshot, retentionDays, nowTs);

    const ddlChanges = await this.applySnapshotToLocal(mergedDdlSnapshot);

    const mergedHabitSnapshot = remoteHabitSnapshot === null
      ? localHabitSnapshot
      : this.mergeHabitSnapshots(localHabitSnapshot, remoteHabitSnapshot, retentionDays, nowTs);

    const habitChanges = await this.applyHabitSnapshotToLocal(mergedHabitSnapshot);

    const putSuccess = await this.provider.putMergedSnapshot(mergedDdlSnapshot, mergedHabitSnapshot);
    if (!putSuccess) {
      console.error('[Sync] Failed to put merged snapshots to remote.');
      return { success: false, hasLocalChanges: ddlChanges || habitChanges };
    }

    await this.provider.triggerSync();
    if (retentionDays > 0) {
      const cutoffTs = new Date(Date.parse(nowTs) - retentionDays * 24 * 60 * 60 * 1000).toISOString();
      const prunedCount = await this.db.pruneExpiredDeletedDDLs(cutoffTs);
      console.info(`[Sync] Pruned ${prunedCount} expired tombstones after sync success.`);
    }
    return { success: true, hasLocalChanges: ddlChanges || habitChanges };
  }
}
