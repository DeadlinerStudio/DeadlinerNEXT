import { DDLItem } from '../../../model/DDLModels';
import { ChartOptions, UCharts, UChartsController } from '@ibestservices/ucharts';
import { StatsCardContainer } from '../../components/OverviewComponents';
import { BarData, BarDataSet, BarEntry,
  HorizontalBarChart,
  HorizontalBarChartModel, JArrayList,
  LegendHorizontalAlignment,
  LegendOrientation,
  LegendVerticalAlignment,
  PieChart,
  PieChartModel,
  PieData,
  PieDataSet,
  PieEntry,
  XAxisPosition,
  ChartAnimator,
  IBarDataSet,
  Fill,
  OnChartValueSelectedListener,
  EntryOhos,
  Highlight
} from '@ohos/mpchart';
import { IndexAxisValueFormatter } from './utils/IndexAxisValueFormatter';
import { ColorUtils, getHexColorSync } from '../../../utils/ColorUtils';
import { CustomMarkerView } from './utils/CustomMarkerView';
import { FloatUpModifier } from '../../../utils/animation/FloatUpModifier';
import { OverviewCard } from './OverviewViewModel';
import { ITheme } from '../../../common/theme/ThemeModel';

interface ChartSeriesItem {
  name: string;
  value: number;
  color: string;
}

@Component
export struct OverviewStatsSection {
  @Prop todayCompleted: number;
  @Prop todayTodo: number;
  @Prop todayOverdue: number;
  @Prop activeAbandoned: number;
  @Prop historyStats: Map<string, number>;
  @Prop completionTimeStats: Array<[string, number]>;
  @Prop overdueItems: DDLItem[];

  @Prop cardOrder: OverviewCard[];
  @Prop isMediumLayout: boolean = false;

  private cardsForColumn(columnIndex: number): OverviewCard[] {
    return this.cardOrder.filter((_: OverviewCard, index: number) => index % 2 === columnIndex);
  }

  private cardOrderIndex(cardId: OverviewCard): number {
    return this.cardOrder.indexOf(cardId);
  }

  @Builder
  private cardBuilder(cardId: OverviewCard) {
    if (cardId === OverviewCard.ACTIVE_STATS) {
      ActiveStatsCard({
        completed: this.todayCompleted,
        todo: this.todayTodo,
        overdue: this.todayOverdue,
        abandoned: this.activeAbandoned
      })
        .attributeModifier(new FloatUpModifier(this.cardOrderIndex(cardId)))
    } else if (cardId === OverviewCard.COMPLETION_TIME) {
      CompletionTimeCard({ completionTimeStats: $completionTimeStats })
        .attributeModifier(new FloatUpModifier(this.cardOrderIndex(cardId)))
    } else if (cardId === OverviewCard.HISTORY_STATS) {
      HistoryStatsCard({ historyStats: $historyStats })
        .attributeModifier(new FloatUpModifier(this.cardOrderIndex(cardId)))
    }
  }

