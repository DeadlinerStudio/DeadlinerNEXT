import { promptAction } from '@kit.ArkUI';
import { ITheme } from '../../../../../common/theme/ThemeModel';
import { DDLItem } from '../../../../../model/DDLModels';
import { DateTimeUtils } from '../../../../../utils/DateTimeUtils';
import { TaskFormView } from './TaskFormView';
import { Toast } from '../../../../../common/ui/Toast';
import { CategoryAssignmentField } from '../../../../components/CategoryAssignmentField';
import { MaterialPresets } from '../../../../../common/style/SystemMaterialCompat';

@Component
export struct TaskEditSheet {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @Link @Watch('onShowChange') isShow: boolean;
  @Prop editingTask: DDLItem | null;
  onSave: (task: DDLItem) => Promise<void> = async () => {};

  // —— 适配 TaskFormView 的状态 ——
  @State private name: string = '';
  @State private note: string = '';
  @State private startTime: Date = new Date();
  @State private endTime: Date = new Date();
  @State private categoryUid: string | null = null;

  // 占位状态，满足 TaskFormView 的 Link 约束
  @State private aiInputText: string = '';
  @State private isAILoading: boolean = false;

  aboutToAppear(): void {
    this.loadData();
  }

  onShowChange() {
    this.loadData();
  }

  // —— 初始化回填数据 ——
  private loadData() {
    if (this.isShow && this.editingTask) {
      this.name = this.editingTask.name;
      this.note = this.editingTask.note;
      this.startTime = new Date(this.editingTask.startTime);
      this.endTime = new Date(this.editingTask.endTime);
      this.categoryUid = this.editingTask.categoryUid ?? null;
    } else {
      console.error('[Edit] Invalid data')
    }
  }

  // —— 保存编辑逻辑 ——
  private async saveEdit() {
    if (!this.editingTask) return;

    if (!this.name.trim()) {
      Toast.show({ message: '任务名称不能为空' });
      return;
    }

    try {
      // 更新传入的 DDLItem 对象
      this.editingTask.name = this.name;
      this.editingTask.note = this.note;
      this.editingTask.startTime = DateTimeUtils.toLocalISOString(this.startTime);
      this.editingTask.endTime = DateTimeUtils.toLocalISOString(this.endTime);
      this.editingTask.categoryUid = this.categoryUid;

      // 调用父组件传入的保存回调
      await this.onSave(this.editingTask);

      // 关闭弹窗
      this.isShow = false;
      Toast.show({ message: '修改已保存' });

    } catch (e) {
      console.error('Save edit failed:', e);
      Toast.show({ message: '保存失败' });
    }
  }

  build() {
    Column() {
      Column({ space: 16 }) {
        // 复用公共表单视图，显式隐藏 AI 区域
        TaskFormView({
          name: $name,
          note: $note,
          startTime: $startTime,
          endTime: $endTime,
          aiInputText: $aiInputText, // 传入占位变量
          isAILoading: $isAILoading, // 传入占位变量
          showAIInput: false
        })

        CategoryAssignmentField({ categoryUid: $categoryUid })

        Button('保存')
          .onClick(() => {
            this.saveEdit();
          })
          .width('100%')
          .backgroundColor(this.theme.accent)
          .attributeModifier(MaterialPresets.buttonGlow(true, undefined, this.theme.accent))
          .margin({ top: 8 })

        Blank().height(60)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16 })
  }
}
