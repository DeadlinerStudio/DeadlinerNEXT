import { AxisBase, EntryOhos, Highlight, IAxisValueFormatter, MarkerView, MPPointF } from '@ohos/mpchart';
import { OverviewTrendSeries } from './OverviewTrendPresentation';

export class OverviewTrendAxisFormatter implements IAxisValueFormatter {
  private labels: string[];
  private grouped: boolean;
  constructor(labels: string[], grouped: boolean) { this.labels = labels; this.grouped = grouped; }
  getFormattedValue(value: number, _axis: AxisBase): string {
    const index: number = this.grouped ? Math.floor(value) : Math.round(value);
    return this.labels[index] ?? '';
  }
}

/** Keeps focus seconds and date ranges in popups instead of displaying rounded chart minutes. */
export class OverviewTrendMarker extends MarkerView {
  private series: OverviewTrendSeries[];
  private grouped: boolean;
  private background: string;
  private textColor: string;
  constructor(series: OverviewTrendSeries[], grouped: boolean, background: string, textColor: string) {
    super(); this.series = series; this.grouped = grouped; this.background = background; this.textColor = textColor;
  }
  draw(context: CanvasRenderingContext2D, posX: number, posY: number, entry: EntryOhos, highlight: Highlight): void {
    const index: number = this.grouped ? Math.floor(entry.getX()) : Math.round(entry.getX());
    const details: string = this.series[highlight.getDataSetIndex()]?.details[index] ?? entry.getY().toString();
    const lines: string[] = details.split('\n');
    context.save();
    context.font = '11vp sans-serif';
    const width: number = Math.max(...lines.map((line: string) => context.measureText(line).width)) + 20;
    const height: number = lines.length * 18 + 12;
    const left: number = Math.max(0, Math.min(posX - width / 2, context.width - width));
    const top: number = Math.max(0, posY - height - 8);
    context.fillStyle = this.background;
    context.beginPath();
    try { context.roundRect(left, top, width, height, 8); }
    catch (_error) { context.rect(left, top, width, height); }
    context.fill();
    context.fillStyle = this.textColor; context.textAlign = 'left'; context.textBaseline = 'middle';
    for (let line: number = 0; line < lines.length; line++) context.fillText(lines[line], left + 10, top + 15 + line * 18);
    context.restore();
  }
  getOffset(): MPPointF { return new MPPointF(0, 0); }
}
