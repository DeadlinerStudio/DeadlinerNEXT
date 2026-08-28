import { AppLog } from '../../common/logging/AppLog';
import { LoginWithHuaweiIDButton, loginComponentManager } from '@kit.AccountKit';
import { promptAction } from '@kit.ArkUI';
import { HuaweiAccountController, HuaweiAccountUtils } from '../../utils/account/HuaweiAccountUtils';
import { BusinessError } from '@kit.BasicServicesKit';
import auth from '@hw-agconnect/auth';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ITheme } from '../../common/theme/ThemeModel';
import { Toast } from '../../common/ui/Toast';

@Component
export struct LoginPanelView {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @State isPrivacyChecked: boolean = false;

  private accountUtils: HuaweiAccountUtils = new HuaweiAccountUtils();

  // 2. 创建官方组件的 Controller
  private loginButtonController: loginComponentManager.LoginWithHuaweiIDButtonController =
    new loginComponentManager.LoginWithHuaweiIDButtonController()
      .onClickLoginWithHuaweiIDButton((error: BusinessError, response: loginComponentManager.HuaweiIDCredential) => {
        // --- 核心逻辑衔接点 ---
        // 当用户点击按钮，并通过了系统级的华为账号授权后，会回调这里

        if (error) {
          // 系统级登录失败（用户取消、网络错误等），这里通常不需要我们额外弹窗，
          // 因为系统控件往往会有自带的提示，或者我们可以简单 Log
          AppLog.error('Native', `System Login Failed: ${error.code}, ${error.message}`);
          return;
        }

        if (response) {
          // 系统授权成功！
          // 现在调用我们封装的 AGC Utils 进行“业务登录” (同步 AGC 会话)
          // 此时因为系统层已登录，AGC 的 signIn 通常会非常快或静默完成
          this.accountUtils.signIn();
        }
      });

  aboutToAppear(): void {
    const ctx = this.getUIContext().getHostContext();

    // 3. 初始化 Utils 的回调监听 (处理 AGC 登录的结果)
    this.accountUtils.init({
      onSignInSucc: async (s) => {
        if (ctx) {
          let userResult = s.getUser();
          let profile = await HuaweiAccountUtils.getHuaweiAccountProfile(ctx);
          AppLog.debug('Native', `[User] Profile photoUrl: ${profile.avatar} | displayName: ${profile.nickname}`)
          userResult.updateProfile({
            displayName: profile.nickname ?? "华为用户",
            photoUrl: profile.avatar ?? "empty",
          }).then(() => {
            auth.getCurrentUser().then(user => {
              if (user) {
                let photo = user.getPhotoUrl();
                let name = user.getDisplayName();
                AppLog.debug('Native', `[User] photoUrl: ${photo} | displayName: ${name}`)
              }
            })

            AppStorage.setOrCreate('userProfileRefreshTrigger', Date.now());
          })
        }

        AppLog.info('Native', 'AGC Login Success');
        Toast.show({ message: '登录成功' });

        // 更新全局状态，通知外部关闭弹窗或刷新 UI
        AppStorage.setOrCreate('isLoggedIn', true);
      },
      onSignInFail: (e: BusinessError) => {
        AppLog.error('Native', `AGC Login Failed: ${e.code}, ${e.message}`);
        // 只有非取消类的错误才弹窗，避免打扰用户
        if (e.code !== 1001502012) {
          Toast.show({ message: `登录验证失败: ${e.message}` });
        }
      },
      onSignOutSucc: () => {},
      onSignOutFail: () => {}
    });

    // 初始化协议状态
    this.updateAgreementStatus(this.isPrivacyChecked);
  }

  // 4. 同步协议勾选状态给官方按钮
  updateAgreementStatus(isChecked: boolean) {
    this.isPrivacyChecked = isChecked;
    // 关键：告诉官方按钮协议是否已同意
    // 如果设置为 NOT_ACCEPTED，用户点击按钮时系统会自动弹出“请先同意协议”的提示气泡，无需我们手动写 Toast
    this.loginButtonController.setAgreementStatus(
      isChecked ? loginComponentManager.AgreementStatus.ACCEPTED : loginComponentManager.AgreementStatus.NOT_ACCEPTED
    );
  }

  build() {
    Column({ space: 24 }) { // 稍微加大一点间距更美观

      // 头部引导文案 (可选，建议加上让界面不空旷)
      Column({ space: 8 }) {
        Text('登录体验完整功能')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Text('登录后可同步数据并使用 AI 助手')
          .fontSize(14)
          .fontColor($r('sys.color.font_secondary'))
      }
      .margin({ top: 20, bottom: 10 })

      // 1. 华为账号登录按钮区域
      Column() {
        LoginWithHuaweiIDButton({
          params: {
            // 样式配置
            style: loginComponentManager.Style.BUTTON_RED, // 红色品牌色
            borderRadius: 24, // 圆角
            loginType: loginComponentManager.LoginType.ID, // 请求 ID 模式
            supportDarkMode: true, // 适配深色模式
            // 加载状态：点击后按钮会转圈，直到我们的逻辑结束
            extraStyle: {
              buttonStyle: new loginComponentManager.ButtonStyle().loadingStyle({
                show: true
              })
            }
          },
          controller: this.loginButtonController
        })
      }
      .width('80%') // 按钮宽度通常不要满屏
      .height(40)

      // 2. 协议勾选区域
      Row() {
        Checkbox({ name: 'privacy', group: 'login' })
          .select(this.isPrivacyChecked)
          .selectedColor(this.theme.brand) // 匹配华为红
          .onChange((value: boolean) => {
            this.updateAgreementStatus(value);
          })
        Text() {
          Span('应 ')
          Span('国家法律法规').fontColor($r('app.color.warning'))
          Span(' 要求，使用人工智能功能需要核验用户身份，勾选此项代表您同意使用。')
          Span('我们仅通过您的华为账号核验身份，不会在云端存储任何您的用户信息。').fontColor($r('app.color.font_secondary'))
        }
        .fontSize(12)
        .fontColor($r('sys.color.font_secondary'))
        .onClick(() => {
          // 优化体验：点击文字也能切换勾选
          this.updateAgreementStatus(!this.isPrivacyChecked);
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ bottom: 20 })
    }
    .width('100%')
    .padding(20)
    // 这一层背景色看情况，如果是半模态通常不需要设置，或者是透明
    .justifyContent(FlexAlign.Center)
  }
}