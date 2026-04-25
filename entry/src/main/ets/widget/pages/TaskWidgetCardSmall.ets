import { WidgetData, WidgetTaskItem } from '../model/WidgetData';

@Entry
@Component
struct TaskWidgetCardSmall {
  @LocalStorageProp('widgetData') data: WidgetData = new WidgetData();

  // --- 颜色资源 ---
  readonly COLOR_ITEM_BG: Resource = $r('app.color.widget_item_bg');
  // 自定义背景下的半透明 Item 背景
  readonly COLOR_SEMI_ITEM_BG: ResourceColor = '#99000000';
  readonly COLOR_SEMI_WHITE_BG: ResourceColor = '#99FFFFFF';

  readonly FONT_PRIMARY: Resource = $r('app.color.font_primary');
  readonly FONT_SECONDARY: Resource = $r('app.color.font_secondary');

  private getThemeKey(): string {
    switch (this.data.themeKey) {
      case 'classic':
      case 'time':
      case 'vibrant':
      case 'nature':
      case 'sunset':
      case 'lavender':
      case 'harmony':
      case 'galaxy':
      case 'glacier':
      case 'tiktick':
        return this.data.themeKey;
      default:
        return 'classic';
    }
  }

  getAccentColor(): ResourceColor {
    switch (this.getThemeKey()) {
      case 'vibrant': return $r('app.color.accent_vibrant');
      case 'nature': return $r('app.color.accent_nature');
      case 'sunset': return $r('app.color.accent_sunset');
      case 'lavender': return $r('app.color.accent_lavender');
      case 'glacier': return $r('app.color.accent_glacier');
      case 'tiktick': return $r('app.color.accent_tik');
      default: return $r('app.color.accent');
    }
  }

  getBrandColor(): ResourceColor {
    switch (this.getThemeKey()) {
      case 'vibrant': return $r('app.color.brand_vibrant');
      case 'nature': return $r('app.color.brand_nature');
      case 'sunset': return $r('app.color.brand_sunset');
      case 'lavender': return $r('app.color.brand_lavender');
      case 'glacier': return $r('app.color.brand_glacier');
      case 'tiktick': return $r('app.color.brand_tik');
      case 'harmony':
      case 'galaxy':
        return $r('sys.color.ohos_id_color_emphasize');
      default: return $r('app.color.brand');
    }
  }

  getWidgetBgStartColor(): ResourceColor {
    switch (this.getThemeKey()) {
      case 'time': return $r('app.color.widget_bg_grad_start_time');
      case 'vibrant': return $r('app.color.widget_bg_grad_start_vibrant');
      case 'nature': return $r('app.color.widget_bg_grad_start_nature');
      case 'sunset': return $r('app.color.widget_bg_grad_start_sunset');
      case 'lavender': return $r('app.color.widget_bg_grad_start_lavender');
      case 'harmony': return $r('app.color.widget_bg_grad_start_harmony');
      case 'galaxy': return $r('app.color.widget_bg_grad_start_galaxy');
      case 'glacier': return $r('app.color.widget_bg_grad_start_glacier');
      case 'tiktick': return $r('app.color.widget_bg_grad_start_tiktick');
      default: return $r('app.color.widget_bg_grad_start_classic');
    }
  }

  getWidgetBgEndColor(): ResourceColor {
    switch (this.getThemeKey()) {
      case 'time': return $r('app.color.widget_bg_grad_end_time');
      case 'vibrant': return $r('app.color.widget_bg_grad_end_vibrant');
      case 'nature': return $r('app.color.widget_bg_grad_end_nature');
      case 'sunset': return $r('app.color.widget_bg_grad_end_sunset');
      case 'lavender': return $r('app.color.widget_bg_grad_end_lavender');
      case 'harmony': return $r('app.color.widget_bg_grad_end_harmony');
      case 'galaxy': return $r('app.color.widget_bg_grad_end_galaxy');
      case 'glacier': return $r('app.color.widget_bg_grad_end_glacier');
      case 'tiktick': return $r('app.color.widget_bg_grad_end_tiktick');
      default: return $r('app.color.widget_bg_grad_end_classic');
    }
  }

  getWidgetDecorColor(): ResourceColor {
    switch (this.getThemeKey()) {
      case 'time': return $r('app.color.widget_decor_time');
      case 'vibrant': return $r('app.color.widget_decor_vibrant');
      case 'nature': return $r('app.color.widget_decor_nature');
      case 'sunset': return $r('app.color.widget_decor_sunset');
      case 'lavender': return $r('app.color.widget_decor_lavender');
      case 'harmony': return $r('app.color.widget_decor_harmony');
      case 'galaxy': return $r('app.color.widget_decor_galaxy');
      case 'glacier': return $r('app.color.widget_decor_glacier');
      case 'tiktick': return $r('app.color.widget_decor_tiktick');
      default: return $r('app.color.widget_decor_classic');
    }
  }

  /**
   * 判断是否使用了自定义背景
   */
  isCustomBg(): boolean {
    return !!(this.data.backgroundImage && this.data.backgroundImage.length > 0);
  }

  /**
   * 判断是否使用白色文字（根据图片分析结果）
   */
  isWhiteText(): boolean {
    if (!this.data.backgroundImage) return false;
    return this.data.isWhiteText;
  }

