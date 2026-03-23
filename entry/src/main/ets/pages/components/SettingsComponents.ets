import auth, { AuthUser } from "@hw-agconnect/auth";
import { LengthMetrics, promptAction } from "@kit.ArkUI";
import { LoginPanelView } from "../common/LoginPanelView";
import { authentication } from "@kit.AccountKit";
import { HuaweiAccountUtils } from "../../utils/account/HuaweiAccountUtils";
import { ITheme } from "../../common/theme/ThemeModel";
import { BlurBackgroundModifier } from "../../utils/animation/BlurBackgroundModifier";

/**
 * SettingsSection: 类似 Android 的 Surface 容器
 * 绘制一个大圆角的卡片背景
 */
@Component
export struct SettingsSection {

  @StorageProp('customBackgroundImage') customBg: string = '';

  title?: string | Resource;
  @BuilderParam content: () => void;

  @State bgColor: ResourceColor = $r('app.color.background_secondary');
  @Prop mainUserPage: boolean = false;

  build() {
    Column() {
      // Section 标题 (TopLabel)
      if (this.title) {
        Text(this.title)
          .fontSize(13)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .fontWeight(FontWeight.Medium)
          .margin({ left: 24, bottom: 4 }) // 对齐卡片内部文字
          .width('100%')
      }

      // 卡片容器
      Column() {
        this.content()
      }
      .width('100%')
      .attributeModifier(new BlurBackgroundModifier((!!this.customBg && this.mainUserPage), this.bgColor, BlurStyle.Regular))
      .borderRadius(24)
      .padding(4) // 让内部 Item 离边缘有间隙 (对应 Android 的 container padding)
      .margin({ left: 16, right: 16 }) // 卡片离屏幕两边的距离
    }
    .width('100%')
  }
}

/**
 * SettingsItem: 具体的设置项按钮
 * 包含：左侧图标、标题、副标题、右侧箭头容器
 */
@Component
export struct SettingsItem {
  title: string | Resource = '';
  subtitle?: string | Resource;
  icon?: Resource;
  onItemClick?: () => void;

  // 内部状态，用于处理按压效果
  @State isPressed: boolean = false;

  build() {
    Row() {
      if (this.icon) {
        SymbolGlyph(this.icon) // 推荐使用 Symbol，如果用 PNG 改用 Image
          .fontSize(24)
          .fontColor([$r('app.color.font_primary')])
          .margin({ right: 16 })
      }

      // 2. Headline & Supporting Text (中间文字)
      Column() {
        Text(this.title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold) // 对应 TitleMediumEmphasized
          .fontColor($r('app.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.subtitle) {
          Text(this.subtitle)
            .fontSize(12) // 对应 BodySmall
            .fontColor($r('app.color.font_secondary'))
            .margin({ top: 4 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.MARQUEE }) // 跑马灯效果
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(24)
        .fontColor([$r('app.color.font_secondary')])
        .margin({ left: 16 })
        .opacity(0.5)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 12 }) // 内部 Padding
    .borderRadius(20) // 按钮自身的圆角 (比容器略小)
    .margin({ top: 2, bottom: 2, start: LengthMetrics.vp(2), end: LengthMetrics.vp(2) }) // 按钮离容器边缘的间隙
    .backgroundColor(this.isPressed ? $r('sys.color.ohos_id_color_click_effect') : Color.Transparent) // 点击态
    .animation({ duration: 200 }) // 简单的颜色过渡动画
    .onTouch((event) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    })
    .onClick(() => {
      if (this.onItemClick) this.onItemClick();
    })
  }
}

/**
 * SettingsGridItem: 宫格类型的设置项按钮 (用于横向排列)
 * 样式：图标在上，文字在下，居中显示
 */
@Component
export struct SettingsGridItem {
  title: string | Resource = '';
  icon?: Resource;
  iconColor?: ResourceColor = $r('app.color.font_primary');
  onItemClick?: () => void;

  // 内部状态，用于处理按压效果
  @State isPressed: boolean = false;

