import { TabSegmentButtonV2, SegmentButtonV2Items } from '@kit.ArkUI';
import { FocusRoundAction } from './FocusTimerControls';

@Component
export struct FocusTimerSetup {
  @Prop title: string = '';
  @Prop busy: boolean = false;
  @Prop available: boolean = false;
  @Link minutes: number;
  @State private countdown: boolean = false;
  @State private customDuration: boolean = false;
  onChooseTarget: () => void = () => {};
  onStart: (countdown: boolean) => void = (_countdown: boolean): void => {};
  private readonly modes: SegmentButtonV2Items = new SegmentButtonV2Items([{ text: '正计时' }, { text: '倒计时' }]);
  private clock(): string {
    const seconds: number = Math.round(this.minutes) * 60;
    const hours: number = Math.floor(seconds / 3600);
    const minute: number = Math.floor(seconds % 3600 / 60);
    return (hours > 0 ? (hours < 10 ? '0' : '') + hours.toString() + ':' : '') +
      (minute < 10 ? '0' : '') + minute.toString() + ':00';
  }
  build() {
    Column({ space: 24 }) {
      Column({ space: 20 }) {
        Button({ type: ButtonType.Capsule }) {
          Row({ space: 12 }) {
            SymbolGlyph($r('sys.symbol.timer')).fontSize(22).fontColor([$r('app.color.chart_blue')])
            Text(this.title.length > 0 ? this.title : '选择任务或习惯').fontSize(16).fontWeight(FontWeight.Medium)
              .layoutWeight(1).textAlign(TextAlign.Start).maxLines(2).fontColor($r('app.color.font_primary'))
            SymbolGlyph($r('sys.symbol.chevron_down')).fontSize(16).fontColor([$r('app.color.font_secondary')])
          }.width('100%')
        }.width('100%').backgroundColor(Color.Transparent).borderRadius(24).padding(0).onClick(() => { this.onChooseTarget(); })
        Row() {
          TabSegmentButtonV2({ items: this.modes, selectedIndex: this.countdown ? 1 : 0,
            $selectedIndex: (index: number): void => { this.countdown = index === 1; } })
        }.width('100%')
        Text(this.countdown ? this.clock() : '00:00').fontSize(48).fontWeight(FontWeight.Medium).margin({ top: 8, bottom: 8 })
        if (this.countdown) {
          Row({ space: 4 }) {
            ForEach([15, 25, 45, 60], (value: number) => {
              Button(value.toString() + ' 分', { type: ButtonType.Capsule }).borderRadius(24).layoutWeight(1).fontSize(13)
                .fontColor($r('app.color.font_primary'))
                .backgroundColor(this.minutes === value ? $r('app.color.background_emphasize') : Color.Transparent)
                .onClick(() => { this.minutes = value; })
            }, (value: number) => value.toString())
          }.width('100%')
          Button('自定义 · ' + Math.round(this.minutes).toString() + ' 分钟').type(ButtonType.Capsule).borderRadius(24)
            .backgroundColor(Color.Transparent).fontColor($r('app.color.font_secondary')).width('100%')
            .onClick(() => { this.customDuration = !this.customDuration; })
          if (this.customDuration) {
            Slider({ value: this.minutes, min: 1, max: 180, step: 1 }).showSteps(false)
              .onChange((value: number) => { this.minutes = Math.round(value); })
          }
        }
      }.padding(20).width('100%').backgroundColor($r('app.color.background_secondary')).borderRadius(24).enabled(!this.busy)
      FocusRoundAction({ label: '开始专注', primary: true, actionEnabled: !this.busy && this.available,
        onAction: (): void => { this.onStart(this.countdown); } })
    }.width('100%').padding({ top: 16, bottom: 16 }).justifyContent(FlexAlign.Start)
  }
}
