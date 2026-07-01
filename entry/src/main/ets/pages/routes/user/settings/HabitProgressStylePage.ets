import { HdsNavDestination, HdsNavDestinationAttribute } from '@kit.UIDesignKit';
import { SettingsConstants as C } from '../../../../common/local/SettingsConstants';
import { TopSafeContainer } from '../../../components/TopSafeContainer';
import { SettingsSection, SettingsDivider, SettingsCheckItem,
  SubSettingsDivider } from '../../../components/SettingsComponents';
import { LocalValues } from '../../../../common/local/LocalValues';
import { getImmersiveTitleBarStyle } from '../../../../common/style/NavStyles';
import { HabitProgress } from '../../../components/HabitComponents';

@Builder
export function HabitProgressStyleSettingsBuilder() {
  HabitProgressStyleSettings()
}

interface StyleOption {
  text: string;
  value: string;
  icon: Resource;
}

@Component
struct HabitProgressStyleSettings {
  @StorageLink('isWideScreen') isWideScreen: boolean = false;
  @StorageLink('statusBarHeight') statusBarHeight: number = 38;
  @StorageLink('topAvoidExtraHeight') topAvoidExtraHeight: number = 0;
  readonly TITLE_BAR_CONTENT_HEIGHT: number = 18;

  // 双向绑定 AppStorage，确保选中状态 UI 自动刷新
  @StorageLink(C.KEY_HABIT_PROGRESS_STYLE) currentStyle: string = 'ellipse';

  // 演示用的虚拟进度，让用户能直观看到效果
  private readonly demoProgress: number = 0.65;

  private readonly options: StyleOption[] = [
    { text: '月相 (默认)', value: 'ellipse', icon: $r('sys.symbol.circle') },
    { text: '环形', value: 'ring', icon: $r('sys.symbol.circle_grid_2x2') },
    { text: '条形', value: 'linear', icon: $r('sys.symbol.slider_horizontal_2') },
  ];

  private handleSelect(value: string) {
    // 1. 更新 StorageLink，触发 UI 刷新
    this.currentStyle = value;
    // 2. 持久化保存
    LocalValues.getInstance().setHabitProgressStyle(value);
  }

  build() {
    HdsNavDestination() {
      TopSafeContainer({ topAvoidHeight: this.statusBarHeight + this.TITLE_BAR_CONTENT_HEIGHT + this.topAvoidExtraHeight }) {
        Column({ space: 16 }) {

          // 1. 预览区域
          SettingsSection() {
            Column() {
              // 预览标题
              Text("预览")
                .fontSize(12)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                .margin({ bottom: 12 })

              Column() {
                HabitProgress({ progress: this.demoProgress })
                  .height(96)
                  .align(Alignment.Center)
              }
              .height(96)
              .alignItems(HorizontalAlign.Center)
            }
            .width('100%')
            .padding({ top: 24, bottom: 24 })
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          }

          // 2. 选项列表
          SettingsSection({ title: '选择样式' }) {
            ForEach(this.options, (item: StyleOption, index: number) => {
              SettingsCheckItem({
                title: item.text,
                isSelected: this.currentStyle === item.value, // 判断选中状态
                onItemClick: () => {
                  this.handleSelect(item.value);
                }
              })

              // 最后一个不需要分割线
              if (index < this.options.length - 1) {
                SubSettingsDivider()
              }
            })
          }

          // 3. 说明文案
          Text('选择最适合您的主页今日进度展示风格。')
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
      avoidLayoutSafeArea: this.isWideScreen,
      style: getImmersiveTitleBarStyle(this.isWideScreen),
      content: { title: { mainTitle: "习惯进度展示样式" } }
    })
  }
}