  build() {
    Column() {
      if (this.icon) {
        SymbolGlyph(this.icon)
          .fontSize(28) // 图标稍微大一点
          .fontColor([this.iconColor]) // 或者用 brand 颜色高亮：this.theme.brand
          .margin({ bottom: 8 }) // 图标和文字的间距
      }

      Text(this.title)
        .fontSize(13) // 字体稍微小一点，适配紧凑布局
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .padding({ top: 16, bottom: 16 })
    .borderRadius(20)
    .backgroundColor(this.isPressed ? $r('sys.color.ohos_id_color_click_effect') : Color.Transparent)
    .animation({ duration: 200 })
    .onTouch((event) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    })
    .onClick(() => {
      if (this.onItemClick) this.onItemClick();
    })
  }
}

/**
 * SettingsSwitch: 带开关的设置项
 * 结构与 SettingsItem 保持一致，右侧为 Toggle 组件
 */
@Component
export struct SettingsSwitch {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  // 基础信息
  title: string | Resource = '';
  subtitle?: string | Resource;
  icon?: Resource;

  // 开关状态 (双向绑定或单向流均可，这里推荐使用 @Link 或 @Prop 配合 onChange)
  // 使用 @Prop 允许父组件单向控制，内部变化通过 onChange 通知
  @Prop isOn: boolean = false;

  // 状态改变回调
  onChange?: (isOn: boolean) => void;

  // 内部按压状态
  @State isPressed: boolean = false;

  build() {
    Row() {
      // 1. 左侧图标 (与 SettingsItem 保持一致)
      if (this.icon) {
        SymbolGlyph(this.icon)
          .fontSize(24)
          .fontColor([$r('app.color.font_primary')])
          .margin({ right: 16 })
      }

      // 2. 中间文字 (与 SettingsItem 保持一致)
      Column() {
        Text(this.title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.subtitle) {
          Text(this.subtitle)
            .fontSize(12)
            .fontColor($r('app.color.font_secondary'))
            .margin({ top: 4 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.MARQUEE })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 3. 右侧开关
      Toggle({ type: ToggleType.Switch, isOn: this.isOn })
        .selectedColor(this.theme.brand) // 选中时的品牌色
        .switchPointColor('#FFFFFF') // 滑块颜色
        .height(24) // 限制高度，使其与图标协调
        .hitTestBehavior(HitTestMode.None) // [关键点]：让 Toggle 不拦截点击，事件交给 Row 统一处理
      // 注意：因为设置了 HitTestMode.None，这里的 onChange 不会被手指触发，
      // 而是依赖 Row 的 onClick 来改变 isOn 的值
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 12 }) // 保持与 SettingsItem 一致的内边距
    .borderRadius(20)
    .margin({ top: 2, bottom: 2, start: LengthMetrics.vp(2), end: LengthMetrics.vp(2) })
    .backgroundColor(this.isPressed ? $r('sys.color.ohos_id_color_click_effect') : Color.Transparent)
    .animation({ duration: 200 })
    // 按压效果
    .onTouch((event) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    })
    // 统一处理点击逻辑
    .onClick(() => {
      // 触发回调，取反当前状态
      if (this.onChange) {
        this.onChange(!this.isOn);
      }
    })
  }
}

/**
 * SettingsDivider: 分割线
 * 根据设计，不应该通栏，而是只在文字部分下方
 */
@Component
export struct SettingsDivider {
  build() {
    Divider()
      .color($r('sys.color.ohos_id_color_list_separator'))
      .strokeWidth(0.5) // 细一点比较精致
      .margin({ left: 56, right: 16, top: 2, bottom: 2 }) // 左侧留出图标位置 (24+16+16)
  }
}

/**
 * SubSettingsDivider: 分割线
 * 根据设计，不应该通栏，而是只在文字部分下方
 */
@Component
export struct SubSettingsDivider {
  build() {
    Divider()
      .color($r('sys.color.ohos_id_color_list_separator'))
      .strokeWidth(0.5) // 细一点比较精致
      .margin({ left: 16, right: 16, top: 2, bottom: 2 })
  }
}

/**
 * SettingsVerticalDivider: 竖向分割线
 * 用于横向排列的 GridItem 之间，高度不占满，居中显示
 */
@Component
export struct SettingsVerticalDivider {
  build() {
    Divider()
      .vertical(true)
      .color($r('sys.color.ohos_id_color_list_separator'))
      .strokeWidth(0.5)
      .height(32)
      .alignSelf(ItemAlign.Center)
      .margin({ left: 4, right: 4 })
  }
}

@Component
export struct SettingsUserProfile {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  @StorageLink('isLoggedIn') @Watch('onLoginStatusChange') isLoggedIn: boolean = false;
  @StorageProp('userProfileRefreshTrigger') @Watch('onTriggerRefresh') refreshTrigger: number = 0;

