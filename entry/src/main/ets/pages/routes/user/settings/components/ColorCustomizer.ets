import { ColorGenerator, AccentOption } from '../../../../../utils/ColorGenerator';
import { ThemeManager } from '../../../../../common/theme/ThemeManager';
import { SettingsSection, SubSettingsSwitch } from '../../../../components/SettingsComponents';
import { promptAction } from '@kit.ArkUI';
import { IndicatorMap, IndicatorSet } from '../../../../../common/theme/ThemeModel';
import { WidgetUpdater } from '../../../../../utils/WidgetUpdater';

interface ChartOption {
  key: string;
  name: string;
  colors: IndicatorSet;
}

@Component
export struct ColorCustomizer {
  // === 状态管理 ===
  @State hue: number = 210; // 初始蓝色
  @State styleStrength: number = 50; // 0=莫兰迪, 100=生动

  // 计算出的当前颜色
  @State currentBrand: string = '#FF000000';
  @State currentAccent: string = '#FF000000';

  @State selectedChartKey: string = 'ios';
  private chartOptions: ChartOption[] = [
    { key: 'ios', name: 'iOS', colors: IndicatorMap['ios'] },
    { key: 'morandi', name: '莫兰迪', colors: IndicatorMap['morandi'] },
    { key: 'vibrant', name: '生动', colors: IndicatorMap['vibrant'] },
    { key: 'nature', name: '森系', colors: IndicatorMap['nature'] },
    { key: 'ocean', name: '深海', colors: IndicatorMap['ocean'] },
    { key: 'retro', name: '复古', colors: IndicatorMap['retro'] }
  ];

  @State enableColdTab: boolean = false;

  // Accent 策略
  @State accentStrategies: AccentOption[] = [];
  @State selectedAccentKey: string = 'mono';

  async aboutToAppear() {
    await this.restoreSavedState();
    this.updateColors();
  }

  private async restoreSavedState() {
    const config = await ThemeManager.getCustomConfig();

    // 只有当当前确认为自定义主题时，才覆盖默认值
    if (config.isCustom) {
      this.hue = config.hue;
      this.styleStrength = config.styleStrength;

      // 如果你想让之前的 accent 选择也大概恢复
      // (虽然 accentStrategies 是重新生成的，但可以尝试匹配颜色)
      this.currentBrand = config.brand; // 先赋个初值防止闪烁
      this.selectedChartKey = config.indicatorKey;
    }
  }

  // 核心刷新逻辑
  private updateColors() {
    if (!ColorGenerator) return;

    // 1. 生成 Brand
    const brandSwatch = ColorGenerator.generateBrand(this.hue, this.styleStrength);
    this.currentBrand = brandSwatch.color;

    // 2. 生成推荐的 Accents
    // 计算当前近似的饱和度传给生成器，保证 Accent 风格一致
    const estimatedSat = 15 + (this.styleStrength / 100) * (90 - 15);
    this.accentStrategies = ColorGenerator.generateAccentStrategies(this.hue, estimatedSat);

    // 3. 更新当前选中的 Accent
    const activeStrategy = this.accentStrategies.find(s => s.key === this.selectedAccentKey);
    this.currentAccent = activeStrategy ? activeStrategy.color : this.currentBrand;
  }

