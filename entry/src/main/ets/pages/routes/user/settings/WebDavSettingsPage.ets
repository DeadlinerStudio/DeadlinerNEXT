import { SettingsConstants } from "../../../../common/local/SettingsConstants";
import { LocalValues } from "../../../../common/local/LocalValues";
import { promptAction, SymbolGlyphModifier } from '@kit.ArkUI';
import { SettingsSection, SubSettingsSwitch, SettingsCheckItem, SettingsDivider } from "../../../components/SettingsComponents"; // 记得确保导入了 SettingsCheckItem 和 SettingsDivider
import { HelpDetailPage } from "../manual/HelpDetailPage";
import { ManualDataManager, ManualItem } from "../../../../common/manual/ManualModel";
import { HelpDetailSheet } from "../manual/HelpDetailSheet";
import { ITheme } from "../../../../common/theme/ThemeModel";
import { common } from '@kit.AbilityKit';
import { TaskRepository } from "../../../../common/repository/TaskRepository";
import { HdsNavDestination, HdsNavDestinationAttribute } from "@kit.UIDesignKit";
import { getImmersiveTitleBarStyle } from "../../../../common/style/NavStyles";
import { TopSafeContainer } from "../../../components/TopSafeContainer";

// 选项接口定义
interface SyncOption {
  text: string;
  value: string;
}

@Builder
export function SettingsWebDavBuilder(name: string, param: Object) {
  SettingsWebDavPage() // 为了不破坏你原有的路由，组件名保留
}

@Component
export struct SettingsWebDavPage {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @StorageProp('statusBarHeight') statusBarHeight: number = 38;
  readonly TITLE_BAR_CONTENT_HEIGHT: number = 18;

  // Navigation 路由栈引用
  pageStack: NavPathStack = new NavPathStack();

  @StorageLink('isWideScreen') isWideScreen: boolean = false;

  @StorageLink(SettingsConstants.KEY_CLOUD_SYNC_ENABLE) syncEnable: boolean = false;
  // 新增：绑定当前的同步模式 (cloud 或 webdav)
  @StorageLink(SettingsConstants.KEY_CLOUD_SYNC_MODE) syncMode: string = 'cloud';

  @StorageLink(SettingsConstants.KEY_WEBDAV_URL) webUrl: string = '';
  @StorageLink(SettingsConstants.KEY_WEBDAV_USERNAME) username: string = '';
  @StorageLink(SettingsConstants.KEY_WEBDAV_PASSWORD) password: string = '';
  @StorageLink(SettingsConstants.KEY_TOMBSTONE_RETENTION_DAYS) tombstoneRetentionDays: number = 30;

  @State isSyncing: boolean = false;
  @State buttonBg: ResourceColor = $r('sys.color.brand');

  // 同步方式的选项配置
  private readonly syncOptions: SyncOption[] = [
    { text: '华为端云协同', value: 'cloud' },
    { text: 'WebDAV', value: 'webdav' }
  ];

  onWillApplyTheme(theme: Theme): void {
    this.buttonBg = theme.colors.brand
  }

  @State isHelpSheetShow: boolean = false;
  @Builder
  helpSheet() {
    HelpDetailSheet({
      item: ManualDataManager.getInstance().getItemById("webdav_config")
    })
  }

