import { promptAction } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { notificationManager } from '@kit.NotificationKit';
import { ITheme } from '../../../common/theme/ThemeModel';
import { LocalValues } from '../../../common/local/LocalValues';
import { SettingsConstants as C } from '../../../common/local/SettingsConstants';
import { AIService } from '../../../ai/AIServcice';
import { ThemeSelectSheet } from '../../routes/user/settings/components/ThemeSelectSheet';
import { ImageCropSheet } from '../../routes/user/settings/components/ImageCropSheet';
import { ThemeManager } from '../../../common/theme/ThemeManager';
import {
  SettingsCheckItem,
  SettingsDivider,
  SettingsItem,
  SettingsSection,
  SettingsSelect,
  SubSettingsDivider,
  SubSettingsSwitch
} from '../../components/SettingsComponents';
import { MATERIAL_OPTIONS } from './OnboardingConfig';
import { MaterialOption, SyncOption } from './OnboardingTypes';
import { GuideContainer } from './OnboardingCorePages';

@Builder
function SetupPageHeader(icon: Resource, title: string, subtitle: string, color: ResourceColor) {
  Column({ space: 16 }) {
    SymbolGlyph(icon)
      .fontSize(56)
      .fontColor([color])
      .margin({ top: 36 })

    Column({ space: 12 }) {
      Text(title)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .textAlign(TextAlign.Center)

      Text(subtitle)
        .fontSize(15)
        .lineHeight(24)
        .fontColor($r('app.color.font_secondary'))
        .textAlign(TextAlign.Center)
    }
    .padding({ left: 8, right: 8 })
  }
  .width('100%')
  .height('42%')
  .justifyContent(FlexAlign.Center)
  .alignItems(HorizontalAlign.Center)
}

@Component
export struct NotificationPage {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  @State allowNotification: boolean = false;
  @StorageLink(C.KEY_NOTIFY_DDL_WARNING) ddlWarning: boolean = true;

  aboutToAppear(): void {
    void this.checkSystemPermission();
  }

  private async checkSystemPermission(): Promise<void> {
    try {
      this.allowNotification = await notificationManager.isNotificationEnabled();
    } catch (error) {
      console.error('[Guide] notification permission check failed:', error);
    }
  }

