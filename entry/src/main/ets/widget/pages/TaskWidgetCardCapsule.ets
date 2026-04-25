import { CapsuleWidgetData } from '../model/CapsuleWidgetData';

@Entry
@Component
struct TaskWidgetCardCapsule {
  @LocalStorageProp('widgetData') widgetData: CapsuleWidgetData = new CapsuleWidgetData();

  private getThemeKey(): string {
    switch (this.widgetData.themeKey) {
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
        return this.widgetData.themeKey;
      default:
        return 'classic';
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

  getBrandSoftColor(): ResourceColor {
    switch (this.getThemeKey()) {
      case 'vibrant': return $r('app.color.brand_vibrant_50');
      case 'nature': return $r('app.color.brand_nature_50');
      case 'sunset': return $r('app.color.brand_sunset_50');
      case 'lavender': return $r('app.color.brand_lavender_50');
      case 'glacier': return $r('app.color.brand_glacier_50');
      case 'tiktick': return $r('app.color.brand_tik_50');
      default: return $r('app.color.brand_50');
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

  build() {
    Stack({ alignContent: Alignment.Center }) {

      // ===============================================
      // Layer 1: 背景装饰层
      // ===============================================
      Stack() {
        // 1.1 渐变底色
        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            direction: GradientDirection.RightBottom,
            colors: [
              [this.getWidgetBgStartColor(), 0.0],
              [this.getWidgetBgEndColor(), 1.0]
            ]
          })

        // 1.2 波纹调整
        Circle()
          .width(140)
          .height(140)
          .fill(this.getWidgetDecorColor())
          .opacity(0.05)
          .position({ x: '60%', y: '-15%' })

        Circle()
          .width(90)
          .height(90)
          .fill(this.getWidgetDecorColor())
          .opacity(0.08)
          .position({ x: '75%', y: '10%' })

        // 1.3 小红点装饰
        if (this.widgetData.remainingCount > 0) {
          Circle()
            .width(10)
            .height(10)
            .fill(this.getAccentColor())
            .opacity(0.8)
            .position({ x: '90%', y: '15%' })
        }
      }
      .width('100%')
      .height('100%')
      .borderRadius(16)
      .clip(true)
      .backgroundColor($r('app.color.background_secondary'))

      Row() {
        // --- 左侧：文本信息块 ---
        Column() {
          Text(this.widgetData.summary)
            .fontSize('14vp')
            .fontWeight(FontWeight.Bold)
            .fontColor(this.widgetData.remainingCount > 0 ? $r('app.color.font_primary') : $r('app.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          // 2. 底部鼓励语
          if (this.widgetData.remainingCount > 0) {
            Text('Keep going')
              .fontSize('11vp')
              .fontColor(this.getBrandSoftColor())
              .margin({ top: 4 }) // 稍微拉开一点间距，平衡去掉了顶部文字后的空旷感
          }
        }
        .alignItems(HorizontalAlign.Start) // 左对齐
        .justifyContent(FlexAlign.Center) // 垂直居中
        .layoutWeight(1) // 占据左侧所有剩余空间
        .height('100%')

        // --- 右侧：大数字展示 ---
        Column() {
          if (this.widgetData.remainingCount > 0) {
            // 显示大数字
            Text(this.widgetData.remainingCount.toString())
              .fontSize('40vp')
              .fontWeight(FontWeight.Bold)
              .fontColor(this.getBrandColor())
              .lineHeight('40vp')
              .textAlign(TextAlign.End)
              .height('35vp')
          } else {
            // 显示完成图标
            SymbolGlyph($r('sys.symbol.checkmark_circle'))
              .fontSize('32vp') // 使用 vp
              .fontColor([$r('app.color.confirm')])
          }
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.End)
        .padding({ left: 4 })
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 16, top: 10, bottom: 10 })
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
}
