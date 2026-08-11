import { CategoryIconResolver } from '../../common/category/CategoryIconResolver';
import { CategoryColorOption, CategoryColorPalette } from '../../common/category/CategoryColorPalette';
import { CategoryDisplayModel, CategoryMutationInput } from '../../common/kmp/KmpCategoryRepositoryAdapter';
import { CategoryRepository } from '../../common/repository/CategoryRepository';
import { ITheme } from '../../common/theme/ThemeModel';
import { Toast } from '../../common/ui/Toast';
import { MaterialPresets } from '../../common/style/SystemMaterialCompat';

@Component
export struct CategoryEditorSheet {
  @Link isShown: boolean;
  @Prop @Watch('onEditingCategoryChanged') editingCategory: CategoryDisplayModel | null = null;
  onSaved: (category: CategoryDisplayModel) => void = (_category: CategoryDisplayModel): void => {};

  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  @State private name: string = '';
  @State private iconKey: string = 'folder';
  @State private colorHex: string = '#3B82F6';
  @State private isSaving: boolean = false;
  private readonly repository: CategoryRepository = CategoryRepository.getInstance();
  private readonly iconKeys: string[] = [
    'tag', 'folder', 'inbox_tray', 'briefcase', 'office_building', 'book', 'education', 'edit', 'home',
    'shopping', 'dining', 'coffee', 'health', 'medical', 'running', 'fitness', 'payment_card', 'cash',
    'analytics', 'group', 'family', 'creativity', 'camera', 'music', 'reading', 'inspiration', 'calendar',
    'time', 'flag', 'idea', 'travel', 'flight', 'gaming', 'tools', 'construction', 'nature'
  ];
  private readonly colorOptions: CategoryColorOption[] = CategoryColorPalette.all();

  aboutToAppear(): void {
    this.applyEditingCategory();
  }

  private onEditingCategoryChanged(): void {
    this.applyEditingCategory();
  }

  private applyEditingCategory(): void {
    if (this.editingCategory === null) {
      this.name = '';
      this.iconKey = 'folder';
      this.colorHex = '#3B82F6';
      return;
    }
    this.name = this.editingCategory.name;
    this.iconKey = this.editingCategory.iconKey;
    this.colorHex = this.editingCategory.colorHex;
  }

  private async save(): Promise<void> {
    const input: CategoryMutationInput = {
      name: this.name,
      iconKey: this.iconKey,
      colorHex: this.colorHex
    };
    if (this.editingCategory !== null) input.uid = this.editingCategory.uid;
    this.isSaving = true;
    try {
      const category: CategoryDisplayModel = this.editingCategory === null
        ? await this.repository.createCategory(input)
        : await this.repository.updateCategory(input);
      this.onSaved(category);
      this.isShown = false;
    } catch (error) {
      console.error('[CategoryEditor] Save failed: ' + String(error));
      Toast.show({ message: '保存分类失败' });
    } finally {
      this.isSaving = false;
    }
  }

  build() {
    Column({ space: 18 }) {
      TextInput({ text: this.name, placeholder: '分类名称' })
        .width('100%')
        .onChange((value: string): void => { this.name = value; })

      Text('图标')
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.iconKeys, (key: string): void => {
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            SymbolGlyph(CategoryIconResolver.resolve(key))
              .fontSize(22)
              .fontColor([this.iconKey === key ? this.colorHex : $r('sys.color.ohos_id_color_text_secondary')])
          }
          .width(44)
          .height(44)
          .margin({ right: 8, bottom: 8 })
          .backgroundColor(this.iconKey === key ? '#140A59F7' : Color.Transparent)
          .borderRadius(12)
          .onClick((): void => { this.iconKey = key; })
        }, (key: string): string => key)
      }
      .width('100%')

      Text('颜色')
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.colorOptions, (option: CategoryColorOption): void => {
          Button({ type: ButtonType.Circle, stateEffect: true }) {}
            .width(28)
            .height(28)
            .margin({ right: 12, bottom: 12 })
            .backgroundColor(option.hex)
            .border({ width: this.colorHex === option.hex ? 3 : 0, color: $r('sys.color.ohos_id_color_text_primary') })
            .onClick((): void => { this.colorHex = option.hex; })
        }, (option: CategoryColorOption): string => option.token)
      }
      .width('100%')

      Button(this.isSaving ? '保存中…' : '保存')
        .enabled(!this.isSaving)
        .type(ButtonType.Capsule)
        .width('100%')
        .backgroundColor(this.theme.brand)
        .fontColor(Color.White)
        .fontWeight(FontWeight.Medium)
        .attributeModifier(MaterialPresets.buttonGlow(true, undefined, this.theme.brand))
        .onClick((): void => { void this.save(); })
    }
    .width('100%')
    .padding(20)
  }
}
