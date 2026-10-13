import { DDLItem, Habit } from '../../../model/DDLModels';
import { FocusPresentation } from './FocusPresentation';
import { FocusTextAction } from './FocusTimerControls';

@Component
export struct FocusSummaryContent {
  @Prop title: string = '';
  @Prop todaySeconds: number = 0;
  @Prop totalSeconds: number = 0;
  @Prop sessionCount: number = 0;
  @Prop selected: boolean = false;
  build() {
    Column({ space: 12 }) {
      Text(this.title.length > 0 ? this.title : '全局专注摘要').fontSize(17).fontWeight(FontWeight.Medium)
        .width('100%').fontColor($r('sys.color.font_primary'))
      Row() {
        Column({ space: 4 }) {
          Text('今日').fontSize(12).fontColor($r('sys.color.font_secondary'))
          Text(FocusPresentation.duration(this.todaySeconds)).fontSize(17).fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start).justifyContent(FlexAlign.Start)
        Column({ space: 4 }) {
          Text(this.selected ? '累计' : '会话数').fontSize(12).fontColor($r('sys.color.font_secondary'))
          Text(this.selected ? FocusPresentation.duration(this.totalSeconds) : this.sessionCount.toString() + ' 次')
            .fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start).justifyContent(FlexAlign.Start)
      }.width('100%')
    }.width('100%').padding(18).backgroundColor($r('app.color.background_secondary')).borderRadius(24)
      .alignItems(HorizontalAlign.Start).justifyContent(FlexAlign.Start)
  }
}

@Component
export struct FocusResultContent {
  @Prop hasSession: boolean = false;
  @Prop seconds: number = 0;
  @Prop showRecord: boolean = false;
  @Prop canRecord: boolean = false;
  @Prop canCompleteTask: boolean = false;
  @Prop taskCompleted: boolean = false;
  @Prop busy: boolean = false;
  onRecord: () => void = () => {};
  onCompleteTask: () => void = () => {};
  build() {
    Column({ space: 16 }) {
      Text('本轮已结束').fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
      if (this.hasSession) {
        Text(FocusPresentation.duration(this.seconds)).fontSize(32).fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        if (this.showRecord) {
          FocusTextAction({ label: '为本轮打卡', actionEnabled: !this.busy && this.canRecord, onAction: this.onRecord })
        }
        if (this.canCompleteTask) {
          FocusTextAction({ label: '完成任务', actionEnabled: !this.busy, onAction: this.onCompleteTask })
        } else if (this.taskCompleted) {
          Text('任务已完成').fontSize(14).fontColor($r('sys.color.font_secondary'))
        }
      }
    }.padding({ top: 36, bottom: 36 }).width('100%').justifyContent(FlexAlign.Start)
  }
}

@Component
export struct FocusRecordConfirmation {
  @Prop name: string = '';
  @Prop date: string = '';
  @Prop quantity: boolean = false;
  @Prop unit: string = '';
  @Prop metadataChanged: boolean = false;
  @Prop busy: boolean = false;
  @Link amount: string;
  onCancel: () => void = () => {};
  onConfirm: () => void = () => {};
  build() {
    Column({ space: 12 }) {
      Text(this.name + ' · ' + this.date).fontSize(14).width('100%').fontColor($r('sys.color.font_primary'))
      if (this.metadataChanged) {
        Text('习惯已修改，请取消并重新打开打卡确认。').fontSize(12).width('100%').fontColor($r('sys.color.font_secondary'))
      }
      if (this.quantity) {
        TextInput({ text: this.amount, placeholder: '本次实际完成数量' }).type(InputType.Number).borderRadius(20)
          .onChange((value: string): void => { this.amount = value; })
        if (this.unit.length > 0) Text(this.unit).fontSize(12).fontColor($r('sys.color.font_secondary'))
      }
      Row({ space: 12 }) {
        FocusTextAction({ label: '取消', actionEnabled: !this.busy, onAction: this.onCancel }).layoutWeight(1)
        FocusTextAction({ label: '确认结束并打卡', actionEnabled: !this.busy && !this.metadataChanged,
          onAction: this.onConfirm }).layoutWeight(1)
      }.width('100%')
    }.padding(16).width('100%').backgroundColor($r('app.color.background_secondary')).borderRadius(24)
      .alignItems(HorizontalAlign.Start).justifyContent(FlexAlign.Start)
  }
}

