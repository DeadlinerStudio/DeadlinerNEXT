import { ThemeManager } from '../../../../../common/theme/ThemeManager';
import { ThemeMap, ITheme } from '../../../../../common/theme/ThemeModel';
import { ColorCustomizer } from './ColorCustomizer';
import { HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigation, HdsNavigationTitleMode, HdsNavigationAttribute, HdsNavDestinationAttribute } from '@kit.UIDesignKit';
import { TopSafeContainer } from '../../../../components/TopSafeContainer';
import { FloatUpModifier } from '../../../../../utils/animation/FloatUpModifier';
import { SettingsItem, SettingsSection, SettingsDivider, SubSettingsSwitch } from '../../../../components/SettingsComponents';
import { IndicatorThemeSheet } from './IndicatorThemeSelect';
import { deviceInfo } from '@kit.BasicServicesKit';
import { WidgetUpdater } from '../../../../../utils/WidgetUpdater';

interface ThemeOption {
  key: string;
  name: string;
  previewBg: ResourceColor;
}

const THEME_OPTIONS: ThemeOption[] = [
  { key: 'vibrant', name: '生动 (默认)', previewBg: $r('sys.color.search_container_focus_color') },
  { key: 'classic', name: '莫兰迪', previewBg: $r('sys.color.search_container_focus_color') },
  { key: 'nature', name: '清新', previewBg: $r('sys.color.search_container_focus_color') },
  { key: 'sunset', name: '暖阳', previewBg: $r('sys.color.search_container_focus_color') },
  { key: 'lavender', name: '极光', previewBg: $r('sys.color.search_container_focus_color') },
  { key: 'time', name: '时光', previewBg: $r('sys.color.search_container_focus_color') },
  { key: 'harmony', name: '鸿蒙', previewBg: $r('sys.color.search_container_focus_color') },
  { key: 'galaxy', name: '星河', previewBg: $r('sys.color.search_container_focus_color') },
  { key: 'glacier', name: '冰川', previewBg: $r('sys.color.search_container_focus_color') },
  { key: 'tiktick', name: '活力', previewBg: $r('sys.color.search_container_focus_color') },
];

@Component
export struct ThemeSelectSheet {
  @Provide('navPathStack') navStack: NavPathStack = new NavPathStack();
  @StorageProp('currentThemeKey') currentKey: string = 'vibrant';
  @StorageProp('currentTheme') @Watch('syncThemeWhiteGlow') theme: ITheme = {} as ITheme;
  @State themeWhiteGlow: boolean = false;

  onDone?: () => void;

  aboutToAppear(): void {
    this.syncThemeWhiteGlow();
  }

  syncThemeWhiteGlow() {
    this.themeWhiteGlow = this.theme.useWhiteGlow ?? false;
  }

  @Builder
  navDestination(name: string) {
    if (name === 'ColorCustomizer') {
      HdsNavDestination() {
        Column() {
          TopSafeContainer({ topAvoidHeight: 72, bgColor: Color.Transparent }) {
            ColorCustomizer()
              .padding({ left: 16, right: 16, bottom: 20 })
          }
        }
        .backgroundBlurStyle(BlurStyle.Regular)
      }
      .titleBar({
        content: {
          title: { mainTitle: "自定义颜色" },
          menu: {
            value: [
              {
                content: {
                  icon: $r('sys.symbol.xmark'),
                  action: () => { if (this.onDone) this.onDone(); }
                }
              }
            ]
          }
        },
      })
      .titleMode(HdsNavDestinationTitleMode.MODAL)
      .backgroundColor(Color.Transparent)
      .onBackPressed(() => {
        this.navStack.pop();
        return true;
      })
      .mode(NavDestinationMode.DIALOG)
      .systemTransition(NavigationSystemTransitionType.SLIDE_RIGHT)
    } else if (name === 'ChartCustomizer') {
      HdsNavDestination() {
        Column() {
          TopSafeContainer({ topAvoidHeight: 72, bgColor: Color.Transparent }) {
            IndicatorThemeSheet()
          }
        }
        .backgroundBlurStyle(BlurStyle.Regular)
      }
      .titleBar({
        content: {
          title: { mainTitle: "图表颜色" },
          menu: {
            value: [
              {
                content: {
                  icon: $r('sys.symbol.xmark'),
                  action: () => { if (this.onDone) this.onDone(); }
                }
              }
            ]
          }
        },
      })
      .titleMode(HdsNavDestinationTitleMode.MODAL)
      .backgroundColor(Color.Transparent)
      .onBackPressed(() => {
        this.navStack.pop();
        return true;
      })
      .mode(NavDestinationMode.DIALOG)
      .systemTransition(NavigationSystemTransitionType.SLIDE_RIGHT)
    }
  }

