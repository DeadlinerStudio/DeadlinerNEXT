import { describe, it, expect } from '@ohos/hypium';
import { SyncService, SnapshotVer } from '../main/ets/common/sync/SyncService';

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
  });
}
