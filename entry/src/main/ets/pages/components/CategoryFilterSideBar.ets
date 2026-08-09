import { CategoryEditorSheet } from './CategoryEditorSheet';
import { CategoryFilter, CategoryFilterMode } from '../../common/category/CategoryFilter';
import { CategoryIconResolver } from '../../common/category/CategoryIconResolver';
import { CategoryDisplayModel } from '../../common/kmp/KmpCategoryRepositoryAdapter';
import { CategoryRepository } from '../../common/repository/CategoryRepository';
import { TaskRepository } from '../../common/repository/TaskRepository';
import { Toast } from '../../common/ui/Toast';
import { ITheme } from '../../common/theme/ThemeModel';
import { HdsListItem } from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { TopSafeContainer } from './TopSafeContainer';
import { MaterialPresets } from '../../common/style/SystemMaterialCompat';
import { DialogCompat } from '../../common/ui/DialogCompat';
import { SheetCompat } from '../../common/ui/SheetCompat';

@Component
export struct CategoryFilterSideBar {
  @Link categoryFilter: CategoryFilter;
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @State private categories: CategoryDisplayModel[] = [];
  @State private isLoading: boolean = true;
  @State private isEditorShown: boolean = false;
  @State private editingCategory: CategoryDisplayModel | null = null;
  @State private selectedCategoryUids: string[] = [];
  @State private isUncategorizedSelected: boolean = false;
  private readonly categoryRepository: CategoryRepository = CategoryRepository.getInstance();
  private readonly taskRepository: TaskRepository = TaskRepository.getInstance();
  @StorageLink('statusBarHeight') private statusBarHeight: number = 38;
  @StorageLink('topAvoidExtraHeight') private topAvoidExtraHeight: number = 0;
  private readonly titleBarAvoidHeight: number = 18;

  aboutToAppear(): void {
    this.syncSelectionFromFilter();
    void this.loadCategories();
  }

  private syncSelectionFromFilter(): void {
    if (this.categoryFilter.mode === CategoryFilterMode.SELECTED) {
      this.selectedCategoryUids = this.categoryFilter.categoryUids.concat();
      this.isUncategorizedSelected = this.categoryFilter.isUncategorizedSelected;
      return;
    }
    this.selectedCategoryUids = [];
    this.isUncategorizedSelected = this.categoryFilter.mode === CategoryFilterMode.UNCATEGORIZED;
  }

  private applySelection(selectedCategoryUids: string[], isUncategorizedSelected: boolean): void {
    this.selectedCategoryUids = selectedCategoryUids.concat();
    this.isUncategorizedSelected = isUncategorizedSelected;
    this.categoryFilter = CategoryFilter.selected(selectedCategoryUids, isUncategorizedSelected);
  }

  private async loadCategories(): Promise<void> {
    try {
      this.categories = await this.categoryRepository.listCategories();
    } catch (error) {
      console.error('[CategorySideBar] Load categories failed: ' + String(error));
      Toast.show({ message: '分类目录暂不可用' });
    } finally {
      this.isLoading = false;
    }
  }

  private selectAll(): void {
    this.applySelection([], false);
  }

  private toggleUncategorized(): void {
    this.applySelection(this.selectedCategoryUids, !this.isUncategorizedSelected);
  }

  private toggleCategory(uid: string): void {
    const selected: string[] = this.selectedCategoryUids.concat();
    const selectedIndex: number = selected.indexOf(uid);
    if (selectedIndex >= 0) {
      selected.splice(selectedIndex, 1);
    } else {
      selected.push(uid);
    }
    this.applySelection(selected, this.isUncategorizedSelected);
  }

  private isSelected(uid: string): boolean {
    return this.selectedCategoryUids.indexOf(uid) >= 0;
  }

