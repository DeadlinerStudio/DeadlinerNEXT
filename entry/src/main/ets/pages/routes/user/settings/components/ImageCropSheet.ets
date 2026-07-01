import * as image_cropper from "@candies/image_cropper";
import { ImageCropper } from "@candies/image_cropper";
import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { Luban, LubanUtils } from '@ark/luban';
import { ITheme } from "../../../../../common/theme/ThemeModel";
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { promptAction } from '@kit.ArkUI';

/**
 * 图片裁剪 Sheet 组件
 * 现已支持内部唤起相册选图、恢复默认及模糊开关操作
 */
@Component
export struct ImageCropSheet {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @State imageSource: image.ImageSource | undefined = undefined;
  @State isLoading: boolean = false;

  // 外部传入配置
  cropRatio: number | undefined = undefined;
  @Prop title: string = '自定义背景';
  @Prop enableCompression: boolean = true;
  @Prop saveDirName: string = 'imported_icons';

  private controller: image_cropper.ImageCropperController = new image_cropper.ImageCropperController();
  @State config: image_cropper.ImageCropperConfig = new image_cropper.ImageCropperConfig({
    maxScale: 8,
    cropRectPadding: image_cropper.geometry.EdgeInsets.all(20),
    controller: this.controller,
    initCropRectType: image_cropper.InitCropRectType.imageRect,
    cropAspectRatio: image_cropper.CropAspectRatios.ratio1_1,
  });

  @Prop @Watch('onSourceUriChange') sourceUri: string = '';

  // --- 新增：模糊开关状态 ---
  // 接收外部传入的初始模糊状态，便于用户重新进入时回显
  @Prop initBlurState: boolean = false;
  @State isBlurEnabled: boolean = false;
  // -----------------------

  // --- 修改：回调增加 isBlur 参数 ---
  onComplete?: (croppedUri: string, isBlur: boolean) => void;
  // ---------------------------------

  onCancel?: () => void;
  onClearBackground?: () => void;

  @StorageLink('bottomRectHeight') bottomRectHeight: number = 0;

  aboutToAppear(): void {
    this.initConfig();
    // 初始化模糊开关状态
    this.isBlurEnabled = this.initBlurState;
    if (this.sourceUri) {
      this.loadImage();
    }
  }

  onSourceUriChange() {
    if (this.sourceUri) {
      this.loadImage();
    } else {
      this.imageSource = undefined;
    }
  }

  private initConfig() {
    this.config = new image_cropper.ImageCropperConfig({
      maxScale: 8,
      cropRectPadding: image_cropper.geometry.EdgeInsets.all(20),
      controller: this.controller,
      initCropRectType: image_cropper.InitCropRectType.imageRect,
      cropAspectRatio: this.cropRatio ?? image_cropper.CropAspectRatios.ratio1_1,
    });
  }

  async pickImageFromGallery() {
    try {
      const photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;

      const photoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const photoSelectResult = await photoViewPicker.select(photoSelectOptions);

      if (photoSelectResult && photoSelectResult.photoUris.length > 0) {
        this.sourceUri = photoSelectResult.photoUris[0];
      }
    } catch (err) {
      console.error('[ImageCrop] Pick image failed:', err);
    }
  }

  private async loadImage(): Promise<void> {
    this.isLoading = true;
    try {
      let filePath = this.sourceUri;
      if (this.sourceUri.startsWith('file://')) {
        filePath = new fileUri.FileUri(this.sourceUri).path;
      }
      const file = await fileIo.open(filePath, fileIo.OpenMode.READ_ONLY);
      this.imageSource = image.createImageSource(file.fd);
      this.isLoading = false;
    } catch (e) {
      console.error('[ImageCrop] Load image failed:', e);
      this.isLoading = false;
      this.imageSource = undefined;
    }
  }

  private async cropAndSave(): Promise<void> {
    if (!this.imageSource) {
      promptAction.showToast({ message: '请先选择图片' });
      return;
    }

    this.isLoading = true;
    try {
      const pixelMap = await this.controller.getCroppedImage();
      if (!pixelMap) {
        console.error('[ImageCrop] Get cropped image failed');
        this.isLoading = false;
        return;
      }

      const context = getContext(this) as common.UIAbilityContext;
      const iconDir = `${context.filesDir}/${this.saveDirName}`;

      try {
        await fileIo.mkdir(iconDir);
      } catch (e) {}

      const isWallpaper = !this.enableCompression;
      const format = isWallpaper ? 'image/jpeg' : 'image/png';
      const quality = isWallpaper ? 90 : 100;
      const ext = isWallpaper ? 'jpg' : 'png';

      const tempFileName = `temp_${Date.now()}.${ext}`;
      const tempPath = `${iconDir}/${tempFileName}`;
      const tempFile = await fileIo.open(tempPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);

      const imagePacker = image.createImagePacker();
      const packData = await imagePacker.packing(pixelMap, { format: format, quality: quality });
      await fileIo.write(tempFile.fd, packData);
      await fileIo.close(tempFile);

      const targetFileName = `bg_${Date.now()}.${ext}`;
      const targetPath = `${iconDir}/${targetFileName}`;

      if (this.enableCompression) {
        try {
          const compressedFiles = await Luban.with(tempPath)
            .ignoreBy(50)
            .setFocusAlpha(true)
            .setTargetDir(iconDir)
            .onRename(() => targetFileName)
            .get();

          if (compressedFiles && compressedFiles.length > 0) {
            const compressedPath = compressedFiles[0];
            try { fileIo.unlinkSync(tempPath); } catch (e) {}
            const savedUri = `file://${compressedPath}`;
            this.isLoading = false;
            // --- 修改：传回模糊状态 ---
            if (this.onComplete) this.onComplete(savedUri, this.isBlurEnabled);
            return;
          }
        } catch (lubanErr) {
          console.error(`[ImageCrop] Luban compress failed: ${lubanErr}`);
        }
      }

      try {
        await fileIo.moveFile(tempPath, targetPath);
      } catch (moveErr) {
        fileIo.copyFileSync(tempPath, targetPath);
        try { fileIo.unlinkSync(tempPath); } catch (e) {}
      }

      const savedUri = `file://${targetPath}`;
      this.isLoading = false;
      // --- 修改：传回模糊状态 ---
      if (this.onComplete) this.onComplete(savedUri, this.isBlurEnabled);

    } catch (e) {
      console.error('[ImageCrop] Crop and save failed:', e);
      this.isLoading = false;
    }
  }

