import { describe, it, expect } from '@ohos/hypium';
import { TaskState, TaskStateAction, TaskStateMachine } from '../main/ets/model/TaskStateMachine';

export default function taskStateMachineTests() {
  describe('TaskStateMachine', () => {
    it('active -> markComplete -> completed', 0, () => {
      expect(TaskStateMachine.nextState(TaskState.ACTIVE, TaskStateAction.MARK_COMPLETE)).assertEqual(TaskState.COMPLETED);
    });

    it('completed -> markArchive -> archived', 0, () => {
      expect(TaskStateMachine.nextState(TaskState.COMPLETED, TaskStateAction.MARK_ARCHIVE)).assertEqual(TaskState.ARCHIVED);
    });

    it('active -> markGiveUp -> abandoned', 0, () => {
      expect(TaskStateMachine.nextState(TaskState.ACTIVE, TaskStateAction.MARK_GIVE_UP)).assertEqual(TaskState.ABANDONED);
    });

    it('abandoned -> markArchive -> abandonedArchived', 0, () => {
      expect(TaskStateMachine.nextState(TaskState.ABANDONED, TaskStateAction.MARK_ARCHIVE)).assertEqual(TaskState.ABANDONED_ARCHIVED);
    });

    it('completed -> restoreActive -> active', 0, () => {
      expect(TaskStateMachine.nextState(TaskState.COMPLETED, TaskStateAction.RESTORE_ACTIVE)).assertEqual(TaskState.ACTIVE);
    });

    it('abandoned -> restoreActive -> active', 0, () => {
      expect(TaskStateMachine.nextState(TaskState.ABANDONED, TaskStateAction.RESTORE_ACTIVE)).assertEqual(TaskState.ACTIVE);
    });

    it('archived -> unarchive -> completed', 0, () => {
      expect(TaskStateMachine.nextState(TaskState.ARCHIVED, TaskStateAction.UNARCHIVE)).assertEqual(TaskState.COMPLETED);
    });

    it('abandonedArchived -> unarchive -> abandoned', 0, () => {
      expect(TaskStateMachine.nextState(TaskState.ABANDONED_ARCHIVED, TaskStateAction.UNARCHIVE)).assertEqual(TaskState.ABANDONED);
    });

    it('illegal transition fails explicitly', 0, () => {
      let didThrow = false;
      try {
        TaskStateMachine.nextState(TaskState.ACTIVE, TaskStateAction.MARK_ARCHIVE);
      } catch (e) {
        didThrow = true;
      }
      expect(didThrow).assertEqual(true);
    });

    it('give up requires confirmation but complete does not', 0, () => {
      expect(TaskStateMachine.requiresConfirmation(TaskStateAction.MARK_GIVE_UP)).assertEqual(true);
      expect(TaskStateMachine.requiresConfirmation(TaskStateAction.MARK_COMPLETE)).assertEqual(false);
    });
  });
}
