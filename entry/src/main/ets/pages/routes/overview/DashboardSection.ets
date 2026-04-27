import { StatsCardContainer } from '../../components/OverviewComponents';
import { FloatUpModifier } from "../../../utils/animation/FloatUpModifier";
import { DailyStat, Metric } from "../../../utils/OverviewUtils";
import { MonthlyAnalysisResult } from "../../../ai/model/AIModels";
import { ITheme } from '../../../common/theme/ThemeModel';
import { BlurBackgroundModifier } from '../../../utils/animation/BlurBackgroundModifier';

@Component
export struct DashboardSection {
  @Prop metrics: Metric[] = [];
  @Prop dailyStats: DailyStat[] = [];
  @Prop lastMonthName: string = '';
  @Prop analysis: MonthlyAnalysisResult | null = null;
  @Prop isAnalyzing: boolean = false;

  build() {
    Column({ space: 12 }) {
      DashboardHeader({ monthName: this.lastMonthName })
        .width('100%')
        .padding({ left: 16, right: 16, top: 16 })
        .attributeModifier(new FloatUpModifier(0))

      if (this.isAnalyzing) {
        AnalyzingCard()
          .padding({ left: 16, right: 16 })
          .attributeModifier(new FloatUpModifier(1))
      } else if (this.analysis !== null) {
        AIAnalysisCard({ analysis: this.analysis })
          .padding({ left: 16, right: 16 })
          .attributeModifier(new FloatUpModifier(1))
      }

      WaterFlow() {
        ForEach(this.metrics, (item: Metric, index: number) => {
          FlowItem() {
            MetricCard({ metric: item })
          }
          .width('100%')
          .attributeModifier(new FloatUpModifier(index + (this.analysis !== null || this.isAnalyzing ? 2 : 1), 20))
        })
      }
      .columnsTemplate("1fr 1fr")
      .columnsGap(10)
      .rowsGap(10)
      .width('100%')
      .height(this.metrics.length > 0 ? 320 : 0)
      .padding({ left: 16, right: 16, top: 4 })
      .nestedScroll({
        scrollForward: NestedScrollMode.PARENT_FIRST,
        scrollBackward: NestedScrollMode.PARENT_FIRST
      })

      if (this.dailyStats.length > 0) {
        LastMonthActivityMap({
          monthName: this.lastMonthName,
          dailyStats: this.dailyStats
        })
          .padding({ left: 16, right: 16, top: 4 })
          .attributeModifier(new FloatUpModifier(this.metrics.length + (this.analysis !== null || this.isAnalyzing ? 2 : 1)))
      }

      Blank().height(72)
    }
    .width('100%')
  }
}

@Component
struct DashboardHeader {
  @Prop monthName: string = '';