  build() {
    HdsNavigation(this.navStack) {
      Column() {
        TopSafeContainer({ topAvoidHeight: 72, bgColor: Color.Transparent }) {
          SettingsSection({ bgColor: $r('sys.color.search_container_focus_color') }) {
            SettingsItem({
              title: '图表颜色',
              subtitle: '自定义概览统计图表颜色',
              icon: $r('sys.symbol.data_proportion'),
              onItemClick: () => {
                this.navStack.pushPath({ name: 'ChartCustomizer' })
              }
            })
          }

          Column().height(12)

          if (deviceInfo.distributionOSApiVersion >= 60100) {
            SettingsSection({ bgColor: $r('sys.color.search_container_focus_color') }) {
              SubSettingsSwitch({
                title: '白光辉映',
                subtitle: '控制沉浸光感标签栏是否显示白色高光；该设置跟随当前主题。',
                isOn: $themeWhiteGlow,
                onChange: async (isOn): Promise<void> => {
                  this.themeWhiteGlow = isOn;
                  await ThemeManager.setCurrentThemeWhiteGlow(isOn);
                }
              })
            }
          }

          Column().height(12)

          this.ThemePresetList()
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
    }
    .titleBar({
      content: {
        title: { mainTitle: "选择主题" },
        menu: {
          value: [
            {
              content: {
                icon: $r('sys.symbol.xmark'),
                action: () => { if (this.onDone) this.onDone(); }
              }
            }
          ]
        }
      },
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .titleMode(HdsNavigationTitleMode.MODAL)
    .navDestination(this.navDestination)
    .hideBackButton(true)
    .backgroundColor(Color.Transparent)
    .mode(NavigationMode.Stack)
    .backgroundBlurStyle(BlurStyle.Regular)
  }

  // === 首页：预设列表内容 ===
  @Builder
  ThemePresetList() {
    GridRow({ columns: 2, gutter: 12 }) {
      ForEach(THEME_OPTIONS, (item: ThemeOption, idx) => {
        GridCol() {
          this.ThemeItemBuilder(item)
        }
        .attributeModifier(new FloatUpModifier(idx))
      })

      // 自定义入口卡片
      GridCol() {
        this.CustomEntryCardBuilder()
      }
      .attributeModifier(new FloatUpModifier(THEME_OPTIONS.length + 1))

      GridCol() {
        Column() { Blank() }.height(70)
      }

      GridCol() {
        Column() { Blank() }.height(70)
      }
    }
    .width('100%')
  }

  // === 组件：自定义入口卡片 ===
  @Builder
  CustomEntryCardBuilder() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Stack({ alignContent: Alignment.Center }) {
          Circle({ width: 48, height: 48 })
            .fill($r('sys.color.container_modal_background'))

          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(24)
            .fontColor([$r('app.color.icon_secondary')])
        }
        .width('100%')
        .height(80)

        Text('自定义')
          .fontSize(14)
          .fontColor($r('app.color.font_primary'))
          .fontWeight(FontWeight.Medium)
          .margin({ top: 12 })
      }
      .width('100%')
      .padding(12)
      .borderRadius(24)
      .backgroundColor($r('sys.color.search_container_focus_color'))
      .onClick(() => {
        this.navStack.pushPath({ name: 'ColorCustomizer' });
      })
    }
  }

  // === 组件：主题卡片 ===
  @Builder
  ThemeItemBuilder(item: ThemeOption) {
    Stack({ alignContent: Alignment.TopEnd }) {
      // 1. 卡片主体内容
      Column() {
        // --- A. 预览区域 (占据主要空间) ---
        // 这里使用 Column + Row 构成正三角形布局
        Column() {
          // 顶点：开关
          Row() {
            Toggle({ type: ToggleType.Switch, isOn: true })
              .selectedColor(ThemeMap[item.key].brand)
              .height(20) // 视觉调整，稍微小一点更精致
              .hitTestBehavior(HitTestMode.None) // 禁用交互
          }
          .width('100%')
          .justifyContent(FlexAlign.Center) // 居中
          .margin({ bottom: 8 })

          // 底边：按钮 + 图标
          Row() {
            // 左下角：+号按钮
            Button({ type: ButtonType.Circle }) {
              SymbolGlyph($r('sys.symbol.plus'))
                .fontSize(24) // 尺寸适中
                .fontWeight(FontWeight.Normal) // ✅ 改回正常粗细
                .fontColor([Color.White])
            }
            .width(44)
            .height(44)
            .backgroundColor(ThemeMap[item.key].accent)
            .shadow({ radius: 6, color: '#33000000', offsetY: 3 }) // 增加阴影提升质感
            .hitTestBehavior(HitTestMode.None)

            // 右下角：Tab图标
            SymbolGlyph($r('sys.symbol.house_fill')) // 使用实心图标更有分量
              .fontSize(36) // ✅ 加大图标
              .fontColor([ThemeMap[item.key].tabIcon]) // ✅ 使用 tabIcon 颜色
              .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY)
              .symbolEffect(new BounceSymbolEffect(EffectScope.WHOLE, EffectDirection.DOWN))
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceAround) // 在行内均匀分布，形成三角形底边
          .alignItems(VerticalAlign.Center)
        }
        .layoutWeight(1) // 让预览区自动撑开高度
        .width('100%')
        .justifyContent(FlexAlign.Center) // 垂直居中内容
        .padding({ top: 8 })

        // --- B. 文字区域 (独立，不重叠) ---
        Column() {
          Text(item.name)
            .fontSize(14)
            .fontColor($r('app.color.font_primary'))
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .height(32) // 给文字固定高度区域
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height(140)
      .padding({ top: 8, bottom: 4, left: 12, right: 12 })
      .borderRadius(24)
      .backgroundColor(item.previewBg)
      .border({
        width: 2,
        // 选中时边框变色，未选中透明
        color: this.currentKey === item.key ? ThemeMap[item.key].brand : Color.Transparent
      })
      .onClick(async () => {
        await ThemeManager.switchUITheme(item.key);
        const context = this.getUIContext().getHostContext();
        if (context) {
          await WidgetUpdater.updateAllWidgets(context);
        }
      })

      // 2. 选中态：右上角悬浮旗标 (Floating Circle)
      if (this.currentKey === item.key) {
        Stack({ alignContent: Alignment.Center }) {
          Circle({ width: 24, height: 24 })
            .fill(ThemeMap[item.key].brand)

          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontColor([Color.White])
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
        }
        .margin({ top: 8, right: 8 }) // ✅ 距离边框有间距，形成“悬浮”感
      }
    }
    .animation({ duration: 250, curve: Curve.FastOutSlowIn })
  }
}
