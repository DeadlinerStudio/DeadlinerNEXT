import { ChartOptions, UCharts, UChartsController } from '@ibestservices/ucharts';
import { StatsCardContainer } from '../../components/OverviewComponents'
import { ContributionDay, DailyStat, MonthlyStat, WeeklyStat } from '../../../utils/OverviewUtils'
import {
  BarChart,
  BarChartModel,
  BarData,
  BarDataSet,
  BarEntry,
  JArrayList,
  IBarDataSet,
  XAxisPosition,
  YAxisLabelPosition,
  LegendVerticalAlignment,
  LegendHorizontalAlignment,
  LegendOrientation,
  LineChartModel,
  LineDataSet,
  Mode,
  ILineDataSet,
  LineChart,
  LineData,
  Fill,
  EntryOhos,
  LegendForm,
  ChartColorStop,
} from '@ohos/mpchart';
import { ColorUtils, getHexColorSync } from '../../../utils/ColorUtils';
import { IndexAxisValueFormatter } from './utils/IndexAxisValueFormatter';
import { CustomMarkerView } from './utils/CustomMarkerView';
import { FloatUpModifier } from '../../../utils/animation/FloatUpModifier';
import { TrendCard } from './OverviewViewModel';
import { ITheme } from '../../../common/theme/ThemeModel';

// --- 3. 主组件 ---
@Component
export struct TrendAnalysisSection {
  @Prop dailyStats: DailyStat[];
  @Prop monthlyStats: MonthlyStat[];
  @Prop weeklyStats: WeeklyStat[];
  @Prop contributionStats: ContributionDay[];

  @Prop cardOrder: TrendCard[];

  build() {
    Column({ space: 8 }) {
      ForEach(this.cardOrder, (cardId: TrendCard, idx) => {
        if (cardId === TrendCard.DAILY_TREND) {
          DailyCompletedCard({ dailyStats: $dailyStats })
            .attributeModifier(new FloatUpModifier(idx))
        } else if (cardId === TrendCard.MONTHLY_TREND) {
          MonthlyTrendCard({ monthlyStats: $monthlyStats })
            .attributeModifier(new FloatUpModifier(idx))
        } else if (cardId === TrendCard.WEEKLY_TREND) {
          PrevWeeksCard({ weeklyStats: $weeklyStats })
            .attributeModifier(new FloatUpModifier(idx))
        } else if (cardId === TrendCard.CONTRIBUTION_HEATMAP) {
          ContributionHeatmapCard({ stats: this.contributionStats })
            .attributeModifier(new FloatUpModifier(idx))
        }
      }, (item: string) => item)

      // 底部留白
      Blank().height(72)
    }
    .justifyContent(FlexAlign.Start)
    .constraintSize({ minHeight: '100%' })
    .width('100%')
    .padding({ left: 16, right: 16, top: 16 })
  }
}

@Component
struct DailyCompletedCard {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  @Link @Watch('updateChart') dailyStats: DailyStat[];

  // 【新增】控制是否显示逾期数据
  @Prop @Watch('updateChart') isOverdueShow: boolean = true;

  private model: BarChartModel = new BarChartModel();

  aboutToAppear() {
    // 1. 基础配置
    this.model.setTouchEnabled(true);
    this.model.setScaleEnabled(false);
    this.model.setDoubleTapToZoomEnabled(false);
    this.model.getDescription()!.setEnabled(false);
    this.model.setDrawGridBackground(false);

    // 图例配置
    const l = this.model.getLegend();
    if (l) {
      l.setEnabled(true);
      l.setVerticalAlignment(LegendVerticalAlignment.BOTTOM);
      l.setHorizontalAlignment(LegendHorizontalAlignment.CENTER);
      l.setOrientation(LegendOrientation.HORIZONTAL);
      l.setDrawInside(false);
      l.setYOffset(0);
    }

    const marker = new CustomMarkerView();
    this.model.setMarker(marker);

    // X 轴配置
    const xAxis = this.model.getXAxis();
    if (xAxis) {
      xAxis.setPosition(XAxisPosition.BOTTOM);
      xAxis.setDrawGridLines(false);
      xAxis.setGranularity(1);
      // 【注意】如果是单柱状图，不需要 CenterAxisLabels；如果是分组才需要。
      // 我们在 updateChart 里根据 isOverdueShow 动态设置
      xAxis.setTextSize(12);
    }

    const leftAxis = this.model.getAxisLeft();
    if (leftAxis) {
      leftAxis.setDrawGridLines(true);
      leftAxis.enableGridDashedLine(10, 10, 0);
      leftAxis.setAxisMinimum(0);
    }
    this.model.getAxisRight()!.setEnabled(false);

    this.updateChart();
  }

