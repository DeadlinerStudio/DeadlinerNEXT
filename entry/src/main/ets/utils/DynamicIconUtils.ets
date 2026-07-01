import { appInfoManager } from "@kit.AppGalleryKit";
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { SeasonUtils } from './SeasonUtils';

type Season = 'spring' | 'summer' | 'autumn' | 'winter';

export class DynamicIconUtils {
  private static readonly PREF_NAME: string = 'dynamic_icon_preferences';
  private static readonly KEY_SEASON_MODE_ENABLED: string = 'season_mode_enabled';

  static async getDynamicIconInfo(): Promise<appInfoManager.DynamicIconInfo[]> {
    try {
      return await appInfoManager.queryDynamicIcons()
    } catch (error) {
      console.error('[DynamicIcon]', "queryDynamicIcons exception code: " + error.code + ", exception message: " + error.message);
      return [];
    }
  }

  static async setDynamicIcon(dynamicId: string): Promise<void> {
    try {
      await appInfoManager.selectDynamicIcon(dynamicId)
    } catch (error) {
      console.error('[DynamicIcon]',
        "selectDynamicIcon exception code: " + error.code + ", exception message: " + error.message);
    }
  }

  static async disableDynamicIcon(): Promise<void> {
    try {
      await appInfoManager.disableDynamicIcon();
    } catch (error) {
      console.error('[DynamicIcon]',
        "disableDynamicIcon exception code: " + error.code + ", exception message: " + error.message);
    }
  }

  static async setSeasonModeEnabled(
    context: common.Context,
    enabled: boolean
  ): Promise<void> {
    try {
      const pref = await preferences.getPreferences(context, DynamicIconUtils.PREF_NAME);
      await pref.put(DynamicIconUtils.KEY_SEASON_MODE_ENABLED, enabled);
      await pref.flush();

      console.info(`[DynamicIcon] season mode saved: ${enabled}`);
    } catch (error) {
      console.error('[DynamicIcon]',
        "setSeasonModeEnabled exception code: " + error.code + ", exception message: " + error.message);
    }
  }

  static async isSeasonModeEnabled(
    context: common.Context
  ): Promise<boolean> {
    try {
      const pref = await preferences.getPreferences(context, DynamicIconUtils.PREF_NAME);
      const value = await pref.get(DynamicIconUtils.KEY_SEASON_MODE_ENABLED, false);

      return value as boolean;
    } catch (error) {
      console.error('[DynamicIcon]',
        "isSeasonModeEnabled exception code: " + error.code + ", exception message: " + error.message);
      return false;
    }
  }

  static getSeasonIconInfo(
    dynamicIconInfos: appInfoManager.DynamicIconInfo[],
    season: Season
  ): appInfoManager.DynamicIconInfo | undefined {
    return dynamicIconInfos.find((info: appInfoManager.DynamicIconInfo): boolean => {
      return info.iconId.toLowerCase().includes(season);
    });
  }

  static getCurrentSeasonDynamicIconId(
    dynamicIconInfos: appInfoManager.DynamicIconInfo[]
  ): string | undefined {
    const season = SeasonUtils.getCurrentSeason(new Date());

    const matchedInfo = DynamicIconUtils.getSeasonIconInfo(dynamicIconInfos, season);

    return matchedInfo?.iconId;
  }

  static hasSeasonIcon(
    dynamicIconInfos: appInfoManager.DynamicIconInfo[],
    season: Season
  ): boolean {
    return dynamicIconInfos.some((info: appInfoManager.DynamicIconInfo): boolean => {
      return info.iconId.toLowerCase().includes(season);
    });
  }

  static hasAllSeasonIcons(
    dynamicIconInfos: appInfoManager.DynamicIconInfo[]
  ): boolean {
    return DynamicIconUtils.hasSeasonIcon(dynamicIconInfos, 'spring') &&
      DynamicIconUtils.hasSeasonIcon(dynamicIconInfos, 'summer') &&
      DynamicIconUtils.hasSeasonIcon(dynamicIconInfos, 'autumn') &&
      DynamicIconUtils.hasSeasonIcon(dynamicIconInfos, 'winter');
  }

  /**
   * 如果用户启用了 season 模式，则按当前节气刷新动态图标。
   *
   * 建议在 EntryAbility 启动时调用。
   */
  static async refreshSeasonIconIfNeeded(
    context: common.Context
  ): Promise<void> {
    const enabled = await DynamicIconUtils.isSeasonModeEnabled(context);

    if (!enabled) {
      console.info('[DynamicIcon] season mode disabled, skip refresh');
      return;
    }

    const dynamicIconInfos = await DynamicIconUtils.getDynamicIconInfo();
    const dynamicId = DynamicIconUtils.getCurrentSeasonDynamicIconId(dynamicIconInfos);

    if (!dynamicId) {
      console.error('[DynamicIcon]', 'refreshSeasonIconIfNeeded failed: no matched current season icon');
      return;
    }

    console.info(`[DynamicIcon] refresh season icon: dynamicId=${dynamicId}`);

    await DynamicIconUtils.setDynamicIcon(dynamicId);
  }
}