  @State isLoginSheetShow: boolean = false;

  @State currentUser: AuthUser | null = null;
  @State displayNickname: string = '';
  @State displayAvatar: string = '';

  onTriggerRefresh() {
    if (this.isLoggedIn) {
      this.refreshUser();
    }
  }

  aboutToAppear(): void {
    if (this.isLoggedIn) {
      this.refreshUser();
    }
  }

  onLoginStatusChange() {
    if (this.isLoggedIn) {
      this.refreshUser(true);
      this.isLoginSheetShow = false;
    } else {
      this.currentUser = null;
      this.displayNickname = '';
      this.displayAvatar = '';
    }
  }

  async refreshUser(isInteractive: boolean = false) {
    try {
      const agcUser = await auth.getCurrentUser();
      this.currentUser = agcUser;

      if (agcUser) {
        // 先用 AGC 的数据垫底 (此时可能是乱码)
        this.displayNickname = agcUser.getDisplayName();
        this.displayAvatar = agcUser.getPhotoUrl();

        const ctx = this.getUIContext().getHostContext();

        if (!ctx) return;

        try {
          const sysProfile = await HuaweiAccountUtils.getHuaweiAccountProfile(ctx, isInteractive);
          if (sysProfile.nickname) {
            console.info(`[Fix] Overwriting AGC nickname with System nickname: ${sysProfile.nickname}`);
            this.displayNickname = sysProfile.nickname;
          }
          if (sysProfile.avatar) {
            this.displayAvatar = sysProfile.avatar;
          }
        } catch (sysErr) {
          console.warn('System profile check failed, using AGC cache.');
        }
      }
    } catch (e) {
      console.error(`User profile refresh failed: ${e.message}`);
      this.currentUser = null;
    }
  }

  handleCardClick() {
    if (this.isLoggedIn && this.currentUser) {
      this.showLogoutDialog();
    } else {
      this.isLoginSheetShow = true;
    }
  }

  private showLogoutDialog() {
    AlertDialog.show({
      title: '退出登录',
      message: '确定要退出当前账号吗？',
      primaryButton: {
        value: '取消',
        fontColor: this.theme.brand,
        action: () => {}
      },
      secondaryButton: {
        value: '退出',
        fontColor: $r('app.color.warning'),
        action: async () => {
          try {
            await auth.signOut();
            AppStorage.setOrCreate('isLoggedIn', false);
            promptAction.showToast({ message: '已退出登录' });
          } catch (e) {
            promptAction.showToast({ message: '退出失败' });
          }
        }
      },
      alignment: DialogAlignment.Bottom,
      offset: { dx: 0, dy: -20 },
      backgroundBlurStyle: BlurStyle.Regular,
    })
  }

  @Builder
  loginSheetBuilder() {
    LoginPanelView()
  }

  build() {
    Row() {
      // 1. 头像区域：使用 displayAvatar
      if (this.displayAvatar) {
        Image(this.displayAvatar)
          .width(56)
          .height(56)
          .borderRadius(28)
          .objectFit(ImageFit.Cover)
          .backgroundColor(Color.Transparent)
      } else {
        Image($r('sys.symbol.person_crop_circle_fill_1'))
          .width(56)
          .height(56)
          .borderRadius(28)
          .objectFit(ImageFit.Cover)
          .fillColor($r('sys.color.ohos_id_color_text_secondary'))
          .backgroundColor($r('sys.color.ohos_id_color_foreground_contrary'))
      }

      // 2. 文本信息区域
      Column({ space: 4 }) {
        // 昵称：使用 displayNickname
        Text(this.displayNickname || (this.isLoggedIn ? '华为用户' : '未登录'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.isLoggedIn ? '已登录华为账号' : '点击登录以同步数据与使用 AI')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)
      .margin({ left: 16 })
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 12, bottom: 12, left: 12, right: 12 })
    .backgroundColor(Color.Transparent)
    .onClick(() => {
      this.handleCardClick();
    })
    .bindSheet($$this.isLoginSheetShow, this.loginSheetBuilder(), {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      blurStyle: BlurStyle.Regular,
      backgroundColor: Color.Transparent,
      title: { title: '登录' }
    })
  }
}

@Component
export struct SubSettingsSwitch {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  title: string | Resource = '';
  subtitle?: string | Resource = '';

