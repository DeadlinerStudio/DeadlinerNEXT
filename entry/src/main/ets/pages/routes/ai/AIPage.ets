import {
  DividerShowType,
  HdsListItem,
  HdsNavigation,
  HdsNavigationTitleMode
} from '@kit.UIDesignKit';
import { getImmersiveTitleBarStyle } from '../../../common/style/NavStyles';
import { AIWorkspaceView } from '../../common/AIPanelView';
import { ITheme } from '../../../common/theme/ThemeModel';
import {
  AppBreakpoint,
  APP_BREAKPOINT_DEFAULT,
  APP_BREAKPOINT_STORAGE_KEY,
  AppBreakpointUtils
} from '../../../common/layout/AppBreakpoints';
import {
  AIConversationHistoryRecord,
  AIWorkspaceSessionSnapshot
} from '../../common/ai/AIPanelModels';
import { AIConversationHistoryStore } from '../../common/ai/AIConversationHistoryStore';
import { DateTimeUtils } from '../../../utils/DateTimeUtils';

@Component
export struct AIPage {
  @Consume('isAiFlowShown') isAiFlowShown: boolean;
  @StorageLink('statusBarHeight') statusBarHeight: number = 38;
  @StorageLink('topAvoidExtraHeight') topAvoidExtraHeight: number = 0;
  @StorageLink(APP_BREAKPOINT_STORAGE_KEY) currentBreakpoint: string = APP_BREAKPOINT_DEFAULT;
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @Prop @Watch('onTabSwitch') currentTabIndex: number = 0;
  @State newChatSignal: number = 0;
  @State currentSessionSnapshot: AIWorkspaceSessionSnapshot | null = null;
  @State archivedHistory: AIConversationHistoryRecord[] = [];
  @State selectedHistoryId: string = '';
  @State workspaceSessionVersion: number = 0;
  @State historyPreviewVersion: number = 0;
  @State deletingHistoryId: string = '';
  readonly TARGET_INDEX: number = 3;

  private flowTimerId: number = -1;

  aboutToAppear(): void {
    if (this.currentTabIndex === this.TARGET_INDEX) {
      this.playAiFlow();
    }
    this.loadConversationState();
  }

  aboutToDisappear(): void {
    this.stopAiFlow();
  }

  onTabSwitch(): void {
    if (this.currentTabIndex === this.TARGET_INDEX) {
      this.playAiFlow();
    }
  }

  private async loadConversationState(): Promise<void> {
    const store = AIConversationHistoryStore.getInstance();
    await store.init(getContext(this));
    this.archivedHistory = store.getArchivedHistory();
    this.currentSessionSnapshot = store.getCurrentDraft();
    this.workspaceSessionVersion += 1;
  }

  private playAiFlow(): void {
    clearTimeout(this.flowTimerId);

    this.isAiFlowShown = true;

    console.log('[DEBUG] play AI flow')

    this.flowTimerId = setTimeout(() => {
      animateTo({ duration: 500, curve: Curve.EaseOut }, () => {
        this.isAiFlowShown = false;
      });
    }, 400);
  }

  private stopAiFlow(): void {
    clearTimeout(this.flowTimerId);
    this.isAiFlowShown = false;
  }

  private startNewConversation(): void {
    this.startNewConversationInternal();
  }

  private async startNewConversationInternal(): Promise<void> {
    const store = AIConversationHistoryStore.getInstance();
    if (this.currentSessionSnapshot && this.currentSessionSnapshot.displayItems.length > 0) {
      await store.archiveSession(this.currentSessionSnapshot);
    }
    await store.clearCurrentDraft();
    this.archivedHistory = store.getArchivedHistory();
    this.currentSessionSnapshot = null;
    this.selectedHistoryId = '';
    this.workspaceSessionVersion += 1;
    this.historyPreviewVersion += 1;
    this.newChatSignal += 1;
  }

  private persistCurrentSnapshot(snapshot: AIWorkspaceSessionSnapshot): void {
    this.persistCurrentSnapshotInternal(snapshot);
  }

  private clearCurrentSnapshotPersistence(): void {
    this.clearCurrentSnapshotPersistenceInternal();
  }

  private async persistCurrentSnapshotInternal(snapshot: AIWorkspaceSessionSnapshot): Promise<void> {
    await AIConversationHistoryStore.getInstance().saveCurrentDraft(snapshot);
  }

