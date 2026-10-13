import { common } from '@kit.AbilityKit';
import {
  registerWidgetUpdateCallback,
  requestWidgetUpdate,
  unregisterWidgetUpdateCallback
} from 'libdeadliner_persistence.so';
import { AppLog } from '../common/logging/AppLog';
import { WidgetUpdater } from './WidgetUpdater';

export enum WidgetUpdateReason {
  DATA_MUTATION = 0,
  USER_REFRESH = 1,
  APP_FOREGROUND = 2,
  PERIODIC = 3
}

export class WidgetRefreshBridge {
  private static readonly DEBOUNCE_MILLIS: number = 150;
  private static pendingTimer: number = -1;
  private static updateInFlight: boolean = false;
  private static updatePending: boolean = false;
  private static started: boolean = false;

  public static start(context: common.Context): void {
    if (WidgetRefreshBridge.started) {
      return;
    }
    const result: number = registerWidgetUpdateCallback((reason: number): void => {
      WidgetRefreshBridge.requestUpdate(context, reason);
    });
    WidgetRefreshBridge.started = result === 1;
    if (!WidgetRefreshBridge.started) {
      AppLog.warn('Native', '[WidgetRefreshBridge] Native callback registration failed.');
    }
  }

  public static stop(): void {
    if (WidgetRefreshBridge.pendingTimer >= 0) {
      clearTimeout(WidgetRefreshBridge.pendingTimer);
      WidgetRefreshBridge.pendingTimer = -1;
    }
    if (WidgetRefreshBridge.started) {
      unregisterWidgetUpdateCallback();
      WidgetRefreshBridge.started = false;
    }
  }

  public static requestKmpUpdate(reason: WidgetUpdateReason): void {
    const result: number = requestWidgetUpdate(reason);
    if (result !== 1) {
      AppLog.warn('Native', '[WidgetRefreshBridge] Native update request failed.');
    }
  }

  private static requestUpdate(context: common.Context, reason: number): void {
    AppLog.debug('Native', '[WidgetRefreshBridge] Requested reason=' + reason.toString());
    if (WidgetRefreshBridge.pendingTimer >= 0) {
      clearTimeout(WidgetRefreshBridge.pendingTimer);
    }
    WidgetRefreshBridge.pendingTimer = setTimeout((): void => {
      WidgetRefreshBridge.pendingTimer = -1;
      void WidgetRefreshBridge.performUpdate(context);
    }, WidgetRefreshBridge.DEBOUNCE_MILLIS);
  }

  private static async performUpdate(context: common.Context): Promise<void> {
    if (WidgetRefreshBridge.updateInFlight) {
      WidgetRefreshBridge.updatePending = true;
      return;
    }
    WidgetRefreshBridge.updateInFlight = true;
    try {
      await WidgetUpdater.updateAllWidgets(context);
    } catch (error) {
      AppLog.error('Native', '[WidgetRefreshBridge] Widget update failed: ' + String(error));
    } finally {
      WidgetRefreshBridge.updateInFlight = false;
      if (WidgetRefreshBridge.updatePending) {
        WidgetRefreshBridge.updatePending = false;
        WidgetRefreshBridge.requestUpdate(context, WidgetUpdateReason.DATA_MUTATION);
      }
    }
  }
}
