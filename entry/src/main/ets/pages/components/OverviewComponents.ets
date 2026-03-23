import { BlurBackgroundModifier } from "../../utils/animation/BlurBackgroundModifier";

@Component
export struct StatsCardContainer {
  @StorageProp('customBackgroundImage') customBg: string = '';

  @BuilderParam content: () => void;
  build() {
    Column() { this.content() }
    .width('100%')
    .padding(16)
    .attributeModifier(new BlurBackgroundModifier(!!this.customBg, $r('app.color.background_secondary'), BlurStyle.Regular))
    .borderRadius(24)
    .clip(true)
  }
}