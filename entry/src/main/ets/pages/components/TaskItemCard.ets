import { DDLStatus } from "../../model/DDLStatus";
import { ColorUtils } from "../../utils/ColorUtils";
import { common } from "@kit.AbilityKit";
import { ITheme } from "../../common/theme/ThemeModel";

@Component
export struct ArchivedDDLItemCard {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @Prop title: string;
  @Prop startTime: string;   // 起始时间
  @Prop completeTime: string; // 完成时间
  @Prop note: string;
  @Prop badgeText: string = '';
  @Prop showRestore: boolean = true;
  onDelete: () => void = () => {}; // 删除回调
  onRestore: () => void = () => {};

  // 主题颜色状态 - 固定为 Undergo 风格
  @State private indicatorColor: ResourceColor = this.theme.indicatorUndergo;
  @State private bgColor: ResourceColor = $r('app.color.background_secondary');
  @State private titleColor: ResourceColor = Color.Black;
  @State private noteColor: ResourceColor = Color.Gray;
  @State private timeColor: ResourceColor = Color.Gray; // 新增时间颜色
  @State private globalBgColor: ResourceColor = $r('app.color.background_secondary');

  @State private isPopUpShow: boolean = false;

  onWillApplyTheme(theme: Theme) {
    this.titleColor = theme.colors.fontPrimary;
    this.noteColor = theme.colors.fontSecondary;
    this.timeColor = theme.colors.fontTertiary; // 时间通常用更淡一点的颜色
    this.globalBgColor = theme.colors.backgroundPrimary;

    // 强制使用 Undergo 风格
    this.indicatorColor = this.theme.indicatorUndergo;
    this.bgColor = $r('app.color.background_secondary');
  }

  @Builder
  notePopupBuilder() {
    Column() {
      Text(this.note)
        .fontSize(14)
        .fontColor(this.titleColor)
        .lineHeight(20)
    }
    .padding(16)
    .constraintSize({ maxWidth: 280 })
    .borderRadius(16)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor(this.bgColor) // 背景底色

      Row() {
        Column() {
          // 标题
          Row({ space: 8 }) {
            Text(this.title)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.titleColor)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)

            if (this.badgeText.length > 0) {
              Text(this.badgeText)
                .fontSize(10)
                .fontColor(this.indicatorColor)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor(this.addAlpha(this.indicatorColor, 0.12))
                .borderRadius(10)
            }
          }
          .width('100%')

          // 时间信息 (起始 - 完成)
          Text(`${this.startTime} - ${this.completeTime}`)
            .fontSize(11)
            .fontColor(this.timeColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 4 })

          // 备注 (如果有)
          if (this.note && this.note.length > 0) {
            Text(this.note)
              .fontSize(12)
              .fontColor(this.noteColor)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .margin({ top: 4 })
          }
        }
        .layoutWeight(1) // 占据中间主要空间
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Center)
        .height('100%')

        // 右侧：红色删除按钮
        Row({ space: 8 }) {
          if (this.showRestore) {
            Button({ type: ButtonType.Circle, stateEffect: true }) {
              SymbolGlyph($r('sys.symbol.arrowshape_turn_up_left'))
                .fontSize(20)
                .fontColor([Color.White])
            }
            .width(36)
            .height(36)
            .backgroundColor(this.theme.brand)
            .onClick(() => {
              this.onRestore()
            })
          }

          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.trash')) // 使用系统垃圾桶图标
              .fontSize(20)
              .fontColor([Color.White])
          }
          .width(36)
          .height(36)
          .backgroundColor($r('app.color.warning')) // 红色背景
          .onClick(() => {
            this.onDelete()
          })
        }
        .margin({ left: 12 }) // 与左侧文字的间距
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(96)
    .borderRadius(24)
    .backgroundColor(this.globalBgColor)
    .clip(true)
    .onClick(() => {
      // 只有存在 note 内容时才弹出
      if (this.note && this.note.length > 0) {
        this.isPopUpShow = true;
      }
    })
    // 3. 完善：绑定 Popup 属性
    .bindPopup(this.isPopUpShow, {
      builder: this.notePopupBuilder,     // 绑定的内容构建器
      placement: Placement.Bottom,        // 弹出位置（可根据需要改成 Top）
      enableArrow: true,                  // 是否显示箭头
      onStateChange: (e) => {
        // 关键：当用户点击弹窗外部导致弹窗关闭时，同步更新状态变量
        if (!e.isVisible) {
          this.isPopUpShow = false;
        }
      }
    })
  }

  // 辅助函数：颜色透明度处理
  private addAlpha(color: ResourceColor, alpha: number): string | ResourceColor {
    try {
      let context = this.getUIContext().getHostContext()
      // 这里假设你项目里有 ColorUtils，如果没有，请替换为你的实现
      return ColorUtils.addAlpha(color, alpha, context);
    } catch (e) {
      return color; // 降级处理
    }
  }
}

