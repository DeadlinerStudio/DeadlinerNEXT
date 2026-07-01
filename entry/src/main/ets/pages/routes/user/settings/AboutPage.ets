import { HdsNavDestination, HdsNavDestinationAttribute } from "@kit.UIDesignKit";
import { LocalValues } from "../../../../common/local/LocalValues";
import { HuaweiAccountUtils } from "../../../../utils/account/HuaweiAccountUtils";
import { SettingsDivider, SettingsItem, SettingsSection } from "../../../components/SettingsComponents";
import { common, bundleManager, Want } from "@kit.AbilityKit";
import { TopSafeContainer } from "../../../components/TopSafeContainer";
import { CodeTextParams } from "../../../common/CodeTextPage";
import { WebParams } from "../../../common/WebBrowserPage";
import { getImmersiveTitleBarStyle } from "../../../../common/style/NavStyles";
import { MarkdownView } from "../../../components/MarkdownView";
import { LETTER_CONTENT } from "./LetterPage";
import { ITheme } from "../../../../common/theme/ThemeModel";

@Builder
export function AboutPageBuilder() {
  AboutPage()
}

@Component
export struct AboutPage {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @StorageLink('isWideScreen') isWideScreen: boolean = false;
  @Consume('appPathStack') appPathStack: NavPathStack;

  @StorageLink('statusBarHeight') statusBarHeight: number = 38;
  @StorageLink('topAvoidExtraHeight') topAvoidExtraHeight: number = 0;
  readonly TITLE_BAR_CONTENT_HEIGHT: number = 18;

  private context = getContext(this) as common.UIAbilityContext;

  @State versionName: string = '';
  @State versionCode: string = '';
  aboutToAppear(): void {
    try {
      let bundleInfo = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      this.versionName = bundleInfo.versionName;
      this.versionCode = bundleInfo.versionCode.toString()
    } catch (error) {
      console.error('获取版本号失败:', JSON.stringify(error));
      this.versionName = '1.0.0';
    }
  }

  private showRevokeDialog() {
    AlertDialog.show({
      title: '撤回隐私协议',
      message: '撤回协议后，应用将无法继续为您提供服务，并会自动退出账号，清除您的 WebDAV 与 AI API Key 设置。下次启动应用时，您需要重新同意协议。\n\n确定要撤回吗？',
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      offset: { dx: 0, dy: -20 },
      primaryButton: {
        value: '取消',
        action: () => {
        },
        fontColor: this.theme.brand
      },
      secondaryButton: {
        value: '确定撤回',
        fontColor: $r('app.color.warning'),
        action: async () => {
          await LocalValues.getInstance().revokePrivacy();
          await LocalValues.getInstance().clearAllAdvancedSettings();
          (new HuaweiAccountUtils()).signOut();
          this.context.terminateSelf();
        }
      },
      backgroundBlurStyle: BlurStyle.Regular
    })
  }

  private privacyUrl: string = 'resource://rawfile/privacy_agreement.html';

  private showPrivacyWebPage() {
    const params: WebParams = {
      url: this.privacyUrl,
      title: '隐私协议',
    };

    this.appPathStack.pushPath({
      name: 'webBrowser',
      param: params,
    });
  }

  private openWeb(title: string, url: string) {
    let want: Want = {
      action: 'ohos.want.action.viewData', // 意图：查看数据
      entities: ['entity.system.browsable'], // 实体：可浏览的（通常指浏览器）
      uri: url
    };

    this.context.startAbility(want).catch((err: object) => {
      console.error("Open System Browser failed", JSON.stringify(err));
    });
  }

  @State isLetterSheetShow: boolean = false;
  @Builder
  letterSheet() {
    Column() {
      MarkdownView({
        content: LETTER_CONTENT,
        baseColor: this.theme.brand
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  build() {
    HdsNavDestination() {
      TopSafeContainer({ topAvoidHeight: this.statusBarHeight + this.TITLE_BAR_CONTENT_HEIGHT + this.topAvoidExtraHeight }) {
        Column({ space: 16 }) {
          Column({ space: 8 }) {
            Image($r('app.media.icon'))
              .width(80)
              .height(80)
              .borderRadius(16)
            Text('Deadliner待办日历')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
            Text(`版本 ${this.versionName} (${this.versionCode})`)
              .fontSize(14)
              .fontColor($r('sys.color.font_secondary'))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 32, bottom: 16 })

          SettingsSection({
            title: "开发者的碎碎念"
          }) {
            SettingsItem({
              title: "致用户的一封信",
              subtitle: "开发背后的故事与初衷",
              icon: $r('sys.symbol.envelope'),
              onItemClick: () => {
                if (this.isWideScreen) this.isLetterSheetShow = true;
                else this.appPathStack.pushPath({ name: 'letterPage' }); }
            })

            SettingsDivider()

            SettingsItem({
              title: "访问官网",
              subtitle: "了解 Deadliner待办日历 的其他平台",
              icon: $r('sys.symbol.discover'),
              onItemClick: () => { this.openWeb('', 'https://aritxonly.top/deadliner') }
            })
          }

          SettingsSection({
            title: "隐私协议与许可"
          }) {
            SettingsItem({
              title: "开源许可证",
              subtitle: "了解 Deadliner 使用的 GPL-3.0 开源协议",
              icon: $r('sys.symbol.doc_text'),
              onItemClick: () => {
                const params: CodeTextParams = {
                  fileName: 'LICENSE.txt',
                  title: '开源许可证'
                };

                this.appPathStack.pushPath({
                  name: 'codeText',
                  param: params
                });
              }
            })

            SettingsDivider()

            SettingsItem({
              title: "查看隐私协议",
              subtitle: "浏览隐私协议的详细内容",
              icon: $r('sys.symbol.person_shield_fill'),
              onItemClick: () => {
                this.showPrivacyWebPage();
              }
            })

            SettingsDivider()

            SettingsItem({
              title: "撤回隐私协议",
              subtitle: "撤回同意并退出应用",
              icon: $r('sys.symbol.lock_shield'), // [新增] 撤回盾牌图标
              onItemClick: () => {
                this.showRevokeDialog(); // 触发弹窗
              }
            })
          }

          Text('Designed & Developed by AritxOnly\nCopyright © 2026. All rights reserved.\nLicensed under GPL-3.0-or-later. No warranty.')
            .fontSize(12)
            .fontColor($r('sys.color.font_tertiary'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 20 })

          // 底部留白
          Blank().height(50)
        }
        .width('100%')
        .padding({ left: 12, right: 12 })
        .justifyContent(FlexAlign.Start)
        .constraintSize({ minHeight: '100%' })
      }
    }
    .titleBar({
      avoidLayoutSafeArea: this.isWideScreen,
      style: getImmersiveTitleBarStyle(this.isWideScreen),
      content: { title: { mainTitle: "关于与协议" } }
    })
    .bindSheet($$this.isLetterSheetShow, this.letterSheet(), {
      title: { title: '开发者说' },
      blurStyle: BlurStyle.Regular,
      backgroundColor: Color.Transparent,
      height: SheetSize.LARGE
    })
  }
}
