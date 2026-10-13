import { KmpPersistenceService } from '../../../common/kmp/KmpPersistenceService';
import { KmpFocusTimerRepository } from '../../../common/kmp/KmpFocusTimerRepository';
import { FocusSessionPayload, FocusTimerUiStatePayload } from '../../../model/FocusModels';
import { FocusTargetPayload } from '../../../model/FocusModels';
import { FocusOverviewStatistics, FocusStatisticsSummary } from './FocusStatisticsModels';
import { FocusPresentation } from '../focus/FocusPresentation';
import { StatsCardContainer } from '../../components/OverviewComponents';
import { Toast } from '../../../common/ui/Toast';
import { OverviewMonthRules } from './OverviewDashboardModel';

interface FocusTargetAllocation { target: FocusTargetPayload; title: string; durationSeconds: number; sessionCount: number; }
interface FocusCategoryAllocation { categoryUid: string | null; categoryTitle: string | null; durationSeconds: number; sessionCount: number; }
interface FocusManagementAllocation { summary: FocusStatisticsSummary; targets: FocusTargetAllocation[]; categories: FocusCategoryAllocation[]; }

@Component
export struct OverviewFocusManagement {
  @StorageProp('KmpDataRevision') @Watch('load') revision: number = 0;
  @StorageProp('IsAppDataReady') @Watch('load') dataReady: boolean = false;
  @StorageProp('OverviewClockRevision') @Watch('load') clockRevision: number = 0;
  @StorageProp('OverviewAppForeground') @Watch('load') foreground: boolean = true;
  @State sessions: FocusSessionPayload[] = [];
  @State statistics: FocusOverviewStatistics | null = null;
  @State allocation: FocusManagementAllocation | null = null;
  @State error: string = '';
  @State editing: string = '';
  @State amount: string = '';
  @State deleting: string = '';
  @State busy: boolean = false;
  aboutToAppear(): void { this.load(); }
  private load(): void {
    if (!this.foreground) return;
    try {
      const core: KmpPersistenceService = KmpPersistenceService.getInstance();
      this.sessions = JSON.parse(core.overviewFocusSessionsJson());
      this.statistics = JSON.parse(core.focusOverviewJson());
      this.allocation = JSON.parse(core.overviewFocusQueryJson('{}'));
      this.error = '';
    } catch (error) { this.error = '专注管理加载失败，请重试。'; }
  }
  private limit(session: FocusSessionPayload): number {
    const wall: number = Math.floor((new Date(session.endedAt).getTime() - new Date(session.startedAt).getTime()) / 1000);
    return Math.min(session.durationSeconds, wall, 86400);
  }
  private async mutate(operation: string, session: FocusSessionPayload): Promise<void> {
    const value: number = Number(this.amount);
    if (operation === 'adjust_session' && (!Number.isInteger(value) || value < 1 || value > this.limit(session))) {
      Toast.show({ message: '请输入 1 至 ' + this.limit(session).toString() + ' 秒，只能调低时长。' }); return;
    }
    this.busy = true;
    try {
      const result: FocusTimerUiStatePayload = await KmpFocusTimerRepository.getInstance().command(operation, '', operation === 'adjust_session' ? value : 0, session.uid);
      if (result.lastOutcome !== 'APPLIED') throw new Error(result.error ?? '操作失败');
      this.editing = ''; this.deleting = ''; this.load();
    } catch (error) { Toast.show({ message: '操作失败，输入已保留：' + String(error) }); }
    finally { this.busy = false; }
  }
  @Builder private summary(title: string, summary: FocusStatisticsSummary) {
    StatsCardContainer() {
      Column({ space: 8 }) {
        Text(title).fontSize(16).fontWeight(FontWeight.Medium).width('100%')
        Text(FocusPresentation.duration(summary.totalDurationSeconds)).fontSize(26).fontWeight(FontWeight.Medium).width('100%')
        Text(summary.sessionCount.toString() + ' 次').fontSize(13).fontColor($r('app.color.font_secondary')).width('100%')
        if (summary.durationByTarget !== null) {
          Text('任务 ' + FocusPresentation.duration(summary.durationByTarget.taskDurationSeconds) + ' · 习惯 ' + FocusPresentation.duration(summary.durationByTarget.habitDurationSeconds))
            .fontSize(13).fontColor($r('app.color.font_secondary')).width('100%')
        }
      }.width('100%').alignItems(HorizontalAlign.Start)
    }
  }
  build() {
    Column({ space: 16 }) {
      if (this.error.length > 0) {
        Text(this.error).fontSize(14)
        Button('重试').onClick(() => { this.load(); })
      } else {
        if (this.statistics !== null) {
          this.summary('今天', this.statistics.today)
          this.summary('累计', this.statistics.allTime)
        }
        if (this.allocation !== null) {
          StatsCardContainer() {
            Column({ space: 10 }) {
              Text('目标分配').fontSize(16).fontWeight(FontWeight.Medium).width('100%')
              ForEach(this.allocation.targets, (target: FocusTargetAllocation) => {
                Row({ space: 12 }) {
                  Text((target.target.kind === 'HABIT' ? '习惯 · ' : '任务 · ') + target.title).fontSize(14).layoutWeight(1)
                  Text(FocusPresentation.duration(target.durationSeconds)).fontSize(14)
                }.width('100%')
              }, (target: FocusTargetAllocation) => target.target.kind + ':' + target.target.uid)
              if (this.allocation.targets.length === 0) Text('暂无分配数据').fontSize(14)
            }.width('100%').alignItems(HorizontalAlign.Start)
          }
          StatsCardContainer() {
            Column({ space: 10 }) {
              Text('分类分配').fontSize(16).fontWeight(FontWeight.Medium).width('100%')
              ForEach(this.allocation.categories, (category: FocusCategoryAllocation) => {
                Row({ space: 12 }) {
                  Text(category.categoryTitle ?? '未分类').fontSize(14).layoutWeight(1)
                  Text(FocusPresentation.duration(category.durationSeconds)).fontSize(14)
                }.width('100%')
              }, (category: FocusCategoryAllocation) => category.categoryUid ?? 'unclassified')
            }.width('100%').alignItems(HorizontalAlign.Start)
          }
        }
        Text('全部已保存记录').fontSize(16).fontWeight(FontWeight.Medium).width('100%')
        if (this.sessions.length === 0) Text('暂无已保存的专注记录').fontSize(14).fontColor($r('app.color.font_secondary'))
        ForEach(this.sessions, (session: FocusSessionPayload) => {
          StatsCardContainer() {
            Column({ space: 8 }) {
              Text(session.taskTitleSnapshot).fontSize(16).fontWeight(FontWeight.Medium).width('100%')
              Text(new Date(session.startedAt).toLocaleString()).fontSize(12).fontColor($r('app.color.font_secondary')).width('100%')
              Text(FocusPresentation.duration(session.durationSeconds)).fontSize(20).width('100%')
              if (session.habitOccurredOn) Text('习惯日期 ' + session.habitOccurredOn).fontSize(12).width('100%')
              Row({ space: 12 }) {
                Button('更正').enabled(!this.busy).onClick(() => { this.editing = session.uid; this.amount = session.durationSeconds.toString(); this.deleting = ''; })
                Button('删除').fontColor($r('app.color.warning')).enabled(!this.busy).onClick(() => { this.deleting = session.uid; this.editing = ''; })
              }
              if (this.editing === session.uid) {
                Text('只允许调低时长，最多 ' + this.limit(session).toString() + ' 秒').fontSize(12).width('100%')
                TextInput({ text: this.amount, placeholder: '有效秒数' }).type(InputType.Number).onChange((value: string) => { this.amount = value; })
                Row({ space: 12 }) {
                  Button('取消').enabled(!this.busy).onClick(() => { this.editing = ''; })
                  Button('保存').enabled(!this.busy).onClick(() => { this.mutate('adjust_session', session); })
                }
              }
              if (this.deleting === session.uid) {
                Text('确认删除该记录？此操作不会撤销习惯打卡。').fontSize(14).width('100%')
                Row({ space: 12 }) {
                  Button('取消').enabled(!this.busy).onClick(() => { this.deleting = ''; })
                  Button('确认删除').fontColor($r('app.color.warning')).enabled(!this.busy).onClick(() => { this.mutate('delete_session', session); })
                }
              }
            }.width('100%').alignItems(HorizontalAlign.Start)
          }
        }, (session: FocusSessionPayload) => session.uid)
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
