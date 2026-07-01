import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { ITheme } from '../../../common/theme/ThemeModel';
import { InspirationItem } from '../../../model/InspirationModels';
import { BlurBackgroundModifier } from '../../../utils/animation/BlurBackgroundModifier';
import { PressEffectModifier } from '../../../utils/animation/PressModifier';

@Component
struct SelectionOverlay {
  @State primaryColor: ResourceColor = Color.Blue;
  @State containerColor: ResourceColor = Color.White;

  onWillApplyTheme(theme: Theme) {
    this.primaryColor = theme.colors.brand;
    this.containerColor = theme.colors.backgroundPrimary;
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .border({
          width: 2,
          color: this.primaryColor,
          radius: 24
        })
        .backgroundColor(this.containerColor)
        .opacity(0.18)
        .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height('100%')
  }
}

export function formatInspirationRelativeTime(isoTime: string): string {
  const target = new Date(isoTime).getTime();
  const now = Date.now();
  const diff = Math.max(0, now - target);

  const minute = 60 * 1000;
  const hour = 60 * minute;
  const day = 24 * hour;

  if (diff < minute) {
    return '刚刚';
  }
  if (diff < hour) {
    return `${Math.floor(diff / minute)}分钟前`;
  }
  if (diff < day) {
    return `${Math.floor(diff / hour)}小时前`;
  }
  if (diff < day * 7) {
    return `${Math.floor(diff / day)}天前`;
  }

  const date = new Date(isoTime);
  return `${date.getMonth() + 1}月${date.getDate()}日`;
}

@Component
export struct InspirationItemCard {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @Prop item: InspirationItem = { id: 0, text: '', createdAt: '', updatedAt: '' };
  @Prop selectionMode: boolean = false;
  @Prop selected: boolean = false;
  onCardClick: () => void = (): void => {};
  onLongPressSelect: () => void = (): void => {};
  onToggleSelect: () => void = (): void => {};

  @StorageProp('customBackgroundImage') customBg: string = '';

  private previewText(): string {
    return this.item.text.trim();
  }

  build() {
    Stack() {
      Row({ space: 12 }) {
        Text('“')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.brand)
          .opacity(0.9)
          .margin({ top: 2 })

        Column({ space: 10 }) {
          Text(this.previewText())
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .lineHeight(24)
            .maxLines(this.selectionMode ? 4 : 5)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Column({ space: 2 }) {
            Text(formatInspirationRelativeTime(this.item.updatedAt))
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .width('100%')

            Text('点开后可以继续编辑，或整理成任务与习惯')
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .lineHeight(18)
              .maxLines(2)
              .width('100%')
          }
          .width('100%')
          .opacity(0.86)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({
        left: 18,
        right: 18,
        top: 16,
        bottom: 16
      })
      .attributeModifier(new BlurBackgroundModifier(!!this.customBg, $r('app.color.background_secondary'), BlurStyle.Thick))
      .borderRadius(24)
    }
    .width('100%')
    .borderRadius(24)
    .border({
      width: (this.selectionMode && this.selected) ? 2 : 0,
      color: this.theme.brand
    })
    .clip(true)
    .attributeModifier(new PressEffectModifier(0.98))
    .gesture(
      GestureGroup(GestureMode.Exclusive,
        LongPressGesture()
          .onAction((): void => {
            if (!this.selectionMode) {
              this.onLongPressSelect();
            }
          }),
        TapGesture()
          .onAction((): void => {
            if (this.selectionMode) {
              this.onToggleSelect();
            } else {
              this.onCardClick();
            }
          })
      )
    )
  }
}

@Component
export struct InspirationItemSwipeable {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  item: InspirationItem = { id: 0, text: '', createdAt: '', updatedAt: '' };
  selectionMode: boolean = false;
  selected: boolean = false;
  onCardClick: () => void = (): void => {};
  onPrimaryAction: () => void = (): void => {};
  onSecondaryAction: () => void = (): void => {};

