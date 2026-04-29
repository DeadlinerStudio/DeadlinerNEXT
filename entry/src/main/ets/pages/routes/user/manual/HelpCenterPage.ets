import { HdsNavDestination, HdsNavDestinationAttribute } from '@kit.UIDesignKit';
import { TopSafeContainer } from '../../../components/TopSafeContainer';
import { SettingsSection, SettingsItem, SettingsDivider } from '../../../components/SettingsComponents';
import { ManualSection, ManualItem, ManualDataManager } from '../../../../common/manual/ManualModel';
import { common } from '@kit.AbilityKit';
import { ITheme } from '../../../../common/theme/ThemeModel';
import { getImmersiveTitleBarStyle } from '../../../../common/style/NavStyles';

@Component
export struct HelpCenterPage {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageProp('statusBarHeight') statusBarHeight: number = 38;
  readonly TITLE_BAR_CONTENT_HEIGHT: number = 18;

  @State sections: ManualSection[] = [];
  @State isLoading: boolean = true;

  aboutToAppear() {
    this.loadData();
  }

  async loadData() {
    this.isLoading = true;
    const context = getContext(this) as common.UIAbilityContext;
    this.sections = await ManualDataManager.getInstance().loadMenu(context);
    this.isLoading = false;
  }

  build() {
    HdsNavDestination() {
      // TopSafeContainer 内部已有 Scroll，这里只需放入静态布局
      TopSafeContainer({ topAvoidHeight: this.statusBarHeight + this.TITLE_BAR_CONTENT_HEIGHT }) {
        if (this.isLoading) {
          Column() {
            LoadingProgress().width(40).height(40).color(this.theme.brand)
          }
          .width('100%').height('100%').justifyContent(FlexAlign.Center)
        } else {
          Column({ space: 16 }) {
            Stack({ alignContent: Alignment.Start }) {
              // A. 背景层
              Column()
                .width('100%')
                .height('100%')
                .linearGradient({
                  angle: 135,
                  colors: [
                    [this.theme.brand, 0.0],
                    [this.theme.brand50, 0.6],
                    ['#803A6EA5', 1.0]
                  ]
                })

              // B. 装饰层
              Stack() {
                SymbolGlyph($r('sys.symbol.book'))
                  .fontSize(120)
                  .fontColor([Color.White])
                  .opacity(0.1)
              }
              .width('100%')
              .height('100%')
              .align(Alignment.BottomEnd)
              .offset({ x: 20, y: 20 })

              // C. 内容层
              Row({ space: 16 }) {
                Image($r('app.media.icon')) // 确保路径正确
                  .width(64)
                  .height(64)
                  .padding(2)

                Column({ space: 4 }) {
                  Text('Deadliner')
                    .fontSize(22)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Color.White)

                  Text('使用手册 & 帮助中心')
                    .fontSize(14)
                    .fontColor(Color.White)
                    .opacity(0.8)
                }
                .alignItems(HorizontalAlign.Start)
              }
              .padding(24)
              .width('100%')
              .alignItems(VerticalAlign.Center)
            }
            .width('100%')
            .height(120)
            .borderRadius(24)
            .clip(true)
            .shadow({ radius: 12, color: '#26000000', offsetY: 4 })

            // --- 2. 列表内容区域 ---
            ForEach(this.sections, (section: ManualSection) => {
              Column() {
                SettingsSection({ title: section.title }) {
                  ForEach(section.items, (item: ManualItem, index: number) => {
                    SettingsItem({
                      title: item.title,
                      icon: item.icon,
                      isImage: item.isImage,
                      onItemClick: () => {
                        this.appPathStack.pushPath({
                          name: 'helpDetail',
                          param: item
                        })
                      }
                    })
                    if (index < section.items.length - 1) {
                      SettingsDivider()
                    }
                  })
                }
              }
            })

            Blank().height(50)
          }
          .width('100%')
          .padding(16)
          .justifyContent(FlexAlign.Start)
          .constraintSize({ minHeight: '100%' })
        }
      }
    }
    .titleBar({
      style: getImmersiveTitleBarStyle(false),
      content: { title: { mainTitle: "使用手册" } }
    })
  }
}

@Builder
export function HelpCenterPageBuilder() {
  HelpCenterPage()
}