  build() {
    Column({ space: 16 }) {

      SettingsSection({ bgColor: $r('sys.color.search_container_focus_color') }) {
        // === 1. 核心预览区 (复用三角形布局) ===
        ThemePreviewCard({
          brandColor: this.currentBrand,
          accentColor: this.currentAccent,
          tabColor: this.enableColdTab ? $r('app.color.cold') : this.currentBrand
        })
          .margin({ top: 10 })
      }

      // === 2. 调色控制区 ===
      Column({ space: 16 }) {
        // A. 色相调节
        SettingsSection({ bgColor: $r('sys.color.search_container_focus_color') }) {
          Column({ space: 10 }) {
            Row() {
              Text("色调 (Hue)").fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
              Blank()
              Text(`${this.hue.toFixed(0)}°`).fontSize(12).fontColor($r('sys.color.font_tertiary'))
            }.width('100%')

            HueSlider({
              hue: $hue, onHueChange: (val) => {
                this.hue = val;
                this.updateColors();
              }
            })
          }
          .padding({ left: 12, right: 12, top: 12, bottom: 12 })
        }

        // B. 风格调节 (莫兰迪 -> 生动)
        SettingsSection({ bgColor: $r('sys.color.search_container_focus_color') }) {
          Column({ space: 10 }) {
            Row() {
              Text("风格 (Style)").fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
              Blank()
              Text(this.styleStrength < 40 ? "莫兰迪" : (this.styleStrength > 70 ? "生动" : "标准"))
                .fontSize(12).fontColor($r('sys.color.font_tertiary'))
            }.width('100%')

            // 使用系统 Slider，自定义轨道颜色体现渐变
            Slider({
              value: this.styleStrength,
              min: 0,
              max: 100,
              style: SliderStyle.OutSet,
            })
              .selectedColor(this.currentBrand) // 滑块颜色跟随品牌色
              .showSteps(false)
              .onChange((val) => {
                this.styleStrength = val;
                this.updateColors();
              })
          }
          .padding({ left: 12, right: 12, top: 12, bottom: 12 })
        }
      }

      SettingsSection({ bgColor: $r('sys.color.search_container_focus_color') }) {
        SubSettingsSwitch({
          title: '灰度菜单栏颜色',
          subtitle: '底部 (平板模式下为侧边) 页签栏的图标会以黑白形式显示',
          isOn: this.enableColdTab,
          onChange: (isOn) => { this.enableColdTab = isOn; }
        })
      }

      // === 3. 强调色推荐 (Accent) ===
      SettingsSection({ bgColor: $r('sys.color.search_container_focus_color') }) {
        Column({ space: 10 }) {
          Text("搭配强调色 (Accent)")
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')

          List({ space: 12 }) {
            ForEach(this.accentStrategies, (item: AccentOption) => {
              ListItem() {
                Column({ space: 8 }) {
                  // 颜色圈
                  Stack({ alignContent: Alignment.Center }) {
                    Circle({ width: 56, height: 56 })
                      .fill(item.color)

                    // 选中态外圈
                    if (this.selectedAccentKey === item.key) {
                      Circle({ width: 62, height: 62 })
                        .fill(Color.Transparent)
                        .stroke(item.color)
                        .strokeWidth(2)

                      SymbolGlyph($r('sys.symbol.checkmark'))
                        .fontColor([Color.White])
                        .fontSize(20)
                    }
                  }
                  .animation({ duration: 200 })

                  Text(item.name)
                    .fontSize(12)
                    .fontColor(this.selectedAccentKey === item.key ? $r('app.color.font_primary') :
                      $r('sys.color.font_tertiary'))
                }
                .onClick(() => {
                  this.selectedAccentKey = item.key;
                  this.updateColors();
                })
                .padding(2)
              }
            })
          }
          .listDirection(Axis.Horizontal)
          .alignListItem(ListItemAlign.Center)
          .width('100%')
          .scrollBar(BarState.Off)
          .height(96)
        }
        .padding({ left: 12, right: 12, top: 12, bottom: 12 })
      }

      SettingsSection({ bgColor: $r('sys.color.search_container_focus_color') }) {
        Column({ space: 10 }) {
          Text("图表配色 (Charts)")
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')

          List({ space: 12 }) {
            ForEach(this.chartOptions, (item: ChartOption) => {
              ListItem() {
                Column({ space: 8 }) {
                  // 1. 颜色预览条 (模拟图表)
                  Stack({ alignContent: Alignment.Center }) {
                    // 背景容器
                    Row({ space: 2 }) {
                      // 展示 4 个核心色
                      this.ColorBar(item.colors.chartInfo, 14)
                      this.ColorBar(item.colors.chartCompleted, 24)
                      this.ColorBar(item.colors.chartTodo, 18)
                      this.ColorBar(item.colors.chartOverdue, 10)
                    }
                    .height(56)
                    .width(56)
                    .justifyContent(FlexAlign.Center)
                    .alignItems(VerticalAlign.Bottom)
                    .backgroundColor($r('sys.color.comp_background_tertiary')) // 浅灰底
                    .borderRadius(12)
                    .border({
                      width: 2,
                      // 选中时高亮边框
                      color: this.selectedChartKey === item.key ? this.currentBrand : Color.Transparent
                    })
                    .animation({ duration: 200 })

                    // 选中对勾
                    if (this.selectedChartKey === item.key) {
                      Stack() {
                        Circle({ width: 18, height: 18 })
                          .fill(this.currentBrand)
                        SymbolGlyph($r('sys.symbol.checkmark'))
                          .fontSize(10)
                          .fontColor([Color.White])
                          .fontWeight(FontWeight.Bold)
                      }
                      .position({ x: 42, y: -4 }) // 右上角角标
                    }
                  }

                  Text(item.name)
                    .fontSize(12)
                    .fontColor(this.selectedChartKey === item.key ? $r('app.color.font_primary') :
                      $r('sys.color.font_tertiary'))
                }
                .onClick(() => {
                  this.selectedChartKey = item.key;
                  // 这里不需要调用 updateColors，因为它不影响 Brand 计算
                  // 但如果你的 ThemePreviewCard 里将来要展示图表色，就需要刷新
                })
                .padding(2)
              }
            })
          }
          .listDirection(Axis.Horizontal)
          .alignListItem(ListItemAlign.Center)
          .width('100%')
          .scrollBar(BarState.Off)
          .height(96)
        }
        .padding({ left: 12, right: 12, top: 12, bottom: 12 })
      }

      // === 4. 底部应用按钮 ===
      Button('应用主题')
        .width('90%')
        .buttonStyle(ButtonStyleMode.EMPHASIZED)
        .controlSize(ControlSize.NORMAL)
        .backgroundColor(this.currentBrand)
        .onClick(async () => {
          await ThemeManager.applyCustomColors(
            this.currentBrand, this.currentAccent,
            this.enableColdTab ? $r('app.color.cold') : this.currentBrand,
            this.selectedChartKey,
            this.hue, this.styleStrength
          );
          const context = this.getUIContext().getHostContext();
          if (context) {
            await WidgetUpdater.updateAllWidgets(context);
          }
          promptAction.showToast({
            message: '主题设置成功！'
          })
        })
        .margin({ bottom: 40 })
    }
  }

