import { promptAction } from '@kit.ArkUI';
import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { HabitFormView } from './HabitFormView';
import { ITheme } from '../../../../../common/theme/ThemeModel';
import { HabitFormHelper } from './HabitFormHelper'; // 引入 Helper

@Component
export struct AddHabitSheet {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  onDone: () => void = () => {}
  initialAiInputText: string = '';
  autoTriggerAI: boolean = false;
  initialName: string = '';

  @State name: string = '';
  @State selectedPeriodIndex: number[] = [0];
  @State selectedGoalTypeIndex: number[] = [0];
  @State timesPerPeriod: string = '1';
  @State totalTarget: string = '';
  @State aiInputText: string = '';
  @State isAILoading: boolean = false;

  aboutToAppear(): void {
    if (this.initialName) {
      this.name = this.initialName;
    }
    if (this.initialAiInputText) {
      this.aiInputText = this.initialAiInputText;
    }

    if (this.autoTriggerAI && this.initialAiInputText) {
      this.onAITriggered();
    }
  }

  private async saveHabit() {
    const pIndex = this.selectedPeriodIndex.length > 0 ? this.selectedPeriodIndex[0] : 0;
    const gIndex = this.selectedGoalTypeIndex.length > 0 ? this.selectedGoalTypeIndex[0] : 0;

    const isSuccess = await HabitFormHelper.saveNewHabit(
      this.name, pIndex, gIndex, this.timesPerPeriod, this.totalTarget
    );

    if (isSuccess) {
      getContext(this).eventHub.emit('sync_done');
      this.onDone();
    }
  }

  private async onAITriggered() {
    this.isAILoading = true;
    const result = await HabitFormHelper.parseAIInput(this.aiInputText);
    if (result) {
      this.name = result.name;
      this.selectedPeriodIndex = [result.pIndex];
      this.selectedGoalTypeIndex = [result.gIndex];
      this.timesPerPeriod = result.times;
      this.totalTarget = result.total;
    }
    this.isAILoading = false;
  }

  build() {
    HdsNavigation() {
      Column() {
        Blank().height(56)

        Text("设定一个新的日常事务。")
          .fontColor($r('app.color.font_secondary'))
          .fontSize(14)
          .width('100%')
          .padding(16)

        HabitFormView({
          name: $name,
          selectedPeriodIndex: $selectedPeriodIndex,
          selectedGoalTypeIndex: $selectedGoalTypeIndex,
          timesPerPeriod: $timesPerPeriod,
          totalTarget: $totalTarget,
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
        title: { mainTitle: "创建新待办" },
        menu: { value: [{ content: { icon: $r('sys.symbol.checkmark'), action: async () => this.saveHabit() } }] },
        subIcon: { content: { icon: $r('sys.symbol.xmark'), action: this.onDone } }
      }
    })
    .titleMode(HdsNavigationTitleMode.MODAL)
    .hideBackButton(false)
    .backgroundColor(Color.Transparent)
  }
}
