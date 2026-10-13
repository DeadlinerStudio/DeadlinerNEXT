import { ChipSize } from '@kit.ArkUI';
import { ChipGroup, ChipGroupItemOptions } from '@ohos.arkui.advanced.ChipGroup';
import { HabitGoalType, HabitPeriod } from '../../../../../model/DDLModels';
import { AITextInput } from '../../../../components/AITextInput';
import { LoadingMask } from '../../../../components/LoadingMask';
import { ITheme } from '../../../../../common/theme/ThemeModel';
import {
  buildImmersiveMaterialCompat,
  canUseSystemMaterial
} from '../../../../../common/style/SystemMaterialCompat';

const COMMON_RADIUS = 24;
const ITEM_HEIGHT = 56;

@Component
export struct HabitFormView {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  // —— 双向绑定的表单数据 ——
  @Link name: string;
  @Link selectedPeriodIndex: number[];
  @Link selectedGoalTypeIndex: number[];
  @Link timesPerPeriod: string;
  @Link totalTarget: string;
  @Link weekdaysMask: number;

  // —— AI 相关配置 ——
  @Prop showAIInput: boolean = true;
  @Link aiInputText: string;
  @Link isAILoading: boolean;
  onAITriggered: () => Promise<void> = async () => {};

  @State inputBgColor: ResourceColor = $r('sys.color.search_container_focus_color');

  // —— 选项定义 ——
  private periodOptions: ChipGroupItemOptions[] = [
    { label: { text: "每日" } },
    { label: { text: "每周" } },
    { label: { text: "每月" } },
    { label: { text: "艾宾浩斯" } },
  ];

  private goalTypeOptions: ChipGroupItemOptions[] = [
    { label: { text: "坚持" } },
    { label: { text: "定量" } }
  ];

  private weekdayLabels: string[] = ['一', '二', '三', '四', '五', '六', '日'];

  private getPeriodFromIndex(index: number): HabitPeriod {
    const map = [HabitPeriod.DAILY, HabitPeriod.WEEKLY, HabitPeriod.MONTHLY, HabitPeriod.EBBINGHAUS];
    return map[index] || HabitPeriod.DAILY;
  }

  private getGoalTypeFromIndex(index: number): HabitGoalType {
    const map = [HabitGoalType.PER_PERIOD, HabitGoalType.TOTAL];
    return map[index] || HabitGoalType.PER_PERIOD;
  }

  private isSimpleMode(): boolean {
    const pIndex = this.selectedPeriodIndex.length > 0 ? this.selectedPeriodIndex[0] : 0;
    return this.getPeriodFromIndex(pIndex) === HabitPeriod.EBBINGHAUS;
  }

  private isWeekdaySelected(index: number): boolean {
    return (this.weekdaysMask & (1 << index)) !== 0;
  }

  private toggleWeekday(index: number): void {
    const bit: number = 1 << index;
    const nextMask: number = this.weekdaysMask ^ bit;
    if (nextMask !== 0) this.weekdaysMask = nextMask;
  }

