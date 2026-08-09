import { ComponentContent, promptAction } from '@kit.ArkUI';
import { ITheme } from '../../common/theme/ThemeModel';
import { ImmersivePopupSurface } from '../../common/ui/ImmersivePopupSurface';
import { DefaultCustomDialogMaterial } from '../../common/style/SystemMaterialCompat';

class DateTimeDialogParams {
  selectedDate: Date = new Date();
  onAccept: (date: Date) => void = () => {};
  close: () => void = () => {};
}

@Component
struct DateTimeContent {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  params: DateTimeDialogParams = new DateTimeDialogParams();

  // 内部状态，用于驱动标题和选择器联动
  @State currentDate: Date = new Date();

  aboutToAppear() {
    // 初始化内部状态
    this.currentDate = new Date(this.params.selectedDate);
  }

  // 辅助方法：获取格式化的日期标题
  private getTitle(date: Date): string {
    const weekDays = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];
    // 格式：2026年1月3日 星期六
    return `${date.getFullYear()}年${date.getMonth() + 1}月${date.getDate()}日 ${weekDays[date.getDay()]}`;
  }

  build() {
    Column() {
      ImmersivePopupSurface({
        paddingValue: 8,
        radius: 36,
        maxWidthValue: 360,
        fallbackBlurStyle: BlurStyle.Regular,
        materialPreset: DefaultCustomDialogMaterial
      }) {
        Column() {
          Row() {
            Text(this.getTitle(this.currentDate))
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 24, bottom: 16 })

          Row() {
            DatePicker({
              start: new Date('2000-1-1'),
              end: new Date('2100-12-31'),
              selected: this.currentDate
            })
              .onDateChange((value: Date) => {
                this.currentDate.setFullYear(value.getFullYear());
                this.currentDate.setMonth(value.getMonth());
                this.currentDate.setDate(value.getDate());
                this.currentDate = new Date(this.currentDate);
              })
              .layoutWeight(3)
              .height(220)
              .selectedTextStyle({
                color: this.theme.accent,
                font: { weight: FontWeight.Medium, size: 18 }
              })

            TimePicker({
              selected: this.currentDate
            })
              .useMilitaryTime(true)
              .onChange((value: TimePickerResult) => {
                this.currentDate.setHours(value.hour);
                this.currentDate.setMinutes(value.minute);
                this.currentDate = new Date(this.currentDate);
              })
              .layoutWeight(2)
              .height(220)
              .selectedTextStyle({
                color: this.theme.accent,
                font: { weight: FontWeight.Medium, size: 18 }
              })
          }
          .width('100%')

          Row() {
            Button("取消")
              .backgroundColor(Color.Transparent)
              .fontColor(this.theme.accent)
              .onClick(() => {
                this.params.close();
              })
              .layoutWeight(1)

            Divider().vertical(true).height(24).color(Color.Gray).opacity(0.3)

            Button("确定")
              .backgroundColor(Color.Transparent)
              .fontColor(this.theme.accent)
              .onClick(() => {
                this.params.onAccept(this.currentDate);
                this.params.close();
              })
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ bottom: 16, top: 16 })
        }
        .width('100%')
      }
    }
    // ComponentContent 的根节点宽度相对于 Dialog 容器计算。占满可用空间后再限制最大宽度，
    // 避免二次百分比约束导致内容被裁剪。
    .width('100%')
    .constraintSize({ maxWidth: 360 })
    .alignItems(HorizontalAlign.Center)
  }
}

@Builder
function DateTimeBuilderWrapper(params: DateTimeDialogParams) {
  DateTimeContent({ params: params })
}

interface DateTimePickerOptions {
  selected?: Date;
  onAccept: (date: Date) => void;
}

export class DateTimePicker {
  static show(context: UIContext, options: DateTimePickerOptions) {
    const params = new DateTimeDialogParams();
    params.selectedDate = options.selected ? new Date(options.selected) : new Date();
    params.onAccept = options.onAccept;

    const contentNode = new ComponentContent(context, wrapBuilder(DateTimeBuilderWrapper), params);

    params.close = () => {
      const prompt = context.getPromptAction();
      prompt.closeCustomDialog(contentNode);
    };

    contentNode.update(params);

    const prompt = context.getPromptAction();
    prompt.openCustomDialog(contentNode, {
      alignment: DialogAlignment.Center,
      autoCancel: true,
      isModal: true,
      onWillDismiss: (dismissDialogAction: DismissDialogAction) => {
        if (dismissDialogAction.reason == DismissReason.TOUCH_OUTSIDE) {
          dismissDialogAction.dismiss()
        }
      },
    });
  }
}
