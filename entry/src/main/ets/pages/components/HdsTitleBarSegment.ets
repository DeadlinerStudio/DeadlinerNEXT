import {
  ColorMetrics,
  LengthMetrics,
  SegmentButtonV2Items,
  TabSegmentButtonV2,
  uiMaterial
} from '@kit.ArkUI';
import { SettingsConstants as C } from '../../common/local/SettingsConstants';
import { getHdsMaterialLevelRaw } from '../../common/style/MaterialLevel';
import { HdsMiniBarButton } from './infra/HdsMiniBarButton';
import { API23_UI_DEFAULT,
  API26_OR_ABOVE,
  EXPERIMENTAL_COMPONENTS_DEFAULT } from '../../common/local/ExperimentalComponentsPolicy';
import { buildImmersiveMaterial } from '../../common/style/SystemMaterialCompat';

@Component
export struct HdsTitleBarSegment {
  @Require items: SegmentButtonV2Items;
  @Link selectedIndexes: number[];

  @Prop maxFontScale: number = 2;
  @Prop segmentHeight: number = 48;
  @Prop normalWidth: Length = '100%';
  @Prop experimentalWidth: Length = '100%';
  @Prop experimentalHeight: number = 52;
  onItemClicked?: (index: number) => void;

  maxWidth?: number;

  @State measuredWidth: number = 0;

  @StorageLink(C.KEY_EXPERIMENTAL_COMPONENTS) experimentalComponents: boolean = EXPERIMENTAL_COMPONENTS_DEFAULT;
  @StorageProp(C.KEY_ENABLE_API23) api23: boolean = API23_UI_DEFAULT;
  @StorageProp('customBackgroundImage') customBg: string = '';

  @StorageProp(C.KEY_API23_MATERIAL_LEVEL) materialLevel: string = 'EXQUISITE';

  private selectedIndex(): number {
    return this.selectedIndexes.length > 0 ? this.selectedIndexes[0] : 0;
  }

  private onSelectedIndexChange(index: number): void {
    this.selectedIndexes = [index];
  }

  @Builder
  private segmentContent(useImmersiveMaterial: boolean, transparentBackground: boolean) {
    Column() {
      if (useImmersiveMaterial) {
        TabSegmentButtonV2({
          items: this.items,
          selectedIndex: this.selectedIndex(),
          $selectedIndex: (index: number): void => {
            this.onSelectedIndexChange(index);
          },
          onItemClicked: this.onItemClicked,
          itemMaxFontScale: this.maxFontScale,
          itemSelectedBackgroundColor: ColorMetrics.resourceColor(
            $r('app.color.segmented_color_selected')
          ),
          itemMinHeight: LengthMetrics.vp(32),
          buttonBackgroundColor: ColorMetrics.rgba(0, 0, 0, 0),
          buttonMinHeight: LengthMetrics.vp(40),
          buttonPadding: LengthMetrics.vp(4),
          backgroundSystemMaterial: buildImmersiveMaterial({
            style: uiMaterial.ImmersiveStyle.THIN,
            interactive: true,
            lightEffect: true
          }),
          enableStateAnimation: true
        })
          .offset({ y: -4 })
      } else {
        TabSegmentButtonV2({
          items: this.items,
          selectedIndex: this.selectedIndex(),
          $selectedIndex: (index: number): void => {
            this.onSelectedIndexChange(index);
          },
          onItemClicked: this.onItemClicked,
          itemMaxFontScale: this.maxFontScale,
          itemSelectedBackgroundColor: ColorMetrics.resourceColor(
            $r('sys.color.segment_button_v2_tab_selected_item_background')
          ),
          buttonBackgroundColor: ColorMetrics.resourceColor(
            transparentBackground ? Color.Transparent : $r('sys.color.comp_background_tertiary')
          ),
          buttonBackgroundBlurStyle: transparentBackground ? BlurStyle.NONE :
            ((!!this.customBg && this.api23) ? BlurStyle.Thin : BlurStyle.NONE),
          enableStateAnimation: true
        })
      }
    }
      .width('100%')
      .height(this.segmentHeight)
      .justifyContent(FlexAlign.Center)
  }

  build() {
    if (this.experimentalComponents && this.api23) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.measuredWidth > 0) {
          HdsMiniBarButton({
            barWidth: this.measuredWidth,
            barHeight: this.experimentalHeight,
            materialLevel: getHdsMaterialLevelRaw(this.materialLevel)
          }) {
            this.segmentContent(false, true)
          }
        }
      }
      .width(this.experimentalWidth)
      .height(this.experimentalHeight)
      .onAreaChange((_, area) => {
        if (typeof area.width === 'number' && area.width > 0 && this.measuredWidth !== area.width) {
          this.measuredWidth = area.width;
        }
      })
      .margin({ top: -8 })
    } else {
      Stack({ alignContent: Alignment.Center }) {
        this.segmentContent(API26_OR_ABOVE, false)
      }
      .width(this.normalWidth)
      .height(this.segmentHeight)
      .constraintSize({ maxWidth: this.maxWidth })
    }
  }
}
