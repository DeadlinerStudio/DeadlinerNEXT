import { SettingsConstants as C } from '../../../common/local/SettingsConstants';
import { LocalValues } from '../../../common/local/LocalValues';
import { ITheme } from '../../../common/theme/ThemeModel';
import { ThemeManager } from '../../../common/theme/ThemeManager';

@Component
export struct OverviewTrendSettings {
  @StorageLink(C.KEY_OVERVIEW_SHOW_OVERDUE) showOverdue: boolean = true;
  @StorageProp('currentTheme') theme: ITheme = ThemeManager.getCurrentTheme();
  onSort: () => void = () => {};
  onClose: () => void = () => {};
  build() {
    Column({ space: 24 }) {
      Row({ space: 16 }) {
        Column({ space: 6 }) {
          Text('显示逾期柱状').fontSize(16).fontColor($r('app.color.font_primary'))
          Text('在最近 7 天图中显示按到期日归属的逾期未完成任务。')
            .fontSize(14).fontColor($r('app.color.font_secondary')).lineHeight(21)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.showOverdue }).selectedColor(this.theme.brand)
          .onChange((value: boolean) => { this.showOverdue = value; LocalValues.getInstance().setOverviewShowOverdue(value); })
          .accessibilityText('显示逾期柱状')
      }.width('100%').alignItems(VerticalAlign.Center)
      Button('调整卡片顺序').width('100%').backgroundColor(Color.Transparent).fontColor(this.theme.brand).onClick(this.onSort)
      Button('完成').width('100%').fontColor(Color.White).backgroundColor(this.theme.brand).onClick(this.onClose)
    }.width('100%').padding({ left: 24, right: 24, top: 16, bottom: 32 })
  }
}