  @Link isOn: boolean;
  onChange?: (isOn: boolean) => void;

  // 内部状态，用于处理按压效果 (与 SettingsItem 保持一致)
  @State isPressed: boolean = false;

  build() {
    Row() {
      // 1. 左侧：标题和副标题 (Column)
      Column() {
        Text(this.title)
          .fontSize(16)
          // 【统一】字重改为 Bold，与 SettingsItem 一致
          .fontWeight(FontWeight.Bold)
          // 【统一】颜色使用 app.color
          .fontColor($r('app.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.subtitle) {
          Text(this.subtitle)
            .fontSize(12)
            .fontColor($r('app.color.font_secondary'))
            .margin({ top: 4 })
            .lineHeight(16) // 优化多行阅读体验
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .maxLines(2) // 允许副标题最多显示2行，防止过长
        }
      }
      .layoutWeight(1) // 占满左侧剩余空间
      .alignItems(HorizontalAlign.Start)
      .margin({ right: 12 }) // 与右侧开关保持间距

      // 2. 右侧：开关
      Toggle({ type: ToggleType.Switch, isOn: this.isOn })
        .onChange((isOn) => {
          this.isOn = isOn;
          if (this.onChange) {
            this.onChange(isOn);
          }
        })
        .selectedColor(this.theme.brand) // 品牌色
        .hitTestBehavior(HitTestMode.Block) // 确保开关点击优先响应
        .height(21)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .backgroundColor(this.isPressed ? $r('sys.color.ohos_id_color_click_effect') : Color.Transparent)
    .borderRadius(20) // 保持圆角一致
    .animation({ duration: 200 })
    .onTouch((event) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    })
    .onClick(() => {
      this.isOn = !this.isOn;
      if (this.onChange) {
        this.onChange(this.isOn);
      }
    })
  }
}

/**
 * SettingsCheckItem: 带 Checkbox 的设置项
 * 样式：图标 + 标题 + 右侧勾选框
 */
@Component
export struct SettingsCheckItem {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  title: string | Resource = '';
  icon?: Resource;
  @Prop isSelected: boolean = false;
  onItemClick?: () => void;

  @State isPressed: boolean = false;

  build() {
    Row() {
      // 1. 左侧图标
      if (this.icon) {
        SymbolGlyph(this.icon)
          .fontSize(24)
          .fontColor([$r('app.color.font_primary')])
          .margin({ right: 16 })
      }

      // 2. 标题
      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.font_primary'))
        .layoutWeight(1)

      // 3. 右侧 Checkbox
      // hitTestBehavior(HitTestMode.None) 让点击事件穿透给 Row，体验更好
      Checkbox({ name: 'checkbox', group: 'group' })
        .select(this.isSelected)
        .selectedColor(this.theme.brand)
        .hitTestBehavior(HitTestMode.None)
        .width(20)
        .height(20)
    }
    .width('100%')
    .height(56) // 标准列表高度
    .padding({ left: 12, right: 12 })
    .borderRadius(20)
    .backgroundColor(this.isPressed ? $r('sys.color.ohos_id_color_click_effect') : Color.Transparent)
    .animation({ duration: 200 })
    .onTouch((event) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    })
    .onClick(() => {
      if (this.onItemClick) {
        this.onItemClick();
      }
    })
  }
}

/**
 * SettingsSlider: 滑动条设置项
 * 支持连续滑动和分段滑动（通过 step 参数控制）
 * 样式保持与其他 SettingsItem 一致
 */
@Component
export struct SettingsSlider {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  // 基础信息
  title: string | Resource = '';
  icon?: Resource;

  // 数据绑定
  @Link value: number; // 双向绑定，父组件需使用 $value
  min: number = 0;
  max: number = 100;

  /**
   * 步长：
   * - undefined 或 0: 连续滑动
   * - > 0: 分段滑动 (吸附效果)
   */
  step?: number = 0;

  // 样式与交互配置
  showValueText: boolean = true; // 是否显示当前数值
  valueSuffix: string = ''; // 数值后缀，例如 "%", "px"
  showSteps: boolean = false; // 是否在轨道上显示分段圆点 (仅 step > 0 时有效)

  // 回调
  onChange?: (value: number) => void;

