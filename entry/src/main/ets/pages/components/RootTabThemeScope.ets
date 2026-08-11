import { ITheme } from '../../common/theme/ThemeModel';
import { DeadlinerTheme } from '../../AppTheme';

/**
 * 只为主 Tab 的一级页面设置局部 ArkUI/HDS 主题。
 * 自定义组件仍通过显式 ITheme 参数消费同一份 scoped theme。
 */
@Component
export struct RootTabThemeScope {
  @Prop theme: ITheme;
  @BuilderParam content: () => void;

  build() {
    WithTheme({ theme: new DeadlinerTheme(this.theme) }) {
      if (this.content) {
        this.content();
      }
    }
  }
}
