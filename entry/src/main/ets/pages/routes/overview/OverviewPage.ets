import { HdsTabId } from '../../../model/HdsTabsCustomization';
import { HdsNavDestination, HdsNavigation, HdsNavDestinationTitleMode, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { getImmersiveTitleBarStyle } from '../../../common/style/NavStyles';
import { ITheme } from '../../../common/theme/ThemeModel';
import { ThemeManager } from '../../../common/theme/ThemeManager';
import { SheetCompat } from '../../../common/ui/SheetCompat';
import { ArchivePanelView } from '../../common/ArchivePanelView';
import { MonthlyInsightRepository } from './MonthlyInsightRepository';
import { OverviewDashboardModel, OverviewMonthRules } from './OverviewDashboardModel';
import { OverviewViewModel } from './OverviewViewModel';
import { OverviewDashboardContent } from './OverviewDashboardContent';

@Component
export struct OverviewPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageProp('currentTheme') theme: ITheme = ThemeManager.getCurrentTheme();
  @Prop rootTheme: ITheme = ThemeManager.getCurrentTheme();
  @Prop @Watch('onTabSwitch') currentTabIndex: number = 0;
  @Prop isNavDestination: boolean = false;
  @StorageProp('statusBarHeight') statusBarHeight: number = 38;
  @StorageProp('bottomRectHeight') bottomAvoidHeight: number = 0;
  @StorageProp('FocusTimerActive') focusActive: boolean = false;
  @StorageProp('KmpDataRevision') @Watch('reload') dataRevision: number = 0;
  @StorageProp('FocusTimerRevision') @Watch('reload') focusRevision: number = 0;
  @StorageProp('OverviewAppForeground') @Watch('onLifecycleChange') foreground: boolean = true;
  @StorageProp('rootSemanticTabId') @Watch('onLifecycleChange') rootTabId: string = '';
  @StorageProp('IsAppDataReady') @Watch('reload') dataReady: boolean = false;
  @State dashboard: OverviewDashboardModel = new OverviewDashboardModel();
  @State model: OverviewViewModel = new OverviewViewModel();
  @State archiveShown: boolean = false;
  private scroller: Scroller = new Scroller();
  private timer: number = -1;
  private clockKey: string = '';
  private currentClockKey(): string { return OverviewMonthRules.dateKey(new Date()) + ':' + new Date().getTimezoneOffset().toString(); }
  private pageTheme(): ITheme { return this.isNavDestination ? this.theme : this.rootTheme; }
  aboutToAppear(): void {
    const context: Context | undefined = this.getUIContext().getHostContext();
    if (context !== undefined) MonthlyInsightRepository.getInstance().init(context);
    this.clockKey = this.currentClockKey();
    this.reload();
    this.onLifecycleChange();
  }
  aboutToDisappear(): void { if (this.timer !== -1) clearInterval(this.timer); this.timer = -1; }
  private active(): boolean { return this.foreground && (this.isNavDestination || this.rootTabId === HdsTabId.OVERVIEW); }
  private onLifecycleChange(): void {
    if (this.timer !== -1) clearInterval(this.timer);
    this.timer = -1;
    if (!this.active()) return;
    this.clockKey = this.currentClockKey();
    this.reload();
    this.timer = setInterval(() => {
      if (this.clockKey !== this.currentClockKey()) {
        this.clockKey = this.currentClockKey();
        AppStorage.setOrCreate('OverviewClockRevision', (AppStorage.get<number>('OverviewClockRevision') ?? 0) + 1);
        this.reload();
      }
    }, 30000);
  }
  private onTabSwitch(): void { if (this.active()) this.reload(); }
  private reload(): void {
    if (!this.active()) return;
    // Clamp after a clock/timezone change without resetting the user's historical selection.
    if (this.dashboard.month > OverviewMonthRules.monthStart()) this.dashboard.month = OverviewMonthRules.monthStart();
    this.dashboard.load(); this.dashboard.loadArchive(); this.model.loadData();
  }
  private open(domain: string): void {
    if (domain === 'archive') this.archiveShown = true;
    else this.appPathStack.pushPath({ name: 'overview' + domain });
  }
  private title(): string { return Number(this.dashboard.month.substring(5, 7)).toString() + '月总览'; }
  private subtitle(): string {
    return this.dashboard.month.substring(0, 4) + '年 · ' + (this.dashboard.month === OverviewMonthRules.monthStart() ? '本月进行中' : '历史月份');
  }
  @Builder private monthButtons() {
    Row({ space: 4 }) {
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(20).fontColor([$r('app.color.font_primary')])
      }.width(48).height(48).backgroundColor(Color.Transparent).accessibilityText('上一个月')
        .onClick(() => { this.dashboard.switchMonth(-1); })
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(20).fontColor([$r('app.color.font_primary')])
      }.width(48).height(48).backgroundColor(Color.Transparent).accessibilityText('下一个月')
        .enabled(this.dashboard.month < OverviewMonthRules.monthStart())
        .onClick(() => { this.dashboard.switchMonth(1); })
    }.height('100%').width('100%').justifyContent(FlexAlign.End).padding({ right: 16 })
  }
  @Builder private archiveSheet() { ArchivePanelView().width('100%').height('100%') }
  @Builder private content() {
    Scroll(this.scroller) {
      Column() {
        OverviewDashboardContent({ dashboard: this.dashboard, model: this.model, theme: this.pageTheme(), onOpen: (domain: string) => { this.open(domain); } })
      }.width('100%').constraintSize({ maxWidth: 760 })
        .padding({ left: 16, right: 16, top: this.statusBarHeight + 18, bottom: Math.max(100, this.bottomAvoidHeight) + (this.focusActive ? 88 : 0) })
    }.width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .bindSheet($$this.archiveShown, this.archiveSheet(), SheetCompat.immersive({
        height: SheetSize.FIT_CONTENT, dragBar: true, enableOutsideInteractive: false,
        title: { title: '归档', subtitle: '管理已归档的任务和习惯' },
        onDisappear: () => { this.archiveShown = false; this.reload(); }
      }))
  }
  build() {
    if (this.isNavDestination) {
      HdsNavDestination() { this.content() }
        .titleBar({ style: getImmersiveTitleBarStyle(false), content: { title: { mainTitle: this.title(), subTitle: this.subtitle() }, stackBuilder: () => { this.monthButtons(); } } })
        .titleMode(HdsNavDestinationTitleMode.MINI).bindToScrollable([this.scroller])
        .backgroundColor(this.pageTheme().bgPrimary).expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onShown(() => { this.reload(); })
    } else {
      HdsNavigation() { this.content() }
        .titleBar({ style: getImmersiveTitleBarStyle(false), content: { title: { mainTitle: this.title(), subTitle: this.subtitle() }, stackBuilder: () => { this.monthButtons(); } } })
        .titleMode(HdsNavigationTitleMode.MINI).bindToScrollable([this.scroller])
        .backgroundColor(Color.Transparent).hideBackButton(true).mode(NavigationMode.Stack).navBarWidth('100%')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
  }
}
@Builder
export function HdsOverviewDestinationBuilder() { OverviewPage({ currentTabIndex: -1, isNavDestination: true }) }
