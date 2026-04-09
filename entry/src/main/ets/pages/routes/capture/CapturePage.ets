import {
  DividerShowType,
  HdsNavigation,
  HdsListItem,
  HdsNavigationTitleMode,
  TextStyleMode
} from '@kit.UIDesignKit';
import { promptAction, SymbolGlyphModifier } from '@kit.ArkUI';
import { TopSafeContainer } from '../../components/TopSafeContainer';
import { getImmersiveTitleBarStyle } from '../../../common/style/NavStyles';
import { InspirationRepository } from '../../../common/repository/InspirationRepository';
import { InspirationItem } from '../../../model/InspirationModels';
import { InspirationEditSheet, InspirationItemCard } from './CaptureComponents';
import { AddTaskSheet } from '../main/modify/task/AddTaskSheet';
import { AddHabitSheet } from '../main/modify/habit/AddHabitSheet';
import { ITheme } from '../../../common/theme/ThemeModel';

@Component
export struct CapturePage {
  @StorageProp('statusBarHeight') statusBarHeight: number = 38;

  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  
  @State inputText: string = '';
  @State items: InspirationItem[] = [];
  @State isLoading: boolean = true;
  @State selectionMode: boolean = false;
  @State selectedIds: number[] = [];

  @State isDetailSheetShow: boolean = false;
  @State editingItem: InspirationItem | null = null;
  @State detailDraftText: string = '';

  @State isAddTaskSheetShow: boolean = false;
  @State isAddHabitSheetShow: boolean = false;
  @State aiTargetText: string = '';
  @State directTaskName: string = '';
  @State directTaskNote: string = '';
  @State directHabitName: string = '';

  private repo: InspirationRepository = InspirationRepository.getInstance();

  @Prop @Watch('onTabSwitch') currentTabIndex: number = 0;
  readonly TARGET_INDEX: number = 2;

  aboutToAppear(): void {
    this.loadItems();
    getContext(this).eventHub.on('sync_done', () => {
      this.loadItems();
    });
  }

  aboutToDisappear(): void {
    getContext(this).eventHub.off('sync_done');
  }

  onTabSwitch() {
    if (this.currentTabIndex === this.TARGET_INDEX) {
      this.loadItems();
    }
  }

  private async loadItems() {
    this.isLoading = true;
    try {
      const data = await this.repo.getAllInspirations();
      this.items = data;
    } catch (error) {
      console.error('[CapturePage] loadItems failed', error);
    }
    this.isLoading = false;
  }

  private isSelected(id: number): boolean {
    return this.selectedIds.indexOf(id) >= 0;
  }

  private toggleSelected(id: number) {
    const next: number[] = [];
    let exists = false;
    for (let i = 0; i < this.selectedIds.length; i++) {
      if (this.selectedIds[i] === id) {
        exists = true;
      } else {
        next.push(this.selectedIds[i]);
      }
    }
    if (!exists) {
      next.push(id);
    }
    this.selectedIds = next;
  }

  private enterSelectionMode(id: number): void {
    this.selectionMode = true;
    if (!this.isSelected(id)) {
      this.selectedIds = [id];
    }
  }

  private exitSelectionMode() {
    this.selectionMode = false;
    this.selectedIds = [];
  }

  private async saveInputAsInspiration() {
    const text = this.inputText.trim();
    if (!text) {
      promptAction.showToast({ message: '先写下一句想法吧' });
      return;
    }

    await this.repo.createInspiration(text);
    this.inputText = '';
    promptAction.showToast({ message: '已保留这条灵感' });
    await this.loadItems();
    getContext(this).eventHub.emit('sync_done');
  }

  private openItem(item: InspirationItem): void {
    this.editingItem = item;
    this.detailDraftText = item.text;
    this.isDetailSheetShow = true;
  }

  private async saveDetail() {
    if (!this.editingItem) {
      return;
    }

    const text = this.detailDraftText.trim();
    if (!text) {
      promptAction.showToast({ message: '留一点内容再保存吧' });
      return;
    }

    await this.repo.updateInspiration({
      id: this.editingItem.id,
      text: text,
      createdAt: this.editingItem.createdAt,
      updatedAt: this.editingItem.updatedAt
    });
    promptAction.showToast({ message: '已更新' });
    this.isDetailSheetShow = false;
    this.editingItem = null;
    await this.loadItems();
    getContext(this).eventHub.emit('sync_done');
  }