  build() {
    HdsNavDestination() {
      TopSafeContainer({ topAvoidHeight: this.statusBarHeight + this.TITLE_BAR_CONTENT_HEIGHT }) {
        Column({ space: 16 }) {
          // 1. 同步主开关
          SettingsSection() {
            SubSettingsSwitch({
              title: "启用云同步",
              isOn: this.syncEnable,
              onChange: (isOn) => {
                LocalValues.getInstance().setCloudSyncEnable(isOn)
              }
            })
          }

          if (this.syncEnable) {

            // 2. 选择同步方式 (仿照你的 SettingsSection 示例)
            SettingsSection({ title: '同步方式' }) {
              ForEach(this.syncOptions, (item: SyncOption, index: number) => {
                SettingsCheckItem({
                  title: item.text,
                  isSelected: this.syncMode === item.value,
                  onItemClick: async () => {
                    this.syncMode = item.value;
                    // 异步写入用户的选择
                    await LocalValues.getInstance().setSyncMode(item.value);
                  }
                })
                if (index < this.syncOptions.length - 1) {
                  SettingsDivider()
                }
              })
            }

            // 3. 根据选择动态渲染不同的配置项
            if (this.syncMode === 'cloud') {
              // 华为云空间提示
              Text("系统将自动使用华为账号的云空间进行端云协同。请确保在“系统设置 -> 云空间”中已开启本应用的同步权限。数据将在您的多台鸿蒙设备间无缝流转。")
                .fontSize(12)
                .fontColor($r('app.color.font_secondary'))
                .padding({ left: 8, right: 8 })

            } else if (this.syncMode === 'webdav') {
              // WebDAV 配置项
              Text("由于我们本身并不提供云服务，需要用户提供支持 WebDAV 服务的云盘账户。账号与密码将在本地存储，不会上传至我们的服务器。")
                .fontSize(12)
                .fontColor($r('app.color.font_secondary'))
                .padding({ left: 8, right: 8 })

              SettingsSection() {
                TextInput({ text: this.webUrl, placeholder: 'WebDAV 地址 (例如 https://dav.jianguoyun.com/dav/)' })
                  .type(InputType.URL)
                  .backgroundColor(Color.Transparent)
                  .onChange((value) => {
                    this.webUrl = value;
                  })
                  .onSubmit(() => {
                    LocalValues.getInstance().setWebDavUrl(this.webUrl);
                  })

                SettingsDivider()

                TextInput({ text: this.username, placeholder: '用户名' })
                  .backgroundColor(Color.Transparent)
                  .onChange((value) => {
                    this.username = value;
                  })

                SettingsDivider()

                TextInput({ text: this.password, placeholder: '应用授权码 / 密码' })
                  .type(InputType.Password)
                  .backgroundColor(Color.Transparent)
                  .onChange((value) => {
                    this.password = value;
                  })
              }
            }

            Divider().color(Color.Transparent).height(12)

            // 4. 保存并测试按钮
            SettingsSection({ title: '墓碑回收' }) {
              Text('已删除记录保留天数')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .width('100%')

              Text('删除后的同步墓碑会保留 N 天，之后自动回收，减少 snapshot 体积和垃圾数据堆积。设为 0 表示永久保留。')
                .fontSize(12)
                .fontColor($r('app.color.font_secondary'))
                .margin({ top: 6, bottom: 8 })

              TextInput({ text: `${this.tombstoneRetentionDays}`, placeholder: '默认 30，0 表示永久保留' })
                .type(InputType.Number)
                .backgroundColor(Color.Transparent)
                .onChange((value: string) => {
                  const parsed = parseInt(value.length > 0 ? value : '0');
                  this.tombstoneRetentionDays = isNaN(parsed) || parsed < 0 ? 0 : parsed;
                })
                .onSubmit(async () => {
                  await LocalValues.getInstance().setTombstoneRetentionDays(this.tombstoneRetentionDays);
                })
            }

            Button(this.isSyncing ? '正在同步...' : '保存并立即同步', { type: ButtonType.Capsule })
              .width('90%')
              .buttonStyle(ButtonStyleMode.EMPHASIZED)
              .controlSize(ControlSize.NORMAL)
              .backgroundColor(this.buttonBg)
              .onClick(async () => {
                if (this.isSyncing) return;

                this.isSyncing = true;
                try {
                  // 如果是 WebDAV 模式，先保存输入框里的凭据
                  if (this.syncMode === 'webdav') {
                    LocalValues.getInstance().setWebDavAuth(this.username, this.password);
                    LocalValues.getInstance().setWebDavUrl(this.webUrl);
                  }
                  await LocalValues.getInstance().setTombstoneRetentionDays(this.tombstoneRetentionDays);

                  promptAction.showToast({ message: '开始同步...' });

                  const repo = TaskRepository.getInstance();
                  repo.setContext(getContext(this) as common.UIAbilityContext);

                  // 执行同步
                  const success = await repo.syncNow();

                  if (success) {
                    promptAction.showToast({ message: '同步成功！' });
                    getContext(this).eventHub.emit('sync_done');
                  } else {
                    promptAction.showToast({ message: '无数据变更或同步遇到问题，请检查网络/配置。' });
                  }
                } catch (e) {
                  console.error(`Sync Error: ${e}`);
                  promptAction.showToast({ message: `发生错误: ${e.message}` });
                } finally {
                  this.isSyncing = false;
                }
              })
          }
        }
        .width('100%')
        .padding(16)
        .justifyContent(FlexAlign.Start)
        .constraintSize({ minHeight: '100%' })
      }
    }
    .titleBar({
      style: getImmersiveTitleBarStyle(this.isWideScreen),
      content: {
        title: { mainTitle: "云同步设置" },
        menu: {
          value: [
            {
              content: {
                icon: $r('sys.symbol.questionmark_circle'),
                action: () => { this.isHelpSheetShow = true }
              }
            }
          ]
        }
      }
    })
    .onReady((context: NavDestinationContext) => {
      this.pageStack = context.pathStack;
    })
    .bindSheet($$this.isHelpSheetShow, this.helpSheet(), {
      title: { title: '同步配置指南' },
      detents: [
        SheetSize.FIT_CONTENT,
        SheetSize.MEDIUM,
        SheetSize.LARGE
      ],
      height: SheetSize.FIT_CONTENT,
      enableOutsideInteractive: false,
      dragBar: true,
      backgroundColor: Color.Transparent,
      blurStyle: BlurStyle.Regular,
      onDisappear: () => { this.isHelpSheetShow = false },
    })
  }
}