  private isAllSelected(): boolean {
    return this.selectedCategoryUids.length === 0 && !this.isUncategorizedSelected;
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
    } catch (error) {
      console.error('[CategorySideBar] Delete category failed: ' + String(error));
      Toast.show({ message: '删除分类失败' });
    }
  }

  @Builder
  private filterRow(title: string, icon: Resource, selected: boolean, onClick: () => void) {
      Row({ space: 12 }) {
        SymbolGlyph(icon)
          .fontSize(20)
          .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
        Text(title)
          .fontSize(16)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .layoutWeight(1)
        if (selected) {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(18)
            .fontColor([$r('sys.color.ohos_id_color_text_primary')])
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(selected ? '#1F0A59F7' : Color.Transparent)
      .borderRadius(16)
      .onClick((): void => { onClick(); })
  }

  @Builder
  private categoryRow(category: CategoryDisplayModel, onClick: () => void) {
      Row({ space: 12 }) {
        SymbolGlyph(CategoryIconResolver.resolve(category.iconKey))
          .fontSize(20)
          .fontColor([category.colorHex])
        Text(category.name)
          .fontSize(16)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .layoutWeight(1)
        if (this.isSelected(category.uid)) {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(18)
            .fontColor([category.colorHex])
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(this.isSelected(category.uid) ? '#1F0A59F7' : Color.Transparent)
      .borderRadius(16)
      .onClick((): void => { onClick(); })
  }

  @Builder
  private categoryListItem(category: CategoryDisplayModel) {
    HdsListItem({
      customItemBuilder: (): void => { this.categoryRow(category, (): void => { this.toggleCategory(category.uid); }); },
      isSelected: this.isSelected(category.uid),
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
  private filterContent() {
    List({ space: 4 }) {
      // HdsListItem caches customItemBuilder content. Use separate branches so
      // the controlled selection state creates a fresh row when it changes.
      if (this.isAllSelected()) {
        HdsListItem({
          customItemBuilder: (): void => {
            this.filterRow('全部', $r('sys.symbol.square_grid_2x2'), true, (): void => {
              this.selectAll();
            });
          },
          isSelected: true,
          listItemStateStyles: {
            normalBackgroundColor: Color.Transparent,
            selectedBackgroundColor: Color.Transparent
          },
          hdsListItemCard: {
            cardBackgroundColor: Color.Transparent,
            cardBorderRadius: 16
          }
        })
      } else {
        HdsListItem({
          customItemBuilder: (): void => {
            this.filterRow('全部', $r('sys.symbol.square_grid_2x2'), false, (): void => {
              this.selectAll();
            });
          },
          isSelected: false,
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
      if (this.isUncategorizedSelected) {
        HdsListItem({
          customItemBuilder: (): void => {
            this.filterRow('未分类', $r('sys.symbol.nosign'), true, (): void => {
              this.toggleUncategorized();
            });
          },
          isSelected: true,
          listItemStateStyles: {
            normalBackgroundColor: Color.Transparent,
            selectedBackgroundColor: Color.Transparent
          },
          hdsListItemCard: {
            cardBackgroundColor: Color.Transparent,
            cardBorderRadius: 16
          }
        })
      } else {
        HdsListItem({
          customItemBuilder: (): void => {
            this.filterRow('未分类', $r('sys.symbol.nosign'), false, (): void => {
              this.toggleUncategorized();
            });
          },
          isSelected: false,
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
      ForEach(this.categories, (category: CategoryDisplayModel): void => {
        this.categoryListItem(category);
      }, (category: CategoryDisplayModel): string => {
        return category.uid + (this.isSelected(category.uid) ? ':selected' : ':normal');
      })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }

  build() {
    Stack() {
      TopSafeContainer({
        bgColor: Color.Transparent,
        topAvoidHeight: this.statusBarHeight + this.titleBarAvoidHeight + this.topAvoidExtraHeight,
        scrollable: false
      }) {
        Column({ space: 12 }) {
          if (this.isLoading) {
            LoadingProgress()
              .width(28)
              .height(28)
              .margin({ top: 24 })
          } else {
            this.filterContent();

            Button('添加分类')
              .type(ButtonType.Capsule)
              .width('100%')
              .margin({ left: 16, right: 16, bottom: 8 })
              .backgroundColor(this.theme.brand)
              .fontColor(Color.White)
              .fontWeight(FontWeight.Medium)
              .attributeModifier(MaterialPresets.buttonGlow(true, undefined, this.theme.brand))
              .onClick((): void => { this.openCreate(); })
          }
        }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 8, right: 8, bottom: 8 })
      }
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.isEditorShown, this.categoryEditorBuilder(), SheetCompat.immersive({
      detents: [SheetSize.FIT_CONTENT, SheetSize.MEDIUM, SheetSize.LARGE],
      height: SheetSize.MEDIUM,
      dragBar: true,
      showClose: true,
      onDisappear: (): void => { this.isEditorShown = false; },
      title: { title: this.editingCategory === null ? '新建分类' : '编辑分类' }
    }))
  }

  @Builder
  private categoryEditorBuilder() {
    CategoryEditorSheet({
      isShown: $isEditorShown,
      editingCategory: this.editingCategory,
      onSaved: (_category: CategoryDisplayModel): void => {
        void this.loadCategories();
        this.taskRepository.triggerExternalUpdates();
      }
    })
  }
}
