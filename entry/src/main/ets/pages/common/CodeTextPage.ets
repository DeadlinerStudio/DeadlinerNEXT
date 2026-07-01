import { LengthMetrics } from '@kit.ArkUI';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType, HdsNavDestinationAttribute } from '@kit.UIDesignKit';
import { TopSafeContainer } from '../components/TopSafeContainer';
import { util } from '@kit.ArkTS'; // 用于解码文本文件

export interface CodeTextParams {
  fileName: string; // rawfile 中的文件名，例如 "LICENSE.txt"
  title: string;    // 标题，例如 "开源许可证"
}

@Component
struct CodeTextPage {
  @State content: string = ''; // 存储读取到的文本内容
  @State title: string = '';

  pathStack: NavPathStack | null = null;

  @StorageLink('statusBarHeight') statusBarHeight: number = 38;
  readonly TITLE_BAR_CONTENT_HEIGHT: number = 18;

  // 读取 RawFile 文件内容
  private async loadRawFile(fileName: string) {
    try {
      // 1. 获取 ResourceManager
      const resourceManager = getContext(this).resourceManager;

      // 2. 读取文件为 Uint8Array
      const fileData = await resourceManager.getRawFileContent(fileName);

      // 3. 解码为字符串 (处理中文乱码风险)
      const textDecoder = new util.TextDecoder('utf-8', { ignoreBOM: true });
      this.content = textDecoder.decodeWithStream(fileData);

    } catch (error) {
      console.error(`[CodeTextPage] Failed to load file: ${fileName}`, error);
      this.content = "无法加载文件内容。";
    }
  }

  build() {
    HdsNavDestination() {
      TopSafeContainer({ topAvoidHeight: this.statusBarHeight + this.TITLE_BAR_CONTENT_HEIGHT }) {
        Text(this.content)
          .fontFamily('Monospace')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .lineHeight(24) // 增加行高，提升阅读体验
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 40 })
          .copyOption(CopyOptions.LocalDevice)
      }
    }
    .titleBar({
      avoidLayoutSafeArea: true,
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.COMMON_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(10)
        },
        originalStyle: {
          backgroundStyle: {
            backgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
          },
        },
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor: $r('sys.color.ohos_id_color_navigation_background_blur'),
          },
        },
      },
      content: {
        title: {
          mainTitle: this.title
        },
      },
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .onReady((context) => {
      this.pathStack = context.pathStack;
      const params = context.pathInfo.param as CodeTextParams;
      if (params) {
        this.title = params.title;
        // 异步加载文件内容
        this.loadRawFile(params.fileName);
      }
    })
  }
}

// 路由 Builder
@Builder
export function CodeTextPageBuilder() {
  CodeTextPage()
}
