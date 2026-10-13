import { ITheme } from '../../../common/theme/ThemeModel';
import { getHexColorSync } from '../../../utils/ColorUtils';

@Component
export struct OverviewPreviewChart {
  @Prop @Watch('redraw') values: number[] = [];
  @Prop @Watch('redraw') colors: ResourceColor[] = [];
  @Prop kind: string = 'bar';
  @Prop description: string = '';
  private canvas: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  @State widthValue: number = 0;
  @State heightValue: number = 0;
  private redraw(): void {
    const hostContext: Context | undefined = this.getUIContext().getHostContext();
    if (hostContext === undefined) return;
    const ctx: CanvasRenderingContext2D = this.canvas;
    const width: number = this.widthValue;
    const height: number = this.heightValue;
    if (width <= 0 || height <= 0) return;
    ctx.clearRect(0, 0, width, height);
    const total: number = this.values.reduce((sum: number, value: number) => sum + value, 0);
    const neutral: string = getHexColorSync(hostContext, $r('app.color.font_secondary'));
    if (this.kind === 'pie') {
      let start: number = -Math.PI / 2;
      if (total === 0) {
        ctx.fillStyle = neutral; ctx.globalAlpha = 0.18; ctx.beginPath();
        ctx.arc(width / 2, height / 2, Math.min(width, height) / 2, 0, Math.PI * 2); ctx.fill(); ctx.globalAlpha = 1;
      } else {
        for (let index: number = 0; index < this.values.length; index++) {
          const end: number = start + this.values[index] / total * Math.PI * 2;
          ctx.fillStyle = getHexColorSync(hostContext, this.colors[index]); ctx.beginPath(); ctx.moveTo(width / 2, height / 2);
          ctx.arc(width / 2, height / 2, Math.min(width, height) / 2, start, end); ctx.closePath(); ctx.fill(); start = end;
        }
      }
      return;
    }
    ctx.strokeStyle = neutral; ctx.globalAlpha = 0.2; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(0, height - 1); ctx.lineTo(width, height - 1); ctx.stroke(); ctx.globalAlpha = 1;
    if (total === 0 || this.values.length === 0) return;
    const maximum: number = Math.max(...this.values, 1);
    const color: string = getHexColorSync(hostContext, this.colors[0]);
    if (this.kind === 'bar') {
      ctx.fillStyle = color;
      const unit: number = width / this.values.length;
      for (let index: number = 0; index < this.values.length; index++) {
        const barHeight: number = this.values[index] / maximum * (height - 4);
        ctx.fillRect(index * unit + unit * 0.2, height - barHeight, unit * 0.6, barHeight);
      }
    } else {
      ctx.beginPath();
      for (let index: number = 0; index < this.values.length; index++) {
        const x: number = index * width / Math.max(1, this.values.length - 1);
        const y: number = height - 2 - this.values[index] / maximum * (height - 6);
        if (index === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
      }
      ctx.strokeStyle = color; ctx.lineWidth = 2; ctx.stroke();
      ctx.lineTo(width, height); ctx.lineTo(0, height); ctx.closePath();
      ctx.fillStyle = color; ctx.globalAlpha = 0.12; ctx.fill(); ctx.globalAlpha = 1;
    }
  }
  build() {
    Canvas(this.canvas).width('100%').height('100%')
      .onReady(() => { this.redraw(); })
      .onAreaChange((_old: Area, area: Area) => { this.widthValue = Number(area.width); this.heightValue = Number(area.height); this.redraw(); })
      .accessibilityText(this.description)
  }
}
