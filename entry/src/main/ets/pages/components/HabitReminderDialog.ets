import { ITheme } from "../../common/theme/ThemeModel";
import { ImmersivePopupSurface } from "../../common/ui/ImmersivePopupSurface";
import { DefaultCustomDialogMaterial } from "../../common/style/SystemMaterialCompat";

@CustomDialog
export struct HabitReminderDialog {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  controller: CustomDialogController;
  habitName: string = "";

  @State isEnabled: boolean = false;
  // 初始时间
  @State selectedTime: Date = new Date();

  onConfirm: (enabled: boolean, timeStr: string) => void = () => {};

  build() {
    Column() {
      ImmersivePopupSurface({
        paddingValue: 16,
        radius: 36,
        fallbackBlurStyle: BlurStyle.Regular,
        materialPreset: DefaultCustomDialogMaterial
      }) {
        Column() {
          Text(`提醒设置: ${this.habitName}`)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 8, bottom: 24 })

          Row() {
            Column() {
              Text("每日打卡提醒")
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.ohos_id_color_text_primary'))

              Text(this.isEnabled ? "将在指定时间发送通知" : "提醒已关闭")
                .fontSize(14)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Toggle({ type: ToggleType.Switch, isOn: this.isEnabled })
              .selectedColor(this.theme.brand)
              .onChange((isOn) => {
                animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
                  this.isEnabled = isOn;
                })
              })
          }
          .width('100%')
          .padding({ left: 8, right: 8 })

          if (this.isEnabled) {
            Column() {
              TimePicker({
                selected: this.selectedTime,
              })
                .useMilitaryTime(true)
                .textStyle({ color: $r('sys.color.ohos_id_color_text_secondary'), font: { size: '14fp', weight: FontWeight.Normal } })
                .selectedTextStyle({ color: this.theme.brand, font: { size: '18fp', weight: FontWeight.Bold } })
                .onChange((value: TimePickerResult) => {
                  const newDate = new Date();
                  newDate.setHours(value.hour, value.minute);
                  this.selectedTime = newDate;
                })
                .margin({ top: 16 })
            }
            .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))
          }

          Row() {
            Button("取消")
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .backgroundColor(Color.Transparent)
              .layoutWeight(1)
              .onClick(() => {
                this.controller.close();
              })

            Divider().vertical(true).height(24).color($r('sys.color.ohos_id_color_list_separator'))

            Button("保存")
              .fontColor(this.theme.brand)
              .backgroundColor(Color.Transparent)
              .layoutWeight(1)
              .onClick(() => {
                const timeStr = this.formatTime(this.selectedTime);
                this.onConfirm(this.isEnabled, timeStr);
                this.controller.close();
              })
          }
          .margin({ top: 24 })
          .width('100%')
        }
        .width('100%')
      }
    }
    .margin(16)
  }

  private formatTime(date: Date): string {
    const hours = date.getHours().toString().padStart(2, '0');
    const minutes = date.getMinutes().toString().padStart(2, '0');
    return `${hours}:${minutes}`;
  }
}
