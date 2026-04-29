import { SettingsCheckItem, SettingsDivider, SettingsSection } from "../../../../components/SettingsComponents"
import { SeasonUtils } from "../../../../../utils/SeasonUtils";
import { DynamicIconUtils } from "../../../../../utils/DynamicIconUtils";
import { appInfoManager } from "@kit.AppGalleryKit";
import { common } from "@kit.AbilityKit";

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

  @State seasonPreviewIndex: number = 0;
  @State seasonPreviewKey: string = 'season-0';

  @State seasonPreviewOpacity: number = 1;
  @State seasonPreviewScale: number = 1;

  private seasonPreviewTimer: number = -1;

  private readonly seasons: Season[] = ['spring', 'summer', 'autumn', 'winter'];

  async aboutToAppear(): Promise<void> {
    const context = getContext(this) as common.Context;

    this.dynamicIconInfos = await DynamicIconUtils.getDynamicIconInfo();

    this.dynamicIcons = [
      { id: 'default', url: $r('app.media.icon'), title: '默认' }
    ];

    const isSeasonModeEnabled = await DynamicIconUtils.isSeasonModeEnabled(context);

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

    if (DynamicIconUtils.hasAllSeasonIcons(this.dynamicIconInfos)) {
      if (isSeasonModeEnabled) {
        this.selectedIconId = 'season';
      }

      this.startSeasonPreviewTimer();
    }
  }

  aboutToDisappear(): void {
    this.stopSeasonPreviewTimer();
  }

  startSeasonPreviewTimer(): void {
    this.stopSeasonPreviewTimer();

    this.seasonPreviewTimer = setInterval(() => {
      this.seasonPreviewOpacity = 0;
      this.seasonPreviewScale = 0.92;

      setTimeout(() => {
        const nextIndex = (this.seasonPreviewIndex + 1) % this.seasons.length;

        this.seasonPreviewIndex = nextIndex;
        this.seasonPreviewKey = `season-${nextIndex}-${Date.now()}`;

        this.seasonPreviewOpacity = 1;
        this.seasonPreviewScale = 1;

        console.info(`[DynamicIcon] season preview changed: index=${nextIndex}, season=${this.seasons[nextIndex]}`);
      }, 180);
    }, 1600);
  }

  stopSeasonPreviewTimer(): void {
    if (this.seasonPreviewTimer !== -1) {
      clearInterval(this.seasonPreviewTimer);
      this.seasonPreviewTimer = -1;
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
      return info.iconId.toLowerCase().includes(season);
    });
  }

  getSeasonIconInfo(season: Season): appInfoManager.DynamicIconInfo | undefined {
    return this.dynamicIconInfos.find((info: appInfoManager.DynamicIconInfo): boolean => {
      return info.iconId.toLowerCase().includes(season);
    });
  }

  getSeasonPreviewIconResource(): ResourceStr {
    const season = this.seasons[this.seasonPreviewIndex];
    const matchedInfo = this.getSeasonIconInfo(season);

    if (matchedInfo) {
      return matchedInfo.iconUrl;
    }

    return $r('app.media.icon');
  }

  getCurrentSeasonDynamicIconId(): string | undefined {
    const season = SeasonUtils.getCurrentSeason(new Date());

    const matchedInfo = this.dynamicIconInfos.find((info: appInfoManager.DynamicIconInfo): boolean => {
      return info.iconId.toLowerCase().includes(season);
    });

    return matchedInfo?.iconId;
  }

  async setIconById(id: string): Promise<void> {
    const context = getContext(this) as common.Context;

    if (id === 'default') {
      await DynamicIconUtils.disableDynamicIcon();
      await DynamicIconUtils.setSeasonModeEnabled(context, false);
      return;
    }

    let dynamicId: string | undefined = id;

    if (id === 'season') {
      dynamicId = DynamicIconUtils.getCurrentSeasonDynamicIconId(this.dynamicIconInfos);

      if (!dynamicId) {
        console.error('[DynamicIcon]', `No matched dynamic icon for season mode`);
        return;
      }

      await DynamicIconUtils.setDynamicIcon(dynamicId);
      await DynamicIconUtils.setSeasonModeEnabled(context, true);
      return;
    }

    await DynamicIconUtils.setDynamicIcon(dynamicId);
    await DynamicIconUtils.setSeasonModeEnabled(context, false);
  }

  build() {
    Column() {
      SettingsSection({ bgColor: $r('sys.color.search_container_focus_color') }) {
        ForEach(this.dynamicIcons, (item: DynamicIcon, index: number): void => {
          SettingsCheckItem({
            title: item.title,
            image: item.url,
            isSelected: this.selectedIconId === item.id,
            onItemClick: async () => {
              this.selectedIconId = item.id;
              await this.setIconById(item.id);
            }
          })

          if (index != this.dynamicIcons.length - 1 || this.hasAllSeasonIcons()) {
            SettingsDivider()
          }
        }, (item: DynamicIcon): string => item.id)

        if (this.hasAllSeasonIcons()) {
          SettingsCheckItem({
            title: '季节',
            image: this.getSeasonPreviewIconResource(),
            imageKey: this.seasonPreviewKey,
            imageOpacity: this.seasonPreviewOpacity,
            imageScale: this.seasonPreviewScale,
            isSelected: this.selectedIconId === 'season',
            onItemClick: async () => {
              this.selectedIconId = 'season';
              await this.setIconById('season');
            }
          })
        }
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12 })
    .justifyContent(FlexAlign.Start)
    .constraintSize({ minHeight: '100%' })
  }
}