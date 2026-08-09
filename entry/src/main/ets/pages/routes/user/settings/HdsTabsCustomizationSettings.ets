import { HdsNavDestination } from '@kit.UIDesignKit';
import { SettingsConstants as C } from '../../../../common/local/SettingsConstants';
import { LocalValues } from '../../../../common/local/LocalValues';
import {
  HdsTabDescriptor,
  HdsTabSymbolRendering,
  HdsTabsCustomization
} from '../../../../model/HdsTabsCustomization';
import { getImmersiveTitleBarStyle } from '../../../../common/style/NavStyles';
import { TopSafeContainer } from '../../../components/TopSafeContainer';
import { SettingsCheckItem, SettingsSection, SubSettingsDivider } from '../../../components/SettingsComponents';
import { Symbol } from '../../../components/infra/Symbol';

@Builder
export function HdsTabsCustomizationSettingsBuilder() {
  HdsTabsCustomizationSettings()
}

@Component
struct HdsTabsCustomizationRow {
  @Prop tab: HdsTabDescriptor;
  @Prop isVisible: boolean;
  @Prop symbolRendering: string;
  onVisibilityChange?: (tabId: string, isVisible: boolean) => void;

  private stateDescription(): string {
    if (!this.tab.canHide) {
      return '固定显示';
    }
    return this.isVisible ? '显示在底栏' : '已隐藏';
  }

