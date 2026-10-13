import { MaterialPresets } from '../../../common/style/SystemMaterialCompat';
import { ImmersiveMaterialScope } from '../../components/ImmersiveMaterialScope';
import { ThemeManager } from '../../../common/theme/ThemeManager';
import { ITheme } from '../../../common/theme/ThemeModel';

@Component
export struct FocusRoundAction {
  @Prop symbol: Resource = $r('sys.symbol.play_fill');
  @Prop label: string = '';
  @Prop primary: boolean = false;
  @Prop actionEnabled: boolean = true;
  onAction: () => void = () => {};
  build() {
    Column({ space: 8 }) {
      ImmersiveMaterialScope({ scopeWidth: this.primary ? 80 : 56, scopeHeight: this.primary ? 80 : 56 }) {
        FocusScopedRoundButton({ symbol: $symbol, label: $label, primary: $primary, actionEnabled: $actionEnabled,
          onAction: (): void => { this.onAction(); } })
      }
      Text(this.label).fontSize(12).fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .textAlign(TextAlign.Center).maxLines(2)
    }.width('100%').opacity(this.actionEnabled ? 1 : 0.4)
  }
}

@Component
export struct FocusTimerDial {
  @Prop seconds: number = 0;
  @Prop countdown: boolean = false;
  @Prop plannedSeconds: number = 1;
  @Prop paused: boolean = false;
  @Prop clock: string = '00:00';
  private progress(): number {
    if (this.countdown) return Math.min(100, Math.max(0, (this.plannedSeconds - this.seconds) / Math.max(1, this.plannedSeconds) * 100));
    return Math.max(0, this.seconds) % 60 / 60 * 100;
  }
  build() {
    Stack() {
      Progress({ value: this.progress(), total: 100, type: ProgressType.Ring })
        .width('100%').height('100%').color($r('app.color.chart_blue'))
        .backgroundColor($r('app.color.background_emphasize'))
        .style({ strokeWidth: 5, enableSmoothEffect: true }).opacity(this.paused ? 0.4 : 1)
      Column({ space: 8 }) {
        Text(this.countdown ? '剩余时间' : '已专注').fontSize(14).fontColor($r('sys.color.ohos_id_color_text_secondary'))
        Text(this.clock).fontSize(this.clock.length > 5 ? 44 : 60).fontWeight(FontWeight.Medium)
          .maxLines(1).fontColor($r('sys.color.font_primary'))
        Text(this.paused ? '已暂停' : '专注中').fontSize(14)
          .fontColor(this.paused ? $r('sys.color.ohos_id_color_text_secondary') : $r('app.color.chart_blue'))
      }.padding(24)
    }.width('100%').aspectRatio(1).constraintSize({ maxWidth: 320 })
  }
}

/** Capsule actions also keep explicit shape when global Button theme defaults change. */
@Component
export struct FocusTextAction {
  @Prop label: string = '';
  @Prop destructive: boolean = false;
  @Prop actionEnabled: boolean = true;
  onAction: () => void = () => {};
  build() {
    Button(this.label, { type: ButtonType.Capsule }).fontSize(13).constraintSize({ minHeight: 40 })
      .borderRadius(24).backgroundColor(Color.Transparent)
      .fontColor(this.destructive ? $r('app.color.chart_red') : $r('sys.color.font_primary'))
      .enabled(this.actionEnabled).onClick(this.onAction)
  }
}

@Component
export struct FocusSwipeAction {
  @StorageProp('currentTheme') theme: ITheme = ThemeManager.getCurrentTheme();
  onAction: () => void = () => {};
  build() {
    Column({ space: 2 }) {
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.timer')).fontSize(19).fontColor([this.theme.bgPrimary])
      }.width(48).height(48).borderRadius(24).padding(0).backgroundColor(this.theme.accent)
        .onClick(this.onAction).accessibilityText('专注')
      Text('专注').fontSize(10).fontColor($r('sys.color.font_secondary')).textAlign(TextAlign.Center)
    }.width(48).height(64).justifyContent(FlexAlign.Center)
  }
}

/** Links update icon/enabled state inside the required material Builder slot without re-evaluating that slot. */
@Component
struct FocusScopedRoundButton {
  @Link symbol: Resource;
  @Link label: string;
  @Link primary: boolean;
  @Link actionEnabled: boolean;
  @StorageProp('currentTheme') theme: ITheme = ThemeManager.getCurrentTheme();
  onAction: () => void = () => {};
  build() {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph(this.symbol).fontSize(this.primary ? 30 : 24)
        .fontColor([this.primary ? this.theme.bgPrimary : $r('sys.color.font_primary')])
    }.width(this.primary ? 80 : 56).height(this.primary ? 80 : 56).borderRadius(this.primary ? 40 : 28).padding(0)
      .backgroundColor(this.primary ? this.theme.accent : $r('app.color.background_secondary'))
      .attributeModifier(MaterialPresets.buttonGlow(true, undefined, this.primary ? this.theme.accent : undefined))
      .enabled(this.actionEnabled).onClick(this.onAction).accessibilityText(this.label)
  }
}
