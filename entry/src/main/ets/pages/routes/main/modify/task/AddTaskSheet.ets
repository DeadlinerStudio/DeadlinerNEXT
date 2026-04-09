import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { TaskFormView } from './TaskFormView';
import { TaskFormHelper } from './TaskFormHelper';

export interface AddTaskParams {
  name: string;
  note?: string;
  dueTime?: string;
}

@Component
export struct AddTaskSheet {
  onDone: () => void = () => {}
  initialAiInputText: string = '';
  autoTriggerAI: boolean = false;
  initialName: string = '';
  initialNote: string = '';

  @State name: string = '';
  @State note: string = '';
  @State startTime: Date = new Date();
  @State endTime: Date = new Date(new Date().getTime() + 60 * 60 * 1000);

  @State aiInputText: string = '';
  @State isAILoading: boolean = false;

  aboutToAppear(): void {
    if (this.initialName) {
      this.name = this.initialName;
    }
    if (this.initialNote) {
      this.note = this.initialNote;
    }
    if (this.initialAiInputText) {
      this.aiInputText = this.initialAiInputText;
    }

    if (this.autoTriggerAI && this.initialAiInputText) {
      this.onAITriggered();
    }
  }

  private async saveTask() {
    const isSuccess = await TaskFormHelper.saveNewTask(
      this.name, this.note, this.startTime, this.endTime
    );

    if (isSuccess) {
      getContext(this).eventHub.emit('sync_done');
      this.onDone();
    }
  }

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
    HdsNavigation() {
      Column() {
        Blank().height(56)

        Text("填写以下信息以设定你的 Deadline。")
          .fontColor($r('app.color.font_secondary'))
          .fontSize(14)
          .width('100%')
          .padding(16)

        TaskFormView({
          name: $name,
          note: $note,
          startTime: $startTime,
          endTime: $endTime,
          aiInputText: $aiInputText,
          isAILoading: $isAILoading,
          onAITriggered: (): Promise<void> => this.onAITriggered(),
          showAIInput: true
        }).padding({ left: 16, right: 16 })
      }
      .width('100%')
      .height('100%')
    }
    .titleBar({
      content: {
        title: { mainTitle: "创建新任务" },
        menu: { value: [{ content: { icon: $r('sys.symbol.checkmark'), action: async () => this.saveTask() } }] },
        subIcon: { content: { icon: $r('sys.symbol.xmark'), action: this.onDone } }
      }
    })
    .titleMode(HdsNavigationTitleMode.MODAL)
    .hideBackButton(false)
    .backgroundColor(Color.Transparent)
  }
}
