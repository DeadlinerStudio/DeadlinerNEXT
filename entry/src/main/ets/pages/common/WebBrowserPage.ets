import { AppLog } from '../../common/logging/AppLog';
import { webview } from '@kit.ArkWeb';
import { LengthMetrics, router } from '@kit.ArkUI';
import { HdsNavDestination, HdsNavDestinationTitleMode, HdsNavDestinationAttribute,
  ScrollEffectType } from '@kit.UIDesignKit';
import { TopSafeContainer } from '../components/TopSafeContainer';
import { getImmersiveTitleBarStyle } from '../../common/style/NavStyles';

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

  @StorageLink('isWideScreen') isWideScreen: boolean = false;

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
      avoidLayoutSafeArea: this.isWideScreen,
      style: getImmersiveTitleBarStyle(this.isWideScreen),
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
        AppLog.info('Native', '[WebBrowserPage] Closing, trigger callback.');
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
