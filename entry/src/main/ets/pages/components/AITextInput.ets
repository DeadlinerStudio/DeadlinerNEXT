import { AppLog } from '../../common/logging/AppLog';
import { Animator, AnimatorResult } from '@kit.ArkUI';
import { SettingsConstants as C } from '../../common/local/SettingsConstants';
import { MaterialPresets, canUseSystemMaterial } from '../../common/style/SystemMaterialCompat';
import { Toast } from '../../common/ui/Toast';

@Component
export struct AITextInput {
  @Link text: string;

  @Prop placeholder: string = '问 AI...';
  @Prop multiline: boolean = true;
  @Prop inputHeight: number = 140;
  @Prop inputEnabled: boolean = true;
  @Prop idleIcon: Resource = $r('sys.symbol.wand_and_stars');
  @Prop showActionButton: boolean = true;
  @Prop respectGlobalVisibility: boolean = true;
  @Prop disableActionWhenEmpty: boolean = false;
  @Prop containerRadius: number = 26;
  @Prop sendButtonSize: number = 32;

  onAITriggered: () => Promise<void> = async (): Promise<void> => {};

  @State isAiLoading: boolean = false;
  @State canvasWidth: number = 0;
  @State canvasHeight: number = 0;

  @StorageProp(C.KEY_SHOW_AI_INPUT) showAiInput: boolean = true;
  @StorageProp(C.KEY_BASIC_MODE) basicMode: boolean = false;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private angleAnimator: AnimatorResult | undefined = undefined;
  private currentAngle: number = 0;

  private readonly gradientColors: string[] = ['#6AA9FF', '#FFC36A', '#FF6AE6'];
  private readonly borderStrokeWidth: number = 2;

  aboutToAppear(): void {
    this.angleAnimator = Animator.create({
      duration: 2000,
      easing: 'linear',
      delay: 0,
      fill: 'none',
      direction: 'normal',
      iterations: -1,
      begin: 0,
      end: 360
    });

    this.angleAnimator.onFrame = (value: number) => {
      this.currentAngle = value;
      this.drawBorder();
    };
  }

  aboutToDisappear(): void {
    this.angleAnimator?.cancel();
    this.angleAnimator = undefined;
  }

  private shouldRender(): boolean {
    return !this.respectGlobalVisibility || (this.showAiInput && !this.basicMode);
  }

  private canEdit(): boolean {
    return this.inputEnabled && !this.isAiLoading;
  }

  private hasText(): boolean {
    return this.text.trim().length > 0;
  }

  private canTriggerAction(): boolean {
    return this.canEdit() && (!this.disableActionWhenEmpty || this.hasText());
  }

  private useImmersiveMaterial(): boolean {
    return canUseSystemMaterial();
  }

  private resolveSurfaceFallbackColor(): ResourceColor {
    return $r('sys.color.search_container_focus_color');
  }

  private resolveInnerBackgroundColor(): ResourceColor | Color {
    return this.useImmersiveMaterial() ? Color.Transparent : this.resolveSurfaceFallbackColor();
  }

  private async triggerAI(): Promise<void> {
    if (!this.inputEnabled || this.isAiLoading) {
      return;
    }

    if (!this.text.trim()) {
      Toast.show({ message: '请先输入内容再让 AI 识别' });
      return;
    }

    this.isAiLoading = true;
    this.angleAnimator?.play();
    try {
      await this.onAITriggered();
    } catch (e) {
      AppLog.error('Native', `[AITextInput] AI trigger failed: ${e}`);
      Toast.show({ message: 'AI 识别失败，请稍后重试' });
    } finally {
      this.isAiLoading = false;
      this.angleAnimator?.cancel();
      this.currentAngle = 0;
      this.drawBorder();
    }
  }

