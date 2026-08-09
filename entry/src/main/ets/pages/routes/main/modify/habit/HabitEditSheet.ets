import { promptAction } from '@kit.ArkUI';
import { ITheme } from '../../../../../common/theme/ThemeModel';
import { Habit, HabitGoalType, HabitPeriod, HabitStatus } from '../../../../../model/DDLModels';
import { HabitFormView } from './HabitFormView';
import { HabitFormHelper } from './HabitFormHelper';
import { Toast } from '../../../../../common/ui/Toast';
import { CategoryAssignmentField } from '../../../../components/CategoryAssignmentField';

@Component
export struct HabitEditSheet {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @Link @Watch('onShowChange') isShow: boolean;
  @Prop editingHabit: Habit | undefined;
  onSave: (habit: Habit) => Promise<void> = async () => {};

  // —— 适配 HabitFormView 的状态 ——
  @State private name: string = '';
  @State private selectedPeriodIndex: number[] = [0];
  @State private selectedGoalTypeIndex: number[] = [0];
  @State private timesPerPeriod: string = '1';
  @State private totalTarget: string = '';
  @State private categoryUid: string | null = null;

  // 占位状态，用于满足 HabitFormView 的 Link 约束 (即使不显示 AI)
  @State private aiInputText: string = '';
  @State private isAILoading: boolean = false;

  // 辅助映射数组，用于初始化时 Enum -> Index 的回填查找
  private periodMap = [HabitPeriod.DAILY, HabitPeriod.WEEKLY, HabitPeriod.MONTHLY, HabitPeriod.EBBINGHAUS];
  private goalMap = [HabitGoalType.PER_PERIOD, HabitGoalType.TOTAL];

  // —— 初始化数据 ——
  onShowChange() {
    if (this.isShow && this.editingHabit) {
      this.initData(this.editingHabit);
    }
  }

  aboutToAppear() {
    if (this.isShow && this.editingHabit) {
      this.initData(this.editingHabit);
    }
  }

  private initData(habit: Habit) {
    this.name = habit.name;

    // 周期：枚举 -> 索引
    const pIndex = this.periodMap.indexOf(habit.period);
    this.selectedPeriodIndex = [pIndex !== -1 ? pIndex : 0];

    // 目标类型：枚举 -> 索引
    const gIndex = this.goalMap.indexOf(habit.goalType);
    this.selectedGoalTypeIndex = [gIndex !== -1 ? gIndex : 0];

    // 数字转字符串
    this.timesPerPeriod = habit.timesPerPeriod.toString();
    this.totalTarget = habit.totalTarget ? habit.totalTarget.toString() : "";
    this.categoryUid = habit.categoryUid;
  }

  // —— 保存逻辑 ——
  private async saveHabitEdit() {
    // 1. 基础校验
    if (!this.name.trim()) {
      Toast.show({ message: '请输入习惯名称' });
      return;
    }

    const pIndex = this.selectedPeriodIndex.length > 0 ? this.selectedPeriodIndex[0] : 0;
    const gIndex = this.selectedGoalTypeIndex.length > 0 ? this.selectedGoalTypeIndex[0] : 0;

    const isSimple = HabitFormHelper.isSimpleMode(pIndex);

    let times = 1;
    let total: number | null = null;
    let newGoalType = HabitGoalType.PER_PERIOD;

    // 2. 根据模式校验频次和总目标
    if (!isSimple) {
      times = parseInt(this.timesPerPeriod);
      if (isNaN(times) || times <= 0) {
        Toast.show({ message: '请输入有效的单次目标' });
        return;
      }

      newGoalType = HabitFormHelper.getGoalTypeFromIndex(gIndex);

      if (newGoalType === HabitGoalType.TOTAL) {
        total = parseInt(this.totalTarget);
        if (isNaN(total) || total <= 0) {
          Toast.show({ message: '请输入有效的总目标' });
          return;
        }
      }
    }

    try {
      if (!this.editingHabit) {
        Toast.show({ message: '数据异常' });
        return;
      }

      const newPeriod = HabitFormHelper.getPeriodFromIndex(pIndex);

      // 3. 构建更新后的对象，保留原有关键字段不变
      const updatedHabit: Habit = {
        id: this.editingHabit.id,
        ddlId: this.editingHabit.ddlId,
        name: this.name,
        description: this.editingHabit.description || "",
        color: this.editingHabit.color,
        iconKey: this.editingHabit.iconKey,
        categoryUid: this.categoryUid,
        period: newPeriod,
        timesPerPeriod: times,
        goalType: newGoalType,
        totalTarget: total,
        createdAt: this.editingHabit.createdAt,
        updatedAt: new Date().toISOString(), // 刷新更新时间
        status: this.editingHabit.status,
        sortOrder: this.editingHabit.sortOrder,
        alarmTime: this.editingHabit.alarmTime
      };

      // 4. 调用父组件回调
      await this.onSave(updatedHabit);

      // 5. UI 反馈与关闭
      Toast.show({ message: '修改成功' });
      this.isShow = false;

    } catch (e) {
      console.error(`Update habit failed: ${e}`);
      Toast.show({ message: '修改失败' });
    }
  }

  build() {
    Column() {
      Column({ space: 16 }) {

        // 核心：复用公共表单视图
        HabitFormView({
          name: $name,
          selectedPeriodIndex: $selectedPeriodIndex,
          selectedGoalTypeIndex: $selectedGoalTypeIndex,
          timesPerPeriod: $timesPerPeriod,
          totalTarget: $totalTarget,
          aiInputText: $aiInputText, // 传入占位变量
          isAILoading: $isAILoading, // 传入占位变量
          showAIInput: false         // 明确隐藏 AI 区域
        })

        CategoryAssignmentField({ categoryUid: $categoryUid })

        Button('保存')
          .onClick(() => {
            this.saveHabitEdit();
          })
          .width('100%')
          .backgroundColor(this.theme.accent)
          .margin({ top: 8 })

        Blank().height(60)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16 })
  }
}
