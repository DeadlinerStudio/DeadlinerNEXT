@Component
export struct Symbol {
  @Prop icon: Resource;
  @Prop isImage: boolean;
  fontSize: number = 24;
  fontColor: ResourceColor = $r('app.color.font_primary');
  fontWeight: number = 400;

  build() {
    if (!this.isImage) {
      SymbolGlyph(this.icon)
        .fontSize(this.fontSize)
        .fontColor([this.fontColor])
        .fontWeight(this.fontWeight)
    } else {
      Image(this.icon)
        .size({ width: this.fontSize, height: this.fontSize })
        .fillColor(this.fontColor)
    }
  }
}