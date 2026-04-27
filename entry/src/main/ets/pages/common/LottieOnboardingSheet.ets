import lottie, { AnimationItem } from '@ohos/lottie';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { ITheme } from '../../common/theme/ThemeModel';

interface LottieSceneMeta {
  id: string;
  fileName: string;
  title: string;
  subtitle: string;
  detail: string;
}

const LOTTIE_SCENES: LottieSceneMeta[] = [
  {
    id: 'guide_scene_1',
    fileName: 'Scene-1-Harmony.json',
    title: '滑动任务，快捷处理',
    subtitle: '在任务卡片上左右滑动，就能快速完成常用操作。',
    detail: '像完成、归档这类高频动作，不必点进详情页，在列表里就能顺手处理。'
  },
  {
    id: 'guide_scene_2',
    fileName: 'Scene-2-Harmony.json',
    title: '点一下 Lifi AI，唤起智能体',
    subtitle: '遇到临时想法、碎片信息或模糊需求，都可以先交给它整理。',
    detail: 'Lifi AI 能帮你提炼任务意图、补齐结构，再决定是否加入清单。'
  },
  {
    id: 'guide_scene_4',
    fileName: 'Scene-4-Harmony.json',
    title: '长按任务，进入多选',
    subtitle: '想批量完成、归档或删除时，长按任意任务即可开始选择。',
    detail: '连续处理一组任务会更高效，适合做每日清单收尾或集中整理。'
  },
  {
    id: 'guide_scene_5',
    fileName: 'Scene-5-Harmony.json',
    title: '轻点任务，查看详情与子任务',
    subtitle: '短按任务可以进入详情页，继续补充信息或拆分子任务。',
    detail: '当一件事需要更多上下文时，详情页就是你继续展开和整理的地方。'
  },
  {
    id: 'guide_scene_6',
    fileName: 'Scene-6-Harmony.json',
    title: '点击 Tab 顶部按钮，快速导航',
    subtitle: '每个 Tab 上方的按钮都可以带你进入对应功能入口。',
    detail: '把常用入口放在手边，切页之外也能更快抵达你要用的能力。'
  }
];

@Component
struct LottieSceneCard {
  @Prop scene: LottieSceneMeta;
  @Prop @Watch('onActiveChanged') isActive: boolean;
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @State private animationData: Object | null = null;
  @State private isCanvasReady: boolean = false;
  @State private hasLoadFailed: boolean = false;

  private readonly renderingSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private readonly canvasRenderingContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.renderingSettings);
  private readonly context = getContext(this) as common.UIAbilityContext;
  private readonly textDecoder = new util.TextDecoder('utf-8', { ignoreBOM: true });

  private animationItem: AnimationItem | null = null;
  private removeDomLoadedListener?: () => void;

  aboutToAppear(): void {
    this.loadSceneData();
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
      const jsonString = this.textDecoder.decodeWithStream(fileData);
      this.animationData = JSON.parse(jsonString) as Object;
      this.tryLoadAnimation();
    } catch (error) {
      this.hasLoadFailed = true;
      console.error(`[LottieSceneCard] Failed to load ${this.scene.fileName}`, error);
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
    Column({ space: 16 }) {
      Stack({ alignContent: Alignment.Center }) {
        // Column()
        //   .width('100%')
        //   .height('100%')
        //   .borderRadius(28)
        //   .backgroundColor($r('sys.color.search_container_focus_color'))

        Canvas(this.canvasRenderingContext)
          .width('100%')
          .height('100%')
          .onReady(() => {
            this.handleCanvasReady();
          })

        if (this.hasLoadFailed) {
          Text('动画资源加载失败')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.warning'))
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })
            .borderRadius(999)
        }
      }
      .width('100%')
      .height(320)
      .borderRadius(28)
      .clip(true)

      Column({ space: 8 }) {
        Text(this.scene.title)
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .textAlign(TextAlign.Center)

        Text(this.scene.subtitle)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.tabIcon)
          .textAlign(TextAlign.Center)

        Text(this.scene.detail)
          .fontSize(14)
          .lineHeight(22)
          .fontColor($r('app.color.font_secondary'))
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding({ left: 8, right: 8 })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 8, bottom: 8 })
  }
}

@Component
export struct LottieOnboardingSheet {
  onClose: () => void = () => {};

  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  @State private currentIndex: number = 0;

  private readonly sceneList: LottieSceneMeta[] = LOTTIE_SCENES;

  private goPrev(): void {
    if (this.currentIndex > 0) {
      this.currentIndex -= 1;
    }
  }

  private goNext(): void {
    if (this.currentIndex < this.sceneList.length - 1) {
      this.currentIndex += 1;
      return;
    }

    this.onClose();
  }

  build() {
    Column({ space: 20 }) {
      Column({ space: 8 }) {
        Row() {
          Text('功能引导')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))

          Blank()

          Button('跳过')
            .type(ButtonType.Normal)
            .fontSize(14)
            .fontColor(this.theme.tabIcon)
            .backgroundColor('#EEF4FF')
            .borderRadius(999)
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .onClick(() => this.onClose())
        }
        .width('100%')

        Text('快速看一遍 Deadliner 里最常用的几个操作。')
          .fontSize(14)
          .lineHeight(22)
          .fontColor($r('app.color.font_secondary'))
      }
      .width('100%')

      Swiper() {
        ForEach(this.sceneList, (scene: LottieSceneMeta, index: number) => {
          LottieSceneCard({
            scene,
            isActive: this.currentIndex === index
          })
        }, (scene: LottieSceneMeta) => scene.id)
      }
      .index(this.currentIndex)
      .indicator(false)
      .itemSpace(0)
      .cachedCount(1)
      .curve(Curve.EaseInOut)
      .loop(false)
      .onChange((index: number) => {
        this.currentIndex = index;
      })
      .width('100%')
      .layoutWeight(1)

      Row({ space: 10 }) {
        ForEach(this.sceneList, (_scene: LottieSceneMeta, index: number) => {
          Row()
            .width(this.currentIndex === index ? 28 : 8)
            .height(8)
            .borderRadius(999)
            .backgroundColor(this.currentIndex === index ? this.theme.tabIcon : '#D6DCE8')
            .animation({ duration: 200, curve: Curve.EaseInOut })
        })
      }

      Row({ space: 12 }) {
        Button('上一页')
          .type(ButtonType.Normal)
          .layoutWeight(1)
          .height(48)
          .enabled(this.currentIndex > 0)
          .fontSize(16)
          .backgroundColor($r('sys.color.search_container_focus_color'))
          .fontColor($r('app.color.font_secondary'))
          .borderRadius(24)
          .onClick(() => this.goPrev())

        Button(this.currentIndex === this.sceneList.length - 1 ? '开始体验' : '下一页')
          .layoutWeight(1)
          .height(48)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .backgroundColor(this.theme.tabIcon)
          .fontColor(Color.White)
          .borderRadius(24)
          .onClick(() => this.goNext())
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 18, bottom: 20 })
  }
}
