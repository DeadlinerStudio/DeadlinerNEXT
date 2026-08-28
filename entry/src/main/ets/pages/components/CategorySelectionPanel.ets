import { AppLog } from '../../common/logging/AppLog';
import { CategoryEditorSheet } from './CategoryEditorSheet';
import { CategorySelectionItem } from './CategorySelectionItem';
import { CategoryIconResolver } from '../../common/category/CategoryIconResolver';
import { CategoryDisplayModel } from '../../common/kmp/KmpCategoryRepositoryAdapter';
import { CategoryRepository } from '../../common/repository/CategoryRepository';
import { TaskRepository } from '../../common/repository/TaskRepository';
import { ITheme } from '../../common/theme/ThemeModel';
import { MaterialPresets } from '../../common/style/SystemMaterialCompat';
import { DialogCompat } from '../../common/ui/DialogCompat';
import { SheetCompat } from '../../common/ui/SheetCompat';
import { Toast } from '../../common/ui/Toast';
import { HdsListItem } from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';

export enum CategorySelectionMode {
  SINGLE = 'single',
  MULTIPLE = 'multiple'
}

@Component
export struct CategorySelectionPanel {
  @Prop selectionMode: CategorySelectionMode = CategorySelectionMode.SINGLE;
  @Prop singleSelectedCategoryUid: string | null = null;
  @Prop multipleSelectedCategoryUids: string[] = [];
  @Prop isUncategorizedSelected: boolean = false;
  onSingleSelectionChanged: (uid: string | null) => void = (_uid: string | null): void => {};
  onMultipleSelectionChanged: (uids: string[], isUncategorizedSelected: boolean) => void =
    (_uids: string[], _isUncategorizedSelected: boolean): void => {};
  onCatalogChanged: () => void = (): void => {};

  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  @State private categories: CategoryDisplayModel[] = [];
  @State private isLoading: boolean = true;
  @State private isEditorShown: boolean = false;
  @State private editingCategory: CategoryDisplayModel | null = null;
  private readonly categoryRepository: CategoryRepository = CategoryRepository.getInstance();
  private readonly taskRepository: TaskRepository = TaskRepository.getInstance();

  aboutToAppear(): void {
    void this.loadCategories();
  }

  private async loadCategories(): Promise<void> {
    try {
      this.categories = await this.categoryRepository.listCategories();
    } catch (error) {
      AppLog.error('Native', '[CategorySelectionPanel] Load categories failed: ' + String(error));
      Toast.show({ message: '分类目录暂不可用' });
    } finally {
      this.isLoading = false;
    }
  }

  private isAllSelected(): boolean {
    return this.multipleSelectedCategoryUids.length === 0 && !this.isUncategorizedSelected;
  }

  private isCategorySelected(uid: string): boolean {
    if (this.selectionMode === CategorySelectionMode.SINGLE) {
      return this.singleSelectedCategoryUid === uid;
    }
    return this.multipleSelectedCategoryUids.indexOf(uid) >= 0;
  }

  private isUncategorizedOptionSelected(): boolean {
    if (this.selectionMode === CategorySelectionMode.SINGLE) {
      return this.singleSelectedCategoryUid === null;
    }
    return this.isUncategorizedSelected;
  }

  private selectAll(): void {
    this.onMultipleSelectionChanged([], false);
  }

  private selectUncategorized(): void {
    if (this.selectionMode === CategorySelectionMode.SINGLE) {
      this.onSingleSelectionChanged(null);
      return;
    }
    this.onMultipleSelectionChanged(
      this.multipleSelectedCategoryUids.concat(),
      !this.isUncategorizedSelected
    );
  }

  private selectCategory(uid: string): void {
    if (this.selectionMode === CategorySelectionMode.SINGLE) {
      this.onSingleSelectionChanged(uid);
      return;
    }
    const selected: string[] = this.multipleSelectedCategoryUids.concat();
    const selectedIndex: number = selected.indexOf(uid);
    if (selectedIndex >= 0) {
      selected.splice(selectedIndex, 1);
    } else {
      selected.push(uid);
    }
    this.onMultipleSelectionChanged(selected, this.isUncategorizedSelected);
  }

