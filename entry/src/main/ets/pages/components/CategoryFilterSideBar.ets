import { CategoryFilter, CategoryFilterMode } from '../../common/category/CategoryFilter';
import { CategorySelectionMode, CategorySelectionPanel } from './CategorySelectionPanel';
import { TopSafeContainer } from './TopSafeContainer';

@Component
export struct CategoryFilterSideBar {
  @Link categoryFilter: CategoryFilter;
  @State private selectedCategoryUids: string[] = [];
  @State private isUncategorizedSelected: boolean = false;
  @StorageLink('statusBarHeight') private statusBarHeight: number = 38;
  @StorageLink('topAvoidExtraHeight') private topAvoidExtraHeight: number = 0;
  private readonly titleBarAvoidHeight: number = 18;

  aboutToAppear(): void {
    this.syncSelectionFromFilter();
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

  build() {
    Stack() {
      TopSafeContainer({
        bgColor: Color.Transparent,
        topAvoidHeight: this.statusBarHeight + this.titleBarAvoidHeight + this.topAvoidExtraHeight,
        scrollable: false
      }) {
        CategorySelectionPanel({
          selectionMode: CategorySelectionMode.MULTIPLE,
          multipleSelectedCategoryUids: this.selectedCategoryUids,
          isUncategorizedSelected: this.isUncategorizedSelected,
          onMultipleSelectionChanged: (uids: string[], isUncategorizedSelected: boolean): void => {
            this.applySelection(uids, isUncategorizedSelected);
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
