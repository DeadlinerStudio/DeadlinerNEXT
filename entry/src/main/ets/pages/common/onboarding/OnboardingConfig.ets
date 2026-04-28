import { util } from '@kit.ArkTS';
import { GuidePageId, GuideSceneConfig, LottieSceneMeta, MaterialOption, RawFileResourceManager } from './OnboardingTypes';

export const MATERIAL_OPTIONS: MaterialOption[] = [
  { label: '自适应', value: 'ADAPTIVE' },
  { label: '流畅', value: 'SMOOTH' },
  { label: '柔和', value: 'GENTLE' },
  { label: '精美', value: 'EXQUISITE' }
];

export const DEFAULT_LOTTIE_SCENES: LottieSceneMeta[] = [
  {
    id: 'lottie_1',
    fileName: 'Scene-1-Harmony.json',
    title: '滑动任务，快捷处理',
    subtitle: '在任务卡片上左右滑动，就能快速完成常用操作。',
    detail: '像完成、归档这类高频动作，不必点进详情页，在列表里就能顺手处理。'
  },
  {
    id: 'lottie_2',
    fileName: 'Scene-2-Harmony.json',
    title: '点一下 Lifi AI，唤起智能体',
    subtitle: '遇到临时想法、碎片信息或模糊需求，都可以先交给它整理。',
    detail: 'Lifi AI 能帮你提炼任务意图、补齐结构，再决定是否加入清单。'
  },
  {
    id: 'lottie_4',
    fileName: 'Scene-4-Harmony.json',
    title: '长按任务，进入多选',
    subtitle: '想批量完成、归档或删除时，长按任意任务即可开始选择。',
    detail: '连续处理一组任务会更高效，适合做每日清单收尾或集中整理。'
  },
  {
    id: 'lottie_5',
    fileName: 'Scene-5-Harmony.json',
    title: '轻点任务，查看详情与子任务',
    subtitle: '短按任务可以进入详情页，继续补充信息或拆分子任务。',
    detail: '当一件事需要更多上下文时，详情页就是你继续展开和整理的地方。'
  },
  {
    id: 'lottie_6',
    fileName: 'Scene-6-Harmony.json',
    title: '点击 Tab 顶部按钮，快速导航',
    subtitle: '每个 Tab 上方的按钮都可以带你进入对应功能入口。',
    detail: '把常用入口放在手边，切页之外也能更快抵达你要用的能力。'
  }
];

export function mapSceneConfigToPageId(id: string): GuidePageId {
  if (id === 'guide_scene_2') {
    return 'lottie_2';
  }
  if (id === 'guide_scene_4') {
    return 'lottie_4';
  }
  if (id === 'guide_scene_5') {
    return 'lottie_5';
  }
  if (id === 'guide_scene_6') {
    return 'lottie_6';
  }
  return 'lottie_1';
}

export function mapGuideSceneConfigs(configs: GuideSceneConfig[]): LottieSceneMeta[] {
  const scenes: LottieSceneMeta[] = [];
  configs.forEach((item: GuideSceneConfig) => {
    scenes.push({
      id: mapSceneConfigToPageId(item.id),
      fileName: item.fileName,
      title: item.title,
      subtitle: item.subtitle,
      detail: item.detail
    });
  });
  return scenes;
}

export async function loadGuideSceneConfigs(resourceManager: RawFileResourceManager): Promise<LottieSceneMeta[]> {
  try {
    const fileData: ArrayBuffer = await resourceManager.getRawFileContent('lottie/guide_scenes.json');
    const textDecoder: util.TextDecoder = new util.TextDecoder('utf-8', { ignoreBOM: true });
    const jsonBytes: Uint8Array = new Uint8Array(fileData);
    const jsonString: string = textDecoder.decodeWithStream(jsonBytes);
    const configs: GuideSceneConfig[] = JSON.parse(jsonString) as GuideSceneConfig[];
    if (configs.length > 0) {
      return mapGuideSceneConfigs(configs);
    }
  } catch {
    console.error('[Guide] Failed to load guide_scenes.json');
  }
  return DEFAULT_LOTTIE_SCENES;
}

export function buildGuidePageIds(hasImmersivePage: boolean): GuidePageId[] {
  const ids: GuidePageId[] = [
    'intro_welcome',
    'privacy',
    'intro_setup',
    'notifications'
  ];

  if (hasImmersivePage) {
    ids.push('immersive');
  }

  ids.push('sync');
  ids.push('ai');
  ids.push('personalization');
  ids.push('intro_interaction');
  ids.push('lottie_1');
  ids.push('lottie_2');
  ids.push('lottie_4');
  ids.push('lottie_5');
  ids.push('lottie_6');
  return ids;
}
