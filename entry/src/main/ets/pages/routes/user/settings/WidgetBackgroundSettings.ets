import { HdsNavDestination, HdsNavigationTitleMode, HdsNavDestinationAttribute } from '@kit.UIDesignKit';
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';
import { fileIo as fs } from '@kit.CoreFileKit';

import { TopSafeContainer } from '../../../components/TopSafeContainer';
import { SettingsSection, SettingsDivider, SettingsCheckItem } from '../../../components/SettingsComponents';
import { LocalValues } from '../../../../common/local/LocalValues';
import { WidgetData } from '../../../../widget/model/WidgetData';
import { TaskWidgetCardSmallPreviewBuilder } from '../../../../widget/pages/TaskWidgetCardSmall';
import { formBindingData } from '@kit.FormKit';
import { WidgetUpdater } from '../../../../utils/WidgetUpdater';
import { image } from '@kit.ImageKit';
import { getImmersiveTitleBarStyle } from '../../../../common/style/NavStyles';

let storage = new LocalStorage();

@Builder
export function WidgetBackgroundSettingsBuilder() {
  // 关键修复点 A：必须将 storage 实例传递给组件
  WidgetBackgroundSettings({}, storage)
}

@Component
struct WidgetBackgroundSettings {
  @StorageProp('statusBarHeight') statusBarHeight: number = 38;
  readonly TITLE_BAR_CONTENT_HEIGHT: number = 18;

  // 这里的 Link 会与传入的 storage 绑定，同时驱动预览组件的 Prop
  @LocalStorageLink('widgetData') widgetData: WidgetData = new WidgetData();

  @StorageLink('isWideScreen') isWideScreen: boolean = false;

  @State currentBgPath: string = '';
  private context = getContext(this) as common.UIAbilityContext;

  async aboutToAppear() {
    // 初始化模拟数据
    this.widgetData.themeKey = AppStorage.get<string>('currentThemeKey') ?? 'vibrant';
    this.widgetData.totalCount = 3;
    this.widgetData.tasks = [
      { title: '完成图形学作业', timeDesc: '2小时', isUrgent: true },
      { title: '去取快递', timeDesc: '1天后', isUrgent: false },
      { title: '鸿蒙开发上架', timeDesc: '7天后', isUrgent: false }
    ];

    // 加载配置
    this.currentBgPath = LocalValues.getInstance().getWidgetBackgroundImage();
    // 关键修复点 B：确保路径带有 file:// 前缀，否则 Image 组件可能无法加载沙箱文件
    if (this.currentBgPath && !this.currentBgPath.startsWith('file://')) {
      this.widgetData.backgroundImage = 'file://' + this.currentBgPath;
    } else {
      this.widgetData.backgroundImage = this.currentBgPath;
    }
  }

  async selectImage() {
    try {
      const photoPicker = new picker.PhotoViewPicker();
      const result = await photoPicker.select({
        MIMEType: picker.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      });

      if (result.photoUris.length > 0) {
        this.resetBackground();
        await this.saveImageToSandbox(result.photoUris[0]);
      }
    } catch (e) {
      console.error('Photo picker failed', e);
    }
  }

  resetBackground() {
    this.currentBgPath = '';
    this.widgetData.backgroundImage = ''; // 清空预览

    LocalValues.getInstance().setWidgetBackgroundImage('');
    this.widgetData.isWhiteText = false; // 默认渐变色背景较浅，通常用深色字，或者根据你原本的设计
    LocalValues.getInstance().setWidgetIsWhiteText(false);

    this.updateDesktopWidget();

    promptAction.showToast({ message: '已恢复默认样式' });
  }

