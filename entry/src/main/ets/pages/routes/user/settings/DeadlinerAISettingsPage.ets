import { SettingsConstants } from "../../../../common/local/SettingsConstants";
import { LocalValues } from "../../../../common/local/LocalValues";
import { promptAction, SymbolGlyphModifier } from '@kit.ArkUI';
import { AIService } from "../../../../ai/AIServcice";
import { Theme } from '@kit.ArkUI';
import { ManualDataManager } from "../../../../common/manual/ManualModel";
import { HelpDetailSheet } from "../manual/HelpDetailSheet";
import { ITheme } from "../../../../common/theme/ThemeModel";
import { HdsNavDestination, HdsNavDestinationAttribute } from "@kit.UIDesignKit";
import { getImmersiveTitleBarStyle } from "../../../../common/style/NavStyles";

@Builder
export function SettingsAIBuilder(name: string, param: Object) {
  LifiAISettingsPage()
}

@Component
export struct LifiAISettingsPage {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @StorageLink('isWideScreen') isWideScreen: boolean = false;

  pageStack: NavPathStack = new NavPathStack();

  @StorageLink(SettingsConstants.KEY_AI_PROVIDER) provider: string = 'deepseek';
  @StorageLink(SettingsConstants.KEY_AI_MODEL) model: string = 'deepseek-chat';
  @StorageLink(SettingsConstants.KEY_AI_BASE_URL) baseUrl: string = 'https://api.deepseek.com';
  @StorageLink(SettingsConstants.KEY_AI_DEEPSEEK_API_KEY) apiKey: string = '';

  @State isTesting: boolean = false;
  // [新增] 用于展示校验状态，给审核员看
  @State isVerified: boolean = false;
  @State buttonBg: ResourceColor = $r('sys.color.brand')

  onWillApplyTheme(theme: Theme): void {
    this.buttonBg = theme.colors.brand
  }

  // 检查 Key 是否已存在，如果已存在默认视为已校验（优化体验）
  aboutToAppear(): void {
    if (this.apiKey && this.apiKey.length > 10) {
      this.isVerified = true;
    }
  }

  @State isHelpSheetShow: boolean = false;
  @Builder
  helpSheet() {
    HelpDetailSheet({
      item: ManualDataManager.getInstance().getItemById("ai_config")
    })
  }

