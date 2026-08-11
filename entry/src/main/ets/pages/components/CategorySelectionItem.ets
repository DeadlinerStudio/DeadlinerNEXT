/** Shared visual primitive used by the complete category selection panel. */
@Component
export struct CategorySelectionItem {
  @Prop title: string;
  @Prop icon: Resource;
  @Prop iconColor: ResourceColor = $r('sys.color.ohos_id_color_text_secondary');
  @Prop selectionColor: ResourceColor = $r('sys.color.ohos_id_color_text_primary');
  @Prop selected: boolean = false;
  @Prop selectedBackgroundColor: ResourceColor = '#1F0A59F7';
  onSelect: () => void = (): void => {};

  build() {
    Row({ space: 12 }) {
      SymbolGlyph(this.icon)
        .fontSize(20)
        .fontColor([this.iconColor])
      Text(this.title)
        .fontSize(16)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .layoutWeight(1)
      if (this.selected) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(18)
          .fontColor([this.selectionColor])
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(this.selected ? this.selectedBackgroundColor : Color.Transparent)
    .borderRadius(16)
    .onClick((): void => { this.onSelect(); })
  }
}
