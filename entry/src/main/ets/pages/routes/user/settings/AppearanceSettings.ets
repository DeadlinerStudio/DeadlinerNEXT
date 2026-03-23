import { LocalValues } from '../../../../common/local/LocalValues';
import { SettingsConstants as C } from '../../../../common/local/SettingsConstants';
import { SettingsDivider, SettingsSection, SettingsItem, SubSettingsSwitch,
  SettingsCheckItem,
  SubSettingsDivider,
  SettingsSlider,
  SettingsSelect} from '../../../components/SettingsComponents';
import { HdsNavDestination, HdsNavDestinationAttribute } from '@kit.UIDesignKit';
import { TopSafeContainer } from '../../../components/TopSafeContainer';
import { common } from '@kit.AbilityKit';
import { getImmersiveTitleBarStyle } from '../../../../common/style/NavStyles';
import { promptAction, window } from '@kit.ArkUI';
import { ThemeSelectSheet } from './components/ThemeSelectSheet';
import { deviceInfo } from '@kit.BasicServicesKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { ThemeManager } from '../../../../common/theme/ThemeManager';
import { ImageCropSheet } from './components/ImageCropSheet';

@Builder
export function AppearanceSettingsBuilder() {
  AppearanceSettings()
}

@Component
struct AppearanceSettings {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @Consume('userLocalPathStack') userLocalPathStack: NavPathStack = new NavPathStack();

  @StorageLink('isWideScreen') isWideScreen: boolean = false;

  private navigateTo(name: string) {
    if (this.isWideScreen) {
      this.userLocalPathStack.pushPath({ name: name });
    } else {
      this.appPathStack.pushPath({ name: name });
    }
  }

  @StorageProp('statusBarHeight') statusBarHeight: number = 38;
  readonly TITLE_BAR_CONTENT_HEIGHT: number = 18;

  @StorageLink(C.KEY_PROGRESS_DIRECTION) progressDir: boolean = false;
  @StorageLink(C.KEY_EXCITEMENT_TEXT) excitementText: boolean = true;
  @StorageLink(C.KEY_CONFETTI_AFTER_FINISHED) confetti: boolean = true;
  @StorageLink(C.KEY_ENGLISH_SOMEWHERE) english: boolean = true;
  @StorageLink(C.KEY_ADD_SYMBOL_WEIGHT) weight: number = 600;
  @StorageLink(C.KEY_ENABLE_API23) api23: boolean = true;

  @StorageLink(C.KEY_ENABLE_TABLET_UI) tabletUi: boolean = true;
  @StorageLink(C.KEY_TABLET_SIDE_DASHBOARD) tabletSd: boolean = true;

  @State isThemeSelectSheetShow: boolean = false;
  @Builder
  themeSheet() {
    ThemeSelectSheet({
      onDone: () => { this.isThemeSelectSheetShow = false }
    })
  }

  @State isBackgroundSheetShow: boolean = false;
  @State pickedImageUri: string = '';
  @StorageProp('customBackgroundImage') currentBgUri: string = '';
  @StorageProp('customBackgroundBlur') isBgBlur: boolean = false;


  async pickImageFromGallery() {
    try {
      const photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1; // 只能选一张

      const photoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const photoSelectResult = await photoViewPicker.select(photoSelectOptions);

      if (photoSelectResult && photoSelectResult.photoUris.length > 0) {
        this.pickedImageUri = photoSelectResult.photoUris[0];
        // 选图成功，触发裁剪 Sheet 显示
        this.isBackgroundSheetShow = true;
      }
    } catch (err) {
      console.error('[AppearanceSettings] Pick image failed:', err);
    }
  }