  build() {
    GuideContainer() {
      Column({ space: 20 }) {
        SetupPageHeader(
          $r('sys.symbol.bell_badge_clock'),
          '通知与提醒',
          '先授予系统通知权限，再决定是否开启 DDL 临近提醒。其他通知项后续也能随时调整。',
          this.theme.tabIcon
        )

        SettingsSection({
          bgColor: $r('sys.color.search_container_focus_color'),
          marginHorizontal: 0
        }) {
          SubSettingsSwitch({
            title: '允许通知',
            subtitle: this.allowNotification ? '当前已授予系统通知权限。' : '授予系统通知权限后，Deadliner 才能按时提醒你。',
            isOn: this.allowNotification,
            onChange: (isOn: boolean) => {
              if (isOn && !this.allowNotification) {
                notificationManager.requestEnableNotification().then(() => {
                  this.allowNotification = true;
                }).catch(() => {
                  this.allowNotification = false;
                  promptAction.showToast({ message: '开启通知失败，请检查系统权限' });
                });
              } else if (!isOn && this.allowNotification) {
                this.allowNotification = true;
                promptAction.showDialog({
                  title: '无法直接关闭',
                  message: '请前往系统设置中的“通知和状态栏”关闭本应用通知权限。',
                  buttons: [{ text: '知道了', color: '#007DFF' }]
                });
              }
            }
          })

          SubSettingsDivider()

          SubSettingsSwitch({
            title: 'DDL 临近预警',
            subtitle: '智能检测临近截止日期的任务，并提前发送提醒。',
            isOn: this.ddlWarning,
            onChange: (isOn: boolean) => {
              void LocalValues.getInstance().setDDLWarning(isOn);
            }
          })
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
  }
}

@Component
export struct ImmersiveEffectPage {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  @StorageLink(C.KEY_ENABLE_API23) api23: boolean = true;
  @State materialLevel: string = 'EXQUISITE';
  @State menuOptions: SelectOption[] = [
    { value: '自适应' },
    { value: '流畅' },
    { value: '柔和' },
    { value: '精美' }
  ];
  @State currentSelectIndex: number = 3;

  aboutToAppear(): void {
    this.materialLevel = LocalValues.getInstance().getMaterialLevel();
    const currentIndex: number = MATERIAL_OPTIONS.findIndex((item: MaterialOption) => item.value === this.materialLevel);
    this.currentSelectIndex = currentIndex >= 0 ? currentIndex : 3;
  }

  build() {
    GuideContainer() {
      Column({ space: 20 }) {
        SetupPageHeader(
          $r('sys.symbol.star_slash'),
          '沉浸光感视效',
          '如果你的设备是 60100+，这里可以先打开沉浸光感，并快速挑一个你喜欢的材质等级。',
          this.theme.tabIcon
        )

        SettingsSection({
          bgColor: $r('sys.color.search_container_focus_color'),
          marginHorizontal: 0
        }) {
          SubSettingsSwitch({
            title: '沉浸光感视效',
            subtitle: '打开后可获得更完整的沉浸材质与光感效果。',
            isOn: this.api23,
            onChange: (isOn: boolean): Promise<void> => LocalValues.getInstance().setApi23Enable(isOn)
          })
          .enabled(this.currentPageEnabled())

          if (this.api23 && this.currentPageEnabled()) {
            SettingsDivider()

            SettingsSelect({
              title: '材质等级',
              subtitle: '选择沉浸光感材质等级',
              options: this.menuOptions,
              selectedIndex: $currentSelectIndex,
              onChange: (index: number, _value: string) => {
                this.currentSelectIndex = index;
                const level: string = MATERIAL_OPTIONS[index].value;
                this.materialLevel = level;
                void LocalValues.getInstance().setMaterialLevel(level);
              }
            })
          }
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
  }

  private currentPageEnabled(): boolean {
    return deviceInfo.distributionOSApiVersion >= 60100;
  }
}

@Component
export struct SyncPage {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  @StorageLink(C.KEY_CLOUD_SYNC_ENABLE) syncEnable: boolean = false;
  @StorageLink(C.KEY_CLOUD_SYNC_MODE) syncMode: string = 'cloud';
  private readonly syncOptions: SyncOption[] = [
    { text: '华为端云协同', value: 'cloud' },
    { text: 'WebDAV', value: 'webdav' }
  ];

  build() {
    GuideContainer() {
      Column({ space: 20 }) {
        SetupPageHeader(
          $r('sys.symbol.externaldrive'),
          '跨端同步与云',
          '这里先决定你是否启用云同步，以及更偏向使用华为端云协同还是 WebDAV。',
          this.theme.tabIcon
        )

        SettingsSection({
          bgColor: $r('sys.color.search_container_focus_color'),
          marginHorizontal: 0
        }) {
          SubSettingsSwitch({
            title: '启用云同步',
            subtitle: '开启后可以在多台设备间同步你的任务与习惯数据。',
            isOn: this.syncEnable,
            onChange: (isOn: boolean): Promise<void> => LocalValues.getInstance().setCloudSyncEnable(isOn)
          })

          if (this.syncEnable) {
            SettingsDivider()

            ForEach(this.syncOptions, (item: SyncOption, index: number) => {
              SettingsCheckItem({
                title: item.text,
                isSelected: this.syncMode === item.value,
                onItemClick: () => {
                  this.syncMode = item.value;
                  void LocalValues.getInstance().setSyncMode(item.value);
                }
              })

              if (index < this.syncOptions.length - 1) {
                SettingsDivider()
              }
            }, (item: SyncOption) => item.value)
          }
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
  }
}

@Component
export struct AiPage {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  @StorageLink(C.KEY_AI_PROVIDER) provider: string = 'deepseek';
  @StorageLink(C.KEY_AI_MODEL) model: string = 'deepseek-chat';
  @StorageLink(C.KEY_AI_BASE_URL) baseUrl: string = 'https://api.deepseek.com';
  @StorageLink(C.KEY_AI_DEEPSEEK_API_KEY) apiKey: string = '';
  @State isTesting: boolean = false;

  build() {
    GuideContainer() {
      Column({ space: 20 }) {
        SetupPageHeader(
          $r('sys.symbol.wand_and_stars'),
          'Lifi AI 设置',
          '演示阶段我们只保留最关键的一步：填写 API Key，并在需要时快速校验一下。',
          this.theme.tabIcon
        )

        SettingsSection({
          title: 'DeepSeek API Key',
          bgColor: $r('sys.color.search_container_focus_color'),
          marginHorizontal: 0
        }) {
          TextInput({ text: this.apiKey, placeholder: 'sk-...' })
            .type(InputType.Password)
            .showPasswordIcon(true)
            .backgroundColor(Color.Transparent)
            .onChange((value: string) => {
              this.apiKey = value;
            })
        }

        Button(this.isTesting ? '正在校验...' : '校验 Key 有效性并保存', { type: ButtonType.Capsule })
          .width('90%')
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .controlSize(ControlSize.NORMAL)
          .backgroundColor(this.theme.brand)
          .enabled(!this.isTesting)
          .onClick(async () => {
            if (this.apiKey.trim().length === 0 || this.isTesting) {
              if (this.apiKey.trim().length === 0) {
                promptAction.showToast({ message: '请输入 API Key' });
              }
              return;
            }

            this.isTesting = true;
            try {
              const local: LocalValues = LocalValues.getInstance();
              await local.setDeepSeekApiKey(this.apiKey);
              await local.updateAIConfig(this.provider, this.model, this.baseUrl);
              await AIService.getInstance().extractTasks('Hi');
              promptAction.showToast({ message: '验证通过，配置已生效' });
            } catch (error) {
              console.error('[Guide] ai verify failed:', error);
              promptAction.showToast({ message: '验证失败，请检查 Key 与网络' });
            } finally {
              this.isTesting = false;
            }
          })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
  }
}

@Component
export struct PersonalizationPage {
  @State isThemeSelectSheetShow: boolean = false;
  @State isBackgroundSheetShow: boolean = false;
  @StorageProp('customBackgroundImage') currentBgUri: string = '';
  @StorageProp('customBackgroundBlur') isBgBlur: boolean = false;
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @Builder
  themeSheet() {
    ThemeSelectSheet({
      onDone: () => {
        this.isThemeSelectSheetShow = false;
      }
    })
  }

  @Builder
  cropSheetBuilder() {
    ImageCropSheet({
      sourceUri: this.currentBgUri,
      initBlurState: this.isBgBlur,
      title: '自定义背景',
      enableCompression: false,
      saveDirName: 'custom_backgrounds',
      cropRatio: undefined,
      onCancel: () => {
        this.isBackgroundSheetShow = false;
      },
      onComplete: (croppedUri: string, isBlur: boolean) => {
        this.isBackgroundSheetShow = false;
        ThemeManager.setCustomBackground(croppedUri, isBlur);
        promptAction.showToast({ message: '自定义背景已生效' });
      },
      onClearBackground: () => {
        this.isBackgroundSheetShow = false;
        ThemeManager.clearCustomBackground();
        promptAction.showToast({ message: '已恢复默认背景' });
      }
    })
  }

  build() {
    Column() {
      Column() {
        GuideContainer() {
          Column({ space: 20 }) {
            SetupPageHeader(
              $r('sys.symbol.paintpalette'),
              '个性化设置',
              '你可以先挑一个喜欢的主题，也可以直接换上自己的背景图。',
              this.theme.tabIcon
            )

            SettingsSection({
              bgColor: $r('sys.color.search_container_focus_color'),
              marginHorizontal: 0
            }) {
              SettingsItem({
                title: '个性化主题',
                subtitle: '自定义应用配色方案',
                icon: $r('sys.symbol.brush'),
                onItemClick: () => {
                  this.isThemeSelectSheetShow = true;
                }
              })

              SettingsDivider()

              SettingsItem({
                title: '自定义背景',
                subtitle: '自定义一级界面的背景图片',
                icon: $r('sys.symbol.background_blurred'),
                onItemClick: () => {
                  this.isBackgroundSheetShow = true;
                }
              })
            }
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.SpaceBetween)
        }
      }
      .bindSheet($$this.isThemeSelectSheetShow, this.themeSheet(), {
        detents: [550, 900],
        height: 550,
        dragBar: true,
        enableFloatingDragBar: true,
        enableOutsideInteractive: false,
        scrollSizeMode: ScrollSizeMode.CONTINUOUS,
        onDisappear: () => {
          this.isThemeSelectSheetShow = false;
        },
        backgroundColor: Color.Transparent,
        showClose: false
      })
    }
    .bindSheet($$this.isBackgroundSheetShow, this.cropSheetBuilder(), {
      showClose: false,
      onDisappear: () => {
        this.isBackgroundSheetShow = false;
      }
    })
    .justifyContent(FlexAlign.Center)
  }
}