  /**
   * 修复方案：按比例缩放保存，依靠 Widget 的 ImageFit.Cover 进行视觉裁切
   * 解决“异常拉伸”问题
   */
  async saveImageToSandbox(originalUri: string) {
    let fileFd: number | null = null;
    let imageSource: image.ImageSource | null = null;
    let pixelMap: image.PixelMap | null = null;

    try {
      const fileName = `widget_bg_small.jpg`;
      const targetPath = this.context.filesDir + '/' + fileName;

      // 1. 打开源文件
      const file = fs.openSync(originalUri, fs.OpenMode.READ_ONLY);
      fileFd = file.fd;

      // 2. 创建 ImageSource
      imageSource = image.createImageSource(fileFd);

      // 3. 获取原图信息
      const imageInfo = await imageSource.getImageInfo();
      const w = imageInfo.size.width;
      const h = imageInfo.size.height;

      console.info(`[Settings] Original Size: ${w}x${h}`);

      // 4. 计算缩放后的尺寸 (保持比例，限制最大边为 1024，或者短边为 512)
      // 这里策略是：让短边至少为 512，保证清晰度
      const targetShortSide = 512;
      let scale = 1;
      let targetW = w;
      let targetH = h;

      if (w < h) {
        // 宽是短边
        scale = targetShortSide / w;
      } else {
        // 高是短边
        scale = targetShortSide / h;
      }

      // 如果原图本身就比 512 小，就不放大，保持原样
      if (scale > 1) scale = 1;

      targetW = Math.round(w * scale);
      targetH = Math.round(h * scale);

      console.info(`[Settings] Target Size: ${targetW}x${targetH} (Scale: ${scale})`);

      // 5. 设置解码参数：只缩放，不裁切
      // 移除 desiredRegion，避免“拉伸”BUG
      const decodingOpts: image.DecodingOptions = {
        editable: true,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
        desiredSize: { width: targetW, height: targetH }
      };

      // 6. 生成保持比例的 PixelMap
      pixelMap = await imageSource.createPixelMap(decodingOpts);

      // 7. 计算亮度
      // 虽然是全图亮度，但在 Cover 模式下，通常全图亮度和中心区域亮度差别不会导致文字彻底看不清
      const isDarkBg = await this.calculatePixelMapBrightness(pixelMap);
      console.info(`[Settings] Background is dark? ${isDarkBg}`);

      LocalValues.getInstance().setWidgetIsWhiteText(isDarkBg);
      this.widgetData.isWhiteText = isDarkBg;

      // 8. 压缩保存
      const imagePacker = image.createImagePacker();
      const packingOpts: image.PackingOption = { format: "image/jpeg", quality: 70 };

      const data: ArrayBuffer = await imagePacker.packing(pixelMap, packingOpts);

      console.info(`[Settings] Final saved size: ${data.byteLength / 1024} KB`);

      const targetFile = fs.openSync(targetPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(targetFile.fd, data);
      fs.closeSync(targetFile);

      imagePacker.release();

      // --- 后续流程 ---
      this.currentBgPath = targetPath;
      this.widgetData.backgroundImage = 'file://' + targetPath;
      LocalValues.getInstance().setWidgetBackgroundImage(targetPath);

      // 触发更新
      this.updateDesktopWidget();

      promptAction.showToast({ message: '背景已设置' });

    } catch (e) {
      console.error('Save/Scale image failed', JSON.stringify(e));
      promptAction.showToast({ message: '图片处理失败' });
    } finally {
      if (pixelMap) pixelMap.release();
      if (imageSource) imageSource.release();
      if (fileFd !== null) fs.closeSync(fileFd);
    }
  }

  /**
   * 辅助方法：计算 PixelMap 的亮度
   * 替代之前的 ImageUtils.isDarkImage(fd)，因为这里只有 PixelMap
   */
  async calculatePixelMapBrightness(pixelMap: image.PixelMap): Promise<boolean> {
    try {
      const info = await pixelMap.getImageInfo();
      const totalPixels = info.size.width * info.size.height;

      // 读取像素数据
      const bufferSize = pixelMap.getPixelBytesNumber();
      const buffer = new ArrayBuffer(bufferSize);
      await pixelMap.readPixelsToBuffer(buffer);

      const data = new Uint8Array(buffer);
      let totalLuminance = 0;

      // 简单抽样计算 (每隔 10 个像素取样一次，提升性能)
      const step = 4 * 10; // RGBA * 10
      let sampledCount = 0;

      for (let i = 0; i < data.length; i += step) {
        const r = data[i];
        const g = data[i + 1];
        const b = data[i + 2];

        // 亮度公式
        totalLuminance += (0.299 * r + 0.587 * g + 0.114 * b);
        sampledCount++;
      }

      const avgLuminance = totalLuminance / sampledCount;
      console.info(`[Settings] Avg Luminance: ${avgLuminance}`);

      // 阈值：< 140 算深色 (需要白字)
      return avgLuminance < 140;
    } catch (e) {
      console.error('Calc brightness failed', e);
      return true; // 失败默认当深色处理
    }
  }

  updateDesktopWidget() {
    const context = this.context;
    if (context) {
      console.info('[WidgetBackgroundSettings] Updating widgets now...');
      WidgetUpdater.updateAllWidgets(context);
    }
  }

  build() {
    HdsNavDestination() {
      TopSafeContainer({ topAvoidHeight: this.statusBarHeight + this.TITLE_BAR_CONTENT_HEIGHT }) {
        Column({ space: 16 }) {
          SettingsSection() {
            Column() {
              Stack({ alignContent: Alignment.Center }) {
                // 这里的 PreviewBuilder 会自动使用父容器的 storage
                TaskWidgetCardSmallPreviewBuilder()
              }
              .width(160)
              .height(156)
              .borderRadius(24) // 增加圆角适配
              .clip(true) // 关键：裁剪掉超出圆角的内容，保证预览效果真实
            }
            .width('100%')
            .height(220)
            .justifyContent(FlexAlign.Center)
          }

          SettingsSection({ title: '背景风格' }) {
            SettingsCheckItem({
              title: "默认极光渐变",
              icon: $r('sys.symbol.display'),
              isSelected: !this.currentBgPath || this.currentBgPath === '',
              onItemClick: () => {
                this.resetBackground();
              }
            })

            SettingsDivider()

            SettingsCheckItem({
              title: "自定义图片",
              icon: $r('sys.symbol.picture'),
              isSelected: !!this.currentBgPath && this.currentBgPath.length > 0,
              onItemClick: () => {
                this.selectImage();
              }
            })
          }

          Text('设置背景后，小组件将自动启用“半透明磨砂”效果以保证文字可读性。建议选择色彩较深或纹理简单的图片。')
            .fontSize(12)
            .lineHeight(16)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .padding({ left: 24, right: 24, top: 8, bottom: 24 })
            .width('100%')
        }
        .width('100%')
        .padding(16)
        .justifyContent(FlexAlign.Start)
        .constraintSize({ minHeight: '100%' })
      }
    }
    .titleBar({
      style: getImmersiveTitleBarStyle(this.isWideScreen),
      content: { title: { mainTitle: "小组件样式" } }
    })
  }
}