  private async deleteEditingItem() {
    if (!this.editingItem) {
      return;
    }
    await this.repo.deleteInspiration(this.editingItem.id);
    promptAction.showToast({ message: '已删除' });
    this.isDetailSheetShow = false;
    this.editingItem = null;
    await this.loadItems();
    getContext(this).eventHub.emit('sync_done');
  }

  private async deleteSingleItem(item: InspirationItem): Promise<void> {
    await this.repo.deleteInspiration(item.id);
    promptAction.showToast({ message: '已删除' });
    await this.loadItems();
    getContext(this).eventHub.emit('sync_done');
  }

  @Builder
  private inspirationRowBuilder(item: InspirationItem) {
    InspirationItemCard({
      item: item,
      selectionMode: this.selectionMode,
      selected: this.isSelected(item.id),
      onCardClick: (): void => {
        if (this.selectionMode) {
          this.toggleSelected(item.id);
        } else {
          this.openItem(item);
        }
      },
      onLongPressSelect: (): void => {
        this.enterSelectionMode(item.id);
      },
      onToggleSelect: (): void => {
        this.toggleSelected(item.id);
      }
    })
  }

  private async deleteSelectedItems() {
    if (this.selectedIds.length === 0) {
      promptAction.showToast({ message: '先选中一些灵感' });
      return;
    }

    for (let i = 0; i < this.selectedIds.length; i++) {
      await this.repo.deleteInspiration(this.selectedIds[i]);
    }
    promptAction.showToast({ message: `已删除 ${this.selectedIds.length} 条灵感` });
    this.exitSelectionMode();
    await this.loadItems();
    getContext(this).eventHub.emit('sync_done');
  }

  private selectedItems(): InspirationItem[] {
    return this.items.filter((item: InspirationItem) => this.isSelected(item.id));
  }

  private async mergeSelectedItems() {
    const selected = this.selectedItems();
    if (selected.length < 2) {
      promptAction.showToast({ message: '至少选择两条灵感再合并' });
      return;
    }

    const mergedText = selected
      .map((item: InspirationItem) => item.text.trim())
      .filter((text: string) => !!text)
      .join('\n\n');

    for (let i = 0; i < selected.length; i++) {
      await this.repo.deleteInspiration(selected[i].id);
    }

    const newId = await this.repo.createInspiration(mergedText);
    const mergedItem = await this.repo.getInspirationById(newId);

    this.exitSelectionMode();
    await this.loadItems();
    getContext(this).eventHub.emit('sync_done');

    if (mergedItem) {
      this.openItem(mergedItem);
    }
    promptAction.showToast({ message: '已合并，接下来可以让 AI 帮你整理' });
  }

  private guessTitleFromText(text: string): string {
    const normalized = text.replace(/\n+/g, ' ').trim();
    if (normalized.length === 0) {
      return '未命名灵感';
    }
    return normalized.length > 24 ? normalized.slice(0, 24) : normalized;
  }

  private openAiTaskFromText(text: string): void {
    this.aiTargetText = text;
    this.isDetailSheetShow = false;
    this.isAddTaskSheetShow = true;
  }

  private openAiHabitFromText(text: string): void {
    this.aiTargetText = text;
    this.isDetailSheetShow = false;
    this.isAddHabitSheetShow = true;
  }

  private openDirectTaskFromText(text: string): void {
    this.aiTargetText = '';
    this.directTaskName = this.guessTitleFromText(text);
    this.directTaskNote = text;
    this.isDetailSheetShow = false;
    this.isAddTaskSheetShow = true;
  }

  private openDirectHabitFromText(text: string): void {
    this.aiTargetText = '';
    this.directHabitName = this.guessTitleFromText(text);
    this.isDetailSheetShow = false;
    this.isAddHabitSheetShow = true;
  }

