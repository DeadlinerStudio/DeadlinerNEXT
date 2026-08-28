import { AppLog } from '../../common/logging/AppLog';
import { AccountController, AccountUtils } from "./AccountUtils";
import auth, { AuthUser, SignInResult } from '@hw-agconnect/auth'
import { hilog } from "@kit.PerformanceAnalysisKit";
import { AuthDefaultUser } from "@hw-agconnect/auth/src/main/ets/k/x4";
import { util } from "@kit.ArkTS";
import { authentication } from "@kit.AccountKit";
import { Context } from "@kit.AbilityKit";

export class HuaweiAccountController implements AccountController {
  onSignInSucc: (s: SignInResult) => void = () => {};
  onSignInFail: (e: BusinessError) => void = (e) => {};
  onSignOutSucc: () => void = () => {};
  onSignOutFail: (e: BusinessError) => void = (e) => {};
}

interface HuaweiAccountProfile {
  avatar?: string,
  nickname?: string,
  authorization?: string
}

export class HuaweiAccountUtils implements AccountUtils {
  controller: AccountController = new HuaweiAccountController();

  init: (controller: AccountController) => void = (c) => {
    this.controller = c;
  }

  signIn: () => boolean = this._signIn;

  signOut: () => boolean = this._signOut;

  private _signIn(): boolean {
    auth.signIn({
      autoCreateUser: true,
      "credentialInfo": {
        "kind": 'hwid'
      }
    }).then(signInResult => {
      AppLog.info('HiLog', 0x0000, 'testTag', '%{public}s',  `signInHwid success. result: ${signInResult.getUser().getUid()}`);

      this.controller.onSignInSucc(signInResult);
    })
      .catch((error: BusinessError) => {
        AppLog.error('HiLog', 0x0000, 'testTag', '%{public}s', `signInHwid error, Code: ${error.code}, message: ${error.message}`);
        this.controller.onSignInFail(error);
        return false;
      })
    return true;
  }

  private _signOut(): boolean {
    auth.signOut().then(() => {
      this.controller.onSignOutSucc();
    }).catch((error: BusinessError) => {
      this.controller.onSignOutFail(error);
      return false;
    });
    return true;
  }

  static async signOutAsync(): Promise<void> {
    await auth.signOut();
  }

   static async getHuaweiAccountProfile(context: Context, forcePrompt: boolean = false): Promise<HuaweiAccountProfile> {
    let avatarUri: string | undefined = undefined;
    let nickName: string | undefined = undefined;
    let authorizationCode: string | undefined = undefined;

    const authRequest = new authentication.HuaweiIDProvider().createAuthorizationWithHuaweiIDRequest();
    authRequest.scopes = ['profile', 'openid'];
    authRequest.forceAuthorization = forcePrompt;
    authRequest.state = util.generateRandomUUID();

    try {
      const controller = new authentication.AuthenticationController(context);

      // 2. 使用 await 等待 executeRequest 的结果
      const data = await controller.executeRequest(authRequest);

      const authorizationWithHuaweiIDResponse = data as authentication.AuthorizationWithHuaweiIDResponse;
      const state = authorizationWithHuaweiIDResponse.state;

      if (state && authRequest.state !== state) {
        AppLog.error('Native', 'State check failed');
        return { avatar: undefined, nickname: undefined, authorization: undefined };
      }

      const authorizationWithHuaweiIDCredential = authorizationWithHuaweiIDResponse?.data;
      avatarUri = authorizationWithHuaweiIDCredential?.avatarUri;
      nickName = authorizationWithHuaweiIDCredential?.nickName;
      authorizationCode = authorizationWithHuaweiIDCredential?.authorizationCode;

      AppLog.debug('Native', `[User] Profile nickName: ${nickName} | avatarUri: ${avatarUri}`);

    } catch (error) {
      const err = error as BusinessError;
      AppLog.error('Native', `Get profile failed: ${err.code}, ${err.message}`);
    }

    // 3. 此时 await 已经结束，变量已被赋值，可以正确返回
    return {
      avatar: avatarUri,
      nickname: nickName,
      authorization: authorizationCode
    };
  }
}
