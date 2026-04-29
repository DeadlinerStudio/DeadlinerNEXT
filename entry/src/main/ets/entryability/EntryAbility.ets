import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { display, ThemeControl, window } from '@kit.ArkUI';
import { LocalValues } from '../common/local/LocalValues';
import { DatabaseHelper } from '../common/data/DatabaseHelper';
import { TaskRepository } from '../common/repository/TaskRepository';
import { WidgetUpdater } from '../utils/WidgetUpdater';
import { buffer } from '@kit.ArkTS';
import auth from '@hw-agconnect/auth'
import { ReminderDataManager } from '../utils/notification/ReminderDataManager';
import { HabitRepository } from '../common/repository/HabitRepository';
import { deviceInfo } from '@kit.BasicServicesKit';
import { notificationManager } from '@kit.NotificationKit';
import { ManualDataManager } from '../common/manual/ManualModel';
import { SettingsConstants as C } from '../common/local/SettingsConstants';
import { ThemeManager } from '../common/theme/ThemeManager';
import { DynamicIconUtils } from '../utils/DynamicIconUtils';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {

  private mainWindowClass: window.Window | undefined = undefined;

  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);

      await ThemeManager.init(this.context);

      await LocalValues.getInstance().init(this.context);

      if (this.mainWindowClass) {
        hilog.info(DOMAIN, 'testTag', 'LocalValues loaded after window created, refreshing window mode...');
        this.updateWindowMode(this.mainWindowClass);
      }

      await DatabaseHelper.getInstance().init(this.context);
      TaskRepository.getInstance().setContext(this.context)
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');

    let file = await this.context.resourceManager.getRawFileContent('agconnect-services.json');
    let json: string = buffer.from(file.buffer).toString();
    auth.init(this.context, json);

    console.info('[EntryAbility] Initializing ReminderDataManager...');
    await ReminderDataManager.getInstance().init(this.context);
    await ManualDataManager.getInstance().loadMenu(this.context)

    await TaskRepository.getInstance().initialReminderCheck();
    await HabitRepository.getInstance().initialReminderCheck();

    DynamicIconUtils.refreshSeasonIconIfNeeded(this.context);

    this.checkLoginStatus();

    this.handleWidgetRoute(want);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.handleWidgetRoute(want)
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    this.mainWindowClass = windowStage.getMainWindowSync();

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }

      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');

      this.handleResponsiveImmersive(windowStage);

      this.context.eventHub.on('refresh_window_mode', () => {
        let windowClass = windowStage.getMainWindowSync();
        this.updateWindowMode(windowClass);
      });

      this.requestNotificationPermission();
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
    WidgetUpdater.updateAllWidgets(this.context)
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
    WidgetUpdater.updateAllWidgets(this.context)
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    window.getLastWindow(this.context).then((windowClass) => {
      if (windowClass) {
        this.updateWindowMode(windowClass);
      }
    }).catch((err: BusinessError) => {
      hilog.debug(DOMAIN, 'testTag', 'Window not ready during config update (Expected in onCreate): ' + err.code);
    });
  }

  private checkLoginStatus() {
    AppStorage.setOrCreate('isLoggedIn', false);

    auth.getCurrentUser()
      .then((user) => {
        if (user) {
          hilog.info(0x0000, 'EntryAbility', 'User already logged in: %{public}s | %{public}s', user.getUid(), user.getDisplayName());
          // 状态确认：已登录
          AppStorage.setOrCreate('isLoggedIn', true);
        } else {
          hilog.info(0x0000, 'EntryAbility', 'User not logged in');
          // 状态确认：未登录
          AppStorage.setOrCreate('isLoggedIn', false);
        }
      })
      .catch((err: BusinessError) => {
        hilog.error(0x0000, 'EntryAbility', 'Check user failed: %{public}s', err.message);
        AppStorage.setOrCreate('isLoggedIn', false);
      });
  }

  /**
   * 统一处理小组件跳转逻辑
   */
  private handleWidgetRoute(want: Want) {
    if (want.parameters && want.parameters['target'] === 'addTask') {
      // 设置全局状态 'QuickAddTaskTrigger' 为 true
      // UI 监听到这个变为 true 后，就会打开弹窗
      AppStorage.setOrCreate('QuickAddTaskTrigger', true);
    }
  }

  /**
   * 处理响应式沉浸逻辑
   * 只有在宽度 >= 840vp 时才开启沉浸式，否则恢复默认
   */
  private handleResponsiveImmersive(windowStage: window.WindowStage) {
    let windowClass: window.Window = windowStage.getMainWindowSync();

    this.updateWindowMode(windowClass);

    // 3. 监听窗口尺寸变化 (用户旋转屏幕或折叠屏展开/折叠时触发)
    windowClass.on('windowSizeChange', (size) => {
      this.updateWindowMode(windowClass);
    });

    // 4. 保持避让区域监听 (用于全屏模式下的精确避让)
    windowClass.on('avoidAreaChange', (data) => {
      if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
        AppStorage.setOrCreate('topRectHeight', data.area.topRect.height);
      } else if (data.type == window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
        AppStorage.setOrCreate('bottomRectHeight', data.area.bottomRect.height);
      }
    });
  }

  private updateWindowMode(windowClass: window.Window) {
    // 获取当前窗口属性
    let windowProperties = windowClass.getWindowProperties();
    let widthPx = windowProperties.windowRect.width;

    let displayClass = display.getDefaultDisplaySync();
    let widthVp = widthPx / displayClass.densityPixels;

    let enableTabletUi = AppStorage.get<boolean>(C.KEY_ENABLE_TABLET_UI) ?? true;

    // 判断界限：840vp (与你 Index.ets 中的媒体查询保持一致)
    let isWideScreen = widthVp >= 840;

    let isDark = this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;

    if (isWideScreen && enableTabletUi) {
      windowClass.setWindowLayoutFullScreen(true);
      windowClass.setWindowSystemBarProperties({
        navigationBarColor: '#00000000',
        statusBarColor: '#00000000',
        statusBarContentColor: isDark ? '#FFFFFF' : '#000000',
        isStatusBarLightIcon: isDark
      });

      hilog.info(DOMAIN, 'testTag', `Width: ${widthVp}vp >= 840. Mode: Immersive`);
    } else {
      windowClass.setWindowLayoutFullScreen(false);
      windowClass.setWindowSystemBarProperties({
        navigationBarColor: isDark ? '#000000' : '#FFFFFF',
        statusBarColor: '#00000000',
        statusBarContentColor: isDark ? '#FFFFFF' : '#000000',
        isStatusBarLightIcon: isDark
      });

      hilog.info(DOMAIN, 'testTag', `Width: ${widthVp}vp < 840. Mode: Normal`);
    }

    this.updateAvoidRects(windowClass);
  };

  private updateAvoidRects(windowClass: window.Window) {
    let topAvoidArea = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
    let bottomAvoidArea = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);

    AppStorage.setOrCreate('topRectHeight', topAvoidArea.topRect.height);
    AppStorage.setOrCreate('bottomRectHeight', bottomAvoidArea.bottomRect.height);
  }

  private requestNotificationPermission() {
    notificationManager.requestEnableNotification(this.context).then(() => {
      hilog.info(DOMAIN, 'testTag', '[ANS] requestEnableNotification success');
    }).catch((err: BusinessError) => {
      hilog.error(DOMAIN, 'testTag', '[ANS] requestEnableNotification failed, code is %{public}d', err.code);
    });
  }
}