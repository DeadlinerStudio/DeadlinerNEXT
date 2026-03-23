import { DividerShowType, HdsNavigation, HdsNavigationAttribute, HdsNavigationTitleMode, ScrollEffectType } from "@kit.UIDesignKit";
import { LengthMetrics, promptAction } from "@kit.ArkUI";
import { SettingsDivider,
  SettingsGridItem,
  SettingsItem, SettingsSection, SettingsSwitch,
  SettingsUserProfile,
  SettingsVerticalDivider} from "../../components/SettingsComponents";
import { TopSafeContainer } from "../../components/TopSafeContainer";
import { common, bundleManager } from "@kit.AbilityKit";
import { LocalValues } from "../../../common/local/LocalValues";
import { WebParams } from "../../common/WebBrowserPage";
import { SettingsConstants as C } from '../../../common/local/SettingsConstants';
import { HuaweiAccountUtils } from "../../../utils/account/HuaweiAccountUtils";
import { FloatUpModifier } from "../../../utils/animation/FloatUpModifier";
import { CodeTextParams } from "../../common/CodeTextPage";
import { ArchivePanelView } from "../../common/ArchivePanelView";
import { AIPanelView } from "../../common/AIPanelView";
import { SupportPanelView } from "../../common/SupportPanelView";
import { getImmersiveTitleBarStyle } from "../../../common/style/NavStyles";
import { ITheme } from "../../../common/theme/ThemeModel";
import { FriendshipLinksPage } from "./settings/FriendshipLinksPage";

const USER_ROUTE_WHITELIST: string[] = [
  'settingsAppearance',
  'settingsInteraction',
  'settingsNotification',
  'settingsWebDav',
  'settingsAI',
  'settingsAbout',
  'settingsHelpCenter',
  'settingsWidgetBackground'
];

const PLACEHOLDER_ROUTE_NAME = 'placeholder';

@Component
export struct UserPage {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @Consume('appPathStack') appPathStack: NavPathStack;
  @Provide('userLocalPathStack') userLocalPathStack: NavPathStack = new NavPathStack();

  @StorageLink('isWideScreen') @Watch('onScreenModeChange') isWideScreen: boolean = false;
  @StorageLink(C.KEY_ENABLE_TABLET_UI) @Watch('onScreenModeChange') tabletUi: boolean = true;

  @StorageProp('statusBarHeight') statusBarHeight: number = 38;

  readonly TITLE_BAR_CONTENT_HEIGHT: number = 18;

  @StorageLink(C.KEY_BASIC_MODE) isBasicMode: boolean = false;

  onScreenModeChange() {
    console.info(`[UserPage] Screen Mode Change Detected. Wide: ${this.isWideScreen}`);

    setTimeout(() => {
      if ((this.isWideScreen && this.tabletUi)) {
        this.migrateToLocal();
      } else {
        this.migrateToGlobal();
      }
    }, 100);
  }

  /**
   * 将全局栈顶的 User 相关页面移动到局部栈 (Narrow -> Wide)
   */
  private migrateToLocal() {
    const allGlobalPaths = this.appPathStack.getAllPathName();

    for (let i = allGlobalPaths.length - 1; i >= 0; i--) {
      const name = allGlobalPaths[i];

      if (USER_ROUTE_WHITELIST.includes(name)) {
        const pathInfo = this.appPathStack.pop();

        if (pathInfo) {
          console.info(`[Router] Migrating ${name} from Global to Local`);
          this.userLocalPathStack.pushPath(pathInfo, false);
        }
      } else {
        break;
      }
    }

    if (this.userLocalPathStack.size() === 0) {
      console.info('[Router] Local stack empty, pushing placeholder.');
      this.userLocalPathStack.pushPath({ name: PLACEHOLDER_ROUTE_NAME }, false);
    }
  }

  /**
   * 将局部栈的所有页面移动到全局栈 (Wide -> Narrow)
   */
  private migrateToGlobal() {
    const allLocalPaths = this.userLocalPathStack.getAllPathName();

    if (allLocalPaths.length === 0) return;

    const stackBackup: NavPathInfo[] = [];
    const size = this.userLocalPathStack.size();

    for(let i=0; i<size; i++) {
      const item = this.userLocalPathStack.pop();
      if(item) stackBackup.push(item);
    }

    for (let i = stackBackup.length - 1; i >= 0; i--) {
      const item = stackBackup[i];
      if (item.name === PLACEHOLDER_ROUTE_NAME) {
        console.info('[Router] Dropping placeholder page during migration.');
        continue;
      }
      console.info(`[Router] Migrating ${item.name} from Local to Global`);
      this.appPathStack.pushPath(item, false); // false = 无动画
    }
  }

  @State versionName: string = '';
  aboutToAppear(): void {
    try {
      let bundleInfo = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      this.versionName = bundleInfo.versionName;
    } catch (error) {
      console.error('获取版本号失败:', JSON.stringify(error));
      this.versionName = '1.0.0'; // 失败时的默认值
    }

    if ((this.isWideScreen && this.tabletUi) && this.userLocalPathStack.size() === 0) {
      this.userLocalPathStack.pushPath({ name: PLACEHOLDER_ROUTE_NAME }, false);
    }
  }

