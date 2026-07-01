import { webview } from '@kit.ArkWeb';
import { LengthMetrics, router } from '@kit.ArkUI';
import { HdsNavDestination, HdsNavDestinationTitleMode, HdsNavDestinationAttribute,
  ScrollEffectType } from '@kit.UIDesignKit';
import { TopSafeContainer } from '../components/TopSafeContainer';

export interface WebParams {
  url: string;
  title: string;
  onClose?: () => void;
}

@Component
struct WebBrowserPage {
  controller: webview.WebviewController = new webview.WebviewController();
  @State targetUrl: string = '';
  @State title: string = '';

  pathStack: NavPathStack | null = null;

  private onCloseCallback?: () => void;


  @StorageLink('statusBarHeight') statusBarHeight: number = 38;

  readonly TITLE_BAR_CONTENT_HEIGHT: number = 18;

  build() {
    HdsNavDestination() {
      TopSafeContainer({ topAvoidHeight: this.statusBarHeight + this.TITLE_BAR_CONTENT_HEIGHT }) {
        Web({ src: this.targetUrl, controller: this.controller })
          .domStorageAccess(true)
          .darkMode(WebDarkMode.Auto)
          .width('100%')
          .layoutWeight(1)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
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
        // --- 初始状态样式 (透明) ---
        originalStyle: {
          backgroundStyle: {
            backgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
          },
        },
        // --- 滚动生效后样式 (模糊) ---
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

      // 获取传递的参数
      const params = context.pathInfo.param as WebParams;
      if (params) {
        this.targetUrl = params.url;
        this.title = params.title;
        this.onCloseCallback = params.onClose;
      }
    })
    .onBackPressed(() => {
      if (this.controller.accessBackward()) {
        this.controller.backward();
        return true; // 返回 true，表示“我已消费该事件”，系统不会关闭页面
      }

      if (this.onCloseCallback) {
        console.info('[WebBrowserPage] Closing, trigger callback.');
        this.onCloseCallback();
      }

      return false;
    })
  }
}

@Builder
export function WebBrowserPageBuilder() {
  WebBrowserPage()
}
