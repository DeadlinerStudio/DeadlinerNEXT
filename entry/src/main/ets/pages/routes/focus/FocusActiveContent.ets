import { FocusRoundAction, FocusTimerDial, FocusTextAction } from './FocusTimerControls';
import { FocusPresentation } from './FocusPresentation';

@Component
export struct FocusActiveContent {
  @Prop title: string = '';
  @Prop habitDate: string = '';
  @Prop seconds: number = 0;
  @Prop countdown: boolean = false;
  @Prop plannedSeconds: number = 1;
  @Prop paused: boolean = false;
  @Prop canPause: boolean = false;
  @Prop canResume: boolean = false;
  @Prop canFinish: boolean = false;
  @Prop canJointFinish: boolean = false;
  @Prop isHabit: boolean = false;
  @Prop busy: boolean = false;
  onFinish: () => void = () => {};
  onToggle: () => void = () => {};
  onJointFinish: () => void = () => {};
  onDiscard: () => void = () => {};
  build() {
    Column({ space: 24 }) {
      Text(this.title).fontSize(17).fontWeight(FontWeight.Medium).maxLines(2).textAlign(TextAlign.Center)
        .fontColor($r('sys.color.font_primary'))
      if (this.habitDate.length > 0) {
        Text('打卡归属 ' + this.habitDate).fontSize(12).fontColor($r('sys.color.font_secondary'))
      }
      FocusTimerDial({ seconds: this.seconds, countdown: this.countdown, plannedSeconds: this.plannedSeconds,
        paused: this.paused, clock: FocusPresentation.clock(this.seconds) })
      Row({ space: 16 }) {
        FocusRoundAction({ symbol: $r('sys.symbol.square'), label: '结束', actionEnabled: !this.busy && this.canFinish,
          onAction: this.onFinish }).layoutWeight(1)
        FocusRoundAction({ symbol: this.canPause ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'),
          label: this.canPause ? '暂停' : '继续', primary: true, actionEnabled: !this.busy && (this.canPause || this.canResume),
          onAction: this.onToggle }).layoutWeight(1)
        FocusRoundAction({ symbol: $r('sys.symbol.checkmark'), label: this.isHabit ? '打卡' : '完成任务',
          actionEnabled: !this.busy && this.canJointFinish, onAction: this.onJointFinish }).layoutWeight(1)
      }.width('100%').alignItems(VerticalAlign.Center)
      FocusTextAction({ label: '放弃本轮', destructive: true, actionEnabled: !this.busy, onAction: this.onDiscard })
    }.width('100%').padding({ top: 16, bottom: 16 }).justifyContent(FlexAlign.Start)
  }
}