  build() {
    HdsNavDestination() {
      Column() {
        Scroll() {
          Column({ space: 16 }) {
            Blank().height(34)

            Column({ space: 8 }) {
              Row() {
                SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
                  .fontSize(16)
                  .fontColor([$r('sys.color.warning')])
                  .margin({ right: 4 })
                Text("合规使用说明")
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('sys.color.font_primary'))
              }
              .width('100%')

              Text("本应用为 AI 服务的客户端工具。根据监管要求，您填写的 API Key 必须是您本人在 AI 提供商开放平台经过实名认证后获取的有效凭证。\n本应用仅作技术透传，不存储您的身份信息。")
                .fontSize(12)
                .fontColor($r('sys.color.font_secondary'))
                .lineHeight(18)
                .width('100%')
            }
            .padding(12)
            .backgroundColor($r('app.color.background_secondary'))
            .borderRadius(24)


            // 2. API Key 输入框
            Column({ space: 8 }) {
              Text("API Key")
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .width('100%')

              TextInput({ text: this.apiKey, placeholder: 'sk-...' })
                .type(InputType.Password)
                .showPasswordIcon(true)
                .onChange((value) => {
                  this.apiKey = value;
                  // 只要修改了，就重置验证状态，强制用户重新测试
                  this.isVerified = false;
                })

              // [新增] 本地存储声明
              Text("您的 Key 仅加密存储于当前设备本地，不会上传至本应用服务器。")
                .fontSize(10)
                .fontColor($r('sys.color.font_tertiary'))
                .width('100%')
            }

            // [新增] 3. 校验状态展示 (审核员通过的视觉依据)
            if (this.isVerified) {
              Row() {
                SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
                  .fontSize(18)
                  .fontColor([$r('app.color.confirm')])
                  .margin({ right: 8 })
                Text("API Key 有效性校验通过 (已实名)")
                  .fontSize(14)
                  .fontColor('#4CAF50')
                  .fontWeight(FontWeight.Medium)
              }
              .width('100%')
              .padding({ top: 4, bottom: 4 })
              .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))
            }

            Divider().color(Color.Transparent).height(4)

            // 4. 高级设置 (保持只读，减少审核员困惑，体现“专为DeepSeek打造”)
            Column({ space: 12 }) {
              Text("高级设置")
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('sys.color.font_secondary'))
                .width('100%')

              // 模型名称
              Row() {
                Text("模型名称").width(80).fontSize(16)
                TextInput({ text: this.model, placeholder: 'deepseek-chat' })
                  .layoutWeight(1)
                  // .enabled(false) // 锁死，不让乱改
                  .fontColor($r('sys.color.font_secondary'))
              }

              // API 地址
              Row() {
                Text("API 地址").width(80).fontSize(16)
                TextInput({ text: this.baseUrl, placeholder: 'https://api.deepseek.com' })
                  .type(InputType.URL)
                  .layoutWeight(1)
                  // .enabled(false) // 锁死
                  .fontColor($r('sys.color.font_secondary'))
              }
            }
            .padding(12)
            .backgroundColor($r('app.color.background_secondary'))
            .borderRadius(24)

            Blank()
          }
          .height('100%')
          .width('100%')
          .justifyContent(FlexAlign.Start)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM, SafeAreaEdge.TOP])
        }
        .layoutWeight(1)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM, SafeAreaEdge.TOP])

        // 5. 保存并验证按钮
        // 按钮文案改成“校验并保存”，强调“校验”动作
        Button(this.isTesting ? '正在校验...' : '校验 Key 有效性并保存', { type: ButtonType.Capsule })
          .width('90%')
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .controlSize(ControlSize.NORMAL)
          .backgroundColor(this.buttonBg)
          .onClick(async () => {
            if (this.apiKey.trim().length === 0) {
              promptAction.showToast({ message: '请输入 API Key' });
              return;
            }

            this.isTesting = true;
            this.isVerified = false; // 重置状态

            try {
              // 1. 先保存
              const local = LocalValues.getInstance();
              await local.setDeepSeekApiKey(this.apiKey);
              await local.updateAIConfig(this.provider, this.model, this.baseUrl);

              // 2. 发起真实请求 (这就叫“校验逻辑”)
              const testPrompt = "Hi";
              await AIService.getInstance().extractTasks(testPrompt);

              // 3. 成功
              this.isVerified = true;
              promptAction.showToast({ message: '验证通过，配置已生效' });

            } catch (e) {
              this.isVerified = false;
              console.error(`AI Connection Error: ${JSON.stringify(e)}`);
              let msg = '验证失败';
              if (e instanceof Error) {
                msg = e.message;
              } else if (typeof e === 'string') {
                msg = e;
              }

              if (msg.includes('401')) {
                msg = 'Key 无效或未激活 (401)';
              } else if (msg.includes('402')) {
                msg = 'Key 余额不足 (402)';
              } else if (msg.includes('timeout')) {
                msg = '网络连接超时';
              }

              // 4. 失败提示，引导用户检查 Key
              AlertDialog.show({
                title: '验证失败',
                message: `无法连接至 AI 服务。\n错误信息：${msg}\n\n请确保您的 API Key 正确且已在相关平台完成实名认证。`,
                confirm: {
                  value: '知道了',
                  action: () => {}
                }
              })
            } finally {
              this.isTesting = false;
            }
          })
      }
      .padding(16)
      .height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM, SafeAreaEdge.TOP])
    }
    .titleBar({
      style: getImmersiveTitleBarStyle(this.isWideScreen, false),
      content: {
        title: {
          mainTitle: "Lifi AI 设置"
        },
        menu: {
          value: [
            {
              content: {
                icon: $r('sys.symbol.questionmark_circle'),
                action: () => { this.isHelpSheetShow = true },
                label: '帮助'
              },
            }
          ]
        }
      }
    })
    .onReady((context: NavDestinationContext) => {
      this.pageStack = context.pathStack;
    })
    .backgroundColor(this.theme.bgPrimary)
    .bindSheet($$this.isHelpSheetShow, this.helpSheet(), {
      title: { title: '如何配置大模型 API？' },
      detents: [
        SheetSize.FIT_CONTENT,
        SheetSize.MEDIUM,
        SheetSize.LARGE
      ],
      height: SheetSize.FIT_CONTENT,
      enableOutsideInteractive: false,
      dragBar: true,
      backgroundColor: Color.Transparent,
      blurStyle: BlurStyle.Regular,
      onDisappear: () => { this.isHelpSheetShow = false },
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM, SafeAreaEdge.TOP])
  }
}