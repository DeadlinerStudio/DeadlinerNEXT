import {
  BottomBuilderShowType,
  HdsNavDestination
} from '@kit.UIDesignKit';
import { SegmentButtonV2Items } from '@kit.ArkUI';
import { TopSafeContainer } from '../../../components/TopSafeContainer';
import { HdsTitleBarSegment } from '../../../components/HdsTitleBarSegment';
import { TaskRepository } from '../../../../common/repository/TaskRepository';
import { HabitRepository } from '../../../../common/repository/HabitRepository';
import { InspirationRepository } from '../../../../common/repository/InspirationRepository';
import { DDLStatus } from '../../../../model/DDLStatus';
import { DDLItemCardSwipeable } from '../../../components/TaskItemCard';
import { HabitRow, HabitWithDailyStatus } from '../../../components/HabitComponents';
import { VibrationUtils } from '../../../../utils/VibrationUtils';
import { ConfettiController } from '../../../components/confetti/ConfettiController';
import {
  ArchivedSearchModel,
  SearchResult,
  SearchScope,
  SearchUtils,
  TaskUIModel
} from '../../../../utils/SearchUtils';
import { DDLItem, Habit } from '../../../../model/DDLModels';
import { InspirationItem } from '../../../../model/InspirationModels';
import { ITheme } from '../../../../common/theme/ThemeModel';
import { TaskState, TaskStateAction } from '../../../../model/TaskStateMachine';
import { InspirationEditSheet, InspirationSearchCard } from '../../capture/CaptureComponents';
import { AddTaskSheet } from '../modify/task/AddTaskSheet';
import { AddHabitSheet } from '../modify/habit/AddHabitSheet';
import { getImmersiveTitleBarStyle } from '../../../../common/style/NavStyles';
import { SettingsConstants as C } from '../../../../common/local/SettingsConstants';
import { getHdsMaterialLevelRaw } from '../../../../common/style/MaterialLevel';
import { HdsMiniBarButton } from '../../../components/infra/HdsMiniBarButton';
import { ImmersiveMaterialModifier } from '../../../../common/style/SystemMaterialCompat';
import { DialogCompat } from '../../../../common/ui/DialogCompat';
import { Toast } from '../../../../common/ui/Toast';
import { API23_UI_DEFAULT, EXPERIMENTAL_COMPONENTS_DEFAULT } from '../../../../common/local/ExperimentalComponentsPolicy';
import { SheetCompat } from '../../../../common/ui/SheetCompat';

@Builder
export function SearchPageBuilder() {
  SearchPage()
}

enum SearchListItemType {
  SPACER = 'spacer',
  LOADING = 'loading',
  FOOTER = 'footer',
  SYMBOL_HEADER = 'symbolHeader',
  IMAGE_HEADER = 'imageHeader',
  TASK = 'task',
  HABIT = 'habit',
  INSPIRATION = 'inspiration',
  ARCHIVED = 'archived'
}

interface SearchListItem {
  id: string;
  type: SearchListItemType;
}

class SearchSpacerItem implements SearchListItem {
  id: string;
  type: SearchListItemType = SearchListItemType.SPACER;

  constructor(id: string) {
    this.id = id;
  }
}

class SearchLoadingItem implements SearchListItem {
  id: string;
  type: SearchListItemType = SearchListItemType.LOADING;

  constructor(id: string) {
    this.id = id;
  }
}

class SearchFooterItem implements SearchListItem {
  id: string;
  type: SearchListItemType = SearchListItemType.FOOTER;

  constructor(id: string) {
    this.id = id;
  }
}

class SearchSymbolHeaderItem implements SearchListItem {
  id: string;
  type: SearchListItemType = SearchListItemType.SYMBOL_HEADER;
  title: string;
  symbol: Resource;
  color: ResourceColor | Color;

  constructor(id: string, title: string, symbol: Resource, color: ResourceColor | Color) {
    this.id = id;
    this.title = title;
    this.symbol = symbol;
    this.color = color;
  }
}

class SearchImageHeaderItem implements SearchListItem {
  id: string;
  type: SearchListItemType = SearchListItemType.IMAGE_HEADER;
  title: string;
  icon: ResourceStr;

  constructor(id: string, title: string, icon: ResourceStr) {
    this.id = id;
    this.title = title;
    this.icon = icon;
  }
}

class SearchTaskItem implements SearchListItem {
  id: string;
  type: SearchListItemType = SearchListItemType.TASK;
  task: TaskUIModel;

  constructor(id: string, task: TaskUIModel) {
    this.id = id;
    this.task = task;
  }
}

