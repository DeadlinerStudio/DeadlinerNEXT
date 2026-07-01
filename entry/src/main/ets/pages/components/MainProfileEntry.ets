import { SettingsSection, SettingsVerticalDivider } from "./SettingsComponents";

@Component
struct MainQuickActionCard {
  title: string = '';
  subtitle: string = '';
  icon: Resource = $r('sys.symbol.square');
  isImage?: boolean;
  accentColor: ResourceColor = $r('app.color.background_tertiary');
  action?: () => void;

  @State isPressed: boolean = false;

  build() {
    Row({ space: 14 }) {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(42)
          .height(42)
          .fill(this.accentColor)
          .opacity(0.18)

        if (this.isImage) {
          Image(this.icon)
            .width(22)
            .height(22)
            .objectFit(ImageFit.Contain)
        } else {
          SymbolGlyph(this.icon)
            .fontSize(20)
            .fontColor([$r('app.color.font_primary')])
        }
      }

      Column({ space: 4 }) {
        Text(this.title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.font_primary'))
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.subtitle)
          .fontSize(12)
          .lineHeight(18)
          .fontColor($r('app.color.font_secondary'))
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .fontColor([$r('app.color.font_secondary')])
        .opacity(0.5)
    }
    .width('100%')
    .padding(16)
    .borderRadius(20)
    .backgroundColor(this.isPressed ? $r('sys.color.ohos_id_color_click_effect') : $r('sys.color.comp_background_secondary'))
    .animation({ duration: 180 })
    .onTouch((event) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    })
    .onClick(() => {
      if (this.action) {
        this.action();
      }
    })
  }
}

@Component
export struct ProfileAvatarMenuButton {
  @Prop buttonSize: number = 40;
  @Prop avatarSize: number = 40;
  @Prop avatarUri: string = '';
  @Prop hasAvatar: boolean = false;
  @Require onButtonClick: () => void;

  build() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      if (this.hasAvatar && this.avatarUri.length > 0) {
        Image(this.avatarUri)
          .width(this.buttonSize)
          .height(this.buttonSize)
          .borderRadius(this.buttonSize / 2)
          .clip(true)
          .objectFit(ImageFit.Cover)
      } else {
        SymbolGlyph($r('sys.symbol.person_crop_circle_fill_1'))
          .fontSize(22)
          .fontColor([$r('sys.color.ohos_id_color_text_primary')])
      }
    }
    .width(this.buttonSize)
    .height(this.buttonSize)
    .backgroundColor(Color.Transparent)
    .onClick(() => {
      this.onButtonClick();
    })
  }
}

@Component
export struct MainProfileQuickSheet {
  onOpenInteraction?: () => void;
  onOpenMainButtons?: () => void;
  onOpenAi?: () => void;

  build() {
    Column({ space: 16 }) {
      SettingsSection({ marginHorizontal: 16 }) {
        Column({ space: 14 }) {
          Row() {
            Text('HOME')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.font_secondary'))
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .backgroundColor($r('sys.color.comp_background_secondary'))
              .borderRadius(999)
          }
          .width('100%')

          Column({ space: 6 }) {
            Text('主页工作台')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.font_primary'))
              .width('100%')

            Text('这里保留的是会影响主页体验的快捷操作。账号、完整偏好和服务管理，继续留在“我的”页。')
              .fontSize(13)
              .lineHeight(20)
              .fontColor($r('app.color.font_secondary'))
              .width('100%')
          }

          Row() {
            Text('更像一块首页工具板，而不是另一套个人中心。')
              .fontSize(12)
              .fontColor($r('app.color.font_secondary'))
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ top: 2 })
        }
        .width('100%')
        .padding(16)
      }

      SettingsSection({ title: '快捷操作', marginHorizontal: 16 }) {
        Column({ space: 10 }) {
          MainQuickActionCard({
            title: '交互与行为',
            subtitle: '调整启动行为、触感反馈和主页层的使用节奏。',
            icon: $r('sys.symbol.hand_tap'),
            accentColor: $r('app.color.chart_yellow'),
            action: () => {
              if (this.onOpenInteraction) {
                this.onOpenInteraction();
              }
            }
          })

          MainQuickActionCard({
            title: '手机按钮布局',
            subtitle: '只处理手机端的主页快捷按钮摆放，不碰平板布局。',
            icon: $r('sys.symbol.slider_horizontal_2'),
            accentColor: $r('app.color.chart_blue'),
            action: () => {
              if (this.onOpenMainButtons) {
                this.onOpenMainButtons();
              }
            }
          })

          Row() {
            Column({ space: 4 }) {
              Text('Lifi AI')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.font_primary'))
                .width('100%')

              Text('从主页直接切到当前 AI 工作流，适合把灵感继续往下整理。')
                .fontSize(12)
                .lineHeight(18)
                .fontColor($r('app.color.font_secondary'))
                .width('100%')
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            SettingsVerticalDivider()

            Button('打开')
              .type(ButtonType.Capsule)
              .height(36)
              .backgroundColor($r('app.color.chart_blue'))
              .fontColor(Color.White)
              .onClick(() => {
                if (this.onOpenAi) {
                  this.onOpenAi();
                }
              })
          }
          .width('100%')
          .padding(16)
          .borderRadius(20)
          .backgroundColor($r('sys.color.comp_background_secondary'))
        }
        .width('100%')
        .padding(12)
      }
    }
    .width('100%')
    .padding({ top: 8, bottom: 16 })
  }
}
