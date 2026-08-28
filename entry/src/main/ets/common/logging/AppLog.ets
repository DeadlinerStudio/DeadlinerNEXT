import { bundleManager, common } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';

export enum AppLogLevel {
  DEBUG = 'debug',
  INFO = 'info',
  WARNING = 'warning',
  ERROR = 'error'
}

class AppLogRecord {
  schemaVersion: number = 1;
  timestamp: number = 0;
  sessionID: string = '';
  processID: number = 0;
  level: string = 'info';
  category: string = 'app';
  message: string = '';
  context: AppLogContext | null = null;
}

class AppLogContext {
  appVersion: string = '';
  deviceBrand: string = '';
  deviceManufacturer: string = '';
  deviceModel: string = '';
  deviceType: string = '';
  osApiVersion: string = '';
  osName: string = '';
  osVersion: string = '';
}

/**
 * The HarmonyOS implementation of the iOS diagnostic file protocol.
 * Logging is deliberately best-effort: it never changes the caller's result.
 */
export class AppLog {
  private static readonly DOMAIN: number = 0xD311;
  private static readonly DIRECTORY: string = 'Diagnostics';
  private static readonly JSONL_FILE: string = 'deadliner-diagnostics.jsonl';
  private static readonly STANDARD_FILE: string = 'deadliner-diagnostics.log';
  private static readonly sessionId: string = util.generateRandomUUID(true).toLowerCase();
  private static diagnosticsDirectory: string = '';

  public static initialize(context: common.Context): void {
    AppLog.diagnosticsDirectory = context.filesDir + '/' + AppLog.DIRECTORY;
    try {
      fileIo.mkdirSync(AppLog.diagnosticsDirectory);
    } catch (error) {
      // The directory commonly already exists; append will report a real failure.
    }
    AppLog.event('app.launch', 'lifecycle');
    AppLog.event('app.environment', 'environment', AppLogLevel.INFO, AppLog.environmentContext());
  }

  public static debug(category: string, ...parts: Object[]): void {
    AppLog.write(AppLogLevel.DEBUG, category, AppLog.join(parts), null);
  }

  public static info(category: string, ...parts: Object[]): void {
    AppLog.write(AppLogLevel.INFO, category, AppLog.join(parts), null);
  }

  public static warn(category: string, ...parts: Object[]): void {
    AppLog.write(AppLogLevel.WARNING, category, AppLog.join(parts), null);
  }

  public static error(category: string, ...parts: Object[]): void {
    AppLog.write(AppLogLevel.ERROR, category, AppLog.join(parts), null);
  }

  public static event(name: string, domain: string, level: AppLogLevel = AppLogLevel.INFO,
    context: AppLogContext | null = null): void {
    AppLog.write(level, domain, '[' + name + ']', context);
  }

  public static exportPaths(): Array<string> {
    if (AppLog.diagnosticsDirectory.length === 0) {
      return [];
    }
    return [
      AppLog.diagnosticsDirectory + '/' + AppLog.STANDARD_FILE,
      AppLog.diagnosticsDirectory + '/' + AppLog.JSONL_FILE
    ];
  }

  private static write(level: AppLogLevel, category: string, message: string, context: AppLogContext | null): void {
    const record: AppLogRecord = new AppLogRecord();
    record.timestamp = Date.now() / 1000;
    record.sessionID = AppLog.sessionId;
    record.level = level;
    record.category = category;
    record.message = message;
    record.context = context;
    AppLog.append(AppLog.JSONL_FILE, JSON.stringify(record) + '\n');
    AppLog.append(AppLog.STANDARD_FILE, AppLog.standardLine(record));
    AppLog.mirror(level, category, message);
  }

