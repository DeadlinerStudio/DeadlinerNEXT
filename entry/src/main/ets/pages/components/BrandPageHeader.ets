import { ITheme } from "../../common/theme/ThemeModel";
import { Symbol } from "./infra/Symbol";

@Component
export struct BrandPageHeader {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @Prop icon: Resource;
  @Prop title: string;
  @Prop gradientColors: [ResourceColor, number][] = [];
  @Prop baseColor: string | ResourceColor = '';
  subtitle?: string = '使用手册详情';
  decorIcon?: Resource = $r('sys.symbol.book');

  isImage?: boolean;

  @Builder
  BackgroundLayer() {
    if (this.baseColor) {
      Stack() {
        // 1. 底色
        Column().width('100%').height('100%')
          .backgroundColor(this.baseColor)

        // 2. 通用光影遮罩 (让纯色变立体)
        Column().width('100%').height('100%')
          .linearGradient({
            angle: 135,
            colors: [
              ['#1AFFFFFF', 0.0], // 左上角：10% 白色 (提亮)
              ['#00000000', 0.5], // 中间：透明
              ['#33000000', 1.0]  // 右下角：20% 黑色 (阴影)
            ]
          })
      }
    } else if (this.gradientColors.length > 0) {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 135, colors: this.gradientColors })
    } else {
      Column().width('100%').height('100%')
        .linearGradient({
          angle: 135,
          colors: [
            [this.theme.brand, 0.0],
            [this.theme.brand50, 0.6],
            ['#803A6EA5', 1.0]
          ]
        })
    }
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      this.BackgroundLayer()

      // B. 装饰层：背景大图标水印
      if (this.decorIcon) {
        Stack() {
          SymbolGlyph(this.decorIcon)
            .fontSize(120)
            .fontColor([Color.White])
            .opacity(0.1)
        }
        .width('100%')
        .height('100%')
        .align(Alignment.BottomEnd)
        .offset({ x: 20, y: 20 })
      }

      // C. 内容层：传入的 Icon 和 Title
      Row({ space: 16 }) {
        // 主图标 (使用 Symbol)
        if (this.icon) {
          Symbol({
            icon: this.icon,
            isImage: this.isImage === true,
            fontSize: 56,
            fontColor: Color.White,
            fontWeight: 600
          })
        }

        Column({ space: 4 }) {
          Text(this.title)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (this.subtitle) {
            Text(this.subtitle)
              .fontSize(14)
              .fontColor(Color.White)
              .opacity(0.8)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .padding(24)
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(120)
    .borderRadius(24)
    .clip(true)
    .shadow({ radius: 12, color: '#26000000', offsetY: 4 })
  }
}