  build() {
    Stack() {
      Image($r('app.media.dashboard_background'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .opacity(0.9)

      Column({ space: 4 }) {
        Text(this.monthName)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)

        Text('上月数据汇总')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .alignItems(HorizontalAlign.Start)
      .padding(24)
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .height(180)
    .borderRadius(24)
    .clip(true)
  }
}

@Component
struct AnalyzingCard {
  build() {
    StatsCardContainer() {
      Row({ space: 12 }) {
        LoadingProgress()
          .width(24)
          .height(24)
          .color($r('sys.color.ohos_id_color_text_primary'))

        Text("AI 正在深度分析上月数据...")
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
  }
}

@Component
struct AIAnalysisCard {
  @Prop analysis: MonthlyAnalysisResult | null = null;

  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  build() {
    if (this.analysis === null) {
      Column() {}
    } else {
      StatsCardContainer() {
        Column({ space: 16 }) {
          Row({ space: 10 }) {
            Image($r('app.media.icon'))
              .width(24)
              .height(24)
              .borderRadius(8)

            Text('AI 月度洞察')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.font_primary'))
          }
          .alignItems(VerticalAlign.Center)

          Text(this.analysisSummary())
            .fontSize(14)
            .lineHeight(22)
            .fontColor($r('app.color.font_primary'))

          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.analysisKeywords(), (tag: string) => {
              Text(tag)
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.font_secondary'))
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .backgroundColor(this.theme.brand50)
                .opacity(0.84)
                .borderRadius(999)
                .margin({ right: 8, bottom: 8 })
            }, (item: string) => item)
          }
          .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
      }
    }
  }

  private analysisSummary(): string {
    if (this.analysis === null) {
      return '';
    }
    return this.analysis.summary;
  }

  private analysisKeywords(): string[] {
    if (this.analysis === null) {
      return [];
    }
    return this.analysis.keywords;
  }
}

@Component
struct MetricCard {
  @Prop metric: Metric;

  @StorageProp('customBackgroundImage') customBg: string = '';

  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  build() {
    Column() {
      Text(this.metric.label)
        .fontSize(12)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .margin({ bottom: 8 })

      Text(this.metric.value)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))

      if (this.metric.change) {
        Row() {
          if (this.metric.isDown !== undefined) {
            SymbolGlyph(this.metric.isDown ? $r('sys.symbol.arrow_down') : $r('sys.symbol.arrow_up'))
              .fontSize(16)
              .fontColor([this.metric.isDown ? this.theme.chartOverdue: this.theme.chartCompleted])
              .margin({ right: 4 })
          }

          Text(this.metric.change)
            .fontSize(14)
            .fontColor(
              this.metric.isDown === true ? this.theme.chartOverdue :
                this.metric.isDown === false ? this.theme.chartCompleted :
                  this.theme.chartInfo
            )
        }
        .margin({ top: 8 })
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .padding(16)
    .attributeModifier(new BlurBackgroundModifier(!!this.customBg, $r('app.color.background_secondary'), BlurStyle.Regular))
    .borderRadius(24)
    .alignItems(HorizontalAlign.Start)
  }
}

@Component
struct LastMonthActivityMap {
  @Prop monthName: string = '';
  @Prop dailyStats: DailyStat[] = [];

  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  build() {
    StatsCardContainer() {
      Column({ space: 16 }) {
        Row() {
          Text(`${this.monthName}活动分布`)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.font_primary'))

          Blank()

          Text('每日完成频率')
            .fontSize(12)
            .fontColor($r('app.color.font_secondary'))
        }
        .width('100%')

        Column({ space: 6 }) {
          ForEach(this.chunkRows(), (row: DailyStat[], rowIndex: number) => {
            Row({ space: 6 }) {
              ForEach(row, (item: DailyStat) => {
                this.ActivityCell(item)
              }, (item: DailyStat) => item.fullDate)

              if (row.length < 7) {
                ForEach(this.placeholderIndexes(7 - row.length), (_: number) => {
                  Blank()
                    .layoutWeight(1)
                    .height(38)
                }, (item: number) => `${rowIndex}_${item}`)
              }
            }
            .width('100%')
          }, (_row: DailyStat[], index: number) => `row_${index}`)
        }
        .width('100%')

        Row({ space: 4 }) {
          Text('低频率')
            .fontSize(10)
            .fontColor($r('app.color.font_secondary'))

          ForEach(this.legendLevels(), (level: number) => {
            Stack() {}
              .width(12)
              .height(12)
              .backgroundColor(this.theme.chartInfo)
              .opacity(this.cellOpacity(level))
              .borderRadius(3)
          }, (item: number) => `${item}`)

          Text('高频率')
            .fontSize(10)
            .fontColor($r('app.color.font_secondary'))
        }
      }
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private ActivityCell(item: DailyStat) {
    Stack({ alignContent: Alignment.Center }) {
      Stack() {}
        .width('100%')
        .height('100%')
        .backgroundColor(this.theme.chartInfo)
        .opacity(this.cellOpacity(item.completed))
        .borderRadius(8)

      Text(item.dateStr)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(item.completed > 0 ? Color.White : $r('app.color.font_secondary'))
    }
    .layoutWeight(1)
    .height(38)
  }

  private chunkRows(): DailyStat[][] {
    const rows: DailyStat[][] = [];
    let index = 0;
    while (index < this.dailyStats.length) {
      rows.push(this.dailyStats.slice(index, index + 7));
      index += 7;
    }
    return rows;
  }

  private placeholderIndexes(count: number): number[] {
    const indexes: number[] = [];
    let index = 0;
    while (index < count) {
      indexes.push(index);
      index += 1;
    }
    return indexes;
  }

  private legendLevels(): number[] {
    return [0, 2, 4, 6, 8];
  }

  private cellOpacity(count: number): number {
    if (count <= 0) {
      return 0.12;
    }
    if (count < 2) {
      return 0.30;
    }
    if (count < 4) {
      return 0.50;
    }
    if (count < 6) {
      return 0.70;
    }
    return 1;
  }
}
