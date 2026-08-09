import { CategoryEditorSheet } from './CategoryEditorSheet';
import { CategoryIconResolver } from '../../common/category/CategoryIconResolver';
import { CategoryDisplayModel } from '../../common/kmp/KmpCategoryRepositoryAdapter';
import { CategoryRepository } from '../../common/repository/CategoryRepository';
import { ITheme } from '../../common/theme/ThemeModel';
import { Toast } from '../../common/ui/Toast';
import { MaterialPresets } from '../../common/style/SystemMaterialCompat';
import { SheetCompat } from '../../common/ui/SheetCompat';

@Component
export struct CategoryPickerSheet {
  @Link isShown: boolean;
  @Link selectedCategoryUid: string | null;
  onChanged: () => void = (): void => {};

  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  @State private categories: CategoryDisplayModel[] = [];
  @State private isLoading: boolean = true;
  @State private isEditorShown: boolean = false;
  private readonly repository: CategoryRepository = CategoryRepository.getInstance();

  aboutToAppear(): void {
    void this.loadCategories();
  }

  private async loadCategories(): Promise<void> {
    this.isLoading = true;
    try {
      this.categories = await this.repository.listCategories();
    } catch (error) {
      console.error('[CategoryPicker] Load failed: ' + String(error));
      Toast.show({ message: '分类目录暂不可用' });
    } finally {
      this.isLoading = false;
    }
  }

  private select(uid: string | null): void {
    this.selectedCategoryUid = uid;
    this.onChanged();
    this.isShown = false;
  }

  @Builder
  private optionRow(category: CategoryDisplayModel) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 12 }) {
        SymbolGlyph(CategoryIconResolver.resolve(category.iconKey))
          .fontSize(20)
          .fontColor([category.colorHex])
        Text(category.name)
          .fontSize(16)
          .layoutWeight(1)
        if (this.selectedCategoryUid === category.uid) {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(18)
            .fontColor([category.colorHex])
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    }
    .width('100%')
    .backgroundColor(this.selectedCategoryUid === category.uid ? '#140A59F7' : Color.Transparent)
    .borderRadius(16)
    .onClick((): void => { this.select(category.uid); })
  }

  build() {
    Column({ space: 12 }) {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Row({ space: 12 }) {
          SymbolGlyph($r('sys.symbol.nosign'))
            .fontSize(20)
            .fontColor([
              this.selectedCategoryUid === null ? this.theme.brand : $r('sys.color.ohos_id_color_text_secondary')
            ])
          Text('未分类')
            .fontSize(16)
            .layoutWeight(1)
          if (this.selectedCategoryUid === null) {
            SymbolGlyph($r('sys.symbol.checkmark'))
              .fontSize(18)
              .fontColor([this.theme.brand])
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      }
      .width('100%')
      .backgroundColor(this.selectedCategoryUid === null ? '#140A59F7' : Color.Transparent)
      .borderRadius(16)
      .onClick((): void => { this.select(null); })

      if (this.isLoading) {
        LoadingProgress()
          .width(28)
          .height(28)
          .margin({ top: 24 })
      } else {
        Scroll() {
          Column({ space: 4 }) {
            ForEach(this.categories, (category: CategoryDisplayModel): void => {
              this.optionRow(category);
            }, (category: CategoryDisplayModel): string => category.uid)
          }
          .width('100%')
        }
        .layoutWeight(1)
        .width('100%')
      }

      Button('新建分类')
        .type(ButtonType.Capsule)
        .width('100%')
        .backgroundColor(this.theme.brand)
        .fontColor(Color.White)
        .fontWeight(FontWeight.Medium)
        .attributeModifier(MaterialPresets.buttonGlow(true, undefined, this.theme.brand))
        .onClick((): void => { this.isEditorShown = true; })
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .bindSheet($$this.isEditorShown, this.categoryEditorBuilder(), SheetCompat.immersive({
      detents: [SheetSize.FIT_CONTENT, SheetSize.MEDIUM, SheetSize.LARGE],
      height: SheetSize.MEDIUM,
      dragBar: true,
      showClose: true,
      onDisappear: (): void => { this.isEditorShown = false; },
      title: { title: '新建分类' }
    }))
  }

  @Builder
  private categoryEditorBuilder() {
    CategoryEditorSheet({
      isShown: $isEditorShown,
      onSaved: (category: CategoryDisplayModel): void => {
        this.selectedCategoryUid = category.uid;
        this.onChanged();
        this.isShown = false;
      }
    })
  }
}
