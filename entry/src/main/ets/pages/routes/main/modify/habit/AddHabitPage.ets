import { HabitFormView } from './HabitFormView';
import { HabitFormHelper } from './HabitFormHelper';
import { ITheme } from '../../../../../common/theme/ThemeModel';
import { CategoryAssignmentField } from '../../../../components/CategoryAssignmentField';

@Builder
export function AddHabitBuilder(name: string, param: Object) {
  AddHabitPage()
}

@Component
export struct AddHabitPage {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  pageStack: NavPathStack = new NavPathStack();

  @State name: string = '';
  @State selectedPeriodIndex: number[] = [0];
  @State selectedGoalTypeIndex: number[] = [0];
  @State timesPerPeriod: string = '1';
  @State totalTarget: string = '';
  @State weekdaysMask: number = 127;
  @State aiInputText: string = '';
  @State isAILoading: boolean = false;
  @State categoryUid: string | null = null;

  saveMenuItem: NavigationMenuItem = {
    value: "Save",
    icon: 'resources/base/media/checkmark.svg',
    action: async () => { await this.saveHabit(); }
  }

  private async saveHabit() {
    const pIndex = this.selectedPeriodIndex.length > 0 ? this.selectedPeriodIndex[0] : 0;
    const gIndex = this.selectedGoalTypeIndex.length > 0 ? this.selectedGoalTypeIndex[0] : 0;

    const isSuccess = await HabitFormHelper.saveNewHabit(
      this.name, pIndex, gIndex, this.timesPerPeriod, this.totalTarget, this.categoryUid, this.weekdaysMask
    );

    if (isSuccess) {
      getContext(this).eventHub.emit('sync_done');
      this.pageStack.pop();
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
    NavDestination() {
      Column() {
        Text("创建新习惯")
          .fontSize(24).fontWeight(FontWeight.Bold).width('100%').padding({ left: 4, top: 8 })
        Text("设定一个你想坚持的目标。")
          .fontSize(14).fontColor($r('app.color.font_secondary')).width('100%').padding({ left: 4, bottom: 16 })

        HabitFormView({
          name: $name,
          selectedPeriodIndex: $selectedPeriodIndex,
          selectedGoalTypeIndex: $selectedGoalTypeIndex,
          timesPerPeriod: $timesPerPeriod,
          totalTarget: $totalTarget,
          weekdaysMask: $weekdaysMask,
          aiInputText: $aiInputText,
          isAILoading: $isAILoading,
          onAITriggered: (): Promise<void> => this.onAITriggered(),
          showAIInput: true
        })

        CategoryAssignmentField({ categoryUid: $categoryUid })
          .margin({ top: 12 })
      }
      .width('100%').height('100%').padding(16)
    }
    .title('')
    .onReady((ctx) => { this.pageStack = ctx.pathStack; })
    .menus([this.saveMenuItem])
    .backgroundColor(this.theme.bgPrimary)
  }
}
