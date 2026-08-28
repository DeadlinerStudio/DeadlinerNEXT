import { AppLog } from '../../common/logging/AppLog';
import { CategoryPickerSheet } from './CategoryPickerSheet';
import { CategoryIconResolver } from '../../common/category/CategoryIconResolver';
import { CategoryDisplayModel } from '../../common/kmp/KmpCategoryRepositoryAdapter';
import { CategoryRepository } from '../../common/repository/CategoryRepository';
import { SheetCompat } from '../../common/ui/SheetCompat';

const FORM_CONTROL_RADIUS = 24;

@Component
export struct CategoryAssignmentField {
  @Link @Watch('onCategoryUidChanged') categoryUid: string | null;
  @State private category: CategoryDisplayModel | null = null;
  @State private isPickerShown: boolean = false;
  private readonly repository: CategoryRepository = CategoryRepository.getInstance();

  aboutToAppear(): void {
    void this.resolveCategory();
  }

  private onCategoryUidChanged(): void {
    void this.resolveCategory();
  }

  private async resolveCategory(): Promise<void> {
    if (this.categoryUid === null) {
      this.category = null;
      return;
    }
    try {
      const categories: CategoryDisplayModel[] = await this.repository.listCategories();
      this.category = null;
      for (let index = 0; index < categories.length; index += 1) {
        if (categories[index].uid === this.categoryUid) {
          this.category = categories[index];
          return;
        }
      }
    } catch (error) {
      AppLog.error('Native', '[CategoryAssignment] Resolve category failed: ' + String(error));
    }
  }

  build() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 10 }) {
        if (this.category === null) {
          SymbolGlyph($r('sys.symbol.bookmark'))
            .fontSize(18)
            .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
          Text('未分类')
            .fontSize(15)
            .layoutWeight(1)
        } else {
          SymbolGlyph(CategoryIconResolver.resolve(this.category.iconKey))
            .fontSize(18)
            .fontColor([this.category.colorHex])
          Text(this.category.name)
            .fontSize(15)
            .layoutWeight(1)
        }
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    }
    .width('100%')
    .borderRadius(FORM_CONTROL_RADIUS)
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .onClick((): void => { this.isPickerShown = true; })
    .bindSheet($$this.isPickerShown, this.categoryPickerBuilder(), SheetCompat.immersive({
      detents: [SheetSize.FIT_CONTENT, SheetSize.MEDIUM, SheetSize.LARGE],
      height: SheetSize.MEDIUM,
      dragBar: true,
      showClose: true,
      onDisappear: (): void => { this.isPickerShown = false; },
      title: { title: '选择分类' }
    }))
  }

  @Builder
  private categoryPickerBuilder() {
    CategoryPickerSheet({
      isShown: $isPickerShown,
      selectedCategoryUid: $categoryUid,
      onChanged: (): void => { void this.resolveCategory(); }
    })
  }
}