  @Builder
  ColorBar(color: ResourceColor, height: number) {
    Column()
      .width(8)
      .height(height)
      .backgroundColor(color)
      .borderRadius(4)
  }
}


// =========================================
// 子组件：Hue 滑动条 (UI优化版)
// =========================================
@Component
struct HueSlider {
  @Link hue: number;
  onHueChange?: (val: number) => void;

  @State trackWidth: number = 0;
  private thumbSize: number = 28;

  private startHue: number = 0;

  getThumbOffset(): number {
    if (this.trackWidth <= this.thumbSize) return 0;
    return (this.hue / 360) * (this.trackWidth - this.thumbSize);
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      // 1. 彩虹轨道
      Row()
        .width('100%')
        .height(14)
        .borderRadius(7)
        .linearGradient({
          angle: 90,
          colors: [
            ['#FF0000', 0.0], ['#FFFF00', 0.17], ['#00FF00', 0.33],
            ['#00FFFF', 0.50], ['#0000FF', 0.67], ['#FF00FF', 0.83], ['#FF0000', 1.0]
          ]
        })

        .onAreaChange((_o, n) => {
          this.trackWidth = Number(n.width);
        })
        .onTouch((e: TouchEvent) => {
          if (e.type === TouchType.Down) {
            this.updateHueByX(e.touches[0].x);
          }
        })

      // 2. 镂空滑块
      Stack({ alignContent: Alignment.Center }) {
        Circle({ width: this.thumbSize, height: this.thumbSize })
          .fill(Color.White)

        Circle({ width: this.thumbSize - 8, height: this.thumbSize - 8 })
          .fill(this.getHueHex(this.hue))
      }
      .width(this.thumbSize)
      .height(this.thumbSize)
      .offset({ x: this.getThumbOffset(), y: 0 })
      .focusable(false)
      .gesture(
        PanGesture({ fingers: 1 })
          .onActionStart(() => {
            this.startHue = this.hue;
          })
          .onActionUpdate((event: GestureEvent) => {
            this.updateHueByOffset(event.offsetX);
          })
      )
    }
    .width('100%')
    .height(40)
  }

  // 根据绝对坐标更新（用于点击轨道）
  private updateHueByX(localX: number) {
    if (this.trackWidth <= this.thumbSize) return;
    const effectiveWidth = this.trackWidth - this.thumbSize;
    // 修正点击位置，使滑块中心移至手指处
    let touchX = localX - (this.thumbSize / 2);
    this.applyRatio(touchX / effectiveWidth);
  }

  // ✅ 根据偏移量更新（用于平滑拖拽）
  private updateHueByOffset(offsetX: number) {
    if (this.trackWidth <= this.thumbSize) return;
    const effectiveWidth = this.trackWidth - this.thumbSize;
    // 计算起始点对应的位移比例
    const startOffset = (this.startHue / 360) * effectiveWidth;
    // 当前总位移 = 起始位移 + 手势偏移
    const currentOffset = startOffset + offsetX;

    this.applyRatio(currentOffset / effectiveWidth);
  }

  private applyRatio(ratio: number) {
    let r = ratio;
    if (r < 0) r = 0;
    if (r > 1) r = 1;
    const newHue = r * 360;
    this.hue = newHue;
    if (this.onHueChange) {
      this.onHueChange(newHue);
    }
  }

  getHueHex(h: number): string {
    return ColorGenerator.hsvToHex(h, 100, 100);
  }
}