  private async clearCurrentSnapshotPersistenceInternal(): Promise<void> {
    await AIConversationHistoryStore.getInstance().clearCurrentDraft();
  }

  private handleWorkspaceSnapshotChange(snapshot: AIWorkspaceSessionSnapshot): void {
    if (snapshot.displayItems.length === 0) {
      this.currentSessionSnapshot = null;
      this.clearCurrentSnapshotPersistence();
      return;
    }
    this.currentSessionSnapshot = snapshot;
    this.persistCurrentSnapshot(snapshot);
  }

  private openCurrentConversation(): void {
    this.selectedHistoryId = '';
    this.workspaceSessionVersion += 1;
  }

  private openArchivedConversation(recordId: string): void {
    this.selectedHistoryId = recordId;
    this.historyPreviewVersion += 1;
  }

  private deleteArchivedConversation(recordId: string): void {
    this.deleteArchivedConversationInternal(recordId);
  }

  private async deleteArchivedConversationInternal(recordId: string): Promise<void> {
    if (this.deletingHistoryId === recordId) {
      return;
    }

    this.deletingHistoryId = recordId;
    try {
      const store = AIConversationHistoryStore.getInstance();
      await store.deleteHistoryRecord(recordId);
      this.archivedHistory = store.getArchivedHistory();

      if (this.selectedHistoryId === recordId) {
        this.selectedHistoryId = '';
        this.workspaceSessionVersion += 1;
        this.historyPreviewVersion += 1;
      }
    } finally {
      this.deletingHistoryId = '';
    }
  }

  private selectedHistoryRecord(): AIConversationHistoryRecord | null {
    if (!this.selectedHistoryId) {
      return null;
    }
    const found = this.archivedHistory.find((item) => item.id === this.selectedHistoryId);
    return found ? found : null;
  }

  private hasCurrentConversation(): boolean {
    return !!this.currentSessionSnapshot && this.currentSessionSnapshot.displayItems.length > 0;
  }

  private currentConversationSubtitle(): string {
    if (!this.currentSessionSnapshot || this.currentSessionSnapshot.displayItems.length === 0) {
      return '从一句自然语言开始';
    }
    const lastText = [...this.currentSessionSnapshot.displayItems]
      .reverse()
      .find((item) => (item.text ?? '').trim().length > 0);
    if (!lastText || !lastText.text) {
      return '继续这一轮任务、习惯和记忆整理';
    }
    return this.limitText(lastText.text, this.usesExtraWideLayout() ? 26 : 20);
  }

  private formatConversationTime(timestamp: number): string {
    return DateTimeUtils.formatForUI(new Date(timestamp));
  }

  private limitText(text: string, maxLength: number): string {
    if (text.length <= maxLength) {
      return text;
    }
    return `${text.substring(0, Math.max(0, maxLength - 1))}…`;
  }

  private usesMediumLayout(): boolean {
    return this.currentBreakpoint === AppBreakpoint.MD;
  }

  private usesWideLayout(): boolean {
    return AppBreakpointUtils.isWide(this.currentBreakpoint);
  }

  private usesExtraWideLayout(): boolean {
    return this.currentBreakpoint === AppBreakpoint.XL;
  }

  private workspaceTopAvoidHeight(): number {
    return this.statusBarHeight + 18 + this.topAvoidExtraHeight;
  }

  private pagePadding(): number {
    return this.usesExtraWideLayout() ? 20 : 16;
  }

  private conversationRailWidth(): number {
    if (this.usesExtraWideLayout()) {
      return 336;
    }
    if (this.usesWideLayout()) {
      return 296;
    }
    return 248;
  }

  private conversationRailCardRadius(): number {
    return this.usesExtraWideLayout() ? 28 : 24;
  }

  private conversationRailCardPadding(): number {
    return this.usesExtraWideLayout() ? 20 : 18;
  }

  private workspaceMaxWidth(): number {
    return this.usesExtraWideLayout() ? 960 : 900;
  }

  private conversationRailListPadding(): number {
    return this.usesExtraWideLayout() ? 10 : 8;
  }

  private hasArchivedHistory(): boolean {
    return this.archivedHistory.length > 0;
  }

