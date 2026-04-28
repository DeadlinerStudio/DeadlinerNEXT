import { SettingsCheckItem, SettingsDivider, SettingsSection } from "../../../../components/SettingsComponents"
import appInfoManager from "@hms.core.appgalleryservice.appInfoManager"
import { SeasonUtils } from "../../../../../utils/SeasonUtils";

interface DynamicIcon {
  id: string,
  url: ResourceStr,
  title: string
}

type Season = 'spring' | 'summer' | 'autumn' | 'winter'

@Component
export struct IconSelectSheet {

  @State dynamicIconInfos: appInfoManager.DynamicIconInfo[] = [];
  @State dynamicIcons: DynamicIcon[] = [
    { id: 'default', url: $r('app.media.icon'), title: '默认' }
  ];

  @State selectedIconId: string = 'default';

  async aboutToAppear(): Promise<void> {
    this.dynamicIconInfos = await this.getDynamicIconInfo();

    this.dynamicIcons = [
      { id: 'default', url: $r('app.media.icon'), title: '默认' }
    ];

    for (let i = 0; i < this.dynamicIconInfos.length; i++) {
      const info = this.dynamicIconInfos[i];

      this.dynamicIcons.push({
        id: info.iconId,
        url: info.iconUrl,
        title: this.getIconTitleById(info.iconId)
      })

      if (info.enabled) {
        this.selectedIconId = info.iconId;
      }
    }

    /**
     * 不再用 this.dynamicIconInfos.length === 4 判断。
     * 因为实际可能是：
     * - Spring-Phone
     * - Spring-Tablet
     * - Summer-Phone
     * - Summer-Tablet
     *
     * 只要当前设备可用的动态图标里，四季都至少各有一个，就显示“季节”项。
     */
    if (this.hasAllSeasonIcons()) {
      this.dynamicIcons.push({
        id: 'season',
        url: this.getCurrentSeasonIconResource(),
        title: '季节'
      });
    }
  }

  async getDynamicIconInfo(): Promise<appInfoManager.DynamicIconInfo[]> {
    try {
      return await appInfoManager.queryDynamicIcons()
    } catch (error) {
      console.error('[DynamicIcon]', "queryDynamicIcons exception code: " + error.code + ", exception message: " + error.message);
      return [];
    }
  }

  getIconTitleById(id: string): string {
    const raw = id.toLowerCase();

    if (raw.includes('spring')) {
      return '春';
    } else if (raw.includes('summer')) {
      return '夏';
    } else if (raw.includes('autumn')) {
      return '秋';
    } else if (raw.includes('winter')) {
      return '冬';
    } else {
      return '(未知)';
    }
  }

  hasAllSeasonIcons(): boolean {
    return this.hasSeasonIcon('spring') &&
      this.hasSeasonIcon('summer') &&
      this.hasSeasonIcon('autumn') &&
      this.hasSeasonIcon('winter');
  }

  hasSeasonIcon(season: Season): boolean {
    return this.dynamicIconInfos.some((info: appInfoManager.DynamicIconInfo): boolean => {
      return info.enabled && info.iconId.toLowerCase().includes(season);
    });
  }

  /**
   * 根据当前季节，找到真正可传给 selectDynamicIcon() 的 iconId。
   *
   * 例如：
   * - 当前季节 spring
   * - 实际 iconId 是 Spring-Tablet
   * - 返回 Spring-Tablet，而不是 spring
   */
  getCurrentSeasonDynamicIconId(): string | undefined {
    const season = SeasonUtils.getCurrentSeason(new Date());

    const matchedInfo = this.dynamicIconInfos.find((info: appInfoManager.DynamicIconInfo): boolean => {
      return info.enabled && info.iconId.toLowerCase().includes(season);
    });

    return matchedInfo?.iconId;
  }

  /**
   * “季节”设置项显示的图标。
   * 这个图标会根据当前节气季节自动切换成春/夏/秋/冬对应图标。
   */
  getCurrentSeasonIconResource(): ResourceStr {
    const season = SeasonUtils.getCurrentSeason(new Date());

    const matchedInfo = this.dynamicIconInfos.find((info: appInfoManager.DynamicIconInfo): boolean => {
      return info.enabled && info.iconId.toLowerCase().includes(season);
    });

    if (matchedInfo) {
      return matchedInfo.iconUrl;
    }

    return $r('app.media.icon');
  }

  async setIconById(id: string): Promise<void> {
    if (id === 'default') {
      try {
        await appInfoManager.disableDynamicIcon();
      } catch(error) {
        console.error('[DynamicIcon]', "disableDynamicIcon exception code: " + error.code + ", exception message: " + error.message);
      }

      return;
    }

    let dynamicId: string | undefined = id;

    if (id === 'season') {
      dynamicId = this.getCurrentSeasonDynamicIconId();
    }

    if (!dynamicId) {
      console.error('[DynamicIcon]', `No matched dynamic icon for id: ${id}`);
      return;
    }

    await this.setDynamicIcon(dynamicId);
  }

  async setDynamicIcon(dynamicId: string): Promise<void> {
    try {
      await appInfoManager.selectDynamicIcon(dynamicId)
    } catch (error) {
      console.error('[DynamicIcon]',
        "selectDynamicIcon exception code: " + error.code + ", exception message: " + error.message);
    }
  }

  build() {
    Column() {
      SettingsSection() {
        ForEach(this.dynamicIcons, (item: DynamicIcon, index: number): void => {
          SettingsCheckItem({
            title: item.title,
            image: item.id === 'season' ? this.getCurrentSeasonIconResource() : item.url,
            isSelected: this.selectedIconId === item.id,
            onItemClick: async () => {
              this.selectedIconId = item.id;
              await this.setIconById(item.id);
            }
          })

          if (index != this.dynamicIcons.length - 1) {
            SettingsDivider()
          }
        })
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12 })
    .justifyContent(FlexAlign.Start)
    .constraintSize({ minHeight: '100%' })
  }
}