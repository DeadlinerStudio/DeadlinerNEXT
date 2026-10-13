import { LocalValues } from '../../../../../common/local/LocalValues';
import { QuickAddSheet } from '../quickadd/QuickAddSheet';
import { promptAction } from '@kit.ArkUI';
import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { HabitFormView } from './HabitFormView';
import { ITheme } from '../../../../../common/theme/ThemeModel';
import { HabitFormHelper } from './HabitFormHelper'; // 引入 Helper
import { CategoryAssignmentField } from '../../../../components/CategoryAssignmentField';
import { getImmersiveTitleBarStyle } from '../../../../../common/style/NavStyles';
import { HdsTitleBarMenuButton } from '../../../../components/HdsTitleBarMenuButton';

@Component
export struct AddHabitSheet {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  onDone: () => void = () => {}
  allowQuickAdd: boolean = true;
  initialAiInputText: string = '';
  autoTriggerAI: boolean = false;
  initialName: string = '';
  initialPeriodIndex: number = 0;
  initialGoalIndex: number = 0;
  initialTarget: string = '1';
  initialWeekdaysMask: number = 127;
  initialReminderTime: string | null = null;

  @State name: string = '';
  @State selectedPeriodIndex: number[] = [0];
  @State selectedGoalTypeIndex: number[] = [0];
  @State timesPerPeriod: string = '1';
  @State totalTarget: string = '';
  @State weekdaysMask: number = 127;
  @State aiInputText: string = '';
  @State isAILoading: boolean = false;
  @State categoryUid: string | null = null;

  aboutToAppear(): void {
    this.selectedPeriodIndex = [this.initialPeriodIndex];
    this.selectedGoalTypeIndex = [this.initialGoalIndex];
    this.timesPerPeriod = this.initialTarget;
    if (this.initialGoalIndex === 1) this.totalTarget = this.initialTarget;
    this.weekdaysMask = this.initialWeekdaysMask;
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
      this.name, pIndex, gIndex, this.timesPerPeriod, this.totalTarget, this.categoryUid, this.weekdaysMask, this.initialReminderTime
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
    if (this.allowQuickAdd && LocalValues.getInstance().getQuickAddEnabled() &&
      !this.initialName && !this.initialAiInputText) {
      QuickAddSheet({ onDone: this.onDone, initialKind: 'HABIT' })
    } else {
      this.fullEditor()
    }
  }

  @Builder
  fullEditor() {
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
          weekdaysMask: $weekdaysMask,
          aiInputText: $aiInputText,
          isAILoading: $isAILoading,
          onAITriggered: (): Promise<void> => this.onAITriggered(),
          showAIInput: true
        }).padding({ left: 16, right: 16 })

        CategoryAssignmentField({ categoryUid: $categoryUid })
          .margin({ left: 16, right: 16, top: 12 })
      }
      .width('100%')
      .height('100%')
    }
    .titleBar({
      style: getImmersiveTitleBarStyle(false),
      content: {
        title: { mainTitle: "创建新习惯" },
        subIcon: { content: { icon: $r('sys.symbol.xmark'), action: this.onDone } },
        menu: {
          value: [{ content: { icon: $r('sys.symbol.checkmark'), action: (): void => { void this.saveHabit(); } } }]
        }
      }
    })
    .titleMode(HdsNavigationTitleMode.MODAL)
    .hideBackButton(false)
    .backgroundColor(Color.Transparent)
  }
}
