import { FocusTimerSnapshotPayload, FocusTimerUiStatePayload } from '../../../model/FocusModels';
import { KmpFocusTimerRepository } from '../../../common/kmp/KmpFocusTimerRepository';
import { FocusActiveUiState, FocusRequestGate } from './FocusUiState';
import { FocusPresentation } from './FocusPresentation';
@Component
export struct FocusTimerMiniBar {
  @Prop compact: boolean = false;
  @StorageLink('FocusMiniBarExpanded') expanded: boolean = false;
  onExpand: () => void = () => {};
  @State private timerUi: FocusActiveUiState = new FocusActiveUiState(null);
  @State private busy: boolean = false;
  onOpen: () => void = () => {};
  @StorageLink('FocusTimerRevision') @Watch('reload') revision: number = 0;
  @State private state: FocusTimerUiStatePayload | null = null;
  @State private displaySeconds: number = 0;
  private readonly requestGate: FocusRequestGate = new FocusRequestGate();
  private timerId: number = -1;
  private readonly repository: KmpFocusTimerRepository = KmpFocusTimerRepository.getInstance();

  aboutToAppear(): void {
    this.reload();
    this.timerId = setInterval(() => {
      const timer: FocusTimerSnapshotPayload | null = this.state === null ? null : this.state.timer;
      if (timer !== null && timer.state === 'RUNNING') {
        this.displaySeconds = timer.mode === 'COUNTDOWN' ? Math.max(0, this.displaySeconds - 1) : this.displaySeconds + 1;

      }
    }, 1000);
  }

  aboutToDisappear(): void {
    this.requestGate.begin();
    if (this.timerId >= 0) clearInterval(this.timerId);
    this.timerId = -1;
  }

  private async toggleTimer(): Promise<void> {
    if (this.busy || !this.timerUi.hasTimer || !(this.timerUi.canPause || this.timerUi.canResume)) return;
    this.busy = true;
    const requestId: number = this.requestGate.begin();
    try {
      const next: FocusTimerUiStatePayload = await this.repository.command(this.timerUi.canPause ? 'pause' : 'resume');
      if (!this.requestGate.accepts(requestId)) return;
      this.state = next;
      this.timerUi = new FocusActiveUiState(next.timer);
      this.displaySeconds = this.resolveDisplaySeconds(next.timer);
    } catch (_error) { this.busy = false; await this.reload(); }
    finally { this.busy = false; }
  }
  private async reload(): Promise<void> {
    if (this.busy) return;
    const requestId: number = this.requestGate.begin();
    try {
      const next: FocusTimerUiStatePayload = await this.repository.state();
      if (!this.requestGate.accepts(requestId)) return;
      this.state = next;
      this.timerUi = new FocusActiveUiState(this.state.timer);
      this.displaySeconds = this.resolveDisplaySeconds(this.state.timer);
    } catch (_error) {
      if (!this.requestGate.accepts(requestId)) return;
      this.state = null;
      this.timerUi = new FocusActiveUiState(null);
    }
  }

  private resolveDisplaySeconds(timer: FocusTimerSnapshotPayload | null): number {
    if (timer === null) return 0;
    return timer.remainingSeconds === null ? timer.elapsedSeconds : timer.remainingSeconds;
  }

  build() {
    if (this.timerUi.hasTimer) {
      if (this.compact && !this.expanded) {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.timer')).fontSize(24).fontColor([$r('sys.color.font_primary')])
        }.width(56).height(56).borderRadius(20).padding(0).backgroundColor(Color.Transparent)
          .accessibilityText('展开专注栏').onClick(this.onExpand)
      } else {
        Row({ space: 4 }) {
          Button({ type: ButtonType.Capsule }) {
            Row({ space: 8 }) {
              // SymbolGlyph($r('sys.symbol.timer')).fontSize(20).fontColor([$r('sys.color.font_primary')])
              Text(this.timerUi.title).fontSize(14).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1).fontColor($r('sys.color.font_primary'))
              Text(FocusPresentation.clock(this.displaySeconds)).fontSize(14).fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_primary')).maxLines(1)
            }.width('100%')
          }.layoutWeight(1).height(40).borderRadius(20).padding({ left: 8, right: 4 }).backgroundColor(Color.Transparent)
            .accessibilityText('打开当前专注 ' + this.timerUi.title).onClick(this.onOpen)
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph(this.timerUi.canPause ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
              .fontSize(20).fontColor([$r('sys.color.font_primary')])
          }.width(40).height(40).borderRadius(20).padding(0).backgroundColor(Color.Transparent)
            .enabled(!this.busy && (this.timerUi.canPause || this.timerUi.canResume))
            .accessibilityText(this.timerUi.canPause ? '暂停' : '继续').onClick((): void => { this.toggleTimer(); })
        }.width(this.compact ? '100%' : 'calc(100% - 32vp)').height(44)
          .padding({ left: 4, right: 4 }).margin(this.compact ? 0 : { left: 16, right: 16, bottom: 102 })
          .backgroundColor(this.compact ? Color.Transparent : $r('sys.color.search_container_focus_color')).borderRadius(22)
      }
    }
  }
}
