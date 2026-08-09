import { deviceInfo } from '@kit.BasicServicesKit';

export const API26_OR_ABOVE: boolean = deviceInfo.apiAvailable('26.0.0');
export const API23_UI_DEFAULT: boolean = deviceInfo.distributionOSApiVersion >= 60100;
export const EXPERIMENTAL_COMPONENTS_DEFAULT: boolean = !API26_OR_ABOVE &&
  (deviceInfo.distributionOSApiVersion === 23 || deviceInfo.distributionOSApiVersion === 24);
export const IMMERSIVE_FLOATING_TOOLBAR_DEFAULT: boolean = false;

export function isApi26OrAbove(): boolean {
  return API26_OR_ABOVE;
}

export function defaultExperimentalComponentsEnabled(): boolean {
  return EXPERIMENTAL_COMPONENTS_DEFAULT;
}

export function canShowExperimentalComponentsSetting(): boolean {
  return !API26_OR_ABOVE;
}

export function canShowImmersiveFloatingToolbarSetting(): boolean {
  return API26_OR_ABOVE;
}
