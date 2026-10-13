import { AppLog } from '../common/logging/AppLog';
import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { display, ThemeControl, window } from '@kit.ArkUI';
import { LocalValues } from '../common/local/LocalValues';
import { TaskRepository } from '../common/repository/TaskRepository';
import { buffer } from '@kit.ArkTS';
import auth from '@hw-agconnect/auth'
import { ReminderDataManager } from '../utils/notification/ReminderDataManager';
import { HabitRepository } from '../common/repository/HabitRepository';
import { InspirationRepository } from '../common/repository/InspirationRepository';
import { deviceInfo } from '@kit.BasicServicesKit';
import { notificationManager } from '@kit.NotificationKit';
import { ManualDataManager } from '../common/manual/ManualModel';
import { SettingsConstants as C } from '../common/local/SettingsConstants';
import { ThemeManager } from '../common/theme/ThemeManager';
import { DynamicIconUtils } from '../utils/DynamicIconUtils';
import { AIService } from '../ai/AIServcice';
import { AppBreakpointUtils, APP_BREAKPOINT_STORAGE_KEY } from '../common/layout/AppBreakpoints';
import { API23_UI_DEFAULT, EXPERIMENTAL_COMPONENTS_DEFAULT } from '../common/local/ExperimentalComponentsPolicy';
import { KmpMigrationService, KmpMigrationState } from '../common/migration/KmpMigrationService';
import { KmpAutomaticSyncConfigurator } from '../common/kmp/KmpAutomaticSyncConfigurator';
import { WidgetRefreshBridge, WidgetUpdateReason } from '../utils/WidgetRefreshBridge';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {

  private mainWindowClass: window.Window | undefined = undefined;

  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    AppLog.initialize(this.context);
    AppStorage.setOrCreate('OverviewAbilityContext', this.context);
    AppStorage.setOrCreate('OverviewAppForeground', true);
    this.handleFocusWant(want);
    WidgetRefreshBridge.start(this.context);
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      AppStorage.setOrCreate(C.KEY_ENABLE_API23, API23_UI_DEFAULT);
      AppStorage.setOrCreate(C.KEY_EXPERIMENTAL_COMPONENTS, EXPERIMENTAL_COMPONENTS_DEFAULT);
      AppStorage.setOrCreate(C.KEY_API23_MATERIAL_LEVEL, 'EXQUISITE');
      AppStorage.setOrCreate('FocusTimerRevision', 0);
      TaskRepository.getInstance().setContext(this.context);
      HabitRepository.getInstance().setContext(this.context);
      InspirationRepository.getInstance().setContext(this.context);
      const migration: KmpMigrationService = KmpMigrationService.getInstance();
      const migrationReady = migration.start(this.context);

      await ThemeManager.init(this.context);

      await LocalValues.getInstance().init(this.context);

      if (this.mainWindowClass) {
        AppLog.info('HiLog', DOMAIN, 'testTag', 'LocalValues loaded after window created, refreshing window mode...');
        this.updateWindowMode(this.mainWindowClass);
      }

      void this.initializeDeferredServices(migrationReady);
    } catch (err) {
      AppLog.error('HiLog', DOMAIN, 'testTag', 'Startup failed. Cause: %{public}s', String(err));
    }
    AppLog.info('HiLog', DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');

    void this.initializeNonBlockingServices(want);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.handleWidgetRoute(want)
    this.handleFocusWant(want);
  }

  onDestroy(): void {
    WidgetRefreshBridge.stop();
    AppLog.info('HiLog', DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    AppLog.info('HiLog', DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    this.mainWindowClass = windowStage.getMainWindowSync();

    let systemProperties = this.mainWindowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
    AppStorage.set("statusBarHeight", systemProperties.topRect.height);

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        AppLog.error('HiLog', DOMAIN, 'testTag', 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }

      AppLog.info('HiLog', DOMAIN, 'testTag', 'Succeeded in loading the content.');

      this.handleResponsiveImmersive(windowStage);

      this.context.eventHub.on('refresh_window_mode', () => {
        let windowClass = windowStage.getMainWindowSync();
        this.updateWindowMode(windowClass);
      });

      void this.requestNotificationPermissionIfNeeded();
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    AppLog.info('HiLog', DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }


  private handleFocusWant(want: Want): void {
    if (want.uri !== undefined && want.uri.startsWith('deadliner://focus/')) {
      AppStorage.setOrCreate('FocusNotificationSessionUid', want.uri.substring('deadliner://focus/'.length));
      AppStorage.setOrCreate('FocusTimerOpen', true);
    }
  }

  onForeground(): void {
    AppStorage.setOrCreate('OverviewAppForeground', true);
    // Ability has brought to foreground
    AppLog.info('HiLog', DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
    AppLog.info('Native', '[GuideDebug][EntryAbility] onForeground');
    WidgetRefreshBridge.requestKmpUpdate(WidgetUpdateReason.APP_FOREGROUND);
    AppStorage.setOrCreate('FocusTimerRevision', (AppStorage.get<number>('FocusTimerRevision') ?? 0) + 1);
  }

  onBackground(): void {
    AppStorage.setOrCreate('OverviewAppForeground', false);
    // Ability has back to background
    AppLog.info('HiLog', DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
    AppLog.info('Native', '[GuideDebug][EntryAbility] onBackground');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    window.getLastWindow(this.context).then((windowClass) => {
      if (windowClass) {
        this.updateWindowMode(windowClass);
      }
    }).catch((err: BusinessError) => {
      AppLog.debug('HiLog', DOMAIN, 'testTag', 'Window not ready during config update (Expected in onCreate): ' + err.code);
    });
  }

  /** Startup work that must not delay WindowStage creation or the first ArkUI frame. */
  private async initializeDeferredServices(migrationReady: Promise<KmpMigrationState>): Promise<void> {
    try {
      await migrationReady;
      KmpAutomaticSyncConfigurator.getInstance().configure();
      await HabitRepository.getInstance().repairLegacyTaskCarriers();
      await AIService.getInstance().init(this.context);
      AppLog.info('Native', '[EntryAbility] KMP-dependent services initialized after migration.');
    } catch (error) {
      AppLog.error('HiLog', DOMAIN, 'testTag', 'Deferred KMP startup failed: %{public}s', String(error));
    }
  }

  /** Non-visual services may initialize after the ability has returned control to ArkUI. */
  private async initializeNonBlockingServices(want: Want): Promise<void> {
    try {
      const file = await this.context.resourceManager.getRawFileContent('agconnect-services.json');
      const json: string = buffer.from(file.buffer).toString();
      auth.init(this.context, json);

      AppLog.info('Native', '[EntryAbility] Initializing ReminderDataManager...');
      await ReminderDataManager.getInstance().init(this.context);
      await ManualDataManager.getInstance().loadMenu(this.context);
      await TaskRepository.getInstance().initialReminderCheck();
      await HabitRepository.getInstance().initialReminderCheck();

      DynamicIconUtils.refreshSeasonIconIfNeeded(this.context);
      this.checkLoginStatus();
      this.handleWidgetRoute(want);
    } catch (error) {
      AppLog.error('HiLog', DOMAIN, 'testTag', 'Deferred startup service failed: %{public}s', String(error));
    }
  }

  private checkLoginStatus() {
    AppStorage.setOrCreate('isLoggedIn', false);

    auth.getCurrentUser()
      .then((user) => {
        if (user) {
          AppLog.info('HiLog', 0x0000, 'EntryAbility', 'User already logged in: %{public}s | %{public}s', user.getUid(), user.getDisplayName());
          // 状态确认：已登录
          AppStorage.setOrCreate('isLoggedIn', true);
        } else {
          AppLog.info('HiLog', 0x0000, 'EntryAbility', 'User not logged in');
          // 状态确认：未登录
          AppStorage.setOrCreate('isLoggedIn', false);
        }
      })
      .catch((err: BusinessError) => {
        AppLog.error('HiLog', 0x0000, 'EntryAbility', 'Check user failed: %{public}s', err.message);
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

    let breakpoint = AppBreakpointUtils.fromWidthVp(widthVp);
    let isWideScreen = AppBreakpointUtils.isWide(breakpoint);

    let isDark = this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    AppStorage.setOrCreate('currentColorMode', this.context.config.colorMode);
    AppStorage.setOrCreate(APP_BREAKPOINT_STORAGE_KEY, breakpoint);
    AppStorage.setOrCreate('isWideScreen', isWideScreen);

    if (isWideScreen && enableTabletUi) {
      windowClass.setWindowLayoutFullScreen(true);
      windowClass.setWindowSystemBarProperties({
        navigationBarColor: '#00000000',
        statusBarColor: '#00000000',
        statusBarContentColor: isDark ? '#FFFFFF' : '#000000',
        isStatusBarLightIcon: isDark
      });

      AppLog.info('HiLog', DOMAIN, 'testTag', `Width: ${widthVp}vp breakpoint=${breakpoint}. Mode: Immersive`);
    } else {
      windowClass.setWindowLayoutFullScreen(false);
      windowClass.setWindowSystemBarProperties({
        navigationBarColor: isDark ? '#000000' : '#FFFFFF',
        statusBarColor: '#00000000',
        statusBarContentColor: isDark ? '#FFFFFF' : '#000000',
        isStatusBarLightIcon: isDark
      });

      AppLog.info('HiLog', DOMAIN, 'testTag', `Width: ${widthVp}vp breakpoint=${breakpoint}. Mode: Normal`);
    }

    this.updateAvoidRects(windowClass);
  };

  private updateAvoidRects(windowClass: window.Window) {
    let topAvoidArea = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
    let bottomAvoidArea = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);

    AppStorage.setOrCreate('topRectHeight', topAvoidArea.topRect.height);
    AppStorage.setOrCreate('bottomRectHeight', bottomAvoidArea.bottomRect.height);
  }

  private async requestNotificationPermissionIfNeeded(): Promise<void> {
    const isFirstLaunch = await LocalValues.getInstance().getIsAppFirstLaunch();
    AppLog.info('Native', `[GuideDebug][EntryAbility] requestNotificationPermissionIfNeeded isFirstLaunch=${isFirstLaunch}`);
    AppStorage.setOrCreate('NotificationPermissionRequestInProgress', false);

    if (isFirstLaunch) {
      AppLog.info('Native', '[GuideDebug][EntryAbility] requestNotificationPermissionIfNeeded:skipFirstLaunch');
      return;
    }

    this.requestNotificationPermission();
  }

  private requestNotificationPermission() {
    AppLog.info('Native', '[GuideDebug][EntryAbility] requestNotificationPermission:start');
    AppStorage.setOrCreate('NotificationPermissionRequestInProgress', true);
    notificationManager.isNotificationEnabled().then((enabled: boolean) => {
      AppLog.info('Native', `[GuideDebug][EntryAbility] requestNotificationPermission:before enabled=${enabled}`);
    }).catch((err: BusinessError) => {
      AppLog.error('Native', `[GuideDebug][EntryAbility] requestNotificationPermission:beforeCheckFailed code=${err.code} message=${err.message}`);
    });

    notificationManager.requestEnableNotification(this.context).then(() => {
      AppLog.info('HiLog', DOMAIN, 'testTag', '[ANS] requestEnableNotification success');
      AppLog.info('Native', '[GuideDebug][EntryAbility] requestNotificationPermission:success');
      AppStorage.setOrCreate('NotificationPermissionRequestInProgress', false);
    }).catch((err: BusinessError) => {
      AppLog.error('HiLog', DOMAIN, 'testTag', '[ANS] requestEnableNotification failed, code is %{public}d', err.code);
      AppLog.error('Native', `[GuideDebug][EntryAbility] requestNotificationPermission:failed code=${err.code} message=${err.message}`);
      AppStorage.setOrCreate('NotificationPermissionRequestInProgress', false);
    });
  }
}