  private drawBorder(): void {
    const ctx = this.context;
    const w = this.canvasWidth;
    const h = this.canvasHeight;
    if (w <= 0 || h <= 0) {
      return;
    }

    const outerR = this.containerRadius;
    const inset = this.borderStrokeWidth / 2;
    const pathR = outerR - inset;

    ctx.clearRect(0, 0, w, h);

    let grad: CanvasGradient;
    if (this.isAiLoading) {
      const cx = w / 2;
      const cy = h / 2;
      const radius = Math.max(w, h) / 1.5;
      const rad = (this.currentAngle * Math.PI) / 180;
      const x1 = cx + radius * Math.cos(rad);
      const y1 = cy + radius * Math.sin(rad);
      const x2 = cx + radius * Math.cos(rad + Math.PI);
      const y2 = cy + radius * Math.sin(rad + Math.PI);

      grad = ctx.createLinearGradient(x1, y1, x2, y2);
      grad.addColorStop(0.0, this.gradientColors[0]);
      grad.addColorStop(0.5, this.gradientColors[1]);
      grad.addColorStop(1.0, this.gradientColors[2]);

      ctx.shadowBlur = 10;
      ctx.shadowColor = this.gradientColors[2];
    } else {
      grad = ctx.createLinearGradient(0, 0, w, h);
      grad.addColorStop(0.0, this.gradientColors[0]);
      grad.addColorStop(0.5, this.gradientColors[1]);
      grad.addColorStop(1.0, this.gradientColors[2]);

      ctx.shadowBlur = 0;
      ctx.shadowColor = 'transparent';
    }

    ctx.lineWidth = this.borderStrokeWidth;
    ctx.strokeStyle = grad;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';

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
    ctx.stroke();
  }

  @Builder
  private actionButton(isCompact: boolean) {
    if (this.showActionButton) {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph(this.isAiLoading ? $r('sys.symbol.arrow_clockwise') : this.idleIcon)
          .fontSize(isCompact ? 18 : 20)
          .effectStrategy(SymbolEffectStrategy.SCALE)
          .fontColor([$r('sys.color.ohos_id_color_text_primary')])
          .symbolEffect(new BounceSymbolEffect(EffectScope.WHOLE, EffectDirection.UP), this.isAiLoading)
      }
      .width(this.sendButtonSize)
      .height(this.sendButtonSize)
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .attributeModifier(MaterialPresets.buttonGlow(this.canTriggerAction()))
      .enabled(this.canTriggerAction())
      .onClick((): void => {
        void this.triggerAI();
      })
    }
  }

  @Builder
  private multilineInput() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Stack({ alignContent: Alignment.BottomEnd }) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(this.resolveInnerBackgroundColor())
            .borderRadius(this.containerRadius - 1)

          TextArea({ text: this.text, placeholder: this.placeholder })
            .width('100%')
            .height('100%')
            .backgroundColor(Color.Transparent)
            .borderRadius(this.containerRadius - 1)
            .padding({ top: 16, bottom: 16, left: 16, right: 56 })
            .enabled(this.canEdit())
            .onChange((value: string): void => {
              this.text = value;
            })

          Column() {
            this.actionButton(false)
          }
          .margin({ right: 10, bottom: 10 })
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .padding(1)

      Canvas(this.context)
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
        .onAreaChange((_, area) => {
          const width = area.width as number;
          const height = area.height as number;
          if (this.canvasWidth !== width || this.canvasHeight !== height) {
            this.canvasWidth = width;
            this.canvasHeight = height;
            this.drawBorder();
          }
        })
    }
    .width('100%')
    .height(this.inputHeight)
  }

  @Builder
  private compactInput() {
    Row({ space: 10 }) {
      TextInput({ text: $$this.text, placeholder: this.placeholder })
        .layoutWeight(1)
        .height('100%')
        .backgroundColor(Color.Transparent)
        .fontSize(15)
        .enabled(this.canEdit())
        .onSubmit((): void => {
          if (!this.canTriggerAction()) {
            return;
          }
          void this.triggerAI();
        })

      this.actionButton(true)
    }
    .width('100%')
    .height(this.inputHeight)
    .padding({ left: 14, right: 8 })
    .backgroundColor(this.resolveInnerBackgroundColor())
    .borderRadius(this.containerRadius)
  }

  build() {
    if (this.shouldRender()) {
      if (this.multiline) {
        this.multilineInput();
      } else {
        this.compactInput();
      }
    } else {
      Blank()
        .width(0)
        .height(0)
    }
  }
}
