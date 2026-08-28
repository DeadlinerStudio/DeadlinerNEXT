import { AppLog } from '../../common/logging/AppLog';
import { SettingsDivider, SettingsItem, SettingsSection } from '../components/SettingsComponents';
import { WebParams } from '../common/WebBrowserPage'; // 调整引用路径
import { common, Want } from '@kit.AbilityKit';
import { commentManager } from '@kit.AppGalleryKit';
import { promptAction } from '@kit.ArkUI';
import { Toast } from '../../common/ui/Toast';

@Component
export struct SupportPanelView {
  @Consume('appPathStack') appPathStack: NavPathStack;
  // 传入关闭回调，以便点击某个选项后自动收起
  public closeAction?: () => void;

  private context = getContext(this) as common.UIAbilityContext;

  private openWeb(title: string, url: string) {
    let want: Want = {
      action: 'ohos.want.action.viewData', // 意图：查看数据
      entities: ['entity.system.browsable'], // 实体：可浏览的（通常指浏览器）
      uri: url
    };

    this.context.startAbility(want).catch((err: object) => {
      AppLog.error('Native', "Open System Browser failed", JSON.stringify(err));
    });
  }

  private showInAppRating() {
    try {
      // 调用 showCommentDialog 拉起评论弹窗
      commentManager.showCommentDialog(this.context)
        .then(() => {
          AppLog.info('Native', 'Deadliner', "succeeded in showing commentDialog.");
          // this.closeAction?.();
        })
        .catch((error: BusinessError<Object>) => {
          AppLog.error('Native', 'Deadliner', `showCommentDialog failed, Code: ${error.code}, message: ${error.message}`);

          if (error.code == 1021500009) Toast.show({
            message: '您已评分'
          })

          this.openAppStore();
        });
    } catch (error) {
      AppLog.error('Native', 'Deadliner', `showCommentDialog failed, Code: ${error.code}, message: ${error.message}`);
    }
  }

  // 跳转应用市场评分
  private openAppStore() {
    let want: Want = {
      action: 'ohos.want.action.appdetail',
      uri: 'store://appgallery.huawei.com/app/detail?id=com.aritxonly.deadliner'
    };
    this.context.startAbility(want).catch((err: object) => {
      AppLog.error('Native', "Open AppGallery failed", JSON.stringify(err));
    });
    this.closeAction?.();
  }

  build() {
  private async exportDiagnostics(): Promise<void> {
    try {
      AppLog.event('diagnostics.export.started', 'app');
      const paths: Array<string> = AppLog.exportPaths();
      if (paths.length !== 2) {
        throw new Error('Diagnostics are not initialized');
      }
      const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      options.newFileNames = ['deadliner-diagnostics.log', 'deadliner-diagnostics.jsonl'];
      options.fileSuffixChoices = ['Log|.log', 'JSON Lines|.jsonl'];
      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(this.context);
      const destinations: Array<string> = await documentPicker.save(options);
      if (destinations.length !== paths.length) {
        throw new Error('Diagnostic export was cancelled');
      }
      await fileIo.copyFile(paths[0], destinations[0]);
      await fileIo.copyFile(paths[1], destinations[1]);
      AppLog.event('diagnostics.export.finished', 'app');
      Toast.show({ message: '诊断日志已导出' });
    } catch (error) {
      AppLog.error('app', 'Diagnostic export failed', String(error));
      Toast.show({ message: '导出诊断日志失败' });
    }
  }

    Column() {
      Column({ space: 16 }) {
        SettingsSection({ title: '用户反馈' }) {
          SettingsItem({
            title: "QQ 交流群",
            subtitle: "群号 982247910",
            icon: $r('sys.symbol.person_3'),
            onItemClick: () => {
              this.openWeb('QQ 群', 'https://qun.qq.com/universal-share/share?ac=1&authKey=35oQsBRrsd6COfRTm27CapeJl3174VURlC3QLmbs%2B33vQpv/EjOy43hEZoMW%2BBqg&busi_data=eyJncm91cENvZGUiOiI5ODIyNDc5MTAiLCJ0b2tlbiI6IkVBNndKRDd3OU4vcFBIdDZvRTllQVlYRmpwazljQmg3djVwRk12UzkyeW5mU0RIeit5NjBPUWVkQmxLYzRvSFkiLCJ1aW4iOiIxNzI5ODIwNzQ5In0=&data=zUxcoMgCie2fv9XB9NgQgAnYzMz7uRp82lt0uUKhK6oqux0X7Aog--e7DEANDZAIfPfmOiGLD7Oqx7d77ps1xhorG_4KEup7V_rj4BWPKBA&svctype=5&tempid=h5_group_info');
            }
          })
        }

        // --- 核心共建区域 (GitHub) ---
        SettingsSection({ title: '开源共建' }) {
          SettingsItem({
            title: "源代码",
            subtitle: "AritxOnly/DeadlinerNEXT",
            icon: $r('sys.symbol.code'), // 代码图标
            onItemClick: () => {
              this.openWeb('GitHub Repository', 'https://github.com/AritxOnly/DeadlinerNEXT');
            }
          })

          SettingsDivider()

          SettingsItem({
            title: "提交 Issue",
            subtitle: "反馈 Bug 或提出新功能建议",
            icon: $r('sys.symbol.exclamationmark_circle'), // 叹号图标
            onItemClick: () => {
              this.openWeb('Issues', 'https://github.com/AritxOnly/DeadlinerNEXT/issues');
            }
          })

          SettingsDivider()

          SettingsItem({
            title: "Pull Request",
            subtitle: "贡献代码，参与开发",
            icon: $r('sys.symbol.link'), // 分支图标
            onItemClick: () => {
              this.openWeb('Pull Requests', 'https://github.com/AritxOnly/DeadlinerNEXT/pulls');
            }
          })
        }

        // --- 情感与支持区域 ---
        SettingsSection({ title: '支持作者' }) {
          SettingsItem({
            title: "给应用评分",
            subtitle: "无需跳转，快速打分",
            icon: $r('sys.symbol.star'),
            onItemClick: () => {
              this.showInAppRating();
            }
          })

          SettingsDivider()

          SettingsItem({
            title: "前往应用市场",
            subtitle: "查看详情或撰写长评",
            icon: $r('sys.symbol.bag'),
            onItemClick: () => {
              this.openAppStore();
            }
          })

          SettingsDivider()

          SettingsItem({
            title: "请我喝杯咖啡",
            subtitle: "通过捐赠支持后续开发",
            icon: $r('sys.symbol.heart'),
            onItemClick: () => {
              this.openWeb('捐赠支持', 'https://aritxonly.top/donate_deadliner');
            }
          })
        }

        Blank().height(30)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
  }
}