import { MemoryBank, MemoryFragment } from '../../ai/model/MemoryModels';
import { ITheme } from '../../common/theme/ThemeModel';
import {
  HdsNavigation,
  HdsNavigationTitleMode
} from '@kit.UIDesignKit';
import { SettingsSection } from '../components/SettingsComponents';
import { TopSafeContainer } from '../components/TopSafeContainer';
import { DialogCompat } from '../../common/ui/DialogCompat';
import { ImmersivePopupSurface } from '../../common/ui/ImmersivePopupSurface';
import { getImmersiveTitleBarStyle } from '../../common/style/NavStyles';

// ==========================================
// MARK: - 自定义画像编辑弹窗
// ==========================================
@CustomDialog
export struct ProfileEditDialog {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  controller?: CustomDialogController;

  @Link draftContent: string;
  onConfirm: () => void = () => {};

  build() {
    Column() {
      ImmersivePopupSurface({ paddingValue: 16, radius: 36, fallbackBlurStyle: BlurStyle.Thick }) {
        Column() {
          Text("编辑用户画像")
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 8, bottom: 24 })

          TextArea({ text: $$this.draftContent, placeholder: "输入画像..." })
            .height(140)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .borderRadius(24)
            .padding(12)

          Row() {
            Button("取消")
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .backgroundColor(Color.Transparent)
              .layoutWeight(1)
              .onClick(() => {
                this.controller?.close();
              })

            Divider().vertical(true).height(24).color($r('sys.color.ohos_id_color_list_separator'))

            Button("保存")
              .fontColor(this.theme.brand)
              .backgroundColor(Color.Transparent)
              .layoutWeight(1)
              .onClick(() => {
                this.onConfirm();
                this.controller?.close();
              })
          }
          .margin({ top: 24 })
          .width('100%')
        }
        .width('100%')
      }
    }
    .margin(16)
  }
}

// ==========================================
// MARK: - 自定义碎片编辑弹窗 (精简版)
// ==========================================
@CustomDialog
export struct FragmentEditDialog {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  controller?: CustomDialogController;

  @Link draftContent: string;
  onConfirm: () => void = () => {};

  build() {
    Column() {
      ImmersivePopupSurface({ paddingValue: 16, radius: 36, fallbackBlurStyle: BlurStyle.Thick }) {
        Column() {
          Text("编辑碎片记忆")
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 8, bottom: 24 })

          TextArea({ text: $$this.draftContent })
            .height(140)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .borderRadius(24)
            .padding(12)

          Row() {
            Button("取消")
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .backgroundColor(Color.Transparent)
              .layoutWeight(1)
              .onClick(() => {
                this.controller?.close();
              })

            Divider().vertical(true).height(24).color($r('sys.color.ohos_id_color_list_separator'))

            Button("保存")
              .fontColor(this.theme.brand)
              .backgroundColor(Color.Transparent)
              .layoutWeight(1)
              .onClick(() => {
                this.onConfirm();
                this.controller?.close();
              })
          }
          .margin({ top: 24 })
          .width('100%')
        }
        .width('100%')
      }
    }
    .margin(16)
  }
}

// ==========================================
// MARK: - 记忆管理主页面
// ==========================================
@Component
export struct MemoryManageSheet {
  @Provide('navPathStack') navStack: NavPathStack = new NavPathStack();
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  @Require onDismiss: () => void;

  // --- 核心数据状态 (同步自 MemoryBank) ---
  @State userProfile: string = "";
  @State fragments: MemoryFragment[] = [];

  // --- 编辑态绑定数据 ---
  @State editingProfileDraft: string = "";
  @State editingFragmentId: string = "";
  @State editingFragmentContent: string = "";

  // --- 弹窗控制器 ---
  private profileDialogController: CustomDialogController = new CustomDialogController({
    builder: ProfileEditDialog({
      draftContent: $editingProfileDraft,
      onConfirm: () => { this.saveProfile(); }
    }),
    customStyle: true,
    alignment: DialogAlignment.Center
  });