  build() {
    Stack() {
      if (this.isAILoading) {
        LoadingMask()
          .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
      }

      Column({ space: 16 }) {
        // 1. AI 输入框 (可选)
        if (this.showAIInput) {
          AITextInput({
            text: $aiInputText,
            placeholder: "例如：每天背20个单词...",
            inputEnabled: !this.isAILoading,
            onAITriggered: this.onAITriggered
          })
        }

        // 2. 习惯名称
        TextInput({ placeholder: '要做什么？', text: this.name })
          .height(ITEM_HEIGHT)
          .fontSize(16)
          .backgroundColor(this.inputBgColor)
          .borderRadius(COMMON_RADIUS)
          .padding({ left: 16, right: 16 })
          .width('100%')
          .onChange((val) => {
            this.name = val;
          })

        // 3. 周期选择
        Column({ space: 8 }) {
          Text("类型 / 周期")
            .fontSize(14)
            .fontColor($r('app.color.font_secondary'))
            .padding({ left: 4 })

          if (canUseSystemMaterial()) {
            ChipGroup({
              items: this.periodOptions,
              itemStyle: {
                size: ChipSize.NORMAL,
                backgroundColor: this.inputBgColor,
                selectedBackgroundColor: this.theme.accent
              },
              selectedBackgroundSystemMaterial: buildImmersiveMaterialCompat({
                materialColor: this.theme.accent
              }),
              selectedIndexes: this.selectedPeriodIndex,
              onChange: (indexes: number[]) => {
                this.selectedPeriodIndex = indexes;
              }
            })
          } else {
            ChipGroup({
              items: this.periodOptions,
              itemStyle: {
                size: ChipSize.NORMAL,
                backgroundColor: this.inputBgColor,
                selectedBackgroundColor: this.theme.accent
              },
              selectedIndexes: this.selectedPeriodIndex,
              onChange: (indexes: number[]) => {
                this.selectedPeriodIndex = indexes;
              }
            })
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        // 4. 执行日：KMP 使用 Monday-first weekday mask 计算展示、进度与提醒。
        if (!this.isSimpleMode()) {
          Column({ space: 10 }) {
            Row() {
              Text('执行日')
                .fontSize(14)
                .fontColor($r('app.color.font_secondary'))
                .padding({ left: 4 })

              Blank()

              Button('每天')
                .type(ButtonType.Normal)
                .fontSize(12)
                .fontColor(this.weekdaysMask === 127 ? this.theme.accent : $r('app.color.font_secondary'))
                .backgroundColor(Color.Transparent)
                .accessibilityDescription(this.weekdaysMask === 127 ? '已选择' : '双击选择每天')
                .onClick(() => {
                  this.weekdaysMask = 127;
                })

              Button('工作日')
                .type(ButtonType.Normal)
                .fontSize(12)
                .fontColor(this.weekdaysMask === 31 ? this.theme.accent : $r('app.color.font_secondary'))
                .backgroundColor(Color.Transparent)
                .accessibilityDescription(this.weekdaysMask === 31 ? '已选择' : '双击选择工作日')
                .onClick(() => {
                  this.weekdaysMask = 31;
                })

              Button('周末')
                .type(ButtonType.Normal)
                .fontSize(12)
                .fontColor(this.weekdaysMask === 96 ? this.theme.accent : $r('app.color.font_secondary'))
                .backgroundColor(Color.Transparent)
                .accessibilityDescription(this.weekdaysMask === 96 ? '已选择' : '双击选择周末')
                .onClick(() => {
                  this.weekdaysMask = 96;
                })
            }
            .width('100%')

            Row({ space: 8 }) {
              ForEach(this.weekdayLabels, (label: string, index: number) => {
                Button(label)
                  .type(ButtonType.Normal)
                  .width(36)
                  .height(36)
                  .padding(0)
                  .borderRadius(18)
                  .fontSize(14)
                  .fontColor(this.isWeekdaySelected(index) ? Color.White : $r('app.color.font_secondary'))
                  .backgroundColor(this.isWeekdaySelected(index) ? this.theme.accent : this.inputBgColor)
                  .accessibilityText('星期' + label)
                  .accessibilityDescription(this.isWeekdaySelected(index) ? '已选择，双击取消' : '未选择，双击选择')
                  .accessibilityLevel('yes')
                  .onClick(() => {
                    this.toggleWeekday(index);
                  })
              })
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))
        }

        // 5. 目标设置区
        if (!this.isSimpleMode()) {
          Row({ space: 12 }) {
            // 左侧：频率
            Column({ space: 8 }) {
              Text("每次/频次")
                .fontSize(14)
                .fontColor($r('app.color.font_secondary'))
                .padding({ left: 4 })
              TextInput({ placeholder: '1', text: this.timesPerPeriod })
                .type(InputType.Number)
                .height(ITEM_HEIGHT)
                .fontSize(16)
                .backgroundColor(this.inputBgColor)
                .borderRadius(COMMON_RADIUS)
                .padding({ left: 16, right: 16 })
                .width('100%')
                .onChange((val) => {
                  this.timesPerPeriod = val;
                })
            }
            .layoutWeight(1)

            // 右侧：目标类型
            Column({ space: 8 }) {
              Text("目标类型")
                .fontSize(14)
                .fontColor($r('app.color.font_secondary'))
                .padding({ left: 4 })

              if (canUseSystemMaterial()) {
                ChipGroup({
                  items: this.goalTypeOptions,
                  itemStyle: {
                    size: ChipSize.NORMAL,
                    backgroundColor: this.inputBgColor,
                    selectedBackgroundColor: this.theme.accent
                  },
                  selectedBackgroundSystemMaterial: buildImmersiveMaterialCompat({
                    materialColor: this.theme.accent
                  }),
                  selectedIndexes: this.selectedGoalTypeIndex,
                  onChange: (indexes: number[]) => {
                    this.selectedGoalTypeIndex = indexes;
                  }
                })
              } else {
                ChipGroup({
                  items: this.goalTypeOptions,
                  itemStyle: {
                    size: ChipSize.NORMAL,
                    backgroundColor: this.inputBgColor,
                    selectedBackgroundColor: this.theme.accent
                  },
                  selectedIndexes: this.selectedGoalTypeIndex,
                  onChange: (indexes: number[]) => {
                    this.selectedGoalTypeIndex = indexes;
                  }
                })
              }
            }
            .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))

          // 6. 总目标输入框
          if (this.selectedGoalTypeIndex.length > 0 &&
            this.getGoalTypeFromIndex(this.selectedGoalTypeIndex[0]) === HabitGoalType.TOTAL) {
            Column({ space: 8 }) {
              Text("总目标数量")
                .fontSize(14)
                .fontColor($r('app.color.font_secondary'))
                .padding({ left: 4 })

              TextInput({ placeholder: '例如：100 (页/次)', text: this.totalTarget })
                .type(InputType.Number)
                .height(ITEM_HEIGHT)
                .fontSize(16)
                .backgroundColor(this.inputBgColor)
                .borderRadius(COMMON_RADIUS)
                .padding({ left: 16, right: 16 })
                .width('100%')
                .onChange((val) => {
                  this.totalTarget = val;
                })
            }
            .width('100%')
            .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))
          }
        } else {
          Row() {
            SymbolGlyph($r('sys.symbol.intelligent'))
              .fontSize(20)
              .fontColor([this.theme.accent])
              .margin({ right: 8 })

            Text("记忆曲线：根据艾宾浩斯遗忘曲线自动规划复习时间。")
              .fontSize(14)
              .fontColor($r('app.color.font_secondary'))
          }
          .width('100%')
          .padding({ top: 16 })
          .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))
        }
      }
      .width('100%')
    }
  }
}