  private static append(fileName: string, line: string): void {
    if (AppLog.diagnosticsDirectory.length === 0) {
      return;
    }
    let file: fileIo.File | null = null;
    try {
      file = fileIo.openSync(
        AppLog.diagnosticsDirectory + '/' + fileName,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.APPEND
      );
      const bytes: Uint8Array = new util.TextEncoder().encodeInto(line);
      fileIo.writeSync(file.fd, bytes.buffer);
    } catch (error) {
      hilog.error(AppLog.DOMAIN, 'AppLog', 'Unable to persist diagnostics: %{public}s', String(error));
    } finally {
      if (file !== null) {
        fileIo.closeSync(file);
      }
    }
  }

  private static standardLine(record: AppLogRecord): string {
    const isEvent: boolean = record.message.startsWith('[') && record.message.endsWith(']');
    const module: string = isEvent ? record.message.substring(1, record.message.length - 1) : record.category;
    const level: string = record.level === AppLogLevel.INFO ? '' : ' level=' + record.level;
    const message: string = isEvent ? '' : AppLog.normalized(record.message);
    const context: string = AppLog.contextLine(record.context);
    const suffix: string = message.length === 0 ? context :
      (context.length === 0 ? message : message + ' ' + context);
    return '[' + new Date(record.timestamp * 1000).toISOString() + '][Native][' + module + ']' + level +
      (suffix.length === 0 ? '\n' : ' ' + suffix + '\n');
  }

  private static join(parts: Object[]): string {
    let message: string = '';
    for (let index: number = 0; index < parts.length; index++) {
      if (index > 0) {
        message += ' ';
      }
      message += AppLog.stringify(parts[index]);
    }
    return message;
  }

  private static stringify(value: Object): string {
    if (value instanceof Error) {
      return value.message;
    }
    try {
      const serialized: string | undefined = JSON.stringify(value);
      return serialized === undefined ? String(value) : serialized;
    } catch (error) {
      return String(value);
    }
  }

  private static normalized(value: string): string {
    return value.replace(/\n/g, '\\n').replace(/\r/g, '\\r');
  }

  private static environmentContext(): AppLogContext {
    const context: AppLogContext = new AppLogContext();
    context.deviceBrand = deviceInfo.brand;
    context.deviceManufacturer = deviceInfo.manufacture;
    context.deviceModel = deviceInfo.productModel;
    context.deviceType = deviceInfo.deviceType;
    context.osApiVersion = deviceInfo.distributionOSApiVersion.toString();
    context.osName = deviceInfo.distributionOSName;
    context.osVersion = deviceInfo.distributionOSVersion;
    try {
      const bundleInfo = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      context.appVersion = bundleInfo.versionName + ' (' + bundleInfo.versionCode.toString() + ')';
    } catch (error) {
      context.appVersion = 'unknown';
    }
    return context;
  }

  private static contextLine(context: AppLogContext | null): string {
    if (context === null) {
      return '';
    }
    return 'app.version=' + AppLog.normalized(context.appVersion) +
      ' device.brand=' + AppLog.normalized(context.deviceBrand) +
      ' device.manufacturer=' + AppLog.normalized(context.deviceManufacturer) +
      ' device.model=' + AppLog.normalized(context.deviceModel) +
      ' device.type=' + AppLog.normalized(context.deviceType) +
      ' os.apiLevel=' + AppLog.normalized(context.osApiVersion) +
      ' os.name=' + AppLog.normalized(context.osName) +
      ' os.version=' + AppLog.normalized(context.osVersion);
  }

  private static mirror(level: AppLogLevel, category: string, message: string): void {
    if (level === AppLogLevel.ERROR) {
      hilog.error(AppLog.DOMAIN, category, '%{public}s', message);
    } else if (level === AppLogLevel.WARNING) {
      hilog.warn(AppLog.DOMAIN, category, '%{public}s', message);
    } else if (level === AppLogLevel.DEBUG) {
      hilog.debug(AppLog.DOMAIN, category, '%{public}s', message);
    } else {
      hilog.info(AppLog.DOMAIN, category, '%{public}s', message);
    }
  }
}