  private fragDialogController: CustomDialogController = new CustomDialogController({
    builder: FragmentEditDialog({
      draftContent: $editingFragmentContent,
      onConfirm: () => { this.saveFragmentEdit(); }
    }),
    customStyle: true,
    alignment: DialogAlignment.Center
  });

  aboutToAppear() {
    this.refreshData();
  }

  onDataChanged?: () => void;

  private refreshData() {
    const mb = MemoryBank.getInstance();
    this.userProfile = mb.userProfile;
    this.fragments = [...mb.fragments];

    if (this.onDataChanged) {
      this.onDataChanged();
    }
  }

  private formatDate(timestamp: number): string {
    const d = new Date(timestamp);
    const yyyy = d.getFullYear();
    const MM = String(d.getMonth() + 1).padStart(2, '0');
    const dd = String(d.getDate()).padStart(2, '0');
    const HH = String(d.getHours()).padStart(2, '0');
    const mm = String(d.getMinutes()).padStart(2, '0');
    return `${yyyy}-${MM}-${dd} ${HH}:${mm}`;
  }

  // ==========================================
  // MARK: - 业务操作逻辑
  // ==========================================

  private async saveProfile() {
    await MemoryBank.getInstance().setUserProfileAllowEmpty(this.editingProfileDraft);
    this.refreshData();
  }

  private startEditFragment(frag: MemoryFragment) {
    this.editingFragmentId = frag.id;
    this.editingFragmentContent = frag.content;
    this.fragDialogController.open();
  }

  private async saveFragmentEdit() {
    if (!this.editingFragmentId) return;

    const content = this.editingFragmentContent.trim();
    if (content.length === 0) {
      await MemoryBank.getInstance().deleteFragment(this.editingFragmentId);
    } else {
      // 保持原有分类和重要性不变，仅更新内容
      const frag = this.fragments.find(f => f.id === this.editingFragmentId);
      await MemoryBank.getInstance().updateFragment(
        this.editingFragmentId,
        content,
        frag?.category || "Auto",
        frag?.importance || 3
      );
    }
    this.refreshData();
  }

  private async deleteFragment(id: string) {
    await MemoryBank.getInstance().deleteFragment(id);
    this.refreshData();
  }

