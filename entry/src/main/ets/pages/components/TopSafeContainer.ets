import { LengthMetrics } from '@kit.ArkUI'
import { ITheme } from '../../common/theme/ThemeModel';

/**
 * 顶部安全避让容器
 * * 作用：
 * 1. 提供一个全屏的 Scroll 容器，允许内容延伸到屏幕顶端（状态栏/标题栏区域）。
 * 2. 在内容顶部自动添加一个指定高度的 Blank 占位符，确保内容初始位置在安全区下方。
 * 3. 配合内部 List 的 nestedScroll，实现“向上滚动时占位符消失，内容穿透到顶部模糊区”的效果。
 */
@Component
export struct TopSafeContainer {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  @StorageProp('customBackgroundImage') customBg: string = '';

  @BuilderParam content: () => void;

  @State bgColor: Resource | Color | ResourceColor = this.theme.bgPrimary;
  @Prop needBgTransparent: boolean = false;

  // 顶部需要避让的高度（通常是 状态栏高度 + 标题栏高度）
  @Prop topAvoidHeight: number = 0;

  scrollable: boolean = true

  // 外层滚动控制器
  scroller: Scroller = new Scroller();

  build() {
    if (this.scrollable) {
      Scroll(this.scroller) {
        Column() {
          // 1. 物理占位符 (Spacer)
          // 初始时占据顶部空间，滚动时随 Scroll 向上卷出屏幕
          Blank()
            .width('100%')
            .height(this.topAvoidHeight)

          // 2. 实际内容插槽
          if (this.content) {
            this.content()
          }
        }
        .width('100%')

        // 注意：Column 不设高度，由内容撑开
      }
      .width('100%')
      .height('100%')
      .backgroundColor((this.needBgTransparent && this.customBg) ? Color.Transparent : this.bgColor)
      .scrollBar(BarState.Off) // 隐藏外层滚动条，视觉更纯净
      .edgeEffect(EdgeEffect.Spring)
      .nestedScroll({
        scrollForward: NestedScrollMode.PARENT_FIRST,
        scrollBackward: NestedScrollMode.SELF_FIRST
      })
      // 关键：允许外层 Scroll 延伸到屏幕边缘（包括状态栏区域）
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM, SafeAreaEdge.TOP])
    } else {
      Column() {
        // 1. 物理占位符 (Spacer)
        // 初始时占据顶部空间，滚动时随 Scroll 向上卷出屏幕
        Blank()
          .width('100%')
          .height(this.topAvoidHeight)

        // 2. 实际内容插槽
        if (this.content) {
          this.content()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor((this.needBgTransparent && this.customBg) ? Color.Transparent : this.bgColor)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM, SafeAreaEdge.TOP])
    }
  }
}