@Component
struct ThemePreviewCard {
  @Prop brandColor: string;
  @Prop accentColor: string;
  @Prop tabColor: string | ResourceColor;

  build() {
    Stack() {
      Column() {
        // --- 1. 顶部：模拟设置项 (承载 Switch) ---
        Row() {
          Column({ space: 4 }) {
            Text("设置项")
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.font_primary'))
            Text("这是设置项的描述")
              .fontSize(12)
              .fontColor($r('app.color.font_secondary'))
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          // 开关：使用品牌色
          Toggle({ type: ToggleType.Switch, isOn: true })
            .selectedColor(this.brandColor)
            .hitTestBehavior(HitTestMode.None) // 仅用于展示
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ bottom: 20 })

        // --- 3. 底部：操作区 (承载 FAB 和 Tab) ---
        Row() {
          // 左侧：FAB 悬浮按钮 (使用 Accent 强调色)
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.plus'))
              .fontSize(28)
              .fontWeight(FontWeight.Medium)
              .fontColor([Color.White])
          }
          .width(56) // 大尺寸预览
          .height(56)
          .backgroundColor(this.accentColor)
          .shadow({ radius: 8, color: this.hexToRgba(this.accentColor, 0.4), offsetY: 4 }) // 带有颜色的阴影
          .hitTestBehavior(HitTestMode.None)

          // 右侧：Tab 图标 (使用 Brand 品牌色)
          Column({ space: 4 }) {
            SymbolGlyph($r('sys.symbol.house_fill'))
              .fontSize(32)
              .fontColor([this.tabColor])
              .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY)
              .symbolEffect(new BounceSymbolEffect(EffectScope.WHOLE, EffectDirection.DOWN))

            // 模拟激活的小点
            Circle({ width: 4, height: 4 })
              .fill(this.tabColor)
          }
          .justifyContent(FlexAlign.Center)
          .padding({ right: 12, top: 8 })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween) // 左右分布
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
    }
    .padding({ top: 12, bottom: 20, left: 24, right: 24 })
  }

  // 辅助函数：简单的 Hex 转 RGBA 用于阴影
  private hexToRgba(hex: string, alpha: number): string {
    // 简单处理 #RRGGBB 格式，实际项目中建议用专门的 ColorUtils
    if (!hex.startsWith('#') || hex.length < 7) return '#33000000';
    // 这里为了演示简单返回黑色半透，如果有工具类可以用工具类生成带颜色的阴影
    return '#40000000';
  }
}
