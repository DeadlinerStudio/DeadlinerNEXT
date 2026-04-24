import { ThemeManager } from '../../../../../common/theme/ThemeManager';
import { IndicatorMap, IndicatorSet } from '../../../../../common/theme/ThemeModel';
import { FloatUpModifier } from '../../../../../utils/animation/FloatUpModifier';

interface IndicatorOption {
  key: string;
  name: string;
  desc: string;
}

const INDICATOR_OPTIONS: IndicatorOption[] = [
  { key: 'ios', name: 'iOS', desc: '系统蓝绿橙红，清爽直接' },
  { key: 'morandi', name: '莫兰迪', desc: '低饱和度，柔和护眼' },
  { key: 'vibrant', name: '生动', desc: '现代扁平，清晰明了' },
  { key: 'nature', name: '森系', desc: '自然大地，清新舒适' },
  { key: 'ocean', name: '深海', desc: '冷调青蓝，冷静专注' },
  { key: 'retro', name: '复古', desc: '胶片暖调，怀旧质感' }
];

@Component
export struct IndicatorThemeSheet {
  @StorageProp('currentIndicatorKey') currentKey: string = 'ios';

  onDone?: () => void;

  build() {
    List({ space: 12 }) {
      ForEach(INDICATOR_OPTIONS, (item: IndicatorOption, idx: number) => {
        ListItem() {
          this.IndicatorItemBuilder(item)
        }
        .attributeModifier(new FloatUpModifier(idx))
      })

      // 底部留白
      ListItem().height(40)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .padding({ left: 16, right: 16 })
  }

  @Builder
  IndicatorItemBuilder(item: IndicatorOption) {
    Row() {
      // === 左侧：文字信息 (自动撑开剩余空间) ===
      Column({ space: 4 }) {
        Text(item.name)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.font_primary'))

        Text(item.desc)
          .fontSize(12)
          .fontColor($r('app.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .padding({ right: 12 }) // 防止文字贴到右边的图表

      // === 右侧：仪表盘预览区 ===
      Row({ space: 12 }) {

        Row({ space: 4 }) {
          this.MiniBar(IndicatorMap[item.key].chartInfo, 10)
          this.MiniBar(IndicatorMap[item.key].chartCompleted, 18)
          this.MiniBar(IndicatorMap[item.key].chartTodo, 14)
          this.MiniBar(IndicatorMap[item.key].chartOverdue, 6)
        }
        .alignItems(VerticalAlign.Bottom)
        .height(28)

        // 2. 双层圆环 (使用 Progress 组件完美对齐)
        Stack({ alignContent: Alignment.Center }) {
          // 外环：Undergo (主色)
          Progress({ value: 75, total: 100, type: ProgressType.Ring })
            .width(28)
            .height(28)
            .color(IndicatorMap[item.key].indicatorUndergo)     // 前景
            .backgroundColor(IndicatorMap[item.key].bgUndergo)  // 背景轨道
            .style({ strokeWidth: 3 })                          // 线宽

          // 内环：Near (辅助/警告色)
          Progress({ value: 60, total: 100, type: ProgressType.Ring })
            .width(16)
            .height(16)
            .color(IndicatorMap[item.key].indicatorNear)
            .backgroundColor(IndicatorMap[item.key].bgNear)
            .style({ strokeWidth: 3 })
            .rotate({ angle: 180 }) // 稍微转一下角度，错落有致
        }
      }
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .borderRadius(12)

      // === 选中状态 Checkmark ===
      // 这里的策略改为：不选中时不占位 (width=0)，选中时挤出来
      if (this.currentKey === item.key) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(20)
          .fontColor([$r('app.color.brand')])
          .fontWeight(FontWeight.Bold)
          .margin({ left: 12 }) // 选中时给左边加个间距，推开预览框
          .transition(
            TransitionEffect.asymmetric(
              TransitionEffect.OPACITY.animation({ duration: 200 }),
              TransitionEffect.OPACITY.animation({ duration: 150 })
            )
          )
      }
    }
    .width('100%')
    .height(72)
    // 动态调整右侧内边距：
    // 选中时，已有 margin-left 推开，padding 可以小一点
    // 未选中时，padding 给足，保证美观
    .padding({ left: 16, right: this.currentKey === item.key ? 16 : 16 })
    .borderRadius(20)
    .backgroundColor($r('sys.color.search_container_focus_color'))
    .border({
      width: 2,
      // 直接属性判断，无中间变量
      color: (this.currentKey === item.key) ? $r('app.color.brand') : Color.Transparent
    })
    .onClick(() => {
      // 配合 animateTo 让布局挤压变动更平滑
      animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
        ThemeManager.switchIndicatorStyle(item.key);
      })
    })
  }

  @Builder
  MiniBar(color: ResourceColor, height: number) {
    Column()
      .width(6)
      .height(height)
      .borderRadius(3)
      .backgroundColor(color)
  }
}