  updateChart() {
    if (!this.dailyStats || this.dailyStats.length === 0) {
      this.model.clear();
      return;
    }

    const ctx = getContext(this);
    // 1. 颜色准备
    const greenColorStr = getHexColorSync(ctx, this.theme.chartCompleted);
    const redColorStr = getHexColorSync(ctx, this.theme.chartOverdue);
    const txtColor = ColorUtils.parseColor(getHexColorSync(ctx, $r('app.color.font_secondary')));

    // 解析颜色为 int，用于 setColorByColor (修复图例颜色)
    const greenColorInt = ColorUtils.parseColor(greenColorStr);
    const redColorInt = ColorUtils.parseColor(redColorStr);

    const categories: string[] = [];
    const completedEntries = new JArrayList<BarEntry>();
    const overdueEntries = new JArrayList<BarEntry>();

    this.dailyStats.forEach((item, index) => {
      categories.push(item.dateStr);
      completedEntries.add(new BarEntry(index, item.completed));
      overdueEntries.add(new BarEntry(index, item.overdue));
    });

    const dataSets = new JArrayList<IBarDataSet>();

    // === 配置 DataSet 1 (完成 - 绿色) ===
    const set1 = new BarDataSet(completedEntries, "完成");
    set1.setDrawValues(false);
    set1.setHighLightAlpha(0);

    // 【修复图例颜色】显式设置基础颜色，这样图例的小方块就是绿色的了
    set1.setColorByColor(greenColorInt);

    // 绿色渐变填充
    const greenStart = ColorUtils.getTransparentColorStr(greenColorStr, '66');
    const greenEnd = ColorUtils.getTransparentColorStr(greenColorStr, 'FF');
    const greenFills = new JArrayList<Fill>();
    for (let i = 0; i < this.dailyStats.length; i++) greenFills.add(new Fill(greenStart, greenEnd));
    set1.setFills(greenFills);

    dataSets.add(set1);

    // === 【逻辑分支】根据 isOverdueShow 决定是否添加第二组 ===
    if (this.isOverdueShow) {
      const set2 = new BarDataSet(overdueEntries, "逾期");
      set2.setDrawValues(false);
      set2.setHighLightAlpha(0);

      // 【修复图例颜色】显式设置基础颜色
      set2.setColorByColor(redColorInt);

      // 红色渐变填充
      const redStart = ColorUtils.getTransparentColorStr(redColorStr, '66');
      const redEnd = ColorUtils.getTransparentColorStr(redColorStr, 'FF');
      const redFills = new JArrayList<Fill>();
      for (let i = 0; i < this.dailyStats.length; i++) redFills.add(new Fill(redStart, redEnd));
      set2.setFills(redFills);

      dataSets.add(set2);
    }

    // === 构建 Data ===
    const data = new BarData(dataSets);
    data.setTopRadius(4); // 圆角

    const xAxis = this.model.getXAxis();
    if (xAxis) {
      xAxis.setValueFormatter(new IndexAxisValueFormatter(categories));
      xAxis.setTextColor(txtColor);
    }

    // === 【关键】分组与不分组的布局差异 ===
    if (this.isOverdueShow) {
      // --- 模式 A: 分组显示 ---
      const groupSpace = 0.10;
      const barSpace = 0.05;
      const barWidth = 0.40;
      // (0.40 + 0.05) * 2 + 0.10 = 1.00

      data.setBarWidth(barWidth);

      // 分组模式下 X 轴设置
      if (xAxis) {
        xAxis.setCenterAxisLabels(true); // 标签居中
        xAxis.setAxisMinimum(0);
        xAxis.setAxisMaximum(this.dailyStats.length); // 这里的 Max 是 group 后的组数
        xAxis.setLabelCount(this.dailyStats.length);
      }

      this.model.setData(data);
      // 执行分组
      this.model.groupBars(0, groupSpace, barSpace);

    } else {
      // --- 模式 B: 单柱显示 ---
      // 没有分组，柱子可以宽一点
      data.setBarWidth(0.6);

      // 单柱模式下 X 轴设置
      if (xAxis) {
        xAxis.setCenterAxisLabels(false); // 标签直接对应柱子，不需偏移
        xAxis.setAxisMinimum(-0.5); // 让第一根柱子稍微离左边有点距离，或者直接默认
        xAxis.setAxisMaximum(this.dailyStats.length - 0.5); // 调整范围
        xAxis.setLabelCount(this.dailyStats.length);
      }

      this.model.setData(data);
    }

    // 更新其他颜色
    const l = this.model.getLegend();
    if (l) l.setTextColor(txtColor);

    const leftAxis = this.model.getAxisLeft();
    if (leftAxis) leftAxis.setTextColor(txtColor);

    this.model.animateY(1000);
    this.model.notifyDataSetChanged();
  }

