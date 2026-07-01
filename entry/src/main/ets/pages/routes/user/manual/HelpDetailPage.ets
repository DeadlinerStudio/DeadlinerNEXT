import { HdsNavDestination, ScrollEffectType, HdsNavDestinationAttribute } from '@kit.UIDesignKit';
import { TopSafeContainer } from '../../../components/TopSafeContainer';
import { ManualDataManager, ManualItem } from '../../../../common/manual/ManualModel';
import { LengthMetrics } from '@kit.ArkUI';
import { MarkdownView } from '../../../components/MarkdownView';
import { common } from '@kit.AbilityKit';
import { BrandPageHeader } from '../../../components/BrandPageHeader';
import { SettingsSection } from '../../../components/SettingsComponents';
import { ITheme } from '../../../../common/theme/ThemeModel';
import { getImmersiveTitleBarStyle } from '../../../../common/style/NavStyles';

@Component
export struct HelpDetailPage {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  // 接收上一个页面传来的数据
  @State item: ManualItem | null = null;
  @State markdownContent: string = '';
  @State title: string = '详情';

  @StorageLink('statusBarHeight') statusBarHeight: number = 38;
  readonly TITLE_BAR_CONTENT_HEIGHT: number = 18;

  async loadMarkdown() {
    if (this.item && this.item.fileName) {
      const context = getContext(this) as common.UIAbilityContext;
      this.markdownContent = await ManualDataManager.getInstance().loadContent(context, this.item.fileName);
    }
  }

  build() {
    HdsNavDestination() {
      TopSafeContainer({ topAvoidHeight: this.statusBarHeight + this.TITLE_BAR_CONTENT_HEIGHT }) {
          Column({ space: 16 }) {
            if (this.item) {
              BrandPageHeader({
                title: this.item.title,
                subtitle: this.item.subtitle,
                icon: this.item.icon ?? $r('sys.symbol.doc_text'),
                isImage: this.item.isImage,
                baseColor: this.item.themeColor,
              })
            }

            SettingsSection() {
              // 内容区域
              Column() {
                if (this.markdownContent) {
                  MarkdownView({ content: this.markdownContent, baseColor: this.item?.themeColor })
                } else {
                  // 加载中占位
                  Row() {
                    LoadingProgress().width(32).height(32).color(this.theme.brand)
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.Center)
                  .padding(32)
                }
              }
              .margin(8)
            }

            Blank().height(50)
          }
          .padding(16)
          .constraintSize({ minHeight: '100%' })
          .align(Alignment.TopStart)
          .width('100%')
      }
    }
    .titleBar({
      avoidLayoutSafeArea: true,
      content: { title: { mainTitle: this.title } },
      style: getImmersiveTitleBarStyle(false),
    })
    .onReady((ctx) => {
      this.item = ctx.pathInfo.param as ManualItem;
      if (this.item) this.title = this.item.title;
      this.loadMarkdown();
    })
  }
}

@Builder
export function HelpDetailPageBuilder() {
  HelpDetailPage()
}
