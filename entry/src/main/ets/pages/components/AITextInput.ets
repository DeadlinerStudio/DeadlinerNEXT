import { Animator, AnimatorResult, promptAction } from '@kit.ArkUI';
import { SettingsConstants as C } from '../../common/local/SettingsConstants'

@Component
export struct AITextInput {
  @Link text: string;
  @State isAiLoading: boolean = false;
  @State placeholder: string = '问 AI...';

  // 这里的 Consume 是为了配合你之前的上下文，如果没有可以删掉
  @Consume('isAiFlowShown') isAiFlowShown: boolean = false;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  @State canvasWidth: number = 0;
  @State canvasHeight: number = 0;

  private readonly gradientColors: string[] = ['#6AA9FF', '#FFC36A', '#FF6AE6'];

  // 核心尺寸
  private readonly borderRadiusA: number = 26; // 外圆角
  private readonly borderWidthA: number = 2;    // 边框粗细

  // 动画相关
  private angleAnimator: AnimatorResult | undefined = undefined;
  // 用于保存当前的旋转角度 (0 - 360)
  private currentAngle: number = 0;

  onAITriggered: () => Promise<void> = async () => {};

  aboutToAppear() {
    this.angleAnimator = Animator.create({
      duration: 2000, // 2秒转一圈
      easing: 'linear',
      delay: 0,
      fill: 'none',
      direction: 'normal',
      iterations: -1, // 无限循环
      begin: 0,
      end: 360
    });

    this.angleAnimator.onFrame = (value: number) => {
      this.currentAngle = value;
      this.drawBorder(); // 实时重绘
    };
  }

  aboutToDisappear(): void {
    this.angleAnimator?.cancel();
    this.angleAnimator = undefined;
  }

  private async triggerAI() {
    if (!this.text.trim()) {
      promptAction.showToast({ message: '请先输入内容再让 AI 识别' });
      return;
    }
    this.isAiFlowShown = true;
    this.isAiLoading = true;

    // 开始旋转动画
    this.angleAnimator?.play();

    try {
      await this.onAITriggered();
    } catch (e) {
      console.error(`[AITextInput] AI trigger failed: ${e}`);
      promptAction.showToast({ message: 'AI 识别失败，请稍后重试' });
    }

    this.isAiLoading = false;
    this.isAiFlowShown = false;

    // 停止动画并重置
    this.angleAnimator?.cancel();
    this.currentAngle = 0;
    this.drawBorder(); // 最后重绘一次回到静态
  }