  build() {
    StatsCardContainer() {
      // 标题栏增加开关
      Row() {
        Text("本周完成情况")
          .fontSize(16)
          .fontWeight(FontWeight.Medium)

        Blank()

        // 简单的切换开关 UI
        Row() {
          Checkbox({ name: 'showOverdue', group: 'stats' })
            .select(this.isOverdueShow)
            .selectedColor(this.theme.chartOverdue) // 选中时的颜色
            .onChange((value: boolean) => {
              this.isOverdueShow = value;
            })
            .width(16)
            .height(16)

          Text("显示逾期")
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .margin({ left: 4 })
        }
        .onClick(() => {
          // 点击文字也能切换
          this.isOverdueShow = !this.isOverdueShow;
        })
      }
      .width('100%')
      .margin({ bottom: 10 })
      .padding({ left: 10, right: 10 })


      if (this.dailyStats.length > 0) {
        Column() {
          BarChart({ model: this.model })
            .width('100%')
            .height(220)
        }
      } else {
        this.EmptyView()
      }
    }
  }

  @Builder EmptyView() {
    Text("暂无数据")
      .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
      .height(100)
      .width('100%')
      .textAlign(TextAlign.Center)
  }
}

@Component
struct MonthlyTrendCard {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  @Link @Watch('updateChart') monthlyStats: MonthlyStat[];
  @State @Watch('updateChart') totalMonth: number = 12;

  private model: LineChartModel = new LineChartModel();

  aboutToAppear() {
    // 1. 基础配置
    this.model.setTouchEnabled(true);
    this.model.setScaleEnabled(false);
    this.model.setDoubleTapToZoomEnabled(false);
    this.model.getDescription()!.setEnabled(false);
    this.model.setDrawGridBackground(false);

    // 设置 Marker
    const marker = new CustomMarkerView();
    this.model.setMarker(marker);

    const ctx = getContext(this);
    const txtColor = ColorUtils.parseColor(getHexColorSync(ctx, $r('app.color.font_secondary')));

    // 图例配置
    const l = this.model.getLegend();
    if (l) {
      l.setEnabled(true);
      l.setVerticalAlignment(LegendVerticalAlignment.BOTTOM);
      l.setHorizontalAlignment(LegendHorizontalAlignment.CENTER);
      l.setOrientation(LegendOrientation.HORIZONTAL);
      l.setDrawInside(false);
      l.setTextColor(txtColor);
      l.setForm(LegendForm.LINE);
    }

    // X 轴配置
    const xAxis = this.model.getXAxis();
    if (xAxis) {
      xAxis.setPosition(XAxisPosition.BOTTOM);
      xAxis.setDrawGridLines(false);
      xAxis.setGranularity(1);
      xAxis.setTextColor(txtColor);

      // 【关键修复 2】设置旋转角度，防止文字太长导致只能显示一半
      xAxis.setLabelRotationAngle(-45);
      // 增加底部距离，防止旋转后的文字被切掉
      xAxis.setYOffset(10);
    }

    // Y 轴配置
    const leftAxis = this.model.getAxisLeft();
    if (leftAxis) {
      leftAxis.enableGridDashedLine(10, 10, 0);
      leftAxis.setAxisMinimum(0);
      leftAxis.setTextColor(txtColor);
    }
    this.model.getAxisRight()!.setEnabled(false);

    this.updateChart();
  }

