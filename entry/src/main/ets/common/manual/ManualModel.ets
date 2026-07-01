import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';

export interface ManualItem {
  id: string;
  title: string;
  subtitle?: string;
  iconName?: string;  // JSON 里存的名字
  icon?: Resource;    // 运行时转换后的资源对象
  fileName: string;   // MD 文件名
  content?: string;   // 运行时加载的 MD 内容
  themeColor?: string;
  isImage?: boolean;
}

export interface ManualSection {
  title: string;
  items: ManualItem[];
}

// 2. 图标映射表 (String -> Resource)
// 因为 JSON 不能存 Resource，我们需要手动映射一下常用的
const ICON_MAP: Record<string, Resource> = {
  // 原有的
  'lightbulb': $r('sys.symbol.lightbulb'),
  'plus_circle': $r('sys.symbol.plus_circle'),
  'lifi': $r('app.media.lifi'),
  'archivebox': $r('sys.symbol.archivebox'),
  'hand_draw': $r('sys.symbol.hand_draw'),             // 手势
  'chart_bar': $r('sys.symbol.data_proportion'),             // 统计
  'cloud': $r('sys.symbol.cloud'),                     // WebDAV
  'gear_shape': $r('sys.symbol.gearshape'),           // 配置
  'questionmark_circle': $r('sys.symbol.questionmark_circle'), // FAQ
  'bell': $r('sys.symbol.bell'),
  'crossplatform': $r('sys.symbol.matebook_and_phone_fill'),
  'widgets': $r('sys.symbol.rectangle_stack'),
};

export class ManualDataManager {
  private static instance: ManualDataManager;

  // 缓存目录结构，避免每次进页面都读 IO
  private cachedSections: ManualSection[] | null = null;
  private itemMap: Map<string, ManualItem> = new Map();

  private constructor() {}

  public static getInstance(): ManualDataManager {
    if (!ManualDataManager.instance) {
      ManualDataManager.instance = new ManualDataManager();
    }
    return ManualDataManager.instance;
  }

  /**
   * 加载目录结构 (menu.json)
   */
  async loadMenu(context: Context): Promise<ManualSection[]> {
    if (this.cachedSections) {
      return this.cachedSections;
    }

    try {
      const resourceManager = context.resourceManager;
      // 读取 menu.json
      const fileData = await resourceManager.getRawFileContent('help/menu.json');
      const textDecoder = new util.TextDecoder('utf-8', { ignoreBOM: true });
      const jsonString = textDecoder.decodeWithStream(fileData);

      const rawSections = JSON.parse(jsonString) as ManualSection[];

      // 处理数据：映射图标 Resource
      rawSections.forEach(section => {
        section.items.forEach(item => {
          if (item.iconName && ICON_MAP[item.iconName]) {
            item.icon = ICON_MAP[item.iconName];
          } else {
            item.icon = $r(`sys.symbol.doc_text`); // 默认图标
          }
        });
      });

      this.cachedSections = rawSections;

      this.buildItemMap();

      return rawSections;

    } catch (error) {
      console.error('[ManualDataManager] Load menu failed:', error);
      return [];
    }
  }

  private buildItemMap() {
    if (!this.cachedSections) return;
    this.itemMap.clear();
    for (const section of this.cachedSections) {
      for (const item of section.items) {
        if (item.id) {
          this.itemMap.set(item.id, item);
        }
      }
    }
  }

  public getItemById(id: string): ManualItem | undefined {
    return this.itemMap.get(id);
  }

  /**
   * 加载具体的 MD 内容
   */
  async loadContent(context: Context, fileName: string): Promise<string> {
    try {
      const resourceManager = context.resourceManager;
      const fileData = await resourceManager.getRawFileContent(`help/manual/${fileName}`);
      const textDecoder = new util.TextDecoder('utf-8', { ignoreBOM: true });
      return textDecoder.decodeWithStream(fileData);
    } catch (error) {
      console.error(`[ManualDataManager] Load content failed: ${fileName}`, error);
      return '# 加载失败\n无法找到文档内容。';
    }
  }
}