  build() {
    Column() {
      if (this.isMediumLayout) {
        Row({ space: 12 }) {
          Column({ space: 8 }) {
            ForEach(this.cardsForColumn(0), (cardId: OverviewCard) => {
              this.cardBuilder(cardId)
            }, (item: OverviewCard) => item)

            Blank().height(72)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Column({ space: 8 }) {
            ForEach(this.cardsForColumn(1), (cardId: OverviewCard) => {
              this.cardBuilder(cardId)
            }, (item: OverviewCard) => item)

            Blank().height(72)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .alignItems(VerticalAlign.Top)
      } else {
        Column({ space: 8 }) {
          ForEach(this.cardOrder, (cardId: OverviewCard) => {
            this.cardBuilder(cardId)
          }, (item: OverviewCard) => item)

          Blank().height(72)
        }
      }
    }
    .justifyContent(FlexAlign.Start)
    .constraintSize({ minHeight: '100%' })
    .width('100%')
    .padding({ left: 16, right: 16, top: 16 })
  }
}

@Component
struct ActiveStatsCard {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @Prop completed: number;
  @Prop todo: number;
  @Prop overdue: number;
  @Prop abandoned: number;

  build() {
    StatsCardContainer() {
      Text("今日概况")
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .margin({ bottom: 20 })
      Flex({ justifyContent: FlexAlign.SpaceAround }) {
        this.StatItem("今日完成", this.completed, this.theme.chartCompleted)
        this.StatItem("待办任务", this.todo, this.theme.chartTodo)
        this.StatItem("今日逾期", this.overdue, this.theme.chartOverdue)
        this.StatItem("已放弃", this.abandoned, $r('sys.color.ohos_id_color_text_secondary'))
      }
    }
  }
  @Builder StatItem(label: string, value: number, color: ResourceColor) {
    Column() {
      Text(value.toString()).fontSize(28).fontWeight(FontWeight.Bold).fontColor(color).margin({ bottom: 4 })
      Text(label).fontSize(12).fontColor($r('sys.color.ohos_id_color_text_secondary'))
    }.alignItems(HorizontalAlign.Center)
  }
}

@Component
struct CompletionTimeCard {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @Link @Watch('updateChart') completionTimeStats: Array<[string, number]>;

  private model: HorizontalBarChartModel = new HorizontalBarChartModel();

  aboutToAppear() {
    // 基础配置
    this.model.setTouchEnabled(true);
    this.model.setScaleEnabled(false);
    this.model.setDoubleTapToZoomEnabled(false);
    this.model.getDescription()!.setEnabled(false);
    this.model.getLegend()!.setEnabled(false);
    this.model.setDrawGridBackground(false);

    // 【修改】设置 MarkerView (点击气泡)
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
      axisLeft.setDrawGridLines(true);
      axisLeft.setEnabled(true);
      axisLeft.setAxisMinimum(0);
    }

    const axisRight = this.model.getAxisRight();
    if (axisRight) {
      axisRight.setEnabled(false);
    }

    this.updateChart();
  }

  updateChart() {
    if (!this.completionTimeStats || this.completionTimeStats.length === 0) return;

    const ctx = getContext(this);

    // 1. 获取基础颜色字符串 (用于生成渐变)
    const blueColorStr = getHexColorSync(ctx, this.theme.chartInfo);
    const txtColor = ColorUtils.parseColor(getHexColorSync(ctx, $r('app.color.font_secondary')));

    // 2. 准备数据
    // 【修改】需求3：把深夜放到最下面。
    // HorizontalBarChart 默认从下往上画 (Index 0 在最下)。
    // 如果原数组是 [深夜, 早晨, 下午...]，深夜在 index 0，应该已经在最下了。
    // 如果你之前看到深夜在最上面，说明原数组可能是倒序的，或者 MPChart 的绘制方向被反转了。
    // 这里我们做一个反转操作，确保顺序颠倒过来。
    const reversedStats = [...this.completionTimeStats].reverse();

    const categories: string[] = [];
    const values = new JArrayList<BarEntry>();

    reversedStats.forEach((item, index) => {
      categories.push(item[0]);
      values.add(new BarEntry(index, item[1]));
    });

    // 3. 设置 DataSet
    const dataSet = new BarDataSet(values, "完成数");

    // 【修改】需求2：渐变色
    // 计算渐变色：从 Alpha 0.5 到 实色
    const startColor = ColorUtils.getTransparentColorStr(blueColorStr, '66'); // 约 40% 透明度
    const endColor = ColorUtils.getTransparentColorStr(blueColorStr, 'FF'); // 100% 不透明

    const gradientFills = new JArrayList<Fill>();
    // HorizontalBarChart 的渐变逻辑：
    // 渐变通常是从 Bar 的底部到顶部（对于横向图，就是从左到右）
    // 我们给每一个 Bar 都添加这个渐变配置
    for (let i = 0; i < reversedStats.length; i++) {
      gradientFills.add(new Fill(endColor, startColor));
    }
    dataSet.setFills(gradientFills);

    dataSet.setHighLightAlpha(0);

    dataSet.setDrawValues(false); // 柱子上不直接写字，点击才显示 Marker

    const dataSets = new JArrayList<IBarDataSet>();
    dataSets.add(dataSet);

    const barData = new BarData(dataSets);
    barData.setBarWidth(0.6);

    // 4. 应用颜色和格式化
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

    this.model.setData(barData);
    this.model.animateY(1000);
    this.model.notifyDataSetChanged();
  }

  build() {
    StatsCardContainer() {
      Text("完成时间分布")
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .margin({ bottom: 10 })

      if (this.completionTimeStats.length > 0) {
        Column() {
          HorizontalBarChart({ model: this.model })
            .width('100%')
            .height(280)
        }
      } else {
        Column() {
          Text("暂无已完成数据")
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
        }
        .height(100)
        .justifyContent(FlexAlign.Center)
        .width('100%')
      }
    }
  }
}

interface SelectedItemInfo {
  label: string;
  value: number;
  color: number;
}

@Component
struct HistoryStatsCard {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  @Link @Watch('updateChart') historyStats: Map<string, number>;

  private model: PieChartModel = new PieChartModel();

  @State totalCount: number = 0;

  // 【新增】用来控制中间文字显示的状态
  @State selectedItem: SelectedItemInfo | null = null;

  // 【新增】定义选择监听器
  private valueSelectedListener: OnChartValueSelectedListener = {
    onValueSelected: (e: EntryOhos, h: Highlight) => {
      // 这里的 e 其实是 PieEntry，强转一下获取 label
      const pieEntry = e as PieEntry;
      this.selectedItem = {
        label: pieEntry.getLabel(),
        value: pieEntry.getY(),
        // 尝试从 DataSet 获取颜色有点麻烦，这里简化处理：
        // 实际上我们可以通过 highlight.getX() 也就是 index 来找颜色，
        // 但为了简单，我们直接显示数值，或者根据 label 匹配颜色。
        color: Color.Black as number // 占位
      };
    },
    onNothingSelected: () => {
      // 点击空白处，清空选中状态，恢复显示总计
      this.selectedItem = null;
    }
  }

  aboutToAppear() {
    this.model.setTouchEnabled(true);
    this.model.setRotationEnabled(true);
    this.model.setHighlightPerTapEnabled(true);
    this.model.setDragDecelerationFrictionCoef(0.95);

    this.model.getDescription()!.setEnabled(false);
    this.model.setExtraOffsets(5, 10, 5, 5);

    // 环形配置
    this.model.setDrawHoleEnabled(true);
    this.model.setHoleColor(Color.Transparent);
    this.model.setTransparentCircleColor(Color.White);
    this.model.setTransparentCircleAlpha(20);
    this.model.setHoleRadius(65);
    this.model.setTransparentCircleRadius(70);
    this.model.setDrawEntryLabels(false);

    // 【新增】注册监听器
    this.model.setOnChartValueSelectedListener(this.valueSelectedListener);

    // 注意：环形图这种交互模式下，通常不需要气泡 Marker，
    // 因为信息直接显示在中间了，所以删掉 setMarker
    // const marker = new CustomMarkerView();
    // this.model.setMarker(marker);

    const l = this.model.getLegend();
    if (l) {
      l.setEnabled(true);
      l.setVerticalAlignment(LegendVerticalAlignment.BOTTOM);
      l.setHorizontalAlignment(LegendHorizontalAlignment.CENTER);
      l.setOrientation(LegendOrientation.HORIZONTAL);
      l.setDrawInside(false);
      l.setYEntrySpace(5);
      l.setTextSize(12);
    }

    this.updateChart();
  }

  updateChart() {
    if (!this.historyStats || this.historyStats.size === 0) return;

    const ctx = getContext(this);
    const greenColor = ColorUtils.parseColor(getHexColorSync(ctx, this.theme.chartCompleted));
    const orangeColor = ColorUtils.parseColor(getHexColorSync(ctx, this.theme.chartTodo));
    const redColor = ColorUtils.parseColor(getHexColorSync(ctx, this.theme.chartOverdue));
    const grayColor = ColorUtils.parseColor(getHexColorSync(ctx, $r('sys.color.ohos_id_color_text_secondary')));
    const txtColor = ColorUtils.parseColor(getHexColorSync(ctx, $r('app.color.font_secondary')));

    const completed = this.historyStats.get("累计完成") || 0;
    const todo = this.historyStats.get("当前待办") || 0;
    const abandoned = this.historyStats.get("累计放弃") || 0;
    const overdue = this.historyStats.get("累计逾期") || 0;

    this.totalCount = completed + todo + abandoned + overdue;

    const entries = new JArrayList<PieEntry>();
    const colors = new JArrayList<number>();

    if (completed > 0) {
      entries.add(new PieEntry(completed, "完成"));
      colors.add(greenColor);
    }
    if (todo > 0) {
      entries.add(new PieEntry(todo, "待办"));
      colors.add(orangeColor);
    }
    if (abandoned > 0) {
      entries.add(new PieEntry(abandoned, "放弃"));
      colors.add(grayColor);
    }
    if (overdue > 0) {
      entries.add(new PieEntry(overdue, "逾期"));
      colors.add(redColor);
    }

    if (entries.isEmpty()) return;

    const dataSet = new PieDataSet(entries, "");
    dataSet.setColorsByList(colors);
    dataSet.setSliceSpace(2);
    dataSet.setSelectionShift(8); // 选中时弹出的距离
    dataSet.setDrawValues(false);
    dataSet.setDrawIcons(false);

    const data = new PieData(dataSet);

    const l = this.model.getLegend();
    if (l) l.setTextColor(txtColor);

    this.model.setData(data);
    this.model.animateY(1200);
    this.model.notifyDataSetChanged();
  }

  build() {
    StatsCardContainer() {
      Text("历史统计")
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .margin({ bottom: 10 })

      if (this.historyStats.size > 0 && Array.from(this.historyStats.values()).some(v => v > 0)) {
        Stack({ alignContent: Alignment.Center }) {

          PieChart({ model: this.model })
            .width('100%')
            .height(260)

          // 【核心修改】中间文字区域：根据是否有选中项显示不同内容
          Column() {
            if (this.selectedItem) {
              // === 状态 A: 显示选中项详情 ===
              Text(this.selectedItem.label)
                .fontSize(14)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                .animation({ duration: 300 }) // 添加一点过渡动画

              Text(Math.round(this.selectedItem.value).toString()) // 去掉小数
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('sys.color.ohos_id_color_text_primary'))
                .margin({ top: 4 })
                .animation({ duration: 300 })

            } else {
              // === 状态 B: 显示总计 ===
              Text("总计")
                .fontSize(14)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                .animation({ duration: 300 })

              Text(this.totalCount.toString())
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('sys.color.ohos_id_color_text_primary'))
                .margin({ top: 4 })
                .animation({ duration: 300 })
            }
          }
          .offset({ x: 0, y: -16 })
          .hitTestBehavior(HitTestMode.None)
        }
        .width('100%')
        .height(260)
      } else {
        Column() {
          Text("暂无数据")
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
        }
        .height(100)
        .justifyContent(FlexAlign.Center)
        .width('100%')
      }
    }
  }
}
