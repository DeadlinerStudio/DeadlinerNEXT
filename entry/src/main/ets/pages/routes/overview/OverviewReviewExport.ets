import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { systemShare } from '@kit.ShareKit';
import { OverviewViewModel } from './OverviewViewModel';
import { Metric } from '../../../utils/OverviewUtils';
import { Toast } from '../../../common/ui/Toast';

@Component
export struct OverviewReviewExport {
  @ObjectLink model: OverviewViewModel;
  @State lightText: boolean = false;
  @State backgroundUri: string = '';
  @State preview: image.PixelMap | null = null;
  @State busy: boolean = false;
  aboutToDisappear(): void { this.preview?.release(); }
  private context(): common.UIAbilityContext | undefined { return AppStorage.get<common.UIAbilityContext>('OverviewAbilityContext'); }
  private async pickBackground(): Promise<void> {
    try {
      const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await picker.select({ MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE, maxSelectNumber: 1 });
      if (result.photoUris.length > 0) { this.backgroundUri = result.photoUris[0]; this.invalidate(); }
    } catch (_error) { Toast.show({ message: '未能选择背景图' }); }
  }
  private invalidate(): void { this.preview?.release(); this.preview = null; }
  @Builder private poster() {
    Stack() {
      if (this.backgroundUri.length > 0) Image(this.backgroundUri).width('100%').height('100%').objectFit(ImageFit.Cover)
      Column({ space: 16 }) {
        Text('Deadliner · ' + this.model.lastMonthName + '复盘').fontColor(this.lightText ? Color.White : '#202124').fontSize(28).fontWeight(FontWeight.Bold).width('100%')
        if (this.model.monthlyAnalysis !== null) {
          Text(this.model.monthlyAnalysis.summary).fontColor(this.lightText ? Color.White : '#202124').fontSize(16).lineHeight(26).width('100%')
          Text(this.model.monthlyAnalysis.keywords.join(' · ')).fontColor(this.lightText ? Color.White : '#202124').fontSize(13).width('100%')
        } else Text('月度洞察暂不可用').fontColor(this.lightText ? Color.White : '#202124').fontSize(16).width('100%')
        ForEach(this.model.metrics, (metric: Metric) => {
          Row({ space: 16 }) {
            Text(metric.label).fontColor(this.lightText ? Color.White : '#202124').fontSize(15).layoutWeight(1)
            Text(metric.value).fontColor(this.lightText ? Color.White : '#202124').fontSize(20).fontWeight(FontWeight.Medium)
          }.width('100%')
        }, (metric: Metric) => metric.label)
        Text('指标按截止日期统计 · 活动按完成日期统计').fontColor(this.lightText ? Color.White : '#202124').fontSize(12).width('100%')
      }.width(360).padding(24).alignItems(HorizontalAlign.Start)
        .backgroundColor(this.backgroundUri.length > 0 ? (this.lightText ? '#99000000' : '#CCFFFFFF') : Color.Transparent)

    }.width(360).backgroundColor(this.lightText ? '#202124' : '#F5F5F7')
  }
  private async render(): Promise<void> {
    this.busy = true;
    try {
      const result: image.PixelMap = await this.getUIContext().getComponentSnapshot().createFromBuilder(() => { this.poster(); }, 300, true, { scale: 2 });
      this.preview?.release(); this.preview = result;
    } catch (_error) { Toast.show({ message: '生成预览失败，请重试' }); }
    finally { this.busy = false; }
  }
  private async file(): Promise<string> {
    const context: common.UIAbilityContext | undefined = this.context();
    if (context === undefined || this.preview === null) throw new Error('请先生成预览');
    const packer: image.ImagePacker = image.createImagePacker();
    try {
      const bytes: ArrayBuffer = await packer.packToData(this.preview, { format: 'image/png', quality: 100 });
      const path: string = context.cacheDir + '/overview-review-' + Date.now().toString() + '.png';
      const output: fileIo.File = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      try { fileIo.writeSync(output.fd, bytes); } finally { fileIo.closeSync(output); }
      return fileUri.getUriFromPath(path);
    } finally { await packer.release(); }
  }
  private async exportImage(save: boolean): Promise<void> {
    this.busy = true;
    try {
      const context: common.UIAbilityContext | undefined = this.context();
      if (context === undefined) throw new Error('页面上下文不可用');
      const uri: string = await this.file();
      if (save) {
        const helper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);
        try {
          const destinations: string[] = await helper.showAssetsCreationDialog([uri], [{ title: 'Deadliner月度复盘', fileNameExtension: 'png', photoType: photoAccessHelper.PhotoType.IMAGE }]);
          if (destinations.length > 0) {
            const source: fileIo.File = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
            const destination: fileIo.File = fileIo.openSync(destinations[0], fileIo.OpenMode.READ_WRITE);
            try { fileIo.copyFileSync(source.fd, destination.fd); } finally { fileIo.closeSync(source); fileIo.closeSync(destination); }
            Toast.show({ message: '已保存到图库' });
          }
        } finally { await helper.release(); }
      } else {
        const data: systemShare.SharedData = new systemShare.SharedData({ utd: 'general.png', uri: uri, title: 'Deadliner月度复盘' });
        const controller: systemShare.ShareController = new systemShare.ShareController(data);
        await controller.show(context, { previewMode: systemShare.SharePreviewMode.DETAIL });
      }
    } catch (error) { Toast.show({ message: '导出失败：' + String(error) }); }
    finally { this.busy = false; }
  }
  build() {
    Column({ space: 16 }) {
      Text('复盘分享').fontSize(18).fontWeight(FontWeight.Medium).width('100%')
      Row() {
        Text('浅色文字').layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.lightText }).onChange((value: boolean) => { this.lightText = value; this.invalidate(); })
      }.width('100%')
      Row({ space: 12 }) {
        Button('选择背景图').enabled(!this.busy).onClick(() => { this.pickBackground(); })
        Button('清除背景').enabled(!this.busy).onClick(() => { this.backgroundUri = ''; this.invalidate(); })
      }
      Button('生成预览').enabled(!this.busy).onClick(() => { this.render(); })
      if (this.preview !== null) {
        Image(this.preview).width('100%').objectFit(ImageFit.Contain).constraintSize({ maxHeight: 560 })
        Row({ space: 12 }) {
          Button('保存到图库').enabled(!this.busy).onClick(() => { this.exportImage(true); })
          Button('系统分享').enabled(!this.busy).onClick(() => { this.exportImage(false); })
        }
      }
      if (this.busy) LoadingProgress().width(24).height(24)
    }.width('100%').padding(16).alignItems(HorizontalAlign.Start)
  }
}
