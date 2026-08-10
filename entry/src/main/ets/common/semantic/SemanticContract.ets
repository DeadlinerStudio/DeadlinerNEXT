export enum DeadlineSemanticStatus {
  ACTIVE = 'active',
  NEAR_DUE = 'nearDue',
  OVERDUE = 'overdue',
  COMPLETED = 'completed',
  ABANDONED = 'abandoned'
}

export enum SemanticTone {
  ACCENT = 'accent',
  SUCCESS = 'success',
  WARNING = 'warning',
  DANGER = 'danger',
  CALM = 'calm',
  NEUTRAL = 'neutral'
}

export enum SemanticPageKind {
  TASKS = 'tasks',
  HABITS = 'habits'
}

export class HabitSemanticInput {
  public readonly id: number;
  public readonly isCompleted: boolean;

  constructor(id: number, isCompleted: boolean) {
    this.id = id;
    this.isCompleted = isCompleted;
  }
}

export class SemanticSnapshot {
  public readonly kind: SemanticPageKind;
  public readonly tone: SemanticTone;
  public readonly taskStatusById: Map<number, DeadlineSemanticStatus>;
  public readonly overdueCount: number;
  public readonly nearDueCount: number;
  public readonly openTaskCount: number;
  public readonly completedTaskCount: number;
  public readonly abandonedTaskCount: number;
  public readonly visibleTaskCount: number;
  public readonly completedHabitCount: number;
  public readonly visibleHabitCount: number;

  constructor(
    kind: SemanticPageKind,
    tone: SemanticTone,
    taskStatusById: Map<number, DeadlineSemanticStatus>,
    overdueCount: number,
    nearDueCount: number,
    openTaskCount: number,
    completedTaskCount: number,
    abandonedTaskCount: number,
    visibleTaskCount: number,
    completedHabitCount: number,
    visibleHabitCount: number
  ) {
    this.kind = kind;
    this.tone = tone;
    this.taskStatusById = taskStatusById;
    this.overdueCount = overdueCount;
    this.nearDueCount = nearDueCount;
    this.openTaskCount = openTaskCount;
    this.completedTaskCount = completedTaskCount;
    this.abandonedTaskCount = abandonedTaskCount;
    this.visibleTaskCount = visibleTaskCount;
    this.completedHabitCount = completedHabitCount;
    this.visibleHabitCount = visibleHabitCount;
  }

  public static empty(kind: SemanticPageKind): SemanticSnapshot {
    const tone: SemanticTone = kind === SemanticPageKind.TASKS ? SemanticTone.SUCCESS : SemanticTone.ACCENT;
    return new SemanticSnapshot(
      kind,
      tone,
      new Map<number, DeadlineSemanticStatus>(),
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0
    );
  }

  public statusForTask(id: number): DeadlineSemanticStatus {
    const status: DeadlineSemanticStatus | undefined = this.taskStatusById.get(id);
    return status === undefined ? DeadlineSemanticStatus.ACTIVE : status;
  }
}