  updateChart() {
    if (!this.monthlyStats || this.monthlyStats.length === 0) {
      this.model.clear();
      return;
    }

    // 1. 重置视口 (防止之前缩放状态残留)
    this.model.fitScreen();

    const ctx = getContext(this);
    const blueHex = getHexColorSync(ctx, this.theme.chartInfo);
    const greenHex = getHexColorSync(ctx, this.theme.chartCompleted);
    const redHex = getHexColorSync(ctx, this.theme.chartOverdue);

    const blueColor = ColorUtils.parseColor(blueHex);
    const greenColor = ColorUtils.parseColor(greenHex);
    const redColor = ColorUtils.parseColor(redHex);

    const txtColor = ColorUtils.parseColor(getHexColorSync(ctx, $r('app.color.font_secondary')));

    // 2. 截取数据
    const displayStats = this.monthlyStats.slice(-this.totalMonth);

    const categories: string[] = [];
    const totalEntries = new JArrayList<EntryOhos>();
    const completedEntries = new JArrayList<EntryOhos>();
    const overdueEntries = new JArrayList<EntryOhos>();

    displayStats.forEach((item, index) => {
      categories.push(item.monthStr);
      totalEntries.add(new EntryOhos(index, item.total));
      completedEntries.add(new EntryOhos(index, item.completed));
      overdueEntries.add(new EntryOhos(index, item.overdue));
    });

    // === 辅助配置函数 ===
    const setupSet = (entries: JArrayList<EntryOhos>, label: string, colorInt: number, colorHex: string): LineDataSet => {
      const set = new LineDataSet(entries, label);

      // 线条
      set.setColorByColor(colorInt);
      set.setLineWidth(2);
      set.setMode(Mode.CUBIC_BEZIER);

      // 【渐变修复】
      set.setDrawFilled(true);
      // 这里的 255 (FF) 很重要，如果设为 100 会导致整体变淡，甚至影响渐变显示
      set.setFillAlpha(255);

      // 生成 Hex 字符串: #AARRGGBB
      const startColor = ColorUtils.getTransparentColorStr(colorHex, '66'); // 顶部 (约40%不透明)
      const endColor = ColorUtils.getTransparentColorStr(colorHex, '00');   // 底部 (全透明)

      // 构造渐变停止点
      let gradientStops = new JArrayList<ChartColorStop>();
      gradientStops.add([startColor, 0.0]); // 0.0 = 顶部
      gradientStops.add([endColor, 1.0]);   // 1.0 = 底部

      set.setGradientFillColor(gradientStops);

      // 1. 不显示数值文字
      set.setDrawValues(false);

      // 2. 开启绘制圆点
      set.setDrawCircles(true);

      // 3. 设置圆点颜色 (与线条颜色 colorInt 一致)
      set.setCircleColor(colorInt);

      // 4. 设置圆点大小 (2.5f 比较小巧精致)
      set.setCircleRadius(2.5);

      // 5. 设置为实心点 (不画内部孔)
      set.setDrawCircleHole(true);

      // 保留点击高亮配置
      set.setHighlightEnabled(true);
      set.setDrawHighlightIndicators(false);

      return set;
    };

    const dataSets = new JArrayList<ILineDataSet>();
    // 添加顺序：总计(最底层) -> 完成 -> 逾期(最上层)
    dataSets.add(setupSet(totalEntries, "总任务", blueColor, blueHex));
    dataSets.add(setupSet(completedEntries, "已完成", greenColor, greenHex));
    dataSets.add(setupSet(overdueEntries, "逾期完成", redColor, redHex));

    const data = new LineData(dataSets);

    // 3. 先设置数据
    this.model.setData(data);

    // === 【关键修复】在 setData 之后强制配置 X 轴 ===
    // 这样可以覆盖 MPChart 在 setData 时自动计算的 labelCount
    const xAxis = this.model.getXAxis();
    if (xAxis) {
      xAxis.setValueFormatter(new IndexAxisValueFormatter(categories));

      xAxis.setAxisMinimum(0);
      // 确保最大值精确对应最后一个索引
      xAxis.setAxisMaximum(displayStats.length - 1);

      // 强制设置标签数量 = 数据长度
      // 第二个参数 true 代表 "force"，即禁止库自动跳过标签
      xAxis.setLabelCount(displayStats.length, true);
    }

    // 4. 动画与刷新
    this.model.animateY(800);
    this.model.notifyDataSetChanged();
  }

