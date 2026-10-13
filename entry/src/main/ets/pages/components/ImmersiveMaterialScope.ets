import { deviceInfo } from '@kit.BasicServicesKit';

/** 局部材质作用域：布局尺寸与绘制余量分开，避免负边距和材质外沿被 TabBar 截断。 */
@Component
export struct ImmersiveMaterialScope {
  @Prop scopeWidth: Length = '100%';
  @Prop scopeHeight: number = 40;
  // 内部 TabBar 仍有裁剪边界；为内容外沿预留绘制空间，不计入父容器布局。
  @Prop overflowInset: number = 24;
  @BuilderParam content: () => void;

  @Builder
  private materialContent() {
    Column() {
      Stack({ alignContent: Alignment.Top }) {
        this.content()
      }
      .width('100%')
      .height(this.scopeHeight)
      .clip(false)
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .padding(this.overflowInset)
    .width('100%')
    .height(this.scopeHeight + this.overflowInset * 2)
    .backgroundColor(Color.Transparent)
    .clip(false)
    .hitTestBehavior(HitTestMode.Transparent)
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      if (deviceInfo.apiAvailable('26.0.0')) {
        Tabs({ barPosition: BarPosition.End }) {
          TabContent() {
          }
          .tabBar(this.materialContent())
        }
        .width('calc(100% + ' + (this.overflowInset * 2).toString() + 'vp)')
        .height(this.scopeHeight + this.overflowInset * 2)
        .position({ x: -this.overflowInset, y: -this.overflowInset })
        .barWidth('100%')
        .barHeight(this.scopeHeight + this.overflowInset * 2)
        .barMode(BarMode.Fixed)
        .scrollable(false)
        .animationDuration(0)
        .fadingEdge(false)
        .divider(null)
        .barBackgroundColor(Color.Transparent)
        .barBackgroundBlurStyle(BlurStyle.NONE)
        .backgroundColor(Color.Transparent)
        .shadow({ radius: 0 })
        .clip(false)
        .hitTestBehavior(HitTestMode.Transparent)
      } else {
        this.content()
      }
    }
    .width(this.scopeWidth)
    .height(this.scopeHeight)
    .clip(false)
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
