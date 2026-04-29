import { HdsNavDestination, HdsNavDestinationAttribute } from '@kit.UIDesignKit';
import { SettingsConstants as C } from '../../../../common/local/SettingsConstants';
import { MainButtonType } from '../../../../common/local/LocalModels';
import { TopSafeContainer } from '../../../components/TopSafeContainer';
import { SettingsSection, SettingsDivider, SettingsCheckItem } from '../../../components/SettingsComponents'; // 确保引入了 CheckItem
import { LocalValues } from '../../../../common/local/LocalValues';
import { getImmersiveTitleBarStyle } from '../../../../common/style/NavStyles';
import { Symbol } from '../../../components/infra/Symbol';

/**
 * SchematicButton: 独立的按钮组件
 * 使用 @Component 替代 @Builder，确保数据变化时必定刷新
 */
@Component
struct SchematicButton {
  @Prop iconType: string;

  getIconResource(type: string): Resource {
    switch (type) {
      case MainButtonType.ARCHIVE: return $r('sys.symbol.archivebox');
      case MainButtonType.AI: return $r('app.media.lifi');
      case MainButtonType.SEARCH: return $r('sys.symbol.magnifyingglass');
      default: return $r('sys.symbol.square');
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Circle()
        .width(48)
        .height(48)
        .fill($r('sys.color.ohos_id_color_button_normal'))

      // SymbolGlyph(this.getIconResource(this.iconType))
      //   .fontSize(24)
      //   .fontColor([$r('sys.color.ohos_id_color_text_primary')])
      Symbol({
        icon: this.getIconResource(this.iconType),
        isImage: this.iconType === MainButtonType.AI,
        fontColor: $r('sys.color.ohos_id_color_text_primary')
      })
    }
    .width(48)
    .height(48)
    // 添加动画，这样变化时会更平滑，也能验证刷新
    .animation({ duration: 200 })
  }
}

@Component
struct TopBarSchematic {
  // 使用 @Prop 接收父组件的值
  // @Watch 不是必须的，但加上可以用于调试，确认值是否传进来了
  @Prop @Watch('onTypeChange') leftType: string;
  @Prop @Watch('onTypeChange') rightType: string;

  onTypeChange() {
    // 如果日志打印了，说明数据传进来了，UI 应该刷新
    console.info(`TopBarSchematic update: left=${this.leftType}, right=${this.rightType}`);
  }

  build() {
    Row() {
      // 使用独立组件，传入参数
      SchematicButton({ iconType: this.leftType })

      Blank()

      SchematicButton({ iconType: this.rightType })
    }
    .width('100%')
    .height(68) // 保持你调整后的高度
    .padding({ left: 24, right: 24 })
    .justifyContent(FlexAlign.SpaceBetween)
  }
}

@Builder
export function MainPageButtonsSettingsBuilder() {
  MainPageButtonsSettings()
}

interface ButtonOption {
  text: string;
  value: MainButtonType;
}

@Component
struct MainPageButtonsSettings {
  @StorageLink('isWideScreen') isWideScreen: boolean = false;

  @StorageProp('statusBarHeight') statusBarHeight: number = 38;
  readonly TITLE_BAR_CONTENT_HEIGHT: number = 18;

  @StorageLink(C.KEY_MAIN_LEFT_BUTTON) leftBtnType: MainButtonType = MainButtonType.ARCHIVE;
  @StorageLink(C.KEY_MAIN_RIGHT_BUTTON) rightBtnType: MainButtonType = MainButtonType.SEARCH;

  private readonly options: ButtonOption[] = [
    { text: '搜索', value: MainButtonType.SEARCH },
    { text: 'Lifi AI', value: MainButtonType.AI },
    { text: '归档箱', value: MainButtonType.ARCHIVE },
  ];

  private getIcon(type: string): Resource {
    switch (type) {
      case MainButtonType.SEARCH: return $r('sys.symbol.magnifyingglass');
      case MainButtonType.AI: return $r('app.media.lifi');
      case MainButtonType.ARCHIVE: return $r('sys.symbol.archivebox');
      default: return $r('sys.symbol.square');
    }
  }

  private handleSelect(isLeft: boolean, value: MainButtonType) {
    if (isLeft) {
      this.leftBtnType = value;
    } else {
      this.rightBtnType = value;
    }

    if (isLeft) {
      LocalValues.getInstance().setMainLeftButton(value);
    } else {
      LocalValues.getInstance().setMainRightButton(value);
    }
  }

  build() {
    HdsNavDestination() {
      TopSafeContainer({ topAvoidHeight: this.statusBarHeight + this.TITLE_BAR_CONTENT_HEIGHT }) {
        Column({ space: 16 }) {

          SettingsSection() {
            Column() {
              TopBarSchematic({
                leftType: this.leftBtnType,
                rightType: this.rightBtnType
              })
            }
            .padding(12)
          }

          SettingsSection({ title: '左侧功能' }) {
            ForEach(this.options, (item: ButtonOption, index: number) => {
              SettingsCheckItem({
                title: item.text,
                icon: this.getIcon(item.value),
                isImage: item.value === MainButtonType.AI,
                isSelected: this.leftBtnType === item.value,
                onItemClick: () => {
                  this.handleSelect(true, item.value);
                }
              })
              if (index < this.options.length - 1) {
                SettingsDivider()
              }
            })
          }

          SettingsSection({ title: '右侧功能' }) {
            ForEach(this.options, (item: ButtonOption, index: number) => {
              SettingsCheckItem({
                title: item.text,
                icon: this.getIcon(item.value),
                isImage: item.value === MainButtonType.AI,
                isSelected: this.rightBtnType === item.value,
                onItemClick: () => {
                  this.handleSelect(false, item.value);
                }
              })
              if (index < this.options.length - 1) {
                SettingsDivider()
              }
            })
          }

          // 4. 说明文案
          Text('通过自定义主页快捷功能，您可以打造符合个人习惯的 Deadliner，让核心功能触手可及。')
            .fontSize(12)
            .lineHeight(16)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .padding({ left: 24, right: 24, top: 8, bottom: 24 })
            .width('100%')

        }
        .width('100%')
        .padding(16)
        .justifyContent(FlexAlign.Start)
        .constraintSize({ minHeight: '100%' })
      }
    }
    .titleBar({
      style: getImmersiveTitleBarStyle(this.isWideScreen),
      content: { title: { mainTitle: "主页快捷功能" } }
    })
  }
}