  private showTurnOnBasicDialog() {
    AlertDialog.show({
      title: '开启基础模式',
      message: '开启后将清除所有高级设置（AI Key、WebDAV 账号等）并退出当前华为账号。\n\n此操作不可撤销，确定要继续吗？',
      autoCancel: false,
      alignment: DialogAlignment.Bottom,
      offset: { dx: 0, dy: -20 },
      backgroundBlurStyle: BlurStyle.Regular,
      primaryButton: {
        value: '取消',
        action: () => {
          this.isBasicMode = false;
        },
        fontColor: this.theme.brand
      },
      secondaryButton: {
        value: '确认开启',
        fontColor: $r('app.color.warning'),
        action: async () => {
          // 1. 清除高级设置
          await LocalValues.getInstance().clearAllAdvancedSettings();

          new HuaweiAccountUtils().signOut();
          AppStorage.setOrCreate('isLoggedIn', false);
          // 3. 设置基础模式为 true
          LocalValues.getInstance().setBasicMode(true);
        }
      }
    });
  }

  @State isArchiveSheetShow: boolean = false;
  @Builder
  archiveSheet() {
    ArchivePanelView()
      .width('100%')
      .height('100%')
  }

  @State isAISheetShow: boolean = false;
  @Consume('isAiFlowShown') isAiFlowShown: boolean;

  private flowTimerId: number = -1;

  openAiPanel() {
    clearTimeout(this.flowTimerId);

    this.isAISheetShow = true;

    this.isAiFlowShown = true;

    this.flowTimerId = setTimeout(() => {
      animateTo({ duration: 500, curve: Curve.EaseOut }, () => {
        this.isAiFlowShown = false;
      })
    }, 400);
  }

  closeAiPanel() {
    clearTimeout(this.flowTimerId);

    this.isAISheetShow = false;
    this.isAiFlowShown = false; // 立即关闭，不需要动画了，因为 Sheet 都要没了
  }

  @Builder
  aiSheet() {
    AIPanelView({
      onDismissPanel: () => {
        this.closeAiPanel();
      }
    })
      .width('100%')
      .height('100%')
  }

  @State isSupportSheetShow: boolean = false;

  // 2. 定义 Builder
  @Builder
  supportSheet() {
    SupportPanelView({
      closeAction: () => {
        this.isSupportSheetShow = false;
      }
    })
  }

  private navigateTo(name: string) {
    if ((this.isWideScreen && this.tabletUi)) {
      this.userLocalPathStack.pushPath({ name: name });
    } else {
      this.appPathStack.pushPath({ name: name });
    }
  }

  @State isFriendsSheetShow: boolean = false;
  @Builder
  friendsSheet() {
    FriendshipLinksPage()
  }

