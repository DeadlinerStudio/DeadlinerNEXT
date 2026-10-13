import { FocusSwipeAction } from '../routes/focus/FocusTimerControls';
import { DDLStatus } from "../../model/DDLStatus";
import { ColorUtils } from "../../utils/ColorUtils";
import { common } from "@kit.AbilityKit";
import { ITheme } from "../../common/theme/ThemeModel";
import { ThemeManager } from '../../common/theme/ThemeManager';
import { ImmersivePopupSurface } from "../../common/ui/ImmersivePopupSurface";
import { CategoryIconResolver } from '../../common/category/CategoryIconResolver';
import { curves } from '@kit.ArkUI';

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
    ImmersivePopupSurface({ maxWidthValue: 280, paddingValue: 16, radius: 16 }) {
      Text(this.note)
        .fontSize(14)
        .fontColor(this.titleColor)
        .lineHeight(20)
    }
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
  @StorageProp('currentTheme') @Watch('syncIndicatorColors') theme: ITheme = ThemeManager.getCurrentTheme();

  @Prop title: string;
  @Prop remainingTimeAlt: string;
  @Prop note: string;
  @Prop progress: number;
  @Prop isStarred: boolean;
  @Prop @Watch('syncIndicatorColors') status: DDLStatus = DDLStatus.UNDERGO;
  @Prop categoryName: string = '';
  @Prop categoryIconKey: string = '';
  @Prop categoryColorHex: string = '';

  @State private indicatorColor: ResourceColor = this.theme.indicatorUndergo;
  @State private indicatorColor50: ResourceColor = this.theme.indicatorUndergo50;
  @State private indicatorColor70: ResourceColor = this.theme.indicatorUndergo70;
  @State private bgColor40: ResourceColor = this.theme.bgUndergo40;
  @State private titleColor: ResourceColor = Color.Black;
  @State private noteColor: ResourceColor = Color.Gray;
  @State private globalBgColor: ResourceColor = $r('app.color.background_secondary');

  aboutToAppear(): void {
    this.syncIndicatorColors();
  }

  onWillApplyTheme(theme: Theme) {
    this.titleColor = theme.colors.fontPrimary;
    this.noteColor = theme.colors.fontSecondary;
    this.globalBgColor = theme.colors.backgroundSecondary;
  }

  private syncIndicatorColors(): void {
    if (this.status === DDLStatus.NEAR) {
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
    } else {
      this.indicatorColor = this.theme.indicatorUndergo;
      this.indicatorColor50 = this.theme.indicatorUndergo50;
      this.indicatorColor70 = this.theme.indicatorUndergo70;
      this.bgColor40 = this.theme.bgUndergo40;
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
                [this.indicatorColor50, 0.0],
                [this.indicatorColor70, 1.0]
              ]
            })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.bgColor40)

      // 2. 内容层
      Column() {
        Row({ space: 8 }) {
          if (this.isStarred) {
            SymbolGlyph($r('sys.symbol.star_fill'))
              .fontSize(20)
              .fontColor([this.indicatorColor])
          }

          Text(this.title)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.titleColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          if (this.categoryName.length > 0) {
            Row({ space: 4 }) {
              SymbolGlyph(CategoryIconResolver.resolve(this.categoryIconKey))
                .fontSize(12)
                .fontColor([this.categoryColorHex])

              Text(this.categoryName)
                .fontSize(11)
                .fontColor(this.categoryColorHex)
                .maxLines(1)
            }
          }

          Text(this.remainingTimeAlt)
            .fontSize(12)
            .fontColor(this.titleColor)
            .maxLines(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (this.note.length > 0) {
          Text(this.note)
            .fontSize(12)
            .fontColor(this.noteColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 4 })
        }
      }
      .width('100%')
      .height('100%')
      .padding({ top: 14, bottom: 14, left: 16, right: 16 })
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .height(72)
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
  @StorageProp('currentIndicatorKey') currentIndicatorKey: string = 'vibrant';
  @StorageLink('activeTaskCardSwipeId') @Watch('onActiveSwipeIdChange') activeSwipeId: number = -1;

  // 数据 Props
  @Prop title: string;
  @Prop remainingTimeAlt: string;
  @Prop note: string;
  @Prop progress: number;
  @Prop isStarred: boolean;
  @Prop status: DDLStatus;
  @Prop categoryName: string = '';
  @Prop categoryIconKey: string = '';
  @Prop categoryColorHex: string = '';
  @Prop swipeId: number = -1;

  // 交互 Props
  @Prop selectionMode: boolean = false;
  @Prop selected: boolean = false;

  // 回调
  onClickItem?: () => void;
  onPrimaryAction?: () => void;
  onSecondaryAction?: () => void;
  onDeleteAction?: () => void;
  onEditAction?: () => void;
  onFocusAction?: () => void;
  onLongPressSelect?: () => void;
  onToggleSelect?: () => void;
  @Prop primaryActionSymbol: Resource = $r('sys.symbol.checkmark_circle');
  @Prop secondaryActionSymbol: Resource = $r('sys.symbol.trash');
  @Prop secondaryActionColor: ResourceColor = $r('app.color.chart_red');
  @Prop editActionSymbol: Resource = $r('sys.symbol.square_and_pencil');
  @Prop deleteActionSymbol: Resource = $r('sys.symbol.trash');

  // 内部状态
  @State offsetX: number = 0;
  @State panStartOffset: number = 0;
  @State cardWidth: number = 0;

  // 颜色状态
  @State completeColor: ResourceColor = $r('app.color.chart_green'); // R.color.chart_green
  @State fontColor: ResourceColor = this.theme.bgPrimary;
  @State reversedFontColor: ResourceColor = $r('app.color.font_secondary');
  @State editColor: ResourceColor = $r('app.color.chart_blue');
  @State deleteColor: ResourceColor = $r('app.color.chart_red');

  private readonly CARD_HEIGHT: number = 70;
  private readonly ACTION_BUTTON_SIZE: number = 48;
  private readonly ACTION_BASE_GAP: number = 8;
  private readonly ACTION_MAX_GAP: number = 24;
  private readonly ACTION_SIDE_PADDING: number = 0;
  private actionRevealWidth(): number { return this.offsetX > 0 && this.onFocusAction !== undefined ? 168 : 112; }
  private readonly ACTION_REVEAL_TRIGGER_DISTANCE: number = 84;
  private readonly ACTION_CLOSE_DISTANCE: number = 32;

  build() {
    Stack() {
      // ==================
      // 1. 背景层 (滑动时露出)
      // ==================
      if (Math.abs(this.offsetX) > 0 && !this.selectionMode) {
        Row() {
          if (this.offsetX > 0) {
            Row({ space: this.actionGap() }) {
              Column() {
                Button({ type: ButtonType.Normal, stateEffect: true }) {
                  SymbolGlyph(this.primaryActionSymbol)
                    .fontSize(19)
                    .fontColor([this.fontColor])
                }
                .width(this.ACTION_BUTTON_SIZE)
                .height(this.ACTION_BUTTON_SIZE)
                .padding(0)
                .borderRadius(this.ACTION_BUTTON_SIZE / 2)
                .backgroundColor(this.primaryButtonColor())
                .onClick((): void => this.runPrimaryAction())

                Text(this.primaryActionLabel())
                  .width(this.ACTION_BUTTON_SIZE)
                  .fontSize(10)
                  .fontColor(this.reversedFontColor)
                  .textAlign(TextAlign.Center)
                  .maxLines(1)
                  .translate({ y: 2 })
              }
              .width(this.fullActionWidth())
              .height(60)
              .alignItems(HorizontalAlign.Start)
              .justifyContent(FlexAlign.Center)

              if (this.onFocusAction !== undefined) {
                FocusSwipeAction({
                  onAction: (): void => { this.resetSwipe(); if (this.onFocusAction) this.onFocusAction(); } })
              }
              Column() {
                Button({ type: ButtonType.Normal, stateEffect: true }) {
                  SymbolGlyph(this.secondaryActionSymbol)
                    .fontSize(19)
                    .fontColor([this.fontColor])
                }
                .width(this.ACTION_BUTTON_SIZE)
                .height(this.ACTION_BUTTON_SIZE)
                .padding(0)
                .borderRadius(this.ACTION_BUTTON_SIZE / 2)
                .backgroundColor(this.secondaryButtonColor())
                .onClick((): void => this.runSecondaryAction())

                Text(this.secondaryActionLabel())
                  .width(this.ACTION_BUTTON_SIZE)
                  .fontSize(10)
                  .fontColor(this.reversedFontColor)
                  .textAlign(TextAlign.Center)
                  .maxLines(1)
                  .translate({ y: 2 })
              }
              .width(this.ACTION_BUTTON_SIZE)
              .height(60)
              .alignItems(HorizontalAlign.Center)
              .justifyContent(FlexAlign.Center)
            }
            .height('100%')
            .width(this.actionGroupWidth())
            .padding({ left: this.ACTION_SIDE_PADDING, right: this.ACTION_SIDE_PADDING })
            .alignItems(VerticalAlign.Center)

            Blank()
          } else {
            Blank()

            Row({ space: this.actionGap() }) {
              Column() {
                Button({ type: ButtonType.Normal, stateEffect: true }) {
                  SymbolGlyph(this.editActionSymbol)
                    .fontSize(19)
                    .fontColor([this.fontColor])
                }
                .width(this.ACTION_BUTTON_SIZE)
                .height(this.ACTION_BUTTON_SIZE)
                .padding(0)
                .borderRadius(this.ACTION_BUTTON_SIZE / 2)
                .backgroundColor(this.editButtonColor())
                .onClick((): void => this.runEditAction())

                Text('编辑')
                  .width(this.ACTION_BUTTON_SIZE)
                  .fontSize(10)
                  .fontColor(this.reversedFontColor)
                  .textAlign(TextAlign.Center)
                  .maxLines(1)
                  .translate({ y: 2 })
              }
              .width(this.ACTION_BUTTON_SIZE)
              .height(60)
              .alignItems(HorizontalAlign.Center)
              .justifyContent(FlexAlign.Center)

              Column() {
                Button({ type: ButtonType.Normal, stateEffect: true }) {
                  SymbolGlyph(this.deleteActionSymbol)
                    .fontSize(19)
                    .fontColor([this.fontColor])
                }
                .width(this.ACTION_BUTTON_SIZE)
                .height(this.ACTION_BUTTON_SIZE)
                .padding(0)
                .borderRadius(this.ACTION_BUTTON_SIZE / 2)
                .backgroundColor(this.deleteButtonColor())
                .onClick((): void => this.runDeleteAction())

                Text('删除')
                  .width(this.ACTION_BUTTON_SIZE)
                  .fontSize(10)
                  .fontColor(this.reversedFontColor)
                  .textAlign(TextAlign.Center)
                  .maxLines(1)
                  .translate({ y: 2 })
              }
              .width(this.fullActionWidth())
              .height(60)
              .alignItems(HorizontalAlign.End)
              .justifyContent(FlexAlign.Center)
            }
            .height('100%')
            .width(this.actionGroupWidth())
            .padding({ left: this.ACTION_SIDE_PADDING, right: this.ACTION_SIDE_PADDING })
            .justifyContent(FlexAlign.End)
            .alignItems(VerticalAlign.Center)
          }
        }
        .width('100%')
        .height(this.CARD_HEIGHT)
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
          status: this.status,
          categoryName: this.categoryName,
          categoryIconKey: this.categoryIconKey,
          categoryColorHex: this.categoryColorHex
        })

        // 选择态覆盖层
        if (this.selectionMode && this.selected) {
          SelectionOverlay()
        }
      }
      .width('100%') // 确保填满
      .height(this.CARD_HEIGHT) // 确保高度一致
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
            .onActionStart(() => {
              if (this.selectionMode) return;
              this.claimSwipeFocus();
              this.panStartOffset = this.offsetX;
            })
            .onActionUpdate((event) => {
              if (this.selectionMode) return;
              const maxOffset = this.cardWidth * 0.82;
              const minOffset = this.hasTrailingActions() ? -maxOffset : 0;
              const accumulatedOffset = this.panStartOffset + event.offsetX;
              this.offsetX = Math.max(minOffset, Math.min(maxOffset, accumulatedOffset));
            })
            .onActionEnd((event: GestureEvent) => {
              if (this.selectionMode) return;
              this.finishSwipe(event.offsetX);
            }),

          // 3. 点击手势
          TapGesture()
            .onAction(() => {
              if (Math.abs(this.offsetX) > 0) {
                this.resetSwipe();
                return;
              }
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
    .height(this.CARD_HEIGHT)
  }

  private primaryActionLabel(): string {
    if (this.status === DDLStatus.COMPLETED) return '撤销完成';
    if (this.status === DDLStatus.ABANDONED) return '恢复';
    return '完成';
  }

  private secondaryActionLabel(): string {
    if (this.status === DDLStatus.COMPLETED || this.status === DDLStatus.ABANDONED) return '归档';
    return '放弃';
  }

  private primaryButtonColor(): ResourceColor {
    if (this.currentIndicatorKey !== 'ios') return this.completeColor;
    if (this.status === DDLStatus.ABANDONED) return $r('app.color.ios_orange');
    return $r('app.color.ios_green');
  }

  private secondaryButtonColor(): ResourceColor {
    if (this.currentIndicatorKey === 'ios' &&
      this.status !== DDLStatus.COMPLETED && this.status !== DDLStatus.ABANDONED) {
      return $r('app.color.ios_orange');
    }
    return this.secondaryActionColor;
  }

  private editButtonColor(): ResourceColor {
    if (this.currentIndicatorKey === 'ios') return $r('app.color.ios_blue');
    return this.editColor;
  }

  private deleteButtonColor(): ResourceColor {
    if (this.currentIndicatorKey === 'ios') return $r('app.color.warning');
    return this.deleteColor;
  }

  private hasTrailingActions(): boolean {
    return this.onEditAction !== undefined && this.onDeleteAction !== undefined;
  }

  private claimSwipeFocus(): void {
    if (this.swipeId < 0 || this.activeSwipeId === this.swipeId) return;
    this.activeSwipeId = this.swipeId;
  }

  private onActiveSwipeIdChange(): void {
    if (this.activeSwipeId === this.swipeId || Math.abs(this.offsetX) === 0) return;
    this.resetSwipe();
  }

  private revealedDistance(): number {
    return Math.abs(this.offsetX);
  }

  private actionGroupWidth(): number {
    return Math.max(this.actionRevealWidth(), this.revealedDistance());
  }

  private actionGap(): number {
    const extraDistance = Math.max(0, this.revealedDistance() - this.actionRevealWidth());
    const gapGrowth = Math.min(this.ACTION_MAX_GAP - this.ACTION_BASE_GAP, extraDistance);
    return this.ACTION_BASE_GAP + gapGrowth;
  }

  private fullActionWidth(): number {
    const separationDistance = this.ACTION_MAX_GAP - this.ACTION_BASE_GAP;
    const stretchDistance = Math.max(0,
      this.revealedDistance() - this.actionRevealWidth() - separationDistance);
    return this.ACTION_BUTTON_SIZE + stretchDistance;
  }

  private finishSwipe(gestureOffset: number): void {
    const fullSwipeThreshold = this.cardWidth * 0.62;
    const revealThreshold = this.ACTION_REVEAL_TRIGGER_DISTANCE;

    if (this.offsetX > fullSwipeThreshold) {
      this.runPrimaryAction();
      return;
    }
    if (this.offsetX < -fullSwipeThreshold) {
      this.runDeleteAction();
      return;
    }

    if (this.panStartOffset <= -revealThreshold && gestureOffset > 0) {
      if (this.offsetX >= revealThreshold) {
        this.revealActions(this.actionRevealWidth());
      } else if (gestureOffset >= this.ACTION_CLOSE_DISTANCE) {
        this.resetSwipe();
      } else {
        this.revealActions(-this.actionRevealWidth());
      }
      return;
    }

    if (this.panStartOffset >= revealThreshold && gestureOffset < 0) {
      if (this.offsetX <= -revealThreshold && this.hasTrailingActions()) {
        this.revealActions(-this.actionRevealWidth());
      } else if (Math.abs(gestureOffset) >= this.ACTION_CLOSE_DISTANCE) {
        this.resetSwipe();
      } else {
        this.revealActions(this.actionRevealWidth());
      }
      return;
    }

    if (this.offsetX >= revealThreshold) {
      this.revealActions(this.actionRevealWidth());
    } else if (this.offsetX <= -revealThreshold) {
      this.revealActions(-this.actionRevealWidth());
    } else {
      this.resetSwipe();
    }
  }

  private runPrimaryAction(): void {
    this.resetSwipe();
    if (this.onPrimaryAction) this.onPrimaryAction();
  }

  private runSecondaryAction(): void {
    this.resetSwipe();
    if (this.onSecondaryAction) this.onSecondaryAction();
  }

  private runEditAction(): void {
    this.resetSwipe();
    if (this.onEditAction) this.onEditAction();
  }

  private runDeleteAction(): void {
    this.resetSwipe();
    if (this.onDeleteAction) this.onDeleteAction();
  }

  private revealActions(targetOffset: number): void {
    this.getUIContext().animateTo({
      curve: curves.responsiveSpringMotion(0.32, 0.78)
    }, () => {
      this.offsetX = targetOffset;
    })
  }

  private resetSwipe(): void {
    this.getUIContext().animateTo({
      curve: curves.responsiveSpringMotion(0.38, 0.72)
    }, () => {
      this.offsetX = 0;
    })
  }
}