  @Builder
  private inputCardBuilder() {
    Column({ space: 14 }) {
      Column({ space: 6 }) {
        Text('先记下一句想法')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.font_primary'))
          .width('100%')

        Text('稍后再整理')
          .fontSize(14)
          .fontColor(this.selectionMode ? $r('app.color.font_secondary') : this.theme.brand)
          .width('100%')

        Text('这里适合放灵感、计划草稿、稍后可能要做的事。先别急着把它变得太正式，先让它被保留下来。')
          .fontSize(14)
          .lineHeight(22)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)

      TextArea({ text: this.inputText, placeholder: '一句念头、一段草稿，或者一件还没想清楚的事。' })
        .width('100%')
        .height(150)
        .fontSize(16)
        .lineHeight(24)
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .borderRadius(22)
        .padding(16)
        .onChange((value: string) => {
          this.inputText = value;
        })

      Row() {
        Button('保存灵感')
          .type(ButtonType.Capsule)
          .width('100%')
          .height(42)
          .backgroundColor(this.theme.brand)
          .fontColor(Color.White)
          .onClick(() => this.saveInputAsInspiration())
      }
      .width('100%')

      // HarmonyOS v1 先不放语音转文字入口，后续如果改为录音文件承接再接回来。
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.background_secondary'))
    .borderRadius(24)
  }

  @Builder
  private selectionBannerBuilder() {
    Row({ space: 10 }) {
      Text('多选中')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme.brand)

      Text('先把几条碎片放在一起，等它们更清楚一点，再决定要不要整理。')
        .layoutWeight(1)
        .fontSize(12)
        .lineHeight(18)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(this.theme.brand50)
    .borderRadius(20)
  }

  @Builder
  private emptyBuilder() {
    Column({ space: 12 }) {
      Text('这里会暂时停泊那些还没定型的内容')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))

      Text('先记下来。等它成熟一点，再决定要不要整理成任务或习惯。')
        .fontSize(13)
        .lineHeight(20)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
    }
    .width('100%')
    .padding({ top: 56, bottom: 56, left: 20, right: 20 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private detailSheetBuilder() {
    InspirationEditSheet({
      isShow: $isDetailSheetShow,
      draftText: $detailDraftText,
      item: this.editingItem,
      onSave: async (): Promise<void> => {
        await this.saveDetail();
      },
      onDelete: async (): Promise<void> => {
        await this.deleteEditingItem();
      },
      onAiTask: (): void => this.openAiTaskFromText(this.detailDraftText),
      onAiHabit: (): void => this.openAiHabitFromText(this.detailDraftText),
      onDirectTask: (): void => this.openDirectTaskFromText(this.detailDraftText),
      onDirectHabit: (): void => this.openDirectHabitFromText(this.detailDraftText)
    })
  }

  @Builder
  private addTaskSheetBuilder() {
    AddTaskSheet({
      onDone: () => {
        this.isAddTaskSheetShow = false;
        this.aiTargetText = '';
        this.directTaskName = '';
        this.directTaskNote = '';
      },
      initialAiInputText: this.aiTargetText,
      autoTriggerAI: this.aiTargetText.length > 0,
      initialName: this.directTaskName,
      initialNote: this.directTaskNote
    })
  }

  @Builder
  private addHabitSheetBuilder() {
    AddHabitSheet({
      onDone: () => {
        this.isAddHabitSheetShow = false;
        this.aiTargetText = '';
        this.directHabitName = '';
      },
      initialAiInputText: this.aiTargetText,
      autoTriggerAI: this.aiTargetText.length > 0,
      initialName: this.directHabitName
    })
  }

  build() {
    HdsNavigation() {
      TopSafeContainer({
        topAvoidHeight: this.statusBarHeight + 18,
        needBgTransparent: true
      }) {
        Column({ space: 16 }) {
          if (!this.selectionMode) {
            Column() {
              this.inputCardBuilder()
            }
            .transition(
              TransitionEffect.OPACITY
                .combine(TransitionEffect.translate({ y: -24 }))
                .animation({
                  duration: 280,
                  curve: Curve.FastOutSlowIn
                })
            )
          }

          if (!this.isLoading && this.items.length === 0) {
            this.emptyBuilder()
          } else {
            List({ space: 12 }) {
              ForEach(this.items, (item: InspirationItem) => {
                if (this.selectionMode) {
                  ListItem() {
                    this.inspirationRowBuilder(item)
                  }
                } else {
                  HdsListItem({
                    customItemBuilder: this.inspirationRowBuilder.bind(this, item),
                    swipeActionOptions: {
                      icons: [
                        {
                          icon: new SymbolGlyphModifier($r('sys.symbol.list_checkmark'))
                            .fontColor([Color.White]),
                          backgroundColor: this.theme.chartInfo,
                          onAction: (): void => {
                            this.openAiTaskFromText(item.text);
                          },
                        },
                        {
                          icon: new SymbolGlyphModifier($r('sys.symbol.leaf'))
                            .fontColor([Color.White]),
                          backgroundColor: this.theme.chartCompleted,
                          onAction: (): void => {
                            this.openAiHabitFromText(item.text);
                          },
                        },
                      ],
                      deleteIconOptions: {
                        backgroundColor: $r('app.color.chart_red'),
                        iconColor: Color.White,
                        onAction: (): void => {
                          void this.deleteSingleItem(item);
                        },
                      },
                      fullDeleteOptions: {
                        isFullDelete: true,
                        onFullDeleteAction: (): void => {
                          void this.deleteSingleItem(item);
                        },
                      },
                    }
                  })
                }
              }, (item: InspirationItem) => `${item.id}_${item.updatedAt}`)
            }
            .width('100%')
            .height('100%')
            .scrollBar(BarState.Off)
          }

          Blank().height(96)

          Blank()
            .width(0)
            .height(0)
            .bindSheet($$this.isDetailSheetShow, this.detailSheetBuilder(), {
              height: SheetSize.LARGE,
              dragBar: true,
              blurStyle: BlurStyle.Regular,
              backgroundColor: Color.Transparent,
              showClose: false,
              onDisappear: () => {
                this.isDetailSheetShow = false;
                this.editingItem = null;
              },
            })

          Blank()
            .width(0)
            .height(0)
            .bindSheet($$this.isAddTaskSheetShow, this.addTaskSheetBuilder(), {
              height: SheetSize.LARGE,
              blurStyle: BlurStyle.Regular,
              backgroundColor: Color.Transparent,
              showClose: false,
              onDisappear: () => {
                this.isAddTaskSheetShow = false;
              }
            })

          Blank()
            .width(0)
            .height(0)
            .bindSheet($$this.isAddHabitSheetShow, this.addHabitSheetBuilder(), {
              height: SheetSize.LARGE,
              blurStyle: BlurStyle.Regular,
              backgroundColor: Color.Transparent,
              showClose: false,
              onDisappear: () => {
                this.isAddHabitSheetShow = false;
              }
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .padding({ left: 16, right: 16 })
      }
    }
    .titleBar({
      style: getImmersiveTitleBarStyle(false, true),
      content: {
        title: {
          mainTitle: this.selectionMode ? `已选 ${this.selectedIds.length} 项` : '灵感'
        },
        subIcon: this.selectionMode ? {
          content: {
            icon: $r('sys.symbol.xmark'),
            action: (): void => {
              this.exitSelectionMode();
            }
          }
        } : undefined,
        menu: {
          value: this.selectionMode ? [
            {
              content: {
                icon: $r('sys.symbol.trash'),
                action: (): void => {
                  void this.deleteSelectedItems();
                }
              }
            },
            {
              content: {
                label: `合并`,
                type: TextStyleMode.NORMAL,
                action: (): void => {
                  if (this.selectedIds.length >= 2) {
                    void this.mergeSelectedItems();
                  } else {
                    promptAction.showToast({ message: '至少选择两条灵感再合并' });
                  }
                }
              }
            }
          ] : [
            {
              content: {
                icon: $r('sys.symbol.checkmark_circle'),
                action: (): void => {
                  this.selectionMode = true
                }
              }
            }
          ]
        },
        divider: { showType: DividerShowType.OFF }
      }
    })
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
  }
}