  @Builder
  customTitleBar() {
    Stack({ alignContent: Alignment.Center }) {
      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(24)
            .fontColor([$r('app.color.font_primary')])
        }
        .width(40)
        .height(40)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .onClick(() => {
          if (this.onCancel) this.onCancel();
        })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .padding({ left: 16 })
      .hitTestBehavior(HitTestMode.Transparent)

      Column() {
        Text(this.title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.font_primary'))
      }
      .justifyContent(FlexAlign.Center)
      .hitTestBehavior(HitTestMode.None)

      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(24)
            .fontColor([this.theme.brand])
        }
        .width(40)
        .height(40)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .onClick(() => {
          this.cropAndSave();
        })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
      .padding({ right: 16 })
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height(56)
  }

  build() {
    Column() {
      this.customTitleBar()

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.imageSource) {
        Stack() {
          ImageCropper({
            image: this.imageSource,
            config: this.config,
          })
            .width('100%')
            .height('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#000000')

      } else {
        Column({ space: 16 }) {
          SymbolGlyph($r('sys.symbol.picture'))
            .fontSize(64)
            .fontColor([$r('app.color.font_secondary')])
          Text('暂未选择图片')
            .fontSize(16)
            .fontColor($r('app.color.font_secondary'))
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }

      // --- 新增：模糊控制开关区域 ---
      if (this.imageSource && !this.enableCompression) {
        // 仅在选择了图片，且是壁纸模式（没开启强制压缩）时显示这个设置
        Row() {
          Text('背景模糊效果')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.font_primary'))

          Toggle({ type: ToggleType.Switch, isOn: this.isBlurEnabled })
            .selectedColor(this.theme.brand)
            .onChange((isOn: boolean) => {
              this.isBlurEnabled = isOn;
            })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 16, bottom: 8 })
        .justifyContent(FlexAlign.SpaceBetween)
        // .backgroundColor(this.theme.bgPrimary)
      }
      // ----------------------------

      Row() {
        Column() {
          SymbolGlyph($r('sys.symbol.picture_and_pencil'))
            .fontSize(24)
            .fontColor([$r('app.color.font_primary')])
          Text('更换图片')
            .fontSize(12)
            .fontColor($r('app.color.font_secondary'))
            .margin({ top: 4 })
        }
        .onClick(() => this.pickImageFromGallery())

        if (this.imageSource) {
          Column() {
            SymbolGlyph($r('sys.symbol.arrow_counterclockwise'))
              .fontSize(24)
              .fontColor([$r('app.color.font_primary')])
            Text('旋转')
              .fontSize(12)
              .fontColor($r('app.color.font_secondary'))
              .margin({ top: 4 })
          }
          .onClick(() => this.controller.rotate({ animation: true }))

          Column() {
            SymbolGlyph($r('sys.symbol.arrow_clockwise'))
              .fontSize(24)
              .fontColor([$r('app.color.font_primary')])
            Text('重置框')
              .fontSize(12)
              .fontColor($r('app.color.font_secondary'))
              .margin({ top: 4 })
          }
          .onClick(() => this.controller.reset())
        }

        Column() {
          SymbolGlyph($r('sys.symbol.trash'))
            .fontSize(24)
            .fontColor([$r('app.color.warning')])
          Text('恢复默认')
            .fontSize(12)
            .fontColor($r('app.color.warning'))
            .margin({ top: 4 })
        }
        .onClick(() => {
          if (this.onClearBackground) this.onClearBackground();
        })

      }
      .width('100%')
      .padding({
        top: 8, // 因为上面有模糊开关，这里 top 间距稍微改小一点
        bottom: this.getUIContext().px2vp(this.bottomRectHeight) + 16
      })
      .justifyContent(FlexAlign.SpaceAround)

    }
    .width('100%')
    .height('100%')
    // .backgroundColor(this.theme.bgPrimary)
  }
}