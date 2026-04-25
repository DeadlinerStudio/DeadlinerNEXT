import { ItemRestriction, SegmentButton, SegmentButtonOptions, SegmentButtonTextItem } from '@kit.ArkUI';
import { SettingsConstants as C } from '../../common/local/SettingsConstants';
import { getHdsMaterialLevelRaw } from '../../common/style/MaterialLevel';
import { HdsMiniBarButton } from './infra/HdsMiniBarButton';

@Component
export struct HdsTitleBarSegment {
  @Require buttons: ItemRestriction<SegmentButtonTextItem>;
  @Link selectedIndexes: number[];

  @Prop maxFontScale: number = 2;
  @Prop segmentHeight: number = 48;
  @Prop normalWidth: Length = '100%';
  @Prop experimentalWidth: Length = '100%';
  @Prop experimentalHeight: number = 52;

  @State measuredWidth: number = 0;

  @StorageLink(C.KEY_EXPERIMENTAL_COMPONENTS) experimentalComponents: boolean = true;
  @StorageProp(C.KEY_ENABLE_API23) api23: boolean = false;
  @StorageProp('customBackgroundImage') customBg: string = '';

  @StorageProp(C.KEY_API23_MATERIAL_LEVEL) materialLevel: string = 'EXQUISITE';

  private buildDefaultOptions(): SegmentButtonOptions {
    return SegmentButtonOptions.tab({
      buttons: this.buttons,
      backgroundBlurStyle: (!!this.customBg && this.api23) ? BlurStyle.Thin : BlurStyle.NONE,
      selectedBackgroundColor: $r('sys.color.segment_button_v2_tab_selected_item_background'),
      backgroundColor: $r('sys.color.comp_background_tertiary'),
      buttonPadding: 10
    });
  }

  private buildExperimentalOptions(): SegmentButtonOptions {
    return SegmentButtonOptions.tab({
      buttons: this.buttons,
      backgroundBlurStyle: BlurStyle.NONE,
      selectedBackgroundColor: $r('sys.color.segment_button_v2_tab_selected_item_background'),
      backgroundColor: Color.Transparent,
      buttonPadding: 10
    });
  }

  private resolveExperimentalBarWidth(): number {
    if (this.measuredWidth > 0) {
      return this.measuredWidth;
    }
    return 10 + this.buttons.length * 84;
  }

  @Builder
  private segmentContent(options: SegmentButtonOptions) {
    SegmentButton({
      options: options,
      selectedIndexes: $selectedIndexes,
      maxFontScale: this.maxFontScale
    })
      .width('100%')
      .height(this.segmentHeight)
  }

  build() {
    if (this.experimentalComponents && this.api23) {
      Stack({ alignContent: Alignment.Center }) {
        HdsMiniBarButton({
          barWidth: this.resolveExperimentalBarWidth(),
          barHeight: this.experimentalHeight,
          materialLevel: getHdsMaterialLevelRaw(this.materialLevel)
        }) {
          this.segmentContent(this.buildExperimentalOptions())
        }
      }
      .width(this.experimentalWidth)
      .height(this.experimentalHeight)
      .onAreaChange((_, area) => {
        if (typeof area.width === 'number' && area.width > 0) {
          this.measuredWidth = area.width;
        }
      })
      .margin({ top: -8 })
    } else {
      Stack({ alignContent: Alignment.Center }) {
        this.segmentContent(this.buildDefaultOptions())
      }
      .width(this.normalWidth)
      .height(this.segmentHeight)
    }
  }
}