  build() {
    StatsCardContainer() {
      Text("每月趋势")
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 10 })

      if (this.monthlyStats.length > 0) {
        Column() {
          LineChart({ model: this.model })
            .width('100%')
            // 如果旋转了文字，图表高度可能需要微调增加一点，给底部文字留空间
            .height(250)
        }
      } else {
        this.EmptyView()
      }
    }
  }

  @Builder EmptyView() {
    Text("暂无数据")
      .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
      .height(100)
      .width('100%')
      .textAlign(TextAlign.Center)
  }
}

@Component
struct PrevWeeksCard {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  @Link @Watch('updateChart') weeklyStats: WeeklyStat[];

  // 【差异点】垂直图表使用 BarChartModel
  private model: BarChartModel = new BarChartModel();

  aboutToAppear() {
    // 1. 基础交互配置 (参考 CompletionTimeCard)
    this.model.setTouchEnabled(true);
    this.model.setScaleEnabled(false); // 禁止缩放
    this.model.setDoubleTapToZoomEnabled(false);
    this.model.getDescription()!.setEnabled(false);
    this.model.getLegend()!.setEnabled(false);
    this.model.setDrawGridBackground(false);

    // 设置 MarkerView
    const marker = new CustomMarkerView();
    this.model.setMarker(marker);

    // X 轴配置
    const xAxis = this.model.getXAxis();
    if (xAxis) {
      xAxis.setPosition(XAxisPosition.BOTTOM);
      xAxis.setDrawGridLines(false);
      xAxis.setGranularity(1);
      xAxis.setTextSize(12);
    }

    // Y 轴配置
    const axisLeft = this.model.getAxisLeft();
    if (axisLeft) {
      axisLeft.enableGridDashedLine(10, 10, 0); // 虚线网格
      axisLeft.setAxisMinimum(0);
    }
    this.model.getAxisRight()!.setEnabled(false);

    this.updateChart();
  }

  updateChart() {
    if (!this.weeklyStats || this.weeklyStats.length === 0) {
      this.model.clear();
      return;
    }

    const ctx = getContext(this);

    // 1. 颜色准备
    const barColor = getHexColorSync(ctx, this.theme.chartTodo);
    const txtColor = ColorUtils.parseColor(getHexColorSync(ctx, $r('app.color.font_secondary')));

    const categories: string[] = [];
    const values = new JArrayList<BarEntry>();

    this.weeklyStats.forEach((item, index) => {
      categories.push(item.weekLabel);
      values.add(new BarEntry(index, item.completed));
    });

    // 2. DataSet 配置
    const set1 = new BarDataSet(values, "完成");
    set1.setDrawValues(false); // 点击才显示
    set1.setHighLightAlpha(0); // 去掉高亮遮罩

    // 3. 渐变色配置 (橙色)
    const startColor = ColorUtils.getTransparentColorStr(barColor, '66');
    const endColor = ColorUtils.getTransparentColorStr(barColor, 'FF');

    const gradientFills = new JArrayList<Fill>();
    for (let i = 0; i < this.weeklyStats.length; i++) {
      // 垂直图表：通常是从下往上渐变
      gradientFills.add(new Fill(startColor, endColor));
    }
    set1.setFills(gradientFills);

    const dataSets = new JArrayList<IBarDataSet>();
    dataSets.add(set1);

    const data = new BarData(dataSets);
    data.setBarWidth(0.5);
    data.setTopRadius(4); // 设置圆角

    // 4. 轴标签格式化与颜色
    const xAxis = this.model.getXAxis();
    if (xAxis) {
      xAxis.setValueFormatter(new IndexAxisValueFormatter(categories));
      xAxis.setLabelCount(categories.length);
      xAxis.setTextColor(txtColor);
    }

    const axisLeft = this.model.getAxisLeft();
    if (axisLeft) {
      axisLeft.setTextColor(txtColor);
    }

    this.model.setData(data);
    this.model.animateY(1000);
    this.model.notifyDataSetChanged();
  }