  @Builder
  cropSheetBuilder() {
    ImageCropSheet({
      // 把当前的背景图路径传进去，如果没有的话内部会显示“暂未选择”
      sourceUri: this.currentBgUri,
      initBlurState: this.isBgBlur,
      title: '自定义背景',
      enableCompression: false,
      saveDirName: 'custom_backgrounds', // 换个文件夹存
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
        // 用户点击了“恢复默认”
        this.isBackgroundSheetShow = false;
        ThemeManager.clearCustomBackground();
        promptAction.showToast({ message: '已恢复默认背景' });
      }
    })
  }

  @State menuOptions: SelectOption[] = [
    { value: '自适应' },
    { value: '流畅' },
    { value: '柔和' },
    { value: '精美' },
  ]
  @State currentSelectIndex: number = 0;

  MATERIAL_LEVELS = ['ADAPTIVE', 'SMOOTH', 'GENTLE', 'EXQUISITE']

  aboutToAppear(): void {
    const level = LocalValues.getInstance().getMaterialLevel()
    this.currentSelectIndex = this.MATERIAL_LEVELS.indexOf(level);
  }

  build() {
    HdsNavDestination() {
      TopSafeContainer({ topAvoidHeight: this.statusBarHeight + this.TITLE_BAR_CONTENT_HEIGHT }) {
        Column({ space: 16 }) {

          SettingsSection({ title: '界面显示' }) {
            SettingsItem({
              title: "个性化主题",
              subtitle: "自定义应用配色方案",
              icon: $r('sys.symbol.brush'),
              onItemClick: () => {
                this.isThemeSelectSheetShow = true;
              }
            })

            SettingsDivider()

            SettingsItem({
              title: "自定义背景",
              subtitle: "自定义一级界面的背景图片",
              icon: $r('sys.symbol.background_blurred'),
              onItemClick: () => {
                this.isBackgroundSheetShow = true;
              }
            })
          }

          SettingsSection() {
            SubSettingsSwitch({
              title: "沉浸光感视效",
              subtitle: "API23以上可以打开该选项获得最佳的视觉体验 (需重启生效)。",
              isOn: this.api23,
              onChange: (isOn): Promise<void> => LocalValues.getInstance().setApi23Enable(isOn)
            })
              .enabled(deviceInfo.distributionOSApiVersion >= 60100)

            if (this.api23 && deviceInfo.distributionOSApiVersion >= 60100) {
              SettingsDivider()

              SettingsSelect({
                title: '材质等级',
                subtitle: '选择沉浸光感材质等级',
                options: this.menuOptions,
                selectedIndex: $currentSelectIndex,
                onChange: (index, value) => {
                  console.info(`用户选中了第 ${index} 项，值为: ${value}`);
                  const level = this.MATERIAL_LEVELS[index];
                  LocalValues.getInstance().setMaterialLevel(level)
                }
              })
            }
          }

          SettingsSection() {
            SubSettingsSwitch({
              title: "正向进度条",
              subtitle: "开启后，首页任务卡片将显示“已进行时间”，关闭则显示“剩余时间”。",
              isOn: this.progressDir,
              onChange: (isOn): Promise<void> => LocalValues.getInstance().setProgressDir(isOn)
            })

            SubSettingsDivider()

            SubSettingsSwitch({
              title: "装饰区域显示英语",
              subtitle: "开启后，将在界面非功能区显示少量英语",
              isOn: this.english,
              onChange: (isOn): Promise<void> => LocalValues.getInstance().setEnglishSomewhere(isOn)
            })

            SubSettingsDivider()

            SettingsItem({
              title: "习惯进度展示样式",
              subtitle: "自定义主页习惯页的进度展示样式",
              onItemClick: () => {
                this.navigateTo('settingsHabitProgressStyle');
              }
            })

            SubSettingsDivider()

            SettingsItem({
              title: "小组件样式",
              subtitle: "自定义桌面服务卡片的背景与风格",
              onItemClick: () => {
                this.navigateTo('settingsWidgetBackground');
              }
            })
          }

          SettingsSection() {
            SettingsSlider({
              title: "主页添加按钮字重",
              icon: $r('sys.symbol.plus_circle'), // 使用加号图标作为示意
              value: $weight, // 双向绑定 StorageLink
              min: 100, // 字重最小值
              max: 800, // 字重最大值
              step: 100, // 步长，让用户可以选择 400, 500, 600 等整数
              showSteps: true, // 显示吸附点
              showValueText: true,
              onChange: (val) => {
                // 保存设置
                LocalValues.getInstance().setAddSymbolWeight(val);
              }
            })
          }

          if (this.isWideScreen) {
            SettingsSection({ title: '平板专区' }) {
              SubSettingsSwitch({
                title: "平板 UI 适配",
                subtitle: "关闭后，平板电脑将回归和手机一致的 UI 布局；否则则为平板特殊适配的布局。",
                isOn: this.tabletUi,
                onChange: async (isOn): Promise<void> => {
                  await LocalValues.getInstance().setTabletUI(isOn);
                  const context = getContext(this) as common.UIAbilityContext;
                  context.eventHub.emit('refresh_window_mode');
                }
              })

              SubSettingsDivider()

              SubSettingsSwitch({
                title: "主页侧边看板",
                subtitle: "开启后，主页将展示侧边看板展示可供预览的信息。",
                isOn: this.tabletSd,
                onChange: (isOn): Promise<void> => LocalValues.getInstance().setSideDashboard(isOn)
              })
            }
          }

          // --- 视觉反馈 ---
          SettingsSection({ title: '视觉反馈' }) {
            SubSettingsSwitch({
              title: "激励语句",
              subtitle: "在首页标题栏显示随机的名言警句，为您的一天注入动力。",
              isOn: this.excitementText,
              onChange: (isOn): Promise<void> => LocalValues.getInstance().setExcitementText(isOn)
            })

            SubSettingsDivider()

            SubSettingsSwitch({
              title: "任务完成礼花",
              subtitle: "当您勾选完成任务时，屏幕上会播放庆祝礼花动画。",
              isOn: this.confetti,
              onChange: (isOn): Promise<void> => LocalValues.getInstance().setConfettiAfterFinished(isOn)
            })
          }
        }
        .width('100%')
        .padding(16)
        .justifyContent(FlexAlign.Start)
        .constraintSize({ minHeight: '100%' })
        .bindSheet($$this.isBackgroundSheetShow, this.cropSheetBuilder(), {
          showClose: false
        })
      }
    }
    .titleBar({
      style: getImmersiveTitleBarStyle(this.isWideScreen),
      content: { title: { mainTitle: "显示与个性化" } }
    })
    .bindSheet($$this.isThemeSelectSheetShow, this.themeSheet(), {
      detents: [ 550, 900 ],
      height: 550,
      dragBar: true,
      enableFloatingDragBar: true,
      enableOutsideInteractive: false,
      scrollSizeMode: ScrollSizeMode.CONTINUOUS,
      onDisappear: () => {
        this.isThemeSelectSheetShow = false;
      },
      // blurStyle: BlurStyle.Regular,
      backgroundColor: Color.Transparent,
      showClose: false
    })
  }
}