  @State private offsetX: number = 0;
  @State private cardWidth: number = 0;

  build() {
    Stack() {
      Row() {
        Row() {
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.wand_and_stars'))
              .fontSize(20)
              .fontColor([Color.White])
          }
          .width(40)
          .height(40)
          .backgroundColor(this.theme.brand)
          .onClick((): void => this.onPrimaryAction())
        }
        .layoutWeight(1)
        .padding({ left: 20 })
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center)

        Row() {
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.trash'))
              .fontSize(20)
              .fontColor([Color.White])
          }
          .width(40)
          .height(40)
          .backgroundColor($r('app.color.chart_red'))
          .onClick((): void => this.onSecondaryAction())
        }
        .layoutWeight(1)
        .padding({ right: 20 })
        .justifyContent(FlexAlign.End)
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height(104)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(24)
      .clip(true)

      InspirationItemCard({
        item: this.item,
        selectionMode: this.selectionMode,
        selected: this.selected,
        onCardClick: this.onCardClick
      })
      .translate({ x: this.offsetX })
      .onAreaChange((oldArea, newArea) => {
        this.cardWidth = newArea.width as number;
      })
      .gesture(
        GestureGroup(GestureMode.Exclusive,
          PanGesture({ direction: PanDirection.Horizontal })
            .onActionUpdate((event) => {
              if (this.selectionMode) {
                return;
              }
              this.offsetX = event.offsetX;
            })
            .onActionEnd(() => {
              if (this.selectionMode) {
                return;
              }

              const threshold = this.cardWidth * 0.36;
              if (this.offsetX > threshold) {
                this.onPrimaryAction();
                this.resetSwipe();
              } else if (this.offsetX < -threshold) {
                this.onSecondaryAction();
                this.resetSwipe();
              } else {
                this.resetSwipe();
              }
            }),
          TapGesture()
            .onAction(() => {
              this.onCardClick();
            })
        )
      )
    }
    .width('100%')
    .height(104)
  }

  private resetSwipe(): void {
    animateTo({ duration: 260, curve: Curve.FastOutSlowIn }, () => {
      this.offsetX = 0;
    })
  }
}

@Component
export struct InspirationSearchCard {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  item: InspirationItem = { id: 0, text: '', createdAt: '', updatedAt: '' };
  onCardClick: () => void = (): void => {};
  onDelete: () => void = (): void => {};
  onAiTask: () => void = (): void => {};
  onAiHabit: () => void = (): void => {};

  build() {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Text('“')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.brand)
          .opacity(0.9)

        Column({ space: 8 }) {
          Text(this.item.text.trim())
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .lineHeight(23)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .maxLines(4)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Column({ space: 2 }) {
            Text(formatInspirationRelativeTime(this.item.updatedAt))
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .width('100%')

            Text('保留它的原始样子，\n之后再整理')
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .lineHeight(18)
              .maxLines(2)
              .width('100%')
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }

      Row({ space: 8 }) {
        Button('AI 任务')
          .type(ButtonType.Capsule)
          .fontSize(13)
          .height(32)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .onClick((): void => {
            this.onAiTask();
          })

        Button('AI 习惯')
          .type(ButtonType.Capsule)
          .fontSize(13)
          .height(32)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .onClick((): void => {
            this.onAiHabit();
          })

        Blank()
          .layoutWeight(1)

        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.trash'))
            .fontSize(18)
            .fontColor([$r('app.color.chart_red')])
        }
        .width(32)
        .height(32)
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .onClick((): void => {
          this.onDelete();
        })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.background_secondary'))
    .borderRadius(22)
    .onClick((): void => this.onCardClick())
  }
}

@Component
export struct InspirationEditSheet {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @Link isShow: boolean;
  @Link draftText: string;
  item: InspirationItem | null = null;

