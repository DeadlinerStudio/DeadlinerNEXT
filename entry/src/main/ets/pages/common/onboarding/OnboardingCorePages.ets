import lottie, { AnimationItem } from '@ohos/lottie';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { ITheme } from '../../../common/theme/ThemeModel';
import { LottieSceneMeta, PANEL_BG } from './OnboardingTypes';
import { deviceInfo } from '@kit.BasicServicesKit';

@Component
export struct GuideContainer {
  @BuilderParam content: () => void;

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .height('100%')
    .padding(8)
    .borderRadius(24)
  }
}

@Component
export struct IntroHeroPage {
  icon: Resource = $r('sys.symbol.star_slash');
  isImage: boolean = false;
  title: string = '';
  subtitle: string = '';
  @Prop @Watch('onActiveChanged') isActive: boolean = false;

  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  @State private visible: boolean = false;

  aboutToAppear(): void {
    if (this.isActive) {
      this.triggerAnimation();
    }
  }

  onActiveChanged(): void {
    if (this.isActive) {
      this.triggerAnimation();
    } else {
      this.visible = false;
    }
  }

  private triggerAnimation(): void {
    this.visible = false;
    setTimeout(() => {
      animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
        this.visible = true;
      });
    }, 50);
  }

  build() {
    GuideContainer() {
      Column() {
        Column() {
          if (this.isImage) {
            Image(this.icon)
              .width(86)
              .height(86)
              .opacity(this.visible ? 1 : 0)
              .scale({ x: this.visible ? 1 : 0.8, y: this.visible ? 1 : 0.8 })
              .animation({ duration: 400, curve: Curve.EaseOut })
          } else {
            SymbolGlyph(this.icon)
              .fontSize(72)
              .fontColor([this.theme.tabIcon])
              .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY)
              .opacity(this.visible ? 1 : 0)
              .scale({ x: this.visible ? 1 : 0.8, y: this.visible ? 1 : 0.8 })
              .animation({ duration: 400, curve: Curve.EaseOut })
          }
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)

        Column({ space: 18 }) {
          Text(this.title)
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .textAlign(TextAlign.Center)
            .opacity(this.visible ? 1 : 0)
            .translate({ y: this.visible ? 0 : 20 })
            .animation({ duration: 450, curve: Curve.EaseOut, delay: 100 })

          Text(this.subtitle)
            .fontSize(15)
            .lineHeight(24)
            .fontColor($r('app.color.font_secondary'))
            .textAlign(TextAlign.Center)
            .opacity(this.visible ? 1 : 0)
            .translate({ y: this.visible ? 0 : 20 })
            .animation({ duration: 500, curve: Curve.EaseOut, delay: 150 })
        }
        .width('100%')
        .padding({ left: 10, right: 10, bottom: 32 })
      }
      .width('100%')
      .height('100%')
    }
  }
}

@Component
export struct PrivacyAgreementPage {
  onJumpToWeb: () => void = () => {};
  @Link accepted: boolean;
  @Prop @Watch('onActiveChanged') isActive: boolean = false;

  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  @State private visible: boolean = false;

  aboutToAppear(): void {
    if (this.isActive) {
      this.triggerAnimation();
    }
  }

  onActiveChanged(): void {
    if (this.isActive) {
      this.triggerAnimation();
    } else {
      this.visible = false;
    }
  }

  private triggerAnimation(): void {
    this.visible = false;
    setTimeout(() => {
      animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
        this.visible = true;
      });
    }, 50);
  }

  build() {
    GuideContainer() {
      Column() {
        Column() {
          SymbolGlyph($r('sys.symbol.security_shield'))
            .fontSize(64)
            .fontColor([this.theme.tabIcon])
            .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY)
            .opacity(this.visible ? 1 : 0)
            .scale({ x: this.visible ? 1 : 0.8, y: this.visible ? 1 : 0.8 })
            .animation({ duration: 400, curve: Curve.EaseOut })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)

        Column({ space: 16 }) {
          Text('服务协议与隐私政策')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .textAlign(TextAlign.Center)
            .opacity(this.visible ? 1 : 0)
            .translate({ y: this.visible ? 0 : 20 })
            .animation({ duration: 450, curve: Curve.EaseOut, delay: 50 })

          Text() {
            Span('在使用本应用前，请您务必认真阅读并充分理解 ')
              .fontColor($r('app.color.font_primary'))
            Span('《隐私协议》')
              .fontColor(this.theme.tabIcon)
              .fontWeight(FontWeight.Medium)
              .onClick(() => this.onJumpToWeb())
            Span('。')
              .fontColor($r('app.color.font_primary'))
          }
          .fontSize(15)
          .lineHeight(24)
          .textAlign(TextAlign.Center)
          .opacity(this.visible ? 1 : 0)
          .translate({ y: this.visible ? 0 : 20 })
          .animation({ duration: 550, curve: Curve.EaseOut, delay: 150 })

          Row() {
            Checkbox({ name: 'privacy_checkbox' })
              .select(this.accepted)
              .selectedColor(this.theme.tabIcon)
              .width(20)
              .height(20)
              .margin({ right: 8 })
              .onChange((value: boolean) => {
                this.accepted = value;
              })

            Text('我已阅读并同意隐私协议条款')
              .fontSize(14)
              .fontColor($r('app.color.font_primary'))
              .onClick(() => {
                this.accepted = !this.accepted;
              })
          }
          .justifyContent(FlexAlign.Center)
          .width('100%')
          .margin({ top: 8 })
          .opacity(this.visible ? 1 : 0)
          .animation({ duration: 600, curve: Curve.EaseOut, delay: 200 })

          Text('点击底部“下一步”继续。')
            .fontSize(12)
            .fontColor($r('app.color.font_secondary'))
            .opacity(this.visible ? 1 : 0)
            .animation({ duration: 650, curve: Curve.EaseOut, delay: 250 })
        }
        .width('100%')
        .padding({ left: 8, right: 8, bottom: 32 })
      }
      .width('100%')
      .height('100%')
    }
  }
}