  build() {
    HdsNavigation(this.userLocalPathStack) {
      TopSafeContainer({ topAvoidHeight: this.statusBarHeight + this.TITLE_BAR_CONTENT_HEIGHT, needBgTransparent: true }) {
        Column({ space: 16 }) {
          if (!this.isBasicMode) {
            SettingsSection({ mainUserPage: true }) {
              SettingsUserProfile()
            }
          }

          SettingsSection({ mainUserPage: true }) {
            Row() {
              SettingsGridItem({
                title: "归档管理",
                icon: $r('sys.symbol.archivebox_fill'),
                iconColor: $r('app.color.func_archive'),
                onItemClick: () => {
                  this.isArchiveSheetShow = true;
                }
              })

              SettingsVerticalDivider()

              SettingsGridItem({
                title: "AI 助理",
                icon: $r('sys.symbol.wand_and_stars_fill'),
                iconColor: $r('app.color.func_ai'),
                onItemClick: () => {
                  this.isAISheetShow = true;
                }
              })

              SettingsVerticalDivider()

              SettingsGridItem({
                title: "使用手册",
                icon: $r('sys.symbol.book_open_fill'),
                iconColor: $r('app.color.func_manual'),
                onItemClick: () => {
                  this.navigateTo('settingsHelpCenter')
                }
              })
            }
            .width('100%')
          }

          SettingsSection({ title: '偏好设置', mainUserPage: true }) {
            SettingsItem({
              title: "显示与个性化",
              subtitle: "界面布局 · 动画效果 · 小组件样式",
              icon: $r('sys.symbol.paintpalette'),
              onItemClick: () => {
                this.navigateTo('settingsAppearance');
              }
            })

            SettingsDivider()

            SettingsItem({
              title: "交互与行为",
              subtitle: "启动页 · 操作体验 · 自动归档",
              icon: $r('sys.symbol.hand_point_up_tap'),
              onItemClick: () => {
                this.navigateTo('settingsInteraction');
              }
            })

            SettingsDivider()

            SettingsItem({
              title: "通知与提醒",
              subtitle: "DDL 预警 · 每日摘要 · 习惯提醒",
              icon: $r('sys.symbol.bell'),
              onItemClick: () => {
                this.navigateTo('settingsNotification');
              }
            })
          }

          if (!this.isBasicMode) {
            SettingsSection({ title: '数据与服务', mainUserPage: true }) {
              SettingsItem({
                title: "数据同步与备份",
                subtitle: "WebDAV 云同步 · 本地导入导出",
                icon: $r('sys.symbol.cloud'),
                onItemClick: () => {
                  this.navigateTo('settingsWebDav');
                }
              })

              SettingsDivider()

              SettingsItem({
                title: "AI 智能服务",
                subtitle: "模型配置 · API Key",
                icon: $r('sys.symbol.AI'),
                onItemClick: () => {
                  this.navigateTo('settingsAI')
                }
              })

              SettingsDivider()

              SettingsSwitch({
                title: "基础模式",
                subtitle: "仅保留核心任务管理功能",
                icon: $r('sys.symbol.leaf'),
                isOn: this.isBasicMode,
                onChange: (isOn) => {
                  if (isOn) {
                    this.showTurnOnBasicDialog();
                  } else {
                    LocalValues.getInstance().setBasicMode(false);
                  }
                }
              })
            }
          } else {
            SettingsSection({ title: '模式切换', mainUserPage: true }) {
              SettingsSwitch({
                title: "基础模式",
                subtitle: "仅保留核心任务管理功能",
                icon: $r('sys.symbol.leaf'),
                isOn: this.isBasicMode,
                onChange: (isOn) => {
                  if (isOn) {
                    this.showTurnOnBasicDialog();
                  } else {
                    LocalValues.getInstance().setBasicMode(false);
                  }
                }
              })
            }
          }

          SettingsSection({ title: "更多", mainUserPage: true }) {
            SettingsItem({
              title: "关于与协议",
              subtitle: `版本 ${this.versionName} · 开发故事 · 隐私政策与许可`,
              icon: $r('sys.symbol.info_circle'),
              onItemClick: () => {
                this.navigateTo('settingsAbout');
              }
            })

            SettingsDivider()

            SettingsItem({
              title: "支持与反馈",
              subtitle: "捐赠 · 评分 · 开源共建",
              icon: $r('sys.symbol.gift'),
              onItemClick: () => {
                this.isSupportSheetShow = true;
              }
            })

            SettingsDivider()

            SettingsItem({
              title: "朋友们",
              subtitle: "来看看其他好友的优秀作品！",
              icon: $r('sys.symbol.application_projection'),
              onItemClick: () => {
                this.isFriendsSheetShow = true;
              }
            })
          }

          // 底部留白

          Blank().height(30)
            .bindSheet($$this.isFriendsSheetShow, this.friendsSheet(), {
              height: SheetSize.FIT_CONTENT,
              enableOutsideInteractive: false,
              dragBar: true,
              onDisappear: () => {
                this.isFriendsSheetShow = false;
              },
              blurStyle: BlurStyle.Regular,
              backgroundColor: Color.Transparent,
              title: { title: "友链" }
            })

          Blank().height(30)
            .bindSheet($$this.isSupportSheetShow, this.supportSheet(), {
              height: SheetSize.FIT_CONTENT,
              enableOutsideInteractive: false,
              dragBar: true,
              onDisappear: () => {
                this.isSupportSheetShow = false;
              },
              blurStyle: BlurStyle.Regular,
              backgroundColor: Color.Transparent,
              title: { title: "支持与反馈" }
            })
        }
        .width('100%')
        .padding({ left: 12, right: 12 })
        .justifyContent(FlexAlign.Start)
        .constraintSize({ minHeight: '100%' })
        .bindSheet($$this.isArchiveSheetShow, this.archiveSheet(), {
          height: SheetSize.FIT_CONTENT,
          dragBar: true,
          enableOutsideInteractive: false,
          onDisappear: () => {
            this.isArchiveSheetShow = false;
          },
          blurStyle: BlurStyle.Regular,
          backgroundColor: Color.Transparent,
          title: {
            title: '归档',
            subtitle: '可以在此处管理你已完成的任务'
          },
        })
      }
    }
    .titleBar({
      style: getImmersiveTitleBarStyle((this.isWideScreen && this.tabletUi)),
      content: {
        title: {
          mainTitle: '我的'
        },
        // divider: { showType: DividerShowType.OFF },
      }
    })
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
    .bindSheet($$this.isAISheetShow, this.aiSheet(), {
      height: SheetSize.LARGE,
      dragBar: true,
      enableOutsideInteractive: false,
      onDisappear: () => {
        this.closeAiPanel();
      },
      blurStyle: BlurStyle.Regular,
      backgroundColor: Color.Transparent,
      title: {
        title: 'Deadliner AI',
      }
    })
    .padding({ top: (this.isWideScreen && this.tabletUi) ? this.statusBarHeight : 0 })
    .mode((this.isWideScreen && this.tabletUi) ? NavigationMode.Split : NavigationMode.Stack)
    .navBarWidth((this.isWideScreen && this.tabletUi) ? '40%' : '100%')
  }
}