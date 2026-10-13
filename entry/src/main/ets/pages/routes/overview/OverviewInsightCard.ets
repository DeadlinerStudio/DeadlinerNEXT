import { OverviewViewModel } from './OverviewViewModel';
import { StatsCardContainer } from '../../components/OverviewComponents';
import { ITheme } from '../../../common/theme/ThemeModel';

@Component
export struct OverviewInsightCard {
  @ObjectLink model: OverviewViewModel;
  @Prop theme: ITheme;
  @Prop detail: boolean = false;
  onOpen: () => void = () => {};
  build() {
    StatsCardContainer() {
      Column({ space: 10 }) {
        Row() {
          Text('月度复盘').fontSize(16).fontWeight(FontWeight.Medium).layoutWeight(1)
          Text(this.model.lastMonthName).fontSize(13).fontColor($r('app.color.font_secondary'))
          if (!this.detail) {
            SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([$r('app.color.font_secondary')]).margin({ left: 8 })
          }
        }.width('100%').onClick(this.onOpen)
        if (this.model.isAnalyzing) {
          Row({ space: 8 }) {
            LoadingProgress().width(20).height(20)
            Text('正在生成月度洞察…').fontSize(14)
          }
        } else if (this.model.monthlyAnalysis !== null) {
          Text(this.model.monthlyAnalysis.summary).fontSize(14).lineHeight(22).width('100%')
            .fontColor($r('app.color.font_primary'))
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.model.monthlyAnalysis.keywords, (tag: string) => {
              Text(tag).fontSize(12).fontColor($r('app.color.font_secondary')).padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .backgroundColor(this.theme.brand50).borderRadius(20).margin({ right: 8, bottom: 8 })
            }, (tag: string) => tag)
          }.width('100%')
        } else {
          Text('月度洞察暂不可用，请配置 AI 或显式重试。').fontSize(14).fontColor($r('app.color.font_secondary'))
          Button('重试生成').onClick(() => { this.model.retryMonthlyAnalysis(); })
        }
        if (!this.detail) {
          Button('查看完整复盘与分享').fontSize(12).fontColor(this.theme.brand).backgroundColor(Color.Transparent)
            .padding(0).onClick(this.onOpen)
        }
      }.width('100%').alignItems(HorizontalAlign.Start)
    }
  }
}
