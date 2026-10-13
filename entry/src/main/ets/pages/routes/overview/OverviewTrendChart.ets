import {
  BarChart, BarChartModel, BarData, BarDataSet, BarEntry, ChartColorStop, EntryOhos, Fill,
  IBarDataSet, ILineDataSet, JArrayList, LineChart, LineChartModel, LineData, LineDataSet, Mode, XAxisPosition
} from '@ohos/mpchart';
import { OverviewTrendSeries } from './OverviewTrendPresentation';
import { OverviewTrendAxisFormatter, OverviewTrendMarker } from './OverviewTrendMarker';
import { ColorUtils, getHexColorSync } from '../../../utils/ColorUtils';
import { ITheme } from '../../../common/theme/ThemeModel';
import { ThemeManager } from '../../../common/theme/ThemeManager';

@Component
export struct OverviewTrendChart {
  @StorageProp('currentTheme') @Watch('updateChart') theme: ITheme = ThemeManager.getCurrentTheme();
  @Prop @Watch('updateChart') labels: string[] = [];
  @Prop @Watch('updateChart') series: OverviewTrendSeries[] = [];
  @Prop @Watch('updateChart') line: boolean = false;
  @Prop heightValue: number = 160;
  @Prop showLegend: boolean = true;
  @Prop description: string = '';
  private barModel: BarChartModel = new BarChartModel();
  private lineModel: LineChartModel = new LineChartModel();
  aboutToAppear(): void { this.updateChart(); }
  private updateChart(): void {
    const context: Context | undefined = this.getUIContext().getHostContext();
    if (context === undefined) return;
    const text: number = ColorUtils.parseColor(getHexColorSync(context, $r('app.color.font_secondary')));
    const popupBackground: string = getHexColorSync(context, this.theme.brand50);
    const popupText: string = getHexColorSync(context, $r('app.color.font_primary'));
    const grouped: boolean = !this.line && this.series.length > 1;
    const maximum: number = Math.max(1, ...this.series.map((set: OverviewTrendSeries) => Math.max(0, ...set.values))) * 1.15;
    if (this.line) {
      this.lineModel.setTouchEnabled(true); this.lineModel.setScaleEnabled(false); this.lineModel.setDoubleTapToZoomEnabled(false);
      this.lineModel.getDescription()?.setEnabled(false); this.lineModel.getLegend()?.setEnabled(false);
      this.lineModel.getAxisRight()?.setEnabled(false);
      this.lineModel.getAxisLeft()?.setDrawLabels(false); this.lineModel.getAxisLeft()?.setDrawGridLines(false);
      this.lineModel.getAxisLeft()?.setDrawAxisLine(false); this.lineModel.getAxisLeft()?.setAxisMinimum(0);
      this.lineModel.getAxisLeft()?.setAxisMaximum(maximum);
      const sets: JArrayList<ILineDataSet> = new JArrayList<ILineDataSet>();
      for (const series of this.series) {
        const entries: JArrayList<EntryOhos> = new JArrayList<EntryOhos>();
        series.values.forEach((value: number, index: number) => { entries.add(new EntryOhos(index, value)); });
        const set: LineDataSet = new LineDataSet(entries, series.label);
        const hex: string = getHexColorSync(context, series.color);
        const color: number = ColorUtils.parseColor(hex);
        set.setColorByColor(color); set.setLineWidth(2); set.setMode(this.showLegend ? Mode.CUBIC_BEZIER : Mode.LINEAR); set.setDrawValues(false);
        set.setDrawCircles(this.showLegend); set.setCircleColor(color); set.setCircleRadius(2.5);
        set.setDrawFilled(true); set.setFillAlpha(255); set.setDrawHighlightIndicators(false);
        const stops: JArrayList<ChartColorStop> = new JArrayList<ChartColorStop>();
        stops.add([ColorUtils.getTransparentColorStr(hex, this.showLegend ? '55' : '29'), 0]);
        stops.add([ColorUtils.getTransparentColorStr(hex, '00'), 1]);
        set.setGradientFillColor(stops); sets.add(set);
      }
      this.lineModel.setData(new LineData(sets));
      const axis = this.lineModel.getXAxis();
      axis?.setPosition(XAxisPosition.BOTTOM); axis?.setDrawGridLines(false); axis?.setDrawAxisLine(false);
      axis?.setTextColor(text); axis?.setTextSize(10); axis?.setGranularity(1);
      axis?.setAxisMinimum(0); axis?.setAxisMaximum(Math.max(1, this.labels.length - 1));
      axis?.setLabelCount(this.labels.length, true); axis?.setValueFormatter(new OverviewTrendAxisFormatter(this.labels, false));
      this.lineModel.setMarker(new OverviewTrendMarker(this.series, false, popupBackground, popupText));
      this.lineModel.notifyDataSetChanged(); this.lineModel.invalidate();
    } else {
      this.barModel.setTouchEnabled(true); this.barModel.setScaleEnabled(false); this.barModel.setDoubleTapToZoomEnabled(false);
      this.barModel.getDescription()?.setEnabled(false); this.barModel.getLegend()?.setEnabled(false);
      this.barModel.getAxisRight()?.setEnabled(false);
      this.barModel.getAxisLeft()?.setDrawLabels(false); this.barModel.getAxisLeft()?.setDrawGridLines(false);
      this.barModel.getAxisLeft()?.setDrawAxisLine(false); this.barModel.getAxisLeft()?.setAxisMinimum(0);
      this.barModel.getAxisLeft()?.setAxisMaximum(maximum);
      const sets: JArrayList<IBarDataSet> = new JArrayList<IBarDataSet>();
      for (const series of this.series) {
        const entries: JArrayList<BarEntry> = new JArrayList<BarEntry>();
        series.values.forEach((value: number, index: number) => { entries.add(new BarEntry(index, value)); });
        const set: BarDataSet = new BarDataSet(entries, series.label);
        const hex: string = getHexColorSync(context, series.color);
        set.setColorByColor(ColorUtils.parseColor(hex)); set.setDrawValues(false); set.setHighLightAlpha(0);
        const fills: JArrayList<Fill> = new JArrayList<Fill>();
        series.values.forEach((_value: number) => { fills.add(new Fill(hex, ColorUtils.getTransparentColorStr(hex, '80'))); });
        set.setFills(fills); sets.add(set);
      }
      const data: BarData = new BarData(sets); data.setBarWidth(grouped ? 0.35 : 0.5); data.setTopRadius(4);
      this.barModel.setData(data);
      if (grouped) this.barModel.groupBars(0, 0.2, 0.05);
      const axis = this.barModel.getXAxis();
      axis?.setPosition(XAxisPosition.BOTTOM); axis?.setDrawGridLines(false); axis?.setDrawAxisLine(false);
      axis?.setTextColor(text); axis?.setTextSize(10); axis?.setGranularity(1); axis?.setCenterAxisLabels(grouped);
      axis?.setAxisMinimum(grouped ? 0 : -0.5); axis?.setAxisMaximum(grouped ? this.labels.length : this.labels.length - 0.5);
      axis?.setLabelCount(this.labels.length, false); axis?.setValueFormatter(new OverviewTrendAxisFormatter(this.labels, grouped));
      this.barModel.setMarker(new OverviewTrendMarker(this.series, grouped, popupBackground, popupText));
      this.barModel.notifyDataSetChanged(); this.barModel.invalidate();
    }
  }
  private chartDescription(): string {
    return this.description + (this.showLegend ? '; ' + this.series.map((series: OverviewTrendSeries) => series.details.join('; ')).join('; ') : '');
  }
  build() {
    Column({ space: 8 }) {
      if (this.labels.length === 0) {
        Text('暂无数据').fontSize(14).fontColor($r('app.color.font_secondary')).height(this.heightValue).width('100%').textAlign(TextAlign.Center)
      } else if (this.line) {
        LineChart({ model: this.lineModel }).height(this.heightValue - (this.showLegend ? 24 : 0)).width('100%').accessibilityText(this.chartDescription())
      } else {
        BarChart({ model: this.barModel }).height(this.heightValue - (this.showLegend ? 24 : 0)).width('100%').accessibilityText(this.chartDescription())
      }
      if (this.showLegend && this.labels.length > 0) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
          ForEach(this.series, (series: OverviewTrendSeries) => {
            Row({ space: 5 }) {
              Blank().width(this.line ? 12 : 8).height(this.line ? 2 : 8).backgroundColor(series.color).borderRadius(2)
              Text(series.label).fontSize(11).fontColor($r('app.color.font_secondary'))
            }.margin({ left: 6, right: 6, bottom: 4 })
          }, (series: OverviewTrendSeries) => series.label)
        }.width('100%')
      }
    }.width('100%')
  }
}
