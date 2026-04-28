export const PANEL_BG: ResourceColor = $r('sys.color.search_container_focus_color');

export type GuidePageId =
  | 'intro_welcome'
  | 'privacy'
  | 'intro_setup'
  | 'notifications'
  | 'immersive'
  | 'sync'
  | 'ai'
  | 'personalization'
  | 'intro_interaction'
  | 'lottie_1'
  | 'lottie_2'
  | 'lottie_4'
  | 'lottie_5'
  | 'lottie_6';

export interface LottieSceneMeta {
  id: GuidePageId;
  fileName: string;
  title: string;
  subtitle: string;
  detail: string;
}

export interface GuideSceneConfig {
  id: string;
  fileName: string;
  title: string;
  subtitle: string;
  detail: string;
}

export interface MaterialOption {
  label: string;
  value: string;
}

export interface SyncOption {
  text: string;
  value: string;
}

export interface RawFileResourceManager {
  getRawFileContent(path: string): Promise<ArrayBuffer>;
}