@Component
export struct FocusHistoryRow {
  @Prop startedAt: string = '';
  @Prop seconds: number = 0;
  @Prop showRecord: boolean = false;
  @Prop canRecord: boolean = false;
  @Prop editing: boolean = false;
  @Prop busy: boolean = false;
  @Link editText: string;
  onRecord: () => void = () => {};
  onEdit: () => void = () => {};
  onDelete: () => void = () => {};
  onSave: () => void = () => {};
  onCancelEdit: () => void = () => {};
  build() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(new Date(this.startedAt).toLocaleDateString()).fontSize(13).fontColor($r('sys.color.font_secondary')).layoutWeight(1)
        Text(FocusPresentation.duration(this.seconds)).fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
      }.width('100%')
      Row({ space: 8 }) {
        if (this.showRecord) {
          FocusTextAction({ label: '打卡', actionEnabled: !this.busy && this.canRecord, onAction: this.onRecord })
        }
        FocusTextAction({ label: '更正', actionEnabled: !this.busy, onAction: this.onEdit })
        FocusTextAction({ label: '删除', destructive: true, actionEnabled: !this.busy, onAction: this.onDelete })
      }.width('100%').justifyContent(FlexAlign.Start)
      if (this.editing) {
        Row({ space: 8 }) {
          TextInput({ text: this.editText, placeholder: '有效秒数' }).type(InputType.Number).layoutWeight(1).borderRadius(20)
            .onChange((value: string): void => { this.editText = value; })
          FocusTextAction({ label: '保存', actionEnabled: !this.busy, onAction: this.onSave })
          FocusTextAction({ label: '取消', actionEnabled: !this.busy, onAction: this.onCancelEdit })
        }.width('100%')
      }
    }.width('100%').padding(14).backgroundColor($r('app.color.background_secondary')).borderRadius(24)
      .alignItems(HorizontalAlign.Start).justifyContent(FlexAlign.Start)
  }
}

@Component
export struct FocusTargetPicker {
  @Prop tasks: DDLItem[] = [];
  @Prop habits: Habit[] = [];
  @Prop busy: boolean = false;
  onTask: (task: DDLItem) => void = (_task: DDLItem): void => {};
  onHabit: (habit: Habit) => void = (_habit: Habit): void => {};
  onCancel: () => void = () => {};
  build() {
    Column({ space: 10 }) {
      Text('选择任务或习惯').fontSize(16).fontWeight(FontWeight.Medium).width('100%').fontColor($r('sys.color.font_primary'))
      if (this.tasks.length === 0) Text('暂无可专注的任务').fontSize(14).fontColor($r('sys.color.font_secondary'))
      ForEach(this.tasks, (task: DDLItem) => {
        FocusTextAction({ label: task.name, actionEnabled: !this.busy, onAction: (): void => { this.onTask(task); } }).width('100%')
      }, (task: DDLItem) => task.uid ?? task.id.toString())
      Text('习惯').fontSize(15).fontWeight(FontWeight.Medium).width('100%').fontColor($r('sys.color.font_primary'))
      ForEach(this.habits, (habit: Habit) => {
        FocusTextAction({ label: habit.name, actionEnabled: !this.busy, onAction: (): void => { this.onHabit(habit); } }).width('100%')
      }, (habit: Habit) => habit.uid ?? habit.id.toString())
      FocusTextAction({ label: '返回', actionEnabled: !this.busy, onAction: this.onCancel })
    }.width('100%').padding(18).backgroundColor($r('app.color.background_secondary')).borderRadius(24)
      .alignItems(HorizontalAlign.Start).justifyContent(FlexAlign.Start)
  }
}
