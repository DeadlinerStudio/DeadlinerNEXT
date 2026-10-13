import { BarChart, BarChartModel, BarData, BarDataSet, BarEntry, JArrayList, IBarDataSet, XAxisPosition } from '@ohos/mpchart';
import { FocusDurationPoint, FocusStatisticsSummary } from './FocusStatisticsModels';
import { IndexAxisValueFormatter } from './utils/IndexAxisValueFormatter';
import { StatsCardContainer } from '../../components/OverviewComponents';
import { ColorUtils, getHexColorSync } from '../../../utils/ColorUtils';
import { ITheme } from '../../../common/theme/ThemeModel';
import { FocusPresentation } from '../focus/FocusPresentation';

@Component
export struct FocusTimeBrief {
  @Prop summary: FocusStatisticsSummary | null = null;
  build() {
    if (this.summary !== null && this.summary.durationByTarget !== null && this.summary.durationByTarget.habitDurationSeconds > 0) {
      Text('任务 ' + FocusPresentation.duration(this.summary.durationByTarget.taskDurationSeconds) +
        ' · 习惯 ' + FocusPresentation.duration(this.summary.durationByTarget.habitDurationSeconds))
        .fontSize(12).fontColor($r('sys.color.ohos_id_color_text_secondary')).width('100%')
    }
  }
}

@Component
export struct FocusDurationChart {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  @Prop title: string = '专注时间';
  @Prop @Watch('updateChart') points: FocusDurationPoint[] = [];
  @Prop summary: FocusStatisticsSummary | null = null;
  private model: BarChartModel = new BarChartModel();
  aboutToAppear(): void {
    this.model.setTouchEnabled(true); this.model.setScaleEnabled(false);
    this.model.getDescription()?.setEnabled(false); this.model.getLegend()?.setEnabled(false);
    this.model.getAxisRight()?.setEnabled(false); this.model.getAxisLeft()?.setAxisMinimum(0);
    this.model.getXAxis()?.setPosition(XAxisPosition.BOTTOM); this.model.getXAxis()?.setDrawGridLines(false);
    this.updateChart();
  }
  private updateChart(): void {
    const entries: JArrayList<BarEntry> = new JArrayList<BarEntry>();
    const labels: string[] = [];
    for (let i: number = 0; i < this.points.length; i++) {
      entries.add(new BarEntry(i, this.points[i].durationSeconds / 60));
      labels.push(this.points[i].startDate.substring(5, 10));
    }
    const sets: JArrayList<IBarDataSet> = new JArrayList<IBarDataSet>();
    const set: BarDataSet = new BarDataSet(entries, '专注（分钟）');
    set.setDrawValues(false); set.setColorByColor(ColorUtils.parseColor(getHexColorSync(getContext(this), this.theme.brand)));
    sets.add(set); const data: BarData = new BarData(sets); data.setBarWidth(0.6); data.setTopRadius(4);
    this.model.getXAxis()?.setValueFormatter(new IndexAxisValueFormatter(labels));
    this.model.setData(data); this.model.notifyDataSetChanged(); this.model.invalidate();
  }
  private total(): number { return this.summary?.totalDurationSeconds ?? this.points.reduce((sum: number, p: FocusDurationPoint) => sum + p.durationSeconds, 0); }
  build() {
    StatsCardContainer() {
      Row() {
        Text(this.title).fontSize(16).fontWeight(FontWeight.Medium).layoutWeight(1)
        Text(FocusPresentation.duration(this.total())).fontSize(14)
      }.width('100%')
      FocusTimeBrief({ summary: this.summary })
      BarChart({ model: this.model }).height(180).width('100%').accessibilityText(this.title + ' ' + FocusPresentation.duration(this.total()))
    }
  }
}