@Component
export struct DDLItemCardSimplified {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @Prop title: string;
  @Prop remainingTimeAlt: string;
  @Prop note: string;
  @Prop progress: number;
  @Prop isStarred: boolean;
  @Prop status: DDLStatus = DDLStatus.UNDERGO;

  // 1. 状态定义：增加专门用于不同透明度的状态变量
  // 仍然保留 indicatorColor 用于星标 Icon (纯色)
  @State private indicatorColor: ResourceColor = this.theme.indicatorUndergo;

  // 新增：直接对应 json 中的透明度资源
  @State private indicatorColor50: ResourceColor = this.theme.indicatorUndergo50;
  @State private indicatorColor70: ResourceColor = this.theme.indicatorUndergo70;
  @State private bgColor40: ResourceColor = this.theme.bgUndergo40;

  @State private titleColor: ResourceColor = Color.Black;
  @State private noteColor: ResourceColor = Color.Gray;
  @State private globalBgColor: ResourceColor = $r('app.color.background_secondary');

  onWillApplyTheme(theme: Theme) {
    this.titleColor = theme.colors.fontPrimary;
    this.noteColor = theme.colors.fontSecondary;
    this.globalBgColor = theme.colors.backgroundSecondary;

    // 2. 根据 Status 映射资源 ID
    // 系统会自动根据当前深浅模式解析这些 ID
    if (this.status === DDLStatus.UNDERGO) {
      this.indicatorColor = this.theme.indicatorUndergo;
      this.indicatorColor50 = this.theme.indicatorUndergo50;
      this.indicatorColor70 = this.theme.indicatorUndergo70;
      this.bgColor40 = this.theme.bgUndergo40;

    } else if (this.status === DDLStatus.NEAR) {
      this.indicatorColor = this.theme.indicatorNear;
      this.indicatorColor50 = this.theme.indicatorNear50;
      this.indicatorColor70 = this.theme.indicatorNear70;
      this.bgColor40 = this.theme.bgNear40;

    } else if (this.status === DDLStatus.PASSED) {
      this.indicatorColor = this.theme.indicatorPassed;
      this.indicatorColor50 = this.theme.indicatorPassed50;
      this.indicatorColor70 = this.theme.indicatorPassed70;
      this.bgColor40 = this.theme.bgPassed40;

    } else if (this.status === DDLStatus.ABANDONED) {
      this.indicatorColor = $r('sys.color.ohos_id_color_text_tertiary');
      this.indicatorColor50 = $r('sys.color.ohos_id_color_text_tertiary');
      this.indicatorColor70 = $r('sys.color.ohos_id_color_text_tertiary');
      this.bgColor40 = $r('app.color.background_tertiary');

    } else if (this.status === DDLStatus.COMPLETED) {
      this.indicatorColor = this.theme.indicatorCompleted;
      this.indicatorColor50 = this.theme.indicatorCompleted50;
      this.indicatorColor70 = this.theme.indicatorCompleted70;
      this.bgColor40 = this.theme.bgCompleted40;
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 1. 背景进度条层
      Row() {
        // 进度部分
        if (this.progress > 0) {
          Row()
            .height('100%')
            .width(`${Math.max(0, Math.min(1, this.progress)) * 100}%`)
            .linearGradient({
              direction: GradientDirection.Right,
              colors: [
                // 3. 直接使用资源变量，无需 addAlpha
                [this.indicatorColor50, 0.0],
                [this.indicatorColor70, 1.0]
              ]
            })
        }
      }
      .width('100%')
      .height('100%')
      // 4. 直接使用带透明度的背景色资源
      .backgroundColor(this.bgColor40)

      // 2. 内容层
      Column() {
        Row() {
          Text(this.title)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.titleColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .margin({ right: 4 })

          Text(this.remainingTimeAlt)
            .fontSize(12)
            .fontColor(this.titleColor)
            .maxLines(1)

          if (this.isStarred) {
            SymbolGlyph($r('sys.symbol.star_fill'))
              .fontSize(20)
              // 星标继续使用纯色
              .fontColor([this.indicatorColor])
              .margin({ left: 8 })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (this.note && this.note.length > 0) {
          Text(this.note)
            .fontSize(12)
            .fontColor(this.noteColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 8 })
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .height(76)
    .borderRadius(24)
    // .backgroundColor(this.globalBgColor)
    .clip(true)
    .backgroundBlurStyle(BlurStyle.Regular)
  }
}

@Component
struct SelectionOverlay {
  @State primaryColor: ResourceColor = Color.Blue;
  @State containerColor: ResourceColor = Color.White;
  @State onPrimaryColor: ResourceColor = Color.White;

  onWillApplyTheme(theme: Theme) {
    this.primaryColor = theme.colors.brand;
    this.containerColor = theme.colors.backgroundPrimary;
    this.onPrimaryColor = theme.colors.fontPrimary;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 1. 半透明遮罩背景
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.containerColor)
        .opacity(0.25)

      // 2. 边框 (使用 border 属性替代 Rect stroke，避免被裁切)
      Column()
        .width('100%')
        .height('100%')
        .border({
          width: 2,
          color: this.primaryColor,
          radius: 24 // 这里的 radius 要和卡片保持一致
        })
        .opacity(0.7)
        .hitTestBehavior(HitTestMode.Transparent) // 确保不拦截点击

      // 3. 左上角打钩
      Stack() {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(16)
          .fontColor([this.onPrimaryColor])
      }
      .width(24)
      .height(24)
      .borderRadius(12)
      .backgroundColor(this.primaryColor)
      .shadow({ radius: 2 })
      .margin({ top: 8, left: 8 }) // 调整位置
      .alignContent(Alignment.Center)
    }
    .width('100%')
    .height('100%')
  }
}

@Component
export struct DDLItemCardSwipeable {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  // 数据 Props
  @Prop title: string;
  @Prop remainingTimeAlt: string;
  @Prop note: string;
  @Prop progress: number;
  @Prop isStarred: boolean;
  @Prop status: DDLStatus;

  // 交互 Props
  @Prop selectionMode: boolean = false;
  @Prop selected: boolean = false;

  // 回调
  onClickItem?: () => void;
  onPrimaryAction?: () => void;
  onSecondaryAction?: () => void;
  onLongPressSelect?: () => void;
  onToggleSelect?: () => void;
  @Prop primaryActionSymbol: Resource = $r('sys.symbol.checkmark_circle');
  @Prop secondaryActionSymbol: Resource = $r('sys.symbol.trash');
  @Prop secondaryActionColor: ResourceColor = $r('app.color.chart_red');

  // 内部状态
  @State offsetX: number = 0;
  @State cardWidth: number = 0;

  // 颜色状态
  @State completeColor: ResourceColor = $r('app.color.chart_green'); // R.color.chart_green
  @State surfaceVariant: ResourceColor = this.theme.bgPrimary;
  @State fontColor: ResourceColor = this.theme.bgPrimary

  build() {
    Stack() {
      // ==================
      // 1. 背景层 (滑动时露出)
      // ==================
      if (Math.abs(this.offsetX) > 0 && !this.selectionMode) {
        Stack() {
          // 根据滑动方向决定背景图标和颜色
          // 这里简化了颜色插值(lerp)，直接根据方向显示
          if (this.offsetX > 0) {
            // 向右滑 -> 完成 (StartToEnd)
            Row() {
              Stack({ alignContent: Alignment.Center }) {
                SymbolGlyph(this.primaryActionSymbol)
                  .fontSize(24) // 图标的实际大小
                  .fontColor([this.fontColor])
              }
              .width(48)
              .height(48)
              .borderRadius(24) // 容器的圆形形状
              .backgroundColor(this.completeColor)
              .shadow({ radius: 4, color: this.completeColor });
            }
            .width('100%')
            .height('100%')
            .padding({ left: 20 })
            .justifyContent(FlexAlign.Start)
            .alignItems(VerticalAlign.Center)
            // .backgroundColor(this.surfaceVariant)
          } else {
            // 向左滑 -> 删除 (EndToStart)
            Row() {
              Stack({ alignContent: Alignment.Center }) {
                SymbolGlyph(this.secondaryActionSymbol)
                  .fontSize(24) // 图标的实际大小
                  .fontColor([this.fontColor])
              }
              .width(48)
              .height(48)
              .borderRadius(24) // 容器的圆形形状
              .backgroundColor(this.secondaryActionColor)
              .shadow({ radius: 4, color: this.secondaryActionColor });
            }
            .width('100%')
            .height('100%')
            .padding({ right: 20 })
            .justifyContent(FlexAlign.End)
            .alignItems(VerticalAlign.Center)
            // .backgroundColor(this.surfaceVariant)
          }
        }
        .width('100%')
        .height(76)
        .borderRadius(24)
        .clip(true)
      }

      // ==================
      // 2. 前景卡片层
      // ==================
      Stack() {
        DDLItemCardSimplified({
          title: this.title,
          remainingTimeAlt: this.remainingTimeAlt,
          note: this.note,
          progress: this.progress,
          isStarred: this.isStarred,
          status: this.status
        })

        // 选择态覆盖层
        if (this.selectionMode && this.selected) {
          SelectionOverlay()
        }
      }
      .width('100%') // 确保填满
      .height(76)    // 确保高度一致
      .borderRadius(24) // 【新增】由父容器统一控制圆角
      .clip(true)       // 【新增】强制裁剪子元素超出圆角的部分
      .translate({ x: this.offsetX }) // 核心位移
      .onAreaChange((oldArea, newArea) => {
        this.cardWidth = newArea.width as number;
      })
      // 手势处理
      .gesture(
        GestureGroup(GestureMode.Exclusive,
          // 1. 长按手势
          LongPressGesture()
            .onAction(() => {
              if (this.onLongPressSelect) {
                this.onLongPressSelect();
              }
            }),

          // 2. 拖动手势 (仅在非选择模式下启用)
          PanGesture({ direction: PanDirection.Horizontal })
            .onActionUpdate((event) => {
              if (this.selectionMode) return;
              this.offsetX = event.offsetX;
            })
            .onActionEnd(() => {
              if (this.selectionMode) return;

              const threshold = this.cardWidth * 0.4; // 滑动超过 40% 触发

              if (this.offsetX > threshold) {
                // 触发完成
                if (this.onPrimaryAction) this.onPrimaryAction();
                // 动画回弹或保持(取决于你的业务逻辑，这里模拟 Compose 的回弹)
                this.resetSwipe();
              } else if (this.offsetX < -threshold) {
                if (this.onSecondaryAction) this.onSecondaryAction();
                this.resetSwipe();
              } else {
                // 未达到阈值，回弹
                this.resetSwipe();
              }
            }),

          // 3. 点击手势
          TapGesture()
            .onAction(() => {
              if (this.selectionMode) {
                if (this.onToggleSelect) this.onToggleSelect();
              } else {
                if (this.onClickItem) this.onClickItem();
              }
            })
        )
      )
    }
    .width('100%')
    .height(76)
  }

  private resetSwipe() {
    animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
      this.offsetX = 0;
    })
  }
}
