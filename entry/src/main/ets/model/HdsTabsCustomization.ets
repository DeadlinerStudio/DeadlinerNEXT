import { TabBrandPalette } from '../common/theme/ThemeModel';

export enum HdsTabId {
  LIST = 'list',
  OVERVIEW = 'overview',
  CAPTURE = 'capture',
  AI = 'ai',
  USER = 'user'
}

export enum HdsTabSymbolRendering {
  MULTIPLE_OPACITY = 'MULTIPLE_OPACITY',
  SINGLE = 'SINGLE'
}

export interface HdsTabDescriptor {
  id: string;
  title: string;
  icon: Resource;
  brandPalette: TabBrandPalette;
  isImage: boolean;
  canHide: boolean;
}

export class HdsTabsCustomization {
  private static readonly DEFAULT_ORDER: string[] = [
    HdsTabId.LIST,
    HdsTabId.OVERVIEW,
    HdsTabId.CAPTURE,
    HdsTabId.AI,
    HdsTabId.USER
  ];

  private static readonly TABS: HdsTabDescriptor[] = [
    {
      id: HdsTabId.LIST,
      title: '清单',
      icon: $r('sys.symbol.house_fill'),
      brandPalette: {
        brand: $r('app.color.module_list'),
        brand50: $r('app.color.module_list_50')
      },
      isImage: false,
      canHide: false
    },
    {
      id: HdsTabId.OVERVIEW,
      title: '概览',
      icon: $r('sys.symbol.data_proportion_fill'),
      brandPalette: {
        brand: $r('app.color.module_overview'),
        brand50: $r('app.color.module_overview_50')
      },
      isImage: false,
      canHide: true
    },
    {
      id: HdsTabId.CAPTURE,
      title: '灵感',
      icon: $r('app.media.capture'),
      brandPalette: {
        brand: $r('app.color.module_capture'),
        brand50: $r('app.color.module_capture_50')
      },
      isImage: true,
      canHide: true
    },
    {
      id: HdsTabId.AI,
      title: 'AI',
      icon: $r('app.media.lifi'),
      brandPalette: {
        brand: $r('app.color.module_ai'),
        brand50: $r('app.color.module_ai_50')
      },
      isImage: true,
      canHide: true
    },
    {
      id: HdsTabId.USER,
      title: '我的',
      icon: $r('sys.symbol.person_crop_circle_fill_1'),
      brandPalette: {
        brand: $r('app.color.module_user'),
        brand50: $r('app.color.module_user_50')
      },
      isImage: false,
      canHide: false
    }
  ];

  static defaultOrder(): string[] {
    return [
      HdsTabId.LIST,
      HdsTabId.OVERVIEW,
      HdsTabId.CAPTURE,
      HdsTabId.AI,
      HdsTabId.USER
    ];
  }

  static defaultHiddenTabs(): string[] {
    return [];
  }

  static defaultSymbolRendering(): string {
    return HdsTabSymbolRendering.MULTIPLE_OPACITY;
  }

  static encodeTabIds(tabIds: string[]): string {
    return tabIds.join('|');
  }

  static decodeTabIds(rawValue: string): string[] {
    return rawValue.length === 0 ? [] : rawValue.split('|');
  }

  static normalizeOrder(rawOrder: string[]): string[] {
    const normalized: string[] = [];
    rawOrder.forEach((id: string) => {
      if (HdsTabsCustomization.isKnownTab(id) && !normalized.includes(id)) {
        normalized.push(id);
      }
    });

    HdsTabsCustomization.DEFAULT_ORDER.forEach((id: string) => {
      if (!normalized.includes(id)) {
        normalized.push(id);
      }
    });
    return normalized;
  }

  static normalizeHiddenTabs(rawHiddenTabs: string[]): string[] {
    const normalized: string[] = [];
    rawHiddenTabs.forEach((id: string) => {
      const tab = HdsTabsCustomization.getTab(id);
      if (tab.canHide && !normalized.includes(id)) {
        normalized.push(id);
      }
    });
    return normalized;
  }

  static normalizeSymbolRendering(rawRendering: string): string {
    return rawRendering === HdsTabSymbolRendering.SINGLE
      ? HdsTabSymbolRendering.SINGLE
      : HdsTabSymbolRendering.MULTIPLE_OPACITY;
  }

  static getOrderedTabs(rawOrder: string[]): HdsTabDescriptor[] {
    const normalizedOrder = HdsTabsCustomization.normalizeOrder(rawOrder);
    const tabs: HdsTabDescriptor[] = [];
    normalizedOrder.forEach((id: string) => {
      tabs.push(HdsTabsCustomization.getTab(id));
    });
    return tabs;
  }

  static getVisibleTabs(rawOrder: string[], rawHiddenTabs: string[]): HdsTabDescriptor[] {
    const hiddenTabs = HdsTabsCustomization.normalizeHiddenTabs(rawHiddenTabs);
    return HdsTabsCustomization.getOrderedTabs(rawOrder)
      .filter((tab: HdsTabDescriptor) => !tab.canHide || !hiddenTabs.includes(tab.id));
  }

  static getHiddenTabs(rawOrder: string[], rawHiddenTabs: string[]): HdsTabDescriptor[] {
    const hiddenTabs = HdsTabsCustomization.normalizeHiddenTabs(rawHiddenTabs);
    return HdsTabsCustomization.getOrderedTabs(rawOrder)
      .filter((tab: HdsTabDescriptor) => tab.canHide && hiddenTabs.includes(tab.id));
  }

  static isTabVisible(tabId: string, rawHiddenTabs: string[]): boolean {
    const tab = HdsTabsCustomization.getTab(tabId);
    if (!tab.canHide) {
      return true;
    }
    return !HdsTabsCustomization.normalizeHiddenTabs(rawHiddenTabs).includes(tabId);
  }

  static isSingleSymbolRendering(rendering: string): boolean {
    return HdsTabsCustomization.normalizeSymbolRendering(rendering) === HdsTabSymbolRendering.SINGLE;
  }

  static getDisplayIcon(tabId: string, rendering: string): Resource {
    if (tabId === HdsTabId.CAPTURE && !HdsTabsCustomization.isSingleSymbolRendering(rendering)) {
      return $r('app.media.capture_mo');
    }
    return HdsTabsCustomization.getTab(tabId).icon;
  }

  private static isKnownTab(tabId: string): boolean {
    return tabId === HdsTabId.LIST || tabId === HdsTabId.OVERVIEW ||
      tabId === HdsTabId.CAPTURE || tabId === HdsTabId.AI || tabId === HdsTabId.USER;
  }

  private static getTab(tabId: string): HdsTabDescriptor {
    for (let index = 0; index < HdsTabsCustomization.TABS.length; index += 1) {
      const tab = HdsTabsCustomization.TABS[index];
      if (tab.id === tabId) {
        return tab;
      }
    }
    return HdsTabsCustomization.TABS[0];
  }
}
