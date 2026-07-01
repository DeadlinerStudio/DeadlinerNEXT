import { describe, it, expect } from '@ohos/hypium';
import {
  HabitSnapshotItem,
  SyncService,
  SnapshotVer,
  SnapshotItem
} from '../main/ets/common/sync/SyncService';
import { HabitGoalType, HabitPeriod, HabitStatus } from '../main/ets/model/DDLModels';

export default function syncServiceTests() {
  describe('SyncServiceHabitSnapshotRules', () => {
    it('applies first habit snapshot even when carrier version matches', 0, () => {
      const itemVer: SnapshotVer = {
        ts: '2026-03-24T12:00:00.123Z',
        ctr: 0,
        dev: 'REMOTE'
      };
      const unsetAppliedVer: SnapshotVer = {
        ts: '1970-01-01T00:00:00Z',
        ctr: 0,
        dev: ''
      };

      const shouldApply = SyncService.shouldApplyHabitSnapshot(itemVer, unsetAppliedVer);
      expect(shouldApply).assertEqual(true);
    });

    it('writes applied version after active habit apply', 0, () => {
      const itemVer: SnapshotVer = {
        ts: '2026-03-24T12:00:01.456Z',
        ctr: 2,
        dev: 'REMOTE'
      };

      const appliedVer = SyncService.appliedHabitVersionAfterApply(itemVer);
      expect(appliedVer.ts).assertEqual(itemVer.ts);
      expect(appliedVer.ctr).assertEqual(itemVer.ctr);
      expect(appliedVer.dev).assertEqual(itemVer.dev);
    });

    it('writes applied version after tombstone apply', 0, () => {
      const tombstoneVer: SnapshotVer = {
        ts: '2026-03-24T12:00:02.789Z',
        ctr: 3,
        dev: 'REMOTE'
      };

      const appliedVer = SyncService.appliedHabitVersionAfterApply(tombstoneVer);
      expect(appliedVer.ts).assertEqual(tombstoneVer.ts);
      expect(appliedVer.ctr).assertEqual(tombstoneVer.ctr);
      expect(appliedVer.dev).assertEqual(tombstoneVer.dev);
    });

    it('does not fabricate tombstone when habit is missing but carrier came from remote', 0, () => {
      const buildMode = SyncService.resolveLocalHabitSnapshotBuildMode(
        false,
        false,
        'REMOTE',
        'LOCAL'
      );
      expect(buildMode).assertEqual('skip');
    });

    it('emits tombstone when habit is missing and carrier was last written locally', 0, () => {
      const buildMode = SyncService.resolveLocalHabitSnapshotBuildMode(
        false,
        false,
        'LOCAL',
        'LOCAL'
      );
      expect(buildMode).assertEqual('emit_tombstone');
    });

    it('emits active doc after local habit payload catches up to carrier version', 0, () => {
      const carrierVer: SnapshotVer = {
        ts: '2026-03-25T12:00:03.100Z',
        ctr: 1,
        dev: 'LOCAL'
      };
      const appliedVer: SnapshotVer = {
        ts: '2026-03-25T12:00:03.100Z',
        ctr: 0,
        dev: 'LOCAL'
      };

      const shouldEmit = SyncService.shouldEmitActiveLocalHabitDoc(
        carrierVer,
        appliedVer,
        SyncService.habitUpdatedAtForLocalPayloadChange(carrierVer)
      );
      expect(shouldEmit).assertEqual(true);
    });

    it('skips local active doc when carrier version is ahead but habit payload is stale', 0, () => {
      const carrierVer: SnapshotVer = {
        ts: '2026-03-25T12:00:03.100Z',
        ctr: 1,
        dev: 'REMOTE'
      };
      const appliedVer: SnapshotVer = {
        ts: '2026-03-25T12:00:03.100Z',
        ctr: 0,
        dev: 'REMOTE'
      };

      const shouldEmit = SyncService.shouldEmitActiveLocalHabitDoc(
        carrierVer,
        appliedVer,
        '2026-03-25T12:00:03.100Z'
      );
      expect(shouldEmit).assertEqual(false);
    });

    it('accepts payload freshness when updated_at is slightly ahead of the derived version timestamp', 0, () => {
      const carrierVer: SnapshotVer = {
        ts: '2026-03-25T12:00:03.100Z',
        ctr: 1,
        dev: 'REMOTE'
      };
      const appliedVer: SnapshotVer = {
        ts: '2026-03-25T12:00:03.100Z',
        ctr: 0,
        dev: 'REMOTE'
      };

      const shouldEmit = SyncService.shouldEmitActiveLocalHabitDoc(
        carrierVer,
        appliedVer,
        '2026-03-25T12:00:03.101Z'
      );
      expect(shouldEmit).assertEqual(true);
    });

    it('local payload changes require new version and updated_at follows that version', 0, () => {
      const beforeVer: SnapshotVer = {
        ts: '2026-03-24T12:00:03.100Z',
        ctr: 0,
        dev: 'LOCAL'
      };
      const afterVer: SnapshotVer = {
        ts: '2026-03-24T12:00:03.100Z',
        ctr: 1,
        dev: 'LOCAL'
      };

      const beforeUpdatedAt = SyncService.habitUpdatedAtForLocalPayloadChange(beforeVer);
      const afterUpdatedAt = SyncService.habitUpdatedAtForLocalPayloadChange(afterVer);

      expect(SyncService.shouldApplyHabitSnapshot(afterVer, beforeVer)).assertEqual(true);
      expect(beforeUpdatedAt === afterUpdatedAt).assertEqual(false);
      expect(afterUpdatedAt).assertEqual('2026-03-24T12:00:03.100001Z');
    });

    it('re-applies equal-version habit snapshot when local payload is missing', 0, () => {
      const item: HabitSnapshotItem = {
        uid: 'REMOTE:42',
        ver: {
          ts: '2026-03-24T12:00:03.100Z',
          ctr: 1,
          dev: 'REMOTE'
        },
        deleted: false,
        doc: {
          ddl_uid: 'REMOTE:42',
          habit: {
            name: 'Read',
            description: null,
            color: null,
            icon_key: null,
            period: HabitPeriod.DAILY,
            times_per_period: 1,
            goal_type: HabitGoalType.PER_PERIOD,
            total_target: null,
            created_at: '2026-03-24T12:00:03.100Z',
            updated_at: '2026-03-24T12:00:03.100001Z',
            status: HabitStatus.ARCHIVED,
            sort_order: 0,
            alarm_time: null
          },
          records: []
        }
      };
      const appliedVer: SnapshotVer = {
        ts: '2026-03-24T12:00:03.100Z',
        ctr: 1,
        dev: 'REMOTE'
      };

      expect(SyncService.shouldApplyHabitSnapshotByContent(item, appliedVer, null)).assertEqual(true);
    });

    it('re-applies equal-version habit snapshot when remote status differs from local status', 0, () => {
      const item: HabitSnapshotItem = {
        uid: 'REMOTE:43',
        ver: {
          ts: '2026-03-24T12:00:03.100Z',
          ctr: 1,
          dev: 'REMOTE'
        },
        deleted: false,
        doc: {
          ddl_uid: 'REMOTE:43',
          habit: {
            name: 'Meditate',
            description: null,
            color: null,
            icon_key: null,
            period: HabitPeriod.DAILY,
            times_per_period: 1,
            goal_type: HabitGoalType.PER_PERIOD,
            total_target: null,
            created_at: '2026-03-24T12:00:03.100Z',
            updated_at: '2026-03-24T12:00:03.100001Z',
            status: HabitStatus.ARCHIVED,
            sort_order: 0,
            alarm_time: null
          },
          records: []
        }
      };
      const appliedVer: SnapshotVer = {
        ts: '2026-03-24T12:00:03.100Z',
        ctr: 1,
        dev: 'REMOTE'
      };

      expect(SyncService.shouldApplyHabitSnapshotByContent(item, appliedVer, {
        id: 1,
        status: HabitStatus.ACTIVE,
        updatedAt: '2026-03-24T12:00:03.100001Z'
      })).assertEqual(true);
    });
  });

  describe('SyncServiceTombstoneRetention', () => {
    it('keeps tombstone during build when retention is enabled but tombstone is still fresh', 0, () => {
      const nowTs = '2026-04-01T12:00:00.000Z';
      const ver: SnapshotVer = { ts: '2026-03-20T12:00:00.000Z', ctr: 0, dev: 'LOCAL' };

      expect(SyncService.isTombstoneExpired(ver, 30, nowTs)).assertEqual(false);
    });

    it('filters tombstone during build when retention is enabled and tombstone is expired', 0, () => {
      const nowTs = '2026-04-01T12:00:00.000Z';
      const items: SnapshotItem[] = [{
        uid: 'LOCAL:1',
        ver: { ts: '2026-02-20T12:00:00.000Z', ctr: 0, dev: 'LOCAL' },
        deleted: true,
        doc: null
      }];

      const filtered = SyncService.filterExpiredTombstones(items, 30, nowTs);
      expect(filtered.length).assertEqual(0);
    });

    it('filters expired tombstones during merge candidates', 0, () => {
      const nowTs = '2026-04-01T12:00:00.000Z';
      const items: SnapshotItem[] = [
        {
          uid: 'LOCAL:1',
          ver: { ts: '2026-02-20T12:00:00.000Z', ctr: 0, dev: 'LOCAL' },
          deleted: true,
          doc: null
        },
        {
          uid: 'LOCAL:2',
          ver: { ts: '2026-03-31T12:00:00.000Z', ctr: 0, dev: 'LOCAL' },
          deleted: true,
          doc: null
        }
      ];

      const filtered = SyncService.filterExpiredTombstones(items, 30, nowTs);
      expect(filtered.length).assertEqual(1);
      expect(filtered[0].uid).assertEqual('LOCAL:2');
    });

    it('finds expired tombstones for db cleanup after sync success', 0, () => {
      const nowTs = '2026-04-01T12:00:00.000Z';
      const items: SnapshotItem[] = [
        {
          uid: 'LOCAL:expired',
          ver: { ts: '2026-02-20T12:00:00.000Z', ctr: 0, dev: 'LOCAL' },
          deleted: true,
          doc: null
        },
        {
          uid: 'LOCAL:active',
          ver: { ts: '2026-03-31T12:00:00.000Z', ctr: 0, dev: 'LOCAL' },
          deleted: false,
          doc: null
        }
      ];

      const expired = SyncService.findExpiredTombstoneUids(items, 30, nowTs);
      expect(expired.length).assertEqual(1);
      expect(expired[0]).assertEqual('LOCAL:expired');
    });

    it('does not filter or gc tombstones when retention is zero', 0, () => {
      const nowTs = '2026-04-01T12:00:00.000Z';
      const items: SnapshotItem[] = [{
        uid: 'LOCAL:1',
        ver: { ts: '2025-01-01T00:00:00.000Z', ctr: 0, dev: 'LOCAL' },
        deleted: true,
        doc: null
      }];

      expect(SyncService.filterExpiredTombstones(items, 0, nowTs).length).assertEqual(1);
      expect(SyncService.findExpiredTombstoneUids(items, 0, nowTs).length).assertEqual(0);
    });

    it('keeps tombstone conservatively when ver.ts is invalid', 0, () => {
      const nowTs = '2026-04-01T12:00:00.000Z';
      const items: SnapshotItem[] = [{
        uid: 'LOCAL:bad-ts',
        ver: { ts: 'not-a-date', ctr: 0, dev: 'LOCAL' },
        deleted: true,
        doc: null
      }];

      expect(SyncService.isTombstoneExpired(items[0].ver, 30, nowTs)).assertEqual(false);
      expect(SyncService.filterExpiredTombstones(items, 30, nowTs).length).assertEqual(1);
      expect(SyncService.findExpiredTombstoneUids(items, 30, nowTs).length).assertEqual(0);
    });
  });
}