  @Builder
  private workspaceBuilder() {
    AIWorkspaceView({
      bypassHuaweiLogin: true,
      topAvoidHeight: this.workspaceTopAvoidHeight(),
      bottomPadding: this.usesWideLayout() ? 42 : 24,
      startNewChatSignal: this.newChatSignal,
      externalSessionSnapshot: this.selectedHistoryId ? null : this.currentSessionSnapshot,
      externalSessionVersion: this.workspaceSessionVersion,
      readonlyHistoryRecord: this.selectedHistoryRecord(),
      readonlyHistoryVersion: this.historyPreviewVersion,
      onSessionSnapshotChange: (snapshot: AIWorkspaceSessionSnapshot): void => {
        this.handleWorkspaceSnapshotChange(snapshot);
      }
    })
      .width('100%')
      .height('100%')
  }

  @Builder
  private workspaceSurfaceBuilder() {
    Stack() {
      this.workspaceBuilder()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.bgPrimary)
    .borderRadius(this.usesWideLayout() ? 28 : 24)
    .clip(true)
  }

  @Builder
  private conversationRowBuilder(
    title: string,
    subtitle: string,
    meta: string,
    icon: Resource,
    active: boolean = false,
    subdued: boolean = false
  ) {
    Row({ space: 12 }) {
      Stack() {
        Circle()
          .width(this.usesExtraWideLayout() ? 42 : 38)
          .height(this.usesExtraWideLayout() ? 42 : 38)
          .fill(active ? this.theme.brand : $r('app.color.background_tertiary'))
          .fillOpacity(active ? 0.16 : 1)

        if (active) {
          Image($r('app.media.lifi'))
            .fillColor(this.theme.brand)
            .width(this.usesExtraWideLayout() ? 24 : 22)
            .height(this.usesExtraWideLayout() ? 24 : 22)
        } else {
          SymbolGlyph(icon)
            .fontSize(17)
            .fontColor([subdued ? $r('app.color.font_secondary') : this.theme.brand])
        }
      }

      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Text(title)
            .fontSize(this.usesExtraWideLayout() ? 17 : 15)
            .fontWeight(active ? FontWeight.Bold : FontWeight.Medium)
            .fontColor($r('app.color.font_primary'))

          if (active) {
            Text(this.selectedHistoryId ? '历史' : '当前')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.brand)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor($r('app.color.background_secondary'))
              .borderRadius(999)
          }
        }

        Text(subtitle)
          .fontSize(this.usesExtraWideLayout() ? 13 : 12)
          .lineHeight(this.usesExtraWideLayout() ? 20 : 18)
          .fontColor($r('app.color.font_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (meta.length > 0) {
          Text(meta)
            .fontSize(11)
            .fontColor($r('app.color.font_secondary'))
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(14)
        .fontColor([$r('app.color.font_secondary')])
    }
    .width('100%')
    .padding(this.conversationRailCardPadding())
    .backgroundColor(active ? this.theme.bgPrimary : Color.Transparent)
    .borderRadius(this.conversationRailCardRadius())
    .border({
      width: active ? 1 : 0,
      color: active ? this.theme.brand : Color.Transparent
    })
    .opacity(subdued ? 0.76 : 1)
  }

  @Builder
  private currentConversationListItemBuilder() {
    this.conversationRowBuilder(
      '当前对话',
      this.currentConversationSubtitle(),
      this.hasCurrentConversation() && this.currentSessionSnapshot
        ? this.formatConversationTime(this.currentSessionSnapshot.updatedAt)
        : '尚未开始',
      $r('sys.symbol.square_and_pencil'),
      this.selectedHistoryId.length === 0
    )
  }

  @Builder
  private historyConversationListItemBuilder(record: AIConversationHistoryRecord) {
    this.conversationRowBuilder(
      record.title,
      record.preview,
      `${this.formatConversationTime(record.updatedAt)} · ${record.itemCount} 条`,
      $r('sys.symbol.doc_text'),
      this.selectedHistoryId === record.id
    )
  }

  @Builder
  private historySectionLabelBuilder() {
    Row() {
      Text('历史')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.font_secondary'))
      Blank()
      if (this.hasArchivedHistory()) {
        Text(`${this.archivedHistory.length}`)
          .fontSize(11)
          .fontColor($r('app.color.font_secondary'))
      }
    }
    .width('100%')
    .padding({
      left: this.conversationRailCardPadding(),
      right: this.conversationRailCardPadding(),
      top: 10,
      bottom: 4
    })
  }