  // 绘制边框逻辑 (合并了静态和动态逻辑)
  private drawBorder() {
    const ctx = this.context;
    const w = this.canvasWidth;
    const h = this.canvasHeight;
    const outerR = this.borderRadiusA;
    const lw = this.borderWidthA;
    const inset = lw / 2;
    const pathR = outerR - inset;

    // 1. 清空画布
    ctx.clearRect(0, 0, w, h);
    if (w === 0 || h === 0) return;

    let grad: CanvasGradient;

    if (this.isAiLoading) {
      // ===========================================
      // 动态模式：旋转渐变坐标 + 发光效果
      // ===========================================

      // 1. 计算中心点
      const cx = w / 2;
      const cy = h / 2;
      // 半径足够覆盖矩形即可
      const radius = Math.max(w, h) / 1.5;

      // 2. 将角度转换为弧度
      const rad = (this.currentAngle * Math.PI) / 180;

      // 3. 计算旋转后的起点 (x1, y1) 和终点 (x2, y2)
      // 这就像一根指针在圆盘上转动，指针的两端就是渐变的起点和终点
      const x1 = cx + radius * Math.cos(rad);
      const y1 = cy + radius * Math.sin(rad);
      const x2 = cx + radius * Math.cos(rad + Math.PI); // 对角线方向
      const y2 = cy + radius * Math.sin(rad + Math.PI);

      grad = ctx.createLinearGradient(x1, y1, x2, y2);

      // 这里可以加更多颜色断点，让旋转看起来更丰富
      grad.addColorStop(0.0, this.gradientColors[0]);
      grad.addColorStop(0.5, this.gradientColors[1]);
      grad.addColorStop(1.0, this.gradientColors[2]);

      // 4. 【核心】：Canvas 原生发光 (Blur)
      // 注意：shadowBlur 会消耗一定性能，但单组件无压力
      ctx.shadowBlur = 10;
      ctx.shadowColor = this.gradientColors[2]; // 使用粉色作为光晕色

    } else {
      // ===========================================
      // 静态模式：固定渐变 + 无发光
      // ===========================================
      grad = ctx.createLinearGradient(0, 0, w, h);
      grad.addColorStop(0.0, this.gradientColors[0]);
      grad.addColorStop(0.5, this.gradientColors[1]);
      grad.addColorStop(1.0, this.gradientColors[2]);

      // 清除阴影/发光
      ctx.shadowBlur = 0;
      ctx.shadowColor = 'transparent';
    }

    ctx.lineWidth = lw;
    ctx.strokeStyle = grad;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';

    // 绘制贝塞尔路径 (保持不变)
    const k = 0.6;
    const drawX = inset;
    const drawY = inset;
    const drawW = w - inset * 2;
    const drawH = h - inset * 2;
    const r = pathR;

    ctx.beginPath();
    ctx.moveTo(drawX + r, drawY);
    ctx.lineTo(drawX + drawW - r, drawY);
    ctx.bezierCurveTo(drawX + drawW - r * (1 - k), drawY, drawX + drawW, drawY + r * (1 - k), drawX + drawW, drawY + r);
    ctx.lineTo(drawX + drawW, drawY + drawH - r);
    ctx.bezierCurveTo(drawX + drawW, drawY + drawH - r * (1 - k), drawX + drawW - r * (1 - k), drawY + drawH, drawX + drawW - r, drawY + drawH);
    ctx.lineTo(drawX + r, drawY + drawH);
    ctx.bezierCurveTo(drawX + r * (1 - k), drawY + drawH, drawX, drawY + drawH - r * (1 - k), drawX, drawY + drawH - r);
    ctx.lineTo(drawX, drawY + r);
    ctx.bezierCurveTo(drawX, drawY + r * (1 - k), drawX + r * (1 - k), drawY, drawX + r, drawY);
    ctx.closePath();

    // 描边
    ctx.stroke();
  }

  @StorageProp(C.KEY_SHOW_AI_INPUT) showAiInput: boolean = true;
  @StorageProp(C.KEY_BASIC_MODE) basicMode: boolean = false;

  build() {
    if (this.showAiInput && !this.basicMode) {
      Stack({ alignContent: Alignment.Center }) {

        // Layer 1: 内容层 (背景 + 输入框)
        Column() {
          Stack({ alignContent: Alignment.BottomEnd }) {
            // 背景层
            Column()
              .width('100%')
              .height('100%')
              .borderRadius(this.borderRadiusA - 1)
              .backgroundColor($r('sys.color.search_container_focus_color'))

            // 输入框
            TextArea({ text: this.text, placeholder: this.placeholder })
              .width('100%')
              .height('100%')
              .backgroundColor(Color.Transparent)
              .borderRadius(this.borderRadiusA - 1)
              .padding(16)
              .onChange((val) => this.text = val)

            // 按钮
            Button({ type: ButtonType.Circle, stateEffect: true }) {
              SymbolGlyph(this.isAiLoading ? $r('sys.symbol.arrow_clockwise') : $r('sys.symbol.wand_and_stars'))
                .fontSize(20)
                .effectStrategy(SymbolEffectStrategy.SCALE)
                .fontColor([$r('app.color.font_primary')])
                // 按钮跳动
                .symbolEffect(new BounceSymbolEffect(EffectScope.WHOLE, EffectDirection.UP), this.isAiLoading)
            }
            .width(32)
            .height(32)
            .margin({ right: 10, bottom: 10 })
            .backgroundColor($r('sys.color.normal_button_container_focus_color'))
            .onClick(() => this.triggerAI())
          }
          .width('100%')
          .height('100%')
        }
        .width('100%')
        .height('100%')
        // Padding 1vp 露出底下的 Canvas
        .padding(1)

        // Layer 2: 唯一的 Canvas 层
        // 这里不需要 Visibility 控制，因为我们在 drawBorder 里动态改变画法
        Canvas(this.context)
          .width('100%')
          .height('100%')
          .hitTestBehavior(HitTestMode.None)
          .onAreaChange((oldValue, newValue) => {
            this.canvasWidth = newValue.width as number;
            this.canvasHeight = newValue.height as number;
            // 首次加载或尺寸变更时绘制
            this.drawBorder();
          })
      }
      .width('100%')
      .height(140)
    }
  }
}