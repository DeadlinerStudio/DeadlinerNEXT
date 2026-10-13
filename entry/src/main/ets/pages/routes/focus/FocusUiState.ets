import { FocusTimerSnapshotPayload } from '../../../model/FocusModels';

/** Flat immutable presentation snapshot. Replace after every query/command, never mutate nested payloads. */
export class FocusActiveUiState {
  hasTimer: boolean = false;
  title: string = '';
  habitDate: string = '';
  countdown: boolean = false;
  plannedSeconds: number = 1;
  paused: boolean = false;
  canPause: boolean = false;
  canResume: boolean = false;
  canFinish: boolean = false;
  canJointFinish: boolean = false;
  isHabit: boolean = false;
  constructor(timer: FocusTimerSnapshotPayload | null) {
    if (timer === null) return;
    this.hasTimer = true;
    this.title = timer.taskTitle;
    this.habitDate = timer.habitOccurredOn ?? '';
    this.countdown = timer.mode === 'COUNTDOWN';
    this.plannedSeconds = timer.plannedDurationSeconds ?? 1;
    this.paused = timer.state === 'PAUSED';
    this.canPause = timer.canPause;
    this.canResume = timer.canResume;
    this.canFinish = timer.canFinish;
    this.canJointFinish = timer.canFinishAndRecord || timer.canFinishAndComplete;
    this.isHabit = timer.target?.kind === 'HABIT';
  }
}

export class FocusMiniBarPolicy {
  /** Layout/APP_TRIGGER callbacks must not overwrite the user's saved choice. */
  static nextExpanded(current: boolean, reported: boolean, userClick: boolean): boolean {
    return userClick ? reported : current;
  }
}

/** UI queries may finish after a newer command; only the latest response owns the screen. */
export class FocusRequestGate {
  private revision: number = 0;
  begin(): number { this.revision += 1; return this.revision; }
  accepts(request: number): boolean { return request === this.revision; }
}
