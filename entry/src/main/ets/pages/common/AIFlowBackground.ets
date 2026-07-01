import {
  HdsVisualComponent,
  HdsSceneController,
  HdsSceneType,
  HdsVisualComponentAttribute
} from '@kit.UIDesignKit';

@Component
export struct AiFlowBackground {

  // 控制器，用于动态更新参数（虽然在这个场景下我们主要是静态配置）
  private sceneController: HdsSceneController = new HdsSceneController()
    .setSceneParams({
      // 背景蒙版颜色：建议使用与你 AI 面板主题匹配的渐变色
      // 这里使用了深色半透明蒙版，让流光更明显
      backgroundMaskColors: [
        0xFF6AA9FF,
        0xFFFFC36A,
        0xFFFF6AE6
      ],
      // 左侧流光：模拟 AI 思考时的蓝色/紫色光晕
      firstEdgeFlowLight: {
        startPos: 0.2, // 流光起始位置（0-1）
        endPos: 0.8,   // 流光结束位置
        color: '#FF007DFF', // 亮蓝色
      },
      // 右侧流光：互补色，增加层次感
      secondEdgeFlowLight: {
        startPos: 0.2,
        endPos: 0.8,
        color: '#FF7F00FF' // 紫色
      }
    });

  build() {
    Stack() {
      // 核心视效组件
      HdsVisualComponent()
        .scene(
          HdsSceneType.DUAL_EDGE_FLOW_LIGHT_WITH_BACKGROUND_MASK,
          this.sceneController,
          () => {
            console.info('AI Flow Light initialized');
          }
        )
        // 确保光效铺满整个背景
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.Transparent)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}