  @Builder
  private emptyHistoryBuilder() {
    Row({ space: 10 }) {
      Stack() {
        Circle()
          .width(34)
          .height(34)
          .fill($r('app.color.background_tertiary'))

        SymbolGlyph($r('sys.symbol.archivebox'))
          .fontSize(15)
          .fontColor([$r('app.color.font_secondary')])
      }

      Text('还没有历史对话')
        .fontSize(13)
        .fontColor($r('app.color.font_secondary'))
    }
    .width('100%')
    .padding({ left: 4, right: 4, top: 6, bottom: 6 })
  }

  @Builder
  private conversationRailBuilder() {
    List({ space: 4 }) {
      HdsListItem({
        customItemBuilder: (): void => {
          this.currentConversationListItemBuilder();
        },
        hdsListItemCard: {
          onClick: (): void => {
            this.openCurrentConversation();
          },
          cardBackgroundColor: Color.Transparent,
          cardBorderRadius: this.conversationRailCardRadius()
        }
      })

      ListItem() {
        this.historySectionLabelBuilder()
      }

      if (!this.hasArchivedHistory()) {
        ListItem() {
          this.emptyHistoryBuilder()
        }
      } else {
        ForEach(this.archivedHistory, (record: AIConversationHistoryRecord) => {
          HdsListItem({
            customItemBuilder: (): void => {
              this.historyConversationListItemBuilder(record);
            },
            hdsListItemCard: {
              onClick: (): void => {
                this.openArchivedConversation(record.id);
              },
              cardBackgroundColor: Color.Transparent,
              cardBorderRadius: this.conversationRailCardRadius()
            },
            swipeActionOptions: {
              deleteIconOptions: {
                backgroundColor: $r('app.color.chart_red'),
                iconColor: Color.White,
                onAction: (): void => {
                  this.deleteArchivedConversation(record.id);
                }
              }
            }
          })
        }, (record: AIConversationHistoryRecord) => record.id)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.conversationRailListPadding(), bottom: this.conversationRailListPadding() })
    .scrollBar(BarState.Off)
  }

  @Builder
  private mediumLayoutBuilder() {
    Row({ space: 16 }) {
      Column() {
        this.conversationRailBuilder()
      }
      .width(this.conversationRailWidth())
      .height('100%')
      .padding({ top: this.workspaceTopAvoidHeight(), bottom: 20 })

      Divider()
        .vertical(true)
        .height('100%')
        .strokeWidth(1)
        .color($r('sys.color.ohos_id_color_list_separator'))
        .opacity(0.5)

      Column() {
        this.workspaceSurfaceBuilder()
      }
      .layoutWeight(1)
      .height('100%')
      .padding({ top: 8, bottom: 8 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: this.pagePadding(), right: this.pagePadding() })
  }

  @Builder
  private wideLayoutBuilder() {
    Row({ space: 18 }) {
      Column() {
        this.conversationRailBuilder()
      }
      .width(this.conversationRailWidth())
      .height('100%')
      .padding({ top: this.workspaceTopAvoidHeight(), bottom: 24 })

      Divider()
        .vertical(true)
        .height('100%')
        .strokeWidth(1)
        .color($r('sys.color.ohos_id_color_list_separator'))
        .opacity(0.5)

      Column() {
        this.workspaceSurfaceBuilder()
      }
      .layoutWeight(1)
      .constraintSize({ maxWidth: this.workspaceMaxWidth() })
      .height('100%')
      .padding({ top: 10, bottom: 10 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: this.pagePadding(), right: this.pagePadding() })
  }

  build() {
    HdsNavigation() {
      if (this.usesWideLayout()) {
        this.wideLayoutBuilder()
      } else if (this.usesMediumLayout()) {
        this.mediumLayoutBuilder()
      } else {
        Column() {
          this.workspaceBuilder()
        }
          .layoutWeight(1)
          .width('100%')
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      }
    }
    .titleBar({
      style: getImmersiveTitleBarStyle(false, false),
      avoidLayoutSafeArea: this.usesWideLayout(),
      content: {
        title: {
          mainTitle: 'Lifi AI'
        },
        menu: {
          value: [
            {
              content: {
                icon: $r('sys.symbol.message_badge_plus'),
                action: (): void => {
                  this.startNewConversation();
                }
              }
            }
          ]
        },
        divider: { showType: DividerShowType.OFF }
      }
    })
    .titleMode(HdsNavigationTitleMode.MINI)
    .mode(NavigationMode.Stack)
    .hideBackButton(true)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
