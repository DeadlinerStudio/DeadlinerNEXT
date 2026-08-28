import { AppLog } from '../../common/logging/AppLog';
import { MarkdownParser, MdNode, MdType } from '../../utils/markdown/MarkdownParser';
import { ManualDataManager, ManualItem } from '../../common/manual/ManualModel';
import { LinkParser, LinkSegment, LinkType } from '../../utils/markdown/LinkParser';
import { ITheme } from '../../common/theme/ThemeModel';
import { SettingsConstants as C } from '../../common/local/SettingsConstants';
import { APP_BREAKPOINT_DEFAULT, APP_BREAKPOINT_STORAGE_KEY, AppBreakpointUtils } from '../../common/layout/AppBreakpoints';

@Component
export struct MarkdownView {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @Consume('appPathStack') appPathStack: NavPathStack;
  @Consume('userLocalPathStack') userLocalPathStack: NavPathStack = new NavPathStack();
  @StorageLink(APP_BREAKPOINT_STORAGE_KEY) currentBreakpoint: string = APP_BREAKPOINT_DEFAULT;
  @StorageLink(C.KEY_ENABLE_TABLET_UI) tabletUi: boolean = true;

  @Prop content: string = '';
  @State nodes: MdNode[] = [];

  @Prop baseColor: string | ResourceColor = '';

  private pushRoute(pathInfo: NavPathInfo) {
    if (AppBreakpointUtils.usesSplitLayout(this.currentBreakpoint, this.tabletUi) && this.userLocalPathStack.size() > 0) {
      this.userLocalPathStack.pushPath(pathInfo);
      return;
    }
    this.appPathStack.pushPath(pathInfo);
  }

  aboutToAppear() {
    // 组件加载时进行解析
    this.nodes = MarkdownParser.parse(this.content);
  }

  @Builder
  UnifiedTextBuilder(text: string, fontSize: number, normalFontColor: ResourceColor) {
    Text() {
      ForEach(LinkParser.parse(text), (segment: LinkSegment) => {

        if (segment.type === LinkType.HELP_LINK || segment.type === LinkType.ROUTE_LINK) {
          Span(segment.text)
            .fontSize(fontSize)
            .fontWeight(FontWeight.Bold) // 粗体
            .fontColor(this.baseColor || this.theme.brand) // 主题色
            .decoration({ type: TextDecorationType.Underline, color: this.baseColor || this.theme.brand }) // 下划线
            .onClick(() => {
              if (segment.type === LinkType.HELP_LINK) {
                const targetId = segment.target;

                const realItem = ManualDataManager.getInstance().getItemById(targetId);

                if (realItem) {
                  this.pushRoute({
                    name: 'helpDetail',
                    param: realItem
                  });
                } else {
                  AppLog.warn('Native', `ManualItem with id '${targetId}' not found in menu.json`);

                  const tempItem: ManualItem = {
                    id: targetId,
                    title: segment.text,
                    fileName: `${targetId}.md`,
                    themeColor: '#808080',
                    icon: $r('sys.symbol.doc')
                  };
                  this.pushRoute({ name: 'helpDetail', param: tempItem });
                }

              } else {
                // 跳转普通路由
                this.pushRoute({ name: segment.target });
              }
            })
        }

        else {
          // 这里把原来的 RichTextBuilder 逻辑内联进来，输出 Span
          // 逻辑：先切 **，再切 *
          ForEach(segment.text.split('**'), (part: string, index: number) => {
            // 逻辑内联
            ForEach(part.split('*'), (subPart: string, subIndex: number) => {
              Span(subPart)
                .fontSize(fontSize)
                .fontColor((index % 2 === 1) ? (this.baseColor || normalFontColor) : normalFontColor)
                .fontWeight((index % 2 === 1) ? FontWeight.Bold : FontWeight.Regular)
                .fontStyle((subIndex % 2 === 1) ? FontStyle.Italic : FontStyle.Normal)
            })
          })
        }
      })
    }
    .lineHeight(fontSize * 1.6)
    .width('100%')
  }

  build() {
    Column({ space: 8 }) {
      ForEach(this.nodes, (node: MdNode) => {

        // 1. 一级标题 (# )
        if (node.type === MdType.HEADER1) {
          Text(node.content)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .margin({ top: 16, bottom: 8 })
            .width('100%')
        }

        // 2. 二级标题 (## )
        else if (node.type === MdType.HEADER2) {
          Text(node.content)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .margin({ top: 12, bottom: 4 })
            .width('100%')
        }

        else if (node.type === MdType.HEADER3) {
          Text(node.content)
            .fontSize(16) // 与正文大小一致或稍大
            .fontWeight(FontWeight.Bold) // 加粗以示区别
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .margin({ top: 8, bottom: 2 }) // 间距比 H2 再小一点
            .width('100%')
        }

        // 3. 列表项 (- )
        else if (node.type === MdType.LIST_ITEM) {
          Row({ space: 8 }) {
            if (node.level === 1) {
              // 二级列表图标：空心圆或稍微小一点
              Circle({ width: 4, height: 4 })
                .stroke($r('sys.color.ohos_id_color_text_secondary'))
                .strokeWidth(1)
                .fill(Color.Transparent)
                .margin({ top: 8 })
            } else {
              // 一级列表图标：实心圆
              Circle({ width: 4, height: 4 })
                .fill($r('sys.color.ohos_id_color_text_secondary'))
                .margin({ top: 8 })
            }

            // 列表内容 (支持加粗)
            this.UnifiedTextBuilder(node.content, 15, $r('sys.color.ohos_id_color_text_secondary'))
          }
          .alignItems(VerticalAlign.Center)
          .width('100%')
          .padding({ left: 8 + (node.level || 0) * 16 })
        }

        // 4. 普通段落
        else if (node.type === MdType.PARAGRAPH) {
          this.UnifiedTextBuilder(node.content, 15, $r('sys.color.ohos_id_color_text_primary'))
        }

        // 5. 空行 (用于调整间距)
        else if (node.type === MdType.SPACE) {
          Blank().height(4)
        }

        else if (node.type === MdType.IMAGE) {
          Column({ space: 4 }) {
            Image($rawfile(node.content))
              .width('100%')
              .constraintSize({ maxHeight: '280vp' })
              .borderRadius(20)
              .objectFit(ImageFit.Contain)
              .backgroundColor(this.theme.bgPrimary)

            if (node.alt) {
              Text(node.alt)
                .fontSize(12)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                .width('100%')
                .textAlign(TextAlign.Center)
            }
          }
          .margin({ top: 8, bottom: 8 })
        }

        else if (node.type === MdType.QUOTE) {
          Column() {
            this.UnifiedTextBuilder(node.content, 14, $r('sys.color.ohos_id_color_text_secondary'))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .backgroundColor($r('sys.color.ohos_id_color_hover'))
          .borderRadius(20)
          .border({
            width: { left: 4 },
            color: { left: this.baseColor || this.theme.brand50 },
            style: { left: BorderStyle.Solid }
          })
          .padding({ left: 12, top: 12, bottom: 12, right: 12 })
          .margin({ top: 4, bottom: 4 })
        }

        else if (node.type === MdType.DIVIDER) {
          Divider()
            .vertical(false)
            .strokeWidth(0.5)
            .color($r('sys.color.ohos_id_color_list_separator'))
            .margin({ top: 16, bottom: 16 })
            .width('100%')
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
