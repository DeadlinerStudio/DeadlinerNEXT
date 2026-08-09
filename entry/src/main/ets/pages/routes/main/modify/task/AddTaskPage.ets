import { ITheme } from '../../../../../common/theme/ThemeModel';
import { DateTimeUtils } from '../../../../../utils/DateTimeUtils';
import { TaskFormView } from './TaskFormView';
import { TaskFormHelper } from './TaskFormHelper';
import { CategoryAssignmentField } from '../../../../components/CategoryAssignmentField';

export interface AddTaskParams {
  name: string;
  note?: string;
  dueTime?: string; // 格式 "yyyy-MM-dd HH:mm"
}

@Builder
export function AddTaskBuilder(name: string, param: Object) {
  AddTaskPage()
}

@Component
export struct AddTaskPage {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  pageStack: NavPathStack = new NavPathStack();

  // —— 适配 TaskFormView 的状态 ——
  @State name: string = '';
  @State note: string = '';
  @State startTime: Date = new Date();
  @State endTime: Date = new Date(new Date().getTime() + 60 * 60 * 1000);
  @State categoryUid: string | null = null;

  @State aiInputText: string = '';
  @State isAILoading: boolean = false;

  saveMenuItem: NavigationMenuItem = {
    value: "Save",
    icon: 'resources/base/media/checkmark.svg',
    action: async () => {
      await this.saveTask();
    }
  }

  // —— 委托给 Helper 的保存逻辑 ——
  private async saveTask() {
    const isSuccess = await TaskFormHelper.saveNewTask(
      this.name, this.note, this.startTime, this.endTime, this.categoryUid
    );

    if (isSuccess) {
      getContext(this).eventHub.emit('sync_done');
      this.pageStack.pop();
    }
  }

  // —— 委托给 Helper 的 AI 解析逻辑 ——
  private async onAITriggered() {
    this.isAILoading = true;
    const result = await TaskFormHelper.parseAIInput(this.aiInputText);

    if (result) {
      this.name = result.name;
      this.note = result.note;
      if (result.endTime) {
        this.endTime = result.endTime;
      }
    }
    this.isAILoading = false;
  }

  build() {
    NavDestination() {
      Column() {
        // 1. 顶部说明文字保留在容器层
        Text("创建新任务")
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .width('100%')
          .padding({ left: 4, top: 8 })

        Text("填写以下信息以设定你的 Deadline。")
          .fontSize(14)
          .fontColor(Color.Gray)
          .width('100%')
          .padding({ left: 4, bottom: 8 })

        // 2. 引入公共表单视图
        TaskFormView({
          name: $name,
          note: $note,
          startTime: $startTime,
          endTime: $endTime,
          aiInputText: $aiInputText,
          isAILoading: $isAILoading,
          onAITriggered: (): Promise<void> => this.onAITriggered(),
          showAIInput: true // 开启 AI 输入框
        })

        CategoryAssignmentField({ categoryUid: $categoryUid })
          .margin({ top: 12 })
      }
      .width('100%')
      .height('100%')
      .padding(16)
    }
    .title('')
    .onReady((ctx) => {
      this.pageStack = ctx.pathStack;

      // 保留优秀的路由传参解析逻辑
      const param = ctx.pathInfo.param as AddTaskParams;
      if (param) {
        if (param.name) this.name = param.name;
        if (param.note) this.note = param.note;

        // 处理时间
        if (param.dueTime) {
          const parsedDate = DateTimeUtils.parseDateString(param.dueTime);
          if (parsedDate) {
            this.endTime = parsedDate;
            this.startTime = new Date(); // 根据需要，设定为当前时间
          }
        }
      }
    })
    .menus([
      this.saveMenuItem
    ])
    .backgroundColor(this.theme.bgPrimary)
  }
}
