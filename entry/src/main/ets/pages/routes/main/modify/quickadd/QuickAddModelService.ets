import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { i18n } from '@kit.LocalizationKit';
import { quickAddModelPrepareAsync, quickAddModelRecognizeAsync, quickAddModelStatusAsync } from 'libdeadliner_persistence.so';
import { QuickAddDraft, QuickAddRequest } from './QuickAddModels';

export class QuickAddModelService {
  private static preparing: Promise<boolean> | null = null;
  private static ready: boolean = false;

  static isReady(): boolean { return QuickAddModelService.ready; }
  static async prepare(context: common.Context): Promise<boolean> {
    if (QuickAddModelService.ready) {
      const status: QuickAddModelDownloadStatus = await QuickAddModelService.status();
      if (status.phase === 'READY') return true;
    }
    if (QuickAddModelService.preparing !== null) return QuickAddModelService.preparing;
    QuickAddModelService.preparing = QuickAddModelService.load(context);
    const ready: boolean = await QuickAddModelService.preparing;
    QuickAddModelService.preparing = null;
    return ready;
  }
  private static async load(context: common.Context): Promise<boolean> {
    try {
      let manifest: string = '';
      try {
        const content = await context.resourceManager.getRawFileContent(i18n.System.getSystemLanguage().startsWith('en') ? 'quick-add-model-en.json' : 'quick-add-model.json');
        const decoder = new util.TextDecoder('utf-8', { ignoreBOM: true });
        manifest = decoder.decodeWithStream(content);
      } catch (_) { /* No release model configuration: keep rules. */ }
      QuickAddModelService.ready = await quickAddModelPrepareAsync(context.filesDir, manifest) === 'true';
    } catch (_) { QuickAddModelService.ready = false; }
    return QuickAddModelService.ready;
  }
  static async status(): Promise<QuickAddModelDownloadStatus> {
    const json: string = await quickAddModelStatusAsync();
    const status: QuickAddModelDownloadStatus = JSON.parse(json);
    return status;
  }
  static async recognize(text: string, kind: string): Promise<QuickAddDraft | null> {
    if (!QuickAddModelService.ready) return null;
    const json: string = await quickAddModelRecognizeAsync(JSON.stringify(new QuickAddRequest(text, kind)));
    const draft: QuickAddDraft = JSON.parse(json);
    return draft;
  }
}

export class QuickAddModelDownloadStatus {
  phase: string = 'UNCONFIGURED';
  downloadedBytes: number = 0;
  totalBytes: number = 0;
}
export function modelDownloadLabel(status: QuickAddModelDownloadStatus): string {
  if (status.phase === 'CHECKING') return '正在检查识别模型缓存';
  if (status.phase === 'DOWNLOADING') {
    const percent: number = status.totalBytes > 0 ? Math.floor(status.downloadedBytes * 100 / status.totalBytes) : 0;
    return '正在下载识别模型 · ' + percent.toString() + '%';
  }
  if (status.phase === 'LOADING') return '正在加载识别模型';
  if (status.phase === 'READY') return '端侧识别模型已就绪';
  if (status.phase === 'FAILED') return '模型不可用，当前使用规则识别';
  if (status.phase === 'CANCELLED') return '模型下载已暂停，当前使用规则识别';
  return '模型尚未配置，当前使用规则识别';
}