  build() {
    Row({ space: 12 }) {
      Symbol({
        icon: HdsTabsCustomization.getDisplayIcon(this.tab.id, this.symbolRendering),
        isImage: this.tab.isImage,
        fontSize: 22,
        fontColor: this.tab.color
      })
        .width(28)

      Column({ space: 3 }) {
        Text(this.tab.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.font_primary'))

        Text(this.stateDescription())
          .fontSize(12)
          .fontColor($r('app.color.font_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.tab.canHide) {
        Toggle({ type: ToggleType.Switch, isOn: this.isVisible })
          .selectedColor($r('app.color.brand'))
          .onChange((isOn: boolean) => {
            if (this.onVisibilityChange) {
              this.onVisibilityChange(this.tab.id, isOn);
            }
          })
      } else {
        Text('固定')
          .fontSize(12)
          .fontColor($r('app.color.font_secondary'))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .borderRadius(10)
      }

      Text('≡')
        .fontSize(20)
        .fontColor($r('app.color.font_secondary'))
        .opacity(0.7)
    }
    .width('100%')
    .height(64)
    .padding({ left: 12, right: 12 })
    .borderRadius(20)
    .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
  }
}

@Component
struct HdsTabsCustomizationSettings {
  @StorageLink('isWideScreen') isWideScreen: boolean = false;
  @StorageLink('statusBarHeight') statusBarHeight: number = 38;
  @StorageLink('topAvoidExtraHeight') topAvoidExtraHeight: number = 0;
  @StorageLink(C.KEY_HDS_TABS_ORDER) tabOrder: string[] = HdsTabsCustomization.defaultOrder();
  @StorageLink(C.KEY_HDS_TABS_HIDDEN) hiddenTabs: string[] = HdsTabsCustomization.defaultHiddenTabs();
  @StorageLink(C.KEY_HDS_TAB_SYMBOL_RENDERING) symbolRendering: string =
    HdsTabsCustomization.defaultSymbolRendering();

  readonly TITLE_BAR_CONTENT_HEIGHT: number = 18;
  @State orderedTabs: HdsTabDescriptor[] = HdsTabsCustomization.getOrderedTabs(
    HdsTabsCustomization.defaultOrder()
  );

  aboutToAppear(): void {
    this.orderedTabs = HdsTabsCustomization.getOrderedTabs(this.tabOrder);
  }

  private updateOrder(order: string[]): void {
    const normalizedOrder = HdsTabsCustomization.normalizeOrder(order);
    this.tabOrder = normalizedOrder;
    this.orderedTabs = HdsTabsCustomization.getOrderedTabs(normalizedOrder);
    void LocalValues.getInstance().setHdsTabsOrder(normalizedOrder);
  }

  private moveTab(from: number, to: number): void {
    if (from === to || from < 0 || to < 0 || from >= this.orderedTabs.length || to >= this.orderedTabs.length) {
      return;
    }

    const reorderedTabs: HdsTabDescriptor[] = this.orderedTabs.slice();
    const movedTab = reorderedTabs[from];
    reorderedTabs.splice(from, 1);
    reorderedTabs.splice(to, 0, movedTab);

    const reorderedIds: string[] = [];
    reorderedTabs.forEach((tab: HdsTabDescriptor) => {
      reorderedIds.push(tab.id);
    });
    this.updateOrder(reorderedIds);
  }

  private changeVisibility(tabId: string, isVisible: boolean): void {
    const normalizedHiddenTabs = HdsTabsCustomization.normalizeHiddenTabs(this.hiddenTabs);
    const updatedHiddenTabs: string[] = [];
    normalizedHiddenTabs.forEach((id: string) => {
      if (id !== tabId) {
        updatedHiddenTabs.push(id);
      }
    });

    if (!isVisible) {
      updatedHiddenTabs.push(tabId);
    }

    const normalizedUpdatedHiddenTabs = HdsTabsCustomization.normalizeHiddenTabs(updatedHiddenTabs);
    this.hiddenTabs = normalizedUpdatedHiddenTabs;
    void LocalValues.getInstance().setHdsTabsHidden(normalizedUpdatedHiddenTabs);
  }

  private selectSymbolRendering(rendering: string): void {
    const normalizedRendering = HdsTabsCustomization.normalizeSymbolRendering(rendering);
    this.symbolRendering = normalizedRendering;
    void LocalValues.getInstance().setHdsTabSymbolRendering(normalizedRendering);
  }

  private restoreDefaults(): void {
    const defaultOrder = HdsTabsCustomization.defaultOrder();
    const defaultHiddenTabs = HdsTabsCustomization.defaultHiddenTabs();
    const defaultRendering = HdsTabsCustomization.defaultSymbolRendering();

    this.tabOrder = defaultOrder;
    this.hiddenTabs = defaultHiddenTabs;
    this.symbolRendering = defaultRendering;
    this.orderedTabs = HdsTabsCustomization.getOrderedTabs(defaultOrder);

    void LocalValues.getInstance().setHdsTabsOrder(defaultOrder);
    void LocalValues.getInstance().setHdsTabsHidden(defaultHiddenTabs);
    void LocalValues.getInstance().setHdsTabSymbolRendering(defaultRendering);
  }

  build() {
    HdsNavDestination() {
      TopSafeContainer({ topAvoidHeight: this.statusBarHeight + this.TITLE_BAR_CONTENT_HEIGHT + this.topAvoidExtraHeight }) {
        Column({ space: 16 }) {
          SettingsSection({ title: '底栏' }) {
            List({ space: 4 }) {
              ForEach(this.orderedTabs, (tab: HdsTabDescriptor) => {
                ListItem() {
                  HdsTabsCustomizationRow({
                    tab: tab,
                    isVisible: HdsTabsCustomization.isTabVisible(tab.id, this.hiddenTabs),
                    symbolRendering: this.symbolRendering,
                    onVisibilityChange: (tabId: string, isVisible: boolean) => {
                      this.changeVisibility(tabId, isVisible);
                    }
                  })
                }
              }, (tab: HdsTabDescriptor) => tab.id)
                .onMove((from: number, to: number) => {
                  this.moveTab(from, to);
                })
            }
            .height(336)
            .scrollBar(BarState.Off)
          }

          Text('长按并拖动可调整顺序。清单和我的固定显示；隐藏的入口可随时在此恢复。')
            .fontSize(12)
            .lineHeight(18)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .padding({ left: 24, right: 24 })
            .width('100%')

          SettingsSection({ title: '系统图标渲染' }) {
            SettingsCheckItem({
              title: '层级透明度',
              icon: $r('sys.symbol.circle_grid_2x2'),
              isSelected: !HdsTabsCustomization.isSingleSymbolRendering(this.symbolRendering),
              onItemClick: () => {
                this.selectSymbolRendering(HdsTabSymbolRendering.MULTIPLE_OPACITY);
              }
            })

            SubSettingsDivider()

            SettingsCheckItem({
              title: '单色',
              icon: $r('sys.symbol.circle'),
              isSelected: HdsTabsCustomization.isSingleSymbolRendering(this.symbolRendering),
              onItemClick: () => {
                this.selectSymbolRendering(HdsTabSymbolRendering.SINGLE);
              }
            })
          }

          Text('层级透明度对应 MULTIPLE_OPACITY（默认）；单色对应 SINGLE。仅影响系统 SymbolGlyph，AI 与灵感图标保持原图。')
            .fontSize(12)
            .lineHeight(18)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .padding({ left: 24, right: 24 })
            .width('100%')

          Button('恢复默认')
            .width('100%')
            .height(48)
            .onClick(() => {
              this.restoreDefaults();
            })

          Blank().height(34)
        }
        .width('100%')
        .padding(16)
        .justifyContent(FlexAlign.Start)
        .constraintSize({ minHeight: '100%' })
      }
    }
    .titleBar({
      avoidLayoutSafeArea: this.isWideScreen,
      style: getImmersiveTitleBarStyle(this.isWideScreen),
      content: { title: { mainTitle: '底栏自定义' } }
    })
  }
}