  onSave: () => Promise<void> = async (): Promise<void> => {};
  onDelete: () => Promise<void> = async (): Promise<void> => {};
  onAiTask: () => void = (): void => {};
  onAiHabit: () => void = (): void => {};
  onDirectTask: () => void = (): void => {};
  onDirectHabit: () => void = (): void => {};

  @State isManualPopupShow: boolean = false;

  @Builder
  private manualPopupBuilder() {
    Column({ space: 6 }) {
      Button('直接整理成任务')
        .type(ButtonType.Capsule)
        .width('100%')
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .onClick((): void => {
          this.isManualPopupShow = false;
          this.onDirectTask();
        })

      Button('直接整理成习惯')
        .type(ButtonType.Capsule)
        .width('100%')
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .onClick((): void => {
          this.isManualPopupShow = false;
          this.onDirectHabit();
        })
    }
    .width(180)
    .padding(10)
  }

  build() {
    HdsNavigation() {
      Column() {
        Blank().height(56)

        Text("先别急着把它变得太正式，等它成熟一点，再决定要不要整理成任务或习惯。")
          .fontColor($r('app.color.font_secondary'))
          .fontSize(14)
          .lineHeight(22)
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 12 })

        Column({ space: 12 }) {
          TextArea({ text: this.draftText, placeholder: '在这里继续补充它，或让它先安静地待着。' })
            .width('100%')
            .height(260)
            .fontSize(16)
            .lineHeight(24)
            .backgroundColor($r('sys.color.comp_background_secondary'))
            .borderRadius(24)
            .padding(16)
            .onChange((value: string) => {
              this.draftText = value;
            })

          Row({ space: 10 }) {
            Button('AI 整理成任务')
              .type(ButtonType.Capsule)
              .layoutWeight(1)
              .height(40)
              .backgroundColor(this.theme.brand)
              .fontColor(Color.White)
              .onClick((): void => this.onAiTask())

            Button('AI 整理成习惯')
              .type(ButtonType.Capsule)
              .layoutWeight(1)
              .height(40)
              .backgroundColor(this.theme.brand50)
              .fontColor(this.theme.brand)
              .onClick((): void => this.onAiHabit())
          }

          Row({ space: 10 }) {
            Button({ type: ButtonType.Circle }) {
              SymbolGlyph($r('sys.symbol.text_and_arrow_down'))
                .fontSize(18)
                .fontColor([$r('sys.color.ohos_id_color_text_primary')])
            }
            .width(36)
            .height(36)
            .backgroundColor($r('sys.color.comp_background_secondary'))
            .onClick((): void => {
              this.isManualPopupShow = true;
            })
            .bindPopup(this.isManualPopupShow, {
              builder: this.manualPopupBuilder,
              placement: Placement.Top,
              mask: false,
              enableArrow: true,
              onStateChange: (event) => {
                if (!event.isVisible) {
                  this.isManualPopupShow = false;
                }
              }
            })

            Text('手动直接整理放在这里，需要时再用。')
              .layoutWeight(1)
              .fontSize(12)
              .lineHeight(18)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))

            Button('删除')
              .type(ButtonType.Capsule)
              .height(36)
              .backgroundColor($r('sys.color.comp_background_secondary'))
              .fontColor($r('app.color.chart_red'))
              .onClick((): void => { void this.onDelete(); })
          }
          .width('100%')
        }
        .padding({ left: 16, right: 16 })

        Blank().height(56)
      }
      .width('100%')
      .height('100%')
    }
    .titleBar({
      content: {
        title: { mainTitle: "编辑灵感" },
        menu: {
          value: [{ content: { icon: $r('sys.symbol.checkmark'), action: async () => this.onSave() } }]
        },
        subIcon: {
          content: {
            icon: $r('sys.symbol.xmark'),
            action: () => {
              this.isShow = false;
            }
          }
        }
      }
    })
    .titleMode(HdsNavigationTitleMode.MODAL)
    .hideBackButton(false)
    .backgroundColor(Color.Transparent)
  }
}