  // 内部状态
  @State isPressed: boolean = false;

  build() {
    Column() {
      // 1. 标题行 (图标 + 标题 + 当前数值)
      Row() {
        if (this.icon) {
          SymbolGlyph(this.icon)
            .fontSize(24)
            .fontColor([$r('app.color.font_primary')])
            .margin({ right: 16 })
        }

        Text(this.title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.font_primary'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        // 右侧显示当前值 (可选)
        if (this.showValueText) {
          Text(`${Math.round(this.value)}${this.valueSuffix}`)
            .fontSize(14)
            .fontColor($r('app.color.font_secondary'))
            .fontWeight(FontWeight.Medium)
            .margin({ left: 8 })
            .textAlign(TextAlign.End)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 2. 滑动条区域
      Row() {
        Slider({
          value: this.value,
          min: this.min,
          max: this.max,
          step: this.step, // 关键：step 决定了是否分段
          style: SliderStyle.OutSet // OutSet 风格更适合列表项，InSet 更适合媒体控制器
        })
          .showSteps(this.showSteps && (this.step ?? 0) > 0) // 是否显示刻度点
          .selectedColor(this.theme.brand) // 选中轨道颜色（品牌色）
          .showTips(false) // 拖动时不显示气泡，因为我们已经在右上角显示数值了
          .onChange((value: number, mode: SliderChangeMode) => {
            this.value = value; // 更新 @Link
            // 只有在移动结束或持续移动时触发回调，视需求而定
            if (this.onChange) {
              this.onChange(value);
            }
          })
          .width('100%')
      }
      .width('100%')
      .padding({ top: 8 }) // 稍微给点间距，让Slider不至于太贴文字
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .borderRadius(20)
    .margin({ top: 2, bottom: 2, start: LengthMetrics.vp(2), end: LengthMetrics.vp(2) })
    .backgroundColor(Color.Transparent)
    .animation({ duration: 200 })
    .onTouch((event) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    })
  }
}

@Component
export struct SettingsSelect {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  title: string | Resource = '';
  subtitle?: string | Resource = '';

  // 1. 新增：下拉菜单的数据源
  options: SelectOption[] = [];
  // 2. 修改：布尔值替换为选中项的索引
  @Link selectedIndex: number;
  // 3. 修改：回调函数传出 索引 和 选中的文本
  onChange?: (index: number, value: string) => void;

  // 内部状态，用于处理按压效果 (与 SettingsItem 保持一致)
  @State isPressed: boolean = false;

  build() {
    Row() {
      // 1. 左侧：标题和副标题 (Column) 完全保持不变
      Column() {
        Text(this.title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.subtitle) {
          Text(this.subtitle)
            .fontSize(12)
            .fontColor($r('app.color.font_secondary'))
            .margin({ top: 4 })
            .lineHeight(16)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .maxLines(2)
        }
      }
      .layoutWeight(1) // 占满左侧剩余空间
      .alignItems(HorizontalAlign.Start)
      .margin({ right: 12 })

      // 2. 右侧：下拉选择框 (替换了 Toggle)
      Select(this.options)
        .selected(this.selectedIndex)
        // 安全取值，防止越界
        .value(this.options?.[this.selectedIndex]?.value ?? '')
        .font({ size: 14, weight: 400 })
        .fontColor($r('app.color.font_secondary'))
        .selectedOptionFont({ size: 14, weight: FontWeight.Bold }) // 选中项文字加粗
        .optionFont({ size: 14, weight: 400 })
        .selectedOptionFontColor(this.theme.brand) // 选中项文字使用品牌色
        .backgroundColor(Color.Transparent) // 取消 Select 自带背景色，融入 Row
        .onSelect((index: number, value: string) => {
          this.selectedIndex = index;
          if (this.onChange) {
            this.onChange(index, value);
          }
        })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .backgroundColor(this.isPressed ? $r('sys.color.ohos_id_color_click_effect') : Color.Transparent)
    .borderRadius(20)
    .animation({ duration: 200 })
    .onTouch((event) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    })
    // ⚠️ 注意：这里移除了原始 Switch 组件中 Row 的 .onClick()。
    // 原因：在 ArkUI 中，原生 Select 必须点击它自己的区域才能弹出。
    // 如果想要保留“点击整行都能弹出菜单”的体验，请查看下方的方案二。
  }
}