  private showClearAllConfirm() {
    AlertDialog.show(DialogCompat.withAlertBlurStyle({
      title: '确认清空所有记忆？',
      message: '这会清空用户画像和所有碎片记忆，且不可恢复。',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '清空全部',
        fontColor: $r('app.color.warning'),
        action: async () => {
          await MemoryBank.getInstance().clearAllMemories();
          this.refreshData();
        }
      }
    }, BlurStyle.Regular));
  }

  // ==========================================
  // MARK: - UI 构建
  // ==========================================

  @Builder
  SectionHeader(title: string) {
    Text(title)
      .fontSize(14)
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
      .padding({ left: 16, bottom: 8, top: 24 })
  }

  @Builder
  SectionFooter(text: string) {
    Text(text)
      .fontSize(12)
      .fontColor($r('sys.color.font_tertiary'))
      .width('100%')
      .padding({ left: 16, right: 16, top: 8 })
  }

  @Builder
  ProfileSection() {
    Column() {
      this.SectionHeader("用户画像")

      SettingsSection({ bgColor: $r('sys.color.search_container_focus_color') }) {
        Column() {
          Text(this.userProfile.trim() ? this.userProfile : "未建立")
            .fontSize(16)
            .fontColor(this.userProfile.trim() ? $r('sys.color.font_primary') : $r('sys.color.font_secondary'))
            .width('100%')
            .copyOption(CopyOptions.LocalDevice)
            .margin({ bottom: 12 })

          Row() {
            Blank().layoutWeight(1)
            Button("编辑画像")
              .type(ButtonType.Normal)
              .backgroundColor(Color.Transparent)
              .fontColor(this.theme.brand)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .padding(0)
              .height(24)
              .onClick(() => {
                this.editingProfileDraft = this.userProfile;
                this.profileDialogController.open();
              })
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
      }

      this.SectionFooter("画像用于给 Agent 提供稳定偏好与背景。建议控制在几百字以内。")
    }
  }

  @Builder
  FragmentsSection() {
    Column() {
      this.SectionHeader(`碎片记忆（${this.fragments.length}）`)

      if (this.fragments.length === 0) {
        SettingsSection({ bgColor: $r('sys.color.search_container_focus_color') }) {
          Text("暂无碎片记忆")
            .fontColor($r('sys.color.font_secondary'))
            .fontSize(14)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding(24)
        }
      } else {
        SettingsSection({ bgColor: $r('sys.color.search_container_focus_color') }) {
          Column() {
            ForEach(this.fragments, (frag: MemoryFragment, index: number) => {
              Column({ space: 8 }) {
                Text(frag.content)
                  .fontSize(16)
                  .maxLines(3)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .copyOption(CopyOptions.LocalDevice)
                  .width('100%')

                Row({ space: 12 }) {
                  Text(frag.category).fontSize(12).fontColor($r('sys.color.font_secondary'))
                  Text(this.formatDate(frag.timestamp)).fontSize(12).fontColor($r('sys.color.font_secondary'))
                  Blank()
                  Text(`★${frag.importance}`).fontSize(12).fontColor($r('sys.color.font_secondary'))
                }
                .width('100%')

                Row({ space: 16 }) {
                  Button("编辑")
                    .type(ButtonType.Normal).backgroundColor(Color.Transparent)
                    .fontColor(this.theme.brand).fontSize(14).padding(0).height(24)
                    .onClick(() => this.startEditFragment(frag))

                  Button("删除")
                    .type(ButtonType.Normal).backgroundColor(Color.Transparent)
                    .fontColor($r('app.color.warning')).fontSize(14).padding(0).height(24)
                    .onClick(() => this.deleteFragment(frag.id))

                  Blank()
                }
                .width('100%')
                .margin({ top: 4 })
              }
              .width('100%')
              .padding(16)

              if (index < this.fragments.length - 1) {
                Divider().color($r('sys.color.comp_divider')).margin({ left: 16, right: 16 })
              }
            }, (frag: MemoryFragment) => frag.id)
          }
        }
      }

      this.SectionFooter("建议把碎片记忆写成可复用的事实/偏好/约束，避免情绪化长文本。")
    }
  }

  @Builder
  ActionsSection() {
    Column() {
      this.SectionHeader("危险操作")
      SettingsSection({ bgColor: $r('sys.color.search_container_focus_color') }) {
        Button("清空所有记忆")
          .type(ButtonType.Normal)
          .width('100%')
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.warning'))
          .fontSize(16)
          .padding(16)
          .borderRadius(24)
          .clip(true)
          .onClick(() => this.showClearAllConfirm())
      }
    }
  }

  build() {
    HdsNavigation(this.navStack) {
      Column() {
        TopSafeContainer({ topAvoidHeight: 72, bgColor: Color.Transparent }) {
          Scroll() {
            Column() {
              this.ProfileSection()
              this.FragmentsSection()
              this.ActionsSection()

              Column().height(40)
            }
          }
          .scrollBar(BarState.Off)
          .width('100%')
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
    }
    .titleBar({
      style: getImmersiveTitleBarStyle(false),
      content: {
        title: { mainTitle: "记忆管理" },
        menu: {
          value: [
            {
              content: {
                icon: $r('sys.symbol.xmark'),
                action: () => { this.onDismiss(); }
              }
            }
          ]
        }
      },
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .titleMode(HdsNavigationTitleMode.MODAL)
    .hideBackButton(true)
    .backgroundColor(Color.Transparent)
    .mode(NavigationMode.Stack)
    .backgroundBlurStyle(BlurStyle.Regular)
  }
}