  private openCreate(): void {
    this.editingCategory = null;
    this.isEditorShown = true;
  }

  private openEdit(category: CategoryDisplayModel): void {
    this.editingCategory = category;
    this.isEditorShown = true;
  }

  private confirmDelete(category: CategoryDisplayModel): void {
    AlertDialog.show(DialogCompat.withAlertBlurStyle({
      title: '删除分类？',
      message: '“' + category.name + '”将从分类目录隐藏，已有任务和习惯会显示为未分类。',
      primaryButton: { value: '取消', action: (): void => {}, fontColor: this.theme.brand },
      secondaryButton: {
        value: '删除',
        action: (): void => { void this.deleteCategory(category); },
        fontColor: $r('app.color.warning')
      },
      alignment: DialogAlignment.Bottom
    }, BlurStyle.Regular));
  }

  private async deleteCategory(category: CategoryDisplayModel): Promise<void> {
    try {
      await this.categoryRepository.deleteCategory(category.uid);
      await this.loadCategories();
      this.taskRepository.triggerExternalUpdates();
      if (this.selectionMode === CategorySelectionMode.SINGLE &&
        this.singleSelectedCategoryUid === category.uid) {
        this.onSingleSelectionChanged(null);
        return;
      }
      if (this.selectionMode === CategorySelectionMode.MULTIPLE &&
        this.multipleSelectedCategoryUids.indexOf(category.uid) >= 0) {
        const selected: string[] = this.multipleSelectedCategoryUids.filter((uid: string): boolean => {
          return uid !== category.uid;
        });
        this.onMultipleSelectionChanged(selected, this.isUncategorizedSelected);
      }
      this.onCatalogChanged();
    } catch (error) {
      AppLog.error('Native', '[CategorySelectionPanel] Delete category failed: ' + String(error));
      Toast.show({ message: '删除分类失败' });
    }
  }

  private handleCategorySaved(category: CategoryDisplayModel): void {
    const createdInSingleMode: boolean = this.selectionMode === CategorySelectionMode.SINGLE &&
      this.editingCategory === null;
    void this.finishCategorySave(category, createdInSingleMode);
  }

  private async finishCategorySave(category: CategoryDisplayModel, createdInSingleMode: boolean): Promise<void> {
    await this.loadCategories();
    this.taskRepository.triggerExternalUpdates();
    if (createdInSingleMode) {
      this.onSingleSelectionChanged(category.uid);
      return;
    }
    this.onCatalogChanged();
  }

  private selectedBackgroundColor(): ResourceColor {
    return this.selectionMode === CategorySelectionMode.SINGLE ? '#140A59F7' : '#1F0A59F7';
  }

  @Builder
  private optionRow(
    title: string,
    icon: Resource,
    iconColor: ResourceColor,
    selectionColor: ResourceColor,
    selected: boolean,
    onSelect: () => void
  ) {
    CategorySelectionItem({
      title: title,
      icon: icon,
      iconColor: iconColor,
      selectionColor: selectionColor,
      selected: selected,
      selectedBackgroundColor: this.selectedBackgroundColor(),
      onSelect: onSelect
    })
  }

  @Builder
  private categoryListItem(category: CategoryDisplayModel) {
    HdsListItem({
      customItemBuilder: (): void => {
        this.optionRow(
          category.name,
          CategoryIconResolver.resolve(category.iconKey),
          category.colorHex,
          category.colorHex,
          this.isCategorySelected(category.uid),
          (): void => { this.selectCategory(category.uid); }
        );
      },
      isSelected: this.isCategorySelected(category.uid),
      listItemStateStyles: {
        normalBackgroundColor: Color.Transparent,
        selectedBackgroundColor: Color.Transparent
      },
      hdsListItemCard: {
        cardBackgroundColor: Color.Transparent,
        cardBorderRadius: 16
      },
      swipeActionOptions: {
        icons: [{
          icon: new SymbolGlyphModifier($r('sys.symbol.square_and_pencil')),
          backgroundColor: this.theme.brand,
          onAction: (): void => { this.openEdit(category); }
        }],
        deleteIconOptions: {
          backgroundColor: $r('app.color.warning'),
          iconColor: Color.White,
          onAction: (): void => { this.confirmDelete(category); }
        }
      }
    })
  }