  /**
   * 获取 Item 背景颜色
   */
  getItemBgColor(): ResourceColor {
    if (this.data.backgroundImage && this.data.backgroundImage.length > 0) {
      if (this.isWhiteText()) {
        return this.COLOR_SEMI_ITEM_BG; // 半透明黑
      } else {
        return this.COLOR_SEMI_WHITE_BG; // 半透明白
      }
    }
    return this.COLOR_ITEM_BG;
  }

  /**
   * 获取主要文字颜色
   */
  getPrimaryFontColor(): ResourceColor {
    if (this.data.backgroundImage) {
      return this.isWhiteText() ? Color.White : '#E6000000';
    }
    return this.FONT_PRIMARY;
  }

  /**
   * 获取次要文字颜色
   */
  getSecondaryFontColor(): ResourceColor {
    if (this.data.backgroundImage) {
      return this.isWhiteText() ? '#CCFFFFFF' : '#99000000';
    }
    return this.FONT_SECONDARY;
  }

  aboutToAppear() {
    console.info(`[TaskWidgetCardSmall] Initialized.`);
  }

  build() {
    Stack() {
      // --- 1. 背景层 ---
      if (this.data.backgroundImage && this.data.backgroundImage.length > 0) {
        // A. 自定义背景图片 (保持不变)
        Image(this.data.backgroundImage)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      } else {
        // B. 默认渐变背景 + 水波纹效果 (修改处)
        Stack() {
          // 1.1 基础渐变底色
          Rect()
            .width('100%')
            .height('100%')
            .fill(this.getWidgetBgStartColor())
            .linearGradient({
              angle: 135,
              colors: [
                [this.getWidgetBgStartColor(), 0.0],
                [this.getWidgetBgEndColor(), 1.0]
              ]
            })

          // 1.2 波纹 - 外圈 (大，极淡)
          Circle()
            .width(200) // 2x2 尺寸较大，圆圈可以画大一点
            .height(200)
            .fill(this.getWidgetDecorColor())
            .opacity(0.03) // 非常淡，作为背景氛围
            .position({ x: '30%', y: '-20%' }) // 从右上角晕开

          // 1.3 波纹 - 中圈 (稍小，稍显)
          Circle()
            .width(140)
            .height(140)
            .fill(this.getWidgetDecorColor())
            .opacity(0.06)
            .position({ x: '55%', y: '-5%' })
        }
        .width('100%')
        .height('100%')
      }

      // --- 2. 内容层 (保持不变) ---
      Column() {
        // --- 顶部栏 ---
        Row() {
          Image($r('app.media.icon'))
            .width(18)
            .height(18)
            .borderRadius(4)
            .margin({ right: 6 })

          Text("Deadliner")
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getPrimaryFontColor())
            .layoutWeight(1)
            .maxLines(1)
            .textShadow(this.data.backgroundImage ? { radius: 2, color: '#40000000' } : undefined)

          if (this.data.totalCount > 0) {
            Text(`${this.data.totalCount}`)
              .fontSize(10)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.data.totalCount > 3 ? this.getAccentColor() : this.getBrandColor())
              .backgroundColor(this.getItemBgColor())
              .padding({ left: 5, right: 5, top: 1, bottom: 1 })
              .borderRadius(6)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // --- 任务列表 ---
        if (this.data.tasks.length === 0) {
          this.EmptyState()
        } else {
          List({ space: 6 }) {
            ForEach(this.data.tasks.slice(0, 3), (item: WidgetTaskItem) => {
              ListItem() {
                this.CompactTaskItem(item)
              }
            })
          }
          .width('100%')
          .layoutWeight(1)
          .margin({ top: 8 })
        }
      }
      .width('100%')
      .height('100%')
      .padding(10)
    }
    .width('100%')
    .height('100%')
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: { target: 'main' }
      });
    })
  }

  @Builder
  CompactTaskItem(item: WidgetTaskItem) {
    Row() {
      // 左侧指示条
      Column()
        .width(3)
        .height(12)
        .backgroundColor(item.isUrgent ? this.getAccentColor() : this.getBrandColor())
        .borderRadius(1.5)
        .margin({ right: 6 })

      // 标题
      Text(item.title)
        .fontSize(12)
        .fontColor(this.getPrimaryFontColor())
        .fontWeight(item.isUrgent ? FontWeight.Medium : FontWeight.Normal)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      // 时间
      Text(item.timeDesc)
        .fontSize(10)
        .fontColor(item.isUrgent ? this.getAccentColor() : this.getSecondaryFontColor())
        .fontWeight(item.isUrgent ? FontWeight.Medium : FontWeight.Normal)
        .margin({ left: 4 })
        .maxLines(1)
        .flexShrink(0)
    }
    .width('100%')
    .height(30)
    .backgroundColor(this.getItemBgColor())
    .borderRadius(8)
    .padding({ left: 6, right: 8 })
    .alignItems(VerticalAlign.Center)
    .border({
      width: (item.isUrgent && !this.data.backgroundImage) ? 1 : 0,
      color: this.getAccentColor()
    })
  }

  @Builder
  EmptyState() {
    Column() {
      Text('🎉')
        .fontSize(30)
        .margin({ bottom: 4 })
        .textShadow(this.data.backgroundImage ? { radius: 10, color: '#80FFFFFF' } : undefined)

      Text("全部搞定")
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.FONT_PRIMARY)
        .opacity(0.8)
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .width('100%')
  }
}

@Builder
export function TaskWidgetCardSmallPreviewBuilder() {
  TaskWidgetCardSmall()
    .borderRadius(20)
    .clip(true)
    .width(150)
    .height(150)
}