  build() {
    StatsCardContainer() {
      Text("近4周完成")
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 10 })

      if (this.weeklyStats.length > 0) {
        Column() {
          // 【差异点】使用 BarChart 组件
          BarChart({ model: this.model })
            .width('100%')
            .height(200)
        }
      } else {
        this.EmptyView()
      }
    }
  }

  @Builder EmptyView() {
    Text("暂无数据")
      .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
      .height(100)
      .width('100%')
      .textAlign(TextAlign.Center)
  }
}

@Component
struct ContributionHeatmapCard {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  @Prop stats: ContributionDay[] = [];

  build() {
    StatsCardContainer() {
      Column({ space: 14 }) {
        Row() {
          Text('活跃热力图')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.font_primary'))

          Blank()

          Text(`${this.stats.length}天内`)
            .fontSize(12)
            .fontColor($r('app.color.font_secondary'))
        }
        .width('100%')

        if (this.stats.length > 0) {
          Scroll() {
            Row({ space: 4 }) {
              ForEach(this.chunkWeeks(), (week: ContributionDay[], weekIndex: number) => {
                Column({ space: 4 }) {
                  ForEach(week, (day: ContributionDay) => {
                    this.HeatmapCell(day)
                  }, (day: ContributionDay) => `${day.date.getTime()}`)

                  if (week.length < 7) {
                    ForEach(this.placeholderIndexes(7 - week.length), (placeholder: number) => {
                      Blank()
                        .width(12)
                        .height(12)
                    }, (item: number) => `${weekIndex}_${item}`)
                  }
                }
              }, (_week: ContributionDay[], index: number) => `week_${index}`)
            }
            .padding({ top: 4, bottom: 4 })
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')

          Row({ space: 4 }) {
            Text('少')
              .fontSize(10)
              .fontColor($r('app.color.font_secondary'))

            ForEach(this.legendLevels(), (level: number) => {
              Stack() {}
                .width(8)
                .height(8)
                .backgroundColor(this.cellColor(level))
                .opacity(this.cellOpacity(level))
                .borderRadius(2)
            }, (item: number) => `${item}`)

            Text('多')
              .fontSize(10)
              .fontColor($r('app.color.font_secondary'))
          }
        } else {
          this.EmptyView()
        }
      }
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private HeatmapCell(day: ContributionDay) {
    Stack() {}
      .width(12)
      .height(12)
      .backgroundColor(this.cellColor(day.count))
      .opacity(this.cellOpacity(day.count))
      .borderRadius(2)
      .border({
        width: 0.5,
        color: $r('sys.color.ohos_id_color_list_separator')
      })
  }

  @Builder
  private EmptyView() {
    Text('暂无数据')
      .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
      .height(80)
      .width('100%')
      .textAlign(TextAlign.Center)
  }

  private chunkWeeks(): ContributionDay[][] {
    const weeks: ContributionDay[][] = [];
    let index = 0;
    while (index < this.stats.length) {
      weeks.push(this.stats.slice(index, index + 7));
      index += 7;
    }
    return weeks;
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
    return [0, 1, 3, 5, 7];
  }

  private cellColor(count: number): ResourceColor {
    if (count <= 0) {
      return $r('sys.color.ohos_id_color_list_separator');
    }
    return this.theme.chartCompleted;
  }

  private cellOpacity(count: number): number {
    if (count <= 0) {
      return 0.2;
    }
    if (count < 2) {
      return 0.28;
    }
    if (count < 4) {
      return 0.46;
    }
    if (count < 6) {
      return 0.68;
    }
    return 0.9;
  }
}