class SearchHabitItem implements SearchListItem {
  id: string;
  type: SearchListItemType = SearchListItemType.HABIT;
  habit: HabitWithDailyStatus;

  constructor(id: string, habit: HabitWithDailyStatus) {
    this.id = id;
    this.habit = habit;
  }
}

class SearchInspirationItem implements SearchListItem {
  id: string;
  type: SearchListItemType = SearchListItemType.INSPIRATION;
  inspiration: InspirationItem;

  constructor(id: string, inspiration: InspirationItem) {
    this.id = id;
    this.inspiration = inspiration;
  }
}

class SearchArchivedItem implements SearchListItem {
  id: string;
  type: SearchListItemType = SearchListItemType.ARCHIVED;
  archived: ArchivedSearchModel;

  constructor(id: string, archived: ArchivedSearchModel) {
    this.id = id;
    this.archived = archived;
  }
}

class SearchListDataSource implements IDataSource {
  private items: SearchListItem[] = [];
  private listeners: DataChangeListener[] = [];

  public setItems(items: SearchListItem[]): void {
    this.items = items;
    this.notifyDataReload();
  }

  public appendItems(items: SearchListItem[]): void {
    if (items.length === 0) {
      return;
    }
    const startIndex = this.items.length;
    this.items = this.items.concat(items);
    this.notifyDataAdd(startIndex, items.length);
  }

  public totalCount(): number {
    return this.items.length;
  }

  public getData(index: number): SearchListItem {
    return this.items[index];
  }

  public registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  public unregisterDataChangeListener(listener: DataChangeListener): void {
    const index = this.listeners.indexOf(listener);
    if (index >= 0) {
      this.listeners.splice(index, 1);
    }
  }

  private notifyDataReload(): void {
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataReloaded();
    });
  }

  private notifyDataAdd(startIndex: number, count: number): void {
    this.listeners.forEach((listener: DataChangeListener) => {
      for (let offset = 0; offset < count; offset++) {
        listener.onDataAdd(startIndex + offset);
      }
    });
  }
}

@Component
export struct SearchPage {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @Consume('appPathStack') appPathStack: NavPathStack;
  @Consume('searchRouteOpacity') searchRouteOpacity: number = 1;
  @Consume('isEnteringSearchRoute') isEnteringSearchRoute: boolean = true;
  @StorageLink('statusBarHeight') statusBarHeight: number = 38;

  @State bgColor: Resource | Color | ResourceColor = this.theme.bgPrimary;
  backAction?: () => void

  @State searchText: string = '';
  @State isSearching: boolean = false;
  @State hasSearchTerm: boolean = false;
  @State selectedScopeIndexes: number[] = [0];
  @State visibleResults: SearchResult = this.emptySearchResult();

  private logic = SearchUtils.getInstance();
  private taskRepo = TaskRepository.getInstance();
  private habitRepo = HabitRepository.getInstance();
  private inspirationRepo = InspirationRepository.getInstance();
  private searchListDataSource: SearchListDataSource = new SearchListDataSource();

  private scroller: Scroller = new Scroller();
  private confetti: ConfettiController = new ConfettiController();
  private togglingHabitIds: Set<number> = new Set();
  @State isFirstLoad: boolean = true;

  @State isInspirationSheetShow: boolean = false;
  @State editingInspiration: InspirationItem | null = null;
  @State inspirationDraftText: string = '';
  @State isAddTaskSheetShow: boolean = false;
  @State isAddHabitSheetShow: boolean = false;
  @State aiTargetText: string = '';
  @State directTaskName: string = '';
  @State directTaskNote: string = '';
  @State directHabitName: string = '';
  @State searchBarMeasuredWidth: number = 0;
  private searchRequestToken: number = 0;
  private listBuildToken: number = 0;
  private cachedQuery: string = '';
  private cachedAllResults: SearchResult = this.emptySearchResult();
  readonly SCOPE_SEGMENT_HEIGHT: number = 48;
  readonly SCOPE_EXPERIMENTAL_HEIGHT: number = 52;
  readonly SEARCH_LIST_APPEND_CHUNK_SIZE: number = 3;

