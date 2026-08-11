import { CategorySelectionMode, CategorySelectionPanel } from './CategorySelectionPanel';

@Component
export struct CategoryPickerSheet {
  @Link isShown: boolean;
  @Link selectedCategoryUid: string | null;
  onChanged: () => void = (): void => {};

  private select(uid: string | null): void {
    this.selectedCategoryUid = uid;
    this.onChanged();
    this.isShown = false;
  }

  build() {
    CategorySelectionPanel({
      selectionMode: CategorySelectionMode.SINGLE,
      singleSelectedCategoryUid: this.selectedCategoryUid,
      onSingleSelectionChanged: (uid: string | null): void => { this.select(uid); },
      onCatalogChanged: (): void => { this.onChanged(); }
    })
  }
}
