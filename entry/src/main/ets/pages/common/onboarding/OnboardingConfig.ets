import { util } from '@kit.ArkTS';
import { GuidePageId, GuideSceneConfig, LottieSceneMeta, MaterialOption, RawFileResourceManager } from './OnboardingTypes';

export const MATERIAL_OPTIONS: MaterialOption[] = [
  { label: '自适应', value: 'ADAPTIVE' },
  { label: '流畅', value: 'SMOOTH' },
  { label: '柔和', value: 'GENTLE' },
  { label: '精美', value: 'EXQUISITE' }
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
  return [];
}

export function buildGuidePageIds(hasImmersivePage: boolean, lottieScenes: LottieSceneMeta[]): GuidePageId[] {
  const ids: GuidePageId[] = [
    'intro_welcome',
    'privacy',
    'huawei_login',
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

  lottieScenes.forEach(scene => ids.push(scene.id));

  return ids;
}