  readonly SEARCH_INPUT_ID = 'search_input';
  readonly scopeButtons: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: '全部' },
    { text: '清单' },
    { text: '归档' }
  ]);
  @StorageLink(C.KEY_EXPERIMENTAL_COMPONENTS) experimentalComponents: boolean = EXPERIMENTAL_COMPONENTS_DEFAULT;
  @StorageProp(C.KEY_ENABLE_API23) api23: boolean = API23_UI_DEFAULT;
  @StorageProp(C.KEY_API23_MATERIAL_LEVEL) materialLevel: string = 'EXQUISITE';

  async aboutToAppear() {
    void this.rebuildSearchListItems();
    await this.logic.preloadData();
    getContext(this).eventHub.on('sync_done', (): void => {
      void this.logic.preloadData().then(async (): Promise<void> => {
        await this.refreshCurrentResults();
      });
    });
    setTimeout(() => {
      focusControl.requestFocus(this.SEARCH_INPUT_ID);
    }, 500);
    setTimeout(() => { this.isFirstLoad = false; }, 750);
  }

  aboutToDisappear(): void {
    getContext(this).eventHub.off('sync_done');
  }

  private resolveScope(index: number): SearchScope {
    switch (index) {
      case 1:
        return SearchScope.ACTIVE;
      case 2:
        return SearchScope.ARCHIVE;
      default:
        return SearchScope.ALL;
    }
  }

  private get currentScope(): SearchScope {
    return this.resolveScope(this.selectedScopeIndexes[0] ?? 0);
  }

  private async handleSearch(value: string, forceRefresh: boolean = false, scopeOverride?: SearchScope) {
    this.searchText = value;
    const normalizedQuery = value.trim();
    const hasTerm = normalizedQuery.length > 0;
    this.hasSearchTerm = hasTerm;
    const targetScope = scopeOverride ?? this.currentScope;

    if (!hasTerm) {
      this.resetSearchCache();
      this.setSearching(false);
      this.clearResults();
      return;
    }

    if (!forceRefresh && this.cachedQuery === normalizedQuery) {
      this.applyResultsForScope(this.cachedAllResults, targetScope);
      this.setSearching(false);
      return;
    }

    const requestToken = ++this.searchRequestToken;
    this.setSearching(true);
    const results = await this.logic.executeSearch(normalizedQuery, SearchScope.ALL);

    if (requestToken !== this.searchRequestToken) {
      return;
    }

    this.cachedQuery = normalizedQuery;
    this.cachedAllResults = results;

    this.setSearching(false);
    this.applyResultsForScope(results, targetScope);
  }

  private async refreshCurrentResults(): Promise<void> {
    if (this.hasSearchTerm) {
      await this.handleSearch(this.searchText, true);
      return;
    }

    this.resetSearchCache();
    this.clearResults();
  }

  private clearResults(): void {
    this.visibleResults = this.emptySearchResult();
    void this.rebuildSearchListItems();
  }

  private emptySearchResult(): SearchResult {
    return {
      tasks: [],
      habits: [],
      inspirations: [],
      archivedTasks: [],
      archivedHabits: []
    };
  }

  private resetSearchCache(): void {
    this.searchRequestToken += 1;
    this.cachedQuery = '';
    this.cachedAllResults = this.emptySearchResult();
  }

  private filterResultsByScope(results: SearchResult, scope: SearchScope): SearchResult {
    switch (scope) {
      case SearchScope.ACTIVE:
        return {
          tasks: results.tasks,
          habits: results.habits,
          inspirations: results.inspirations,
          archivedTasks: [],
          archivedHabits: []
        };
      case SearchScope.ARCHIVE:
        return {
          tasks: [],
          habits: [],
          inspirations: [],
          archivedTasks: results.archivedTasks,
          archivedHabits: results.archivedHabits
        };
      case SearchScope.ALL:
      default:
        return results;
    }
  }

  private applyResultsForScope(results: SearchResult, scope: SearchScope): void {
    this.applyResults(this.filterResultsByScope(results, scope));
  }

  private applyResults(results: SearchResult): void {
    this.visibleResults = results;
    void this.rebuildSearchListItems();
  }

  private setSearching(value: boolean): void {
    if (this.isSearching === value) {
      return;
    }
    this.isSearching = value;
    void this.rebuildSearchListItems();
  }

  private async yieldUiFrame(): Promise<void> {
    await new Promise<void>((resolve: () => void) => {
      setTimeout(() => resolve(), 0);
    });
  }

  private buildTaskSectionItems(): SearchListItem[] {
    const items: SearchListItem[] = [];
    if (this.visibleResults.tasks.length === 0) {
      return items;
    }

    items.push(new SearchSymbolHeaderItem('header_tasks', '任务', $r('sys.symbol.checkmark_circle'), this.theme.brand));
    this.visibleResults.tasks.forEach((task: TaskUIModel) => {
      items.push(new SearchTaskItem(`task_${task.dbId}`, task));
    });
    return items;
  }

  private buildHabitSectionItems(): SearchListItem[] {
    const items: SearchListItem[] = [];
    if (this.visibleResults.habits.length === 0) {
      return items;
    }

    items.push(new SearchSymbolHeaderItem('header_habits', '习惯', $r('sys.symbol.leaf'), $r('app.color.chart_green')));
    this.visibleResults.habits.forEach((habit: HabitWithDailyStatus) => {
      items.push(new SearchHabitItem(`habit_${habit.habit.id}`, habit));
    });
    return items;
  }

  private buildInspirationSectionItems(): SearchListItem[] {
    const items: SearchListItem[] = [];
    if (this.visibleResults.inspirations.length === 0) {
      return items;
    }

    items.push(new SearchImageHeaderItem('header_inspirations', '灵感', $r('app.media.capture_mo')));
    this.visibleResults.inspirations.forEach((inspiration: InspirationItem) => {
      items.push(new SearchInspirationItem(`inspiration_${inspiration.id}`, inspiration));
    });
    return items;
  }

  private buildArchivedTaskSectionItems(): SearchListItem[] {
    const items: SearchListItem[] = [];
    if (this.visibleResults.archivedTasks.length === 0) {
      return items;
    }

    items.push(new SearchSymbolHeaderItem(
      'header_archived_tasks',
      '归档任务',
      $r('sys.symbol.archivebox'),
      $r('sys.color.ohos_id_color_text_secondary')
    ));
    this.visibleResults.archivedTasks.forEach((archived: ArchivedSearchModel) => {
      items.push(new SearchArchivedItem(archived.id, archived));
    });
    return items;
  }

  private buildArchivedHabitSectionItems(): SearchListItem[] {
    const items: SearchListItem[] = [];
    if (this.visibleResults.archivedHabits.length === 0) {
      return items;
    }

    items.push(new SearchSymbolHeaderItem(
      'header_archived_habits',
      '归档习惯',
      $r('sys.symbol.archivebox'),
      $r('sys.color.ohos_id_color_text_secondary')
    ));
    this.visibleResults.archivedHabits.forEach((archived: ArchivedSearchModel) => {
      items.push(new SearchArchivedItem(archived.id, archived));
    });
    return items;
  }

  private async appendSectionItems(buildToken: number, items: SearchListItem[]): Promise<boolean> {
    if (this.listBuildToken !== buildToken) {
      return false;
    }
    if (items.length === 0) {
      return true;
    }

    for (let startIndex = 0; startIndex < items.length; startIndex += this.SEARCH_LIST_APPEND_CHUNK_SIZE) {
      if (this.listBuildToken !== buildToken) {
        return false;
      }

      this.searchListDataSource.appendItems(
        items.slice(startIndex, Math.min(startIndex + this.SEARCH_LIST_APPEND_CHUNK_SIZE, items.length))
      );
      await this.yieldUiFrame();
    }
    return this.listBuildToken === buildToken;
  }

  private async rebuildSearchListItems(): Promise<void> {
    const buildToken = ++this.listBuildToken;
    this.searchListDataSource.setItems([new SearchSpacerItem('search_spacer')]);

    if (this.isSearching) {
      this.searchListDataSource.appendItems([
        new SearchLoadingItem('search_loading'),
        new SearchFooterItem('search_footer')
      ]);
      return;
    }

    if (!await this.appendSectionItems(buildToken, this.buildTaskSectionItems())) {
      return;
    }
    if (!await this.appendSectionItems(buildToken, this.buildHabitSectionItems())) {
      return;
    }
    if (!await this.appendSectionItems(buildToken, this.buildInspirationSectionItems())) {
      return;
    }
    if (!await this.appendSectionItems(buildToken, this.buildArchivedTaskSectionItems())) {
      return;
    }
    if (!await this.appendSectionItems(buildToken, this.buildArchivedHabitSectionItems())) {
      return;
    }

    if (this.listBuildToken !== buildToken) {
      return;
    }
    this.searchListDataSource.appendItems([new SearchFooterItem('search_footer')]);
  }

  private onScopeSegmentClick(index: number): void {
    const targetScope = this.resolveScope(index);

    if (!this.hasSearchTerm) {
      return;
    }

    const normalizedQuery = this.searchText.trim();
    if (normalizedQuery.length === 0) {
      return;
    }

    if (this.cachedQuery === normalizedQuery) {
      this.applyResultsForScope(this.cachedAllResults, targetScope);
      return;
    }

    void this.handleSearch(this.searchText, false, targetScope);
  }

  // —— 交互操作 ——

  private async onTaskPrimaryAction(taskUI: TaskUIModel) {
    VibrationUtils.vibrateShort();
    try {
      if (taskUI.taskState === TaskState.ACTIVE) {
        await this.taskRepo.transitionDDL(taskUI.dbId, TaskStateAction.MARK_COMPLETE);
        this.confetti.fire();
      } else {
        await this.taskRepo.transitionDDL(taskUI.dbId, TaskStateAction.RESTORE_ACTIVE);
      }
      await this.refreshCurrentResults();
      getContext(this).eventHub.emit('sync_done');
    } catch (e) {
      console.error('Task complete failed', e);
    }
  }

  private onTaskSecondaryAction(taskUI: TaskUIModel) {
    if (taskUI.taskState === TaskState.ACTIVE) {
      AlertDialog.show(DialogCompat.withAlertBlurStyle({
        title: '放弃确认',
        message: `确定要放弃任务“${taskUI.title}”吗？`,
        primaryButton: {
          value: '取消',
          fontColor: this.theme.brand,
          action: () => {}
        },
        secondaryButton: {
          value: '放弃',
          fontColor: Color.Red,
          action: async () => {
            await this.taskRepo.transitionDDL(taskUI.dbId, TaskStateAction.MARK_GIVE_UP);
            await this.refreshCurrentResults();
            getContext(this).eventHub.emit('sync_done');
          }
        }
      }, BlurStyle.Regular));
      return;
    }

    this.taskRepo.transitionDDL(taskUI.dbId, TaskStateAction.MARK_ARCHIVE).then(() => {
      void this.refreshCurrentResults();
      getContext(this).eventHub.emit('sync_done');
    }).catch((e: Error) => {
      console.error('Task archive failed', e);
    });
  }

  private async onHabitToggle(item: HabitWithDailyStatus) {
    if (this.togglingHabitIds.has(item.habit.id)) {
      return;
    }

    this.togglingHabitIds.add(item.habit.id);

    VibrationUtils.vibrateShort();
    try {
      const today = new Date();
      await this.habitRepo.toggleRecord(item.habit.id, today);
      if (!item.isCompleted && (item.doneCount + 1 >= item.targetCount)) {
        this.confetti.fire();
      }
      await this.refreshCurrentResults();
      getContext(this).eventHub.emit('sync_done');
    } catch (e) {
      console.error('Habit toggle failed', e);
    } finally {
      this.togglingHabitIds.delete(item.habit.id);
    }
  }

  private async onArchivedDelete(item: ArchivedSearchModel) {
    AlertDialog.show(DialogCompat.withAlertBlurStyle({
      title: '永久删除',
      message: '确定要永久删除此归档记录吗？',
      primaryButton: {
        value: '取消',
        fontColor: this.theme.brand,
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: Color.Red,
        action: async () => {
          try {
            if (item.originalType === 'task') {
              await this.taskRepo.deleteDDL((item.originalItem as DDLItem).id);
            } else {
              await this.habitRepo.deleteHabitByDdlId((item.originalItem as Habit).ddlId);
            }
            Toast.show({ message: '已删除' });
            await this.refreshCurrentResults();
            getContext(this).eventHub.emit('sync_done');
          } catch (e) {
            Toast.show({ message: '删除失败' });
          }
        }
      }
    }, BlurStyle.Regular))
  }

  private async saveInspirationDetail(): Promise<void> {
    if (!this.editingInspiration) {
      return;
    }

    const text = this.inspirationDraftText.trim();
    if (!text) {
      Toast.show({ message: '留一点内容再保存吧' });
      return;
    }

    await this.inspirationRepo.updateInspiration({
      id: this.editingInspiration.id,
      text: text,
      createdAt: this.editingInspiration.createdAt,
      updatedAt: this.editingInspiration.updatedAt
    });
    this.isInspirationSheetShow = false;
    this.editingInspiration = null;
    await this.logic.preloadData();
    await this.refreshCurrentResults();
    getContext(this).eventHub.emit('sync_done');
  }

  private async deleteInspiration(item: InspirationItem): Promise<void> {
    await this.inspirationRepo.deleteInspiration(item.id);
    Toast.show({ message: '已删除' });
    await this.logic.preloadData();
    await this.refreshCurrentResults();
    getContext(this).eventHub.emit('sync_done');
  }

  private openInspirationDetail(item: InspirationItem): void {
    this.editingInspiration = item;
    this.inspirationDraftText = item.text;
    this.isInspirationSheetShow = true;
  }

  private guessTitleFromText(text: string): string {
    const normalized = text.replace(/\n+/g, ' ').trim();
    if (!normalized) {
      return '未命名灵感';
    }
    return normalized.length > 24 ? normalized.slice(0, 24) : normalized;
  }

  private openAiTaskFromText(text: string): void {
    this.aiTargetText = text;
    this.isInspirationSheetShow = false;
    this.isAddTaskSheetShow = true;
  }

  private openAiHabitFromText(text: string): void {
    this.aiTargetText = text;
    this.isInspirationSheetShow = false;
    this.isAddHabitSheetShow = true;
  }

  private openDirectTaskFromText(text: string): void {
    this.aiTargetText = '';
    this.directTaskName = this.guessTitleFromText(text);
    this.directTaskNote = text;
    this.isInspirationSheetShow = false;
    this.isAddTaskSheetShow = true;
  }

  private openDirectHabitFromText(text: string): void {
    this.aiTargetText = '';
    this.directHabitName = this.guessTitleFromText(text);
    this.isInspirationSheetShow = false;
    this.isAddHabitSheetShow = true;
  }

  private resolveSearchBarWidth(): number {
    return this.searchBarMeasuredWidth > 0 ? this.searchBarMeasuredWidth : 320;
  }

  @Builder
  private searchInputContent(isTransparentBg: boolean = false) {
    Search({ value: this.searchText, placeholder: '搜索任务、习惯或灵感...' })
      .searchButton('搜索', { fontColor: this.theme.brand })
      .id(this.SEARCH_INPUT_ID)
      .defaultFocus(true)
      .width('100%')
      .height(40)
      .backgroundColor(isTransparentBg ? Color.Transparent : $r('sys.color.comp_background_tertiary'))
      .placeholderColor($r('sys.color.ohos_id_color_text_secondary'))
      .onChange((value: string) => this.handleSearch(value))
      .margin({ top: 0 })
      .attributeModifier(new ImmersiveMaterialModifier())
  }

  @Builder searchBuilder() {
    if (this.experimentalComponents && this.api23) {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          HdsMiniBarButton({
            barWidth: this.resolveSearchBarWidth(),
            barHeight: 52,
            materialLevel: getHdsMaterialLevelRaw(this.materialLevel)
          }) {
            this.searchInputContent(true)
          }
        }
        .width('100%')
        .height(52)
        .onAreaChange((_, area) => {
          if (typeof area.width === 'number' && area.width > 0) {
            this.searchBarMeasuredWidth = area.width;
          }
        })
      }
      .padding({ left: 64, right: 16 })
      .transition(
        TransitionEffect.OPACITY
          .combine(TransitionEffect.translate({ x: -52, y: 72 }))
          .animation({ duration: 400, curve: Curve.EaseInOut })
      )
    } else {
      Row() {
        this.searchInputContent()
      }
      .padding({ left: 64, right: 16 })
      .transition(
        TransitionEffect.OPACITY
          .combine(TransitionEffect.translate({ x: -52, y: 72 }))
          .animation({ duration: 400, curve: Curve.EaseInOut })
      )
    }
  }

  @Builder buildEmptyPlaceholder() {
    Column({ space: 16 }) {
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(80)
        .fontColor([$r('sys.color.ohos_id_color_text_tertiary')])
        .opacity(0.5)
      Column({ space: 8 }) {
        Text('输入关键词进行搜索')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        Text('支持搜索任务、习惯和灵感内容')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder buildNoResultPlaceholder() {
    Row({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.nosign'))
        .fontSize(22)
        .fontColor([$r('sys.color.ohos_id_color_text_tertiary')])
      Column({ space: 4 }) {
        Text('没有找到匹配内容')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
        Text('试试换个关键词，或切换搜索范围。')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(22)
  }

  @Builder
  private buildSearchScopeRow() {
    Column() {
      HdsTitleBarSegment({
        items: this.scopeButtons,
        selectedIndexes: $selectedScopeIndexes,
        onItemClicked: (index: number) => {
          this.onScopeSegmentClick(index);
        },
        maxFontScale: 2,
        segmentHeight: this.SCOPE_SEGMENT_HEIGHT,
        normalWidth: '100%',
        experimentalWidth: '100%',
        experimentalHeight: this.SCOPE_EXPERIMENTAL_HEIGHT
      })
        .align(Alignment.Center)
    }
    .id('search_scope_segment')
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16 })
    .justifyContent(FlexAlign.Center)
    .constraintSize({ maxWidth: 500 })
  }

  @Builder
  private buildNoResultState() {
    Column({ space: 12 }) {
      this.buildNoResultPlaceholder()
      Blank()
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
    .padding({ left: 12, right: 12, top: 16, bottom: 24 })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  private buildLoadingRow() {
    Row() {
      LoadingProgress()
        .width(24)
        .height(24)
      Text('搜索中...')
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .margin({ left: 10 })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 24, bottom: 12 })
  }

  @Builder
  private sectionHeader(title: string, symbol: Resource, color: ResourceColor | Color) {
    Row({ space: 8 }) {
      SymbolGlyph(symbol)
        .fontSize(18)
        .fontColor([color])

      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
    }
    .width('100%')
    .padding({ top: 16, bottom: 4, left: 4 })
  }

  @Builder
  private imageSectionHeader(title: string, icon: ResourceStr) {
    Row({ space: 8 }) {
      Image(icon)
        .width(18)
        .height(18)
        .objectFit(ImageFit.Contain)

      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
    }
    .width('100%')
    .padding({ top: 16, bottom: 4, left: 4 })
  }

  @Builder
  private buildTaskSearchItem(item: SearchTaskItem) {
    DDLItemCardSwipeable({
      title: item.task.title,
      remainingTimeAlt: item.task.remainingTimeAlt,
      note: item.task.note,
      progress: item.task.progress,
      isStarred: item.task.isStarred,
      status: item.task.status,
      selectionMode: false,
      selected: false,
      primaryActionSymbol: item.task.taskState === TaskState.ACTIVE
        ? $r('sys.symbol.checkmark_circle')
        : $r('sys.symbol.arrowshape_turn_up_left'),
      secondaryActionSymbol: item.task.taskState === TaskState.ACTIVE
        ? $r('sys.symbol.flag')
        : $r('sys.symbol.archivebox'),
      secondaryActionColor: item.task.taskState === TaskState.ACTIVE
        ? $r('app.color.chart_yellow')
        : $r('app.color.chart_red'),
      onPrimaryAction: (): Promise<void> => this.onTaskPrimaryAction(item.task),
      onSecondaryAction: (): void => this.onTaskSecondaryAction(item.task)
    })
  }

  @Builder
  private buildHabitSearchItem(item: SearchHabitItem) {
    HabitRow({
      data: item.habit,
      status: item.habit.isCompleted ? DDLStatus.COMPLETED : DDLStatus.UNDERGO,
      isSelected: false,
      canToggle: item.habit.isDueToday ?? true,
      remainingText: item.habit.dueStateText ?? '',
      disableProgressAnimation: true,
      onToggle: (): Promise<void> => this.onHabitToggle(item.habit),
      onLongPress: () => {}
    })
  }

  @Builder
  private buildInspirationSearchItem(item: SearchInspirationItem) {
    InspirationSearchCard({
      item: item.inspiration,
      onCardClick: (): void => this.openInspirationDetail(item.inspiration),
      onDelete: (): void => { void this.deleteInspiration(item.inspiration); },
      onAiTask: (): void => this.openAiTaskFromText(item.inspiration.text),
      onAiHabit: (): void => this.openAiHabitFromText(item.inspiration.text)
    })
  }

  private buildArchivedMetaText(item: ArchivedSearchModel): string {
    if (item.detail1.length > 0 && item.detail2.length > 0) {
      return `${item.detail1} · ${item.detail2}`;
    }
    if (item.detail1.length > 0) {
      return item.detail1;
    }
    return item.detail2;
  }

  @Builder
  private buildArchivedSearchItem(item: SearchArchivedItem) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(item.archived.title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .layoutWeight(1)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (item.archived.badgeText.length > 0) {
          Text(item.archived.badgeText)
            .fontSize(10)
            .fontColor(this.theme.indicatorUndergo)
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor(this.theme.bgUndergo40)
            .borderRadius(10)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Text(this.buildArchivedMetaText(item.archived))
        .fontSize(11)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .width('100%')

      if (item.archived.note.length > 0) {
        Text(item.archived.note)
          .fontSize(12)
          .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
          .width('100%')
          .lineHeight(18)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('sys.color.comp_background_secondary'))
    .borderRadius(24)
    .clip(true)
    .gesture(
      LongPressGesture()
        .onAction(() => {
          void this.onArchivedDelete(item.archived);
        })
    )
  }

  @Builder
  private buildSearchListItem(item: SearchListItem) {
    if (item.type === SearchListItemType.SPACER) {
      Column().height(8)
    } else if (item.type === SearchListItemType.LOADING) {
      this.buildLoadingRow()
    } else if (item.type === SearchListItemType.FOOTER) {
      Column().height(100)
    } else if (item.type === SearchListItemType.SYMBOL_HEADER) {
      this.sectionHeader((item as SearchSymbolHeaderItem).title, (item as SearchSymbolHeaderItem).symbol,
        (item as SearchSymbolHeaderItem).color)
    } else if (item.type === SearchListItemType.IMAGE_HEADER) {
      this.imageSectionHeader((item as SearchImageHeaderItem).title, (item as SearchImageHeaderItem).icon)
    } else if (item.type === SearchListItemType.TASK) {
      this.buildTaskSearchItem(item as SearchTaskItem)
    } else if (item.type === SearchListItemType.HABIT) {
      this.buildHabitSearchItem(item as SearchHabitItem)
    } else if (item.type === SearchListItemType.INSPIRATION) {
      this.buildInspirationSearchItem(item as SearchInspirationItem)
    } else {
      this.buildArchivedSearchItem(item as SearchArchivedItem)
    }
  }

  @Builder inspirationSheetBuilder() {
    InspirationEditSheet({
      isShow: $isInspirationSheetShow,
      draftText: $inspirationDraftText,
      item: this.editingInspiration,
      onSave: async (): Promise<void> => {
        await this.saveInspirationDetail();
      },
      onDelete: async (): Promise<void> => {
        if (this.editingInspiration) {
          await this.deleteInspiration(this.editingInspiration);
          this.isInspirationSheetShow = false;
        }
      },
      onAiTask: (): void => this.openAiTaskFromText(this.inspirationDraftText),
      onAiHabit: (): void => this.openAiHabitFromText(this.inspirationDraftText),
      onDirectTask: (): void => this.openDirectTaskFromText(this.inspirationDraftText),
      onDirectHabit: (): void => this.openDirectHabitFromText(this.inspirationDraftText)
    })
  }

  @Builder addTaskSheetBuilder() {
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

  @Builder addHabitSheetBuilder() {
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

  private hasVisibleResults(): boolean {
    return this.visibleResults.tasks.length > 0 ||
      this.visibleResults.habits.length > 0 ||
      this.visibleResults.inspirations.length > 0 ||
      this.visibleResults.archivedTasks.length > 0 ||
      this.visibleResults.archivedHabits.length > 0;
  }

  private getScopeBottomBuilderHeight(): number {
    return this.experimentalComponents && this.api23
      ? this.SCOPE_EXPERIMENTAL_HEIGHT
      : this.SCOPE_SEGMENT_HEIGHT;
  }

  private getTopAvoidHeight(): number {
    return this.statusBarHeight + this.getScopeBottomBuilderHeight();
  }

  @Builder
  private searchScopeBottomBuilder() {
    Column() {
      this.buildSearchScopeRow();
    }
    .width('100%')
    .height('100%')
    .opacity(this.hasSearchTerm ? 1 : 0)
    .enabled(this.hasSearchTerm)
    .hitTestBehavior(this.hasSearchTerm ? HitTestMode.Transparent : HitTestMode.None)
  }

  build() {
    HdsNavDestination() {
      TopSafeContainer({
        topAvoidHeight: this.getTopAvoidHeight(),
        bgColor: this.bgColor,
        scrollable: false
      }) {
        if (!this.hasSearchTerm) {
          this.buildEmptyPlaceholder()
        } else if (!this.isSearching && !this.hasVisibleResults()) {
          this.buildNoResultState()
        } else {
          List({ scroller: this.scroller, space: 10 }) {
            LazyForEach(this.searchListDataSource, (item: SearchListItem) => {
              ListItem() {
                this.buildSearchListItem(item);
              }
            }, (item: SearchListItem) => item.id)
          }
          .width('100%')
          .scrollBar(BarState.Off)
          .padding({ left: 12, right: 12 })
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        }

        Blank()
          .width(0)
          .height(0)
          .bindSheet($$this.isInspirationSheetShow, this.inspirationSheetBuilder(), SheetCompat.immersive({
            height: SheetSize.LARGE,
            showClose: false,
            onDisappear: () => {
              this.isInspirationSheetShow = false;
              this.editingInspiration = null;
            },
          }))

        Blank()
          .width(0)
          .height(0)
          .bindSheet($$this.isAddTaskSheetShow, this.addTaskSheetBuilder(), SheetCompat.immersive({
            height: SheetSize.LARGE,
            showClose: false,
            onDisappear: () => {
              this.isAddTaskSheetShow = false;
            }
          }))

        Blank()
          .width(0)
          .height(0)
          .bindSheet($$this.isAddHabitSheetShow, this.addHabitSheetBuilder(), SheetCompat.immersive({
            height: SheetSize.LARGE,
            showClose: false,
            onDisappear: () => {
              this.isAddHabitSheetShow = false;
            }
          }))
      }
    }
    .backgroundColor(this.bgColor)
    .opacity(this.searchRouteOpacity)
    .titleBar({
      content: {
        title: { mainTitle: '' },
        stackBuilder: () => {
          this.searchBuilder();
        },
        bottomBuilder: {
          builder: () => {
            this.searchScopeBottomBuilder();
          },
          height: this.getScopeBottomBuilderHeight(),
          showType: BottomBuilderShowType.DIRECTLY_SHOW
        },
        backIcon: {
          action: this.backAction
        },
      },
      style: getImmersiveTitleBarStyle(false, false)
    })
  }
}
