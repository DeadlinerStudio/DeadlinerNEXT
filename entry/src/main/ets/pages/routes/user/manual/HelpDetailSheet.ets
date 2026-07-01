import { ManualDataManager, ManualItem } from "../../../../common/manual/ManualModel";
import { common } from "@kit.AbilityKit";
import { BrandPageHeader } from "../../../components/BrandPageHeader";
import { SettingsSection } from "../../../components/SettingsComponents";
import { MarkdownView } from "../../../components/MarkdownView";
import { ITheme } from "../../../../common/theme/ThemeModel";

@Component
export struct HelpDetailSheet {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @State item: ManualItem | null = null;
  @State markdownContent: string = '';
  @State title: string = '详情';

  @StorageLink('statusBarHeight') statusBarHeight: number = 38;
  readonly TITLE_BAR_CONTENT_HEIGHT: number = 18;

  aboutToAppear(): void {
    console.log('[ManualSheetDebug] ', this.item?.id)
    this.loadMarkdown();
  }

  async loadMarkdown() {
    if (this.item && this.item.fileName) {
      const context = getContext(this) as common.UIAbilityContext;
      this.markdownContent = await ManualDataManager.getInstance().loadContent(context, this.item.fileName);
    }
  }

  build() {
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