import { FocusSwipeAction } from '../focus/FocusTimerControls';

@Component
export struct HabitSwipeActions {
  @Prop leading: boolean = true;
  onArchive: () => void = () => {};
  onFocusAction: () => void = () => {};
  onEdit: () => void = () => {};
  onDelete: () => void = () => {};
  build() {
    Row({ space: 12 }) {
      if (this.leading) {
        HabitSwipeButton({ symbol: $r('sys.symbol.archivebox'), label: '归档', onAction: this.onArchive })
        FocusSwipeAction({ onAction: this.onFocusAction })
      } else {
        HabitSwipeButton({ symbol: $r('sys.symbol.square_and_pencil'), label: '编辑', onAction: this.onEdit })
        HabitSwipeButton({ symbol: $r('sys.symbol.trash'), label: '删除', destructive: true, onAction: this.onDelete })
      }
    }.padding({ left: 12, right: 12 }).height('100%')
  }
}

@Component
struct HabitSwipeButton {
  @Prop symbol: Resource = $r('sys.symbol.archivebox');
  @Prop label: string = '';
  @Prop destructive: boolean = false;
  onAction: () => void = () => {};
  build() {
    Column({ space: 2 }) {
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph(this.symbol).fontSize(19)
          .fontColor([this.destructive ? $r('app.color.chart_red') : $r('sys.color.font_primary')])
      }.width(48).height(48).borderRadius(24).padding(0).backgroundColor($r('app.color.background_secondary'))
        .onClick(this.onAction).accessibilityText(this.label)
      Text(this.label).fontSize(10).fontColor($r('sys.color.font_secondary')).textAlign(TextAlign.Center)
    }.width(48).height(64).justifyContent(FlexAlign.Center)
  }
}