  @Builder
  private simpleListItem(
    title: string,
    icon: Resource,
    iconColor: ResourceColor,
    selectionColor: ResourceColor,
    selected: boolean,
    onSelect: () => void
  ) {
    HdsListItem({
      customItemBuilder: (): void => {
        this.optionRow(title, icon, iconColor, selectionColor, selected, onSelect);
      },
      isSelected: selected,
      listItemStateStyles: {
        normalBackgroundColor: Color.Transparent,
        selectedBackgroundColor: Color.Transparent
      },
      hdsListItemCard: {
        cardBackgroundColor: Color.Transparent,
        cardBorderRadius: 16
      }
    })
  }

  @Builder
  private selectionList() {
    List({ space: 4 }) {
      if (this.selectionMode === CategorySelectionMode.MULTIPLE) {
        if (this.isAllSelected()) {
          this.simpleListItem(
            '全部',
            $r('sys.symbol.square_grid_2x2'),
            $r('sys.color.ohos_id_color_text_secondary'),
            $r('sys.color.ohos_id_color_text_primary'),
            true,
            (): void => { this.selectAll(); }
          )
        } else {
          this.simpleListItem(
            '全部',
            $r('sys.symbol.square_grid_2x2'),
            $r('sys.color.ohos_id_color_text_secondary'),
            $r('sys.color.ohos_id_color_text_primary'),
            false,
            (): void => { this.selectAll(); }
          )
        }
      }
      if (this.isUncategorizedOptionSelected()) {
        this.simpleListItem(
          '未分类',
          $r('sys.symbol.nosign'),
          this.selectionMode === CategorySelectionMode.SINGLE
            ? this.theme.brand
            : $r('sys.color.ohos_id_color_text_secondary'),
          this.selectionMode === CategorySelectionMode.SINGLE
            ? this.theme.brand
            : $r('sys.color.ohos_id_color_text_primary'),
          true,
          (): void => { this.selectUncategorized(); }
        )
      } else {
        this.simpleListItem(
          '未分类',
          $r('sys.symbol.nosign'),
          $r('sys.color.ohos_id_color_text_secondary'),
          this.selectionMode === CategorySelectionMode.SINGLE
            ? this.theme.brand
            : $r('sys.color.ohos_id_color_text_primary'),
          false,
          (): void => { this.selectUncategorized(); }
        )
      }
      ForEach(this.categories, (category: CategoryDisplayModel): void => {
        this.categoryListItem(category);
      }, (category: CategoryDisplayModel): string => {
        return category.uid + (this.isCategorySelected(category.uid) ? ':selected' : ':normal');
      })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }

  build() {
    Column({ space: 12 }) {
      if (this.isLoading) {
        LoadingProgress()
          .width(28)
          .height(28)
          .margin({ top: 24 })
      } else {
        this.selectionList()

        Button('添加分类')
          .type(ButtonType.Capsule)
          .width('100%')
          .margin({
            left: 24,
            right: 24,
            bottom: this.selectionMode === CategorySelectionMode.MULTIPLE ? 56 : 24
          })
          .backgroundColor(this.theme.brand)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Medium)
          .attributeModifier(MaterialPresets.buttonGlow(true, undefined, this.theme.brand))
          .onClick((): void => { this.openCreate(); })
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 8, right: 8, bottom: 8 })
    .bindSheet($$this.isEditorShown, this.categoryEditorBuilder(), SheetCompat.immersive({
      detents: [SheetSize.FIT_CONTENT, SheetSize.MEDIUM, SheetSize.LARGE],
      height: SheetSize.MEDIUM,
      dragBar: true,
      showClose: true,
      onDisappear: (): void => {
        this.isEditorShown = false;
        this.editingCategory = null;
      },
      title: { title: this.editingCategory === null ? '新建分类' : '编辑分类' }
    }))
  }

  @Builder
  private categoryEditorBuilder() {
    CategoryEditorSheet({
      isShown: $isEditorShown,
      editingCategory: this.editingCategory,
      onSaved: (category: CategoryDisplayModel): void => { this.handleCategorySaved(category); }
    })
  }
}
