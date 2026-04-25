import { SettingsConstants as C } from '../../common/local/SettingsConstants';
import { getHdsMaterialLevelRaw } from '../../common/style/MaterialLevel';
import { BlurBackgroundModifier } from '../../utils/animation/BlurBackgroundModifier';
import { HdsMiniBarButton } from './infra/HdsMiniBarButton';

@Component
export struct HdsTitleBarMenuButton {
  @Prop icon: Resource = $r('sys.symbol.square');
  @Prop iconSize: number = 24;
  @Prop buttonSize: number = 40;
  @Prop barHeight: number = 52;

  @Prop isEnabled: boolean = true;
  @Require onButtonClick: () => void;

  @StorageProp('customBackgroundImage') customBg: string = '';
  @StorageProp(C.KEY_ENABLE_API23) api23: boolean = false;
  @StorageLink(C.KEY_EXPERIMENTAL_COMPONENTS) experimentalComponents: boolean = true;

  @StorageProp(C.KEY_API23_MATERIAL_LEVEL) materialLevel: string = 'EXQUISITE';

  private handleClick() {
    if (!this.isEnabled) {
      return;
    }
    this.onButtonClick();
  }

  @Builder
  private buttonIcon() {
    SymbolGlyph(this.icon)
      .fontSize(this.iconSize)
      .fontColor([$r('sys.color.ohos_id_color_text_primary')])
  }

  build() {
    if (this.experimentalComponents && this.api23) {
      HdsMiniBarButton({
        barWidth: this.buttonSize,
        barHeight: this.barHeight,
        onButtonClick: () => {
          this.handleClick();
        },
        materialLevel: getHdsMaterialLevelRaw(this.materialLevel)
      }) {
        this.buttonIcon()
      }
    } else {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        this.buttonIcon()
      }
      .width(this.buttonSize)
      .height(this.buttonSize)
      .attributeModifier(new BlurBackgroundModifier((!!this.customBg && this.api23), $r('sys.color.comp_background_tertiary')))
      .onClick(() => {
        this.handleClick();
      })
      .enabled(this.isEnabled)
    }
  }
}
