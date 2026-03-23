import { DDLItem } from "../../../model/DDLModels";
import { Metric, generateDashboardMetrics } from "../../../utils/OverviewUtils";
import { LengthMetrics } from '@kit.ArkUI';
import { FloatUpModifier } from "../../../utils/animation/FloatUpModifier";
import { BlurBackgroundModifier } from "../../../utils/animation/BlurBackgroundModifier";

@Component
export struct DashboardSection {
  @Prop items: DDLItem[] = [];

  @State metrics: Metric[] = [];

  aboutToAppear(): void {
    // 计算指标
    this.metrics = generateDashboardMetrics(this.items);
  }

  // 监听数据变化重新计算
  onItemsChange() {
    this.metrics = generateDashboardMetrics(this.items);
  }

  build() {
    Column() {

      DashboardHeader()
        .width('100%')
        .padding({ left: 16, right: 16, top: 16 })
        .attributeModifier(new FloatUpModifier(0))

      WaterFlow() {
        ForEach(this.metrics, (item: Metric, index: number) => {
          FlowItem() {
            MetricCard({ metric: item })
          }
          .width('100%') // 在两列模式下，这会让它填充列宽
          .attributeModifier(new FloatUpModifier(index + 1, 20))
        })
      }
      .columnsTemplate("1fr 1fr") // 两列布局
      .columnsGap(10) // 列间距
      .rowsGap(10)    // 行间距
      .width('100%')
      .height('100%') // 必须有高度，否则可能显示不出来
      .padding({ left: 16, right: 16, top: 16, bottom: 40 })

      // 注意：WaterFlow 也是个 Scroll 容器。
      // 如果外层有 TopSafeContainer (Scroll)，WaterFlow 可能会导致嵌套滚动冲突。
      // 解决方案：使用 .nestedScroll 属性
      .nestedScroll({
        scrollForward: NestedScrollMode.PARENT_FIRST,
        scrollBackward: NestedScrollMode.PARENT_FIRST
      })
    }
    .width('100%')
    // 这里也不要定死高度，让 WaterFlow 自己撑开或滚动
  }
}

// =========================================
// Header 组件 (带有背景图的大卡片)
// =========================================
@Component
struct DashboardHeader {
  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Image($r('app.media.dashboard_background'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .opacity(0.8)

      // 文字
      Text("上月\n数据汇总")
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .padding(24)
        .lineHeight(36)
    }
    .width('100%')
    .height(180)
    .borderRadius(24)
    .clip(true)
  }
}

// =========================================
// Metric Card 组件 (单个指标)
// =========================================
@Component
struct MetricCard {
  @Prop metric: Metric;

  @StorageProp('customBackgroundImage') customBg: string = '';

  build() {
    Column() {
      // 标题
      Text(this.metric.label)
        .fontSize(12)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .margin({ bottom: 8 })

      // 数值
      Text(this.metric.value)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))

      // 变化量 (如果有)
      if (this.metric.change) {
        Row() {
          // 箭头图标
          if (this.metric.isDown !== undefined) {
            SymbolGlyph(this.metric.isDown ? $r('sys.symbol.arrow_down') : $r('sys.symbol.arrow_up'))
              .fontSize(16)
              .fontColor([this.metric.isDown ? $r('app.color.chart_red') : $r('app.color.chart_green')])
              .margin({ right: 4 })
          }

          // 变化数值
          Text(this.metric.change)
            .fontSize(14)
            .fontColor(
              this.metric.isDown === true ? $r('app.color.chart_red') :
                this.metric.isDown === false ? $r('app.color.chart_green') :
                  $r('app.color.chart_blue')
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