@Component
export struct LottieScenePage {
  @Prop scene: LottieSceneMeta;
  @Prop @Watch('onActiveChanged') isActive: boolean = false;
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @State private animationData: Object | null = null;
  @State private isCanvasReady: boolean = false;
  @State private hasLoadFailed: boolean = false;

  private readonly renderingSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private readonly canvasRenderingContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.renderingSettings);
  private readonly context = getContext(this) as common.UIAbilityContext;
  private readonly textDecoder: util.TextDecoder = new util.TextDecoder('utf-8', { ignoreBOM: true });
  private animationItem: AnimationItem | null = null;
  private removeDomLoadedListener?: () => void;

  aboutToAppear(): void {
    void this.loadSceneData();
  }

  aboutToDisappear(): void {
    this.destroyAnimation();
  }

  onActiveChanged(): void {
    if (this.isActive) {
      this.animationItem?.play();
    } else {
      this.animationItem?.pause();
    }
  }

  private async loadSceneData(): Promise<void> {
    if (this.animationData !== null || this.hasLoadFailed) {
      this.tryLoadAnimation();
      return;
    }

    try {
      const fileData = await this.context.resourceManager.getRawFileContent(`lottie/${this.scene.fileName}`);
      const jsonBytes: Uint8Array = new Uint8Array(fileData);
      const jsonString: string = this.textDecoder.decodeWithStream(jsonBytes);
      this.animationData = JSON.parse(jsonString) as Object;
      this.tryLoadAnimation();
    } catch (error) {
      this.hasLoadFailed = true;
      console.error(`[LottieScenePage] Failed to load ${this.scene.fileName}`, error);
    }
  }

  private handleCanvasReady(): void {
    this.canvasRenderingContext.imageSmoothingEnabled = true;
    this.canvasRenderingContext.imageSmoothingQuality = 'medium';
    this.isCanvasReady = true;
    this.tryLoadAnimation();
  }

  private tryLoadAnimation(): void {
    if (!this.isCanvasReady || this.animationData === null || this.animationItem !== null) {
      return;
    }

    lottie.destroy(this.scene.id);
    this.animationItem = lottie.loadAnimation({
      container: this.canvasRenderingContext,
      renderer: 'canvas',
      loop: true,
      autoplay: false,
      name: this.scene.id,
      context: this.context,
      contentMode: 'Contain',
      animationData: this.animationData
    });

    this.removeDomLoadedListener = this.animationItem.addEventListener('DOMLoaded', () => {
      this.animationItem?.resize();
      if (this.isActive) {
        this.animationItem?.play();
      } else {
        this.animationItem?.pause();
      }
    });
  }

  private destroyAnimation(): void {
    this.removeDomLoadedListener?.();
    this.removeDomLoadedListener = undefined;
    lottie.destroy(this.scene.id);
    this.animationItem = null;
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Canvas(this.canvasRenderingContext)
          .width('100%')
          .height('75%')
          .onReady(() => {
            this.handleCanvasReady();
          })

        if (this.hasLoadFailed) {
          Text('动画资源加载失败')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#7A3E3E')
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })
            .backgroundColor('#FFF2F2')
            .borderRadius(999)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .borderRadius(28)
      .clip(true)

      Column({ space: 8 }) {
        Text(this.scene.title)
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .textAlign(TextAlign.Center)
          .opacity(this.isActive ? 1 : 0)
          .translate({ y: this.isActive ? 0 : 20 })
          .animation({ duration: 450, curve: Curve.EaseOut, delay: 100 })

        if (deviceInfo.sdkApiVersion >= 22) {
          Text(this.scene.subtitle)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.tabIcon)
            .textAlign(TextAlign.Center)
            .minLines(2)
            .opacity(this.isActive ? 1 : 0)
            .translate({ y: this.isActive ? 0 : 20 })
            .animation({ duration: 500, curve: Curve.EaseOut, delay: 150 })
        } else {
          Text(this.scene.subtitle)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.tabIcon)
            .textAlign(TextAlign.Center)
            .opacity(this.isActive ? 1 : 0)
            .translate({ y: this.isActive ? 0 : 20 })
            .animation({ duration: 500, curve: Curve.EaseOut, delay: 150 })
        }

        Text(this.scene.detail)
          .fontSize(14)
          .lineHeight(22)
          .fontColor($r('app.color.font_secondary'))
          .textAlign(TextAlign.Center)
          .opacity(this.isActive ? 1 : 0)
          .translate({ y: this.isActive ? 0 : 20 })
          .animation({ duration: 550, curve: Curve.EaseOut, delay: 200 })
      }
      .width('100%')
      .padding({ left: 8, right: 8, bottom: 32 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, top: 8, bottom: 8 })
  }
}
